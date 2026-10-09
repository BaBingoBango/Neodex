import Foundation

/// A Pokémon species or an alternate form of one (Mega, Gigantamax, regional variant, …).
///
/// Identifiers are Pokémon Showdown IDs (`"charizardmegax"`), which makes team import/export
/// and usage-statistics lookups trivial. Species-level data (Pokédex entries, catch rate, …)
/// is shared by all forms of a species.
public struct Pokemon: Codable, Sendable, Hashable, Identifiable {
    /// Showdown ID, e.g. `"charizardmegax"`.
    public var id: String
    /// Showdown name, e.g. `"Charizard-Mega-X"`. Used in team import/export.
    public var name: String
    /// Human-friendly name, e.g. `"Mega Charizard X"`.
    public var displayName: String
    /// National Pokédex number shared by all forms of the species.
    public var nationalDexNumber: Int
    /// Generation the form was introduced in.
    public var generation: Int
    /// ID of the base form when this is an alternate form; `nil` for the base form.
    public var baseSpeciesID: String?
    /// Showdown form suffix, e.g. `"Mega-X"`, `"Alola"`.
    public var formName: String?
    /// Category of alternate form, if any.
    public var formKind: FormKind?
    /// Whether the form is only reachable in battle (Megas, Zen Mode, …).
    public var isBattleOnly: Bool
    /// ID of the form this one transforms from in battle, when applicable.
    public var changesFrom: String?
    /// Item IDs required to use this form (Mega Stones, Primal orbs, Ogerpon masks).
    public var requiredItems: [String]?
    /// Name of the G-Max move when this form can Gigantamax.
    public var gigantamaxMove: String?

    public var types: [PokemonType]
    public var abilities: AbilitySet
    public var baseStats: StatBlock
    /// Height in metres.
    public var height: Double
    /// Weight in kilograms.
    public var weight: Double
    /// Fraction of the species that is male (0…1); `nil` means genderless.
    public var maleRatio: Double?
    /// Species category, e.g. `"Flame"` for the Flame Pokémon.
    public var genus: String?
    public var color: String?
    public var eggGroups: [String]
    public var catchRate: Int?
    public var baseFriendship: Int?
    public var baseExperience: Int?
    public var growthRate: String?
    public var hatchCycles: Int?
    public var evYield: StatBlock?
    /// In-game Pokédex entries in English, newest game first, de-duplicated.
    public var dexEntries: [DexEntry]
    /// ID of the Pokémon this one evolves from.
    public var evolvesFrom: String?
    /// Pokémon this one evolves into, with how.
    public var evolutions: [Evolution]
    /// IDs of every other form of the same species (excluding this one).
    public var otherFormIDs: [String]
    /// Purely visual variants that share all data with this form (Unown letters, Vivillon patterns, …).
    public var cosmeticForms: [String]
    /// Smogon tier in the current generation, e.g. `"OU"`.
    public var tier: String?
    public var availability: Availability
    /// Flags such as `"Legendary"`, `"Mythical"`, `"Sub-Legendary"`, `"Paradox"`, `"Ultra Beast"`.
    public var tags: [String]
    /// Where the species can be encountered in the most recent game with location data.
    public var locations: GameLocations?
    /// File stem of the bundled artwork and sprite. Falls back to the base species when a form has no art.
    public var imageID: String

