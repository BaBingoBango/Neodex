import Foundation
import NeodexKit

/// Smogon conventions shared by the app and the leaderboard widget.
nonisolated enum UsageDefaults {
    /// Formats to offer when Smogon's list hasn't been fetched yet.
    static let fallbackFormats = ["gen9ou", "gen9ubers", "gen9uu", "gen9ru", "gen9nu", "gen9pu", "gen9lc", "gen9doublesou",
                                  "gen9monotype", "gen9nationaldex", "gen9randombattle"]

    /// Smogon's "standard" cutoff is 1695 for OU-style formats and 1630 elsewhere.
    static func defaultRating(for format: UsageFormat) -> Int {
        for preferred in [1695, 1630, 1760, 1500] where format.ratingCutoffs.contains(preferred) { return preferred }
        return format.ratingCutoffs.first ?? 0
    }

    /// `"2026-09"` → `"September 2026"`.
    static func displayMonth(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count >= 2, let year = Int(parts[0]), let monthNumber = Int(parts[1]) else { return month }
        var components = DateComponents()
        components.year = year
        components.month = monthNumber
        guard let date = Calendar.current.date(from: components) else { return month }
        return date.formatted(.dateTime.month(.wide).year())
    }
}
