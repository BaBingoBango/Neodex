import Foundation
import NeodexKit
import Testing
@testable import NeodexDataCore

/// A miniature Showdown + PokeAPI world covering the join rules the real data exercises.
enum Fixture {
    static func json(_ text: String) throws -> [String: JSONValue] {
        try #require(try JSONValue.decode(Data(text.utf8)).object)
    }

    static let pokedex = """
    {
      "bulbasaur": {"num":1,"name":"Bulbasaur","types":["Grass","Poison"],"genderRatio":{"M":0.875,"F":0.125},
        "baseStats":{"hp":45,"atk":49,"def":49,"spa":65,"spd":65,"spe":45},"abilities":{"0":"Overgrow","H":"Chlorophyll"},
        "heightm":0.7,"weightkg":6.9,"color":"Green","evos":["Ivysaur"],"eggGroups":["Monster","Grass"],"tier":"LC"},
      "ivysaur": {"num":2,"name":"Ivysaur","types":["Grass","Poison"],"genderRatio":{"M":0.875,"F":0.125},
        "baseStats":{"hp":60,"atk":62,"def":63,"spa":80,"spd":80,"spe":60},"abilities":{"0":"Overgrow","H":"Chlorophyll"},
        "heightm":1,"weightkg":13,"color":"Green","prevo":"Bulbasaur","evoLevel":16,"eggGroups":["Monster","Grass"],"tier":"NFE"},
      "venusaurmega": {"num":3,"name":"Venusaur-Mega","baseSpecies":"Venusaur","forme":"Mega","types":["Grass","Poison"],
        "genderRatio":{"M":0.875,"F":0.125},"baseStats":{"hp":80,"atk":100,"def":123,"spa":122,"spd":120,"spe":80},
        "abilities":{"0":"Thick Fat"},"heightm":2.4,"weightkg":155.5,"color":"Green","eggGroups":["Monster","Grass"],
        "requiredItem":"Venusaurite","battleOnly":"Venusaur","isNonstandard":"Past","tier":"Illegal"},
      "ogerpon": {"num":1017,"name":"Ogerpon","baseForme":"Teal","types":["Grass"],"gender":"F",
        "baseStats":{"hp":80,"atk":120,"def":84,"spa":60,"spd":96,"spe":110},"abilities":{"0":"Defiant"},
        "heightm":1.2,"weightkg":39.8,"color":"Green","tags":["Sub-Legendary"],"eggGroups":["Undiscovered"],
        "otherFormes":["Ogerpon-Wellspring"],"formeOrder":["Ogerpon","Ogerpon-Wellspring"],"tier":"OU"},
      "ogerponwellspring": {"num":1017,"name":"Ogerpon-Wellspring","baseSpecies":"Ogerpon","forme":"Wellspring",
        "types":["Grass","Water"],"gender":"F","baseStats":{"hp":80,"atk":120,"def":84,"spa":60,"spd":96,"spe":110},
        "abilities":{"0":"Water Absorb"},"heightm":1.2,"weightkg":39.8,"color":"Blue","eggGroups":["Undiscovered"],
        "requiredItem":"Wellspring Mask","changesFrom":"Ogerpon","tier":"OU"},
      "arceus": {"num":493,"name":"Arceus","types":["Normal"],"gender":"N",
        "baseStats":{"hp":120,"atk":120,"def":120,"spa":120,"spd":120,"spe":120},"abilities":{"0":"Multitype"},
        "heightm":3.2,"weightkg":320,"color":"White","eggGroups":["Undiscovered"],"otherFormes":["Arceus-Fire"],
        "formeOrder":["Arceus","Arceus-Fire"],"tier":"Uber"},
      "arceusfire": {"num":493,"name":"Arceus-Fire","baseSpecies":"Arceus","forme":"Fire","types":["Fire"],"gender":"N",
        "baseStats":{"hp":120,"atk":120,"def":120,"spa":120,"spd":120,"spe":120},"abilities":{"0":"Multitype"},
        "heightm":3.2,"weightkg":320,"color":"White","eggGroups":["Undiscovered"],"requiredItem":"Flame Plate",
        "changesFrom":"Arceus","tier":"Uber"},
      "pikachustarter": {"num":25,"name":"Pikachu-Starter","baseSpecies":"Pikachu","forme":"Starter","types":["Electric"],
        "genderRatio":{"M":0.5,"F":0.5},"baseStats":{"hp":45,"atk":80,"def":50,"spa":75,"spd":60,"spe":120},
        "abilities":{"0":"Static"},"heightm":0.4,"weightkg":6,"color":"Yellow","eggGroups":["Undiscovered"],
        "isNonstandard":"LGPE","tier":"Illegal"},
      "futuremon": {"num":2000,"name":"Futuremon","types":["Fire"],"baseStats":{"hp":1,"atk":1,"def":1,"spa":1,"spd":1,"spe":1},
        "abilities":{"0":"Static"},"isNonstandard":"Future"},
      "syclant": {"num":-1,"name":"Syclant","types":["Ice","Bug"],"baseStats":{"hp":70,"atk":116,"def":70,"spa":114,"spd":64,"spe":121},
        "abilities":{"0":"Compound Eyes"},"isNonstandard":"CAP"}
    }
    """

