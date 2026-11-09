import AppIntents
import Foundation
import NeodexKit

/// The Pokémon that Siri and Shortcuts know by name, as in "Open Pikachu in Neodex".
///
/// The system writes out one phrase for every pairing of a phrase and a suggested Pokémon, and gives an
/// app 1,000 of them. Suggesting every species made 7,182, and the Shortcuts app lagged searching them.
/// So the list is short: your favorites, then Pokémon everyone knows. Any other Pokémon is one question
/// away ("Open a Pokémon in Neodex").
///
/// Recently viewed Pokémon stay out of it. Home tells people their browsing history never leaves the
/// device, and Apple's documentation says it may extract App Shortcuts data, the values shown for
/// parameters included, to improve the feature.
enum ShortcutPokemon {
    /// Seven phrases take a Pokémon, so 50 names make 350 phrases.
    nonisolated static let limit = 50

    /// The names a new install starts with, a few from each generation. Favorites push the last ones out.
    nonisolated static let wellKnown = [
        "pikachu", "charizard", "eevee", "mewtwo", "mew", "bulbasaur", "squirtle", "gengar", "snorlax", "dragonite",
        "gyarados", "lapras", "jigglypuff", "psyduck", "umbreon", "tyranitar", "lugia", "scizor", "togepi", "blaziken",
        "gardevoir", "rayquaza", "metagross", "mudkip", "lucario", "garchomp", "piplup", "darkrai", "zoroark", "hydreigon",
        "volcarona", "greninja", "sylveon", "aegislash", "mimikyu", "incineroar", "rowlet", "dragapult", "cinderace",
        "corviknight", "meowscarada", "gholdengo", "kingambit", "tinkaton", "sprigatito", "fuecoco", "quaxly", "greattusk",
        "koraidon", "miraidon",
    ]

    /// Favorites, newest first, then the well-known, without repeats.
    nonisolated static func pick(favorites: [String], limit: Int = limit) -> [String] {
        var seen = Set<String>()
        return Array((favorites.reversed() + wellKnown).filter { seen.insert($0).inserted }.prefix(limit))
    }

    /// The list as it stands.
    static func ids() -> [String] { pick(favorites: FavoritePokemon.shared.ids) }

    /// The favorites the system's phrases were last built from.
    private static var sentFavorites: [String]?

    /// Has the system rebuild its phrases from the list as it stands. Called once the Pokédex has loaded.
    static func refreshPhrases() {
        sentFavorites = FavoritePokemon.shared.ids
        NeodexShortcuts.updateAppShortcutParameters()
    }

    /// Rebuilds the phrases when a Pokémon was hearted or un-hearted since they were last built.
    static func refreshPhrasesIfFavoritesChanged() {
        if FavoritePokemon.shared.ids != sentFavorites { refreshPhrases() }
    }
}
