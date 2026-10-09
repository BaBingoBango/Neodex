import Foundation
import Testing
@testable import NeodexKit

@Suite("Pokédex database")
struct DatabaseTests {
    static func fixture() -> PokedexDatabase {
        let bulbasaur = Pokemon(id: "bulbasaur", name: "Bulbasaur", displayName: "Bulbasaur", nationalDexNumber: 1, generation: 1,
                                types: [.grass, .poison], abilities: AbilitySet(primary: "overgrow", hidden: "chlorophyll"),
                                baseStats: StatBlock(hp: 45, attack: 49, defense: 49, specialAttack: 65, specialDefense: 65, speed: 45),
                                height: 0.7, weight: 6.9, maleRatio: 0.875, evolutions: [Evolution(to: "ivysaur", level: 16)],
                                imageID: "bulbasaur")
        let ivysaur = Pokemon(id: "ivysaur", name: "Ivysaur", displayName: "Ivysaur", nationalDexNumber: 2, generation: 1,
                              types: [.grass, .poison], abilities: AbilitySet(primary: "overgrow", hidden: "chlorophyll"),
                              baseStats: StatBlock(hp: 60, attack: 62, defense: 63, specialAttack: 80, specialDefense: 80, speed: 60),
                              height: 1, weight: 13, maleRatio: 0.875, evolvesFrom: "bulbasaur",
                              evolutions: [Evolution(to: "venusaur", level: 32)], imageID: "ivysaur")
        let venusaurMega = Pokemon(id: "venusaurmega", name: "Venusaur-Mega", displayName: "Mega Venusaur", nationalDexNumber: 3,
                                   generation: 6, baseSpeciesID: "venusaur", formName: "Mega", formKind: .mega, isBattleOnly: true,
                                   types: [.grass, .poison], abilities: AbilitySet(primary: "thickfat"),
                                   baseStats: StatBlock(hp: 80, attack: 100, defense: 123, specialAttack: 122, specialDefense: 120, speed: 80),
                                   height: 2.4, weight: 155.5, maleRatio: 0.875, availability: .past, imageID: "venusaurmega")
        let venusaur = Pokemon(id: "venusaur", name: "Venusaur", displayName: "Venusaur", nationalDexNumber: 3, generation: 1,
                               types: [.grass, .poison], abilities: AbilitySet(primary: "overgrow", hidden: "chlorophyll"),
                               baseStats: StatBlock(hp: 80, attack: 82, defense: 83, specialAttack: 100, specialDefense: 100, speed: 80),
                               height: 2, weight: 100, maleRatio: 0.875, evolvesFrom: "ivysaur", otherFormIDs: ["venusaurmega"],
                               imageID: "venusaur")
        let tackle = Move(id: "tackle", name: "Tackle", type: .normal, category: .physical, basePower: 40, accuracy: 100, pp: 35,
                          priority: 0, target: "normal", flags: ["contact"], generation: 1)
        let solarBeam = Move(id: "solarbeam", name: "Solar Beam", type: .grass, category: .special, basePower: 120, accuracy: 100,
                             pp: 10, priority: 0, target: "normal", flags: [], tmNumber: 168, generation: 1)
        let overgrow = Ability(id: "overgrow", name: "Overgrow", generation: 3)
        let chlorophyll = Ability(id: "chlorophyll", name: "Chlorophyll", generation: 3)
        let thickFat = Ability(id: "thickfat", name: "Thick Fat", generation: 3)
        let learnsets = [
            "bulbasaur": Learnset(moves: ["tackle": [LearnSource(code: "9L1")!], "solarbeam": [LearnSource(code: "9M")!]]),
            "venusaur": Learnset(moves: ["solarbeam": [LearnSource(code: "9M")!, LearnSource(code: "9L1")!]]),
        ]
        return PokedexDatabase(pokemon: [bulbasaur, ivysaur, venusaur, venusaurMega], moves: [solarBeam, tackle],
                               abilities: [chlorophyll, overgrow, thickFat], items: [], learnsets: learnsets)
    }

