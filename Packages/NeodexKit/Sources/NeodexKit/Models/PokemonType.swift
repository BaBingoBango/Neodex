import Foundation

/// One of the eighteen Pokémon types.
public enum PokemonType: String, Codable, Sendable, Hashable, CaseIterable, Identifiable, Comparable {
    case normal, fire, water, electric, grass, ice, fighting, poison, ground
    case flying, psychic, bug, rock, ghost, dragon, dark, steel, fairy

    public var id: String { rawValue }

    /// Capitalised display name, e.g. "Fire".
    public var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// Case-insensitive lookup by name ("Fire", "fire", "FIRE").
    public init?(name: String) {
        self.init(rawValue: name.trimmingCharacters(in: .whitespaces).lowercased())
    }

    public static func < (lhs: PokemonType, rhs: PokemonType) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    // MARK: - Type chart

    /// Damage multiplier when a move of this type hits a single defending type.
    public func effectiveness(against defender: PokemonType) -> Effectiveness {
        Self.chart[self]?[defender] ?? .neutral
    }

    /// Combined damage multiplier when a move of this type hits a Pokémon with the given type(s).
    public func multiplier(against defenders: [PokemonType]) -> Double {
        defenders.reduce(1.0) { $0 * effectiveness(against: $1).multiplier }
    }

    /// Non-neutral matchups for the whole chart: `chart[attacker][defender]`.
    /// Gen 6+ chart (unchanged since the introduction of Fairy).
    static let chart: [PokemonType: [PokemonType: Effectiveness]] = [
        .normal: [.rock: .notVeryEffective, .ghost: .immune, .steel: .notVeryEffective],
        .fire: [.fire: .notVeryEffective, .water: .notVeryEffective, .grass: .superEffective, .ice: .superEffective,
                .bug: .superEffective, .rock: .notVeryEffective, .dragon: .notVeryEffective, .steel: .superEffective],
        .water: [.fire: .superEffective, .water: .notVeryEffective, .grass: .notVeryEffective, .ground: .superEffective,
                 .rock: .superEffective, .dragon: .notVeryEffective],
        .electric: [.water: .superEffective, .electric: .notVeryEffective, .grass: .notVeryEffective, .ground: .immune,
                    .flying: .superEffective, .dragon: .notVeryEffective],
        .grass: [.fire: .notVeryEffective, .water: .superEffective, .grass: .notVeryEffective, .poison: .notVeryEffective,
                 .ground: .superEffective, .flying: .notVeryEffective, .bug: .notVeryEffective, .rock: .superEffective,
                 .dragon: .notVeryEffective, .steel: .notVeryEffective],
        .ice: [.fire: .notVeryEffective, .water: .notVeryEffective, .grass: .superEffective, .ice: .notVeryEffective,
               .ground: .superEffective, .flying: .superEffective, .dragon: .superEffective, .steel: .notVeryEffective],
        .fighting: [.normal: .superEffective, .ice: .superEffective, .poison: .notVeryEffective, .flying: .notVeryEffective,
                    .psychic: .notVeryEffective, .bug: .notVeryEffective, .rock: .superEffective, .ghost: .immune,
                    .dark: .superEffective, .steel: .superEffective, .fairy: .notVeryEffective],
        .poison: [.grass: .superEffective, .poison: .notVeryEffective, .ground: .notVeryEffective, .rock: .notVeryEffective,
                  .ghost: .notVeryEffective, .steel: .immune, .fairy: .superEffective],
        .ground: [.fire: .superEffective, .electric: .superEffective, .grass: .notVeryEffective, .poison: .superEffective,
                  .flying: .immune, .bug: .notVeryEffective, .rock: .superEffective, .steel: .superEffective],
        .flying: [.electric: .notVeryEffective, .grass: .superEffective, .fighting: .superEffective, .bug: .superEffective,
                  .rock: .notVeryEffective, .steel: .notVeryEffective],
        .psychic: [.fighting: .superEffective, .poison: .superEffective, .psychic: .notVeryEffective, .dark: .immune,
                   .steel: .notVeryEffective],
        .bug: [.fire: .notVeryEffective, .grass: .superEffective, .fighting: .notVeryEffective, .poison: .notVeryEffective,
               .flying: .notVeryEffective, .psychic: .superEffective, .ghost: .notVeryEffective, .dark: .superEffective,
               .steel: .notVeryEffective, .fairy: .notVeryEffective],
        .rock: [.fire: .superEffective, .ice: .superEffective, .fighting: .notVeryEffective, .ground: .notVeryEffective,
                .flying: .superEffective, .bug: .superEffective, .steel: .notVeryEffective],
        .ghost: [.normal: .immune, .psychic: .superEffective, .ghost: .superEffective, .dark: .notVeryEffective],
        .dragon: [.dragon: .superEffective, .steel: .notVeryEffective, .fairy: .immune],
        .dark: [.fighting: .notVeryEffective, .psychic: .superEffective, .ghost: .superEffective, .dark: .notVeryEffective,
                .fairy: .notVeryEffective],
        .steel: [.fire: .notVeryEffective, .water: .notVeryEffective, .electric: .notVeryEffective, .ice: .superEffective,
                 .rock: .superEffective, .steel: .notVeryEffective, .fairy: .superEffective],
        .fairy: [.fire: .notVeryEffective, .fighting: .superEffective, .poison: .notVeryEffective, .dragon: .superEffective,
                 .dark: .superEffective, .steel: .notVeryEffective],
    ]
}

