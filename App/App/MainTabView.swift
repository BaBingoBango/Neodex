import NeodexKit
import SwiftUI

/// Top-level navigation. Adapts to a sidebar on iPad and a tab bar on iPhone; the user chooses
/// which features appear as tabs in Settings.
struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @AppStorage(TabPreferences.key) private var storedTabs = TabPreferences.encode(TabPreferences.defaultTabs)
    @State private var selection: AppTab = .home

    private var customTabs: [AppTab] { TabPreferences.decode(storedTabs) }

    var body: some View {
        @Bindable var appModel = appModel
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                AppTab.home.root
            }
            ForEach(customTabs) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    tab.root
                }
            }
            Tab(value: AppTab.search, role: .search) {
                AppTab.search.root
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .sheet(item: $appModel.pendingRoute) { route in
            NavigationStack {
                AppRouteView(route: route)
                    .appDestinations()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { appModel.pendingRoute = nil }
                        }
                    }
            }
        }
        .onChange(of: storedTabs) {
            if !customTabs.contains(selection), selection != .home, selection != .search { selection = .home }
        }
    }
}

#if DEBUG
#Preview { MainTabView().previewEnvironment() }
#endif
