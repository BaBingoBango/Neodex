import ScopeLens
import SwiftUI

/// Scope Lens inside Neodex. The live tracker is the sidebar's Scope Lens tab and, for parking it
/// next to the mirrored game, its own window; the scout report, battle log, dossier and archive
/// windows keep the ids and ⇧⌘ shortcuts the standalone app used, so the tracker's own buttons open
/// them unchanged.
struct ScopeLensWindows: Scene {
    var body: some Scene {
        Window("Live Tracker", id: "live-tracker") {
            LiveTrackerView()
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])
        .defaultSize(width: 760, height: 480)

        Window("Scout Report", id: "scout-report") {
            ScoutReportView()
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .defaultSize(width: 760, height: 640)

        Window("Battle Log", id: "battle-log") {
            BattleLogView()
        }
        .keyboardShortcut("b", modifiers: [.command, .shift])
        .defaultSize(width: 520, height: 560)

        Window("Scouting Dex", id: "dossier") {
            DossierWindowView()
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])
        .defaultSize(width: 480, height: 700)

        Window("Battle Archive", id: "battle-archive") {
            BattleArchiveView()
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
    }
}

// The Settings window's Scope Lens tabs: the Champions team, the advisor's API key, and the usage
// snapshot. Thin wrappers keep `import ScopeLens` out of the shared App sources.
struct ScopeLensTeamSettings: View {
    var body: some View { TeamSettingsView() }
}

struct ScopeLensAdvisorSettings: View {
    var body: some View { AdvisorSettingsView() }
}

struct ScopeLensMetaSettings: View {
    var body: some View { MetaSettingsView() }
}
