import Foundation

/// Identifiers of the watch complications, shared by the watch app (to reload them) and its extension.
nonisolated enum WatchComplicationKind {
    static let pokemonOfTheDay = "watch.pokemonOfTheDay"
    static let mystery = "watch.mystery"
    static let open = "watch.open"
}
