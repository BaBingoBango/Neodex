import CoreGraphics
import Foundation
import NeodexKit
import Testing
@testable import Neodex

/// Smoke tests that exercise the real bundled dataset inside the app bundle.
/// Logic-level tests live in the NeodexKit package (`Packages/NeodexKit/Tests`).
@Suite("Bundled data")
struct BundledDataTests {
    @Test("The bundled Pokédex loads and is complete")
    func loadsBundledDatabase() async throws {
        let database = try await PokedexDatabase.load(from: .main)
        #expect(database.pokemon.count >= 1300)
        #expect(database.species.count == 1025)
        #expect(database.moves.count >= 900)
        #expect(database.abilities.count >= 300)
        #expect(database.items.count >= 500)
        #expect(database.manifest?.schemaVersion == DataManifest.currentSchemaVersion)
    }

    @Test("Every Pokémon has bundled artwork and a sprite")
    func imagesArePresent() async throws {
        let database = try await PokedexDatabase.load(from: .main)
        var missing: [String] = []
        for pokemon in database.pokemon {
            let hasArtwork = Bundle.main.url(forResource: "\(pokemon.imageID)-art", withExtension: "heic") != nil
            let hasThumbnail = Bundle.main.url(forResource: "\(pokemon.imageID)-thumb", withExtension: "heic") != nil
            let hasSprite = Bundle.main.url(forResource: "\(pokemon.imageID)-sprite", withExtension: "png") != nil
            if !(hasArtwork && hasThumbnail && hasSprite) { missing.append(pokemon.name) }
        }
        #expect(missing.isEmpty, "Missing images for: \(missing.joined(separator: ", "))")
    }

    @Test("No two Pokémon share a name, so lists and search never show twins")
    func displayNamesAreUnique() async throws {
        let database = try await PokedexDatabase.load(from: .main)
        let shared = Dictionary(grouping: database.pokemon, by: \.displayName).filter { $0.value.count > 1 }
        #expect(shared.isEmpty, "Shared names: \(shared.map { "\($0.key) (\($0.value.map(\.id).joined(separator: ", ")))" })")
        #expect(database.pokemon(id: "ogerponwellspringtera")?.displayName == "Wellspring Mask Ogerpon (Terastallized)")
    }

    @Test("Legends: Z-A's Mega Evolutions are in the Pokédex under the names Smogon's statistics use")
    func newerMegaEvolutions() async throws {
        let database = try await PokedexDatabase.load(from: .main)
        // The rows that showed a question mark in Global Stats.
        let names = ["Raichu-Mega-Y": "Mega Raichu Y", "Raichu-Mega-X": "Mega Raichu X", "Floette-Mega": "Mega Floette",
                     "Staraptor-Mega": "Mega Staraptor", "Golisopod-Mega": "Mega Golisopod", "Garchomp-Mega-Z": "Mega Garchomp Z",
                     "Froslass-Mega": "Mega Froslass", "Delphox-Mega": "Mega Delphox", "Dragonite-Mega": "Mega Dragonite",
                     "Meowstic-F-Mega": "Mega Meowstic (Female)", "Tatsugiri-Curly-Mega": "Mega Curly Tatsugiri"]
        for (usageName, displayName) in names {
            let pokemon = try #require(database.pokemon(named: usageName), "\(usageName) is missing")
            #expect(pokemon.displayName == displayName)
            #expect(pokemon.formKind == .mega && pokemon.availability == .future)
            for itemID in pokemon.requiredItems ?? [] {
                #expect(database.item(id: itemID)?.category == .megaStone, "\(usageName) needs unknown stone \(itemID)")
            }
        }
        #expect(database.pokemon.filter { $0.formKind == .mega }.count == 97)
        #expect(database.ability(named: "Dragonize")?.availability == .future)

        // Showdown has a pixel sprite for Mega Dragonite but not yet for Mega Raichu Y, whose artwork stands in.
        func sprite(_ id: String) throws -> CGImage {
            try #require(Bundle.main.url(forResource: "\(id)-sprite", withExtension: "png").flatMap(CGImage.decoded(contentsOf:)))
        }
        #expect(try sprite("dragonitemega").isPixelSprite)
        #expect(try !sprite("raichumegay").isPixelSprite)
    }

    @Test("Showdown names round-trip through the database")
    func showdownNames() async throws {
        let database = try await PokedexDatabase.load(from: .main)
        let set = try #require(ShowdownTeamCodec.parseSet("""
        Great Tusk @ Heavy-Duty Boots
        Ability: Protosynthesis
        Tera Type: Steel
        EVs: 252 Atk / 4 Def / 252 Spe
        Jolly Nature
        - Headlong Rush
        - Ice Spinner
        - Rapid Spin
        - Knock Off
        """))
        #expect(database.pokemon(named: set.species)?.nationalDexNumber == 984)
        #expect(database.item(named: set.item ?? "")?.id == "heavydutyboots")
        #expect(database.ability(named: set.ability ?? "")?.id == "protosynthesis")
        for move in set.moves {
            #expect(database.move(named: move) != nil, "Unknown move \(move)")
        }
    }
}

@Suite("Preview fixture")
struct PreviewFixtureTests {
    @Test("The preview fixture is bundled in debug builds and self-consistent")
    func previewFixture() throws {
        let database = try PokedexDatabase.loadSynchronously(from: .main, subdirectory: nil, filePrefix: "preview-")
        #expect(database.manifest?.schemaVersion == DataManifest.currentSchemaVersion)
        #expect(database.pokemon.count >= 20)
        #expect(database.pokemon(named: "Charizard") != nil)
        #expect(database.item(id: "leftovers") != nil)
        for pokemon in database.pokemon {
            for abilityID in pokemon.abilities.all {
                #expect(database.ability(id: abilityID) != nil, "\(pokemon.name) references unknown ability \(abilityID)")
            }
            for evolution in pokemon.evolutions {
                #expect(database.pokemon(id: evolution.to) != nil, "\(pokemon.name) evolves into unknown \(evolution.to)")
            }
            for form in pokemon.otherFormIDs {
                #expect(database.pokemon(id: form) != nil, "\(pokemon.name) lists unknown form \(form)")
            }
            for itemID in pokemon.requiredItems ?? [] {
                #expect(database.item(id: itemID) != nil, "\(pokemon.name) requires unknown item \(itemID)")
            }
            if pokemon.isBaseForm {
                #expect(!database.learnset(for: pokemon).isEmpty, "\(pokemon.name) has no moves in the fixture")
            }
            #expect(Bundle.main.url(forResource: "\(pokemon.imageID)-thumb", withExtension: "heic") != nil, "\(pokemon.name) has no thumbnail")
        }
    }
}
