import Foundation

/// Smogon's Generation 9 singles ladder, from most to least permissive.
public enum SmogonFormat: String, CaseIterable, Sendable, Hashable, Identifiable {
    case anythingGoes = "gen9ag"
    case ubers = "gen9ubers"
    case ou = "gen9ou"
    case uu = "gen9uu"
    case ru = "gen9ru"
    case nu = "gen9nu"
    case pu = "gen9pu"
    case zu = "gen9zu"
    case lc = "gen9lc"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .anythingGoes: "Gen 9 Anything Goes"
        case .ubers: "Gen 9 Ubers"
        case .ou: "Gen 9 OU"
        case .uu: "Gen 9 UU"
        case .ru: "Gen 9 RU"
        case .nu: "Gen 9 NU"
        case .pu: "Gen 9 PU"
        case .zu: "Gen 9 ZU"
        case .lc: "Gen 9 Little Cup"
        }
    }

    /// Resolves a Showdown format ID such as `"gen9ou"` (case-insensitive, spaces ignored).
    public init?(formatID: String) {
        let key = formatID.lowercased().replacingOccurrences(of: " ", with: "")
        guard let format = SmogonFormat.allCases.first(where: { $0.rawValue == key }) else { return nil }
        self = format
    }

    /// The least permissive tier allowed in this format; everything ranked below it is also allowed.
    var highestAllowedTier: TierRank {
        switch self {
        case .anythingGoes: .ag
        case .ubers: .uber
        case .ou: .ou
        case .uu: .uu
        case .ru: .ru
        case .nu: .nu
        case .pu: .pu
        case .zu: .zu
        case .lc: .lc
        }
    }

    /// Standard clauses apply to every tier except Anything Goes.
    public var usesStandardClauses: Bool { self != .anythingGoes }
}

/// Showdown's tier strings, ranked from most to least restricted.
enum TierRank: Int, Comparable {
    case ag, uber, ou, uubl, uu, rubl, ru, nubl, nu, publ, pu, zubl, zu, nfe, lc

    static func < (lhs: TierRank, rhs: TierRank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Parses `"OU"`, `"(PU)"`, `"UUBL"`, …; returns `nil` for `"Illegal"`, CAP and unknown tiers.
    init?(showdownTier: String) {
        let cleaned = showdownTier.trimmingCharacters(in: CharacterSet(charactersIn: "() ")).uppercased()
        switch cleaned {
        case "AG": self = .ag
        case "UBER", "UBERS": self = .uber
        case "OU": self = .ou
        case "UUBL": self = .uubl
        case "UU": self = .uu
        case "RUBL": self = .rubl
        case "RU": self = .ru
        case "NUBL": self = .nubl
        case "NU": self = .nu
        case "PUBL": self = .publ
        case "PU": self = .pu
        case "ZUBL": self = .zubl
        case "ZU": self = .zu
        case "NFE": self = .nfe
        case "LC": self = .lc
        default: return nil
        }
    }
}

/// One set as the legality checker sees it.
public struct LegalitySet: Sendable, Hashable, Identifiable {
    public var id: String
    public var pokemonID: String
    public var abilityID: String?
    public var itemID: String?
    public var moveIDs: [String]
    public var level: Int

    public init(id: String, pokemonID: String, abilityID: String? = nil, itemID: String? = nil, moveIDs: [String] = [], level: Int = 100) {
        self.id = id
        self.pokemonID = pokemonID
        self.abilityID = abilityID
        self.itemID = itemID
        self.moveIDs = moveIDs
        self.level = level
    }
}

/// A problem with a set or team under a format's rules.
public struct LegalityIssue: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable { case pokemon, ability, item, move, team }

    /// The set the issue belongs to; `nil` for team-wide issues.
    public var setID: String?
    public var kind: Kind
    public var message: String

    public init(setID: String?, kind: Kind, message: String) {
        self.setID = setID
        self.kind = kind
        self.message = message
    }

    public var id: String { "\(setID ?? "team")|\(kind.rawValue)|\(message)" }
}

/// Checks teams against Smogon's Generation 9 singles formats using Showdown's tier data.
public enum FormatLegality {
    static let evasionMoves: Set<String> = ["doubleteam", "minimize"]
    static let ohkoMoves: Set<String> = ["fissure", "guillotine", "horndrill", "sheercold"]
    static let evasionItems: Set<String> = ["brightpowder", "laxincense"]
    static let bannedInStandardTiers: Set<String> = ["batonpass"]
    static let bannedAbilitiesInStandardTiers: Set<String> = ["moody", "shadowtag", "arenatrap"]

