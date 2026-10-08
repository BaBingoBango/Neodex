import Testing
@testable import NeodexKit

@Suite("Type chart")
struct TypeChartTests {
    @Test("Well-known single-type matchups")
    func singleMatchups() {
        #expect(PokemonType.fire.effectiveness(against: .grass) == .superEffective)
        #expect(PokemonType.water.effectiveness(against: .fire) == .superEffective)
        #expect(PokemonType.electric.effectiveness(against: .ground) == .immune)
        #expect(PokemonType.normal.effectiveness(against: .ghost) == .immune)
        #expect(PokemonType.ghost.effectiveness(against: .normal) == .immune)
        #expect(PokemonType.dragon.effectiveness(against: .fairy) == .immune)
        #expect(PokemonType.fighting.effectiveness(against: .fairy) == .notVeryEffective)
        #expect(PokemonType.ice.effectiveness(against: .dragon) == .superEffective)
        #expect(PokemonType.steel.effectiveness(against: .fairy) == .superEffective)
        #expect(PokemonType.poison.effectiveness(against: .steel) == .immune)
        #expect(PokemonType.psychic.effectiveness(against: .dark) == .immune)
        #expect(PokemonType.fire.effectiveness(against: .normal) == .neutral)
    }

    @Test("Dual-type multipliers combine")
    func dualTypes() {
        // Rock/Ground (Golem) takes 4× from Water and Grass.
        #expect(PokemonType.water.multiplier(against: [.rock, .ground]) == 4)
        #expect(PokemonType.grass.multiplier(against: [.rock, .ground]) == 4)
        // Steel/Fairy (Mawile) takes 0 from Poison and Dragon, ¼ from Bug.
        #expect(PokemonType.poison.multiplier(against: [.steel, .fairy]) == 0)
        #expect(PokemonType.dragon.multiplier(against: [.steel, .fairy]) == 0)
        #expect(PokemonType.bug.multiplier(against: [.steel, .fairy]) == 0.25)
        // Water/Ground (Swampert) is only weak to Grass (4×) and immune to Electric.
        let profile = TypeMatchup.defensiveProfile(for: [.water, .ground])
        #expect(profile.doubleWeaknesses == [.grass])
        #expect(profile.weaknesses.isEmpty)
        #expect(profile.immunities == [.electric])
    }

    @Test("Every type has 18 defenders accounted for")
    func profileCoversAllTypes() {
        for type in PokemonType.allCases {
            let profile = TypeMatchup.defensiveProfile(for: [type])
            let total = profile.doubleWeaknesses.count + profile.weaknesses.count + profile.neutral.count
                + profile.resistances.count + profile.doubleResistances.count + profile.immunities.count
            #expect(total == 18, "\(type) profile covers \(total) types")
            #expect(profile.doubleWeaknesses.isEmpty && profile.doubleResistances.isEmpty)
        }
    }

    @Test("Names round-trip")
    func names() {
        #expect(PokemonType(name: "Fire") == .fire)
        #expect(PokemonType(name: " fairy ") == .fairy)
        #expect(PokemonType(name: "Stellar") == nil)
        #expect(PokemonType.fighting.name == "Fighting")
    }
}
