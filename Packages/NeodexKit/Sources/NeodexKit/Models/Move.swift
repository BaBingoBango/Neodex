import Foundation

/// A move a Pokémon can use in battle.
public struct Move: Codable, Sendable, Hashable, Identifiable {
    /// Showdown ID, e.g. `"flamethrower"`.
    public var id: String
    public var name: String
    public var type: PokemonType
    public var category: MoveCategory
    /// Base power; `0` for status moves and moves with variable power.
    public var basePower: Int
    /// Accuracy percentage; `nil` for moves that never miss.
    public var accuracy: Int?
    public var pp: Int
    public var priority: Int
    /// Showdown target code, e.g. `"normal"`, `"self"`, `"allAdjacentFoes"`.
    public var target: String
    /// Showdown move flags, e.g. `"contact"`, `"sound"`, `"protect"`.
    public var flags: [String]
    /// In-game description from the most recent game.
    public var description: String?
    /// Short competitive summary from Showdown, e.g. `"10% chance to burn the target."`.
    public var shortDescription: String?
    /// Full competitive description from Showdown.
    public var longDescription: String?
    /// Chance of the secondary effect, when there is one.
    public var effectChance: Int?
    /// Technical Machine number in the current generation, when teachable by TM.
    public var tmNumber: Int?
    public var generation: Int
    public var availability: Availability
    public var kind: MoveKind
    /// Critical-hit stage bonus (1 = raised crit ratio).
    public var critRatio: Int?
    /// Fraction of damage healed, e.g. `[1, 2]` for Drain Punch.
    public var drain: [Int]?
    /// Fraction of damage taken as recoil, e.g. `[33, 100]`.
    public var recoil: [Int]?
    /// `[min, max]` hits for multi-hit moves.
    public var multiHit: [Int]?
    public var isOneHitKO: Bool
    /// Stat changes applied to the user or target by the move's primary effect.
    public var statChanges: [StatChange]?

    public init(id: String, name: String, type: PokemonType, category: MoveCategory, basePower: Int, accuracy: Int?,
                pp: Int, priority: Int, target: String, flags: [String], description: String? = nil,
                shortDescription: String? = nil, longDescription: String? = nil, effectChance: Int? = nil,
                tmNumber: Int? = nil, generation: Int, availability: Availability = .current, kind: MoveKind = .standard,
                critRatio: Int? = nil, drain: [Int]? = nil, recoil: [Int]? = nil, multiHit: [Int]? = nil,
                isOneHitKO: Bool = false, statChanges: [StatChange]? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.category = category
        self.basePower = basePower
        self.accuracy = accuracy
        self.pp = pp
        self.priority = priority
        self.target = target
        self.flags = flags
        self.description = description
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.effectChance = effectChance
        self.tmNumber = tmNumber
        self.generation = generation
        self.availability = availability
        self.kind = kind
        self.critRatio = critRatio
        self.drain = drain
        self.recoil = recoil
        self.multiHit = multiHit
        self.isOneHitKO = isOneHitKO
        self.statChanges = statChanges
    }

    /// Maximum PP after three PP Ups (the in-game cap of 8/5 of base PP).
    public var maxPP: Int { pp * 8 / 5 }

    /// `true` if the move makes contact with the target.
    public var makesContact: Bool { flags.contains("contact") }

    /// Best available description, preferring the in-game text.
    public var bestDescription: String? { description ?? longDescription ?? shortDescription }

    /// `"—"` when the move has no base power.
    public var basePowerText: String { basePower > 0 ? String(basePower) : "—" }

    /// `"—"` when the move cannot miss.
    public var accuracyText: String { accuracy.map { "\($0)%" } ?? "—" }

    /// Zero-padded TM label, e.g. `"TM125"`.
    public var tmLabel: String? { tmNumber.map { "TM" + String(format: "%03d", $0) } }

    /// Human-readable target description.
    public var targetDescription: String {
        switch target {
        case "normal": "One adjacent Pokémon"
        case "self": "User"
        case "adjacentAlly": "One adjacent ally"
        case "adjacentAllyOrSelf": "User or adjacent ally"
        case "adjacentFoe": "One adjacent foe"
        case "allAdjacentFoes": "All adjacent foes"
        case "allAdjacent": "All adjacent Pokémon"
        case "allies": "All allies"
        case "allySide": "User's side"
        case "allyTeam": "User's team"
        case "foeSide": "Foes' side"
        case "all": "Entire field"
        case "any": "Any Pokémon"
        case "randomNormal": "Random adjacent foe"
        case "scripted": "Last attacker"
        default: target
        }
    }
}

/// Physical, special or status.
public enum MoveCategory: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case physical = "Physical"
    case special = "Special"
    case status = "Status"

    public var id: String { rawValue }
    public var name: String { rawValue }
}

/// Distinguishes regular moves from mechanic-specific ones.
public enum MoveKind: String, Codable, Sendable, Hashable, CaseIterable {
    case standard
    case zMove
    case maxMove
    case gigantamaxMove

    public var name: String {
        switch self {
        case .standard: "Move"
        case .zMove: "Z-Move"
        case .maxMove: "Max Move"
        case .gigantamaxMove: "G-Max Move"
        }
    }
}

/// A stat stage change caused by a move.
public struct StatChange: Codable, Sendable, Hashable {
    public var stat: Stat
    /// Positive raises, negative lowers (in stages).
    public var stages: Int
    /// `true` when the change applies to the user, `false` for the target.
    public var affectsUser: Bool

    public init(stat: Stat, stages: Int, affectsUser: Bool) {
        self.stat = stat
        self.stages = stages
        self.affectsUser = affectsUser
    }
}
