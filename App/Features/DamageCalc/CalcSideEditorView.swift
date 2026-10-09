import NeodexKit
import SwiftUI

/// Edits one side of a damage calculation: the set, its battle state and its stat investment.
struct CalcSideEditorView: View {
    @Environment(\.database) private var database
    var role: CalcRole
    @Binding var side: CalcSide

    @State private var changingPokemon = false
    @State private var showingPaste = false

    var body: some View {
        if let current = side.member, let pokemon = database.pokemon(id: current.pokemonID) {
            let member = Binding(get: { side.member ?? current }, set: { side.member = $0 })
            Form {
                speciesSection(pokemon, member)
                battleStateSection(pokemon, member)
                setSection(pokemon, member)
                movesSection(pokemon, member)
                statsSection(pokemon, member)
            }
            .navigationTitle(role.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Paste Showdown Set", systemImage: "doc.on.clipboard") { showingPaste = true }
                        Button("Reset Battle State", systemImage: "arrow.counterclockwise") {
                            side.boosts = .zero
                            side.status = .none
                            side.hpPercent = 100
                            side.terastallized = false
                            side.faintedAllies = 0
                        }
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
                    side = CalcSide.make(newPokemon, database: database)
                }
            }
            .alert("Paste a Showdown set", isPresented: $showingPaste) {
                Button("Paste from Clipboard") { pasteSet() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Copy a single set from Pokémon Showdown, then paste it here to replace this Pokémon.")
            }
        } else {
            ContentUnavailableView("No Pokémon", systemImage: "questionmark.circle")
        }
    }

    // MARK: Sections

    private func speciesSection(_ pokemon: Pokemon, _ member: Binding<TeamMember>) -> some View {
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
            Stepper("Level \(member.wrappedValue.level)", value: member.level, in: 1...100)
        }
    }

    private func battleStateSection(_ pokemon: Pokemon, _ member: Binding<TeamMember>) -> some View {
        Section {
            Picker("Status", selection: $side.status) {
                ForEach(StatusCondition.allCases) { Text($0.name).tag($0) }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("HP")
                    Spacer()
                    Text("\(Int(side.hpPercent))%").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $side.hpPercent, in: 1...100, step: 1)
            }
            ForEach([Stat.attack, .defense, .specialAttack, .specialDefense, .speed]) { stat in
                Stepper(value: Binding(get: { side.boosts[stat] }, set: { side.boosts[stat] = $0 }), in: -6...6) {
                    HStack {
                        Text(stat.shortName)
                        Spacer()
                        Text(stageText(side.boosts[stat]))
                            .monospacedDigit()
                            .foregroundStyle(side.boosts[stat] > 0 ? .green : side.boosts[stat] < 0 ? .red : .secondary)
                    }
                }
            }
            if let tera = member.wrappedValue.teraType {
                Toggle("Terastallized (\(tera.name))", isOn: $side.terastallized)
            }
            if member.wrappedValue.abilityID == "supremeoverlord" || member.wrappedValue.chosenMoveIDs.contains("lastrespects") {
                Stepper("Fainted allies: \(side.faintedAllies)", value: $side.faintedAllies, in: 0...5)
            }
        } header: {
            Text("Battle State")
        } footer: {
            Text("Stat stages, status and remaining HP as they are right now in the battle.")
        }
    }

    private func setSection(_ pokemon: Pokemon, _ member: Binding<TeamMember>) -> some View {
        Section("Set") {
            NavigationLink {
                ItemPickerList(selection: member.itemID)
            } label: {
                LabeledContent("Item", value: member.wrappedValue.itemID.flatMap { database.item(id: $0)?.name } ?? "None")
            }
            Picker("Ability", selection: member.abilityID) {
                ForEach(abilityChoices(pokemon, current: member.wrappedValue.abilityID), id: \.self) { id in
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

    private func abilityChoices(_ pokemon: Pokemon, current: String?) -> [String] {
        var ids = pokemon.abilities.all
        if let current, !ids.contains(current) { ids.append(current) }
        return ids
    }

    private func abilityLabel(_ id: String, pokemon: Pokemon) -> String {
        let name = database.ability(id: id)?.name ?? id
        return pokemon.abilities.hidden == id ? "\(name) (Hidden)" : name
    }

    private func movesSection(_ pokemon: Pokemon, _ member: Binding<TeamMember>) -> some View {
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
            Text("Only moves \(pokemon.displayName) can learn are offered. Status moves do no damage.")
        }
    }

    private func statsSection(_ pokemon: Pokemon, _ member: Binding<TeamMember>) -> some View {
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
                                              set: { setEV(Int($0.rounded()), for: stat, member) }),
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
            Text("Stats are calculated at level \(current.level) with a \(nature.name) nature.")
        }
    }

    // MARK: Helpers

    private func stageText(_ stage: Int) -> String {
        stage == 0 ? "±0" : stage > 0 ? "+\(stage)" : "\(stage)"
    }

    private func setEV(_ value: Int, for stat: Stat, _ member: Binding<TeamMember>) {
        var evs = member.wrappedValue.evs
        let others = evs.total - evs[stat]
        evs[stat] = max(0, min(value, StatCalculator.maximumTotalEVs - others, StatCalculator.maximumStatEVs))
        member.wrappedValue.evs = evs
    }

    private func pasteSet() {
        guard let text = UIPasteboard.general.string, let set = ShowdownTeamCodec.parseSet(text),
              let pokemon = database.pokemon(named: set.species) else { return }
        var warnings: [String] = []
        side.member = TeamConversion.member(from: set, pokemon: pokemon, database: database, warnings: &warnings)
    }
}

#if DEBUG
#Preview {
    PreviewHost {
        CalcSideEditorView(role: .attacker, side: .constant(CalcSide.make(PokedexDatabase.preview.previewPokemon("Garchomp"),
                                                                            database: .preview)))
    }
}
#endif
