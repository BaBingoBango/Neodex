import NeodexKit
import SwiftData
import SwiftUI

/// Neodex — an offline Pokédex with Pokémon Showdown teambuilding.
@main
struct NeodexApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
        .modelContainer(for: [SavedTeam.self, BrowsingRecord.self])
    }
}
