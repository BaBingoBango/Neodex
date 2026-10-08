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
