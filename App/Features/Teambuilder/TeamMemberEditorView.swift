import NeodexKit
import SwiftData
import SwiftUI

/// Edits a single set on a team: species, item, ability, nature, moves, EVs and IVs.
struct TeamMemberEditorView: View {
    @Environment(\.database) private var database
    @Bindable var team: SavedTeam
    var memberIndex: Int

    @State private var changingPokemon = false
    @State private var showingImport = false

    private var member: Binding<TeamMember> {
        Binding(
            get: { team.members[memberIndex] },
            set: { team.members[memberIndex] = $0; team.touch() }
        )
    }

    var body: some View {
        if memberIndex < team.members.count, let pokemon = database.pokemon(id: team.members[memberIndex].pokemonID) {
            Form {
                speciesSection(pokemon)
                detailsSection(pokemon)
                movesSection(pokemon)
                statsSection(pokemon)
            }
            .navigationTitle(pokemon.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Copy Set", systemImage: "doc.on.doc") {
                            TeamConversion.copyToPasteboard(TeamConversion.exportText(for: member.wrappedValue, database: database))
                        }
                        Button("Paste Set", systemImage: "doc.on.clipboard") { showingImport = true }
                        NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
                            Label("View in Pokédex", systemImage: "book")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $changingPokemon) {
                PokemonPickerSheet(title: "Change Pokémon") { newPokemon in
                    var updated = TeamMember(pokemon: newPokemon)
                    updated.id = member.wrappedValue.id
                    updated.level = member.wrappedValue.level
                    member.wrappedValue = updated
                }
            }
            .alert("Paste a Showdown set", isPresented: $showingImport) {
                Button("Paste from Clipboard") { pasteSet() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Copy a single set from Pokémon Showdown, then paste it here to replace this Pokémon.")
            }
        } else {
            ContentUnavailableView("Removed", systemImage: "trash", description: Text("This Pokémon is no longer on the team."))
        }
    }

    // MARK: Sections