    static let moves = """
    {
      "flamethrower": {"num":53,"accuracy":100,"basePower":90,"category":"Special","name":"Flamethrower","pp":15,"priority":0,
        "flags":{"protect":1,"mirror":1,"metronome":1},"secondary":{"chance":10,"status":"brn"},"target":"normal","type":"Fire"},
      "swordsdance": {"num":14,"accuracy":true,"basePower":0,"category":"Status","name":"Swords Dance","pp":20,"priority":0,
        "flags":{"snatch":1,"metronome":1,"dance":1},"boosts":{"atk":2},"target":"self","type":"Normal"},
      "closecombat": {"num":370,"accuracy":100,"basePower":120,"category":"Physical","name":"Close Combat","pp":5,"priority":0,
        "flags":{"contact":1,"protect":1,"mirror":1,"metronome":1},"self":{"boosts":{"def":-1,"spd":-1}},"target":"normal","type":"Fighting"},
      "hiddenpowerfire": {"num":237,"accuracy":100,"basePower":60,"category":"Special","name":"Hidden Power Fire","pp":15,"priority":0,
        "flags":{"protect":1,"mirror":1},"target":"normal","type":"Fire","isNonstandard":"Past"},
      "gigavolthavoc": {"num":646,"accuracy":true,"basePower":1,"category":"Physical","name":"Gigavolt Havoc","pp":1,"priority":0,
        "flags":{},"isZ":"electriumz","target":"normal","type":"Electric","isNonstandard":"Past"},
      "maxflare": {"num":757,"accuracy":true,"basePower":10,"category":"Physical","name":"Max Flare","pp":10,"priority":0,
        "flags":{},"isMax":true,"target":"adjacentFoe","type":"Fire","isNonstandard":"Past"},
      "gmaxwildfire": {"num":1000,"accuracy":true,"basePower":10,"category":"Physical","name":"G-Max Wildfire","pp":10,"priority":0,
        "flags":{},"isMax":"Charizard","target":"adjacentFoe","type":"Fire","isNonstandard":"Past"},
      "doubleedge": {"num":38,"accuracy":100,"basePower":120,"category":"Physical","name":"Double-Edge","pp":15,"priority":0,
        "flags":{"contact":1,"protect":1},"recoil":[33,100],"target":"normal","type":"Normal"},
      "drainpunch": {"num":409,"accuracy":100,"basePower":75,"category":"Physical","name":"Drain Punch","pp":10,"priority":0,
        "flags":{"contact":1,"protect":1,"punch":1},"drain":[1,2],"target":"normal","type":"Fighting"},
      "bulletseed": {"num":331,"accuracy":100,"basePower":25,"category":"Physical","name":"Bullet Seed","pp":30,"priority":0,
        "flags":{"protect":1,"bullet":1},"multihit":[2,5],"target":"normal","type":"Grass"},
      "fissure": {"num":90,"accuracy":30,"basePower":0,"category":"Physical","name":"Fissure","pp":5,"priority":0,
        "flags":{"protect":1},"ohko":true,"target":"normal","type":"Ground"},
      "slash": {"num":163,"accuracy":100,"basePower":70,"category":"Physical","name":"Slash","pp":20,"priority":0,
        "flags":{"contact":1,"protect":1,"slicing":1},"critRatio":2,"target":"normal","type":"Normal"}
    }
    """

