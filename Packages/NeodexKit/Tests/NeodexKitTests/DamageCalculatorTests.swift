import Foundation
import Testing
@testable import NeodexKit

@Suite("Damage calculator")
struct DamageCalculatorTests {
    static let garchomp = Pokemon(id: "garchomp", name: "Garchomp", displayName: "Garchomp", nationalDexNumber: 445, generation: 4,
                                  types: [.dragon, .ground], abilities: AbilitySet(primary: "sandveil", hidden: "roughskin"),
                                  baseStats: StatBlock(hp: 108, attack: 130, defense: 95, specialAttack: 80, specialDefense: 85, speed: 102),
                                  height: 1.9, weight: 95, maleRatio: nil, imageID: "garchomp")
    /// Garchomp's stats with an Electric typing, so Earthquake is super effective.
    static let zapchomp = Pokemon(id: "zapchomp", name: "Zapchomp", displayName: "Zapchomp", nationalDexNumber: 9999, generation: 9,
                                  types: [.electric], abilities: AbilitySet(primary: "static"),
                                  baseStats: garchomp.baseStats, height: 1.9, weight: 320, maleRatio: nil, imageID: "zapchomp")
    static let corviknight = Pokemon(id: "corviknight", name: "Corviknight", displayName: "Corviknight", nationalDexNumber: 823,
                                     generation: 8, types: [.flying, .steel], abilities: AbilitySet(primary: "pressure"),
                                     baseStats: StatBlock(hp: 98, attack: 87, defense: 105, specialAttack: 53, specialDefense: 85, speed: 67),
                                     height: 2.2, weight: 75, maleRatio: nil, imageID: "corviknight")

    static let earthquake = Move(id: "earthquake", name: "Earthquake", type: .ground, category: .physical, basePower: 100,
                                 accuracy: 100, pp: 10, priority: 0, target: "allAdjacent", flags: [], generation: 1)
    static let lowKick = Move(id: "lowkick", name: "Low Kick", type: .fighting, category: .physical, basePower: 0, accuracy: 100,
                              pp: 20, priority: 0, target: "normal", flags: ["contact"], generation: 1)
    static let swordsDance = Move(id: "swordsdance", name: "Swords Dance", type: .normal, category: .status, basePower: 0,
                                  accuracy: nil, pp: 20, priority: 0, target: "self", flags: [], generation: 1)

    static func ability(_ id: String) -> Ability { Ability(id: id, name: id.capitalized, generation: 9) }
    static func item(_ id: String, name: String) -> Item { Item(id: id, name: name, category: .held, generation: 9) }

    /// 252+ Atk Garchomp.
    static var attacker: BattleCombatant {
        BattleCombatant(pokemon: garchomp, ability: ability("roughskin"), nature: .adamant, evs: StatBlock(attack: 252))
    }

    /// 0 HP / 0 Def Garchomp: 357 HP, 226 Def.
    static var defender: BattleCombatant {
        BattleCombatant(pokemon: garchomp, ability: ability("roughskin"))
    }

    @Test("Showdown arithmetic primitives")
    func primitives() {
        #expect(DamageCalculator.baseDamage(level: 100, basePower: 100, attack: 359, defense: 227) == 134)
        #expect(DamageCalculator.pokeRound(187.5) == 187)
        #expect(DamageCalculator.pokeRound(187.51) == 188)
        #expect(DamageCalculator.chain([6144, 6144]) == 9216)
        #expect(DamageCalculator.chain([]) == 4096)
        #expect(DamageCalculator.modified(stat: 100, stage: 2) == 200)
        #expect(DamageCalculator.modified(stat: 100, stage: -1) == 66)
        #expect(DamageCalculator.modified(stat: 100, stage: 9) == 400)
        #expect(Self.defender.maxHP == 357)
        #expect(Self.defender.stats.defense == 226)
        #expect(Self.attacker.stats.attack == 394)
    }

