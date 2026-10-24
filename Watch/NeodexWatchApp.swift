import NeodexKit
import SwiftUI

/// Neodex on the wrist: the Pokédex, type matchups and the daily picks, all from the bundled dataset.
@main
struct NeodexWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
                .task { await model.load() }
        }
    }
}

/// Loads the bundled Pokédex once and hands it to every screen.
@Observable
@MainActor
final class WatchModel {
    enum State {
        case loading
        case ready(PokedexDatabase)
        case failed(String)
    }

    private(set) var state: State = .loading

    var database: PokedexDatabase? {
        if case .ready(let database) = state { return database }
        return nil
    }

    func load() async {
        guard case .loading = state else { return }
        do {
            state = .ready(try await PokedexDatabase.load(from: .main, subdirectory: "Data"))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
