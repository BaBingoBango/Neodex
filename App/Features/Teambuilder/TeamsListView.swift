import NeodexKit
import SwiftData
import SwiftUI

/// Teams tab root.
struct TeamsView: View {
    var body: some View {
        NavigationStack {
            TeamsContent()
                .appDestinations()
        }
    }
}

/// All saved teams.
struct TeamsContent: View {
    @Environment(\.database) private var database
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedTeam.updatedAt, order: .reverse) private var teams: [SavedTeam]
    @State private var showingImport = false
    @State private var newTeam: SavedTeam?

    var body: some View {
        List {
            ForEach(teams) { team in
                NavigationLink {
                    TeamDetailView(team: team)
                } label: {
                    TeamRow(team: team)
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .navigationTitle("Teams")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingImport = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                Button {
                    let team = SavedTeam()
                    modelContext.insert(team)
                    newTeam = team
                } label: {
                    Label("New Team", systemImage: "plus")
                }
            }
        }
        .navigationDestination(item: $newTeam) { team in
            TeamDetailView(team: team)
        }
        .sheet(isPresented: $showingImport) {
            TeamImportSheet()
        }
        .overlay {
            if teams.isEmpty {
                ContentUnavailableView {
                    Label("No Teams Yet", systemImage: "rectangle.stack.person.crop")
                } description: {
                    Text("Build a team from scratch or import one from Pokémon Showdown.")
                } actions: {
                    Button("New Team") {
                        let team = SavedTeam()
                        modelContext.insert(team)
                        newTeam = team
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Import from Showdown") { showingImport = true }
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(teams[index]) }
    }
}

struct TeamRow: View {
    @Environment(\.database) private var database
    var team: SavedTeam

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(team.name).font(.headline)
                Spacer()
                if let format = team.format {
                    Text(UsageFormat.displayName(for: format))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 4) {
                ForEach(team.members) { member in
                    if let pokemon = database.pokemon(id: member.pokemonID) {
                        PokemonImage(pokemon: pokemon, kind: .sprite)
                            .frame(width: 40, height: 40)
                    }
                }
                ForEach(team.members.count..<SavedTeam.maximumMembers, id: \.self) { _ in
                    Circle().strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .frame(width: 28, height: 28)
                        .padding(6)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

/// Paste Showdown text to create teams.
struct TeamImportSheet: View {
    @Environment(\.database) private var database
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var warnings: [String] = []
    @State private var importedCount: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 220)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    PasteButton(payloadType: String.self) { strings in
                        if let pasted = strings.first { text = pasted }
                    }
                    .buttonBorderShape(.capsule)
                } header: {
                    Text("Showdown export text")
                } footer: {
                    Text("Paste one or more teams exported from Pokémon Showdown's teambuilder. Teams separated by “=== [format] Name ===” headers are imported individually.")
                }
                if !warnings.isEmpty {
                    Section("Warnings") {
                        ForEach(warnings, id: \.self) { Text($0).font(.footnote) }
                    }
                }
                if let importedCount {
                    Section {
                        Label("Imported \(importedCount) team\(importedCount == 1 ? "" : "s").", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Import Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { runImport() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func runImport() {
        let result = TeamConversion.importTeams(from: text, database: database)
        warnings = result.warnings
        for team in result.teams { modelContext.insert(team) }
        importedCount = result.teams.count
        if result.warnings.isEmpty, !result.teams.isEmpty { dismiss() }
    }
}

#if DEBUG
#Preview("Teams") { TeamsView().previewEnvironment() }

#Preview("Import") { TeamImportSheet().previewEnvironment() }
#endif
