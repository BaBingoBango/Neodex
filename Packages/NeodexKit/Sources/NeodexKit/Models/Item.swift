import Foundation

/// A held item or other battle-relevant item.
public struct Item: Codable, Sendable, Hashable, Identifiable {
    /// Showdown ID, e.g. `"leftovers"`.
    public var id: String
    public var name: String
    /// In-game description from the most recent game.
    public var description: String?
    /// Short competitive summary from Showdown.
    public var shortDescription: String?
    public var category: ItemCategory
    public var generation: Int
    public var availability: Availability
    /// Base power when thrown with Fling.
    public var flingPower: Int?
    /// Type and power of Natural Gift for Berries.
    public var naturalGift: NaturalGift?
    /// Name of the Pokémon this Mega Stone evolves.
    public var megaEvolves: String?
    /// Names of the Pokémon that can use this signature item.
    public var users: [String]?
    /// Type of Z-Move, Plate, Memory or Drive this item is tied to.
    public var associatedType: PokemonType?
    /// Index into Showdown's item sprite sheet.
    public var spriteIndex: Int?

    public init(id: String, name: String, description: String? = nil, shortDescription: String? = nil,
                category: ItemCategory, generation: Int, availability: Availability = .current, flingPower: Int? = nil,
                naturalGift: NaturalGift? = nil, megaEvolves: String? = nil, users: [String]? = nil,
                associatedType: PokemonType? = nil, spriteIndex: Int? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.shortDescription = shortDescription
        self.category = category
        self.generation = generation
        self.availability = availability
        self.flingPower = flingPower
        self.naturalGift = naturalGift
        self.megaEvolves = megaEvolves
        self.users = users
        self.associatedType = associatedType
        self.spriteIndex = spriteIndex
    }

    /// Best available description, preferring the in-game text.
    public var bestDescription: String? { description ?? shortDescription }
}

/// Broad grouping of items for browsing and filtering.
public enum ItemCategory: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case berry
    case megaStone
    case zCrystal
    case choice
    case plate
    case memory
    case drive
    case gem
    case pokeBall
    case evolution
    case signature
    case teraShard
    case held

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .berry: "Berries"
        case .megaStone: "Mega Stones"
        case .zCrystal: "Z-Crystals"
        case .choice: "Choice Items"
        case .plate: "Plates"
        case .memory: "Memories"
        case .drive: "Drives"
        case .gem: "Gems"
        case .pokeBall: "Poké Balls"
        case .evolution: "Evolution Items"
        case .signature: "Signature Items"
        case .teraShard: "Tera Shards"
        case .held: "Held Items"
        }
    }
}

/// Natural Gift parameters for a Berry.
public struct NaturalGift: Codable, Sendable, Hashable {
    public var basePower: Int
    public var type: PokemonType

    public init(basePower: Int, type: PokemonType) {
        self.basePower = basePower
        self.type = type
    }
}
