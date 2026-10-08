import Foundation

/// How a Pokémon learns a move.
public enum LearnMethod: String, Codable, Sendable, Hashable, CaseIterable, Comparable {
    case levelUp = "L"
    case machine = "M"
    case egg = "E"
    case tutor = "T"
    case event = "S"
    case reminder = "R"
    case virtualConsole = "V"
    case dreamWorld = "D"

    public var name: String {
        switch self {
        case .levelUp: "Level Up"
        case .machine: "TM"
        case .egg: "Egg Move"
        case .tutor: "Move Tutor"
        case .event: "Event"
        case .reminder: "Move Reminder"
        case .virtualConsole: "Virtual Console"
        case .dreamWorld: "Dream World"
        }
    }

    private var sortOrder: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    public static func < (lhs: LearnMethod, rhs: LearnMethod) -> Bool { lhs.sortOrder < rhs.sortOrder }
}

/// A single way of learning a move, encoded compactly as Showdown does (`"9L24"`, `"9M"`, `"8E"`).
public struct LearnSource: Codable, Sendable, Hashable, Comparable, CustomStringConvertible {
    public var generation: Int
    public var method: LearnMethod
    /// Level for level-up moves (`0` or `1` means known from the start / via Move Reminder).
    public var level: Int?

    public init(generation: Int, method: LearnMethod, level: Int? = nil) {
        self.generation = generation
        self.method = method
        self.level = level
    }

    /// Parses a Showdown learnset code such as `"9L24"`, `"9M"` or `"7S3"`.
    public init?(code: String) {
        guard code.count >= 2, let generation = code.first?.wholeNumberValue,
              let method = LearnMethod(rawValue: String(code[code.index(after: code.startIndex)])) else { return nil }
        self.generation = generation
        self.method = method
        let rest = code.dropFirst(2)
        if method == .levelUp {
            level = Int(rest) ?? 0
        } else {
            level = nil
        }
    }

    /// The Showdown code for this source.
    public var code: String {
        switch method {
        case .levelUp: "\(generation)L\(level ?? 0)"
        default: "\(generation)\(method.rawValue)"
        }
    }

    public var description: String { code }

    /// Short label such as `"Lv. 24"`, `"TM"`, `"Egg"`.
    public var label: String {
        switch method {
        case .levelUp:
            if let level, level > 1 { return "Lv. \(level)" }
            return "Start"
        case .machine: return "TM"
        case .egg: return "Egg"
        case .tutor: return "Tutor"
        case .event: return "Event"
        case .reminder: return "Reminder"
        case .virtualConsole: return "Transfer"
        case .dreamWorld: return "Dream World"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(String.self)
        guard let parsed = LearnSource(code: code) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid learnset code \(code)")
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code)
    }

    public static func < (lhs: LearnSource, rhs: LearnSource) -> Bool {
        if lhs.method != rhs.method { return lhs.method < rhs.method }
        if lhs.method == .levelUp { return (lhs.level ?? 0) < (rhs.level ?? 0) }
        return lhs.generation > rhs.generation
    }
}

/// Every move a Pokémon can learn, keyed by move ID, with the ways it learns each one.
public struct Learnset: Codable, Sendable, Hashable {
    public var moves: [String: [LearnSource]]

    public init(moves: [String: [LearnSource]]) {
        self.moves = moves
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        moves = try container.decode([String: [LearnSource]].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(moves)
    }
}

/// A move resolved against a Pokémon's learnset.
public struct LearnedMove: Sendable, Hashable, Identifiable {
    public var move: Move
    /// Sources sorted by method, then level.
    public var sources: [LearnSource]

    public init(move: Move, sources: [LearnSource]) {
        self.move = move
        self.sources = sources.sorted()
    }

    public var id: String { move.id }

    public var methods: [LearnMethod] { Array(Set(sources.map(\.method))).sorted() }

    /// The lowest level at which the move is learned by levelling up, if any.
    public func levelUpLevel() -> Int? {
        sources.filter { $0.method == .levelUp }.compactMap(\.level).min()
    }

    public func learned(by method: LearnMethod) -> Bool { sources.contains { $0.method == method } }
}
