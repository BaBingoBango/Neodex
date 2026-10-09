import Foundation
import Testing
@testable import NeodexKit

@Suite("Format legality")
struct FormatLegalityTests {
    static func fixture() -> PokedexDatabase {
        func pokemon(_ id: String, _ name: String, number: Int, types: [PokemonType], abilities: AbilitySet, tier: String?,
                     availability: Availability = .current, baseSpeciesID: String? = nil, formName: String? = nil) -> Pokemon {
            Pokemon(id: id, name: name, displayName: name, nationalDexNumber: number, generation: 9, baseSpeciesID: baseSpeciesID,
                    formName: formName, types: types, abilities: abilities, baseStats: StatBlock(repeating: 80), height: 1, weight: 10, maleRatio: nil,
                    tier: tier, availability: availability, imageID: id)
        }
        let garchomp = pokemon("garchomp", "Garchomp", number: 445, types: [.dragon, .ground],
                               abilities: AbilitySet(primary: "sandveil", hidden: "roughskin"), tier: "UUBL")
        let koraidon = pokemon("koraidon", "Koraidon", number: 1007, types: [.fighting, .dragon],
                               abilities: AbilitySet(primary: "orichalcumpulse"), tier: "Uber")
        let pikachu = pokemon("pikachu", "Pikachu", number: 25, types: [.electric],
                              abilities: AbilitySet(primary: "static", hidden: "lightningrod"), tier: "ZU")
        let eevee = pokemon("eevee", "Eevee", number: 133, types: [.normal],
                            abilities: AbilitySet(primary: "runaway", secondary: "adaptability", hidden: "moody"), tier: "LC")
        let charizard = pokemon("charizard", "Charizard", number: 6, types: [.fire, .flying],
                                abilities: AbilitySet(primary: "blaze", hidden: "solarpower"), tier: "ZUBL")
        let megaX = pokemon("charizardmegax", "Charizard-Mega-X", number: 6, types: [.fire, .dragon],
                            abilities: AbilitySet(primary: "toughclaws"), tier: "Illegal", availability: .past,
                            baseSpeciesID: "charizard", formName: "Mega-X")
        func move(_ id: String, _ name: String, type: PokemonType, category: MoveCategory = .physical, power: Int = 80,
                  ohko: Bool = false, availability: Availability = .current) -> Move {
            Move(id: id, name: name, type: type, category: category, basePower: power, accuracy: 100, pp: 10, priority: 0,
                 target: "normal", flags: [], generation: 1, availability: availability, isOneHitKO: ohko)
        }
        let moves = [
            move("earthquake", "Earthquake", type: .ground),
            move("doubleteam", "Double Team", type: .normal, category: .status, power: 0),
            move("fissure", "Fissure", type: .ground, ohko: true),
            move("batonpass", "Baton Pass", type: .normal, category: .status, power: 0),
            move("thunderbolt", "Thunderbolt", type: .electric, category: .special, power: 90),
            move("pursuit", "Pursuit", type: .dark, power: 40, availability: .past),
        ]
        let abilities = ["sandveil", "roughskin", "orichalcumpulse", "static", "lightningrod", "runaway", "adaptability", "moody",
                         "blaze", "solarpower", "toughclaws", "arenatrap"].map { Ability(id: $0, name: $0.capitalized, generation: 9) }
        let items = [
            Item(id: "brightpowder", name: "Bright Powder", category: .held, generation: 2),
            Item(id: "leftovers", name: "Leftovers", category: .held, generation: 2),
            Item(id: "charizarditex", name: "Charizardite X", category: .megaStone, generation: 6, availability: .past),
        ]
        let learnsets = [
            "garchomp": Learnset(moves: ["earthquake": [LearnSource(code: "9M")!], "fissure": [LearnSource(code: "9M")!],
                                         "doubleteam": [LearnSource(code: "9M")!]]),
            "pikachu": Learnset(moves: ["thunderbolt": [LearnSource(code: "9M")!], "doubleteam": [LearnSource(code: "9M")!]]),
            "eevee": Learnset(moves: ["batonpass": [LearnSource(code: "9L1")!], "pursuit": [LearnSource(code: "7L1")!]]),
            "charizard": Learnset(moves: ["earthquake": [LearnSource(code: "9M")!]]),
        ]
        return PokedexDatabase(pokemon: [garchomp, koraidon, pikachu, eevee, charizard, megaX], moves: moves,
                               abilities: abilities, items: items, learnsets: learnsets)
    }

