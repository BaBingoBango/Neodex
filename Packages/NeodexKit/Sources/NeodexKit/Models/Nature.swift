import Foundation

/// One of the 25 Natures. Natures never change between games, so they are defined in code.
public struct Nature: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    /// Stat raised by 10%; `nil` for neutral natures.
    public var increased: Stat?
    /// Stat lowered by 10%; `nil` for neutral natures.
    public var decreased: Stat?

    public init(name: String, increased: Stat? = nil, decreased: Stat? = nil) {
        self.id = name.lowercased()
        self.name = name
        self.increased = increased
        self.decreased = decreased
    }

    /// `true` for the five natures with no stat effect.
    public var isNeutral: Bool { increased == nil || increased == decreased }

    /// The multiplier this nature applies to a stat (1.1, 0.9 or 1.0).
    public func modifier(for stat: Stat) -> Double {
        guard !isNeutral else { return 1 }
        if stat == increased { return 1.1 }
        if stat == decreased { return 0.9 }
        return 1
    }

    /// Berry flavor this nature likes (tied to the increased stat).
    public var likedFlavor: Flavor? { isNeutral ? nil : increased.flatMap(Flavor.init(stat:)) }

    /// Berry flavor this nature dislikes (tied to the decreased stat).
    public var dislikedFlavor: Flavor? { isNeutral ? nil : decreased.flatMap(Flavor.init(stat:)) }

    /// Short summary, e.g. `"+Atk −SpA"` or `"Neutral"`.
    public var summary: String {
        guard !isNeutral, let increased, let decreased else { return "Neutral" }
        return "+\(increased.showdownAbbreviation) −\(decreased.showdownAbbreviation)"
    }

    public static let hardy = Nature(name: "Hardy")
    public static let lonely = Nature(name: "Lonely", increased: .attack, decreased: .defense)
    public static let brave = Nature(name: "Brave", increased: .attack, decreased: .speed)
    public static let adamant = Nature(name: "Adamant", increased: .attack, decreased: .specialAttack)
    public static let naughty = Nature(name: "Naughty", increased: .attack, decreased: .specialDefense)
    public static let bold = Nature(name: "Bold", increased: .defense, decreased: .attack)
    public static let docile = Nature(name: "Docile")
    public static let relaxed = Nature(name: "Relaxed", increased: .defense, decreased: .speed)
    public static let impish = Nature(name: "Impish", increased: .defense, decreased: .specialAttack)
    public static let lax = Nature(name: "Lax", increased: .defense, decreased: .specialDefense)
    public static let timid = Nature(name: "Timid", increased: .speed, decreased: .attack)
    public static let hasty = Nature(name: "Hasty", increased: .speed, decreased: .defense)
    public static let serious = Nature(name: "Serious")
    public static let jolly = Nature(name: "Jolly", increased: .speed, decreased: .specialAttack)
    public static let naive = Nature(name: "Naive", increased: .speed, decreased: .specialDefense)
    public static let modest = Nature(name: "Modest", increased: .specialAttack, decreased: .attack)
    public static let mild = Nature(name: "Mild", increased: .specialAttack, decreased: .defense)
    public static let quiet = Nature(name: "Quiet", increased: .specialAttack, decreased: .speed)
    public static let bashful = Nature(name: "Bashful")
    public static let rash = Nature(name: "Rash", increased: .specialAttack, decreased: .specialDefense)
    public static let calm = Nature(name: "Calm", increased: .specialDefense, decreased: .attack)
    public static let gentle = Nature(name: "Gentle", increased: .specialDefense, decreased: .defense)
    public static let sassy = Nature(name: "Sassy", increased: .specialDefense, decreased: .speed)
    public static let careful = Nature(name: "Careful", increased: .specialDefense, decreased: .specialAttack)
    public static let quirky = Nature(name: "Quirky")

    /// All 25 natures in the in-game order.
    public static let all: [Nature] = [
        hardy, lonely, brave, adamant, naughty,
        bold, docile, relaxed, impish, lax,
        timid, hasty, serious, jolly, naive,
        modest, mild, quiet, bashful, rash,
        calm, gentle, sassy, careful, quirky,
    ]

    /// Case-insensitive lookup by name.
    public static func named(_ name: String) -> Nature? {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        return all.first { $0.id == key }
    }
}

/// Berry flavors, each tied to a stat.
public enum Flavor: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case spicy, dry, sweet, bitter, sour

    public var id: String { rawValue }
    public var name: String { rawValue.capitalized }

    /// The stat associated with the flavor.
    public var stat: Stat {
        switch self {
        case .spicy: .attack
        case .dry: .specialAttack
        case .sweet: .speed
        case .bitter: .specialDefense
        case .sour: .defense
        }
    }

    public init?(stat: Stat) {
        switch stat {
        case .attack: self = .spicy
        case .specialAttack: self = .dry
        case .speed: self = .sweet
        case .specialDefense: self = .bitter
        case .defense: self = .sour
        case .hp: return nil
        }
    }
}
