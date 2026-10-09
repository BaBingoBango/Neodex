import NeodexKit
import SwiftData
import SwiftUI

/// Settings: tab bar layout, history, Spotlight and about.
struct SettingsView: View {
    @Environment(\.database) private var database
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TabBarPreferences.customizationKey) private var customization = TabViewCustomization()
    @AppStorage(TabBarPreferences.storageKey) private var storedVisible = TabBarPreferences.encode(AppTab.defaultVisible)
    @State private var confirmingHistoryClear = false
    @State private var reindexing = false

    private var visibleTabs: [AppTab] {
        AppTab.features.filter { TabBarPreferences.isVisible($0, stored: TabBarPreferences.decode(storedVisible), customization: customization) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppTab.Group.allCases) { group in
                    Section {
                        ForEach(group.tabs) { tab in
                            let isVisible = visibleTabs.contains(tab)
                            Toggle(isOn: Binding(get: { isVisible }, set: { set(tab, visible: $0) })) {
                                Label(tab.title, systemImage: tab.systemImage)
                            }
                            .disabled(!isVisible && visibleTabs.count >= TabBarPreferences.maximumVisible)
                        }
                    } header: {
                        Text(group == .reference ? "Tab Bar · Reference" : "Tab Bar · Battle")
                    } footer: {
                        if group == .battle {
                            Text("Keep up to \(TabBarPreferences.maximumVisible) features in the tab bar alongside Home and Search. Everything is always on Home, and on iPad the sidebar lists every feature.")
                        }
                    }
                }

                Section("Your Data") {
                    Button("Clear Browsing History", systemImage: "clock.arrow.circlepath", role: .destructive) {
                        confirmingHistoryClear = true
                    }
                    Button {
                        reindexing = true
                        Task {
                            await SpotlightIndexer.reindex(database: database)
                            reindexing = false
                        }
                    } label: {
                        HStack {
                            Label("Rebuild Spotlight Index", systemImage: "magnifyingglass.circle")
                            if reindexing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(reindexing)
                }

                Section {
                    NavigationLink { AboutView() } label: { Label("About Neodex", systemImage: "info.circle") }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Clear your browsing history?", isPresented: $confirmingHistoryClear, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { History.clear(in: modelContext) }
            } message: {
                Text("Explore's recently viewed and personalised picks will start over.")
            }
        }
    }

    private func set(_ tab: AppTab, visible: Bool) {
        var tabs = visibleTabs
        if visible {
            guard !tabs.contains(tab), tabs.count < TabBarPreferences.maximumVisible else { return }
            tabs.append(tab)
            tabs.sort { (AppTab.features.firstIndex(of: $0) ?? 0) < (AppTab.features.firstIndex(of: $1) ?? 0) }
        } else {
            tabs.removeAll { $0 == tab }
        }
        storedVisible = TabBarPreferences.encode(tabs)
        // The toggles are the explicit choice; clear any visibility edits made in iPad's sidebar.
        customization.resetVisibility()
    }
}

#if DEBUG
#Preview { SettingsView().previewEnvironment() }
#endif
