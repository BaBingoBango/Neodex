import NeodexKit
import SwiftUI

/// Sort orders for the Pokédex.
enum PokedexSort: String, CaseIterable, Identifiable {
    case dexNumber, name, total, hp, attack, defense, specialAttack, specialDefense, speed, height, weight

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dexNumber: "Dex Number"
        case .name: "Name"
        case .total: "Base Stat Total"
        case .hp: "HP"
        case .attack: "Attack"
        case .defense: "Defense"
        case .specialAttack: "Sp. Atk"
        case .specialDefense: "Sp. Def"
        case .speed: "Speed"
        case .height: "Height"
        case .weight: "Weight"
        }
    }

    func sorted(_ pokemon: [Pokemon]) -> [Pokemon] {
        switch self {
        case .dexNumber: pokemon
        case .name: pokemon.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .total: pokemon.sorted { ($0.baseStats.total, $1.nationalDexNumber) > ($1.baseStats.total, $0.nationalDexNumber) }
        case .hp: pokemon.sorted { $0.baseStats.hp > $1.baseStats.hp }
        case .attack: pokemon.sorted { $0.baseStats.attack > $1.baseStats.attack }
        case .defense: pokemon.sorted { $0.baseStats.defense > $1.baseStats.defense }
        case .specialAttack: pokemon.sorted { $0.baseStats.specialAttack > $1.baseStats.specialAttack }
        case .specialDefense: pokemon.sorted { $0.baseStats.specialDefense > $1.baseStats.specialDefense }
        case .speed: pokemon.sorted { $0.baseStats.speed > $1.baseStats.speed }
        case .height: pokemon.sorted { $0.height > $1.height }
        case .weight: pokemon.sorted { $0.weight > $1.weight }
        }
    }

    /// Secondary text shown in the row when sorting by something other than dex number.
    func detail(for pokemon: Pokemon) -> String? {
        switch self {
        case .dexNumber, .name: nil
        case .total: "BST \(pokemon.baseStats.total)"
        case .hp: "HP \(pokemon.baseStats.hp)"
        case .attack: "Atk \(pokemon.baseStats.attack)"
        case .defense: "Def \(pokemon.baseStats.defense)"
        case .specialAttack: "SpA \(pokemon.baseStats.specialAttack)"
        case .specialDefense: "SpD \(pokemon.baseStats.specialDefense)"
        case .speed: "Spe \(pokemon.baseStats.speed)"
        case .height: Measurements.height(pokemon.height)
        case .weight: Measurements.weight(pokemon.weight)
        }
    }
}

/// Filter criteria for the Pokédex list.
struct PokedexFilters: Equatable {
    var types: Set<PokemonType> = []
    var generations: Set<Int> = []
    var formKinds: Set<FormKind> = []
    var baseFormsOnly = false
    var currentGamesOnly = false
    var legendaryOnly = false
    var fullyEvolvedOnly = false
    var eggGroup: String?
    var abilityID: String?
    var moveID: String?

    var isActive: Bool { self != PokedexFilters() }

    var activeCount: Int {
        [!types.isEmpty, !generations.isEmpty, !formKinds.isEmpty, baseFormsOnly, currentGamesOnly, legendaryOnly,
         fullyEvolvedOnly, eggGroup != nil, abilityID != nil, moveID != nil].filter { $0 }.count
    }

    func apply(to pokemon: [Pokemon], database: PokedexDatabase) -> [Pokemon] {
        guard isActive else { return pokemon }
        return pokemon.filter { entry in
            if !types.isEmpty, !types.isSubset(of: Set(entry.types)) { return false }
            if !generations.isEmpty, !generations.contains(entry.generation) { return false }
            if !formKinds.isEmpty, entry.formKind.map({ !formKinds.contains($0) }) ?? true { return false }
            if baseFormsOnly, !entry.isBaseForm { return false }
            if currentGamesOnly, entry.availability != .current { return false }
            if legendaryOnly, !(entry.isLegendary || entry.isMythical || entry.isSubLegendary) { return false }
            if fullyEvolvedOnly, !entry.evolutions.isEmpty { return false }
            if let eggGroup, !entry.eggGroups.contains(eggGroup) { return false }
            if let abilityID, !entry.abilities.contains(abilityID) { return false }
            if let moveID, !database.canLearn(entry, moveID: moveID) { return false }
            return true
        }
    }
}

/// The filter sheet.
struct PokedexFilterSheet: View {
    @Environment(\.database) private var database
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: PokedexFilters

