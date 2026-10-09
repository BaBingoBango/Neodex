import NeodexKit
import SwiftUI

/// Top-level navigation. iPad shows every feature in a grouped, customisable sidebar; iPhone shows
/// Home, Search and the tabs the user keeps in the bar. Screens requested by Spotlight or Siri open
/// as a sheet.
struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(TabBarPreferences.customizationKey) private var customization = TabViewCustomization()
    @AppStorage(TabBarPreferences.storageKey) private var storedVisible = TabBarPreferences.encode(AppTab.defaultVisible)
    @State private var router = DeepLinkRouter.shared
    @State private var selection: AppTab = .home

    private var visibleTabs: [AppTab] { TabBarPreferences.decode(storedVisible) }

    private func isVisible(_ tab: AppTab) -> Bool {
        TabBarPreferences.isVisible(tab, stored: visibleTabs, customization: customization)
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                AppTab.home.root
            }
            .customizationBehavior(.disabled, for: .sidebar, .tabBar)

            if sizeClass == .compact {
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
        .onChange(of: storedVisible) { fallBackIfHidden() }
        .onChange(of: customization) { fallBackIfHidden() }
    }

    /// A tab hidden from the iPhone bar can't stay selected there; fall back to Home.
    private func fallBackIfHidden() {
        guard sizeClass == .compact, selection != .home, selection != .search else { return }
        if !isVisible(selection) { selection = .home }
    }
}

#if DEBUG
#Preview { MainTabView().previewEnvironment() }
#endif
