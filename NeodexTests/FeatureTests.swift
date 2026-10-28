import AppIntents
import Foundation
import NeodexKit
import Testing
@testable import Neodex

/// The newer features exercised against the real bundled dataset.
@Suite("Intents, calculator, legality and trends")
struct FeatureTests {
    @Test("Siri's Pokémon entity query finds species by name and ID")
    func entityQuery() async throws {
        let query = PokemonEntityQuery()
        let matches = try await query.entities(matching: "garch")
        let first = try #require(matches.first)
        #expect(first.id == "garchomp")
        #expect(String(localized: first.displayRepresentation.title) == "Garchomp")
        #expect(try await query.entities(for: ["pecharunt"]).map(\.name) == ["Pecharunt"])
        #expect(try await query.suggestedEntities().count == 1025)
    }

    @Test("Type matchups can be spoken for every species")
    func spokenMatchups() async throws {
        let database = try await DatabaseProvider.shared.database()
        let charizard = try #require(database.pokemon(id: "charizard"))
        #expect(TypeMatchupSummary.spoken(for: charizard).hasPrefix("Charizard is a Fire and Flying type."))
        for pokemon in database.species {
            #expect(TypeMatchupSummary.spoken(for: pokemon).hasSuffix("."), "\(pokemon.name) has no spoken summary")
        }
    }

    @Test("A sample OU core is legal and an Uber is flagged")
    func legality() async throws {
        let database = try await DatabaseProvider.shared.database()
        let sets = [
            LegalitySet(id: "a", pokemonID: "greattusk", abilityID: "protosynthesis", itemID: "heavydutyboots",
                        moveIDs: ["headlongrush", "knockoff", "rapidspin", "icespinner"]),
            LegalitySet(id: "b", pokemonID: "gholdengo", abilityID: "goodasgold", itemID: "choicescarf",
                        moveIDs: ["makeitrain", "shadowball"]),
        ]
        #expect(FormatLegality.check(sets, format: .ou, database: database).isEmpty)
        let koraidon = try #require(database.pokemon(id: "koraidon"))
        #expect(!FormatLegality.check(pokemon: koraidon, format: .ou).isEmpty)
        #expect(FormatLegality.check(pokemon: koraidon, format: .ubers).isEmpty)
    }

    @Test("Default calculator sets favour the stronger attacking stat")
    func calculatorDefaults() async throws {
        let database = try await DatabaseProvider.shared.database()
        let garchomp = try #require(database.pokemon(id: "garchomp"))
        let side = CalcSide.make(garchomp, database: database)
        let moves = try #require(side.member?.chosenMoveIDs).compactMap { database.move(id: $0) }
        #expect(moves.count == 4)
        #expect(moves.allSatisfy { $0.category == .physical })
        #expect(moves.contains { $0.type == .ground })
        let combatant = try #require(side.combatant(in: database))
        #expect(combatant.stats.hp == 357)
    }

    @Test("Heights round to whole inches before splitting into feet")
    func heightFormatting() {
        #expect(Measurements.feetAndInches(0.6) == "2′00″")
        #expect(Measurements.feetAndInches(1.9) == "6′03″")
        #expect(Measurements.feetAndInches(0.3) == "1′00″")
        #expect(Measurements.height(0.6).hasSuffix("2′00″"))
    }

    @Test("Favorite formats keep their order, persist, and unstar cleanly")
    @MainActor
    func favoriteFormats() throws {
        let suite = "FavoriteFormatsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let favorites = FavoriteFormats(defaults: defaults)
        favorites.toggle("gen9ou")
        favorites.toggle("gen9vgc2026regh")
        favorites.toggle("gen7ou")
        favorites.toggle("gen9vgc2026regh")
        #expect(favorites.ids == ["gen9ou", "gen7ou"])
        #expect(favorites.contains("gen7ou") && !favorites.contains("gen9vgc2026regh"))
        // A favorite outlives the months that don't include it; only unstarring removes it.
        #expect(FavoriteFormats(defaults: defaults).ids == ["gen9ou", "gen7ou"])
        #expect(FavoriteFormats.unavailableNote(month: "2026-09") == "Not played in \(UsageStatsModel.displayMonth("2026-09"))")
    }

    @Test("Usage trend months parse to the first of the month")
    func trendDates() {
        let point = UsageTrendPoint(month: "2026-09", usagePercent: 12.5, rank: 3)
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: point.date)
        #expect(components.year == 2026 && components.month == 9 && components.day == 1)
    }

    @Test("The manifest carries a dataset version and release notes")
    func manifest() async throws {
        let database = try await DatabaseProvider.shared.database()
        let manifest = try #require(database.manifest)
        #expect(manifest.version?.hasPrefix("20") == true)
        #expect(manifest.displayVersion == manifest.version)
        #expect(manifest.releaseNotes?.count == 3)
    }
}