    /// Every issue with the team, in team order. An empty result means the team is legal.
    public static func check(_ sets: [LegalitySet], format: SmogonFormat, database: PokedexDatabase) -> [LegalityIssue] {
        var issues: [LegalityIssue] = []
        var speciesSeen: [String: String] = [:]

        for set in sets {
            guard let pokemon = database.pokemon(id: set.pokemonID) else {
                issues.append(LegalityIssue(setID: set.id, kind: .pokemon, message: "Unknown Pokémon."))
                continue
            }
            issues.append(contentsOf: check(pokemon: pokemon, format: format, setID: set.id))

            if format.usesStandardClauses {
                if let previous = speciesSeen[pokemon.speciesID] {
                    issues.append(LegalityIssue(setID: set.id, kind: .team, message: "Species Clause: \(pokemon.displayName) is already on the team as \(previous)."))
                } else {
                    speciesSeen[pokemon.speciesID] = pokemon.displayName
                }
            }

            if let abilityID = set.abilityID {
                if !pokemon.abilities.contains(abilityID) {
                    let name = database.ability(id: abilityID)?.name ?? abilityID
                    issues.append(LegalityIssue(setID: set.id, kind: .ability, message: "\(pokemon.displayName) can't have \(name)."))
                } else if let ability = database.ability(id: abilityID), ability.availability != .current {
                    issues.append(LegalityIssue(setID: set.id, kind: .ability, message: "\(ability.name) isn't available in the current games."))
                } else if format.usesStandardClauses, bannedAbilitiesInStandardTiers.contains(abilityID), format != .ubers || abilityID == "moody" {
                    let name = database.ability(id: abilityID)?.name ?? abilityID
                    issues.append(LegalityIssue(setID: set.id, kind: .ability, message: "\(name) is banned in \(format.name)."))
                }
            }

            if let itemID = set.itemID, let item = database.item(id: itemID) {
                if item.availability != .current {
                    issues.append(LegalityIssue(setID: set.id, kind: .item, message: "\(item.name) isn't available in the current games."))
                } else if format.usesStandardClauses, evasionItems.contains(itemID) {
                    issues.append(LegalityIssue(setID: set.id, kind: .item, message: "Evasion Items Clause: \(item.name) is banned."))
                }
            }

            for moveID in set.moveIDs {
                guard let move = database.move(id: moveID) else { continue }
                if !database.canLearn(pokemon, moveID: moveID) {
                    issues.append(LegalityIssue(setID: set.id, kind: .move, message: "\(pokemon.displayName) can't learn \(move.name)."))
                } else if move.availability != .current {
                    issues.append(LegalityIssue(setID: set.id, kind: .move, message: "\(move.name) isn't available in the current games."))
                } else if format.usesStandardClauses {
                    if evasionMoves.contains(moveID) {
                        issues.append(LegalityIssue(setID: set.id, kind: .move, message: "Evasion Moves Clause: \(move.name) is banned."))
                    } else if ohkoMoves.contains(moveID) {
                        issues.append(LegalityIssue(setID: set.id, kind: .move, message: "OHKO Clause: \(move.name) is banned."))
                    } else if bannedInStandardTiers.contains(moveID) {
                        issues.append(LegalityIssue(setID: set.id, kind: .move, message: "\(move.name) is banned in \(format.name)."))
                    }
                }
            }

            if format == .lc, set.level != 5 {
                issues.append(LegalityIssue(setID: set.id, kind: .pokemon, message: "Little Cup Pokémon must be level 5."))
            }
        }
        return issues
    }

    /// Whether a Pokémon itself may be used in a format, ignoring its set.
    public static func check(pokemon: Pokemon, format: SmogonFormat) -> [LegalityIssue] {
        if pokemon.availability != .current {
            return [LegalityIssue(setID: nil, kind: .pokemon, message: "\(pokemon.displayName) isn't available in the current games.")]
        }
        guard let tier = pokemon.tier, let rank = TierRank(showdownTier: tier) else {
            if pokemon.tier == "Illegal" {
                return [LegalityIssue(setID: nil, kind: .pokemon, message: "\(pokemon.displayName) isn't obtainable in Generation 9.")]
            }
            return []
        }
        if format == .lc {
            return rank == .lc ? [] : [LegalityIssue(setID: nil, kind: .pokemon, message: "\(pokemon.displayName) isn't a Little Cup Pokémon.")]
        }
        if rank < format.highestAllowedTier {
            let tierName = tier.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            return [LegalityIssue(setID: nil, kind: .pokemon, message: "\(pokemon.displayName) is \(tierName), which is banned from \(format.name).")]
        }
        return []
    }

    /// Issues for one Pokémon, stamped with the set ID.
    static func check(pokemon: Pokemon, format: SmogonFormat, setID: String) -> [LegalityIssue] {
        check(pokemon: pokemon, format: format).map { LegalityIssue(setID: setID, kind: $0.kind, message: $0.message) }
    }
}

extension FormatLegality {
    /// The formats a Pokémon is legal in, most permissive first.
    public static func legalFormats(for pokemon: Pokemon) -> [SmogonFormat] {
        SmogonFormat.allCases.filter { check(pokemon: pokemon, format: $0).isEmpty }
    }
}
