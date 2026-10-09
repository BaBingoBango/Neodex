import Foundation

/// A Generation 9 damage calculator that follows the structure, modifier order and rounding of
/// Pokémon Showdown's damage calculator. It covers what decides the overwhelming majority of real
/// calcs: stat stages, natures and EVs, STAB and Terastallization, critical hits, weather, terrain,
/// screens, burns, the common offensive and defensive abilities, held items, variable-power moves
/// and type immunities. Entry hazards, multi-turn moves and ally abilities are not modelled.
public enum DamageCalculator {
    public static func calculate(attacker: BattleCombatant, defender: BattleCombatant, move: Move,
                                 field: BattleField = BattleField()) -> DamageResult {
        var calculation = Calculation(attacker: attacker, defender: defender, move: move, field: field)
        return calculation.run()
    }

    // MARK: - Showdown arithmetic

    /// Rounds half *down*, as the games do.
    static func pokeRound(_ value: Double) -> Int {
        let floor = value.rounded(.down)
        return value - floor > 0.5 ? Int(floor) + 1 : Int(floor)
    }

    /// Chains 4096-based modifiers the way the games do.
    static func chain(_ modifiers: [Int], lowerBound: Int = 410, upperBound: Int = 131_072) -> Int {
        var result = 4096
        for modifier in modifiers where modifier != 4096 {
            result = (result * modifier + 0x800) >> 12
        }
        return max(lowerBound, min(upperBound, result))
    }

    static func apply(_ value: Int, _ modifier: Int) -> Int {
        max(1, pokeRound(Double(value) * Double(modifier) / 4096))
    }

    /// A stat after stages (+2 → ×2, −2 → ×½).
    static func modified(stat: Int, stage: Int) -> Int {
        let stage = max(-6, min(6, stage))
        return stage >= 0 ? stat * (2 + stage) / 2 : stat * 2 / (2 - stage)
    }

    /// ⌊⌊⌊2·Level/5 + 2⌋ · Power · A / D⌋ / 50⌋ + 2.
    static func baseDamage(level: Int, basePower: Int, attack: Int, defense: Int) -> Int {
        let levelFactor = 2 * level / 5 + 2
        return levelFactor * basePower * attack / max(1, defense) / 50 + 2
    }

    // MARK: - Calculation

    struct Calculation {
        let attacker: BattleCombatant
        let defender: BattleCombatant
        let move: Move
        let field: BattleField
        let defenderAbilityIgnored: Bool

        var attackBoost = 0
        var defenseBoost = 0
        var isBurned = false
        var attackerNotes: [String] = []
        var defenderNotes: [String] = []
        var fieldNotes: [String] = []

        init(attacker: BattleCombatant, defender: BattleCombatant, move: Move, field: BattleField) {
            self.attacker = attacker
            self.defender = defender
            self.move = move
            self.field = field
            let ignores = DamageTables.moldBreakerAbilities.contains(attacker.ability.id)
                || DamageTables.abilityIgnoringMoves.contains(move.id)
            defenderAbilityIgnored = ignores && !DamageTables.unbreakableAbilities.contains(defender.ability.id)
        }

        func defenderHas(_ ids: String...) -> Bool {
            !defenderAbilityIgnored && ids.contains(defender.ability.id)
        }

        var attackerAbility: String { attacker.ability.id }

