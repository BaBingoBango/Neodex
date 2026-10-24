//
//  TeamStore.swift
//  Scope Lens
//
//  Phase 3, m9: team management. The pilot's team, previously hardcoded in
//  three places, becomes data: a Showdown-paste import (the format VGC
//  players already have) parsed into a Codable Team, validated against the
//  engine's closed vocabulary (vocab.json), and fed to every surface —
//  scout report, reconciler seeds, live matchup, advisor context, and the
//  CLI harnesses.
//
//  SHARED-FILE RULE (Diagnostics compile this outside the app): Foundation
//  only — no SwiftUI, no Keychain, no sandbox assumptions. App-side
//  persistence lives in TeamManager.swift (app-only); CLIs load the
//  committed default paste at `Scope Lens/Resources/Team/default-team.txt`.
//

import Foundation

// MARK: - Model

/// One team slot, as a Showdown paste describes it. `moves`/`evs`/`ivs`
/// use canonical engine spellings once `canonicalized(with:)` has run.
/// EV/IV keys: hp/atk/def/spa/spd/spe.
nonisolated public struct TeamMember: Codable, Sendable, Equatable {
    public var species: String
    public var nickname: String?
    public var gender: String?          // "M" | "F"
    public var item: String?
    public var ability: String?
    public var moves: [String]
    public var nature: String?
    public var teraType: String?        // parsed + kept for paste round-trips ONLY —
                                        // Champions has no Terastallization
                                        // (pilot-confirmed 2026-07-09); never rendered/calc'd
    public var level: Int
    public var evs: [String: Int]?
    public var ivs: [String: Int]?
    public var shiny: Bool

    public init(species: String, nickname: String? = nil, gender: String? = nil,
                item: String? = nil, ability: String? = nil, moves: [String] = [],
                nature: String? = nil, teraType: String? = nil, level: Int = 50,
                evs: [String: Int]? = nil, ivs: [String: Int]? = nil, shiny: Bool = false) {
        self.species = species
        self.nickname = nickname
        self.gender = gender
        self.item = item
        self.ability = ability
        self.moves = moves
        self.nature = nature
        self.teraType = teraType
        self.level = level
        self.evs = evs
        self.ivs = ivs
        self.shiny = shiny
    }

    /// What Champions prints on plates and in narration for OUR side:
    /// the nickname when set, else the base-forme display name
    /// ("Rotom-Wash" → "Rotom").
    public func displayName(vocab: TeamVocab?) -> String {
        nickname ?? vocab?.speciesEntry(for: species)?.display ?? species
    }
}

nonisolated public struct Team: Codable, Sendable, Equatable {
    public var name: String?
    public var members: [TeamMember]

    public init(name: String? = nil, members: [TeamMember]) {
        self.name = name
        self.members = members
    }

    /// Repo-side default paste — the parity source for every CLI harness and
    /// the app's bundled fallback. Path is a documented convention (m9).
    public static let defaultPasteRepoPath = "Scope Lens/Resources/Team/default-team.txt"

    /// Load + parse + canonicalize the committed default team from a repo
    /// checkout (CLI harnesses; the sandboxed app uses its bundle instead).
    /// Returns the vocab too so callers derive display names for free.
    public static func fromRepoDefault(root: String)
        throws -> (team: Team, vocab: TeamVocab, issues: [TeamIssue]) {
        let paste = try String(contentsOfFile: "\(root)/\(defaultPasteRepoPath)", encoding: .utf8)
        let vocab = try TeamVocab(vocabJSON: Data(contentsOf: URL(
            fileURLWithPath: "\(root)/Engine/data/vocab.json")))
        let (team, issues) = ShowdownPaste.parse(paste).canonicalized(with: vocab)
        return (team, vocab, issues)
    }
}

// MARK: - Validation vocabulary