    static let abilities = """
    {
      "overgrow": {"name":"Overgrow","rating":2,"num":65},
      "chlorophyll": {"name":"Chlorophyll","rating":3,"num":34},
      "thickfat": {"name":"Thick Fat","rating":3.5,"num":47},
      "defiant": {"name":"Defiant","rating":3,"num":128},
      "waterabsorb": {"name":"Water Absorb","rating":3.5,"num":11},
      "multitype": {"name":"Multitype","rating":4,"num":121},
      "static": {"name":"Static","rating":2,"num":9},
      "noability": {"name":"No Ability","rating":0.1,"num":0}
    }
    """

    static let items = """
    {
      "leftovers": {"name":"Leftovers","spritenum":242,"fling":{"basePower":10},"num":234,"gen":2},
      "wellspringmask": {"name":"Wellspring Mask","spritenum":759,"fling":{"basePower":60},"itemUser":["Ogerpon-Wellspring"],"num":2407,"gen":9},
      "flameplate": {"name":"Flame Plate","spritenum":146,"onPlate":"Fire","fling":{"basePower":90},"num":298,"gen":4},
      "venusaurite": {"name":"Venusaurite","spritenum":608,"megaStone":"Venusaur-Mega","itemUser":["Venusaur"],"num":659,"gen":6,"isNonstandard":"Past"},
      "sitrusberry": {"name":"Sitrus Berry","spritenum":448,"isBerry":true,"naturalGift":{"basePower":80,"type":"Psychic"},"num":158,"gen":3},
      "choicescarf": {"name":"Choice Scarf","spritenum":69,"fling":{"basePower":10},"isChoice":true,"num":287,"gen":4}
    }
    """

    static let learnsets = """
    {
      "bulbasaur": {"learnset": {"flamethrower":["9M","8M","7M"],"swordsdance":["8M"],"unknownmove":["9L1"],"closecombat":["9L5","9L5","9M"]}},
      "futuremon": {"learnset": {"flamethrower":["9M"]}}
    }
    """

    static let text = """
    {
      "flamethrower": {"name":"Flamethrower","desc":"Has a 10% chance to burn the target.","shortDesc":"10% chance to burn the target."},
      "overgrow": {"name":"Overgrow","shortDesc":"At 1/3 or less of its max HP, this Pokemon's offensive stat is 1.5x with Grass attacks."},
      "leftovers": {"name":"Leftovers","shortDesc":"At the end of every turn, holder restores 1/16 of its max HP."}
    }
    """

    static let typeChart = """
    {"fire": {"damageTaken": {"Water": 1, "Grass": 2, "Fire": 2, "Normal": 0}},
     "ground": {"damageTaken": {"Electric": 3}}}
    """

    static var natures: String {
        "{" + Nature.all.map { nature in
            var fields = ["\"name\":\"\(nature.name)\""]
            if !nature.isNeutral, let plus = nature.increased, let minus = nature.decreased {
                fields += ["\"plus\":\"\(plus.rawValue)\"", "\"minus\":\"\(minus.rawValue)\""]
            }
            return "\"\(nature.id)\":{\(fields.joined(separator: ","))}"
        }.joined(separator: ",") + "}"
    }