        mutating func run() -> DamageResult {
            guard move.category != .status, move.kind == .standard || move.kind == .zMove else {
                return result(rolls: [0], moveType: move.type, category: move.category, basePower: 0, effectiveness: 1, stab: false)
            }

            let moveType = resolvedMoveType()
            let category = resolvedCategory()
            let effectiveness = effectiveness(of: moveType)
            if effectiveness == 0 {
                return result(rolls: [0], moveType: moveType, category: category, basePower: move.basePower, effectiveness: 0, stab: false)
            }

            let basePower = resolvedBasePower(moveType: moveType, category: category, effectiveness: effectiveness)
            guard basePower > 0 else {
                return result(rolls: [0], moveType: moveType, category: category, basePower: 0, effectiveness: effectiveness, stab: false)
            }

            let attack = attackStat(category: category, moveType: moveType)
            let defense = defenseStat(category: category, moveType: moveType)
            var base = DamageCalculator.baseDamage(level: attacker.level, basePower: basePower, attack: attack, defense: defense)

            if field.isDoubles, ["allAdjacentFoes", "allAdjacent"].contains(move.target) {
                base = DamageCalculator.apply(base, 3072)
            }
            if field.weather == .sun, move.id == "hydrosteam" {
                base = DamageCalculator.apply(base, 6144)
                note(field: "in Sun")
            } else {
                switch (field.weather, moveType) {
                case (.sun, .fire), (.rain, .water):
                    base = DamageCalculator.apply(base, 6144)
                    note(field: "in " + field.weather.name)
                case (.sun, .water), (.rain, .fire):
                    base = DamageCalculator.apply(base, 2048)
                    note(field: "in " + field.weather.name)
                default:
                    break
                }
            }
            if field.isCritical {
                base = Int(Double(base) * 1.5)
            }

            // STAB, including Terastallization and Adaptability.
            var stabModifier = 4096
            if attacker.hasOriginalType(moveType) {
                stabModifier += 2048
            } else if attacker.hasAbility("protean", "libero"), !attacker.isTerastallized {
                stabModifier += 2048
                note(attacker: attacker.ability.name)
            }
            if let tera = attacker.teraType, tera == moveType {
                stabModifier += 2048
            }
            if attacker.hasAbility("adaptability"), attacker.hasType(moveType) {
                let teraMatchesOriginal = attacker.teraType.map { attacker.hasOriginalType($0) } ?? false
                stabModifier += teraMatchesOriginal ? 1024 : 2048
                note(attacker: "Adaptability")
            }

            isBurned = attacker.status == .burn && category == .physical && !attacker.hasAbility("guts") && move.id != "facade"
            let finalModifier = DamageCalculator.chain(finalModifiers(moveType: moveType, category: category, effectiveness: effectiveness))

            var rolls: [Int] = []
            for roll in 0..<16 {
                var damage = base * (85 + roll) / 100
                if stabModifier != 4096 {
                    damage = DamageCalculator.pokeRound(Double(damage) * Double(stabModifier) / 4096)
                }
                damage = Int(Double(damage) * effectiveness)
                if isBurned { damage /= 2 }
                damage = DamageCalculator.pokeRound(max(1, Double(damage) * Double(finalModifier) / 4096))
                rolls.append(damage)
            }
            rolls.sort()
            return result(rolls: rolls, moveType: moveType, category: category, basePower: basePower,
                          effectiveness: effectiveness, stab: stabModifier > 4096)
        }

        // MARK: Type, category and effectiveness

        func resolvedMoveType() -> PokemonType {
            if move.id == "terablast", let tera = attacker.teraType { return tera }
            if move.id == "weatherball" { return DamageTables.weatherBallType(field.weather) }
            if move.id == "terrainpulse", attacker.isGrounded { return DamageTables.terrainPulseType(field.terrain) }
            if let signature = DamageTables.formSignatureType(move: move.id, pokemonID: attacker.pokemon.id) { return signature }
            if move.id == "revelationdance" { return attacker.types.first ?? move.type }
            if move.type == .normal, let changed = DamageTables.ateAbilities[attackerAbility] { return changed }
            return move.type
        }

        func resolvedCategory() -> MoveCategory {
            let dependsOnStats = (move.id == "terablast" && attacker.isTerastallized)
                || move.id == "photongeyser" || move.id == "lightthatburnsthesky"
            if dependsOnStats {
                return attacker.boostedStat(.attack) > attacker.boostedStat(.specialAttack) ? .physical : .special
            }
            return move.category
        }

