import Foundation
import NeodexKit

/// The little a widget needs to know about a Pokémon; the app writes one of these per Pokémon.
nonisolated struct WidgetPokemon: Codable, Sendable, Hashable, Identifiable {
    var id: String
    var name: String
    var displayName: String
    var dexNumber: Int
    var types: [PokemonType]
    var genus: String?
    var entry: String?
    var imageID: String
    var isSpecies: Bool

    init(_ pokemon: Pokemon) {
        id = pokemon.id
        name = pokemon.name
        displayName = pokemon.displayName
        dexNumber = pokemon.nationalDexNumber
        types = pokemon.types
        genus = pokemon.genus
        entry = pokemon.dexEntries.first?.text
        imageID = pokemon.imageID
        isSpecies = pokemon.isBaseForm
    }

    var formattedDexNumber: String { "#" + String(format: "%04d", dexNumber) }
}

/// Two weeks of daily picks, written by the app so the widgets agree with Home.
nonisolated struct WidgetSnapshot: Codable, Sendable {
    struct Day: Codable, Sendable {
        var date: Date
        var pokemonID: String
        var mysteryID: String
    }

    var datasetVersion: String
    var writtenAt: Date
    var days: [Day]
}

/// Deterministic daily picks shared by Home and the widgets: the same Pokémon all day for everyone.
nonisolated enum DailyPick {
    static func dayOrdinal(for date: Date = .now) -> Int {
        Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    static func index(day: Int, count: Int, salt: Int) -> Int {
        guard count > 0 else { return 0 }
        return abs((day &* 7919 &+ salt) % count)
    }

    static func pokemonOfTheDay<T>(_ species: [T], on date: Date = .now) -> T? {
        species.isEmpty ? nil : species[index(day: dayOrdinal(for: date), count: species.count, salt: 0)]
    }

    /// A second, unrelated pick for "Who's that Pokémon?".
    static func mystery<T>(_ species: [T], on date: Date = .now) -> T? {
        species.isEmpty ? nil : species[index(day: dayOrdinal(for: date), count: species.count, salt: 104_729)]
    }
}

nonisolated enum WidgetKind {
    static let pokemonOfTheDay = "Ethan.Neodex.pokemonOfTheDay"
    static let mystery = "Ethan.Neodex.mystery"
    static let team = "Ethan.Neodex.team"
    static let leaderboard = "Ethan.Neodex.leaderboard"
}
