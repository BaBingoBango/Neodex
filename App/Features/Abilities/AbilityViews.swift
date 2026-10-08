import NeodexKit
import SwiftUI

/// The Ability Dex.
struct AbilityListView: View {
    @Environment(\.database) private var database
    @State private var searchText = ""

    private var results: [Ability] {
        let query = SearchNormalizer.normalize(searchText)
        guard !query.isEmpty else { return database.abilities }
        return database.abilities.filter { SearchNormalizer.match(SearchNormalizer.normalize($0.name), query: query) != .none }
    }

    var body: some View {
        List(results) { ability in
            NavigationLink(value: AppRoute.ability(ability.id)) {
                AbilityRow(ability: ability)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Abilities")
        .searchable(text: $searchText, prompt: "Ability name")
        .overlay { if results.isEmpty { ContentUnavailableView.search(text: searchText) } }
    }
}

struct AbilityRow: View {
    var ability: Ability

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(ability.name).font(.body.weight(.medium))
            if let summary = ability.shortDescription ?? ability.description {
                Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Everything about one ability, including who can have it.
struct AbilityDetailView: View {
    @Environment(\.database) private var database
    var ability: Ability

    var body: some View {
        List {
            Section {
                if let description = ability.description {
                    Text(description)
                }
                if let competitive = ability.longDescription ?? ability.shortDescription, competitive != ability.description {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Competitive Effect").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
                        Text(competitive)
                    }
                }
                LabeledContent("Generation", value: "Gen \(ability.generation)")
                if let rating = ability.rating {
                    LabeledContent("Smogon Rating") {
                        Text(rating.formatted(.number.precision(.fractionLength(0...1))) + " / 5")
                    }
                }
                if ability.availability != .current {
                    LabeledContent("Availability", value: ability.availability.name)
                }
            } header: {
                Text(ability.name)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
            }

            let holders = database.pokemon(withAbility: ability.id)
            Section("Pokémon with \(ability.name) (\(holders.count))") {
                ForEach(holders) { pokemon in
                    NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
                        HStack(spacing: 12) {
                            PokemonImage(pokemon: pokemon, kind: .sprite)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pokemon.displayName).font(.body.weight(.medium))
                                Text(pokemon.abilities.hidden == ability.id ? "Hidden Ability" : "Ability")
                                    .font(.caption)
                                    .foregroundStyle(pokemon.abilities.hidden == ability.id ? Color.gold : .secondary)
                            }
                            Spacer()
                            TypeBadgeRow(types: pokemon.types, size: .small)
                        }
                    }
                }
            }
        }
        .navigationTitle(ability.name)
        .navigationBarTitleDisplayMode(.inline)
        .recordsHistory(.ability, id: ability.id)
    }
}
