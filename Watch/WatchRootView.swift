import NeodexKit
import SwiftUI

/// Three pages, swiped vertically like a watch face stack: Today, the type calculator and the Pokédex.
/// The long list goes last, so no page sits behind a thousand rows.
struct WatchRootView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        switch model.state {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Opening the Pokédex…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            ContentUnavailableView("Pokédex Unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
        case .ready(let database):
            TabView {
                NavigationStack {
                    WatchTodayView(database: database)
                }
                NavigationStack {
                    WatchTypeMatchupView()
                }
                NavigationStack {
                    WatchPokedexView(database: database)
                }
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

/// Resolves `AppRoute`-style string destinations to the detail screen.
extension View {
    func watchDestinations(database: PokedexDatabase) -> some View {
        navigationDestination(for: WatchRoute.self) { route in
            switch route {
            case .pokemon(let id):
                if let pokemon = database.pokemon(id: id) {
                    WatchPokemonDetailView(pokemon: pokemon, database: database)
                } else {
                    ContentUnavailableView("Not Found", systemImage: "questionmark.circle")
                }
            case .ability(let id):
                if let ability = database.ability(id: id) {
                    WatchAbilityView(ability: ability)
                } else {
                    ContentUnavailableView("Not Found", systemImage: "questionmark.circle")
                }
            }
        }
    }
}

nonisolated enum WatchRoute: Hashable {
    case pokemon(String)
    case ability(String)
}
