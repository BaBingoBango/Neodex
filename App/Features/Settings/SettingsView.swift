import NeodexKit
import SwiftData
import SwiftUI

/// Settings: tab bar layout, history, Spotlight and about.
struct SettingsView: View {
    @Environment(\.database) private var database
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TabPreferences.key) private var storedTabs = TabPreferences.encode(TabPreferences.defaultTabs)
    @State private var confirmingHistoryClear = false
    @State private var reindexing = false

    private var selectedTabs: [AppTab] { TabPreferences.decode(storedTabs) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppTab.customizable) { tab in
                        Toggle(isOn: Binding(get: { selectedTabs.contains(tab) }, set: { set(tab, selected: $0) })) {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                        .disabled(!selectedTabs.contains(tab) && selectedTabs.count >= TabPreferences.maximumCustomTabs)
                    }
                } header: {
                    Text("Tab Bar")
                } footer: {
                    Text("Choose up to \(TabPreferences.maximumCustomTabs) features to keep alongside Home and Search. Everything is always available from Home.")
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

    private func set(_ tab: AppTab, selected: Bool) {
        var tabs = selectedTabs
        if selected {
            guard !tabs.contains(tab), tabs.count < TabPreferences.maximumCustomTabs else { return }
            tabs.append(tab)
            tabs.sort { (AppTab.customizable.firstIndex(of: $0) ?? 0) < (AppTab.customizable.firstIndex(of: $1) ?? 0) }
        } else {
            tabs.removeAll { $0 == tab }
        }
        storedTabs = TabPreferences.encode(tabs)
    }
}

#if DEBUG
#Preview { SettingsView().previewEnvironment() }
#endif
