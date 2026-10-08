import Foundation
import NeodexKit

/// `neodex-data` — regenerates Neodex's bundled Pokédex from Pokémon Showdown and PokeAPI.
///
/// Usage: `swift run neodex-data [--output DIR] [--cache DIR] [--skip-images] [--force-images] [--limit N] [--pretty]`
@main
struct NeodexDataTool {
    struct Options {
        var outputDirectory: URL
        var cacheDirectory: URL
        var skipImages = false
        var forceImages = false
        var limit: Int?
        var pretty = false
        var concurrency = 8

        static func parse(_ arguments: [String]) throws -> Options {
            // Main.swift lives at Tools/NeodexData/Sources/neodex-data/Main.swift → five levels up is the repository root.
            var root = URL(fileURLWithPath: #filePath)
            for _ in 0..<5 { root.deleteLastPathComponent() }
            var options = Options(outputDirectory: root.appendingPathComponent("App/Resources"),
                                  cacheDirectory: root.appendingPathComponent("Tools/NeodexData/.cache"))
            var iterator = arguments.dropFirst().makeIterator()
            while let argument = iterator.next() {
                switch argument {
                case "--output": options.outputDirectory = URL(fileURLWithPath: try value(iterator.next(), for: argument))
                case "--cache": options.cacheDirectory = URL(fileURLWithPath: try value(iterator.next(), for: argument))
                case "--skip-images": options.skipImages = true
                case "--force-images": options.forceImages = true
                case "--pretty": options.pretty = true
                case "--limit": options.limit = Int(try value(iterator.next(), for: argument))
                case "--concurrency": options.concurrency = max(1, Int(try value(iterator.next(), for: argument)) ?? 8)
                case "--help", "-h":
                    print(usage)
                    exit(0)
                default:
                    throw OptionError.unknown(argument)
                }
            }
            return options
        }

        private static func value(_ value: String?, for flag: String) throws -> String {
            guard let value else { throw OptionError.missingValue(flag) }
            return value
        }

        enum OptionError: Error, LocalizedError {
            case unknown(String)
            case missingValue(String)
            var errorDescription: String? {
                switch self {
                case .unknown(let flag): "Unknown option \(flag)\n\n\(usage)"
                case .missingValue(let flag): "Missing value for \(flag)"
                }
            }
        }

        static let usage = """
        neodex-data — regenerate Neodex's bundled Pokédex data

        Options:
          --output DIR     Directory that receives Data/*.json and Images/ (default: App/Resources)
          --cache DIR      Download cache (default: Tools/NeodexData/.cache)
          --skip-images    Only regenerate JSON; keep existing images
          --force-images   Re-download and re-encode every image
          --limit N        Only include species up to National Dex number N (quick test runs)
          --pretty         Pretty-print the JSON output
          --concurrency N  Parallel image downloads (default 8)
        """
    }

    static func main() async {
        let start = Date()
        do {
            let options = try Options.parse(CommandLine.arguments)
            try await run(options)
            log(String(format: "Done in %.1f s.", Date().timeIntervalSince(start)))
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func run(_ options: Options) async throws {
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
        let sizes = try Writer.write(dataset, to: options.outputDirectory.appendingPathComponent("Data"), pretty: options.pretty)
        for (name, size) in sizes.sorted(by: { $0.key < $1.key }) {
            log(String(format: "  %@.json  %.1f MB", name, Double(size) / 1_000_000))
        }
        log("Pokémon: \(dataset.pokemon.count) (\(dataset.pokemon.filter(\.isBaseForm).count) species) · moves: \(dataset.moves.count) · abilities: \(dataset.abilities.count) · items: \(dataset.items.count) · learnsets: \(dataset.learnsets.count)")
        let downloads = await fetcher.downloads
        let hits = await fetcher.cacheHits
        log("Network: \(downloads) downloads, \(hits) cache hits")
    }

    static func log(_ message: String) {
        print(message)
        fflush(stdout)
    }
}
