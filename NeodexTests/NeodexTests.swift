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
