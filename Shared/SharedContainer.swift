import Foundation

/// The App Group the app shares with its widgets, and what lives in it.
nonisolated enum SharedContainer {
    static let groupID = "group.Ethan.Neodex"
    /// `neodex://pokemon/garchomp`, `neodex://team/<uuid>`, `neodex://stats/gen9ou`, `neodex://calc`,
    /// `neodex://random`, `neodex://today`, `neodex://mystery`.
    static let urlScheme = "neodex"

    static var url: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) }
    static var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }

    /// The SwiftData store, placed in the group so the Team widget can read it.
    static var storeURL: URL? { url?.appendingPathComponent("Neodex.store") }
    static var widgetDataURL: URL? { url?.appendingPathComponent("WidgetData", isDirectory: true) }
    static var snapshotURL: URL? { widgetDataURL?.appendingPathComponent("snapshot.json") }
    static var indexURL: URL? { widgetDataURL?.appendingPathComponent("pokemon-index.json") }
    static func spriteURL(_ imageID: String) -> URL? { widgetDataURL?.appendingPathComponent("sprites/\(imageID)-sprite.png") }
    static func artworkURL(_ imageID: String) -> URL? { widgetDataURL?.appendingPathComponent("artwork/\(imageID)-art.heic") }

    enum DefaultsKey {
        /// Format IDs the app last saw on Smogon, for the leaderboard widget's picker.
        static let usageFormats = "usageFormats"
        /// The format Home's "Popular on Showdown" shows; the leaderboard widget's default.
        static let popularFormat = "popularFormat"
        /// Formats starred in the format picker, shared by Global Stats and Home.
        static let favoriteFormats = "favoriteFormats"
        /// Day ordinal on which the mystery Pokémon was revealed.
        static let mysteryRevealedDay = "mysteryRevealedDay"
    }

    static func deepLink(_ path: String) -> URL { URL(string: "\(urlScheme)://\(path)")! }
}
