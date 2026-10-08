import Foundation

/// Provenance information written by the data pipeline alongside the generated JSON.
public struct DataManifest: Codable, Sendable, Hashable {
    public var generatedAt: Date
    /// Schema version of the generated files; bump when the models change incompatibly.
    public var schemaVersion: Int
    public var counts: Counts
    public var sources: [DataSource]

    public init(generatedAt: Date, schemaVersion: Int, counts: Counts, sources: [DataSource]) {
        self.generatedAt = generatedAt
        self.schemaVersion = schemaVersion
        self.counts = counts
        self.sources = sources
    }

    public struct Counts: Codable, Sendable, Hashable {
        public var pokemon: Int
        public var species: Int
        public var moves: Int
        public var abilities: Int
        public var items: Int
        public var learnsets: Int

        public init(pokemon: Int, species: Int, moves: Int, abilities: Int, items: Int, learnsets: Int) {
            self.pokemon = pokemon
            self.species = species
            self.moves = moves
            self.abilities = abilities
            self.items = items
            self.learnsets = learnsets
        }
    }

    public struct DataSource: Codable, Sendable, Hashable, Identifiable {
        public var name: String
        public var url: String
        public var license: String

        public init(name: String, url: String, license: String) {
            self.name = name
            self.url = url
            self.license = license
        }

        public var id: String { name }
    }

    /// The schema version the current models expect.
    public static let currentSchemaVersion = 1
}
