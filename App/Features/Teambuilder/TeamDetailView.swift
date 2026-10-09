import NeodexKit
import SwiftData
import SwiftUI

/// One team: its six slots, analysis, and export.
struct TeamDetailView: View {
    @Environment(\.database) private var database
    @Environment(\.modelContext) private var modelContext
    @Bindable var team: SavedTeam

    @State private var pickingPokemon = false
    @State private var editingMemberID: UUID?
    @State private var showingExport = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                nameSection
                membersSection
                if !team.members.isEmpty {
                    summarySection
                    legalitySection
                    coverageSection
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingExport = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(team.members.isEmpty)
            }
        }
        .sheet(isPresented: $pickingPokemon) {
            PokemonPickerSheet(title: "Add to Team") { pokemon in
                team.members.append(TeamMember(pokemon: pokemon))
                team.touch()
            }
        }
        .sheet(isPresented: $showingExport) {
            TeamExportSheet(text: TeamConversion.exportText(for: team, database: database))
        }
        .navigationDestination(item: $editingMemberID) { id in
            if let index = team.members.firstIndex(where: { $0.id == id }) {
                TeamMemberEditorView(team: team, memberIndex: index)
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Team name", text: $team.name)
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .textFieldStyle(.plain)
                .onSubmit { team.touch() }
            TextField("Format (e.g. gen9ou)", text: Binding(get: { team.format ?? "" }, set: { team.format = $0.isEmpty ? nil : $0; team.touch() }))
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var membersSection: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(team.members) { member in
                Button {
                    editingMemberID = member.id
                } label: {
                    TeamMemberCard(member: member, issueCount: legalityIssues.filter { $0.setID == member.id.uuidString }.count)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Copy Set", systemImage: "doc.on.doc") {
                        TeamConversion.copyToPasteboard(TeamConversion.exportText(for: member, database: database))
                    }
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        team.members.removeAll { $0.id == member.id }
                        team.touch()
                    }
                }
            }
            if team.members.count < SavedTeam.maximumMembers {
                Button {
                    pickingPokemon = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.largeTitle)
                        Text("Add Pokémon").font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .foregroundStyle(.tint)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private var summarySection: some View {
        let members = team.members.compactMap { member in database.pokemon(id: member.pokemonID).map { (member, $0) } }
        let totals = members.map { $0.0.calculatedStats(for: $0.1).total }
        let types = Set(members.flatMap { $0.1.types })
        return HStack(spacing: 10) {
            StatPill(label: "Pokémon", value: "\(team.members.count)/\(SavedTeam.maximumMembers)")
            StatPill(label: "Types used", value: "\(types.count)")
            StatPill(label: "Avg. stat total", value: totals.isEmpty ? "—" : "\(totals.reduce(0, +) / totals.count)")
        }
        .padding(.horizontal)
    }

    private var legalityIssues: [LegalityIssue] {
        guard let format = team.smogonFormat else { return [] }
        return FormatLegality.check(team.legalitySets, format: format, database: database)
    }

    private var legalitySection: some View {
        TeamLegalityView(team: team, issues: legalityIssues)
            .padding(.horizontal)
    }

    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Defensive Coverage")
            Text("How many team members are weak to or resist each attacking type.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TeamCoverageGrid(team: team)
        }
        .padding(.horizontal)
    }
}

/// A compact card for a member: sprite, name, item, ability and moves.
struct TeamMemberCard: View {
    @Environment(\.database) private var database
    var member: TeamMember
    /// Format-legality problems with this set, shown as a badge.
    var issueCount = 0

    var body: some View {
        if let pokemon = database.pokemon(id: member.pokemonID) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    PokemonImage(pokemon: pokemon, kind: .sprite)
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        // Teambuilder cards use Showdown's compact species names ("Ogerpon-Wellspring").
                        Text(member.nickname?.isEmpty == false ? member.nickname! : pokemon.name)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        if member.nickname?.isEmpty == false {
                            Text(pokemon.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                TypeBadgeRow(types: pokemon.types, size: .small)
                VStack(alignment: .leading, spacing: 2) {
                    if let itemID = member.itemID, let item = database.item(id: itemID) {
                        Label(item.name, systemImage: "cube").font(.caption).lineLimit(1)
                    }
                    if let abilityID = member.abilityID, let ability = database.ability(id: abilityID) {
                        Label(ability.name, systemImage: "sparkles").font(.caption).lineLimit(1)
                    }
                }
                .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(0..<4, id: \.self) { slot in
                        if let moveID = member.moveIDs[slot], let move = database.move(id: moveID) {
                            HStack(spacing: 4) {
                                Circle().fill(move.type.color).frame(width: 8, height: 8)
                                Text(move.name).font(.caption)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Circle().strokeBorder(.quaternary).frame(width: 8, height: 8)
                                Text("—").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 4) {
                    if issueCount > 0 {
                        Label("\(issueCount)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                            .accessibilityLabel("\(issueCount) legality issues")
                    }
                    if member.shiny {
                        Image(systemName: "sparkle").font(.caption).foregroundStyle(.yellow)
                    }
                }
                .padding(8)
            }
        }
    }
}

/// Per-type counts of weak and resistant team members.
struct TeamCoverageGrid: View {
    @Environment(\.database) private var database
    var team: SavedTeam

    private var pokemon: [Pokemon] { team.members.compactMap { database.pokemon(id: $0.pokemonID) } }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
            ForEach(PokemonType.allCases) { attacker in
                let weak = pokemon.filter { attacker.multiplier(against: $0.types) >= 2 }.count
                let resist = pokemon.filter { attacker.multiplier(against: $0.types) < 1 }.count
                HStack {
                    TypeBadge(type: attacker, size: .small)
                    Spacer()
                    Label("\(weak)", systemImage: "arrow.down.circle")
                        .foregroundStyle(weak >= 3 ? .red : weak > 0 ? .orange : .secondary)
                        .monospacedDigit()
                    Label("\(resist)", systemImage: "shield")
                        .foregroundStyle(resist > 0 ? .green : .secondary)
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel("\(attacker.name): \(weak) weak, \(resist) resist")
            }
        }
    }
}

/// Shows export text with copy and share actions.
struct TeamExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    var text: String
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Showdown Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
                        TeamConversion.copyToPasteboard(text)
                        copied = true
                    }
                    ShareLink(item: text)
                }
            }
        }
    }
}

/// Modal Pokémon chooser used by the Teambuilder and Face-Off.
struct PokemonPickerSheet: View {
    @Environment(\.database) private var database
    @Environment(\.dismiss) private var dismiss
    var title: LocalizedStringKey
    var onPick: (Pokemon) -> Void
    @State private var searchText = ""

    private var results: [Pokemon] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? database.pokemon : database.search(trimmed, limitPerCategory: 300).pokemon
    }

    var body: some View {
        NavigationStack {
            List(results) { pokemon in
                Button {
                    onPick(pokemon)
                    dismiss()
                } label: {
                    PokemonRow(pokemon: pokemon)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Name or number")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

#if DEBUG
#Preview { PreviewHost { TeamDetailView(team: PreviewStore.sampleTeam) } }
#endif