/// The damage multiplier of a single type-on-type matchup.
public enum Effectiveness: Double, Sendable, Hashable, Comparable {
    case immune = 0
    case notVeryEffective = 0.5
    case neutral = 1
    case superEffective = 2

    public var multiplier: Double { rawValue }

    public static func < (lhs: Effectiveness, rhs: Effectiveness) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Defensive and offensive type analysis helpers.
public enum TypeMatchup {
    /// Buckets of attacking types by the combined multiplier they deal to a Pokémon with `types`.
    public struct DefensiveProfile: Sendable, Hashable {
        /// Takes 4× damage (only possible with two types).
        public var doubleWeaknesses: [PokemonType] = []
        /// Takes 2× damage.
        public var weaknesses: [PokemonType] = []
        /// Takes 1× damage.
        public var neutral: [PokemonType] = []
        /// Takes ½× damage.
        public var resistances: [PokemonType] = []
        /// Takes ¼× damage.
        public var doubleResistances: [PokemonType] = []
        /// Takes no damage.
        public var immunities: [PokemonType] = []

        /// The multiplier a given attacking type deals against this profile.
        public func multiplier(for attacker: PokemonType) -> Double {
            if doubleWeaknesses.contains(attacker) { return 4 }
            if weaknesses.contains(attacker) { return 2 }
            if resistances.contains(attacker) { return 0.5 }
            if doubleResistances.contains(attacker) { return 0.25 }
            if immunities.contains(attacker) { return 0 }
            return 1
        }
    }

    /// Computes how every attacking type fares against a Pokémon with the given type(s).
    public static func defensiveProfile(for types: [PokemonType]) -> DefensiveProfile {
        var profile = DefensiveProfile()
        let unique = Array(Set(types)).sorted()
        for attacker in PokemonType.allCases {
            let multiplier = attacker.multiplier(against: unique)
            switch multiplier {
            case 4: profile.doubleWeaknesses.append(attacker)
            case 2: profile.weaknesses.append(attacker)
            case 0.5: profile.resistances.append(attacker)
            case 0.25: profile.doubleResistances.append(attacker)
            case 0: profile.immunities.append(attacker)
            default: profile.neutral.append(attacker)
            }
        }
        return profile
    }

    /// Offensive coverage of a single attacking type: which defending types take more or less damage.
    public struct OffensiveProfile: Sendable, Hashable {
        public var superEffective: [PokemonType] = []
        public var neutral: [PokemonType] = []
        public var notVeryEffective: [PokemonType] = []
        public var noEffect: [PokemonType] = []
    }

    public static func offensiveProfile(for attacker: PokemonType) -> OffensiveProfile {
        var profile = OffensiveProfile()
        for defender in PokemonType.allCases {
            switch attacker.effectiveness(against: defender) {
            case .superEffective: profile.superEffective.append(defender)
            case .neutral: profile.neutral.append(defender)
            case .notVeryEffective: profile.notVeryEffective.append(defender)
            case .immune: profile.noEffect.append(defender)
            }
        }
        return profile
    }
}
