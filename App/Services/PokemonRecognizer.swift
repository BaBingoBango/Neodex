import Accelerate
import CoreImage
import CoreVideo
import Foundation
import ImageIO
import NeodexKit
import Vision

/// A camera frame handed from the capture queue to the recogniser.
nonisolated struct CameraFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let orientation: CGImagePropertyOrientation
}

/// A recognised Pokémon and how sure the recogniser is.
nonisolated struct PokemonMatch: Sendable, Hashable, Identifiable {
    var pokemonID: String
    /// 0…1; classifier probability, or a fixed high value for a printed name.
    var confidence: Double
    nonisolated var id: String { pokemonID }
}

/// Recognises Pokémon in images: Vision's scene-print feature vector of the image goes through the
/// softmax head the data pipeline trained (`PokemonClassifier.weights` + `Data/classifier.json`).
/// Printed names (cards, screens) are read as a second opinion. Everything runs on device.
actor PokemonRecognizer {
    static let shared = PokemonRecognizer()

    typealias Match = PokemonMatch

    nonisolated enum RecognizerError: Error, LocalizedError {
        case modelMissing
        case featureMismatch

        var errorDescription: String? {
            switch self {
            case .modelMissing: "The Pokémon recogniser isn't included in this build."
            case .featureMismatch: "This device's image features don't match the recogniser."
            }
        }
    }

    /// Whether this build ships the classifier.
    nonisolated static var isAvailable: Bool {
        ClassifierManifest.url() != nil && weightsURL != nil
    }

    private nonisolated static var weightsURL: URL? {
        Bundle.main.url(forResource: "PokemonClassifier", withExtension: "weights")
    }

    private struct Head {
        let manifest: ClassifierManifest
        /// Row-major `dimension × classes`.
        let weights: [Float]
        let biases: [Float]
    }

    private var head: Head?
    private var names: [(name: String, id: String)] = []

    /// Loads the weights so the first camera frame doesn't stall.
    func prepare() async {
        _ = try? loadHead()
    }

    /// The most likely Pokémon in an image, best first. `fill` crops to the centre (live camera);
    /// otherwise the whole image is letterboxed (photos and screenshots).
    func matches(in image: CGImage, orientation: CGImagePropertyOrientation = .up, limit: Int = 5, fill: Bool = false) async throws -> [Match] {
        var request = GenerateImageFeaturePrintRequest()
        request.cropAndScaleAction = fill ? .centerCrop : .scaleToFit
        let observation = try await request.perform(on: image, orientation: orientation)
        return try classify(observation, limit: limit)
    }

    func matches(in frame: CameraFrame, limit: Int = 5) async throws -> [Match] {
        var request = GenerateImageFeaturePrintRequest()
        request.cropAndScaleAction = .centerCrop
        let observation = try await request.perform(on: frame.pixelBuffer, orientation: frame.orientation)
        return try classify(observation, limit: limit)
    }

    /// Pokémon whose names are printed in the image, such as on a trading card or a web page.
    func namedPokemon(in image: CGImage, orientation: CGImagePropertyOrientation = .up, database: PokedexDatabase) async throws -> [Match] {
        if names.isEmpty {
            names = database.pokemon
                .map { (name: $0.displayName.lowercased(), id: $0.id) }
                .filter { $0.name.count >= 3 }
                .sorted { $0.name.count > $1.name.count }
        }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let observations = try await request.perform(on: image, orientation: orientation)
        var found: [Match] = []
        var seen: Set<String> = []
        for observation in observations {
            guard var line = observation.topCandidates(1).first?.string.lowercased() else { continue }
            // Longest names first, so "mewtwo" can't be claimed by "mew".
            for entry in names where line.contains(entry.name) && !seen.contains(entry.id) {
                seen.insert(entry.id)
                found.append(Match(pokemonID: entry.id, confidence: 0.92))
                line = line.replacingOccurrences(of: entry.name, with: " ")
            }
        }
        return found
    }

    /// Classifier matches and printed names together, strongest first.
    func combinedMatches(in image: CGImage, orientation: CGImagePropertyOrientation = .up, database: PokedexDatabase, limit: Int = 5) async throws -> [Match] {
        let visual = try await matches(in: image, orientation: orientation, limit: limit)
        let named = (try? await namedPokemon(in: image, orientation: orientation, database: database)) ?? []
        return Self.merge(visual, named, limit: limit)
    }

    static func merge(_ visual: [Match], _ named: [Match], limit: Int) -> [Match] {
        var best: [String: Double] = [:]
        for match in visual { best[match.pokemonID] = match.confidence }
        for match in named { best[match.pokemonID] = max(best[match.pokemonID] ?? 0, match.confidence) }
        return best.map { Match(pokemonID: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - The softmax head

    private func classify(_ observation: FeaturePrintObservation, limit: Int) throws -> [Match] {
        let head = try loadHead()
        let dimension = head.manifest.dimension
        let classCount = head.manifest.classes.count
        guard observation.elementCount == dimension else { throw RecognizerError.featureMismatch }
        let features = observation.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let standardised = vDSP.divide(vDSP.subtract(features, head.manifest.featureMean), head.manifest.featureStd)
        var logits = head.biases
        cblas_sgemv(CblasRowMajor, CblasTrans, Int32(dimension), Int32(classCount), 1, head.weights, Int32(classCount),
                    standardised, 1, 1, &logits, 1)
        let peak = vDSP.maximum(logits)
        let exponentials = vForce.exp(vDSP.add(-peak, logits))
        let probabilities = vDSP.divide(exponentials, vDSP.sum(exponentials))
        return probabilities.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(limit)
            .map { Match(pokemonID: head.manifest.classes[$0.offset], confidence: Double($0.element)) }
    }

    private func loadHead() throws -> Head {
        if let head { return head }
        guard let manifest = ClassifierManifest.load(), let url = Self.weightsURL, let data = try? Data(contentsOf: url) else {
            throw RecognizerError.modelMissing
        }
        let floats = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let dimension = manifest.dimension
        let classCount = manifest.classes.count
        guard floats.count == dimension * classCount + classCount,
              manifest.featureMean.count == dimension, manifest.featureStd.count == dimension else {
            throw RecognizerError.modelMissing
        }
        let head = Head(manifest: manifest, weights: Array(floats[0..<dimension * classCount]), biases: Array(floats[(dimension * classCount)...]))
        self.head = head
        return head
    }
}
