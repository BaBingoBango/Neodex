import Foundation

/// A single Pokémon set in Pokémon Showdown's text format.
public struct ShowdownSet: Sendable, Hashable, Codable {
    /// Showdown species name, e.g. `"Charizard-Mega-X"`.
    public var species: String
    /// Nickname, when different from the species name.
    public var nickname: String?
    /// `"M"`, `"F"` or `nil`.
    public var gender: String?
    public var item: String?
    public var ability: String?
    public var level: Int = 100
    public var shiny: Bool = false
    public var happiness: Int?
    public var pokeball: String?
    public var hiddenPowerType: String?
    public var teraType: String?
    public var dynamaxLevel: Int?
    public var gigantamax: Bool = false
    public var evs: StatBlock = .zero
    public var ivs: StatBlock = .perfectIVs
    public var nature: String?
    public var moves: [String] = []

    public init(species: String) {
        self.species = species
    }
}

/// A team of up to six sets, optionally with a name and format.
public struct ShowdownTeam: Sendable, Hashable, Codable {
    public var name: String?
    /// Showdown format ID, e.g. `"gen9ou"`.
    public var format: String?
    public var sets: [ShowdownSet]

    public init(name: String? = nil, format: String? = nil, sets: [ShowdownSet]) {
        self.name = name
        self.format = format
        self.sets = sets
    }
}

/// Parses and produces Pokémon Showdown's human-readable team format.
public enum ShowdownTeamCodec {
    // MARK: - Export

    public static func export(_ team: ShowdownTeam, includeHeader: Bool = false) -> String {
        var out = ""
        if includeHeader, team.name != nil || team.format != nil {
            let format = team.format.map { "[\($0)] " } ?? ""
            out += "=== \(format)\(team.name ?? "Untitled") ===\n\n"
        }
        out += team.sets.map(export).joined(separator: "\n")
        return out
    }