    static func showdown() throws -> ShowdownData {
        let text = try json(Self.text)
        return ShowdownData(
            pokedex: try json(pokedex), moves: try json(moves), abilities: try json(abilities), items: try json(items),
            learnsets: try json(learnsets), aliases: [:], abilitiesText: text, movesText: text, itemsText: text,
            natures: try json(natures), typeChart: try json(typeChart)
        )
    }

    static func pokeapi() -> PokeAPIData {
        typealias Species = PokeAPIData.Species
        typealias Row = PokeAPIData.PokemonRow
        let species: [Int: Species] = [
            1: Species(id: 1, identifier: "bulbasaur", generation: 1, evolvesFrom: nil, genderRate: 1, captureRate: 45, baseHappiness: 50,
                       hatchCounter: 20, growthRate: "Medium Slow", isLegendary: false, isMythical: false, name: "Bulbasaur", genus: "Seed"),
            2: Species(id: 2, identifier: "ivysaur", generation: 1, evolvesFrom: 1, genderRate: 1, captureRate: 45, baseHappiness: 50,
                       hatchCounter: 20, growthRate: "Medium Slow", isLegendary: false, isMythical: false, name: "Ivysaur", genus: "Seed"),
            1017: Species(id: 1017, identifier: "ogerpon", generation: 9, evolvesFrom: nil, genderRate: 8, captureRate: 5, baseHappiness: 50,
                          hatchCounter: 10, growthRate: "Slow", isLegendary: false, isMythical: false, name: "Ogerpon", genus: "Mask"),
            493: Species(id: 493, identifier: "arceus", generation: 4, evolvesFrom: nil, genderRate: -1, captureRate: 3, baseHappiness: 0,
                         hatchCounter: 120, growthRate: "Slow", isLegendary: false, isMythical: true, name: "Arceus", genus: "Alpha"),
        ]
        let rows: [Int: Row] = [
            1: Row(id: 1, identifier: "bulbasaur", speciesID: 1, height: 7, weight: 69, baseExperience: 64, isDefault: true,
                   effort: StatBlock(specialAttack: 1), formName: nil, pokemonName: nil),
            2: Row(id: 2, identifier: "ivysaur", speciesID: 2, height: 10, weight: 130, baseExperience: 142, isDefault: true,
                   effort: StatBlock(specialAttack: 1, specialDefense: 1), formName: nil, pokemonName: nil),
            1017: Row(id: 1017, identifier: "ogerpon", speciesID: 1017, height: 12, weight: 398, baseExperience: 275, isDefault: true,
                      effort: StatBlock(attack: 3), formName: "Teal Mask", pokemonName: "Teal Mask Ogerpon"),
            10273: Row(id: 10273, identifier: "ogerpon-wellspring-mask", speciesID: 1017, height: 12, weight: 398, baseExperience: 275,
                       isDefault: false, effort: StatBlock(attack: 3), formName: "Wellspring Mask", pokemonName: "Wellspring Mask Ogerpon"),
            493: Row(id: 493, identifier: "arceus", speciesID: 493, height: 32, weight: 3200, baseExperience: 324, isDefault: true,
                     effort: StatBlock(hp: 3), formName: "Normal", pokemonName: "Arceus"),
        ]
        let versions: [Int: PokeAPIData.Version] = [
            41: .init(id: 41, name: "Violet", order: 25, versionGroupID: 25),
            40: .init(id: 40, name: "Scarlet", order: 25, versionGroupID: 25),
            1: .init(id: 1, name: "Red", order: 1, versionGroupID: 1),
        ]
        return PokeAPIData(
            species: species, pokemon: rows,
            pokemonByIdentifier: Dictionary(uniqueKeysWithValues: rows.values.map { ($0.identifier, $0.id) }),
            defaultPokemonForSpecies: Dictionary(uniqueKeysWithValues: rows.values.filter(\.isDefault).map { ($0.speciesID, $0.id) }),
            flavorTexts: [1: [
                .init(versionID: 41, text: "A strange seed was planted on its back at birth."),
                .init(versionID: 40, text: "A strange seed was planted on its back at birth."),
                .init(versionID: 1, text: "It can go for days without eating a single morsel."),
            ]],
            versions: versions,
            moves: ["flamethrower": .init(id: 53, name: "Flamethrower", generation: 1, effectChance: 10,
                                          flavorText: "The target is scorched with an intense blast of fire.", tmNumber: 62)],
            abilities: ["overgrow": .init(id: 65, name: "Overgrow", generation: 3, flavorText: "Powers up Grass-type moves when the Pokémon's HP is low.")],
            items: ["leftovers": .init(id: 211, name: "Leftovers", category: "held-items", flavorText: "The holder's HP is slowly restored."),
                    "flameplate": .init(id: 298, name: "Flame Plate", category: "plates", flavorText: nil)],
            locations: [1: [41: ["Mesagoza", "Cortondo"], 1: ["Pallet Town"]]]
        )
    }