        func effectiveness(of moveType: PokemonType) -> Double {
            let groundHitsAnyway = moveType == .ground && (field.gravity || defender.hasItem("ironball") || move.id == "thousandarrows")
            if !defenderAbilityIgnored {
                if let immune = DamageTables.typeImmunityAbilities[defender.ability.id], immune == moveType, !groundHitsAnyway { return 0 }
                if let flag = DamageTables.flagImmunityAbilities[defender.ability.id], move.flags.contains(flag) { return 0 }
                if move.priority > 0, DamageTables.priorityBlockingAbilities.contains(defender.ability.id) { return 0 }
            }
            if moveType == .ground, defender.hasItem("airballoon"), !field.gravity, move.id != "thousandarrows" { return 0 }
            if move.priority > 0, field.terrain == .psychic, defender.isGrounded { return 0 }

            var result = 1.0
            for type in defender.types {
                var single = moveType.effectiveness(against: type).multiplier
                if move.id == "freezedry", type == .water { single = 2 }
                if type == .flying, groundHitsAnyway { single = 1 }
                result *= single
            }
            if defenderHas("wonderguard"), result <= 1 { return 0 }
            return result
        }

        // MARK: Base power

        mutating func resolvedBasePower(moveType: PokemonType, category: MoveCategory, effectiveness: Double) -> Int {
            var power = move.basePower
            switch move.id {
            case "lowkick", "grassknot":
                power = DamageTables.weightBasedPower(targetWeight: defender.pokemon.weight)
            case "heavyslam", "heatcrash":
                power = DamageTables.weightRatioPower(userWeight: attacker.pokemon.weight, targetWeight: defender.pokemon.weight)
            case "electroball":
                power = DamageTables.electroBallPower(userSpeed: attacker.boostedStat(.speed), targetSpeed: defender.boostedStat(.speed))
            case "gyroball":
                let userSpeed = attacker.boostedStat(.speed)
                power = userSpeed == 0 ? 1 : min(150, 25 * defender.boostedStat(.speed) / userSpeed + 1)
            case "hex", "infernalparade":
                if defender.status.isStatused { power *= 2 }
            case "acrobatics":
                if attacker.item == nil { power *= 2 }
            case "storedpower", "powertrip":
                let positive = Stat.allCases.filter { $0 != .hp }.map { max(0, attacker.boosts[$0]) }.reduce(0, +)
                power = 20 + 20 * positive
            case "eruption", "waterspout", "dragonenergy":
                power = max(1, 150 * attacker.currentHP / attacker.maxHP)
            case "flail", "reversal":
                let fraction = 48 * attacker.currentHP / attacker.maxHP
                power = fraction <= 1 ? 200 : fraction <= 4 ? 150 : fraction <= 9 ? 100 : fraction <= 16 ? 80 : fraction <= 32 ? 40 : 20
            case "lastrespects":
                power = 50 + 50 * attacker.faintedAllies
            case "return", "frustration":
                power = 102
            default:
                break
            }
            guard power > 0 else { return 0 }

            var modifiers: [Int] = []

            // Move effects.
            if (move.id == "facade" && [.burn, .poison, .toxic, .paralysis].contains(attacker.status))
                || (move.id == "brine" && defender.currentHP * 2 <= defender.maxHP)
                || (move.id == "venoshock" && [.poison, .toxic].contains(defender.status)) {
                modifiers.append(8192)
            } else if move.id == "expandingforce", field.terrain == .psychic, attacker.isGrounded {
                modifiers.append(6144)
            } else if (move.id == "knockoff" && defender.item != nil)
                || (move.id == "mistyexplosion" && attacker.isGrounded && field.terrain == .misty)
                || (move.id == "gravapple" && field.gravity) {
                modifiers.append(6144)
            } else if ["solarbeam", "solarblade"].contains(move.id), [.rain, .sandstorm, .snow].contains(field.weather) {
                modifiers.append(2048)
                note(field: "in " + field.weather.name)
            } else if ["collisioncourse", "electrodrift"].contains(move.id), effectiveness >= 2 {
                modifiers.append(5461)
            }

            // Terrain.
            if attacker.isGrounded {
                switch (field.terrain, moveType) {
                case (.electric, .electric), (.grassy, .grass), (.psychic, .psychic):
                    modifiers.append(5325)
                    note(field: "in " + field.terrain.name)
                default:
                    break
                }
            }
            if defender.isGrounded {
                if (field.terrain == .misty && moveType == .dragon)
                    || (field.terrain == .grassy && ["bulldoze", "earthquake"].contains(move.id)) {
                    modifiers.append(2048)
                    note(field: "in " + field.terrain.name)
                }
            }

            // Attacker abilities.
            let ability = attackerAbility
            if (ability == "technician" && power <= 60)
                || (ability == "flareboost" && attacker.status == .burn && category == .special)
                || (ability == "toxicboost" && [.poison, .toxic].contains(attacker.status) && category == .physical)
                || (ability == "megalauncher" && move.flags.contains("pulse"))
                || (ability == "strongjaw" && move.flags.contains("bite"))
                || (ability == "steelyspirit" && moveType == .steel)
                || (ability == "sharpness" && move.flags.contains("slicing")) {
                modifiers.append(6144)
                note(attacker: attacker.ability.name)
            }
            if (ability == "sheerforce" && move.effectChance != nil)
                || (ability == "sandforce" && field.weather == .sandstorm && [.rock, .ground, .steel].contains(moveType))
                || (ability == "toughclaws" && move.flags.contains("contact"))
                || (ability == "punkrock" && move.flags.contains("sound")) {
                modifiers.append(5325)
                note(attacker: attacker.ability.name)
            }
            if ability == "supremeoverlord", attacker.faintedAllies > 0 {
                modifiers.append(DamageTables.supremeOverlordModifiers[min(5, attacker.faintedAllies)])
                note(attacker: attacker.ability.name)
            }
            if move.type == .normal, DamageTables.ateAbilities[ability] != nil {
                modifiers.append(4915)
                note(attacker: attacker.ability.name)
            }
            if (ability == "reckless" && (move.recoil != nil || DamageTables.crashMoves.contains(move.id)))
                || (ability == "ironfist" && move.flags.contains("punch")) {
                modifiers.append(4915)
                note(attacker: attacker.ability.name)
            }
            if defenderHas("dryskin"), moveType == .fire {
                modifiers.append(5120)
                note(defender: defender.ability.name)
            }

            // Items.
            if let item = attacker.item {
                if let boosted = DamageTables.typeBoostItems[item.id], boosted == moveType {
                    modifiers.append(4915)
                    note(attacker: item.name)
                } else if let orb = DamageTables.signatureOrbs[item.id], orb.species.contains(attacker.pokemon.speciesID),
                          orb.types.contains(moveType) {
                    modifiers.append(4915)
                    note(attacker: item.name)
                } else if (item.id == "muscleband" && category == .physical)
                    || (item.id == "wiseglasses" && category == .special)
                    || (item.id == "punchingglove" && move.flags.contains("punch")) {
                    modifiers.append(4505)
                    note(attacker: item.name)
                }
            }
            return DamageCalculator.apply(power, DamageCalculator.chain(modifiers, lowerBound: 41))
        }