    public static func export(_ set: ShowdownSet) -> String {
        var lines: [String] = []
        var first = set.nickname.map { nickname in
            nickname == set.species ? set.species : "\(nickname) (\(set.species))"
        } ?? set.species
        if set.gender == "M" { first += " (M)" }
        if set.gender == "F" { first += " (F)" }
        if let item = set.item, !item.isEmpty { first += " @ \(item)" }
        lines.append(first)
        if let ability = set.ability, !ability.isEmpty { lines.append("Ability: \(ability)") }
        if set.level != 100 { lines.append("Level: \(set.level)") }
        if set.shiny { lines.append("Shiny: Yes") }
        if let happiness = set.happiness, happiness != 255 { lines.append("Happiness: \(happiness)") }
        if let pokeball = set.pokeball, !pokeball.isEmpty { lines.append("Pokeball: \(pokeball)") }
        if let hiddenPower = set.hiddenPowerType { lines.append("Hidden Power: \(hiddenPower)") }
        if let dynamaxLevel = set.dynamaxLevel, dynamaxLevel != 10 { lines.append("Dynamax Level: \(dynamaxLevel)") }
        if set.gigantamax { lines.append("Gigantamax: Yes") }
        if let teraType = set.teraType, !teraType.isEmpty { lines.append("Tera Type: \(teraType)") }
        let evs = set.evs.nonZero.map { "\($0.value) \($0.stat.showdownAbbreviation)" }
        if !evs.isEmpty { lines.append("EVs: " + evs.joined(separator: " / ")) }
        if let nature = set.nature, !nature.isEmpty { lines.append("\(nature) Nature") }
        let ivs = set.ivs.values.filter { $0.value != 31 }.map { "\($0.value) \($0.stat.showdownAbbreviation)" }
        if !ivs.isEmpty { lines.append("IVs: " + ivs.joined(separator: " / ")) }
        for move in set.moves where !move.isEmpty {
            var name = move
            if name.hasPrefix("Hidden Power "), !name.contains("[") {
                name = "Hidden Power [" + name.dropFirst("Hidden Power ".count) + "]"
            }
            lines.append("- \(name)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Import

    /// Parses one or more teams. Text without `=== ... ===` headers yields a single unnamed team.
    public static func parseTeams(_ text: String) -> [ShowdownTeam] {
        var teams: [ShowdownTeam] = []
        var current = ShowdownTeam(sets: [])
        var hasHeader = false
        var block: [String] = []

        func flushBlock() {
            let trimmed = block.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !trimmed.isEmpty, let set = parseSet(lines: trimmed) {
                current.sets.append(set)
            }
            block = []
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("===") && line.hasSuffix("===") {
                flushBlock()
                if hasHeader || !current.sets.isEmpty { teams.append(current) }
                current = ShowdownTeam(sets: [])
                hasHeader = true
                let header = line.trimmingCharacters(in: CharacterSet(charactersIn: "= "))
                if header.hasPrefix("["), let close = header.firstIndex(of: "]") {
                    current.format = String(header[header.index(after: header.startIndex)..<close])
                    current.name = String(header[header.index(after: close)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    current.name = header
                }
                continue
            }
            if line.isEmpty {
                // A blank line ends a set, but only if the block already has a species line.
                if !block.isEmpty { flushBlock() }
                continue
            }
            // A new species line while a block is in progress means the previous set had no blank separator.
            if !block.isEmpty, isSpeciesLine(line), !isDetailLine(line) {
                flushBlock()
            }
            block.append(line)
        }
        flushBlock()
        if hasHeader || !current.sets.isEmpty { teams.append(current) }
        return teams
    }

    /// Parses text that contains a single set (or the first set of a team).
    public static func parseSet(_ text: String) -> ShowdownSet? {
        parseTeams(text).first?.sets.first
    }

    private static func isDetailLine(_ line: String) -> Bool {
        let prefixes = ["Ability:", "Level:", "Shiny:", "Happiness:", "Pokeball:", "Hidden Power:", "Tera Type:",
                        "Dynamax Level:", "Gigantamax:", "EVs:", "IVs:", "- ", "– ", "— "]
        if prefixes.contains(where: { line.hasPrefix($0) }) { return true }
        return line.hasSuffix(" Nature") || line == "Nature"
    }

    private static func isSpeciesLine(_ line: String) -> Bool {
        !isDetailLine(line)
    }

    private static func parseSet(lines: [String]) -> ShowdownSet? {
        guard let first = lines.first else { return nil }
        var set = parseSpeciesLine(first)
        guard !set.species.isEmpty else { return nil }

        for line in lines.dropFirst() {
            if let value = value(of: "Ability:", in: line) {
                set.ability = value
            } else if let value = value(of: "Level:", in: line) {
                set.level = Int(value) ?? 100
            } else if let value = value(of: "Shiny:", in: line) {
                set.shiny = value.lowercased().hasPrefix("y")
            } else if let value = value(of: "Happiness:", in: line) {
                set.happiness = Int(value)
            } else if let value = value(of: "Pokeball:", in: line) {
                set.pokeball = value
            } else if let value = value(of: "Hidden Power:", in: line) {
                set.hiddenPowerType = value
            } else if let value = value(of: "Tera Type:", in: line) {
                set.teraType = value
            } else if let value = value(of: "Dynamax Level:", in: line) {
                set.dynamaxLevel = Int(value)
            } else if let value = value(of: "Gigantamax:", in: line) {
                set.gigantamax = value.lowercased().hasPrefix("y")
            } else if let value = value(of: "EVs:", in: line) {
                set.evs = parseStatList(value, default: 0)
            } else if let value = value(of: "IVs:", in: line) {
                set.ivs = parseStatList(value, default: 31)
            } else if line.hasSuffix(" Nature") {
                set.nature = String(line.dropLast(" Nature".count)).trimmingCharacters(in: .whitespaces)
            } else if let move = moveName(from: line) {
                if set.moves.count < 4 { set.moves.append(move) }
            }
        }
        return set
    }

    private static func value(of prefix: String, in line: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func moveName(from line: String) -> String? {
        for marker in ["- ", "– ", "— "] where line.hasPrefix(marker) {
            var move = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            if move.hasPrefix("Hidden Power [") || move.hasPrefix("Hidden Power ") {
                let type = move.dropFirst("Hidden Power ".count).trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
                move = type.isEmpty ? "Hidden Power" : "Hidden Power \(type)"
            }
            return move.isEmpty ? nil : move
        }
        if line == "-" { return nil }
        return nil
    }

    private static func parseStatList(_ text: String, default defaultValue: Int) -> StatBlock {
        var block = StatBlock(repeating: defaultValue)
        for part in text.components(separatedBy: "/") {
            let pieces = part.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard pieces.count == 2, let value = Int(pieces[0]), let stat = Stat(parsing: String(pieces[1])) else { continue }
            block[stat] = value
        }
        return block
    }

    /// Parses `Nickname (Species) (M) @ Item` and all of its shorter variants.
    static func parseSpeciesLine(_ line: String) -> ShowdownSet {
        var rest = line
        var item: String?
        if let range = rest.range(of: " @ ") {
            item = String(rest[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            rest = String(rest[..<range.lowerBound])
        }
        rest = rest.trimmingCharacters(in: .whitespaces)
        var gender: String?
        if rest.hasSuffix(" (M)") { gender = "M"; rest = String(rest.dropLast(4)) }
        else if rest.hasSuffix(" (F)") { gender = "F"; rest = String(rest.dropLast(4)) }
        rest = rest.trimmingCharacters(in: .whitespaces)

        var species = rest
        var nickname: String?
        if rest.hasSuffix(")"), let open = rest.lastIndex(of: "(") {
            let inner = rest[rest.index(after: open)..<rest.index(before: rest.endIndex)]
            let outer = rest[..<open].trimmingCharacters(in: .whitespaces)
            if !outer.isEmpty {
                species = String(inner).trimmingCharacters(in: .whitespaces)
                nickname = outer
            }
        }
        var set = ShowdownSet(species: species)
        set.nickname = nickname
        set.gender = gender
        set.item = item?.isEmpty == false ? item : nil
        return set
    }
}
