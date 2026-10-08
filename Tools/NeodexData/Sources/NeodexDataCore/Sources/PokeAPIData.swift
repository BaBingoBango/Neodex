import Foundation
import NeodexKit

/// The subset of PokeAPI's CSV database used to enrich Showdown's data.
struct PokeAPIData: Sendable {
    struct Species: Sendable {
        var id: Int
        var identifier: String
        var generation: Int
        var evolvesFrom: Int?
        var genderRate: Int
        var captureRate: Int?
        var baseHappiness: Int?
        var hatchCounter: Int?
        var growthRate: String?
        var isLegendary: Bool
        var isMythical: Bool
        var name: String
        var genus: String
    }

    struct PokemonRow: Sendable {
        var id: Int
        var identifier: String
        var speciesID: Int
        var height: Int
        var weight: Int
        var baseExperience: Int?
        var isDefault: Bool
        var effort: StatBlock
        /// English form display names, e.g. ("Mega X", "Mega Charizard X").
        var formName: String?
        var pokemonName: String?
    }

    struct FlavorText: Sendable {
        var versionID: Int
        var text: String
    }

    struct Version: Sendable {
        var id: Int
        var name: String
        var order: Int
        var versionGroupID: Int
    }

    struct MoveRow: Sendable {
        var id: Int
        var name: String
        var generation: Int
        var effectChance: Int?
        var flavorText: String?
        var tmNumber: Int?
    }

    struct AbilityRow: Sendable {
        var id: Int
        var name: String
        var generation: Int
        var flavorText: String?
    }

    struct ItemRow: Sendable {
        var id: Int
        var name: String
        var category: String
        var flavorText: String?
    }

    var species: [Int: Species]
    var pokemon: [Int: PokemonRow]
    var pokemonByIdentifier: [String: Int]
    var defaultPokemonForSpecies: [Int: Int]
    var flavorTexts: [Int: [FlavorText]]
    var versions: [Int: Version]
    /// Keyed by Showdown ID of the English name.
    var moves: [String: MoveRow]
    var abilities: [String: AbilityRow]
    var items: [String: ItemRow]
    /// species id → version id → location names
    var locations: [Int: [Int: Set<String>]]

    static let base = URL(string: "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/")!
    static let spriteBase = URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/")!
    static let english = 9

