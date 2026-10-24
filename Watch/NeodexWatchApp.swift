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
                .onOpenURL { model.open($0) }
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

    enum Page: Hashable {
        case today, types, pokedex
    }

    private(set) var state: State = .loading
    /// Which vertical page is showing; complications land on Today.
    var page: Page = .today
    /// Today's navigation path, so a complication can open a Pokémon directly.
    var todayPath: [WatchRoute] = []

    var database: PokedexDatabase? {
        if case .ready(let database) = state { return database }
        return nil
    }

    /// Handles `neodex://pokemon/<id>`, `neodex://mystery` and `neodex://today` from complications.
    func open(_ url: URL) {
        guard url.scheme == SharedContainer.urlScheme else { return }
        let argument = url.pathComponents.dropFirst().first
        switch url.host() {
        case "pokemon":
            guard let argument else { return }
            page = .today
            todayPath = [.pokemon(argument)]
        case "mystery", "today":
            page = .today
            todayPath = []
        default:
            break
        }
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
