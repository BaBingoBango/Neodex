import NeodexKit
import SwiftUI

/// Unified search across Pokémon, moves, abilities, items and natures.
struct SearchView: View {
    @Environment(\.database) private var database
    @State private var searchText = ""

    private var results: PokedexDatabase.SearchResults {
        database.search(searchText.trimmingCharacters(in: .whitespaces), limitPerCategory: 30)
    }

    var body: some View {
        NavigationStack {
            List {
                if !results.pokemon.isEmpty {
                    Section("Pokémon") {
                        ForEach(results.pokemon) { pokemon in
                            NavigationLink(value: AppRoute.pokemon(pokemon.id)) { PokemonRow(pokemon: pokemon) }
                        }
                    }
                }
                if !results.moves.isEmpty {
                    Section("Moves") {
                        ForEach(results.moves) { move in
                            NavigationLink(value: AppRoute.move(move.id)) { MoveRow(move: move) }
                        }
                    }
                }
                if !results.abilities.isEmpty {
                    Section("Abilities") {
                        ForEach(results.abilities) { ability in
                            NavigationLink(value: AppRoute.ability(ability.id)) { AbilityRow(ability: ability) }
                        }
                    }
                }
                if !results.items.isEmpty {
                    Section("Items") {
                        ForEach(results.items) { item in
                            NavigationLink(value: AppRoute.item(item.id)) { ItemRow(item: item) }
                        }
                    }
                }
                if !results.natures.isEmpty {
                    Section("Natures") {
                        ForEach(results.natures) { nature in
                            NavigationLink(value: AppRoute.nature(nature.id)) {
                                LabeledContent(nature.name, value: nature.summary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search")
            .appDestinations()
            .searchable(text: $searchText, prompt: "Pokémon, moves, abilities, items…")
            .overlay {
                if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView("Search Neodex", systemImage: "magnifyingglass",
                                           description: Text("Find any Pokémon, move, Ability, item or nature."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

#if DEBUG
#Preview { SearchView().previewEnvironment() }
#endif