    static func build() throws -> (Dataset, ShowdownData) {
        let showdown = try showdown()
        let builder = DatasetBuilder(showdown: showdown, pokeapi: pokeapi())
        return (try builder.build(), showdown)
    }
}

@Suite("Dataset builder")
struct DatasetBuilderTests {
    @Test("Species join PokeAPI data by dex number and keep Showdown's competitive fields")
    func joinsSpecies() throws {
        let (dataset, _) = try Fixture.build()
        let bulbasaur = try #require(dataset.pokemon.first { $0.id == "bulbasaur" })
        #expect(bulbasaur.displayName == "Bulbasaur")
        #expect(bulbasaur.genus == "Seed")
        #expect(bulbasaur.catchRate == 45)
        #expect(bulbasaur.growthRate == "Medium Slow")
        #expect(bulbasaur.evYield == StatBlock(specialAttack: 1))
        #expect(bulbasaur.abilities == AbilitySet(primary: "overgrow", hidden: "chlorophyll"))
        #expect(bulbasaur.types == [.grass, .poison])
        #expect(bulbasaur.maleRatio == 0.875)
        #expect(bulbasaur.tier == "LC")
        #expect(bulbasaur.generation == 1)
        #expect(bulbasaur.evolutions == [Evolution(to: "ivysaur", level: 16)])
        #expect(bulbasaur.evolutions.first?.methodDescription == "Level 16")
        #expect(dataset.pokemon.first { $0.id == "ivysaur" }?.evolvesFrom == "bulbasaur")
        #expect(dataset.pokeapiPokemonIDs["bulbasaur"] == 1)
    }

    @Test("Pokédex entries are de-duplicated with their games merged, newest first")
    func dexEntries() throws {
        let (dataset, _) = try Fixture.build()
        let bulbasaur = try #require(dataset.pokemon.first { $0.id == "bulbasaur" })
        #expect(bulbasaur.dexEntries.count == 2)
        #expect(bulbasaur.dexEntries[0].games == ["Pokémon Violet", "Pokémon Scarlet"])
        #expect(bulbasaur.dexEntries[0].gamesSummary == "Violet / Scarlet")
        #expect(bulbasaur.dexEntries[1].games == ["Pokémon Red"])
        #expect(bulbasaur.locations == GameLocations(game: "Pokémon Violet", areas: ["Cortondo", "Mesagoza"]))
    }

