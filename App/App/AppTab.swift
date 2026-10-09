import Foundation
import SwiftUI

/// Tabs the user can place in the tab bar. Search is always present as the system search tab.
enum AppTab: String, CaseIterable, Codable, Hashable, Identifiable {
    case home, pokedex, moves, abilities, items, types, natures, teams, faceOff, damageCalc, usageStats, explore, search

    var id: String { rawValue }

    /// Tabs the user may choose from (Home is always first; Search is handled separately).
    static let customizable: [AppTab] = [.pokedex, .moves, .abilities, .items, .types, .natures, .teams, .faceOff, .damageCalc, .usageStats, .explore]

    var title: String {
        switch self {
        case .home: "Home"
        case .pokedex: "Pokédex"
        case .moves: "Moves"
        case .abilities: "Abilities"
        case .items: "Items"
        case .types: "Type-O-Matic"
        case .natures: "Natures"
        case .teams: "Teams"
        case .faceOff: "Face-Off"
        case .damageCalc: "Damage Calc"
        case .usageStats: "Global Stats"
        case .explore: "Explore"
        case .search: "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .pokedex: "person.fill"
        case .moves: "burst.fill"
        case .abilities: "sparkles"
        case .items: "cube.fill"
        case .types: "circle.grid.cross.fill"
        case .natures: "leaf.fill"
        case .teams: "rectangle.stack.person.crop.fill"
        case .faceOff: "bolt.circle.fill"
        case .damageCalc: "function"
        case .usageStats: "network"
        case .explore: "wand.and.stars"
        case .search: "magnifyingglass"
        }
    }

    /// The root view for the tab, wrapped in its own navigation stack.
    @ViewBuilder
    var root: some View {
        switch self {
        case .home: HomeView()
        case .search: SearchView()
        default:
            NavigationStack {
                content.appDestinations()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch self {
        case .pokedex: PokedexListContent()
        case .moves: MoveListContent()
        case .abilities: AbilityListView()
        case .items: ItemListView()
        case .types: TypeMatchupView()
        case .natures: NatureListView()
        case .teams: TeamsContent()
        case .faceOff: FaceOffView(initial: nil)
        case .damageCalc: DamageCalculatorView()
        case .usageStats: UsageStatsView()
        case .explore: ExploreView()
        case .home, .search: EmptyView()
        }
    }
}

/// Persists the user's tab bar layout in `UserDefaults`.
enum TabPreferences {
    static let key = "selectedTabs"
    static let defaultTabs: [AppTab] = [.pokedex, .moves, .teams]
    /// The tab bar fits Home, Search and at most this many chosen tabs before iOS collapses into "More".
    static let maximumCustomTabs = 3

    static func decode(_ raw: String) -> [AppTab] {
        guard let data = raw.data(using: .utf8), let tabs = try? JSONDecoder().decode([AppTab].self, from: data) else {
            return defaultTabs
        }
        return tabs.filter { AppTab.customizable.contains($0) }
    }

    static func encode(_ tabs: [AppTab]) -> String {
        (try? JSONEncoder().encode(tabs)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}
