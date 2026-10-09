import Foundation

/// Weather that affects damage.
public enum Weather: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case none, sun, rain, sandstorm, snow

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .none: "None"
        case .sun: "Sun"
        case .rain: "Rain"
        case .sandstorm: "Sandstorm"
        case .snow: "Snow"
        }
    }
}

/// Terrain that affects damage.
public enum Terrain: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case none, electric, grassy, psychic, misty

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .none: "None"
        case .electric: "Electric Terrain"
        case .grassy: "Grassy Terrain"
        case .psychic: "Psychic Terrain"
        case .misty: "Misty Terrain"
        }
    }
}

/// Non-volatile status conditions that change damage.
public enum StatusCondition: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case none, burn, poison, toxic, paralysis, sleep, freeze

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .none: "Healthy"
        case .burn: "Burned"
        case .poison: "Poisoned"
        case .toxic: "Badly Poisoned"
        case .paralysis: "Paralyzed"
        case .sleep: "Asleep"
        case .freeze: "Frozen"
        }
    }

    public var isStatused: Bool { self != .none }
}

/// One side of a damage calculation: a Pokémon with a full set and its in-battle state.
public struct BattleCombatant: Sendable, Hashable {
    public var pokemon: Pokemon
    public var level: Int
    public var nature: Nature
    public var evs: StatBlock
    public var ivs: StatBlock
    /// Stat stages from −6 to +6. HP is ignored.
    public var boosts: StatBlock
    public var ability: Ability
    public var item: Item?
    public var status: StatusCondition
    /// Set when the Pokémon has Terastallized.
    public var teraType: PokemonType?
    /// Remaining HP as a percentage of the maximum.
    public var currentHPPercent: Double
    /// For Supreme Overlord and Last Respects.
    public var faintedAllies: Int

    public init(pokemon: Pokemon, ability: Ability, level: Int = 100, nature: Nature = .serious, evs: StatBlock = .zero,
                ivs: StatBlock = .perfectIVs, boosts: StatBlock = .zero, item: Item? = nil, status: StatusCondition = .none,
                teraType: PokemonType? = nil, currentHPPercent: Double = 100, faintedAllies: Int = 0) {
        self.pokemon = pokemon
        self.level = max(1, min(100, level))
        self.nature = nature
        self.evs = evs
        self.ivs = ivs
        self.boosts = boosts
        self.ability = ability
        self.item = item
        self.status = status
        self.teraType = teraType
        self.currentHPPercent = max(0, min(100, currentHPPercent))
        self.faintedAllies = max(0, min(5, faintedAllies))
    }

    /// Stats at the given level, nature and investment, before stat stages.
    public var stats: StatBlock {
        StatCalculator.calculateAll(base: pokemon.baseStats, ivs: ivs, evs: evs, level: level, nature: nature)
    }

    public var maxHP: Int { stats.hp }

    public var currentHP: Int {
        max(1, min(maxHP, Int((Double(maxHP) * currentHPPercent / 100).rounded())))
    }

    /// The Pokémon's current types, taking Terastallization into account.
    public var types: [PokemonType] {
        if let teraType { return [teraType] }
        return pokemon.types
    }

    public func hasType(_ type: PokemonType) -> Bool { types.contains(type) }
    public func hasOriginalType(_ type: PokemonType) -> Bool { pokemon.types.contains(type) }
    public func hasAbility(_ ids: String...) -> Bool { ids.contains(ability.id) }
    public func hasItem(_ ids: String...) -> Bool { item.map { ids.contains($0.id) } ?? false }

    public var isTerastallized: Bool { teraType != nil }

    /// Whether the Pokémon is affected by terrain and Ground-type moves.
    public var isGrounded: Bool {
        if hasItem("ironball") { return true }
        if hasType(.flying) || hasAbility("levitate") || hasItem("airballoon") { return false }
        return true
    }

    /// A stat after its current stage, e.g. +2 Attack.
    public func boostedStat(_ stat: Stat) -> Int {
        stat == .hp ? stats.hp : DamageCalculator.modified(stat: stats[stat], stage: boosts[stat])
    }

    /// The stat that Protosynthesis or Quark Drive would raise (ties go to the earlier stat).
    public var highestStat: Stat {
        var best = Stat.attack
        for stat in [Stat.defense, .specialAttack, .specialDefense, .speed] where boostedStat(stat) > boostedStat(best) {
            best = stat
        }
        return best
    }
}

