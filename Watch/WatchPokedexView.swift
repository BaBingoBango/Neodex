import NeodexKit
import SwiftUI

/// Every species, searchable by name or number with dictation or scribble.
struct WatchPokedexView: View {
    var database: PokedexDatabase

    @State private var query = ""

    private var results: [Pokemon] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return database.species }
        if let number = Int(trimmed) { return database.species.filter { $0.nationalDexNumber == number } }
        return database.search(trimmed, limitPerCategory: 40).pokemon
    }

    var body: some View {
        List(results) { pokemon in
            NavigationLink(value: WatchRoute.pokemon(pokemon.id)) {
                WatchPokemonRow(pokemon: pokemon)
            }
        }
        .listStyle(.carousel)
        .searchable(text: $query, prompt: "Name or number")
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Pokédex")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                NavigationLink(value: WatchRoute.pokemon(database.species.randomElement()?.id ?? "pikachu")) {
                    Image(systemName: "dice")
                }
                .accessibilityLabel("Random Pokémon")
            }
        }
        .containerBackground(WatchTheme.neutral, for: .navigation)
        .watchDestinations(database: database)
    }
}

/// A thumbnail, name and dex number.
struct WatchPokemonRow: View {
    var pokemon: Pokemon

    var body: some View {
        HStack(spacing: 10) {
            WatchPokemonImage(pokemon: pokemon)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(pokemon.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("#\(String(format: "%04d", pokemon.nationalDexNumber))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
