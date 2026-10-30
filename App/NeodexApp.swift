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

        // Entries opened in a new window, from a context menu on iPad and the Mac or from Spotlight, Siri,
        // Dexbot or the Pokémon menu on the Mac, get a window of their own, so the main window keeps its
        // place and two entries can sit side by side.
        WindowGroup("Neodex", for: AppRoute.self) { $route in
            DatabaseLoadingView { _ in
                if let route {
                    NavigationStack {
                        AppRouteView(route: route)
                            .appDestinations()
                    }
                    .routePresenter()
                }
            }
            #if os(macOS)
            .frame(minWidth: 560, minHeight: 520)
            #endif
            .environment(appModel)
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 720, height: 840)
        #endif
        // An entry window always opens on an entry: File › New Window, links from widgets and Spotlight
        // hand-offs belong to the main window.
        .commandsRemoved()
        .handlesExternalEvents(matching: [])

        #if os(macOS)
        Settings {
            DatabaseLoadingView { _ in SettingsView() }
                .environment(appModel)
        }
        .modelContainer(container)

        ScopeLensWindows()
        #endif
    }
}
