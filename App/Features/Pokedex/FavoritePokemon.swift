import NeodexKit
import Observation
import SwiftUI

/// The Pokémon you hearted, in the order you hearted them, kept by Pokémon ID in the App Group's
/// defaults like your favorite formats.
@Observable
@MainActor
final class FavoritePokemon {
    static let shared = FavoritePokemon()
    private static let key = SharedContainer.DefaultsKey.favoritePokemon

    private(set) var ids: [String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = SharedContainer.defaults ?? .standard) {
        self.defaults = defaults
        ids = defaults.stringArray(forKey: Self.key) ?? []
    }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    /// Hearts or un-hearts a Pokémon; new favorites go to the end.
    func toggle(_ id: String) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        defaults.set(ids, forKey: Self.key)
    }
}

/// A heart that adds a Pokémon to Favorites or takes it out.
struct FavoriteButton: View {
    var pokemon: Pokemon
    @State private var favorites = FavoritePokemon.shared

    var body: some View {
        let isFavorite = favorites.contains(pokemon.id)
        Button {
            favorites.toggle(pokemon.id)
        } label: {
            Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.fill" : "heart")
                .contentTransition(.symbolEffect(.replace))
        }
        // Toolbars draw their icons in one colour; a tint is how one stands out.
        .tint(isFavorite ? .pink : .primary)
        .sensoryFeedback(.selection, trigger: isFavorite)
    }
}
