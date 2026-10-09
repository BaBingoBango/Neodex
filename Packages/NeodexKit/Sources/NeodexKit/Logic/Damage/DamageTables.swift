import Foundation

/// Lookup tables for the items, abilities and moves the damage calculator understands.
enum DamageTables {
    /// Items that boost moves of one type by 20%.
    static let typeBoostItems: [String: PokemonType] = [
        "silkscarf": .normal, "charcoal": .fire, "mysticwater": .water, "magnet": .electric, "miracleseed": .grass,
        "nevermeltice": .ice, "blackbelt": .fighting, "poisonbarb": .poison, "softsand": .ground, "sharpbeak": .flying,
        "twistedspoon": .psychic, "silverpowder": .bug, "hardstone": .rock, "spelltag": .ghost, "dragonfang": .dragon,
        "blackglasses": .dark, "metalcoat": .steel, "fairyfeather": .fairy,
        "seaincense": .water, "waveincense": .water, "oddincense": .psychic, "rockincense": .rock, "roseincense": .grass,
        "flameplate": .fire, "splashplate": .water, "zapplate": .electric, "meadowplate": .grass, "icicleplate": .ice,
        "fistplate": .fighting, "toxicplate": .poison, "earthplate": .ground, "skyplate": .flying, "mindplate": .psychic,
        "insectplate": .bug, "stoneplate": .rock, "spookyplate": .ghost, "dracoplate": .dragon, "dreadplate": .dark,
        "ironplate": .steel, "pixieplate": .fairy,
    ]

    /// Signature orbs that boost two types for particular species (20%).
    static let signatureOrbs: [String: (species: [String], types: [PokemonType])] = [
        "adamantorb": (["dialga"], [.steel, .dragon]), "adamantcrystal": (["dialga"], [.steel, .dragon]),
        "lustrousorb": (["palkia"], [.water, .dragon]), "lustrousglobe": (["palkia"], [.water, .dragon]),
        "griseousorb": (["giratina"], [.ghost, .dragon]), "griseouscore": (["giratina"], [.ghost, .dragon]),
        "souldew": (["latias", "latios"], [.psychic, .dragon]),
    ]

    /// Berries that halve one super-effective hit of a type (Chilan halves any Normal hit).
    static let resistBerries: [String: PokemonType] = [
        "occaberry": .fire, "passhoberry": .water, "wacanberry": .electric, "rindoberry": .grass, "yacheberry": .ice,
        "chopleberry": .fighting, "kebiaberry": .poison, "shucaberry": .ground, "cobaberry": .flying, "payapaberry": .psychic,
        "tangaberry": .bug, "chartiberry": .rock, "kasibberry": .ghost, "habanberry": .dragon, "colburberry": .dark,
        "babiriberry": .steel, "roseliberry": .fairy, "chilanberry": .normal,
    ]

    /// Abilities that grant immunity to a type.
    static let typeImmunityAbilities: [String: PokemonType] = [
        "flashfire": .fire, "wellbakedbody": .fire,
        "waterabsorb": .water, "stormdrain": .water, "dryskin": .water,
        "voltabsorb": .electric, "lightningrod": .electric, "motordrive": .electric,
        "sapsipper": .grass, "eartheater": .ground, "levitate": .ground,
    ]

    /// Abilities that grant immunity to moves with a flag.
    static let flagImmunityAbilities: [String: String] = [
        "soundproof": "sound", "bulletproof": "bullet", "windrider": "wind",
    ]

    /// Abilities that block priority moves.
    static let priorityBlockingAbilities: Set<String> = ["queenlymajesty", "dazzling", "armortail"]

    /// Abilities that ignore the defender's ability.
    static let moldBreakerAbilities: Set<String> = ["moldbreaker", "teravolt", "turboblaze"]

    /// Defender abilities that cannot be ignored.
    static let unbreakableAbilities: Set<String> = ["fullmetalbody", "neutralizinggas", "prismarmor", "shadowshield"]

    /// Moves that ignore the defender's ability.
    static let abilityIgnoringMoves: Set<String> = ["sunsteelstrike", "moongeistbeam", "photongeyser", "lightthatburnsthesky"]

    /// Abilities that turn Normal-type moves into another type with a 20% boost.
    static let ateAbilities: [String: PokemonType] = [
        "aerilate": .flying, "pixilate": .fairy, "refrigerate": .ice, "galvanize": .electric,
    ]

    /// Moves whose user takes crash damage on a miss (for Reckless).
    static let crashMoves: Set<String> = ["highjumpkick", "jumpkick", "axekick", "supercellslam"]

    /// Special moves that hit the target's Defense.
    static let physicalDefenseSpecialMoves: Set<String> = ["psyshock", "psystrike", "secretsword"]

    /// Moves that ignore the target's stat stages.
    static let ignoreDefensiveStagesMoves: Set<String> = ["chipaway", "sacredsword", "darkestlariat"]

    /// Supreme Overlord's boost for 0…5 fainted allies.
    static let supremeOverlordModifiers = [4096, 4506, 4915, 5325, 5734, 6144]

    static func weatherBallType(_ weather: Weather) -> PokemonType {
        switch weather {
        case .sun: .fire
        case .rain: .water
        case .sandstorm: .rock
        case .snow: .ice
        case .none: .normal
        }
    }

    static func terrainPulseType(_ terrain: Terrain) -> PokemonType {
        switch terrain {
        case .electric: .electric
        case .grassy: .grass
        case .psychic: .psychic
        case .misty: .fairy
        case .none: .normal
        }
    }

    /// Ivy Cudgel and Raging Bull change type with the user's form.
    static func formSignatureType(move: String, pokemonID: String) -> PokemonType? {
        switch (move, pokemonID) {
        case ("ivycudgel", let id) where id.hasPrefix("ogerponwellspring"): .water
        case ("ivycudgel", let id) where id.hasPrefix("ogerponhearthflame"): .fire
        case ("ivycudgel", let id) where id.hasPrefix("ogerponcornerstone"): .rock
        case ("ragingbull", "taurospaldeablaze"): .fire
        case ("ragingbull", "taurospaldeaaqua"): .water
        case ("ragingbull", "taurospaldeacombat"): .fighting
        default: nil
        }
    }

    static func weightBasedPower(targetWeight: Double) -> Int {
        switch targetWeight {
        case 200...: 120
        case 100...: 100
        case 50...: 80
        case 25...: 60
        case 10...: 40
        default: 20
        }
    }

    static func weightRatioPower(userWeight: Double, targetWeight: Double) -> Int {
        let ratio = targetWeight > 0 ? userWeight / targetWeight : 5
        return switch ratio {
        case 5...: 120
        case 4...: 100
        case 3...: 80
        case 2...: 60
        default: 40
        }
    }

    static func electroBallPower(userSpeed: Int, targetSpeed: Int) -> Int {
        guard targetSpeed > 0 else { return 40 }
        return switch userSpeed / targetSpeed {
        case 4...: 150
        case 3: 120
        case 2: 80
        case 1: 60
        default: 40
        }
    }
}