    public init(id: String, name: String, displayName: String, nationalDexNumber: Int, generation: Int,
                baseSpeciesID: String? = nil, formName: String? = nil, formKind: FormKind? = nil,
                isBattleOnly: Bool = false, changesFrom: String? = nil, requiredItems: [String]? = nil,
                gigantamaxMove: String? = nil, types: [PokemonType], abilities: AbilitySet, baseStats: StatBlock,
                height: Double, weight: Double, maleRatio: Double?, genus: String? = nil, color: String? = nil,
                eggGroups: [String] = [], catchRate: Int? = nil, baseFriendship: Int? = nil, baseExperience: Int? = nil,
                growthRate: String? = nil, hatchCycles: Int? = nil, evYield: StatBlock? = nil, dexEntries: [DexEntry] = [],
                evolvesFrom: String? = nil, evolutions: [Evolution] = [], otherFormIDs: [String] = [],
                cosmeticForms: [String] = [], tier: String? = nil, availability: Availability = .current,
                tags: [String] = [], locations: GameLocations? = nil, imageID: String) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.nationalDexNumber = nationalDexNumber
        self.generation = generation
        self.baseSpeciesID = baseSpeciesID
        self.formName = formName
        self.formKind = formKind
        self.isBattleOnly = isBattleOnly
        self.changesFrom = changesFrom
        self.requiredItems = requiredItems
        self.gigantamaxMove = gigantamaxMove
        self.types = types
        self.abilities = abilities
        self.baseStats = baseStats
        self.height = height
        self.weight = weight
        self.maleRatio = maleRatio
        self.genus = genus
        self.color = color
        self.eggGroups = eggGroups
        self.catchRate = catchRate
        self.baseFriendship = baseFriendship
        self.baseExperience = baseExperience
        self.growthRate = growthRate
        self.hatchCycles = hatchCycles
        self.evYield = evYield
        self.dexEntries = dexEntries
        self.evolvesFrom = evolvesFrom
        self.evolutions = evolutions
        self.otherFormIDs = otherFormIDs
        self.cosmeticForms = cosmeticForms
        self.tier = tier
        self.availability = availability
        self.tags = tags
        self.locations = locations
        self.imageID = imageID
    }

    // MARK: - Convenience

    /// `true` for the base form of a species.
    public var isBaseForm: Bool { baseSpeciesID == nil }

    /// ID of the species' base form (self when this is the base form).
    public var speciesID: String { baseSpeciesID ?? id }

    /// Primary type.
    public var primaryType: PokemonType { types[0] }

    /// Secondary type, if dual-typed.
    public var secondaryType: PokemonType? { types.count > 1 ? types[1] : nil }

    /// `#0025`-style formatted dex number.
    public var formattedDexNumber: String { "#" + String(format: "%04d", nationalDexNumber) }

    public var isGenderless: Bool { maleRatio == nil }

    public var isLegendary: Bool { tags.contains("Legendary") || tags.contains("Restricted Legendary") }
    public var isMythical: Bool { tags.contains("Mythical") }
    public var isSubLegendary: Bool { tags.contains("Sub-Legendary") }
    public var isParadox: Bool { tags.contains("Paradox") }
    public var isUltraBeast: Bool { tags.contains("Ultra Beast") }

    /// `true` when the Pokémon can be used in the current generation's games.
    public var isAvailableInCurrentGames: Bool { availability == .current }

    /// Weaknesses, resistances and immunities derived from the type combination.
    public var defensiveProfile: TypeMatchup.DefensiveProfile { TypeMatchup.defensiveProfile(for: types) }

    /// Pokémon Showdown's sprite and cry file stem, e.g. `"charizard-megax"` or `"pikachu"`.
    public var showdownSpriteID: String {
        guard let baseSpeciesID, let formName else { return id }
        return baseSpeciesID + "-" + ShowdownID.make(formName)
    }

    /// `true` when the Pokémon has no further evolutions.
    public var isFullyEvolved: Bool { evolutions.isEmpty }
}

/// The regular and hidden abilities of a Pokémon, stored as ability IDs.
public struct AbilitySet: Codable, Sendable, Hashable {
    public var primary: String
    public var secondary: String?
    public var hidden: String?

    public init(primary: String, secondary: String? = nil, hidden: String? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.hidden = hidden
    }

    /// All ability IDs in slot order (regular abilities first, hidden last).
    public var all: [String] { [primary, secondary, hidden].compactMap { $0 } }

    public func contains(_ abilityID: String) -> Bool { all.contains(abilityID) }
}

/// Category of an alternate form.
public enum FormKind: String, Codable, Sendable, Hashable, CaseIterable {
    case mega
    case gigantamax
    case primal
    case alolan
    case galarian
    case hisuian
    case paldean
    case totem
    case terastal
    case other

