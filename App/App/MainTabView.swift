import NeodexKit
import SwiftUI

/// Top-level navigation. iPad and Mac show every feature in a grouped, customisable sidebar; iPhone
/// shows Home, Search and the tabs the user keeps in the bar. Screens requested by Spotlight or Siri
/// open as a sheet on iOS and in their own window on the Mac.
struct MainTabView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #else
    @Environment(\.openWindow) private var openWindow
    #endif
    @Environment(\.database) private var database
    @AppStorage(TabBarPreferences.customizationKey) private var customization = TabViewCustomization()
    @AppStorage(TabBarPreferences.storageKey) private var storedVisible = TabBarPreferences.encode(AppTab.defaultVisible)
    @State private var router = DeepLinkRouter.shared
    @State private var selection: AppTab

    init() {
        // The Mac reopens on the sidebar item you left; iPhone and iPad start on Home.
        #if os(macOS)
        let remembered = UserDefaults.standard.string(forKey: Self.selectionKey).flatMap(AppTab.init(rawValue:))
        _selection = State(initialValue: remembered.flatMap { AppTab.features.contains($0) || $0 == .search ? $0 : nil } ?? .home)
        #else
        _selection = State(initialValue: .home)
        #endif
    }

    private static let selectionKey = "selectedTab"

    private var visibleTabs: [AppTab] { TabBarPreferences.decode(storedVisible) }

    /// iPhone shows a tab bar; iPad and the Mac show the sidebar.
    private var isCompact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    private func isVisible(_ tab: AppTab) -> Bool {
        TabBarPreferences.isVisible(tab, stored: visibleTabs, customization: customization)
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                AppTab.home.root
            }
            #if os(iOS)
            .customizationBehavior(.disabled, for: .sidebar, .tabBar)
            #endif

            if isCompact {
                // iPhone keeps every declared tab reachable (overflowing into More), so only the
                // chosen tabs are declared here. Everything else is on Home.
                ForEach(visibleTabs) { tab in
                    Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                        tab.root
                    }
                }
            } else {
                ForEach(AppTab.Group.allCases) { group in
                    TabSection(group.title) {
                        ForEach(group.tabs) { tab in
                            Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                                tab.root
                            }
                            .customizationID(tab.customizationID)
                            .defaultVisibility(isVisible(tab) ? .visible : .hidden, for: .tabBar)
                        }
                    }
                    .customizationID("neodex.section.\(group.id)")
                }
            }

            Tab(value: AppTab.search, role: .search) {
                AppTab.search.root
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
        .focusedSceneValue(\.tabSelection, $selection)
        #if os(macOS)
        .onChange(of: selection) { _, tab in UserDefaults.standard.set(tab.rawValue, forKey: Self.selectionKey) }
        .onChange(of: router.pendingRoute) { _, route in
            // A requested entry gets its own window, so the main window keeps its place.
            guard let route else { return }
            router.pendingRoute = nil
            openWindow(value: route)
        }
        #else
        .sheet(item: $router.pendingRoute) { route in
            NavigationStack {
                AppRouteView(route: route)
                    .appDestinations()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { router.pendingRoute = nil }
                        }
                    }
            }
        }
        #endif
        .onChange(of: router.pendingPick, initial: true) { _, request in
            guard let request else { return }
            let species = database.species
            let pick: Pokemon? = switch request {
            case .random: species.randomElement()
            case .today: DailyPick.pokemonOfTheDay(species)
            case .mystery: DailyPick.mystery(species)
            }
            router.pendingPick = nil
            if let pick { router.pendingRoute = .pokemon(pick.id) }
        }
        .onChange(of: router.pendingTab) { _, tab in
            guard let tab else { return }
            router.pendingTab = nil
            selection = tab
        }
        .onChange(of: storedVisible) { fallBackIfHidden() }
        .onChange(of: customization) { fallBackIfHidden() }
    }

    /// A tab hidden from the iPhone bar can't stay selected there; fall back to Home.
    private func fallBackIfHidden() {
        guard isCompact, selection != .home, selection != .search else { return }
        if !isVisible(selection) { selection = .home }
    }
}

extension FocusedValues {
    /// The focused window's selected tab, so the Mac's Go menu can switch it.
    @Entry var tabSelection: Binding<AppTab>?
}

#if DEBUG
#Preview { MainTabView().previewEnvironment() }
#endif
