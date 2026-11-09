import NeodexKit
import SwiftUI

/// Unified search across Pokémon, moves, abilities, items and natures.
struct SearchView: View {
    @Environment(\.database) private var database
    @State private var searchText = ""
    @State private var router = DeepLinkRouter.shared
    @State private var path = NavigationPath()
    @FocusState private var searchFocused: Bool

    private var results: PokedexDatabase.SearchResults {
        database.search(query, limitPerCategory: 30)
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack(path: $path) {
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
            .searchFocused($searchFocused)
        }
        // The Search quick action on the Home Screen opens this tab ready to type in, whatever entry
        // was left open in it.
        .onChange(of: router.wantsSearchFocus, initial: true) { _, wanted in
            guard wanted else { return }
            router.wantsSearchFocus = false
            path = NavigationPath()
            Task {
                // The field can't take focus until the tab has finished switching in.
                try? await Task.sleep(for: .milliseconds(400))
                searchFocused = true
            }
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
