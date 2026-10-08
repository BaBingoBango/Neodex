import Foundation
import NeodexDataCore

/// `neodex-data` — regenerates Neodex's bundled Pokédex from Pokémon Showdown and PokeAPI.
///
/// Usage: `swift run neodex-data [--output DIR] [--cache DIR] [--skip-images] [--force-images] [--limit N] [--pretty]`
///        `swift run neodex-data --preview-fixture` rebuilds only the Xcode Previews fixture from the existing data.
@main
struct NeodexDataTool {
    struct Arguments {
        var options: PipelineOptions
        var previewFixtureOnly = false

        static func parse(_ arguments: [String]) throws -> Arguments {
            // Main.swift lives at Tools/NeodexData/Sources/neodex-data/Main.swift → five levels up is the repository root.
            var root = URL(fileURLWithPath: #filePath)
            for _ in 0..<5 { root.deleteLastPathComponent() }
            var parsed = Arguments(options: PipelineOptions(
                outputDirectory: root.appendingPathComponent("App/Resources"),
                previewDirectory: root.appendingPathComponent("App/Preview Content"),
                cacheDirectory: root.appendingPathComponent("Tools/NeodexData/.cache")
            ))
            var iterator = arguments.dropFirst().makeIterator()
            while let argument = iterator.next() {
                switch argument {
                case "--output": parsed.options.outputDirectory = URL(fileURLWithPath: try value(iterator.next(), for: argument))
                case "--preview-output": parsed.options.previewDirectory = URL(fileURLWithPath: try value(iterator.next(), for: argument))
                case "--cache": parsed.options.cacheDirectory = URL(fileURLWithPath: try value(iterator.next(), for: argument))
                case "--skip-images": parsed.options.skipImages = true
                case "--force-images": parsed.options.forceImages = true
                case "--pretty": parsed.options.pretty = true
                case "--limit": parsed.options.limit = Int(try value(iterator.next(), for: argument))
                case "--concurrency": parsed.options.concurrency = max(1, Int(try value(iterator.next(), for: argument)) ?? 8)
                case "--preview-fixture": parsed.previewFixtureOnly = true
                case "--help", "-h":
                    print(usage)
                    exit(0)
                default:
                    throw OptionError.unknown(argument)
                }
            }
            return parsed
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
          --output DIR          Directory that receives Data/*.json and Images/ (default: App/Resources)
          --preview-output DIR  Directory that receives the Xcode Previews fixture (default: App/Preview Content)
          --cache DIR           Download cache (default: Tools/NeodexData/.cache)
          --skip-images         Only regenerate JSON; keep existing images
          --force-images        Re-download and re-encode every image
          --limit N             Only include species up to National Dex number N (quick test runs)
          --pretty              Pretty-print the JSON output
          --concurrency N       Parallel image downloads (default 8)
          --preview-fixture     Only rebuild the preview fixture from the existing generated data
        """
    }

    static func main() async {
        let start = Date()
        do {
            let arguments = try Arguments.parse(CommandLine.arguments)
            if arguments.previewFixtureOnly {
                let summary = try PreviewFixture.write(from: arguments.options.outputDirectory.appendingPathComponent("Data"),
                                                       to: arguments.options.previewDirectory, pretty: arguments.options.pretty)
                log("Preview fixture: \(summary)")
            } else {
                try await Pipeline.run(arguments.options) { message in NeodexDataTool.log(message) }
            }
            log(String(format: "Done in %.1f s.", Date().timeIntervalSince(start)))
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func log(_ message: String) {
        print(message)
        fflush(stdout)
    }
}