    private var eggGroups: [String] {
        Array(Set(database.pokemon.flatMap(\.eggGroups))).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Types") {
                    FlowLayout(spacing: 8) {
                        ForEach(PokemonType.allCases) { type in
                            Button {
                                if filters.types.contains(type) { filters.types.remove(type) }
                                else if filters.types.count < 2 { filters.types.insert(type) }
                            } label: {
                                TypeBadge(type: type, size: .small)
                                    .opacity(filters.types.isEmpty || filters.types.contains(type) ? 1 : 0.35)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    Text("Pick up to two types. Pokémon must have every selected type.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Generation") {
                    FlowLayout(spacing: 8) {
                        ForEach(1...9, id: \.self) { generation in
                            Toggle("Gen \(generation)", isOn: Binding(
                                get: { filters.generations.contains(generation) },
                                set: { on in if on { filters.generations.insert(generation) } else { filters.generations.remove(generation) } }
                            ))
                            .toggleStyle(.button)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                Section("Forms") {
                    Toggle("Base forms only", isOn: $filters.baseFormsOnly)
                    ForEach(FormKind.allCases, id: \.self) { kind in
                        Toggle(kind.name, isOn: Binding(
                            get: { filters.formKinds.contains(kind) },
                            set: { on in if on { filters.formKinds.insert(kind) } else { filters.formKinds.remove(kind) } }
                        ))
                        .disabled(filters.baseFormsOnly)
                    }
                }
                Section("Traits") {
                    Toggle("Legendary, Mythical or Sub-Legendary", isOn: $filters.legendaryOnly)
                    Toggle("Fully evolved", isOn: $filters.fullyEvolvedOnly)
                    Toggle("Available in current games", isOn: $filters.currentGamesOnly)
                    Picker("Egg group", selection: $filters.eggGroup) {
                        Text("Any").tag(String?.none)
                        ForEach(eggGroups, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                }
                Section("Ability & Move") {
                    NavigationLink {
                        AbilityPickerList(selection: $filters.abilityID)
                    } label: {
                        LabeledContent("Ability", value: filters.abilityID.flatMap { database.ability(id: $0)?.name } ?? "Any")
                    }
                    NavigationLink {
                        MovePickerList(selection: $filters.moveID)
                    } label: {
                        LabeledContent("Can learn move", value: filters.moveID.flatMap { database.move(id: $0)?.name } ?? "Any")
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { filters = PokedexFilters() }
                        .disabled(!filters.isActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Searchable single-selection list of abilities, for filters and the team editor.
struct AbilityPickerList: View {
    @Environment(\.database) private var database
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String?
    var candidates: [Ability]? = nil
    @State private var searchText = ""

    private var results: [Ability] {
        let source = candidates ?? database.abilities
        let query = SearchNormalizer.normalize(searchText)
        guard !query.isEmpty else { return source }
        return source.filter { SearchNormalizer.match(SearchNormalizer.normalize($0.name), query: query) != .none }
    }

    var body: some View {
        List {
            if candidates == nil {
                Button("Any ability") { selection = nil; dismiss() }
            }
            ForEach(results) { ability in
                Button {
                    selection = ability.id
                    dismiss()
                } label: {
                    HStack {
                        AbilityRow(ability: ability)
                        Spacer()
                        if selection == ability.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Ability name")
        .navigationTitle("Ability")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Searchable single-selection list of moves, for filters and the team editor.
struct MovePickerList: View {
    @Environment(\.database) private var database
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String?
    var candidates: [LearnedMove]? = nil
    @State private var searchText = ""

    private var results: [Move] {
        let source = candidates?.map(\.move) ?? database.moves.filter { $0.kind == .standard }
        let query = SearchNormalizer.normalize(searchText)
        guard !query.isEmpty else { return source }
        return source.filter { SearchNormalizer.match(SearchNormalizer.normalize($0.name), query: query) != .none }
    }

    var body: some View {
        List {
            if candidates == nil {
                Button("Any move") { selection = nil; dismiss() }
            }
            ForEach(results) { move in
                Button {
                    selection = move.id
                    dismiss()
                } label: {
                    HStack {
                        MoveRow(move: move, trailing: candidates?.first { $0.move.id == move.id }?.sources.first?.label)
                        if selection == move.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Move name")
        .navigationTitle("Move")
        .navigationBarTitleDisplayMode(.inline)
    }
}
