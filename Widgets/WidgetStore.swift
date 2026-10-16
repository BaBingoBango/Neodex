import Foundation
import NeodexKit
import UIKit

/// Reads what the app left in the App Group for the widgets.
nonisolated enum WidgetStore {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func index() -> [WidgetPokemon] {
        guard let url = SharedContainer.indexURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([WidgetPokemon].self, from: data)) ?? []
    }

    static func snapshot() -> WidgetSnapshot? {
        guard let url = SharedContainer.snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// The scheduled pick for a day, falling back to the shared formula when the schedule has run out.
    static func pick(on date: Date, mystery: Bool, index: [WidgetPokemon]) -> WidgetPokemon? {
        let day = Calendar.current.startOfDay(for: date)
        if let scheduled = snapshot()?.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            let id = mystery ? scheduled.mysteryID : scheduled.pokemonID
            if let pokemon = index.first(where: { $0.id == id }) { return pokemon }
        }
        let species = index.filter(\.isSpecies)
        return mystery ? DailyPick.mystery(species, on: date) : DailyPick.pokemonOfTheDay(species, on: date)
    }

    static func sprite(_ imageID: String) -> UIImage? {
        SharedContainer.spriteURL(imageID).flatMap { UIImage(contentsOfFile: $0.path) }
    }

    static func artwork(_ imageID: String) -> UIImage? {
        SharedContainer.artworkURL(imageID).flatMap { UIImage(contentsOfFile: $0.path) }
    }

    static func isMysteryRevealed(on date: Date) -> Bool {
        SharedContainer.defaults?.integer(forKey: SharedContainer.DefaultsKey.mysteryRevealedDay) == DailyPick.dayOrdinal(for: date)
    }

    /// Showdown-style name matching for Smogon's rankings.
    static func pokemon(named name: String, in index: [WidgetPokemon]) -> WidgetPokemon? {
        let key = ShowdownID.make(name)
        return index.first { $0.id == key } ?? index.first { ShowdownID.make($0.name) == key }
    }
}
