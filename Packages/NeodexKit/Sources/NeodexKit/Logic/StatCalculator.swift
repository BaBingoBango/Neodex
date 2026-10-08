import Foundation

/// The Gen 3+ stat formulas.
public enum StatCalculator {
    /// HP at a given level. Shedinja (base HP 1) always has exactly 1 HP.
    public static func hp(base: Int, iv: Int, ev: Int, level: Int) -> Int {
        guard base > 1 else { return 1 }
        let core = (2 * base + iv + ev / 4) * level / 100
        return core + level + 10
    }

    /// Any non-HP stat at a given level.
    public static func stat(base: Int, iv: Int, ev: Int, level: Int, natureModifier: Double) -> Int {
        let core = (2 * base + iv + ev / 4) * level / 100
        return Int((Double(core + 5) * natureModifier).rounded(.towardZero))
    }

    /// A single stat for a fully specified Pokémon.
    public static func calculate(_ stat: Stat, base: StatBlock, ivs: StatBlock, evs: StatBlock, level: Int, nature: Nature) -> Int {
        let clampedLevel = max(1, min(100, level))
        let iv = max(0, min(31, ivs[stat]))
        let ev = max(0, min(252, evs[stat]))
        if stat == .hp {
            return hp(base: base.hp, iv: iv, ev: ev, level: clampedLevel)
        }
        return self.stat(base: base[stat], iv: iv, ev: ev, level: clampedLevel, natureModifier: nature.modifier(for: stat))
    }

    /// All six stats for a fully specified Pokémon.
    public static func calculateAll(base: StatBlock, ivs: StatBlock = .perfectIVs, evs: StatBlock = .zero,
                                    level: Int = 100, nature: Nature = .serious) -> StatBlock {
        var result = StatBlock()
        for stat in Stat.allCases {
            result[stat] = calculate(stat, base: base, ivs: ivs, evs: evs, level: level, nature: nature)
        }
        return result
    }

    /// The highest value a stat can reach (max IVs/EVs, beneficial nature) at a level.
    public static func maximum(_ stat: Stat, base: StatBlock, level: Int = 100) -> Int {
        if stat == .hp { return hp(base: base.hp, iv: 31, ev: 252, level: level) }
        return self.stat(base: base[stat], iv: 31, ev: 252, level: level, natureModifier: 1.1)
    }

    /// The lowest value a stat can reach (0 IVs/EVs, hindering nature) at a level.
    public static func minimum(_ stat: Stat, base: StatBlock, level: Int = 100) -> Int {
        if stat == .hp { return hp(base: base.hp, iv: 0, ev: 0, level: level) }
        return self.stat(base: base[stat], iv: 0, ev: 0, level: level, natureModifier: 0.9)
    }

    /// Total EVs may not exceed this value.
    public static let maximumTotalEVs = 510
    /// A single stat may not receive more EVs than this.
    public static let maximumStatEVs = 252
}
