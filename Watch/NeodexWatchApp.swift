import NeodexKit
import SwiftUI

/// Neodex on the wrist: the Pokédex, type matchups and the daily picks from the bundled dataset, plus
/// your teams and Dexbot over the link to the iPhone.
@main
struct NeodexWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
                .environment(PhoneLink.shared)
                .task {
                    PhoneLink.shared.activate()
                    await model.load()
                }
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
        case today, dexbot, teams, types, pokedex
    }

    private(set) var state: State = .loading
    /// Which vertical page is showing; complications land on Today.
    var page: Page = .today

    init() {
        #if DEBUG
        // `-watchStartPage teams` opens on a page, for driving the simulator without the crown.
        switch UserDefaults.standard.string(forKey: "watchStartPage") {
        case "dexbot": page = .dexbot
        case "teams": page = .teams
        case "types": page = .types
        case "pokedex": page = .pokedex
        default: break
        }
        #endif
    }
    /// Today's navigation path, so a complication can open a Pokémon directly.
    var todayPath: [WatchRoute] = []

    var database: PokedexDatabase? {
        if case .ready(let database) = state { return database }
        return nil
    }

    /// Handles `neodex://pokemon/<id>`, `neodex://mystery` and `neodex://today` from complications, and
    /// `neodex://dexbot` and `neodex://teams` for jumping straight to those pages.
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
        case "dexbot":
            page = .dexbot
        case "teams":
            page = .teams
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