        // MARK: Attack

        mutating func attackStat(category: MoveCategory, moveType: PokemonType) -> Int {
            let source = move.id == "foulplay" ? defender : attacker
            let stat: Stat = move.id == "bodypress" ? .defense : (category == .physical ? .attack : .specialAttack)
            let rawStat = source.stats[stat]
            let boost = source.boosts[stat]

            var attack: Int
            if boost == 0 || (field.isCritical && boost < 0) {
                attack = rawStat
            } else if defenderHas("unaware") {
                attack = rawStat
                note(defender: defender.ability.name)
            } else {
                attack = DamageCalculator.modified(stat: rawStat, stage: boost)
                attackBoost = boost
            }
            if attacker.hasAbility("hustle"), category == .physical {
                attack = DamageCalculator.pokeRound(Double(attack) * 3 / 2)
                note(attacker: attacker.ability.name)
            }

            var modifiers: [Int] = []
            let ability = attackerAbility
            let lowHP = attacker.currentHP * 3 <= attacker.maxHP
            if (ability == "slowstart" && (category == .physical || move.kind == .zMove))
                || (ability == "defeatist" && attacker.currentHP * 2 <= attacker.maxHP) {
                modifiers.append(2048)
                note(attacker: attacker.ability.name)
            } else if (ability == "solarpower" && field.weather == .sun && category == .special)
                || (ability == "gorillatactics" && category == .physical) {
                modifiers.append(6144)
                note(attacker: attacker.ability.name)
            } else if (ability == "guts" && attacker.status.isStatused && category == .physical)
                || (lowHP && ((ability == "overgrow" && moveType == .grass) || (ability == "blaze" && moveType == .fire)
                              || (ability == "torrent" && moveType == .water) || (ability == "swarm" && moveType == .bug))) {
                modifiers.append(6144)
                note(attacker: attacker.ability.name)
            } else if (ability == "flashfire" && moveType == .fire)
                || (ability == "steelworker" && moveType == .steel)
                || (ability == "dragonsmaw" && moveType == .dragon)
                || (ability == "rockypayload" && moveType == .rock) {
                modifiers.append(6144)
                note(attacker: attacker.ability.name)
            } else if ability == "transistor", moveType == .electric {
                modifiers.append(5325)
                note(attacker: attacker.ability.name)
            } else if (ability == "waterbubble" && moveType == .water)
                || ((ability == "hugepower" || ability == "purepower") && category == .physical) {
                modifiers.append(8192)
                note(attacker: attacker.ability.name)
            }
            if (ability == "hadronengine" && field.terrain == .electric && category == .special)
                || (ability == "orichalcumpulse" && field.weather == .sun && category == .physical) {
                modifiers.append(5461)
                note(attacker: attacker.ability.name)
            }
            if (ability == "protosynthesis" && (field.weather == .sun || attacker.hasItem("boosterenergy")) && attacker.highestStat == stat)
                || (ability == "quarkdrive" && (field.terrain == .electric || attacker.hasItem("boosterenergy")) && attacker.highestStat == stat) {
                modifiers.append(5325)
                note(attacker: attacker.ability.name)
            }

            if (defenderHas("thickfat") && [.fire, .ice].contains(moveType))
                || (defenderHas("waterbubble") && moveType == .fire)
                || (defenderHas("purifyingsalt") && moveType == .ghost)
                || (defenderHas("heatproof") && moveType == .fire) {
                modifiers.append(2048)
                note(defender: defender.ability.name)
            }
            if (defenderHas("tabletsofruin") && category == .physical && ability != "tabletsofruin")
                || (defenderHas("vesselofruin") && category == .special && ability != "vesselofruin") {
                modifiers.append(3072)
                note(defender: defender.ability.name)
            }

            if let item = attacker.item {
                if (item.id == "choiceband" && category == .physical) || (item.id == "choicespecs" && category == .special) {
                    modifiers.append(6144)
                    note(attacker: item.name)
                } else if (item.id == "lightball" && attacker.pokemon.speciesID == "pikachu")
                    || (item.id == "thickclub" && ["cubone", "marowak"].contains(attacker.pokemon.speciesID) && category == .physical) {
                    modifiers.append(8192)
                    note(attacker: item.name)
                }
            }
            return DamageCalculator.apply(attack, DamageCalculator.chain(modifiers))
        }

