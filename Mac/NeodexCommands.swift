import SwiftUI

/// The menu bar: a Go menu for every sidebar destination and a Pokémon menu for the daily picks.
/// Entries the Pokémon menu opens appear in their own window, like a Spotlight result would.
struct NeodexCommands: Commands {
    @FocusedBinding(\.tabSelection) private var selection: AppTab?

    var body: some Commands {
        CommandMenu("Go") {
            goItem(.home, key: "1")
            Divider()
            ForEach(Array(AppTab.features.enumerated()), id: \.element) { index, tab in
                goItem(tab, key: index < 8 ? KeyEquivalent(Character(String(index + 2))) : nil)
            }
            Divider()
            goItem(.search, key: "f", modifiers: [.command, .option])
        }
        CommandMenu("Pokémon") {
            Button("Random Pokémon", systemImage: "dice") { DeepLinkRouter.shared.pendingPick = .random }
                .keyboardShortcut("r", modifiers: .command)
            Button("Pokémon of the Day", systemImage: "calendar") { DeepLinkRouter.shared.pendingPick = .today }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Button("Who's That Pokémon?", systemImage: "questionmark.circle") { DeepLinkRouter.shared.pendingPick = .mystery }
                .keyboardShortcut("m", modifiers: [.command, .option])
        }
        CommandGroup(replacing: .help) {
            Link("Neodex on GitHub", destination: URL(string: "https://github.com/BaBingoBango/Neodex")!)
        }
    }

    /// A menu item that selects `tab` in the frontmost window; disabled when no window has focus.
    @ViewBuilder
    private func goItem(_ tab: AppTab, key: KeyEquivalent?, modifiers: EventModifiers = .command) -> some View {
        let item = Button(tab.title, systemImage: tab.systemImage) { selection = tab }
            .disabled(selection == nil)
        if let key {
            item.keyboardShortcut(key, modifiers: modifiers)
        } else {
            item
        }
    }
}
