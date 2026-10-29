import NeodexKit
import ScopeLens
import SwiftData
import SwiftUI

/// Scope Lens inside Neodex. The live tracker is the sidebar's Scope Lens tab and, for parking it
/// next to the mirrored game, its own window; the scout report, battle log, dossier and archive
/// windows keep the ids and ⇧⌘ shortcuts the standalone app used, so the tracker's own buttons open
/// them unchanged.
struct ScopeLensWindows: Scene {
    var body: some Scene {
        Window("Live Tracker", id: "live-tracker") {
            LiveTrackerView()
                .neodexBridge()
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])
        .defaultSize(width: 760, height: 480)

        Window("Scout Report", id: "scout-report") {
            ScoutReportView()
                .neodexBridge()
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .defaultSize(width: 760, height: 640)

        Window("Battle Log", id: "battle-log") {
            BattleLogView()
                .neodexBridge()
        }
        .keyboardShortcut("b", modifiers: [.command, .shift])
        .defaultSize(width: 520, height: 560)

        Window("Scouting Dex", id: "dossier") {
            DossierWindowView()
                .neodexBridge()
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])
        .defaultSize(width: 480, height: 700)

        Window("Battle Archive", id: "battle-archive") {
            BattleArchiveView()
                .neodexBridge()
        }
        .keyboardShortcut("a", modifiers: [.command, .shift])
        .defaultSize(width: 860, height: 560)
    }
}

/// The Scope Lens tab: the live tracker, with the window title it deserves.
struct ScopeLensContent: View {
    var body: some View {
        LiveTrackerView()
            .navigationTitle("Scope Lens")
            .neodexBridge()
    }
}

// MARK: - The bridge

/// Wires Scope Lens to the rest of Neodex: names open Neodex entries in their own window, and "Ask
/// Dexbot" switches to Dexbot with the question. Installed by whichever Scope Lens view appears first;
/// installing again is harmless.
private struct NeodexBridgeInstaller: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear(perform: install)
    }

    private func install() {
        let openWindow = openWindow
        NeodexBridge.openEntry = { kind, name in
            Task { @MainActor in
                guard let database = try? await DatabaseProvider.shared.database(),
                      let route = ScopeLensEntryResolver.route(for: name, kind: kind, in: database) else { return }
                openWindow(value: route)
            }
        }
        NeodexBridge.askDexbot = { question in
            DeepLinkRouter.shared.askDexbot(question)
        }
    }
}

extension View {
    func neodexBridge() -> some View { modifier(NeodexBridgeInstaller()) }
}

/// Scope Lens names use the engine's spellings ("Charizard-Mega-Y", "Rock Slide", "Life Orb"), which
/// collapse to Neodex's Showdown-style ids ("charizardmegay", "rockslide", "lifeorb"); a name search is
/// the fallback for the few that don't.
enum ScopeLensEntryResolver {
    static func route(for name: String, kind: NeodexBridge.EntryKind, in database: PokedexDatabase) -> AppRoute? {
        let id = String(name.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
        let results = database.search(name, limitPerCategory: 1)
        switch kind {
        case .species:
            if let pokemon = database.pokemon(id: id) ?? database.resolvePokemon(name) { return .pokemon(pokemon.id) }
        case .move:
            if database.move(id: id) != nil { return .move(id) }
            if let move = results.moves.first { return .move(move.id) }
        case .ability:
            if database.ability(id: id) != nil { return .ability(id) }
            if let ability = results.abilities.first { return .ability(ability.id) }
        case .item:
            if database.item(id: id) != nil { return .item(id) }
            if let item = results.items.first { return .item(item.id) }
        }
        return nil
    }
}

/// Hands a Neodex team to Scope Lens through the Showdown export both already speak.
enum ScopeLensTeamBridge {
    static let linkedTeamKey = "scopeLensLinkedTeam"

    /// Imports the team into Scope Lens and remembers it as the linked team when it validated.
    /// Returns Scope Lens's validation issues; any error means the team was not adopted.
    @discardableResult
    static func use(_ team: SavedTeam, database: PokedexDatabase) -> [TeamIssue] {
        let text = TeamConversion.exportText(for: team, database: database, includeHeader: false)
        let issues = TeamManager.shared.importPaste(text)
        if !issues.contains(where: { $0.severity == .error }) {
            UserDefaults.standard.set(team.id.uuidString, forKey: linkedTeamKey)
        }
        return issues
    }

    /// One sentence for the alert after "Use in Scope Lens".
    static func summary(_ issues: [TeamIssue], team: SavedTeam) -> String {
        let errors = issues.filter { $0.severity == .error }
        guard errors.isEmpty else {
            return "Scope Lens couldn't use “\(team.name)”: " + errors.map(\.message).joined(separator: " ")
        }
        var text = "Scope Lens is now using “\(team.name)”."
        if !issues.isEmpty { text += " " + issues.map(\.message).joined(separator: " ") }
        return text
    }
}

// The Settings window's Scope Lens tabs: the Champions team, the advisor's API key, and the usage
// snapshot. Thin wrappers keep `import ScopeLens` out of the shared App sources.
/// The Champions Team pane: Scope Lens's own paste editor, with Neodex's saved teams one menu away.
struct ScopeLensTeamSettings: View {
    @Query(sort: \SavedTeam.updatedAt, order: .reverse) private var teams: [SavedTeam]
    @Environment(\.database) private var database
    @AppStorage(ScopeLensTeamBridge.linkedTeamKey) private var linkedTeamID = ""
    @State private var issues: [TeamIssue] = []

    private var linkedTeam: SavedTeam? { teams.first { $0.id.uuidString == linkedTeamID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            neodexRow
                .padding(.horizontal, 20)
                .padding(.top, 20)
            TeamSettingsView()
        }
    }

    private var neodexRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(teams) { team in
                        Button(team.name) { use(team) }
                    }
                } label: {
                    Label("Use a Neodex team", systemImage: "rectangle.stack.person.crop")
                }
                .fixedSize()
                .disabled(teams.isEmpty)
                .help(teams.isEmpty ? "Build a team in Neodex's Teambuilder first." : "Hand one of your Neodex teams to Scope Lens.")
                if let linkedTeam {
                    Text("Using “\(linkedTeam.name)” from Neodex.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Re-import") { use(linkedTeam) }
                        .controlSize(.small)
                        .help("Send the team again after editing it in Neodex.")
                }
                Spacer()
            }
            ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                Label(issue.message, systemImage: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(issue.severity == .error ? .red : .orange)
            }
        }
    }

    private func use(_ team: SavedTeam) {
        issues = ScopeLensTeamBridge.use(team, database: database)
    }
}

/// The advisor's settings in Neodex: the same Claude key section as Dexbot's, since they share one key.
struct ScopeLensAdvisorSettings: View {
    @State private var savedKeyHint = DexbotClaude.APIKey.hint
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("“What's the play” advisor")
                    .font(.headline)
                Text("Scope Lens's opt-in advisor sends the current battle to Claude, about a cent per ask. The deterministic matchup and damage math never needs it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ClaudeKeySection(savedKeyHint: $savedKeyHint, model: DexbotClaude.model, focus: $keyFieldFocused,
                             usage: "When you ask, the advisor sends the battle from this Mac straight to Anthropic, billed to your Anthropic account.")
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 420)
    }
}

struct ScopeLensMetaSettings: View {
    var body: some View { MetaSettingsView() }
}