/// The closed legal vocabulary (species/moves/abilities/items) in matchable
/// form. Deliberately self-contained (parses vocab.json directly) so this
/// file never depends on BattleVocabulary's compile unit.
nonisolated public struct TeamVocab: Sendable {

    public struct SpeciesEntry: Sendable {
        public let name: String        // canonical: "Rotom-Wash"
        public let display: String     // plate/narration: "Rotom"
    }

    private let species: [String: SpeciesEntry]
    private let moves: [String: String]
    private let abilities: [String: String]
    private let items: [String: String]

    /// The 25 natures — a game constant, not in vocab.json.
    public static let natures: Set<String> = [
        "Adamant", "Bashful", "Bold", "Brave", "Calm", "Careful", "Docile",
        "Gentle", "Hardy", "Hasty", "Impish", "Jolly", "Lax", "Lonely",
        "Mild", "Modest", "Naive", "Naughty", "Quiet", "Quirky", "Rash",
        "Relaxed", "Sassy", "Serious", "Timid",
    ]

    public init(vocabJSON: Data) throws {
        struct Raw: Decodable {
            struct Species: Decodable { let name: String; let display: String }
            let species: [Species]
            let moves: [String]
            let abilities: [String]
            let items: [String]
        }
        let raw = try JSONDecoder().decode(Raw.self, from: vocabJSON)
        var sp: [String: SpeciesEntry] = [:]
        for s in raw.species {
            sp[Self.matchKey(s.name)] = SpeciesEntry(name: s.name, display: s.display)
        }
        species = sp
        moves = Dictionary(raw.moves.map { (Self.matchKey($0), $0) }, uniquingKeysWith: { a, _ in a })
        abilities = Dictionary(raw.abilities.map { (Self.matchKey($0), $0) }, uniquingKeysWith: { a, _ in a })
        items = Dictionary(raw.items.map { (Self.matchKey($0), $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Case/punctuation/apostrophe-insensitive key ("Farfetch’d" == "farfetchd").
    static func matchKey(_ s: String) -> String {
        s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init).joined()
    }

    public func speciesEntry(for raw: String) -> SpeciesEntry? { species[Self.matchKey(raw)] }
    public func canonicalMove(_ raw: String) -> String? { moves[Self.matchKey(raw)] }
    public func canonicalAbility(_ raw: String) -> String? { abilities[Self.matchKey(raw)] }
    public func canonicalItem(_ raw: String) -> String? { items[Self.matchKey(raw)] }
}

// MARK: - Issues

nonisolated public struct TeamIssue: Sendable, Equatable {
    public enum Severity: String, Sendable { case error, warning }
    public let severity: Severity
    public let memberIndex: Int?       // nil = team-level
    public let message: String

    public init(_ severity: Severity, member: Int? = nil, _ message: String) {
        self.severity = severity
        self.memberIndex = member
        self.message = message
    }
}

// MARK: - Showdown paste

nonisolated public enum ShowdownPaste {

    /// Parse Showdown export text into a Team. Pure text → model; unknown
    /// attribute lines are ignored (forward-compatible), name validation is
    /// `canonicalized(with:)`'s job.
    public static func parse(_ text: String) -> Team {
        var teamName: String?
        var members: [TeamMember] = []
        var current: TeamMember?

        func flush() {
            if let m = current, !m.species.isEmpty { members.append(m) }
            current = nil
        }

        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").split(
            separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty { flush(); continue }

            // `=== [gen9vgc2026] Folder/Team Name ===` team header
            if line.hasPrefix("==="), line.hasSuffix("===") {
                flush()
                var name = line.trimmingCharacters(in: CharacterSet(charactersIn: "= "))
                if let close = name.range(of: "]") {
                    name = String(name[close.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
                if let slash = name.range(of: "/", options: .backwards) {
                    name = String(name[slash.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
                if !name.isEmpty { teamName = name }
                continue
            }

            if var member = current {
                if line.hasPrefix("-") {
                    let move = line.dropFirst().trimmingCharacters(in: .whitespaces)
                    if !move.isEmpty { member.moves.append(move) }
                } else if let (key, value) = attribute(line) {
                    switch key {
                    case "ability": member.ability = value.isEmpty ? nil : value
                    case "level": member.level = Int(value) ?? member.level
                    case "shiny": member.shiny = value.lowercased() == "yes"
                    case "tera type": member.teraType = value.isEmpty ? nil : value
                    case "nature": member.nature = value.isEmpty ? nil : value
                    case "evs": member.evs = statLine(value)
                    case "ivs": member.ivs = statLine(value)
                    default: break // Happiness, Gigantamax, Hidden Power, …
                    }
                } else if line.hasSuffix(" Nature") {
                    member.nature = String(line.dropLast(" Nature".count))
                        .trimmingCharacters(in: .whitespaces)
                } else {
                    // A non-attribute, non-move line while inside a block:
                    // treat as the next member's header (missing blank line).
                    flush()
                    current = headerLine(line)
                    continue
                }
                current = member
            } else {
                current = headerLine(line)
            }
        }
        flush()
        return Team(name: teamName, members: members)
    }

    /// `Nickname (Species) (G) @ Item` in all its reduced forms.
    private static func headerLine(_ line: String) -> TeamMember {
        var rest = line
        var item: String?
        if let at = rest.range(of: " @ ") {
            item = String(rest[at.upperBound...]).trimmingCharacters(in: .whitespaces)
            rest = String(rest[..<at.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        var gender: String?
        for g in ["(M)", "(F)"] where rest.hasSuffix(g) {
            gender = String(g.dropFirst().dropLast())
            rest = String(rest.dropLast(g.count)).trimmingCharacters(in: .whitespaces)
        }
        var species = rest
        var nickname: String?
        if rest.hasSuffix(")"), let open = rest.range(of: "(", options: .backwards) {
            let inner = String(rest[rest.index(after: open.lowerBound)...].dropLast())
                .trimmingCharacters(in: .whitespaces)
            let prefix = String(rest[..<open.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !inner.isEmpty, !prefix.isEmpty {
                species = inner
                nickname = prefix
            }
        }
        return TeamMember(species: species, nickname: nickname, gender: gender,
                          item: (item?.isEmpty ?? true) ? nil : item)
    }

    /// `Key: Value` attribute lines (lowercased key), nil when not one.
    private static func attribute(_ line: String) -> (key: String, value: String)? {
        guard let colon = line.range(of: ":") else { return nil }
        let key = String(line[..<colon.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
        let value = String(line[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard ["ability", "level", "shiny", "tera type", "nature", "evs", "ivs",
               "happiness", "gigantamax", "hidden power", "dynamax level"].contains(key)
        else { return nil }
        return (key, value)
    }

    /// `4 HP / 252 SpA / 252 Spe` → canonical lowercase stat keys.
    private static func statLine(_ value: String) -> [String: Int]? {
        var out: [String: Int] = [:]
        for part in value.split(separator: "/") {
            let bits = part.trimmingCharacters(in: .whitespaces)
                .split(separator: " ", maxSplits: 1).map(String.init)
            guard bits.count == 2, let n = Int(bits[0]),
                  let stat = statKey(bits[1]) else { continue }
            out[stat] = n
        }
        return out.isEmpty ? nil : out
    }

    private static func statKey(_ raw: String) -> String? {
        switch TeamVocab.matchKey(raw) {
        case "hp": "hp"
        case "atk", "attack": "atk"
        case "def", "defense": "def"
        case "spa", "spatk", "spattack", "specialattack": "spa"
        case "spd", "spdef", "spdefense", "specialdefense": "spd"
        case "spe", "speed": "spe"
        default: nil
        }
    }

    /// Model → Showdown export text (Settings editor prefill; round-trip).
    public static func render(_ team: Team) -> String {
        var blocks: [String] = []
        for m in team.members {
            var L: [String] = []
            var head = m.nickname.map { "\($0) (\(m.species))" } ?? m.species
            if let g = m.gender { head += " (\(g))" }
            if let item = m.item { head += " @ \(item)" }
            L.append(head)
            if let a = m.ability { L.append("Ability: \(a)") }
            L.append("Level: \(m.level)")
            if m.shiny { L.append("Shiny: Yes") }
            if let t = m.teraType { L.append("Tera Type: \(t)") }
            if let evs = m.evs, !evs.isEmpty { L.append("EVs: \(statText(evs))") }
            if let n = m.nature { L.append("\(n) Nature") }
            if let ivs = m.ivs, !ivs.isEmpty { L.append("IVs: \(statText(ivs))") }
            L.append(contentsOf: m.moves.map { "- \($0)" })
            blocks.append(L.joined(separator: "\n"))
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }

    private static let statOrder = ["hp", "atk", "def", "spa", "spd", "spe"]
    private static let statLabels = ["hp": "HP", "atk": "Atk", "def": "Def",
                                     "spa": "SpA", "spd": "SpD", "spe": "Spe"]
    private static func statText(_ stats: [String: Int]) -> String {
        statOrder.compactMap { key in
            stats[key].map { "\($0) \(statLabels[key]!)" }
        }.joined(separator: " / ")
    }
}

// MARK: - Canonicalization + validation

// Explicitly nonisolated: the app target defaults to MainActor isolation
// (Xcode 26), which would otherwise capture these extension methods and
// break the shared-file rule for CLI harnesses and the capture loop.
nonisolated extension Team {

    /// Snap every name to the engine's canonical spelling and collect
    /// issues. Errors (unknown species, empty/oversized team) mean the team
    /// can't drive the engine; warnings (unknown item/move, EV overspend)
    /// degrade gracefully — the engine falls back per-field.
    public func canonicalized(with vocab: TeamVocab) -> (team: Team, issues: [TeamIssue]) {
        var issues: [TeamIssue] = []
        var team = self

        if team.members.isEmpty {
            issues.append(TeamIssue(.error, "no team members found in the paste"))
        }
        if team.members.count > 6 {
            issues.append(TeamIssue(.error,
                "\(team.members.count) members — a team is at most 6"))
        }

        var seenSpecies: Set<String> = []
        for i in team.members.indices {
            var m = team.members[i]

            if let entry = vocab.speciesEntry(for: m.species) {
                m.species = entry.name
            } else {
                issues.append(TeamIssue(.error, member: i,
                    "unknown species “\(m.species)”"))
            }
            if !seenSpecies.insert(m.species).inserted {
                issues.append(TeamIssue(.warning, member: i,
                    "duplicate species \(m.species)"))
            }

            if let item = m.item {
                if let canon = vocab.canonicalItem(item) { m.item = canon }
                else {
                    issues.append(TeamIssue(.warning, member: i,
                        "unknown item “\(item)” — kept as written"))
                }
            }
            if let ability = m.ability {
                if let canon = vocab.canonicalAbility(ability) { m.ability = canon }
                else {
                    issues.append(TeamIssue(.warning, member: i,
                        "unknown ability “\(ability)” — kept as written"))
                }
            }

            var moves: [String] = []
            for move in m.moves {
                if let canon = vocab.canonicalMove(move) { moves.append(canon) }
                else {
                    issues.append(TeamIssue(.warning, member: i,
                        "unknown move “\(move)” — kept as written"))
                    moves.append(move)
                }
            }
            if moves.count > 4 {
                issues.append(TeamIssue(.warning, member: i,
                    "\(moves.count) moves listed — keeping the first 4"))
                moves = Array(moves.prefix(4))
            }
            m.moves = moves

            if let nature = m.nature {
                let title = nature.prefix(1).uppercased() + nature.dropFirst().lowercased()
                if TeamVocab.natures.contains(title) { m.nature = title }
                else {
                    issues.append(TeamIssue(.warning, member: i,
                        "unknown nature “\(nature)” — ignoring it"))
                    m.nature = nil
                }
            }

            if var evs = m.evs {
                for (k, v) in evs where !(0...252).contains(v) {
                    issues.append(TeamIssue(.warning, member: i,
                        "EV \(k)=\(v) out of range — clamped"))
                    evs[k] = min(max(v, 0), 252)
                }
                let total = evs.values.reduce(0, +)
                if total > 510 {
                    issues.append(TeamIssue(.warning, member: i,
                        "EV total \(total) exceeds the usual 510 cap"))
                }
                m.evs = evs
            }
            if var ivs = m.ivs {
                for (k, v) in ivs where !(0...31).contains(v) {
                    issues.append(TeamIssue(.warning, member: i,
                        "IV \(k)=\(v) out of range — clamped"))
                    ivs[k] = min(max(v, 0), 31)
                }
                m.ivs = ivs
            }

            team.members[i] = m
        }
        return (team, issues)
    }

    /// Reconciler seeds: canonical species + what the screen will call it.
    public func teamSeeds(vocab: TeamVocab?) -> [(species: String, display: String)] {
        members.map { ($0.species, $0.displayName(vocab: vocab)) }
    }
}