    @Test("Format IDs and names")
    func formats() {
        #expect(SmogonFormat(formatID: "gen9ou") == .ou)
        #expect(SmogonFormat(formatID: "Gen 9 OU") == .ou)
        #expect(SmogonFormat(formatID: "GEN9UBERS") == .ubers)
        #expect(SmogonFormat(formatID: "gen9vgc2026") == nil)
        #expect(SmogonFormat.ou.name == "Gen 9 OU")
        #expect(!SmogonFormat.anythingGoes.usesStandardClauses && SmogonFormat.ubers.usesStandardClauses)
        #expect(TierRank(showdownTier: "(PU)") == .pu)
        #expect(TierRank(showdownTier: "Illegal") == nil)
    }

    @Test("The tier ladder decides where a Pokémon may be used")
    func tierLadder() throws {
        let db = Self.fixture()
        let garchomp = try #require(db.pokemon(id: "garchomp"))
        let koraidon = try #require(db.pokemon(id: "koraidon"))
        let pikachu = try #require(db.pokemon(id: "pikachu"))
        let eevee = try #require(db.pokemon(id: "eevee"))
        let megaX = try #require(db.pokemon(id: "charizardmegax"))

        #expect(FormatLegality.check(pokemon: garchomp, format: .ou).isEmpty)
        #expect(FormatLegality.check(pokemon: garchomp, format: .uu).first?.message == "Garchomp is UUBL, which is banned from Gen 9 UU.")
        #expect(FormatLegality.check(pokemon: koraidon, format: .ou).first?.message == "Koraidon is Uber, which is banned from Gen 9 OU.")
        #expect(FormatLegality.check(pokemon: koraidon, format: .ubers).isEmpty)
        #expect(FormatLegality.check(pokemon: koraidon, format: .anythingGoes).isEmpty)
        #expect(FormatLegality.check(pokemon: eevee, format: .lc).isEmpty)
        #expect(FormatLegality.check(pokemon: garchomp, format: .lc).first?.message == "Garchomp isn't a Little Cup Pokémon.")
        #expect(FormatLegality.check(pokemon: megaX, format: .anythingGoes).first?.message == "Charizard-Mega-X isn't available in the current games.")

        #expect(FormatLegality.legalFormats(for: garchomp) == [.anythingGoes, .ubers, .ou])
        #expect(FormatLegality.legalFormats(for: pikachu) == SmogonFormat.allCases.filter { $0 != .lc })
        #expect(FormatLegality.legalFormats(for: eevee) == SmogonFormat.allCases)
        #expect(FormatLegality.legalFormats(for: megaX).isEmpty)
    }

    @Test("Standard clauses apply outside Anything Goes")
    func clauses() {
        let db = Self.fixture()
        let team = [
            LegalitySet(id: "a", pokemonID: "garchomp", abilityID: "roughskin", itemID: "brightpowder", moveIDs: ["earthquake", "fissure", "doubleteam"]),
            LegalitySet(id: "b", pokemonID: "garchomp", abilityID: "arenatrap", itemID: "leftovers", moveIDs: ["thunderbolt"]),
            LegalitySet(id: "c", pokemonID: "eevee", abilityID: "moody", itemID: "charizarditex", moveIDs: ["batonpass", "pursuit"]),
            LegalitySet(id: "d", pokemonID: "missingno"),
        ]
        let ou = FormatLegality.check(team, format: .ou, database: db)
        let messages = Dictionary(grouping: ou, by: { $0.setID ?? "team" }).mapValues { $0.map(\.message) }
        #expect(messages["a"] == ["Evasion Items Clause: Bright Powder is banned.", "OHKO Clause: Fissure is banned.",
                                  "Evasion Moves Clause: Double Team is banned."])
        #expect(messages["b"] == ["Species Clause: Garchomp is already on the team as Garchomp.", "Garchomp can't have Arenatrap.",
                                  "Garchomp can't learn Thunderbolt."])
        #expect(messages["c"] == ["Moody is banned in Gen 9 OU.", "Charizardite X isn't available in the current games.",
                                  "Baton Pass is banned in Gen 9 OU.", "Pursuit isn't available in the current games."])
        #expect(messages["d"] == ["Unknown Pokémon."])

        let ag = FormatLegality.check(team, format: .anythingGoes, database: db)
        #expect(ag.map(\.message) == ["Garchomp can't have Arenatrap.", "Garchomp can't learn Thunderbolt.",
                                      "Charizardite X isn't available in the current games.",
                                      "Pursuit isn't available in the current games.", "Unknown Pokémon."])
    }

    @Test("Little Cup requires level 5")
    func littleCup() {
        let db = Self.fixture()
        let grown = FormatLegality.check([LegalitySet(id: "e", pokemonID: "eevee", level: 100)], format: .lc, database: db)
        #expect(grown.map(\.message) == ["Little Cup Pokémon must be level 5."])
        let baby = FormatLegality.check([LegalitySet(id: "e", pokemonID: "eevee", level: 5)], format: .lc, database: db)
        #expect(baby.isEmpty)
    }
}
