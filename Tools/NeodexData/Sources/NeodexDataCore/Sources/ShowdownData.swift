import Foundation

/// Raw Pokémon Showdown data, keyed by Showdown ID.
struct ShowdownData: Sendable {
    var pokedex: [String: JSONValue]
    var moves: [String: JSONValue]
    var abilities: [String: JSONValue]
    var items: [String: JSONValue]
    var learnsets: [String: JSONValue]
    var aliases: [String: String]
    var abilitiesText: [String: JSONValue]
    var movesText: [String: JSONValue]
    var itemsText: [String: JSONValue]
    var natures: [String: JSONValue]
    var typeChart: [String: JSONValue]

    static let clientBase = URL(string: "https://play.pokemonshowdown.com/data/")!
    static let serverBase = URL(string: "https://raw.githubusercontent.com/smogon/pokemon-showdown/master/data/")!
    static let spriteBase = URL(string: "https://play.pokemonshowdown.com/sprites/")!

    static func load(using fetcher: Fetcher) async throws -> ShowdownData {
        async let pokedex = clientModule("pokedex", export: "BattlePokedex", fetcher)
        async let moves = clientModule("moves", export: "BattleMovedex", fetcher)
        async let abilities = clientModule("abilities", export: "BattleAbilities", fetcher)
        async let items = clientModule("items", export: "BattleItems", fetcher)
        async let learnsets = clientModule("learnsets", export: "BattleLearnsets", fetcher)
        async let aliases = clientModule("aliases", export: "BattleAliases", fetcher)
        async let abilitiesText = serverModule("text/abilities", fetcher)
        async let movesText = serverModule("text/moves", fetcher)
        async let itemsText = serverModule("text/items", fetcher)
        async let natures = serverModule("natures", fetcher)
        async let typeChart = serverModule("typechart", fetcher)

        return try await ShowdownData(
            pokedex: pokedex, moves: moves, abilities: abilities, items: items, learnsets: learnsets,
            aliases: aliases.compactMapValues(\.string),
            abilitiesText: abilitiesText, movesText: movesText, itemsText: itemsText,
            natures: natures, typeChart: typeChart
        )
    }

    private static func clientModule(_ name: String, export: String, _ fetcher: Fetcher) async throws -> [String: JSONValue] {
        let source = try await fetcher.string(for: clientBase.appendingPathComponent("\(name).js"))
        let json = try JSEvaluator.clientModuleJSON(source, exportName: export)
        return try JSONValue.decode(json).object ?? [:]
    }

    private static func serverModule(_ path: String, _ fetcher: Fetcher) async throws -> [String: JSONValue] {
        let source = try await fetcher.string(for: serverBase.appendingPathComponent("\(path).ts"))
        let json = try JSEvaluator.typeScriptModuleJSON(source)
        return try JSONValue.decode(json).object ?? [:]
    }

    /// Showdown's sprite file stem for a species entry, e.g. `charizard-megax`, `raichu-alola`.
    static func spriteID(for entry: JSONValue) -> String {
        guard let name = entry["name"]?.string else { return "" }
        if let base = entry["baseSpecies"]?.string, let forme = entry["forme"]?.string, !forme.isEmpty {
            return toID(base) + "-" + toID(forme)
        }
        return toID(name)
    }

    /// Showdown's `toID`: lowercase letters and digits only (accents are kept out by the data itself).
    static func toID(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        return folded.unicodeScalars.filter { ("a"..."z").contains($0) || ("0"..."9").contains($0) }.map(String.init).joined()
    }
}