    private func speciesSection(_ pokemon: Pokemon) -> some View {
        Section {
            Button {
                changingPokemon = true
            } label: {
                HStack(spacing: 12) {
                    PokemonImage(pokemon: pokemon, kind: .thumbnail).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pokemon.displayName).font(.headline).foregroundStyle(.primary)
                        TypeBadgeRow(types: pokemon.types, size: .small)
                    }
                    Spacer()
                    Text("Change").foregroundStyle(.tint)
                }
            }
            .buttonStyle(.plain)
            TextField("Nickname", text: Binding(get: { member.wrappedValue.nickname ?? "" },
                                                set: { member.wrappedValue.nickname = $0.isEmpty ? nil : $0 }))
            if pokemon.maleRatio != nil {
                Picker("Gender", selection: member.gender) {
                    if pokemon.maleRatio ?? 0 > 0 { Text("Male").tag(String?.some("M")) }
                    if pokemon.maleRatio ?? 0 < 1 { Text("Female").tag(String?.some("F")) }
                    Text("Unspecified").tag(String?.none)
                }
            }
            Stepper("Level \(member.wrappedValue.level)", value: member.level, in: 1...100)
            Toggle("Shiny", isOn: member.shiny)
        }
    }

    private func detailsSection(_ pokemon: Pokemon) -> some View {
        Section("Battle Details") {
            NavigationLink {
                ItemPickerList(selection: member.itemID)
            } label: {
                LabeledContent("Item", value: member.wrappedValue.itemID.flatMap { database.item(id: $0)?.name } ?? "None")
            }
            Picker("Ability", selection: member.abilityID) {
                ForEach(pokemon.abilities.all, id: \.self) { id in
                    Text(abilityLabel(id, pokemon: pokemon)).tag(String?.some(id))
                }
            }
            NavigationLink {
                NaturePickerList(selection: member.natureID)
            } label: {
                LabeledContent("Nature") {
                    let nature = Nature.named(member.wrappedValue.natureID) ?? .serious
                    Text("\(nature.name) (\(nature.summary))")
                }
            }
            Picker("Tera Type", selection: member.teraType) {
                Text("None").tag(PokemonType?.none)
                ForEach(PokemonType.allCases) { Text($0.name).tag(PokemonType?.some($0)) }
            }
        }
    }

    private func abilityLabel(_ id: String, pokemon: Pokemon) -> String {
        let name = database.ability(id: id)?.name ?? id
        return pokemon.abilities.hidden == id ? "\(name) (Hidden)" : name
    }

    private func movesSection(_ pokemon: Pokemon) -> some View {
        Section {
            ForEach(0..<4, id: \.self) { slot in
                NavigationLink {
                    MovePickerList(selection: Binding(get: { member.wrappedValue.moveIDs[slot] },
                                                      set: { member.wrappedValue.moveIDs[slot] = $0 }),
                                   candidates: database.learnset(for: pokemon))
                } label: {
                    if let moveID = member.wrappedValue.moveIDs[slot], let move = database.move(id: moveID) {
                        MoveRow(move: move)
                    } else {
                        Text("Move \(slot + 1)").foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    if member.wrappedValue.moveIDs[slot] != nil {
                        Button("Clear", systemImage: "xmark", role: .destructive) { member.wrappedValue.moveIDs[slot] = nil }
                    }
                }
            }
        } header: {
            Text("Moves")
        } footer: {
            Text("Only moves \(pokemon.displayName) can learn are offered.")
        }
    }

    private func statsSection(_ pokemon: Pokemon) -> some View {
        let current = member.wrappedValue
        let stats = current.calculatedStats(for: pokemon)
        let nature = Nature.named(current.natureID) ?? .serious
        return Section {
            ForEach(Stat.allCases) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(stat.shortName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(nature.modifier(for: stat) > 1 ? .green : nature.modifier(for: stat) < 1 ? .red : .primary)
                        Spacer()
                        Text("Base \(pokemon.baseStats[stat])")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(stats[stat])")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack(spacing: 10) {
                        Text("EV")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Slider(value: Binding(get: { Double(current.evs[stat]) },
                                              set: { setEV(Int($0.rounded()), for: stat) }),
                               in: 0...Double(StatCalculator.maximumStatEVs), step: 4)
                        Text("\(current.evs[stat])")
                            .font(.caption.monospacedDigit())
                            .frame(width: 30, alignment: .trailing)
                        Stepper("IV", value: Binding(get: { current.ivs[stat] }, set: { member.wrappedValue.ivs[stat] = $0 }), in: 0...31)
                            .labelsHidden()
                        Text("\(current.ivs[stat])")
                            .font(.caption.monospacedDigit())
                            .frame(width: 22, alignment: .trailing)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text("Stats")
                Spacer()
                Text("\(current.remainingEVs) EVs left")
                    .foregroundStyle(current.remainingEVs < 0 ? .red : .secondary)
            }
        } footer: {
            Text("Stats are calculated at level \(current.level) with a \(nature.name) nature. Sliders move in steps of 4 EVs; the total cannot exceed \(StatCalculator.maximumTotalEVs).")
        }
    }

    private func setEV(_ value: Int, for stat: Stat) {
        var evs = member.wrappedValue.evs
        let others = evs.total - evs[stat]
        evs[stat] = max(0, min(value, StatCalculator.maximumTotalEVs - others, StatCalculator.maximumStatEVs))
        member.wrappedValue.evs = evs
    }

    private func pasteSet() {
        guard let text = UIPasteboard.general.string, let set = ShowdownTeamCodec.parseSet(text) else { return }
        guard let pokemon = database.pokemon(named: set.species) else { return }
        var warnings: [String] = []
        var updated = TeamConversion.member(from: set, pokemon: pokemon, database: database, warnings: &warnings)
        updated.id = member.wrappedValue.id
        member.wrappedValue = updated
    }
}

/// Searchable item chooser grouped by category.
struct ItemPickerList: View {
    @Environment(\.database) private var database
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String?
    @State private var searchText = ""

    private var results: [Item] {
        let query = SearchNormalizer.normalize(searchText)
        let items = database.items.filter { $0.availability == .current || $0.id == selection }
        guard !query.isEmpty else { return items }
        return items.filter { SearchNormalizer.match(SearchNormalizer.normalize($0.name), query: query) != .none }
    }

    var body: some View {
        List {
            Button("No item") { selection = nil; dismiss() }
            ForEach(results) { item in
                Button {
                    selection = item.id
                    dismiss()
                } label: {
                    HStack {
                        ItemRow(item: item)
                        if selection == item.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Item name")
        .navigationTitle("Item")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Nature chooser showing each nature's stat effect.
struct NaturePickerList: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    var body: some View {
        List(Nature.all) { nature in
            Button {
                selection = nature.id
                dismiss()
            } label: {
                HStack {
                    Text(nature.name)
                    Spacer()
                    Text(nature.summary)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(nature.isNeutral ? .secondary : .primary)
                    if selection == nature.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Nature")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview { PreviewHost { TeamMemberEditorView(team: PreviewStore.sampleTeam, memberIndex: 0) } }
#endif