    @Test("STAB Earthquake matches the reference calc line")
    func stabEarthquake() {
        let result = DamageCalculator.calculate(attacker: Self.attacker, defender: Self.defender, move: Self.earthquake)
        #expect(result.rolls.count == 16)
        #expect(result.minDamage == 187)
        #expect(result.maxDamage == 222)
        #expect(result.rolls[7] == 204)
        #expect(result.isSTAB)
        #expect(result.effectiveness == 1)
        #expect(result.koChance.hits == 2)
        #expect(result.summary(moveName: "Earthquake") ==
                "252+ Atk Garchomp Earthquake vs. 0 HP / 0 Def Garchomp: 187-222 (52.3 - 62.1%) -- guaranteed 2HKO")
    }

    @Test("Choice Band, critical hits and Guts")
    func attackModifiers() {
        var banded = Self.attacker
        banded.item = Self.item("choiceband", name: "Choice Band")
        let bandResult = DamageCalculator.calculate(attacker: banded, defender: Self.defender, move: Self.earthquake)
        #expect(bandResult.minDamage == 280 && bandResult.maxDamage == 331)
        #expect(bandResult.summary(moveName: "Earthquake") ==
                "252+ Atk Choice Band Garchomp Earthquake vs. 0 HP / 0 Def Garchomp: 280-331 (78.4 - 92.7%) -- guaranteed 2HKO")

        let crit = DamageCalculator.calculate(attacker: Self.attacker, defender: Self.defender, move: Self.earthquake,
                                              field: BattleField(isCritical: true))
        #expect(crit.minDamage == 282 && crit.maxDamage == 333)

        var guts = Self.attacker
        guts.ability = Self.ability("guts")
        guts.status = .burn
        let gutsResult = DamageCalculator.calculate(attacker: guts, defender: Self.defender, move: Self.earthquake)
        #expect(gutsResult.minDamage == 280 && gutsResult.maxDamage == 331)
        #expect(gutsResult.attackerDescription == "252+ Atk Guts Garchomp")

        var boosted = Self.attacker
        boosted.boosts.attack = 2
        let boostedResult = DamageCalculator.calculate(attacker: boosted, defender: Self.defender, move: Self.earthquake)
        #expect(boostedResult.attackerDescription == "+2 252+ Atk Garchomp")
        #expect(boostedResult.minDamage == 373 && boostedResult.maxDamage == 441)
    }

    @Test("Terastallization and Adaptability STAB")
    func teraSTAB() {
        var tera = Self.attacker
        tera.teraType = .ground
        let teraResult = DamageCalculator.calculate(attacker: tera, defender: Self.defender, move: Self.earthquake)
        #expect(teraResult.minDamage == 250 && teraResult.maxDamage == 296)
        #expect(teraResult.attackerDescription == "252+ Atk Tera Ground Garchomp")

        var adaptable = Self.attacker
        adaptable.ability = Self.ability("adaptability")
        let adaptableResult = DamageCalculator.calculate(attacker: adaptable, defender: Self.defender, move: Self.earthquake)
        #expect(adaptableResult.minDamage == 250 && adaptableResult.maxDamage == 296)

        adaptable.teraType = .ground
        let both = DamageCalculator.calculate(attacker: adaptable, defender: Self.defender, move: Self.earthquake)
        #expect(both.minDamage == 281 && both.maxDamage == 333)

        adaptable.teraType = .fire   // Tera into a new type: Earthquake loses Adaptability, keeps plain STAB.
        let offType = DamageCalculator.calculate(attacker: adaptable, defender: Self.defender, move: Self.earthquake)
        #expect(offType.minDamage == 187 && offType.maxDamage == 222)
    }

    @Test("Burn, screens and Multiscale halve damage")
    func halvingEffects() {
        var burned = Self.attacker
        burned.status = .burn
        let burnResult = DamageCalculator.calculate(attacker: burned, defender: Self.defender, move: Self.earthquake)
        #expect(burnResult.minDamage == 93 && burnResult.maxDamage == 111)
        #expect(burnResult.attackerDescription == "252+ Atk burned Garchomp")

        let reflect = DamageCalculator.calculate(attacker: Self.attacker, defender: Self.defender, move: Self.earthquake,
                                                 field: BattleField(defenderHasReflect: true))
        #expect(reflect.minDamage == 93 && reflect.maxDamage == 111)
        #expect(reflect.fieldDescription == " through Reflect")

        let lightScreen = DamageCalculator.calculate(attacker: Self.attacker, defender: Self.defender, move: Self.earthquake,
                                                     field: BattleField(defenderHasLightScreen: true))
        #expect(lightScreen.minDamage == 187)

        var multiscale = Self.defender
        multiscale.ability = Self.ability("multiscale")
        let fullHP = DamageCalculator.calculate(attacker: Self.attacker, defender: multiscale, move: Self.earthquake)
        #expect(fullHP.minDamage == 93 && fullHP.maxDamage == 111)
        multiscale.currentHPPercent = 50
        let chipped = DamageCalculator.calculate(attacker: Self.attacker, defender: multiscale, move: Self.earthquake)
        #expect(chipped.minDamage == 187)
        #expect(chipped.koChance.text == "guaranteed OHKO")
    }

    @Test("Immunities, Mold Breaker and gravity")
    func immunities() {
        var levitating = Self.defender
        levitating.ability = Self.ability("levitate")
        let immune = DamageCalculator.calculate(attacker: Self.attacker, defender: levitating, move: Self.earthquake)
        #expect(immune.isImmune)
        #expect(immune.rolls == [0])
        #expect(immune.koChance.text == "no effect")

        var breaker = Self.attacker
        breaker.ability = Self.ability("moldbreaker")
        let broken = DamageCalculator.calculate(attacker: breaker, defender: levitating, move: Self.earthquake)
        #expect(broken.minDamage == 187)

        let corviknight = BattleCombatant(pokemon: Self.corviknight, ability: Self.ability("pressure"))
        let flying = DamageCalculator.calculate(attacker: Self.attacker, defender: corviknight, move: Self.earthquake)
        #expect(flying.isImmune)
        let grounded = DamageCalculator.calculate(attacker: Self.attacker, defender: corviknight, move: Self.earthquake,
                                                  field: BattleField(gravity: true))
        #expect(grounded.effectiveness == 2)
    }

    @Test("Super effective hits and KO chances")
    func superEffective() {
        let zapchomp = BattleCombatant(pokemon: Self.zapchomp, ability: Self.ability("static"))
        let result = DamageCalculator.calculate(attacker: Self.attacker, defender: zapchomp, move: Self.earthquake)
        #expect(result.effectiveness == 2)
        #expect(result.minDamage == 374 && result.maxDamage == 444)
        #expect(result.koChance.text == "guaranteed OHKO")
        #expect(result.minPercent == 104.7)

        #expect(KOChance.compute(rolls: Array(repeating: 100, count: 16), hp: 250).text == "guaranteed 3HKO")
        #expect(KOChance.compute(rolls: Array(90...105), hp: 100).text == "37.5% chance to OHKO")
        #expect(KOChance.compute(rolls: Array(90...105), hp: 100).probability == 0.375)
    }

    @Test("Variable base power, terrain and status moves")
    func variablePower() {
        let heavy = BattleCombatant(pokemon: Self.zapchomp, ability: Self.ability("static"))
        #expect(DamageCalculator.calculate(attacker: Self.attacker, defender: heavy, move: Self.lowKick).basePower == 120)
        #expect(DamageCalculator.calculate(attacker: Self.attacker, defender: Self.defender, move: Self.lowKick).basePower == 80)

        let grassy = DamageCalculator.calculate(attacker: Self.attacker, defender: Self.defender, move: Self.earthquake,
                                                field: BattleField(terrain: .grassy))
        #expect(grassy.basePower == 50)
        #expect(grassy.minDamage == 94 && grassy.maxDamage == 112)
        #expect(grassy.fieldDescription == " in Grassy Terrain")

        let status = DamageCalculator.calculate(attacker: Self.attacker, defender: Self.defender, move: Self.swordsDance)
        #expect(status.rolls == [0])
        #expect(status.koChance.text == "does no damage")
    }

    @Test("Combatant state helpers")
    func combatantHelpers() {
        var combatant = Self.attacker
        #expect(combatant.highestStat == .attack)
        combatant.boosts.speed = 6
        #expect(combatant.boostedStat(.speed) == combatant.stats.speed * 4)
        #expect(combatant.highestStat == .speed)
        #expect(combatant.isGrounded)
        combatant.item = Self.item("airballoon", name: "Air Balloon")
        #expect(!combatant.isGrounded)
        combatant.teraType = .flying
        #expect(combatant.types == [.flying])
        #expect(combatant.hasOriginalType(.dragon))
    }
}