        // MARK: Defense

        mutating func defenseStat(category: MoveCategory, moveType: PokemonType) -> Int {
            let hitsDefense = category == .physical || DamageTables.physicalDefenseSpecialMoves.contains(move.id)
            let stat: Stat = hitsDefense ? .defense : .specialDefense
            let rawStat = defender.stats[stat]
            let boost = defender.boosts[stat]

            var defense: Int
            if boost == 0 || (field.isCritical && boost > 0) || DamageTables.ignoreDefensiveStagesMoves.contains(move.id) {
                defense = rawStat
            } else if attacker.hasAbility("unaware") {
                defense = rawStat
                note(attacker: attacker.ability.name)
            } else {
                defense = DamageCalculator.modified(stat: rawStat, stage: boost)
                defenseBoost = boost
            }
            if field.weather == .sandstorm, defender.hasType(.rock), !hitsDefense {
                defense = DamageCalculator.pokeRound(Double(defense) * 3 / 2)
                note(field: "in Sandstorm")
            }
            if field.weather == .snow, defender.hasType(.ice), hitsDefense {
                defense = DamageCalculator.pokeRound(Double(defense) * 3 / 2)
                note(field: "in Snow")
            }

            var modifiers: [Int] = []
            if defenderHas("marvelscale"), defender.status.isStatused, hitsDefense {
                modifiers.append(6144)
                note(defender: defender.ability.name)
            } else if defenderHas("grasspelt"), field.terrain == .grassy, hitsDefense {
                modifiers.append(6144)
                note(defender: defender.ability.name)
            } else if defenderHas("furcoat"), hitsDefense {
                modifiers.append(8192)
                note(defender: defender.ability.name)
            }
            if (defenderHas("protosynthesis") && (field.weather == .sun || defender.hasItem("boosterenergy")) && defender.highestStat == stat)
                || (defenderHas("quarkdrive") && (field.terrain == .electric || defender.hasItem("boosterenergy")) && defender.highestStat == stat) {
                modifiers.append(5325)
                note(defender: defender.ability.name)
            }
            if let item = defender.item {
                if (item.id == "eviolite" && !defender.pokemon.isFullyEvolved) || (item.id == "assaultvest" && !hitsDefense) {
                    modifiers.append(6144)
                    note(defender: item.name)
                }
            }
            if (attacker.hasAbility("swordofruin") && hitsDefense && defender.ability.id != "swordofruin")
                || (attacker.hasAbility("beadsofruin") && !hitsDefense && defender.ability.id != "beadsofruin") {
                modifiers.append(3072)
                note(attacker: attacker.ability.name)
            }
            return DamageCalculator.apply(defense, DamageCalculator.chain(modifiers))
        }

