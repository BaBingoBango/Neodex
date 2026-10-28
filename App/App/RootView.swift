import AppIntents
import CoreSpotlight
import NeodexKit
import SwiftData
import SwiftUI

/// Shows a launch placeholder until the Pokédex has loaded, then the main interface.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DatabaseLoadingView { database in
            MainTabView()
                .task(id: database.manifest?.generatedAt) {
                    #if DEBUG && os(iOS)
                    DebugSeeds.seedSampleTeamIfRequested(context: modelContext, database: database)
                    DebugSeeds.seedSampleChatsIfRequested(context: modelContext)
                    #endif
                    await SpotlightIndexer.indexIfNeeded(database: database)
                    NeodexShortcuts.updateAppShortcutParameters()
                    #if os(iOS)
                    // The Mac has no widgets yet, so it skips copying sprites into the group container.
                    await WidgetBridge.refresh(database: database)
                    #endif
                }
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        // An open main window takes incoming URLs itself instead of SwiftUI opening another one.
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        #endif
        .onOpenURL { url in
            DeepLinkRouter.shared.open(url: url)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let route = AppRoute(spotlightIdentifier: identifier) else { return }
            DeepLinkRouter.shared.open(route)
        }
    }
}

/// Waits for the bundled Pokédex, then shows `content` with the database in the environment.
/// Every window and the Mac's Settings scene go through this, so none of them can outrun the load.
struct DatabaseLoadingView<Content: View>: View {
    @Environment(AppModel.self) private var appModel
    @ViewBuilder var content: (PokedexDatabase) -> Content

    var body: some View {
        Group {
            switch appModel.loadState {
            case .loading:
                ProgressView("Opening the Pokédex…")
                    .controlSize(.large)
            case .ready(let database):
                content(database)
                    .environment(\.database, database)
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
    }
}
