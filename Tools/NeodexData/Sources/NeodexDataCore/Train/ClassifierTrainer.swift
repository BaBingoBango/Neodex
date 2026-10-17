import Foundation
import NeodexKit

/// Turns the training set into feature vectors, trains the softmax head and writes what the app
/// needs: `PokemonClassifier.weights` (raw floats) beside the images and `Data/classifier.json`.
enum ClassifierTrainer {
    /// Recorded as `Data/classifier.json`; the app reads the class list and standardisation from it.
    struct Manifest: Codable {
        var version: String
        var trainedAt: Date
        var featureVersion: String
        var dimension: Int
        var classes: [String]
        var featureMean: [Float]
        var featureStd: [Float]
        var trainingImages: Int
        var validationImages: Int
        var trainingAccuracy: Double
        var validationAccuracy: Double?
        var sources: [String: Int]
    }

    struct Result {
        var model: SoftmaxTrainer.Model
        var classes: [String]
        var outcome: SoftmaxTrainer.Outcome
        var trainingImages: Int
        var validationImages: Int
    }

    static func train(training: [String: [URL]], validation: [String: [URL]], cacheDirectory: URL, epochs: Int,
                      concurrency: Int, log: Pipeline.Log) async throws -> Result {
        let classes = training.keys.sorted()
        let classIndex = Dictionary(uniqueKeysWithValues: classes.enumerated().map { ($1, $0) })
        let trainingPairs = classes.flatMap { label in training[label]!.map { ($0, classIndex[label]!) } }
        let validationPairs = classes.flatMap { label in (validation[label] ?? []).map { ($0, classIndex[label]!) } }

        log("Extracting feature vectors for \(trainingPairs.count + validationPairs.count) images…")
        var extractor = FeatureExtractor(cacheDirectory: cacheDirectory)
        extractor.concurrency = concurrency
        let vectors = try await extractor.features(for: (trainingPairs + validationPairs).map(\.0), log: log)
        var trainingSamples: [SoftmaxTrainer.Sample] = []
        var validationSamples: [SoftmaxTrainer.Sample] = []
        for (index, pair) in trainingPairs.enumerated() {
            if let vector = vectors[index] { trainingSamples.append(.init(features: vector, label: pair.1)) }
        }
        for (index, pair) in validationPairs.enumerated() {
            if let vector = vectors[trainingPairs.count + index] { validationSamples.append(.init(features: vector, label: pair.1)) }
        }

        log("Training the softmax head (\(trainingSamples.count) vectors, \(classes.count) classes, \(epochs) epochs)…")
        var trainer = SoftmaxTrainer()
        trainer.epochs = epochs
        let (model, outcome) = trainer.train(trainingSamples, validation: validationSamples, classCount: classes.count, log: log)
        return Result(model: model, classes: classes, outcome: outcome, trainingImages: trainingSamples.count, validationImages: validationSamples.count)
    }

    static func write(_ result: Result, summary: TrainingSet.Summary, version: String, weightsURL: URL, manifestDirectory: URL) throws {
        let model = result.model
        var bytes = Data()
        bytes.append(contentsOf: model.weights.withUnsafeBufferPointer { Data(buffer: $0) })
        bytes.append(contentsOf: model.biases.withUnsafeBufferPointer { Data(buffer: $0) })
        try bytes.write(to: weightsURL, options: .atomic)

        let manifest = Manifest(version: version, trainedAt: .now, featureVersion: FeatureExtractor.version, dimension: model.dimension,
                                classes: result.classes, featureMean: model.mean, featureStd: model.std,
                                trainingImages: result.trainingImages, validationImages: result.validationImages,
                                trainingAccuracy: result.outcome.trainingAccuracy, validationAccuracy: result.outcome.validationAccuracy,
                                sources: summary.sources)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: manifestDirectory, withIntermediateDirectories: true)
        try encoder.encode(manifest).write(to: manifestDirectory.appendingPathComponent("classifier.json"), options: .atomic)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
