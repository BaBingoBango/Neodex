import Foundation
import NeodexKit

/// Writes the generated JSON files and the provenance manifest.
enum Writer {
    static let sources = [
        DataManifest.DataSource(name: "Pokémon Showdown", url: "https://github.com/smogon/pokemon-showdown", license: "MIT"),
        DataManifest.DataSource(name: "PokeAPI", url: "https://github.com/PokeAPI/pokeapi", license: "BSD-3-Clause"),
        DataManifest.DataSource(name: "PokeAPI sprites", url: "https://github.com/PokeAPI/sprites", license: "Pokémon artwork © Nintendo / Game Freak / The Pokémon Company"),
        DataManifest.DataSource(name: "Pokémon Showdown sprites", url: "https://play.pokemonshowdown.com/sprites/", license: "Pokémon sprites © Nintendo / Game Freak / The Pokémon Company"),
    ]

    static func write(_ dataset: Dataset, to dataDirectory: URL, pretty: Bool) throws -> [String: Int] {
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        var sizes: [String: Int] = [:]
        func write<T: Encodable>(_ value: T, as name: String) throws {
            let data = try encoder.encode(value)
            try data.write(to: dataDirectory.appendingPathComponent("\(name).json"), options: .atomic)
            sizes[name] = data.count
        }
        try write(dataset.pokemon, as: "pokemon")
        try write(dataset.moves, as: "moves")
        try write(dataset.abilities, as: "abilities")
        try write(dataset.items, as: "items")
        try write(dataset.learnsets, as: "learnsets")

        let now = Date()
        let manifest = DataManifest(
            generatedAt: now,
            schemaVersion: DataManifest.currentSchemaVersion,
            counts: DataManifest.Counts(pokemon: dataset.pokemon.count, species: dataset.pokemon.filter(\.isBaseForm).count,
                                        moves: dataset.moves.count, abilities: dataset.abilities.count, items: dataset.items.count,
                                        learnsets: dataset.learnsets.count),
            sources: sources,
            version: DataManifest.calendarVersion(for: now),
            releaseNotes: releaseNotes(for: dataset, generatedAt: now)
        )
        try write(manifest, as: "manifest")
        return sizes
    }

    /// "What's new" lines for the app's dataset card, derived from the dataset itself.
    static func releaseNotes(for dataset: Dataset, generatedAt: Date) -> [String] {
        var notes: [String] = []
        let species = dataset.pokemon.filter(\.isBaseForm)
        if let newest = species.max(by: { $0.nationalDexNumber < $1.nationalDexNumber }) {
            let forms = dataset.pokemon.count - species.count
            let megas = dataset.pokemon.filter { $0.formKind == .mega }.count
            notes.append("Every Pokémon through #\(newest.nationalDexNumber) \(newest.displayName), with \(forms.formatted()) alternate forms including \(megas.formatted()) Mega Evolutions.")
        }
        notes.append("\(dataset.moves.count.formatted()) moves, \(dataset.abilities.count.formatted()) Abilities and \(dataset.items.count.formatted()) items with in-game and competitive descriptions.")
        let generation = dataset.pokemon.map(\.generation).max() ?? 9
        notes.append("Generation \(generation) learnsets for \(dataset.learnsets.count.formatted()) Pokémon, plus Smogon tiers and Pokémon Showdown data as of \(generatedAt.formatted(date: .long, time: .omitted)).")
        return notes
    }
}
