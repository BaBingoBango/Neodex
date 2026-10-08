import Foundation

/// Pokémon Showdown-style identifiers: lowercase ASCII letters and digits only.
///
/// `"Charizard-Mega-X"` → `"charizardmegax"`, `"Flabébé"` → `"flabebe"`, `"Farfetch’d"` → `"farfetchd"`.
public enum ShowdownID {
    public static func make(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        var result = ""
        result.reserveCapacity(folded.count)
        for scalar in folded.lowercased().unicodeScalars {
            switch scalar {
            case "a"..."z", "0"..."9": result.unicodeScalars.append(scalar)
            case "♀": result += "f"
            case "♂": result += "m"
            default: continue
            }
        }
        return result
    }
}

/// Normalisation used for user-facing search: case- and diacritic-insensitive, punctuation ignored.
public enum SearchNormalizer {
    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        return folded.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
            .map(String.init).joined()
            .split(separator: " ").joined(separator: " ")
    }

    /// Word-boundary aware match used to rank search results.
    public enum MatchQuality: Int, Comparable, Sendable {
        case none = 0
        case contains = 1
        case wordPrefix = 2
        case prefix = 3
        case exact = 4

        public static func < (lhs: MatchQuality, rhs: MatchQuality) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// How well `candidate` matches a user query. Both arguments should already be normalised.
    public static func match(_ candidate: String, query: String) -> MatchQuality {
        guard !query.isEmpty else { return .contains }
        if candidate == query { return .exact }
        if candidate.hasPrefix(query) { return .prefix }
        if candidate.split(separator: " ").dropFirst().contains(where: { $0.hasPrefix(query) }) { return .wordPrefix }
        if candidate.contains(query) { return .contains }
        return .none
    }
}
