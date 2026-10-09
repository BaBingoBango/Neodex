import Foundation

/// The complete, immutable Pokédex dataset with fast lookups.
///
/// Create one with ``load(from:)`` at launch. All data is loaded into memory once; the
/// instance is `Sendable` so it can be shared freely between actors and views.
public final class PokedexDatabase: Sendable {
    /// Every Pokémon and form, sorted by National Pokédex number then form order.
    public let pokemon: [Pokemon]
    /// Every move, sorted by name.
    public let moves: [Move]
    /// Every ability, sorted by name.
    public let abilities: [Ability]
    /// Every item, sorted by name.
    public let items: [Item]
    /// All 25 natures.
    public let natures: [Nature]
    public let manifest: DataManifest?

    private let pokemonIndex: [String: Int]
    private let moveIndex: [String: Int]
    private let abilityIndex: [String: Int]
    private let itemIndex: [String: Int]
    private let learnsets: [String: Learnset]
    private let learnersByMove: [String: [String]]
    private let pokemonByAbility: [String: [String]]
    private let formsBySpecies: [String: [String]]
    private let pokemonByDexNumber: [Int: [String]]
    private let pokemonByName: [String: String]
    private let moveByName: [String: String]
    private let itemByName: [String: String]
    private let abilityByName: [String: String]

