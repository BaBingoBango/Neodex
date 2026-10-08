import NeodexKit
import SwiftUI

/// The Item Dex: every battle-relevant item.
struct ItemListView: View {
    @Environment(\.database) private var database
    @State private var searchText = ""
    @State private var category: ItemCategory?
    @State private var includePast = true

    private var results: [Item] {
        var items = database.items
        if let category { items = items.filter { $0.category == category } }
        if !includePast { items = items.filter { $0.availability == .current } }
        let query = SearchNormalizer.normalize(searchText)
        if !query.isEmpty {
            items = items.filter { SearchNormalizer.match(SearchNormalizer.normalize($0.name), query: query) != .none }
        }
        return items
    }

    var body: some View {
        List(results) { item in
            NavigationLink(value: AppRoute.item(item.id)) {
                ItemRow(item: item)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Items")
        .searchable(text: $searchText, prompt: "Item name")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Category", selection: $category) {
                        Text("All Categories").tag(ItemCategory?.none)
                        ForEach(ItemCategory.allCases) { Text($0.name).tag(ItemCategory?.some($0)) }
                    }
                    Toggle("Include past-generation items", isOn: $includePast)
                } label: {
                    Label("Filter", systemImage: category != nil || !includePast ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .overlay { if results.isEmpty { ContentUnavailableView.search(text: searchText) } }
    }
}

struct ItemRow: View {
    var item: Item

    var body: some View {
        HStack(spacing: 12) {
            ItemImage(item: item)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.body.weight(.medium))
                if let summary = item.shortDescription ?? item.description {
                    Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if item.availability != .current {
                Image(systemName: "clock")
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Past generations only")
            }
        }
        .padding(.vertical, 2)
    }
}

/// Everything about one item.
struct ItemDetailView: View {
    @Environment(\.database) private var database
    var item: Item

    var body: some View {
        List {
            Section {
                if let description = item.description { Text(description) }
                if let competitive = item.shortDescription, competitive != item.description {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Competitive Effect").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
                        Text(competitive)
                    }
                }
                LabeledContent("Category", value: item.category.name)
                LabeledContent("Generation", value: "Gen \(item.generation)")
                if item.availability != .current { LabeledContent("Availability", value: item.availability.name) }
                if let fling = item.flingPower { LabeledContent("Fling power", value: "\(fling)") }
                if let gift = item.naturalGift {
                    LabeledContent("Natural Gift") { HStack { Text("\(gift.basePower)"); TypeBadge(type: gift.type, size: .small) } }
                }
                if let type = item.associatedType {
                    LabeledContent("Type") { NavigationLink(value: AppRoute.type(type)) { TypeBadge(type: type, size: .small) }.buttonStyle(.plain) }
                }
            } header: {
                HStack(spacing: 14) {
                    ItemImage(item: item).frame(width: 48, height: 48)
                    Text(item.name)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(.primary)
                }
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
            }

            if let species = item.megaEvolves, let pokemon = database.pokemon(named: species) {
                Section("Mega Evolves") {
                    pokemonLink(pokemon)
                }
            }
            if let users = item.users, !users.isEmpty {
                Section("Used By") {
                    ForEach(users.compactMap(database.pokemon(named:))) { pokemonLink($0) }
                }
            }
            let requirers = database.pokemon.filter { $0.requiredItems?.contains(item.id) == true }
            if !requirers.isEmpty {
                Section("Enables") {
                    ForEach(requirers) { pokemonLink($0) }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .recordsHistory(.item, id: item.id)
    }

    private func pokemonLink(_ pokemon: Pokemon) -> some View {
        NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
            HStack(spacing: 12) {
                PokemonImage(pokemon: pokemon, kind: .sprite).frame(width: 44, height: 44)
                Text(pokemon.displayName).font(.body.weight(.medium))
                Spacer()
                TypeBadgeRow(types: pokemon.types, size: .small)
            }
        }
    }
}

#if DEBUG
#Preview("List") { PreviewHost { ItemListView() } }

#Preview("Detail") {
    PreviewHost {
        if let item = PokedexDatabase.preview.item(id: "leftovers") { ItemDetailView(item: item) }
    }
}
#endif
