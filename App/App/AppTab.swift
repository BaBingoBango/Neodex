import Foundation
import NeodexKit
import SwiftUI

/// Every top-level destination. On iPad all of them appear in the sidebar, grouped into sections;
/// on iPhone the tab bar shows Home, Search and the tabs the user keeps visible.
enum AppTab: String, CaseIterable, Codable, Hashable, Identifiable {
    case home, pokedex, moves, abilities, items, types, natures, teams, damageCalc, faceOff, usageStats, search

    var id: String { rawValue }

    /// Sidebar sections. Home and Search sit outside them.
    enum Group: String, CaseIterable, Identifiable {
        case reference, battle

        var id: String { rawValue }

        var title: String {
            switch self {
            case .reference: "Reference"
            case .battle: "Battle"
            }
        }

        var tabs: [AppTab] { AppTab.features.filter { $0.group == self } }
    }

    /// Tabs that live in a sidebar section, in display order.
    static let features: [AppTab] = [.pokedex, .moves, .abilities, .items, .types, .natures, .teams, .damageCalc, .faceOff, .usageStats]

    /// Shown in the iPhone tab bar until the user changes the layout.
    static let defaultVisible: [AppTab] = [.pokedex, .teams, .damageCalc]

    var group: Group? {
        switch self {
        case .pokedex, .moves, .abilities, .items, .types, .natures: .reference
        case .teams, .damageCalc, .faceOff, .usageStats: .battle
        case .home, .search: nil
        }
    }

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
        case .damageCalc: "Damage Calc"
        case .faceOff: "Face-Off"
        case .usageStats: "Global Stats"
        case .search: "Search"
        }
    }

    /// The longer name used on Home's cards.
    var cardTitle: String {
        switch self {
        case .moves: "Move Dex"
        case .abilities: "Ability Dex"
        case .items: "Item Dex"
        case .teams: "Teambuilder"
        case .damageCalc: "Damage Calculator"
        default: title
        }
    }

    var subtitle: String {
        switch self {
        case .home: "Jump back in"
        case .pokedex: "Every species and form"
        case .moves: "Power, accuracy, learners"
        case .abilities: "What each Ability does"
        case .items: "Held items and more"
        case .types: "Weaknesses and resistances"
        case .natures: "All 25 natures"
        case .teams: "Build and share Showdown teams"
        case .damageCalc: "Showdown-style damage calcs"
        case .faceOff: "Compare two Pokémon"
        case .usageStats: "Smogon usage statistics"
        case .search: "Find anything"
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
        case .damageCalc: "function"
        case .faceOff: "bolt.circle.fill"
        case .usageStats: "network"
        case .search: "magnifyingglass"
        }
    }

    var tint: Color {
        switch self {
        case .home: .accentColor
        case .pokedex: .blue
        case .moves: .red
        case .abilities: .gold
        case .items: PokemonType.flying.color
        case .types: PokemonType.psychic.color
        case .natures: .green
        case .teams: PokemonType.ice.color
        case .damageCalc: PokemonType.fire.color
        case .faceOff: PokemonType.dragon.color
        case .usageStats: .blue
        case .search: .gray
        }
    }

    /// Stable identifier for the system's tab customization.
    var customizationID: String { "neodex.tab.\(rawValue)" }

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

    /// The feature's content, also pushed from Home's cards.
    @ViewBuilder
    var content: some View {
        switch self {
        case .pokedex: PokedexListContent()
        case .moves: MoveListContent()
        case .abilities: AbilityListView()
        case .items: ItemListView()
        case .types: TypeMatchupView()
        case .natures: NatureListView()
        case .teams: TeamsContent()
        case .damageCalc: DamageCalculatorView()
        case .faceOff: FaceOffView(initial: nil)
        case .usageStats: UsageStatsView()
        case .home, .search: EmptyView()
        }
    }
}

/// Which feature tabs the iPhone tab bar shows. SwiftUI's `TabViewCustomization` records edits made
/// in iPad's sidebar but its tab-bar visibility can't be set in code, so the app stores its own choice
/// (as a JSON list of tab names, the same key earlier versions used) and reads the system's edits on top.
enum TabBarPreferences {
    static let storageKey = "selectedTabs"
    static let customizationKey = "tabCustomization"
    /// Home, Search and this many more fit in the iPhone tab bar.
    static let maximumVisible = 3

    static func decode(_ raw: String) -> [AppTab] {
        guard let data = raw.data(using: .utf8), let names = try? JSONDecoder().decode([String].self, from: data) else {
            return AppTab.defaultVisible
        }
        return names.compactMap(AppTab.init(rawValue:)).filter { AppTab.features.contains($0) }
    }

    static func encode(_ tabs: [AppTab]) -> String {
        (try? JSONEncoder().encode(tabs.map(\.rawValue))).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    /// An explicit choice made in iPad's sidebar wins; otherwise the stored set decides.
    static func isVisible(_ tab: AppTab, stored: [AppTab], customization: TabViewCustomization) -> Bool {
        switch customization[tab: tab.customizationID].tabBarVisibility {
        case .visible: true
        case .hidden: false
        case .automatic: stored.contains(tab)
        }
    }
}