    @Test("Forms resolve through the alias table or fall back to their species")
    func forms() throws {
        let (dataset, _) = try Fixture.build()
        let wellspring = try #require(dataset.pokemon.first { $0.id == "ogerponwellspring" })
        #expect(wellspring.displayName == "Wellspring Mask Ogerpon")
        #expect(wellspring.baseSpeciesID == "ogerpon")
        #expect(wellspring.formKind == .other)
        #expect(wellspring.generation == 9)
        #expect(wellspring.requiredItems == ["wellspringmask"])
        #expect(wellspring.changesFrom == "ogerpon")
        #expect(wellspring.otherFormIDs == ["ogerpon"])
        #expect(dataset.pokeapiPokemonIDs["ogerponwellspring"] == 10273)

        let arceusFire = try #require(dataset.pokemon.first { $0.id == "arceusfire" })
        #expect(arceusFire.displayName == "Arceus (Fire)")
        #expect(arceusFire.tags == ["Mythical"])
        #expect(arceusFire.evYield == StatBlock(hp: 3))
        #expect(dataset.pokeapiPokemonIDs["arceusfire"] == nil)
        #expect(dataset.notes.first?.contains("Arceus-Fire") == true)

        let mega = try #require(dataset.pokemon.first { $0.id == "venusaurmega" })
        #expect(mega.displayName == "Mega Venusaur")
        #expect(mega.formKind == .mega)
        #expect(mega.generation == 6)
        #expect(mega.isBattleOnly)
        #expect(mega.availability == .past)
        #expect(mega.requiredItems == ["venusaurite"])
    }

    @Test("Ordering follows dex number then Showdown's form order")
    func ordering() throws {
        let (dataset, _) = try Fixture.build()
        #expect(dataset.pokemon.map(\.id) == ["bulbasaur", "ivysaur", "venusaurmega", "pikachustarter", "arceus", "arceusfire", "ogerpon", "ogerponwellspring"])
        #expect(dataset.pokemon.first { $0.id == "pikachustarter" }?.availability == .letsGo)
        #expect(dataset.spriteIDs["ogerponwellspring"] == "ogerpon-wellspring")
    }

    @Test("Moves carry effects, descriptions and TM numbers; special move kinds are classified")
    func moves() throws {
        let (dataset, _) = try Fixture.build()
        func move(_ id: String) throws -> Move { try #require(dataset.moves.first { $0.id == id }) }
        #expect(dataset.moves.map(\.id).contains("hiddenpowerfire") == false)
        let flamethrower = try move("flamethrower")
        #expect(flamethrower.effectChance == 10)
        #expect(flamethrower.tmNumber == 62)
        #expect(flamethrower.description == "The target is scorched with an intense blast of fire.")
        #expect(flamethrower.shortDescription == "10% chance to burn the target.")
        #expect(flamethrower.flags == ["metronome", "mirror", "protect"])
        #expect(flamethrower.generation == 1)
        #expect(try move("swordsdance").statChanges == [StatChange(stat: .attack, stages: 2, affectsUser: true)])
        #expect(try move("closecombat").statChanges == [StatChange(stat: .defense, stages: -1, affectsUser: true),
                                                        StatChange(stat: .specialDefense, stages: -1, affectsUser: true)])
        #expect(try move("gigavolthavoc").kind == .zMove)
        #expect(try move("maxflare").kind == .maxMove)
        #expect(try move("gmaxwildfire").kind == .gigantamaxMove)
        #expect(try move("doubleedge").recoil == [33, 100])
        #expect(try move("drainpunch").drain == [1, 2])
        #expect(try move("bulletseed").multiHit == [2, 5])
        #expect(try move("fissure").isOneHitKO)
        #expect(try move("slash").critRatio == 2)
        #expect(try move("swordsdance").accuracy == nil)
    }

    @Test("Abilities and items are categorised and described")
    func abilitiesAndItems() throws {
        let (dataset, _) = try Fixture.build()
        #expect(dataset.abilities.map(\.id).contains("noability") == false)
        let overgrow = try #require(dataset.abilities.first { $0.id == "overgrow" })
        #expect(overgrow.description == "Powers up Grass-type moves when the Pokémon's HP is low.")
        #expect(overgrow.shortDescription?.hasPrefix("At 1/3") == true)
        #expect(overgrow.generation == 3)
        #expect(overgrow.rating == 2)

        func item(_ id: String) throws -> Item { try #require(dataset.items.first { $0.id == id }) }
        #expect(try item("leftovers").category == .held)
        #expect(try item("leftovers").description == "The holder's HP is slowly restored.")
        #expect(try item("wellspringmask").category == .signature)
        #expect(try item("flameplate").category == .plate)
        #expect(try item("flameplate").associatedType == .fire)
        #expect(try item("venusaurite").category == .megaStone)
        #expect(try item("venusaurite").megaEvolves == "Venusaur")
        #expect(try item("venusaurite").availability == .past)
        #expect(try item("sitrusberry").category == .berry)
        #expect(try item("sitrusberry").naturalGift == NaturalGift(basePower: 80, type: .psychic))
        #expect(try item("choicescarf").category == .choice)
    }

    @Test("Learnsets keep the newest generation, drop unknown moves and de-duplicate")
    func learnsets() throws {
        let (dataset, _) = try Fixture.build()
        let learnset = try #require(dataset.learnsets["bulbasaur"])
        #expect(learnset.moves["flamethrower"] == [LearnSource(code: "9M")!])
        #expect(learnset.moves["swordsdance"] == [LearnSource(code: "8M")!])
        #expect(learnset.moves["unknownmove"] == nil)
        #expect(learnset.moves["closecombat"] == [LearnSource(code: "9L5")!, LearnSource(code: "9M")!])
        #expect(dataset.learnsets["futuremon"] == nil)
    }

    @Test("Verification passes for a consistent dataset and fails on dangling references")
    func verification() throws {
        let (dataset, showdown) = try Fixture.build()
        let warnings = try Verifier.verify(dataset, showdown: showdown)
        #expect(warnings.contains { $0.contains("without learnsets") })

        var broken = dataset
        broken.pokemon[0].abilities = AbilitySet(primary: "doesnotexist")
        #expect(throws: Verifier.VerificationError.self) {
            try Verifier.verify(broken, showdown: showdown)
        }
    }
}

