import Foundation

/// What the pipeline recorded when it trained the scanner's classifier (`Data/classifier.json`):
/// the class list, the feature standardisation and how well the model did.
nonisolated struct ClassifierManifest: Decodable, Sendable {
    var version: String
    var trainedAt: Date
    var featureVersion: String
    var dimension: Int
    /// Pokémon IDs in the order of the weight matrix's columns.
    var classes: [String]
    var featureMean: [Float]
    var featureStd: [Float]
    var trainingImages: Int
    var validationImages: Int
    var trainingAccuracy: Double
    var validationAccuracy: Double?
    var sources: [String: Int]

    static func url(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "classifier", withExtension: "json", subdirectory: "Data")
            ?? bundle.url(forResource: "classifier", withExtension: "json")
    }

    static func load(from bundle: Bundle = .main) -> ClassifierManifest? {
        guard let url = url(in: bundle), let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ClassifierManifest.self, from: data)
    }
}