    public var name: String {
        switch self {
        case .mega: "Mega Evolution"
        case .gigantamax: "Gigantamax"
        case .primal: "Primal Reversion"
        case .alolan: "Alolan Form"
        case .galarian: "Galarian Form"
        case .hisuian: "Hisuian Form"
        case .paldean: "Paldean Form"
        case .totem: "Totem"
        case .terastal: "Terastal Form"
        case .other: "Alternate Form"
        }
    }

    /// Regional variants (Alola, Galar, Hisui, Paldea).
    public var isRegional: Bool {
        switch self {
        case .alolan, .galarian, .hisuian, .paldean: true
        default: false
        }
    }
}

/// Whether a Pokémon, move, ability or item exists in the current generation's games.
public enum Availability: String, Codable, Sendable, Hashable, CaseIterable {
    /// Obtainable in the current generation.
    case current
    /// Existed in earlier generations but is not in the current games.
    case past
    /// Exclusive to Let's Go, Pikachu! / Let's Go, Eevee!.
    case letsGo
    /// Exists in the game data but cannot be legitimately obtained.
    case unobtainable

    public var name: String {
        switch self {
        case .current: "Current games"
        case .past: "Past generations only"
        case .letsGo: "Let's Go only"
        case .unobtainable: "Unobtainable"
        }
    }
}

/// An in-game Pokédex entry and the games it appears in.
public struct DexEntry: Codable, Sendable, Hashable, Identifiable {
    public var text: String
    /// Game names, e.g. `["Pokémon Scarlet", "Pokémon Violet"]`.
    public var games: [String]

    public init(text: String, games: [String]) {
        self.text = text
        self.games = games
    }

    public var id: String { text }

    /// `"Scarlet / Violet"`-style summary of the games, dropping the "Pokémon " prefix.
    public var gamesSummary: String {
        games.map { $0.replacingOccurrences(of: "Pokémon ", with: "") }.joined(separator: " / ")
    }
}

/// An evolution from one Pokémon to another and the conditions for it.
public struct Evolution: Codable, Sendable, Hashable, Identifiable {
    /// ID of the resulting Pokémon.
    public var to: String
    /// Showdown evolution type, e.g. `"levelFriendship"`, `"useItem"`, `"trade"`, `"levelHold"`,
    /// `"levelMove"`, `"levelExtra"`, `"other"`; `nil` means a plain level-up.
    public var kind: String?
    public var level: Int?
    /// Item name for `useItem`/`levelHold`/`trade` evolutions.
    public var item: String?
    /// Move name for `levelMove` evolutions.
    public var move: String?
    /// Free-text condition, e.g. `"during the day"`, `"in the Alola region"`.
    public var condition: String?
    /// Region restriction, e.g. `"Alola"`.
    public var region: String?

    public init(to: String, kind: String? = nil, level: Int? = nil, item: String? = nil, move: String? = nil,
                condition: String? = nil, region: String? = nil) {
        self.to = to
        self.kind = kind
        self.level = level
        self.item = item
        self.move = move
        self.condition = condition
        self.region = region
    }

    public var id: String { to }

    /// Human-readable description of the evolution method, e.g. `"Level 16"`, `"Use Fire Stone"`.
    public var methodDescription: String {
        var base: String
        switch kind {
        case "useItem":
            base = "Use \(item ?? "item")"
        case "trade":
            base = item.map { "Trade holding \($0)" } ?? "Trade"
        case "levelHold":
            base = "Level up holding \(item ?? "item")"
        case "levelMove":
            base = "Level up knowing \(move ?? "a move")"
        case "levelFriendship":
            base = "Level up with high friendship"
        case "levelExtra":
            base = level.map { "Level \($0)" } ?? "Level up"
        case "other":
            base = condition ?? "Special"
            if let level { base = "Level \(level), \(base)" }
            return region.map { "\(base) (\($0))" } ?? base
        default:
            base = level.map { "Level \($0)" } ?? "Level up"
        }
        if let condition, kind != "other" { base += " \(condition)" }
        if let region { base += " in \(region)" }
        return base
    }
}

/// Encounter locations for a species in a single game.
public struct GameLocations: Codable, Sendable, Hashable {
    /// Game name, e.g. `"Pokémon Shield"`.
    public var game: String
    public var areas: [String]

    public init(game: String, areas: [String]) {
        self.game = game
        self.areas = areas
    }
}