        // MARK: Final modifiers

        mutating func finalModifiers(moveType: PokemonType, category: MoveCategory, effectiveness: Double) -> [Int] {
            var modifiers: [Int] = []
            let screenModifier = field.isDoubles ? 2732 : 2048

            if !field.isCritical, !attacker.hasAbility("infiltrator") {
                if field.defenderHasAuroraVeil {
                    modifiers.append(screenModifier)
                    note(field: "through Aurora Veil")
                } else if field.defenderHasReflect, category == .physical {
                    modifiers.append(screenModifier)
                    note(field: "through Reflect")
                } else if field.defenderHasLightScreen, category == .special {
                    modifiers.append(screenModifier)
                    note(field: "through Light Screen")
                }
            }

            if attacker.hasAbility("neuroforce"), effectiveness > 1 {
                modifiers.append(5120)
                note(attacker: attacker.ability.name)
            } else if attacker.hasAbility("sniper"), field.isCritical {
                modifiers.append(6144)
                note(attacker: attacker.ability.name)
            } else if attacker.hasAbility("tintedlens"), effectiveness < 1 {
                modifiers.append(8192)
                note(attacker: attacker.ability.name)
            }

            if defenderHas("multiscale", "shadowshield"), defender.currentHP == defender.maxHP {
                modifiers.append(2048)
                note(defender: defender.ability.name)
            }
            if defenderHas("fluffy"), move.flags.contains("contact"), !attacker.hasAbility("longreach") {
                modifiers.append(2048)
                note(defender: defender.ability.name)
            } else if (defenderHas("punkrock") && move.flags.contains("sound")) || (defenderHas("icescales") && category == .special) {
                modifiers.append(2048)
                note(defender: defender.ability.name)
            }
            if defenderHas("solidrock", "filter", "prismarmor"), effectiveness > 1 {
                modifiers.append(3072)
                note(defender: defender.ability.name)
            }
            if defenderHas("fluffy"), moveType == .fire {
                modifiers.append(8192)
                note(defender: defender.ability.name)
            }

            if let item = attacker.item {
                if item.id == "expertbelt", effectiveness > 1 {
                    modifiers.append(4915)
                    note(attacker: item.name)
                } else if item.id == "lifeorb" {
                    modifiers.append(5324)
                    note(attacker: item.name)
                }
            }
            if let item = defender.item, let berryType = DamageTables.resistBerries[item.id], berryType == moveType,
               effectiveness > 1 || berryType == .normal, !attacker.hasAbility("unnerve") {
                modifiers.append(defenderHas("ripen") ? 1024 : 2048)
                note(defender: item.name)
            }
            return modifiers
        }

