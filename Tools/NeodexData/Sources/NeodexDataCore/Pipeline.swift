import Foundation
import NeodexKit

/// Settings for one pipeline run.
package struct PipelineOptions: Sendable {
    /// Receives `Data/*.json` and `Images/`.
    package var outputDirectory: URL
    /// Receives the Xcode Previews fixture (`preview-*.json`).
    package var previewDirectory: URL
    /// Download cache; re-runs are offline once it is warm.
    package var cacheDirectory: URL
    package var skipImages = false
    package var forceImages = false
    /// Only include species up to this National Dex number (quick test runs).
    package var limit: Int?
    package var pretty = false
    package var concurrency = 8

    package init(outputDirectory: URL, previewDirectory: URL, cacheDirectory: URL) {
        self.outputDirectory = outputDirectory
        self.previewDirectory = previewDirectory
        self.cacheDirectory = cacheDirectory
    }
}

/// Runs the whole pipeline: download, build, verify, process images, write JSON, refresh the preview fixture.
package enum Pipeline {
    package typealias Log = @Sendable (String) -> Void

    package static func run(_ options: PipelineOptions, log: Log) async throws {
        let fetcher = Fetcher(cacheDirectory: options.cacheDirectory)

        log("Loading Pokémon Showdown data…")
        let showdown = try await ShowdownData.load(using: fetcher)
        log("  \(showdown.pokedex.count) pokedex entries, \(showdown.moves.count) moves, \(showdown.abilities.count) abilities, \(showdown.items.count) items, \(showdown.learnsets.count) learnsets")

        log("Loading PokeAPI data…")
        let pokeapi = try await PokeAPIData.load(using: fetcher)
        log("  \(pokeapi.species.count) species, \(pokeapi.pokemon.count) Pokémon rows, \(pokeapi.moves.count) moves, \(pokeapi.items.count) items")

        log("Building dataset…")
        var builder = DatasetBuilder(showdown: showdown, pokeapi: pokeapi)
        builder.limit = options.limit
        var dataset = try builder.build()
        for note in dataset.notes { log("  " + note) }

        log("Verifying…")
        let warnings = try Verifier.verify(dataset, showdown: showdown)
        for warning in warnings { log("  warning: \(warning)") }

        let imagesDirectory = options.outputDirectory.appendingPathComponent("Images")
        if options.skipImages {
            // Keep image IDs consistent with whatever artwork already exists on disk.
            let artwork = imagesDirectory.appendingPathComponent("artwork")
            for index in dataset.pokemon.indices {
                let entry = dataset.pokemon[index]
                let own = artwork.appendingPathComponent("\(entry.id)-art.heic").path
                if !FileManager.default.fileExists(atPath: own), !entry.isBaseForm {
                    dataset.pokemon[index].imageID = entry.speciesID
                }
            }
            log("Skipping images.")
        } else {
            log("Processing images (this downloads ~\(dataset.pokemon.count) artworks on a fresh cache)…")
            var pipeline = ImagePipeline(fetcher: fetcher, imagesDirectory: imagesDirectory)
            pipeline.concurrency = options.concurrency
            pipeline.force = options.forceImages
            let report = try await pipeline.run(pokemon: &dataset.pokemon, pokeapiIDs: dataset.pokeapiPokemonIDs,
                                                spriteIDs: dataset.spriteIDs, items: dataset.items)
            log("  artwork files: \(report.artworkWritten), item icons: \(report.itemIcons)")
            if !report.dexSpriteFallbacks.isEmpty { log("  using Showdown dex sprite as artwork (\(report.dexSpriteFallbacks.count)): " + report.dexSpriteFallbacks.joined(separator: ", ")) }
            if !report.speciesFallbacks.isEmpty { log("  using base species artwork (\(report.speciesFallbacks.count)): " + report.speciesFallbacks.joined(separator: ", ")) }
            if !report.missingArtwork.isEmpty { log("  WARNING no artwork (\(report.missingArtwork.count)): " + report.missingArtwork.joined(separator: ", ")) }
            if !report.missingSprites.isEmpty { log("  WARNING no sprite (\(report.missingSprites.count)): " + report.missingSprites.joined(separator: ", ")) }
        }

        log("Writing JSON…")
        let dataDirectory = options.outputDirectory.appendingPathComponent("Data")
        let sizes = try Writer.write(dataset, to: dataDirectory, pretty: options.pretty)
        for (name, size) in sizes.sorted(by: { $0.key < $1.key }) {
            log(String(format: "  %@.json  %.1f MB", name, Double(size) / 1_000_000))
        }
        log("Pokémon: \(dataset.pokemon.count) (\(dataset.pokemon.filter(\.isBaseForm).count) species) · moves: \(dataset.moves.count) · abilities: \(dataset.abilities.count) · items: \(dataset.items.count) · learnsets: \(dataset.learnsets.count)")

        log("Writing preview fixture…")
        let summary = try PreviewFixture.write(from: dataDirectory, to: options.previewDirectory, pretty: options.pretty)
        log("  " + summary.description)

        let downloads = await fetcher.downloads
        let hits = await fetcher.cacheHits
        log("Network: \(downloads) downloads, \(hits) cache hits")
    }
}