    @Test("Lookups by ID and tolerant name")
    func lookups() throws {
        let db = Self.fixture()
        #expect(db.pokemon(id: "ivysaur")?.name == "Ivysaur")
        #expect(db.pokemon(named: "venusaur-mega")?.id == "venusaurmega")
        #expect(db.pokemon(named: "VENUSAUR MEGA")?.id == "venusaurmega")
        #expect(db.move(named: "solar beam")?.id == "solarbeam")
        #expect(db.ability(named: "Thick Fat")?.id == "thickfat")
        #expect(db.pokemon(dexNumber: 3).map(\.id) == ["venusaur", "venusaurmega"])
    }

    @Test("Forms, evolution family and reverse indexes")
    func relationships() throws {
        let db = Self.fixture()
        let mega = try #require(db.pokemon(id: "venusaurmega"))
        #expect(db.forms(of: mega).map(\.id) == ["venusaur", "venusaurmega"])
        #expect(db.baseForm(of: mega).id == "venusaur")
        let family = db.evolutionFamily(of: mega)
        #expect(family.map(\.id) == ["bulbasaur", "ivysaur", "venusaur"])
        #expect(db.rootOfEvolutionLine(for: db.pokemon(id: "venusaur")!).id == "bulbasaur")
        #expect(db.pokemon(withAbility: "chlorophyll").map(\.id) == ["bulbasaur", "ivysaur", "venusaur"])
        #expect(db.species.map(\.id) == ["bulbasaur", "ivysaur", "venusaur"])
    }

    @Test("Learnsets resolve and fall back to the base species")
    func learnsets() throws {
        let db = Self.fixture()
        let bulbasaur = try #require(db.pokemon(id: "bulbasaur"))
        let learned = db.learnset(for: bulbasaur)
        #expect(learned.map(\.move.id) == ["solarbeam", "tackle"])
        #expect(learned[1].levelUpLevel() == 1)
        let mega = try #require(db.pokemon(id: "venusaurmega"))
        // Falls back to Venusaur's learnset and inherits Bulbasaur's Tackle through the line.
        #expect(db.learnset(for: mega).map(\.move.id) == ["solarbeam", "tackle"])
        #expect(db.canLearn(mega, moveID: "solarbeam"))
        #expect(db.canLearn(mega, moveID: "tackle"))
        #expect(!db.canLearn(mega, moveID: "vinewhip"))
        #expect(db.lineage(of: mega).map(\.id) == ["venusaurmega", "venusaur", "ivysaur", "bulbasaur"])
        #expect(db.learnSources(for: mega, moveID: "solarbeam")?.count == 2)   // Venusaur 9M + 9L1; Bulbasaur 9M is a duplicate
        let solarBeam = try #require(db.move(id: "solarbeam"))
        #expect(db.learners(of: solarBeam).map(\.pokemon.id) == ["bulbasaur", "ivysaur", "venusaur", "venusaurmega"])
    }

    @Test("Search ranks across categories and understands dex numbers")
    func search() {
        let db = Self.fixture()
        let results = db.search("venu")
        #expect(results.pokemon.map(\.id) == ["venusaur", "venusaurmega"])
        #expect(db.search("3").pokemon.first?.id == "venusaur")
        #expect(db.search("solar").moves.map(\.id) == ["solarbeam"])
        #expect(db.search("chloro").abilities.map(\.id) == ["chlorophyll"])
        #expect(db.search("adamant").natures.map(\.name) == ["Adamant"])
        #expect(db.search("   ").isEmpty)
    }

    @Test("Loads the generated dataset when it is present", .enabled(if: generatedDataDirectory != nil))
    func loadsGeneratedData() async throws {
        let directory = try #require(Self.generatedDataDirectory)
        let db = try await PokedexDatabase.load(from: directory)
        #expect(db.pokemon.count > 1000)
        #expect(db.moves.count > 900)
        #expect(db.abilities.count > 300)
        #expect(db.items.count > 400)
        let pecharunt = try #require(db.pokemon(named: "Pecharunt"))
        #expect(pecharunt.nationalDexNumber == 1025)
        for entry in db.pokemon {
            for abilityID in entry.abilities.all {
                #expect(db.ability(id: abilityID) != nil, "\(entry.name) references unknown ability \(abilityID)")
            }
            for evolution in entry.evolutions {
                #expect(db.pokemon(id: evolution.to) != nil, "\(entry.name) evolves into unknown \(evolution.to)")
            }
        }
    }

    /// `App/Resources/Data` relative to the package, if the pipeline has been run.
    static var generatedDataDirectory: URL? {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/Data")
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("pokemon.json").path) ? url : nil
    }
}
