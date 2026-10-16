import Foundation
import NeodexKit
import WidgetKit

/// Keeps the App Group stocked with what the widgets need: a compact Pokémon index, every sprite,
/// artwork for two weeks of daily picks, and the pick schedule itself.
enum WidgetBridge {
    static func refresh(database: PokedexDatabase) async {
        guard let dataURL = SharedContainer.widgetDataURL, let snapshotURL = SharedContainer.snapshotURL,
              let indexURL = SharedContainer.indexURL else { return }
        let version = database.manifest?.displayVersion ?? "unknown"
        let species = database.species
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var days: [WidgetSnapshot.Day] = []
        for offset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                  let pick = DailyPick.pokemonOfTheDay(species, on: date),
                  let mystery = DailyPick.mystery(species, on: date) else { continue }
            days.append(WidgetSnapshot.Day(date: date, pokemonID: pick.id, mysteryID: mystery.id))
        }
        let snapshot = WidgetSnapshot(datasetVersion: version, writtenAt: .now, days: days)
        let index = database.pokemon.map(WidgetPokemon.init)
        let artworkIDs = Set(days.flatMap { [$0.pokemonID, $0.mysteryID] }).compactMap { database.pokemon(id: $0)?.imageID }
        let spriteIDs = database.pokemon.map(\.imageID)
        await write(snapshot: snapshot, index: index, artworkIDs: artworkIDs, spriteIDs: spriteIDs, version: version,
                    dataURL: dataURL, snapshotURL: snapshotURL, indexURL: indexURL)
        WidgetCenter.shared.reloadAllTimelines()
    }

    @concurrent
    nonisolated private static func write(snapshot: WidgetSnapshot, index: [WidgetPokemon], artworkIDs: [String], spriteIDs: [String],
                                          version: String, dataURL: URL, snapshotURL: URL, indexURL: URL) async {
        let fileManager = FileManager.default
        let sprites = dataURL.appendingPathComponent("sprites", isDirectory: true)
        let artwork = dataURL.appendingPathComponent("artwork", isDirectory: true)
        try? fileManager.createDirectory(at: sprites, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: artwork, withIntermediateDirectories: true)

        // Every sprite, copied once per dataset version (about 5 MB).
        let marker = dataURL.appendingPathComponent("sprites-version.txt")
        if (try? String(contentsOf: marker, encoding: .utf8)) != version {
            for imageID in spriteIDs {
                guard let source = Bundle.main.url(forResource: "\(imageID)-sprite", withExtension: "png") else { continue }
                let destination = sprites.appendingPathComponent("\(imageID)-sprite.png")
                try? fileManager.removeItem(at: destination)
                try? fileManager.copyItem(at: source, to: destination)
            }
            try? version.write(to: marker, atomically: true, encoding: .utf8)
        }
        // Artwork only for the scheduled picks; drop what's no longer scheduled.
        let wanted = Set(artworkIDs.map { "\($0)-art.heic" })
        for existing in (try? fileManager.contentsOfDirectory(atPath: artwork.path)) ?? [] where !wanted.contains(existing) {
            try? fileManager.removeItem(at: artwork.appendingPathComponent(existing))
        }
        for imageID in artworkIDs {
            let destination = artwork.appendingPathComponent("\(imageID)-art.heic")
            guard !fileManager.fileExists(atPath: destination.path),
                  let source = Bundle.main.url(forResource: "\(imageID)-art", withExtension: "heic") else { continue }
            try? fileManager.copyItem(at: source, to: destination)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(index).write(to: indexURL, options: .atomic)
        try? encoder.encode(snapshot).write(to: snapshotURL, options: .atomic)
    }
}
