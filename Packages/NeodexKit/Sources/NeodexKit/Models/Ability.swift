import Foundation

/// A Pokémon Ability.
public struct Ability: Codable, Sendable, Hashable, Identifiable {
    /// Showdown ID, e.g. `"intimidate"`.
    public var id: String
    public var name: String
    /// In-game description from the most recent game.
    public var description: String?
    /// Short competitive summary from Showdown.
    public var shortDescription: String?
    /// Full competitive description from Showdown.
    public var longDescription: String?
    /// Showdown's competitive usefulness rating from -1 to 5.
    public var rating: Double?
    public var generation: Int
    public var availability: Availability

    public init(id: String, name: String, description: String? = nil, shortDescription: String? = nil,
                longDescription: String? = nil, rating: Double? = nil, generation: Int, availability: Availability = .current) {
        self.id = id
        self.name = name
        self.description = description
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.rating = rating
        self.generation = generation
        self.availability = availability
    }

    /// Best available description, preferring the in-game text.
    public var bestDescription: String? { description ?? longDescription ?? shortDescription }
}
