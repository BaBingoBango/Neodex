import NeodexKit
import SwiftUI

/// Unified search across Pokémon, moves, abilities, items and natures.
struct SearchView: View {
    @Environment(\.database) private var database
    @State private var searchText = ""

    private var results: PokedexDatabase.SearchResults {
        database.search(query, limitPerCategory: 30)
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    SearchBrowseView()
                } else {
                    resultList
                }
            }
            .navigationTitle("Search")
            // A pinned search field starts a large title collapsed, so the title stays small, as on Global Stats.
            .inlineNavigationTitle()
            .navigationDestination(for: AppTab.self) { $0.content }
            .appDestinations()
            .searchable(text: $searchText, placement: .pinned, prompt: "Pokémon, moves, abilities, items…")
        }
    }

    private var resultList: some View {
        List {
            if !results.pokemon.isEmpty {
                Section("Pokémon") {
                    ForEach(results.pokemon) { pokemon in
                        NavigationLink(value: AppRoute.pokemon(pokemon.id)) { PokemonRow(pokemon: pokemon) }
                            .entryActions(AppRoute.pokemon(pokemon.id))
                    }
                }
            }
            if !results.moves.isEmpty {
                Section("Moves") {
                    ForEach(results.moves) { move in
                        NavigationLink(value: AppRoute.move(move.id)) { MoveRow(move: move) }
                            .entryActions(AppRoute.move(move.id))
                    }
                }
            }
            if !results.abilities.isEmpty {
                Section("Abilities") {
                    ForEach(results.abilities) { ability in
                        NavigationLink(value: AppRoute.ability(ability.id)) { AbilityRow(ability: ability) }
                            .entryActions(AppRoute.ability(ability.id))
                    }
                }
            }
            if !results.items.isEmpty {
                Section("Items") {
                    ForEach(results.items) { item in
                        NavigationLink(value: AppRoute.item(item.id)) { ItemRow(item: item) }
                            .entryActions(AppRoute.item(item.id))
                    }
                }
            }
            if !results.natures.isEmpty {
                Section("Natures") {
                    ForEach(results.natures) { nature in
                        NavigationLink(value: AppRoute.nature(nature.id)) {
                            LabeledContent(nature.name, value: nature.summary)
                        }
                        .entryActions(AppRoute.nature(nature.id))
                    }
                }
            }
        }
        .groupedListStyle()
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}

#if DEBUG
#Preview { SearchView().previewEnvironment() }
#endif