    static func load(using fetcher: Fetcher) async throws -> PokeAPIData {
        let names = ["pokemon_species", "pokemon_species_names", "pokemon_species_flavor_text", "pokemon", "pokemon_stats",
                     "pokemon_forms", "pokemon_form_names", "growth_rate_prose", "versions", "version_names", "version_groups",
                     "moves", "move_names", "move_flavor_text", "machines", "abilities", "ability_names", "ability_flavor_text",
                     "items", "item_names", "item_flavor_text", "item_categories", "encounters", "location_areas", "locations",
                     "location_names"]
        var tables: [String: CSVTable] = [:]
        try await withThrowingTaskGroup(of: (String, CSVTable).self) { group in
            for name in names {
                group.addTask {
                    guard let data = try await fetcher.data(for: base.appendingPathComponent("\(name).csv")) else {
                        throw Fetcher.FetchError.badStatus(404, base.appendingPathComponent("\(name).csv"))
                    }
                    return (name, CSVTable(data: data))
                }
            }
            for try await (name, table) in group { tables[name] = table }
        }
        func table(_ name: String) -> [CSVRow] { tables[name]?.dictionaries ?? [] }

        // Versions, ordered chronologically via version_groups.order.
        var groupOrder: [Int: Int] = [:]
        for row in table("version_groups") { if let id = row.int("id") { groupOrder[id] = row.int("order") ?? id } }
        var versionNames: [Int: String] = [:]
        for row in table("version_names") where row.int("local_language_id") == english {
            if let id = row.int("version_id") { versionNames[id] = row["name"] }
        }
        var versions: [Int: Version] = [:]
        for row in table("versions") {
            guard let id = row.int("id"), let group = row.int("version_group_id") else { continue }
            versions[id] = Version(id: id, name: versionNames[id] ?? row["identifier"].capitalized, order: groupOrder[group] ?? group, versionGroupID: group)
        }
        var orderByVersionGroup = groupOrder

        // Growth rates
        var growthRates: [Int: String] = [:]
        for row in table("growth_rate_prose") where row.int("local_language_id") == english {
            if let id = row.int("growth_rate_id") { growthRates[id] = growthRateName(row["name"]) }
        }

        // Species
        var speciesNames: [Int: (String, String)] = [:]
        for row in table("pokemon_species_names") where row.int("local_language_id") == english {
            if let id = row.int("pokemon_species_id") { speciesNames[id] = (row["name"], row["genus"]) }
        }
        var species: [Int: Species] = [:]
        for row in table("pokemon_species") {
            guard let id = row.int("id") else { continue }
            let names = speciesNames[id] ?? (row["identifier"].capitalized, "")
            species[id] = Species(
                id: id, identifier: row["identifier"], generation: row.int("generation_id") ?? 0,
                evolvesFrom: row.int("evolves_from_species_id"), genderRate: row.int("gender_rate") ?? -1,
                captureRate: row.int("capture_rate"), baseHappiness: row.int("base_happiness"), hatchCounter: row.int("hatch_counter"),
                growthRate: row.int("growth_rate_id").flatMap { growthRates[$0] }, isLegendary: row.bool("is_legendary"),
                isMythical: row.bool("is_mythical"), name: names.0, genus: names.1.replacingOccurrences(of: " Pokémon", with: "")
            )
        }

        // Flavor text (English only), newest first.
        var flavor: [Int: [FlavorText]] = [:]
        for row in table("pokemon_species_flavor_text") where row.int("language_id") == english {
            guard let speciesID = row.int("species_id"), let versionID = row.int("version_id") else { continue }
            flavor[speciesID, default: []].append(FlavorText(versionID: versionID, text: cleanFlavor(row["flavor_text"])))
        }
        for key in flavor.keys {
            flavor[key]?.sort { (versions[$0.versionID]?.order ?? 0, $0.versionID) > (versions[$1.versionID]?.order ?? 0, $1.versionID) }
        }

        // Pokémon rows + stats + form names
        var effort: [Int: StatBlock] = [:]
        for row in table("pokemon_stats") {
            guard let pokemonID = row.int("pokemon_id"), let statID = row.int("stat_id"), (1...6).contains(statID) else { continue }
            effort[pokemonID, default: .zero][Stat.allCases[statID - 1]] = row.int("effort") ?? 0
        }
        var formNamesByForm: [Int: (String, String)] = [:]
        for row in table("pokemon_form_names") where row.int("local_language_id") == english {
            if let id = row.int("pokemon_form_id") { formNamesByForm[id] = (row["form_name"], row["pokemon_name"]) }
        }
        var formNamesByPokemon: [Int: (String, String)] = [:]
        for row in table("pokemon_forms") {
            guard let formID = row.int("id"), let pokemonID = row.int("pokemon_id"), let names = formNamesByForm[formID] else { continue }
            if formNamesByPokemon[pokemonID] == nil || row.bool("is_default") { formNamesByPokemon[pokemonID] = names }
        }
        var pokemon: [Int: PokemonRow] = [:]
        var byIdentifier: [String: Int] = [:]
        var defaults: [Int: Int] = [:]
        for row in table("pokemon") {
            guard let id = row.int("id"), let speciesID = row.int("species_id") else { continue }
            let names = formNamesByPokemon[id]
            pokemon[id] = PokemonRow(
                id: id, identifier: row["identifier"], speciesID: speciesID, height: row.int("height") ?? 0,
                weight: row.int("weight") ?? 0, baseExperience: row.int("base_experience"), isDefault: row.bool("is_default"),
                effort: effort[id] ?? .zero, formName: names?.0.isEmpty == false ? names?.0 : nil,
                pokemonName: names?.1.isEmpty == false ? names?.1 : nil
            )
            byIdentifier[row["identifier"]] = id
            if row.bool("is_default") { defaults[speciesID] = id }
        }

        // Moves
        var moveNames: [Int: String] = [:]
        for row in table("move_names") where row.int("local_language_id") == english {
            if let id = row.int("move_id") { moveNames[id] = row["name"] }
        }
        var moveFlavor: [Int: (order: Int, text: String)] = [:]
        for row in table("move_flavor_text") where row.int("language_id") == english {
            guard let id = row.int("move_id"), let group = row.int("version_group_id") else { continue }
            let order = orderByVersionGroup[group] ?? group
            if (moveFlavor[id]?.order ?? -1) < order { moveFlavor[id] = (order, cleanFlavor(row["flavor_text"])) }
        }
        // TM numbers follow Scarlet/Violet (and its DLC), the games whose numbering players know.
        let machineGroups = Set(table("version_groups").filter { ["scarlet-violet", "the-teal-mask", "the-indigo-disk"].contains($0["identifier"]) }.compactMap { $0.int("id") })
        var tmNumbers: [Int: (order: Int, number: Int)] = [:]
        for row in table("machines") {
            guard let moveID = row.int("move_id"), let group = row.int("version_group_id"), machineGroups.contains(group),
                  let number = row.int("machine_number") else { continue }
            let order = orderByVersionGroup[group] ?? group
            if (tmNumbers[moveID]?.order ?? -1) < order { tmNumbers[moveID] = (order, number) }
        }
        var moves: [String: MoveRow] = [:]
        for row in table("moves") {
            guard let id = row.int("id"), let name = moveNames[id] else { continue }
            moves[ShowdownID.make(name)] = MoveRow(id: id, name: name, generation: row.int("generation_id") ?? 0,
                                                   effectChance: row.int("effect_chance"), flavorText: moveFlavor[id]?.text,
                                                   tmNumber: tmNumbers[id]?.number)
        }

        // Abilities
        var abilityNames: [Int: String] = [:]
        for row in table("ability_names") where row.int("local_language_id") == english {
            if let id = row.int("ability_id") { abilityNames[id] = row["name"] }
        }
        var abilityFlavor: [Int: (order: Int, text: String)] = [:]
        for row in table("ability_flavor_text") where row.int("language_id") == english {
            guard let id = row.int("ability_id"), let group = row.int("version_group_id") else { continue }
            let order = orderByVersionGroup[group] ?? group
            if (abilityFlavor[id]?.order ?? -1) < order { abilityFlavor[id] = (order, cleanFlavor(row["flavor_text"])) }
        }
        var abilities: [String: AbilityRow] = [:]
        for row in table("abilities") where row.bool("is_main_series") {
            guard let id = row.int("id"), let name = abilityNames[id] else { continue }
            abilities[ShowdownID.make(name)] = AbilityRow(id: id, name: name, generation: row.int("generation_id") ?? 0,
                                                          flavorText: abilityFlavor[id]?.text)
        }

        // Items
        var itemNames: [Int: String] = [:]
        for row in table("item_names") where row.int("local_language_id") == english {
            if let id = row.int("item_id") { itemNames[id] = row["name"] }
        }
        var itemFlavor: [Int: (order: Int, text: String)] = [:]
        for row in table("item_flavor_text") where row.int("language_id") == english {
            guard let id = row.int("item_id"), let group = row.int("version_group_id") else { continue }
            let order = orderByVersionGroup[group] ?? group
            if (itemFlavor[id]?.order ?? -1) < order { itemFlavor[id] = (order, cleanFlavor(row["flavor_text"])) }
        }
        var categories: [Int: String] = [:]
        for row in table("item_categories") { if let id = row.int("id") { categories[id] = row["identifier"] } }
        var items: [String: ItemRow] = [:]
        for row in table("items") {
            guard let id = row.int("id"), let name = itemNames[id] else { continue }
            items[ShowdownID.make(name)] = ItemRow(id: id, name: name, category: row.int("category_id").flatMap { categories[$0] } ?? "",
                                                   flavorText: itemFlavor[id]?.text)
        }

        // Encounter locations: species → version → location names
        var locationNames: [Int: String] = [:]
        for row in table("location_names") where row.int("local_language_id") == english {
            if let id = row.int("location_id") { locationNames[id] = row["name"] }
        }
        var areaToLocation: [Int: Int] = [:]
        for row in table("location_areas") {
            if let id = row.int("id"), let location = row.int("location_id") { areaToLocation[id] = location }
        }
        var locations: [Int: [Int: Set<String>]] = [:]
        for row in table("encounters") {
            guard let pokemonID = row.int("pokemon_id"), let versionID = row.int("version_id"), let area = row.int("location_area_id"),
                  let location = areaToLocation[area], let name = locationNames[location], let speciesID = pokemon[pokemonID]?.speciesID else { continue }
            locations[speciesID, default: [:]][versionID, default: []].insert(name)
        }

        orderByVersionGroup.removeAll()
        return PokeAPIData(species: species, pokemon: pokemon, pokemonByIdentifier: byIdentifier, defaultPokemonForSpecies: defaults,
                           flavorTexts: flavor, versions: versions, moves: moves, abilities: abilities, items: items, locations: locations)
    }

    /// PokeAPI names growth rates by their curve ("medium slow"); use the familiar in-game names.
    static func growthRateName(_ raw: String) -> String {
        switch raw.lowercased().replacingOccurrences(of: "-", with: " ") {
        case "slow": "Slow"
        case "medium": "Medium Fast"
        case "fast": "Fast"
        case "medium slow": "Medium Slow"
        case "slow then very fast": "Erratic"
        case "fast then very slow": "Fluctuating"
        default: raw.capitalized
        }
    }

    /// Game text uses form feeds and hard line breaks; collapse them into normal spaces.
    static func cleanFlavor(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{0C}", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{00AD}", with: "")
            .replacingOccurrences(of: "POKéMON", with: "Pokémon")
            .split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }
}