@Suite("Preview fixture")
struct PreviewFixtureTests {
    @Test("Selection is closed under forms and evolutions and keeps what the Pokémon need")
    func selection() throws {
        let (dataset, _) = try Fixture.build()
        let subset = PreviewFixture.select(pokemon: dataset.pokemon, moves: dataset.moves, abilities: dataset.abilities,
                                           items: dataset.items, learnsets: dataset.learnsets)
        let ids = Set(subset.pokemon.map(\.id))
        #expect(ids.contains("bulbasaur") && ids.contains("ivysaur"))          // evolution family
        #expect(ids.contains("ogerpon") && ids.contains("ogerponwellspring"))  // forms
        #expect(!ids.contains("arceus"))                                       // not seeded
        #expect(Set(subset.moves.map(\.id)) == ["flamethrower", "swordsdance", "closecombat"])
        #expect(Set(subset.abilities.map(\.id)) == ["overgrow", "chlorophyll", "defiant", "waterabsorb"])
        #expect(subset.items.map(\.id).contains("wellspringmask"))
        #expect(subset.items.map(\.id).contains("leftovers"))
        #expect(subset.learnsets.keys.sorted() == ["bulbasaur"])
    }

    @Test("Writes prefixed files that the kit can load back")
    func roundTrip() async throws {
        let (dataset, _) = try Fixture.build()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("neodex-fixture-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try Writer.write(dataset, to: directory.appendingPathComponent("Data"), pretty: false)
        let summary = try PreviewFixture.write(from: directory.appendingPathComponent("Data"),
                                               to: directory.appendingPathComponent("Preview"))
        #expect(summary.pokemon == 4)
        let database = try await PokedexDatabase.load(from: directory.appendingPathComponent("Preview"), filePrefix: "preview-")
        #expect(database.pokemon.count == 4)
        #expect(database.pokemon(named: "Ogerpon-Wellspring")?.requiredItems == ["wellspringmask"])
        #expect(database.item(id: "wellspringmask") != nil)
        #expect(database.manifest?.counts.pokemon == 4)
    }
}
