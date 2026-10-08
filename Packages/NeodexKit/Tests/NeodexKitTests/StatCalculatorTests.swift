import Testing
@testable import NeodexKit

@Suite("Stat calculator")
struct StatCalculatorTests {
    // Garchomp: 108 / 130 / 95 / 80 / 85 / 102
    let garchomp = StatBlock(hp: 108, attack: 130, defense: 95, specialAttack: 80, specialDefense: 85, speed: 102)

    @Test("Standard Jolly Garchomp at level 100")
    func jollyGarchomp() {
        let evs = StatBlock(hp: 0, attack: 252, defense: 4, specialAttack: 0, specialDefense: 0, speed: 252)
        let stats = StatCalculator.calculateAll(base: garchomp, ivs: .perfectIVs, evs: evs, level: 100, nature: .jolly)
        #expect(stats.hp == 357)
        #expect(stats.attack == 359)
        #expect(stats.defense == 227)
        #expect(stats.specialAttack == 176)   // Jolly lowers Sp. Atk: (160+31)+5 = 196 × 0.9 = 176
        #expect(stats.specialDefense == 206)
        #expect(stats.speed == 333)
    }

    @Test("Level 50 values floor correctly")
    func levelFifty() {
        let evs = StatBlock(hp: 252, attack: 0, defense: 0, specialAttack: 252, specialDefense: 4, speed: 0)
        let stats = StatCalculator.calculateAll(base: garchomp, ivs: .perfectIVs, evs: evs, level: 50, nature: .modest)
        #expect(stats.hp == 215)
        #expect(stats.attack == 135)          // 130×2+31 = 291 × 50/100 = 145 + 5 = 150 × 0.9 = 135
        #expect(stats.specialAttack == 145)   // (160+31+63) × 50/100 = 127; (127+5) × 1.1 = 145.2 → 145
    }

    @Test("Shedinja always has 1 HP")
    func shedinja() {
        #expect(StatCalculator.hp(base: 1, iv: 31, ev: 252, level: 100) == 1)
    }

    @Test("Neutral natures do not change stats")
    func neutralNature() {
        for nature in [Nature.hardy, .docile, .serious, .bashful, .quirky] {
            #expect(nature.isNeutral)
            for stat in Stat.allCases { #expect(nature.modifier(for: stat) == 1) }
        }
        #expect(Nature.adamant.modifier(for: .attack) == 1.1)
        #expect(Nature.adamant.modifier(for: .specialAttack) == 0.9)
        #expect(Nature.adamant.likedFlavor == .spicy)
        #expect(Nature.adamant.dislikedFlavor == .dry)
        #expect(Nature.all.count == 25)
        #expect(Set(Nature.all.map(\.name)).count == 25)
    }
}