    public init(pokemon: [Pokemon], moves: [Move], abilities: [Ability], items: [Item],
                learnsets: [String: Learnset], manifest: DataManifest? = nil) {
        self.pokemon = pokemon
        self.moves = moves
        self.abilities = abilities
        self.items = items
        self.natures = Nature.all
        self.learnsets = learnsets
        self.manifest = manifest

        pokemonIndex = Dictionary(uniqueKeysWithValues: pokemon.enumerated().map { ($1.id, $0) })
        moveIndex = Dictionary(uniqueKeysWithValues: moves.enumerated().map { ($1.id, $0) })
        abilityIndex = Dictionary(uniqueKeysWithValues: abilities.enumerated().map { ($1.id, $0) })
        itemIndex = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })

        pokemonByName = Dictionary(pokemon.map { (ShowdownID.make($0.name), $0.id) }, uniquingKeysWith: { first, _ in first })
        moveByName = Dictionary(moves.map { (ShowdownID.make($0.name), $0.id) }, uniquingKeysWith: { first, _ in first })
        itemByName = Dictionary(items.map { (ShowdownID.make($0.name), $0.id) }, uniquingKeysWith: { first, _ in first })
        abilityByName = Dictionary(abilities.map { (ShowdownID.make($0.name), $0.id) }, uniquingKeysWith: { first, _ in first })

        // A Pokémon can use every move its pre-evolutions learn, so the reverse index walks each line.
        let byID = pokemonIndex
        func stages(of entry: Pokemon) -> [Pokemon] {
            var result = [entry]
            var current = entry.baseSpeciesID.flatMap { byID[$0] }.map { pokemon[$0] } ?? entry
            if current.id != entry.id { result.append(current) }
            var seen = Set(result.map(\.id))
            while let previousID = current.evolvesFrom, let index = byID[previousID], seen.insert(previousID).inserted {
                current = pokemon[index]
                result.append(current)
            }
            return result
        }
        var learners: [String: [String]] = [:]
        for entry in pokemon {
            var moveIDs: Set<String> = []
            for stage in stages(of: entry) {
                if let learnset = learnsets[stage.id] ?? learnsets[stage.speciesID] {
                    moveIDs.formUnion(learnset.moves.keys)
                }
            }
            for moveID in moveIDs {
                learners[moveID, default: []].append(entry.id)
            }
        }
        let order = pokemonIndex
        for key in learners.keys {
            learners[key]?.sort { (order[$0] ?? .max) < (order[$1] ?? .max) }
        }
        learnersByMove = learners

        var byAbility: [String: [String]] = [:]
        var bySpecies: [String: [String]] = [:]
        var byDex: [Int: [String]] = [:]
        for entry in pokemon {
            for abilityID in entry.abilities.all {
                byAbility[abilityID, default: []].append(entry.id)
            }
            bySpecies[entry.speciesID, default: []].append(entry.id)
            byDex[entry.nationalDexNumber, default: []].append(entry.id)
        }
        pokemonByAbility = byAbility
        formsBySpecies = bySpecies
        pokemonByDexNumber = byDex
    }

    // MARK: - Loading

    /// Loads the bundled dataset off the calling actor. Looks in `subdirectory` first, then at the bundle root.
    /// `filePrefix` selects an alternative set of files, such as the `preview-` fixture used by Xcode Previews.
    @concurrent
    public static func load(from bundle: Bundle, subdirectory: String? = "Data", filePrefix: String = "") async throws -> PokedexDatabase {
        try loadSynchronously(from: bundle, subdirectory: subdirectory, filePrefix: filePrefix)
    }

    /// Loads the bundled dataset on the current thread. Intended for Xcode Previews and tests;
    /// the app uses ``load(from:subdirectory:filePrefix:)`` so launch never blocks the main actor.
    public static func loadSynchronously(from bundle: Bundle, subdirectory: String? = "Data", filePrefix: String = "") throws -> PokedexDatabase {
        func url(_ name: String) throws -> URL {
            let resource = filePrefix + name
            if let subdirectory, let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: subdirectory) {
                return url
            }
            if let url = bundle.url(forResource: resource, withExtension: "json") { return url }
            throw LoadError.missingFile(resource)
        }
        return try load(pokemonURL: url("pokemon"), movesURL: url("moves"), abilitiesURL: url("abilities"),
                        itemsURL: url("items"), learnsetsURL: url("learnsets"),
                        manifestURL: try? url("manifest"))
    }

    /// Loads the dataset from a directory containing the generated JSON files.
    @concurrent
    public static func load(from directory: URL, filePrefix: String = "") async throws -> PokedexDatabase {
        func url(_ name: String) -> URL { directory.appendingPathComponent("\(filePrefix)\(name).json") }
        return try load(pokemonURL: url("pokemon"), movesURL: url("moves"), abilitiesURL: url("abilities"),
                        itemsURL: url("items"), learnsetsURL: url("learnsets"), manifestURL: url("manifest"))
    }

    public enum LoadError: Error, LocalizedError {
        case missingFile(String)
        case incompatibleSchema(found: Int, expected: Int)

        public var errorDescription: String? {
            switch self {
            case .missingFile(let name): "The data file “\(name).json” is missing from the app bundle."
            case .incompatibleSchema(let found, let expected): "Data schema \(found) does not match the expected schema \(expected)."
            }
        }
    }

    private static func load(pokemonURL: URL, movesURL: URL, abilitiesURL: URL, itemsURL: URL,
                             learnsetsURL: URL, manifestURL: URL?) throws -> PokedexDatabase {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try manifestURL.flatMap { url -> DataManifest? in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try decoder.decode(DataManifest.self, from: Data(contentsOf: url))
        }
        if let manifest, manifest.schemaVersion != DataManifest.currentSchemaVersion {
            throw LoadError.incompatibleSchema(found: manifest.schemaVersion, expected: DataManifest.currentSchemaVersion)
        }
        let pokemon = try decoder.decode([Pokemon].self, from: Data(contentsOf: pokemonURL))
        let moves = try decoder.decode([Move].self, from: Data(contentsOf: movesURL))
        let abilities = try decoder.decode([Ability].self, from: Data(contentsOf: abilitiesURL))
        let items = try decoder.decode([Item].self, from: Data(contentsOf: itemsURL))
        let learnsets = try decoder.decode([String: Learnset].self, from: Data(contentsOf: learnsetsURL))
        return PokedexDatabase(pokemon: pokemon, moves: moves, abilities: abilities, items: items,
                               learnsets: learnsets, manifest: manifest)
    }

    // MARK: - Lookups by ID

    public func pokemon(id: String) -> Pokemon? { pokemonIndex[id].map { pokemon[$0] } }
    public func move(id: String) -> Move? { moveIndex[id].map { moves[$0] } }
    public func ability(id: String) -> Ability? { abilityIndex[id].map { abilities[$0] } }
    public func item(id: String) -> Item? { itemIndex[id].map { items[$0] } }
    public func nature(id: String) -> Nature? { Nature.named(id) }

    // MARK: - Lookups by name (tolerant of case, punctuation and accents)

    public func pokemon(named name: String) -> Pokemon? {
        let key = ShowdownID.make(name)
        if let id = pokemonByName[key] ?? (pokemonIndex[key] != nil ? key : nil) { return pokemon(id: id) }
        return nil
    }

    public func move(named name: String) -> Move? {
        let key = ShowdownID.make(name)
        return (moveByName[key] ?? (moveIndex[key] != nil ? key : nil)).flatMap(move(id:))
    }

    public func ability(named name: String) -> Ability? {
        let key = ShowdownID.make(name)
        return (abilityByName[key] ?? (abilityIndex[key] != nil ? key : nil)).flatMap(ability(id:))
    }

    public func item(named name: String) -> Item? {
        let key = ShowdownID.make(name)
        return (itemByName[key] ?? (itemIndex[key] != nil ? key : nil)).flatMap(item(id:))
    }

    // MARK: - Relationships

    /// All forms of a species, base form first.
    public func forms(of pokemon: Pokemon) -> [Pokemon] {
        (formsBySpecies[pokemon.speciesID] ?? [pokemon.id]).compactMap(self.pokemon(id:))
    }

    /// Every Pokémon sharing a National Pokédex number.
    public func pokemon(dexNumber: Int) -> [Pokemon] {
        (pokemonByDexNumber[dexNumber] ?? []).compactMap(pokemon(id:))
    }

    /// Only base forms (one entry per species), in dex order.
    public var species: [Pokemon] { pokemon.filter(\.isBaseForm) }

    /// The base form of the species a Pokémon belongs to.
    public func baseForm(of pokemon: Pokemon) -> Pokemon {
        self.pokemon(id: pokemon.speciesID) ?? pokemon
    }

    /// The Pokémon a given one evolves from, if any.
    public func preEvolution(of pokemon: Pokemon) -> Pokemon? {
        pokemon.evolvesFrom.flatMap(self.pokemon(id:))
    }

    /// The first stage of a Pokémon's evolutionary line.
    public func rootOfEvolutionLine(for pokemon: Pokemon) -> Pokemon {
        var current = baseForm(of: pokemon)
        var visited: Set<String> = [current.id]
        while let previous = preEvolution(of: current), visited.insert(previous.id).inserted {
            current = previous
        }
        return current
    }

    /// Every Pokémon in the same evolutionary family, starting from the root, breadth-first.
    public func evolutionFamily(of pokemon: Pokemon) -> [Pokemon] {
        let root = rootOfEvolutionLine(for: pokemon)
        var result: [Pokemon] = []
        var queue = [root]
        var visited: Set<String> = []
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard visited.insert(current.id).inserted else { continue }
            result.append(current)
            queue.append(contentsOf: current.evolutions.compactMap { self.pokemon(id: $0.to) })
        }
        return result
    }

    /// Pokémon that can have the given ability (as a regular or hidden ability).
    public func pokemon(withAbility abilityID: String) -> [Pokemon] {
        (pokemonByAbility[abilityID] ?? []).compactMap(pokemon(id:))
    }

    /// The Pokémon, its base species (for alternate forms) and every pre-evolution, nearest first.
    public func lineage(of pokemon: Pokemon) -> [Pokemon] {
        var result = [pokemon]
        var current = baseForm(of: pokemon)
        if current.id != pokemon.id { result.append(current) }
        var seen = Set(result.map(\.id))
        while let previous = preEvolution(of: current), seen.insert(previous.id).inserted {
            result.append(previous)
            current = previous
        }
        return result
    }

    /// Every way a Pokémon can learn a move, including as a pre-evolution; `nil` if it can't.
    /// Forms without their own learnset use the base species'.
    public func learnSources(for pokemon: Pokemon, moveID: String) -> [LearnSource]? {
        var sources: [LearnSource] = []
        for stage in lineage(of: pokemon) {
            guard let learnset = learnsets[stage.id] ?? learnsets[stage.speciesID] else { continue }
            for source in learnset.moves[moveID] ?? [] where !sources.contains(source) {
                sources.append(source)
            }
        }
        return sources.isEmpty ? nil : sources
    }

    /// Resolved learnset for a Pokémon. An evolved Pokémon keeps everything its pre-evolutions can
    /// learn (egg moves, earlier level-up moves), so those are merged in, as Showdown's validator does.
    public func learnset(for pokemon: Pokemon) -> [LearnedMove] {
        var merged: [String: [LearnSource]] = [:]
        for stage in lineage(of: pokemon) {
            guard let learnset = learnsets[stage.id] ?? learnsets[stage.speciesID] else { continue }
            for (moveID, sources) in learnset.moves {
                var existing = merged[moveID] ?? []
                for source in sources where !existing.contains(source) {
                    existing.append(source)
                }
                merged[moveID] = existing
            }
        }
        return merged.compactMap { moveID, sources in
            move(id: moveID).map { LearnedMove(move: $0, sources: sources) }
        }
        .sorted { $0.move.name < $1.move.name }
    }

    /// Whether a Pokémon can learn a move (by any method, in any generation, at any stage of its line).
    public func canLearn(_ pokemon: Pokemon, moveID: String) -> Bool {
        learnSources(for: pokemon, moveID: moveID) != nil
    }

    /// Pokémon that can learn a move, with how they learn it, in dex order.
    public func learners(of move: Move) -> [(pokemon: Pokemon, sources: [LearnSource])] {
        (learnersByMove[move.id] ?? []).compactMap { pokemonID in
            guard let pokemon = pokemon(id: pokemonID), let sources = learnSources(for: pokemon, moveID: move.id) else { return nil }
            return (pokemon, sources.sorted())
        }
    }

    /// Moves of a type, or Pokémon of a type.
    public func pokemon(ofType type: PokemonType) -> [Pokemon] { pokemon.filter { $0.types.contains(type) } }
    public func moves(ofType type: PokemonType) -> [Move] { moves.filter { $0.type == type } }

    // MARK: - Search

    public struct SearchResults: Sendable {
        public var pokemon: [Pokemon] = []
        public var moves: [Move] = []
        public var abilities: [Ability] = []
        public var items: [Item] = []
        public var natures: [Nature] = []

        public var isEmpty: Bool { pokemon.isEmpty && moves.isEmpty && abilities.isEmpty && items.isEmpty && natures.isEmpty }
        public var count: Int { pokemon.count + moves.count + abilities.count + items.count + natures.count }
    }

    /// Searches every category by name. Results are ranked exact → prefix → word prefix → contains.
    public func search(_ query: String, limitPerCategory limit: Int = 25) -> SearchResults {
        let normalized = SearchNormalizer.normalize(query)
        guard !normalized.isEmpty else { return SearchResults() }

        func rank<T>(_ candidates: [T], name: (T) -> String, secondary: ((T) -> String)? = nil) -> [T] {
            candidates.compactMap { candidate -> (T, SearchNormalizer.MatchQuality)? in
                var quality = SearchNormalizer.match(SearchNormalizer.normalize(name(candidate)), query: normalized)
                if let secondary {
                    quality = max(quality, SearchNormalizer.match(SearchNormalizer.normalize(secondary(candidate)), query: normalized))
                }
                return quality == .none ? nil : (candidate, quality)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
        }

        var results = SearchResults()
        results.pokemon = rank(pokemon, name: \.displayName, secondary: \.name)
        if let number = Int(normalized), number > 0 {
            let byNumber = self.pokemon(dexNumber: number)
            results.pokemon = byNumber + results.pokemon.filter { candidate in !byNumber.contains(where: { $0.id == candidate.id }) }
        }
        results.moves = rank(moves, name: \.name)
        results.abilities = rank(abilities, name: \.name)
        results.items = rank(items, name: \.name)
        results.natures = rank(natures, name: \.name)
        return results
    }
}
