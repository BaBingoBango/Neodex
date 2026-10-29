import Foundation
import NeodexKit
import Testing
@testable import Neodex

/// Favorite Pokémon and the units setting.
@Suite("Favorites and units")
@MainActor
struct FavoritesAndUnitsTests {
    private func scratchDefaults() throws -> UserDefaults {
        let name = "FavoritesAndUnitsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Hearting a Pokémon saves it, in order, and hearting again takes it out")
    func togglesFavorites() throws {
        let defaults = try scratchDefaults()
        let favorites = FavoritePokemon(defaults: defaults)
        favorites.toggle("garchomp")
        favorites.toggle("pikachu")
        #expect(favorites.ids == ["garchomp", "pikachu"])
        #expect(FavoritePokemon(defaults: defaults).ids == ["garchomp", "pikachu"], "A fresh launch reads them back")
        favorites.toggle("garchomp")
        #expect(favorites.ids == ["pikachu"])
        #expect(!favorites.contains("garchomp"))
    }

    @Test("The Favorites filter keeps only hearted Pokémon")
    func filtersFavorites() async throws {
        let database = try await DatabaseProvider.shared.database()
        var filters = PokedexFilters()
        filters.favoritesOnly = true
        #expect(filters.isActive && filters.activeCount == 1)
        let shown = filters.apply(to: database.pokemon, database: database, favorites: ["pikachu", "garchomp"])
        #expect(Set(shown.map(\.id)) == ["pikachu", "garchomp"])
        #expect(filters.apply(to: database.pokemon, database: database).isEmpty, "No favorites, nothing to show")
    }

    @Test("Heights and weights come in one unit")
    func formatsUnits() {
        #expect(Measurements.height(1.9, in: .metric) == "1.9 m")
        #expect(Measurements.height(1.9, in: .imperial) == "6′03″")
        #expect(Measurements.height(0.6, in: .imperial) == "2′00″")
        #expect(Measurements.weight(95, in: .metric) == "95.0 kg")
        #expect(Measurements.weight(95, in: .imperial) == "209.4 lbs")
        #expect(Measurements.genderRatio(0.875) == "87.5% ♂ · 12.5% ♀")
    }
}
