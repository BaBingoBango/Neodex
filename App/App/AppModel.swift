import Foundation
import NeodexKit
import Observation

/// App-wide state: loads the bundled Pokédex once at launch and exposes it to every view.
@Observable
@MainActor
final class AppModel {
    enum LoadState {
        case loading
        case ready(PokedexDatabase)
        case failed(Error)
    }

    private(set) var loadState: LoadState = .loading

    /// A screen requested from outside the app (Spotlight), presented as a sheet once data is ready.
    var pendingRoute: AppRoute?

    var database: PokedexDatabase? {
        if case .ready(let database) = loadState { return database }
        return nil
    }

    /// Loads the bundled dataset off the main actor. Safe to call more than once; later calls are no-ops.
    func loadIfNeeded() async {
        guard case .loading = loadState else { return }
        do {
            let database = try await PokedexDatabase.load(from: .main)
            loadState = .ready(database)
        } catch {
            loadState = .failed(error)
        }
    }

    func retry() async {
        loadState = .loading
        await loadIfNeeded()
    }
}