        // MARK: Notes and result

        mutating func note(attacker text: String) {
            if !attackerNotes.contains(text) { attackerNotes.append(text) }
        }

        mutating func note(defender text: String) {
            if !defenderNotes.contains(text) { defenderNotes.append(text) }
        }

        mutating func note(field text: String) {
            if !fieldNotes.contains(text) { fieldNotes.append(text) }
        }

        func result(rolls: [Int], moveType: PokemonType, category: MoveCategory, basePower: Int, effectiveness: Double,
                    stab: Bool) -> DamageResult {
            let koChance = rolls.allSatisfy({ $0 == 0 })
                ? KOChance(hits: 0, probability: 0, text: effectiveness == 0 ? "no effect" : "does no damage")
                : KOChance.compute(rolls: rolls, hp: defender.currentHP)
            let attackStat: Stat = move.id == "bodypress" ? .defense : (category == .physical ? .attack : .specialAttack)
            let defenseStat: Stat = category == .physical || DamageTables.physicalDefenseSpecialMoves.contains(move.id) ? .defense : .specialDefense
            return DamageResult(
                rolls: rolls, defenderMaxHP: defender.maxHP, defenderCurrentHP: defender.currentHP, moveType: moveType,
                category: category, basePower: basePower, effectiveness: effectiveness, isSTAB: stab, koChance: koChance,
                attackerDescription: describe(attacker, stat: attackStat, boost: attackBoost, notes: attackerNotes, burned: isBurned, includeHP: false),
                defenderDescription: describe(defender, stat: defenseStat, boost: defenseBoost, notes: defenderNotes, burned: false, includeHP: true),
                fieldDescription: fieldNotes.isEmpty ? "" : " " + fieldNotes.joined(separator: " ")
            )
        }

        private func describe(_ combatant: BattleCombatant, stat: Stat, boost: Int, notes: [String], burned: Bool,
                              includeHP: Bool) -> String {
            var parts: [String] = []
            if boost != 0 { parts.append(boost > 0 ? "+\(boost)" : "\(boost)") }
            var investment = ""
            if includeHP { investment += "\(combatant.evs.hp) HP / " }
            let mark = combatant.nature.increased == stat ? "+" : combatant.nature.decreased == stat ? "-" : ""
            investment += "\(combatant.evs[stat])\(mark) \(stat.showdownAbbreviation)"
            parts.append(investment)
            parts.append(contentsOf: notes)
            if burned { parts.append("burned") }
            if let tera = combatant.teraType { parts.append("Tera \(tera.name)") }
            parts.append(combatant.pokemon.name)
            return parts.joined(separator: " ")
        }
    }
}