/// Everything about the battle that is not one of the two Pokémon.
public struct BattleField: Sendable, Hashable {
    public var weather: Weather
    public var terrain: Terrain
    public var isDoubles: Bool
    public var isCritical: Bool
    public var defenderHasReflect: Bool
    public var defenderHasLightScreen: Bool
    public var defenderHasAuroraVeil: Bool
    public var gravity: Bool

    public init(weather: Weather = .none, terrain: Terrain = .none, isDoubles: Bool = false, isCritical: Bool = false,
                defenderHasReflect: Bool = false, defenderHasLightScreen: Bool = false, defenderHasAuroraVeil: Bool = false,
                gravity: Bool = false) {
        self.weather = weather
        self.terrain = terrain
        self.isDoubles = isDoubles
        self.isCritical = isCritical
        self.defenderHasReflect = defenderHasReflect
        self.defenderHasLightScreen = defenderHasLightScreen
        self.defenderHasAuroraVeil = defenderHasAuroraVeil
        self.gravity = gravity
    }
}

/// How many hits a move needs to knock the defender out, with the probability of doing so.
public struct KOChance: Sendable, Hashable {
    public var hits: Int
    /// Probability (0…1) that `hits` hits knock out the defender.
    public var probability: Double
    /// Showdown-style wording, e.g. `"guaranteed 2HKO"` or `"43.8% chance to OHKO"`.
    public var text: String

    public init(hits: Int, probability: Double, text: String) {
        self.hits = hits
        self.probability = probability
        self.text = text
    }

    /// Exact KO probabilities from the sixteen damage rolls, assuming no healing between hits.
    public static func compute(rolls: [Int], hp: Int) -> KOChance {
        guard hp > 0, !rolls.isEmpty, rolls.contains(where: { $0 > 0 }) else {
            return KOChance(hits: 0, probability: 0, text: "does no damage")
        }
        let rollProbability = 1.0 / Double(rolls.count)
        var distribution = [Double](repeating: 0, count: hp + 1)
        distribution[0] = 1
        for hits in 1...9 {
            var next = [Double](repeating: 0, count: hp + 1)
            for sum in 0..<hp where distribution[sum] > 0 {
                for roll in rolls {
                    next[min(hp, sum + roll)] += distribution[sum] * rollProbability
                }
            }
            next[hp] += distribution[hp]
            distribution = next
            let probability = distribution[hp]
            if probability >= 0.9999 {
                return KOChance(hits: hits, probability: 1, text: "guaranteed \(label(hits))")
            }
            if probability > 0.0005 {
                let percent = (probability * 1000).rounded() / 10
                return KOChance(hits: hits, probability: probability, text: "\(percent.formatted(.number.precision(.fractionLength(0...1))))% chance to \(label(hits))")
            }
        }
        return KOChance(hits: 10, probability: 0, text: "possibly the worst case 10HKO or more")
    }

    private static func label(_ hits: Int) -> String { hits == 1 ? "OHKO" : "\(hits)HKO" }
}

/// The outcome of a damage calculation.
public struct DamageResult: Sendable, Hashable {
    /// Sixteen damage rolls, lowest first.
    public var rolls: [Int]
    public var defenderMaxHP: Int
    public var defenderCurrentHP: Int
    public var moveType: PokemonType
    public var category: MoveCategory
    public var basePower: Int
    public var effectiveness: Double
    public var isSTAB: Bool
    public var koChance: KOChance
    /// Showdown-style descriptions, e.g. `"252+ Atk Choice Band Garchomp"`.
    public var attackerDescription: String
    public var defenderDescription: String
    public var fieldDescription: String

    public var minDamage: Int { rolls.first ?? 0 }
    public var maxDamage: Int { rolls.last ?? 0 }
    public var minPercent: Double { percent(minDamage) }
    public var maxPercent: Double { percent(maxDamage) }
    public var isImmune: Bool { maxDamage == 0 }

    /// Damage as a percentage of max HP, truncated to one decimal place like Showdown.
    public func percent(_ damage: Int) -> Double {
        defenderMaxHP > 0 ? (Double(damage) * 1000 / Double(defenderMaxHP)).rounded(.down) / 10 : 0
    }

    /// The whole calculation on one line, in the format Showdown's calculator uses.
    public func summary(moveName: String) -> String {
        let percents = "\(format(minPercent)) - \(format(maxPercent))%"
        return "\(attackerDescription) \(moveName) vs. \(defenderDescription)\(fieldDescription): \(minDamage)-\(maxDamage) (\(percents)) -- \(koChance.text)"
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}
