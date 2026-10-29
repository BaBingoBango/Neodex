import NeodexKit
import SwiftData
import SwiftUI

/// Neodex — an offline Pokédex with Pokémon Showdown teambuilding.
@main
struct NeodexApp: App {
    @State private var appModel = AppModel()
    private let container = PersistenceContainer.shared

    init() {
        #if os(iOS)
        // The watch bridge starts with the app, so a question from the wrist can wake us in the background.
        WatchLink.shared.activate(container: container)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands { NeodexCommands() }
        // URLs and Spotlight hand-offs belong to the main window scene, not the entry windows.
        .handlesExternalEvents(matching: ["*"])
        #endif

        #if os(macOS)
        // Entries requested from Spotlight, Siri, Dexbot or the Pokémon menu open in their own window,
        // so the main window keeps its place and two entries can sit side by side.
        WindowGroup("Neodex", for: AppRoute.self) { $route in
            DatabaseLoadingView { _ in
                if let route {
                    NavigationStack {
                        AppRouteView(route: route)
                            .appDestinations()
                    }
                }
            }
            .frame(minWidth: 560, minHeight: 520)
            .environment(appModel)
        }
        .modelContainer(container)
        .defaultSize(width: 720, height: 840)
        // An entry window always opens on an entry; File › New Window belongs to the main window.
        .commandsRemoved()

        Settings {
            DatabaseLoadingView { _ in SettingsView() }
                .environment(appModel)
        }
        .modelContainer(container)

        ScopeLensWindows()
        #endif
    }
}
