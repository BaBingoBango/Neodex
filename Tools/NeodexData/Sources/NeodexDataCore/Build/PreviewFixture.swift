import Foundation
import NeodexKit

/// Writes a small, self-consistent slice of the generated dataset for Xcode Previews.
///
/// Starting from a handful of well-known species, the fixture pulls in their whole evolution
/// families and alternate forms, every move they can learn, every ability they can have and
/// the items that matter to them, so previews behave exactly like the real app.
/// Files are prefixed (`preview-pokemon.json`) because Xcode flattens resources into the bundle root.
package enum PreviewFixture {
    package static let filePrefix = "preview-"

    /// Showdown IDs that seed the fixture. Chosen to cover branching evolutions, Megas,
    /// Gigantamax, regional forms, Paradox Pokémon and the newest generation.
    package static let seedSpecies = [
        "bulbasaur", "charizard", "pikachu", "eevee", "gengar", "garchomp", "dragonite",
        "greattusk", "gholdengo", "kingambit", "ogerpon", "pecharunt", "mimikyu", "lucario",
    ]

    /// Items worth having around in previews even when no seed Pokémon requires them.
    package static let seedItems = [
        "leftovers", "choicescarf", "choiceband", "choicespecs", "heavydutyboots", "rockyhelmet", "airballoon",
        "lifeorb", "focussash", "assaultvest", "boosterenergy", "sitrusberry", "lumberry", "lightball",
        "thunderstone", "firestone", "waterstone", "leafstone", "icestone", "eviolite", "expertbelt",
    ]

    package struct Summary: Sendable, CustomStringConvertible {
        package var pokemon: Int
        package var moves: Int
        package var abilities: Int
        package var items: Int
        package var learnsets: Int
        package var bytes: Int

        package var description: String {
            String(format: "%d Pokémon, %d moves, %d abilities, %d items, %d learnsets · %.2f MB",
                   pokemon, moves, abilities, items, learnsets, Double(bytes) / 1_000_000)
        }
    }

    package enum FixtureError: Error, LocalizedError {
        case noSeedsFound

        package var errorDescription: String? {
            "None of the seed species exist in the dataset; was the pipeline run with --limit?"
        }
    }

    /// Reads the generated JSON in `dataDirectory` and writes the fixture into `outputDirectory`.
    @discardableResult
    package static func write(from dataDirectory: URL, to outputDirectory: URL, pretty: Bool = false) throws -> Summary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        func read<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            try decoder.decode(type, from: Data(contentsOf: dataDirectory.appendingPathComponent("\(name).json")))
        }
        let pokemon = try read("pokemon", as: [Pokemon].self)
        let moves = try read("moves", as: [Move].self)
        let abilities = try read("abilities", as: [Ability].self)
        let items = try read("items", as: [Item].self)
        let learnsets = try read("learnsets", as: [String: Learnset].self)
        let manifest = try? read("manifest", as: DataManifest.self)

        let subset = select(pokemon: pokemon, moves: moves, abilities: abilities, items: items, learnsets: learnsets)
        guard !subset.pokemon.isEmpty else { throw FixtureError.noSeedsFound }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        var bytes = 0
        func store<T: Encodable>(_ value: T, as name: String) throws {
            let data = try encoder.encode(value)
            try data.write(to: outputDirectory.appendingPathComponent("\(filePrefix)\(name).json"), options: .atomic)
            bytes += data.count
        }
        try store(subset.pokemon, as: "pokemon")
        try store(subset.moves, as: "moves")
        try store(subset.abilities, as: "abilities")
        try store(subset.items, as: "items")
        try store(subset.learnsets, as: "learnsets")
        try store(DataManifest(
            generatedAt: Date(),
            schemaVersion: DataManifest.currentSchemaVersion,
            counts: DataManifest.Counts(pokemon: subset.pokemon.count, species: subset.pokemon.filter(\.isBaseForm).count,
                                        moves: subset.moves.count, abilities: subset.abilities.count, items: subset.items.count,
                                        learnsets: subset.learnsets.count),
            sources: manifest?.sources ?? Writer.sources
        ), as: "manifest")

        return Summary(pokemon: subset.pokemon.count, moves: subset.moves.count, abilities: subset.abilities.count,
                       items: subset.items.count, learnsets: subset.learnsets.count, bytes: bytes)
    }

    struct Subset {
        var pokemon: [Pokemon]
        var moves: [Move]
        var abilities: [Ability]
        var items: [Item]
        var learnsets: [String: Learnset]
    }

    /// Chooses the closed set of entities reachable from the seeds. Pure, so it is easy to test.
    static func select(pokemon: [Pokemon], moves: [Move], abilities: [Ability], items: [Item],
                       learnsets: [String: Learnset]) -> Subset {
        let byID = Dictionary(uniqueKeysWithValues: pokemon.map { ($0.id, $0) })

        // Breadth-first over families and forms so evolutions and form links never dangle.
        var included = Set<String>()
        var queue = seedSpecies.filter { byID[$0] != nil }
        while let id = queue.popLast() {
            guard included.insert(id).inserted, let entry = byID[id] else { continue }
            var neighbours = entry.otherFormIDs + entry.evolutions.map(\.to)
            if let from = entry.evolvesFrom { neighbours.append(from) }
            if let changesFrom = entry.changesFrom { neighbours.append(changesFrom) }
            queue.append(contentsOf: neighbours.filter { byID[$0] != nil && !included.contains($0) })
        }

        let chosenPokemon = pokemon.filter { included.contains($0.id) }
        var chosenLearnsets: [String: Learnset] = [:]
        var moveIDs = Set<String>()
        var abilityIDs = Set<String>()
        var itemIDs = Set(seedItems)
        for entry in chosenPokemon {
            if let learnset = learnsets[entry.id] {
                chosenLearnsets[entry.id] = learnset
                moveIDs.formUnion(learnset.moves.keys)
            } else if let learnset = learnsets[entry.speciesID] {
                moveIDs.formUnion(learnset.moves.keys)
            }
            abilityIDs.formUnion(entry.abilities.all)
            itemIDs.formUnion(entry.requiredItems ?? [])
        }
        let chosenItems = items.filter { itemIDs.contains($0.id) }
        // Mega Stones and signature items point back at Pokémon by name; keep those references resolvable.
        let chosenAbilities = abilities.filter { abilityIDs.contains($0.id) }
        let chosenMoves = moves.filter { moveIDs.contains($0.id) }
        return Subset(pokemon: chosenPokemon, moves: chosenMoves, abilities: chosenAbilities, items: chosenItems,
                      learnsets: chosenLearnsets)
    }
}
