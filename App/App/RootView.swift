import AppIntents
import CoreSpotlight
import NeodexKit
import SwiftUI

/// Shows a launch placeholder until the Pokédex has loaded, then the main interface.
struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            switch appModel.loadState {
            case .loading:
                ProgressView("Opening the Pokédex…")
                    .controlSize(.large)
            case .ready(let database):
                MainTabView()
                    .environment(\.database, database)
                    .task(id: database.manifest?.generatedAt) {
                        await SpotlightIndexer.indexIfNeeded(database: database)
                        NeodexShortcuts.updateAppShortcutParameters()
                    }
            case .failed(let error):
                ContentUnavailableView {
                    Label("Pokédex Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Try Again") { Task { await appModel.retry() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { await appModel.loadIfNeeded() }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let route = AppRoute(spotlightIdentifier: identifier) else { return }
            DeepLinkRouter.shared.open(route)
        }
    }
}
