import NeodexKit
import SwiftUI

/// Pokédex tab root.
struct PokedexListView: View {
    var body: some View {
        NavigationStack {
            PokedexListContent()
                .appDestinations()
        }
    }
}

/// The National Pokédex: every species and form, searchable, filterable and sortable.
struct PokedexListContent: View {
    @Environment(\.database) private var database
    @State private var searchText = ""
    @State private var filters = PokedexFilters()
    @State private var sort: PokedexSort = .dexNumber
    @State private var layout: PokedexLayout = .list
    @State private var showingFilters = false

    private var results: [Pokemon] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        var pokemon = trimmed.isEmpty ? database.pokemon : database.search(trimmed, limitPerCategory: 400).pokemon
        pokemon = filters.apply(to: pokemon, database: database)
        if trimmed.isEmpty || sort != .dexNumber { pokemon = sort.sorted(pokemon) }
        return pokemon
    }

    var body: some View {
        Group {
            switch layout {
            case .list:
                List(results) { pokemon in
                    NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
                        PokemonRow(pokemon: pokemon, detail: sort.detail(for: pokemon))
                    }
                }
                .listStyle(.plain)
            case .grid:
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                        ForEach(results) { pokemon in
                            NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
                                VStack(spacing: 2) {
                                    PokemonImage(pokemon: pokemon, kind: .thumbnail)
                                        .frame(width: 72, height: 72)
                                    Text(pokemon.formattedDexNumber)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(6)
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(pokemon.displayName)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Pokédex")
        .searchable(text: $searchText, prompt: "Name or number")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    layout = layout == .list ? .grid : .list
                } label: {
                    Label(layout == .list ? "Grid" : "List", systemImage: layout == .list ? "square.grid.3x3" : "list.bullet")
                }
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(PokedexSort.allCases) { Text($0.name).tag($0) }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                Button {
                    showingFilters = true
                } label: {
                    Label("Filter", systemImage: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            PokedexFilterSheet(filters: $filters)
        }
        .overlay {
            if results.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("No Matches", systemImage: "line.3.horizontal.decrease.circle", description: Text("Try removing some filters."))
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

enum PokedexLayout { case list, grid }

/// A Pokédex list row: thumbnail, name, number and types.
struct PokemonRow: View {
    var pokemon: Pokemon
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            PokemonImage(pokemon: pokemon, kind: .thumbnail)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(pokemon.displayName)
                    .font(.headline)
                Text(detail ?? pokemon.formattedDexNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(pokemon.types) { TypeBadge(type: $0, size: .small) }
            }
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
#Preview { PokedexListView().previewEnvironment() }
#endif
