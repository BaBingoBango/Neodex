import Foundation

/// One of the six battle stats, in the canonical in-game order.
///
/// Raw values match Pokémon Showdown's stat identifiers so the same enum
/// can be used for JSON data, team import/export, and usage statistics.
public enum Stat: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case hp
    case attack = "atk"
    case defense = "def"
    case specialAttack = "spa"
    case specialDefense = "spd"
    case speed = "spe"

    public var id: String { rawValue }

    /// Full name, e.g. "Special Attack".
    public var name: String {
        switch self {
        case .hp: "HP"
        case .attack: "Attack"
        case .defense: "Defense"
        case .specialAttack: "Special Attack"
        case .specialDefense: "Special Defense"
        case .speed: "Speed"
        }
    }

    /// In-game abbreviation, e.g. "Sp. Atk".
    public var shortName: String {
        switch self {
        case .hp: "HP"
        case .attack: "Attack"
        case .defense: "Defense"
        case .specialAttack: "Sp. Atk"
        case .specialDefense: "Sp. Def"
        case .speed: "Speed"
        }
    }

    /// Showdown's three-letter abbreviation used in exported sets, e.g. "SpA".
    public var showdownAbbreviation: String {
        switch self {
        case .hp: "HP"
        case .attack: "Atk"
        case .defense: "Def"
        case .specialAttack: "SpA"
        case .specialDefense: "SpD"
        case .speed: "Spe"
        }
    }

    /// Parses any common spelling: "HP", "Atk", "Sp. Atk", "spa", "Special Attack", …
    public init?(parsing text: String) {
        let key = text.lowercased().replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "")
        switch key {
        case "hp", "hitpoints": self = .hp
        case "atk", "attack": self = .attack
        case "def", "defense", "defence": self = .defense
        case "spa", "spatk", "specialattack", "spattack": self = .specialAttack
        case "spd", "spdef", "specialdefense", "spdefense", "specialdefence": self = .specialDefense
        case "spe", "speed", "spd_", "spee": self = .speed
        default: return nil
        }
    }
}

/// A full set of six stat values (base stats, EVs, IVs, or calculated stats).
public struct StatBlock: Codable, Sendable, Hashable {
    public var hp: Int
    public var attack: Int
    public var defense: Int
    public var specialAttack: Int
    public var specialDefense: Int
    public var speed: Int

    enum CodingKeys: String, CodingKey {
        case hp
        case attack = "atk"
        case defense = "def"
        case specialAttack = "spa"
        case specialDefense = "spd"
        case speed = "spe"
    }

    public init(hp: Int = 0, attack: Int = 0, defense: Int = 0, specialAttack: Int = 0, specialDefense: Int = 0, speed: Int = 0) {
        self.hp = hp
        self.attack = attack
        self.defense = defense
        self.specialAttack = specialAttack
        self.specialDefense = specialDefense
        self.speed = speed
    }

    /// A block with every stat set to the same value (e.g. 31 for perfect IVs).
    public init(repeating value: Int) {
        self.init(hp: value, attack: value, defense: value, specialAttack: value, specialDefense: value, speed: value)
    }

    public static let zero = StatBlock()
    public static let perfectIVs = StatBlock(repeating: 31)

    public subscript(stat: Stat) -> Int {
        get {
            switch stat {
            case .hp: hp
            case .attack: attack
            case .defense: defense
            case .specialAttack: specialAttack
            case .specialDefense: specialDefense
            case .speed: speed
            }
        }
        set {
            switch stat {
            case .hp: hp = newValue
            case .attack: attack = newValue
            case .defense: defense = newValue
            case .specialAttack: specialAttack = newValue
            case .specialDefense: specialDefense = newValue
            case .speed: speed = newValue
            }
        }
    }

    /// Sum of all six values (the "base stat total").
    public var total: Int { hp + attack + defense + specialAttack + specialDefense + speed }

    /// The highest single value.
    public var maximum: Int { Stat.allCases.map { self[$0] }.max() ?? 0 }

    /// Stats in canonical order as `(stat, value)` pairs.
    public var values: [(stat: Stat, value: Int)] { Stat.allCases.map { ($0, self[$0]) } }

    /// Stats with a non-zero value, in canonical order.
    public var nonZero: [(stat: Stat, value: Int)] { values.filter { $0.value != 0 } }
}
