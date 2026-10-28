import NeodexKit
import SwiftData
import SwiftUI

/// Settings: the iPhone tab bar layout, history, Spotlight and about. On the Mac this is the
/// Settings window (⌘,), without the tab bar section.
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
        content
            .confirmationDialog("Clear your browsing history?", isPresented: $confirmingHistoryClear, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { History.clear(in: modelContext) }
            } message: {
                Text("Explore's recently viewed and personalised picks will start over.")
            }
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        TabView {
            Tab("General", systemImage: "gearshape") {
                Form { dataSection }
                    .formStyle(.grouped)
                    .frame(width: 560, height: 300)
            }
            Tab("Champions Team", systemImage: "person.3") {
                ScopeLensTeamSettings()
            }
            Tab("Advisor", systemImage: "sparkles") {
                ScopeLensAdvisorSettings()
            }
            Tab("Meta", systemImage: "chart.bar.doc.horizontal") {
                ScopeLensMetaSettings()
            }
            Tab("About", systemImage: "info.circle") {
                AboutView()
                    .frame(width: 560, height: 480)
            }
        }
        #else
        NavigationStack {
            List {
                tabBarSections
                watchSection
                dataSection
                Section {
                    NavigationLink { AboutView() } label: { Label("About Neodex", systemImage: "info.circle") }
                }
            }
            .navigationTitle("Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        #endif
    }

    private var tabBarSections: some View {
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
    }

    #if os(iOS)
    /// What the watch has: teams travel over WatchConnectivity whenever they change.
    @ViewBuilder
    private var watchSection: some View {
        let link = WatchLink.shared
        if link.isPaired {
            Section {
                if link.isWatchAppInstalled {
                    LabeledContent("Teams on your watch", value: link.lastTeamSync == nil ? "Not sent yet" : "\(link.lastTeamCount), \(link.lastTeamSync!.formatted(date: .omitted, time: .shortened))")
                    Button("Send Teams Now", systemImage: "applewatch.radiowaves.left.and.right") { link.pushTeams() }
                } else {
                    Text("Install Neodex on your Apple Watch to see your teams and ask Dexbot from your wrist.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Apple Watch")
            }
        }
    }
    #else
    private var watchSection: some View { EmptyView() }
    #endif

    private var dataSection: some View {
        Section("Your Data") {
            Button(role: .destructive) {
                confirmingHistoryClear = true
            } label: {
                Label("Clear Browsing History", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(.red)
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
