import Foundation
import NeodexKit

/// Everything the pipeline produces, before images are resolved and files are written.
struct Dataset: Sendable {
    var pokemon: [Pokemon]
    var moves: [Move]
    var abilities: [Ability]
    var items: [Item]
    var learnsets: [String: Learnset]
    /// Showdown ID → PokeAPI `pokemon.id`, only for forms that matched their own PokeAPI row.
    var pokeapiPokemonIDs: [String: Int]
    /// Showdown ID → Showdown sprite file stem (`charizard-megax`).
    var spriteIDs: [String: String]
    var notes: [String]
}

/// Merges Showdown's competitive data with PokeAPI's in-game data into Neodex's models.
struct DatasetBuilder {
    let showdown: ShowdownData
    let pokeapi: PokeAPIData
    /// When set, only species up to this National Dex number are included (for quick test runs).
    var limit: Int?

    func build() throws -> Dataset {
        var notes: [String] = []
        let abilities = buildAbilities()
        let abilityIDs = Set(abilities.map(\.id))
        let moves = buildMoves()
        let moveIDs = Set(moves.map(\.id))
        let items = buildItems()
        let itemIDs = Set(items.map(\.id))
        let (pokemon, apiIDs, spriteIDs, unmatched) = buildPokemon(abilityIDs: abilityIDs, itemIDs: itemIDs)
        notes.append("Forms using base-species PokeAPI data (\(unmatched.count)): " + unmatched.joined(separator: ", "))
        let learnsets = buildLearnsets(pokemonIDs: Set(pokemon.map(\.id)), moveIDs: moveIDs)
        return Dataset(pokemon: pokemon, moves: moves, abilities: abilities, items: items, learnsets: learnsets,
                       pokeapiPokemonIDs: apiIDs, spriteIDs: spriteIDs, notes: notes)
    }

    // MARK: - Shared helpers

    private static let skippedNonstandard: Set<String> = ["CAP", "Custom", "Future"]

    private func availability(for nonstandard: String?) -> Availability {
        switch nonstandard {
        case nil: .current
        case "Past": .past
        case "LGPE": .letsGo
        default: .unobtainable
        }
    }

    private func shouldSkip(nonstandard: String?) -> Bool {
        nonstandard.map { Self.skippedNonstandard.contains($0) } ?? false
    }

    // MARK: - Pokémon

    /// Showdown form names whose PokeAPI identifier is spelled differently.
    static let formAliases: [String: String] = [
        "darmanitan-galar": "darmanitan-galar-standard",
        "meowstic": "meowstic-male", "meowstic-f": "meowstic-female",
        "indeedee": "indeedee-male", "indeedee-f": "indeedee-female",
        "basculegion": "basculegion-male", "basculegion-f": "basculegion-female",
        "oinkologne": "oinkologne-male", "oinkologne-f": "oinkologne-female",
        "necrozma-dusk-mane": "necrozma-dusk", "necrozma-dawn-wings": "necrozma-dawn",
        "minior": "minior-red-meteor", "minior-meteor": "minior-red-meteor",
        "tauros-paldea-combat": "tauros-paldea-combat-breed", "tauros-paldea-blaze": "tauros-paldea-blaze-breed",
        "tauros-paldea-aqua": "tauros-paldea-aqua-breed",
        "maushold": "maushold-family-of-three", "maushold-four": "maushold-family-of-four",
        "squawkabilly": "squawkabilly-green-plumage", "squawkabilly-blue": "squawkabilly-blue-plumage",
        "squawkabilly-yellow": "squawkabilly-yellow-plumage", "squawkabilly-white": "squawkabilly-white-plumage",
        "ogerpon-wellspring": "ogerpon-wellspring-mask", "ogerpon-hearthflame": "ogerpon-hearthflame-mask",
        "ogerpon-cornerstone": "ogerpon-cornerstone-mask",
        "ogerpon-teal-tera": "ogerpon", "ogerpon-wellspring-tera": "ogerpon-wellspring-mask",
        "ogerpon-hearthflame-tera": "ogerpon-hearthflame-mask", "ogerpon-cornerstone-tera": "ogerpon-cornerstone-mask",
        "pikachu-original": "pikachu-original-cap", "pikachu-hoenn": "pikachu-hoenn-cap", "pikachu-sinnoh": "pikachu-sinnoh-cap",
        "pikachu-unova": "pikachu-unova-cap", "pikachu-kalos": "pikachu-kalos-cap", "pikachu-alola": "pikachu-alola-cap",
        "pikachu-partner": "pikachu-partner-cap", "pikachu-world": "pikachu-world-cap",
        "greninja-bond": "greninja-battle-bond",
        "rockruff-dusk": "rockruff-own-tempo",
        "cherrim-sunshine": "cherrim-sunshine",
        "vivillon-pokeball": "vivillon-poke-ball",
        "toxtricity-gmax": "toxtricity-amped-gmax", "urshifu-gmax": "urshifu-single-strike-gmax",
        "raticate-alola-totem": "raticate-totem-alola", "marowak-alola-totem": "marowak-totem",
        "mimikyu-totem": "mimikyu-totem-disguised", "mimikyu-busted-totem": "mimikyu-totem-busted",
        "gumshoos-totem": "gumshoos-totem", "vikavolt-totem": "vikavolt-totem", "lurantis-totem": "lurantis-totem",
        "salazzle-totem": "salazzle-totem", "kommo-o-totem": "kommo-o-totem", "togedemaru-totem": "togedemaru-totem",
        "ribombee-totem": "ribombee-totem", "araquanid-totem": "araquanid-totem",
        "zygarde-10": "zygarde-10",
        "basculin-white-striped": "basculin-white-striped",
        "greninja-ash": "greninja-ash",
        "floette-eternal": "floette-eternal",
        "eevee-starter": "eevee-starter", "pikachu-starter": "pikachu-starter",
        "dialga-origin": "dialga-origin", "palkia-origin": "palkia-origin",
        "ursaluna-bloodmoon": "ursaluna-bloodmoon",
        "terapagos-terastal": "terapagos-terastal", "terapagos-stellar": "terapagos-stellar",
    ]

    /// Showdown name → PokeAPI identifier spelling (before aliasing).
    static func pokeapiIdentifier(for showdownName: String) -> String {
        showdownName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
            .replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "%", with: "").replacingOccurrences(of: " ", with: "-")
    }

    private struct RawSpecies {
        var id: String
        var entry: JSONValue
        var num: Int
        var name: String
        var baseID: String?
        var forme: String?
    }

    private func buildPokemon(abilityIDs: Set<String>, itemIDs: Set<String>) -> ([Pokemon], [String: Int], [String: String], [String]) {
        var raws: [RawSpecies] = []
        for (id, entry) in showdown.pokedex {
            guard let num = entry["num"]?.int, num >= 1, let name = entry["name"]?.string else { continue }
            if let limit, num > limit { continue }
            if shouldSkip(nonstandard: entry["isNonstandard"]?.string) { continue }
            if entry["isCosmeticForme"]?.isTrue == true { continue }
            guard let types = entry["types"]?.stringArray, !types.isEmpty, entry["baseStats"]?.object != nil else { continue }
            let forme = entry["forme"]?.string.flatMap { $0.isEmpty ? nil : $0 }
            let baseID = entry["baseSpecies"]?.string.map(ShowdownData.toID)
            raws.append(RawSpecies(id: id, entry: entry, num: num, name: name, baseID: baseID, forme: forme))
        }
        let included = Set(raws.map(\.id))

        func formeOrderIndex(_ raw: RawSpecies) -> Int {
            guard let baseID = raw.baseID else { return 0 }
            if let order = showdown.pokedex[baseID]?["formeOrder"]?.stringArray,
               let index = order.firstIndex(where: { ShowdownData.toID($0) == raw.id }) { return index }
            return 999
        }
        raws.sort { ($0.num, formeOrderIndex($0), $0.id) < ($1.num, formeOrderIndex($1), $1.id) }

        var siblings: [String: [String]] = [:]
        for raw in raws { siblings[raw.baseID ?? raw.id, default: []].append(raw.id) }

        // Count PokeAPI display names per species so ambiguous ones get their form name appended.
        var apiNameCounts: [Int: [String: Int]] = [:]
        for row in pokeapi.pokemon.values {
            if let name = row.pokemonName { apiNameCounts[row.speciesID, default: [:]][name, default: 0] += 1 }
        }

        var results: [Pokemon] = []
        var apiIDs: [String: Int] = [:]
        var spriteIDs: [String: String] = [:]
        var unmatched: [String] = []

        for raw in raws {
            let e = raw.entry
            let species = pokeapi.species[raw.num]
            let (apiRow, matchedOwnRow) = matchPokeAPIRow(name: raw.name, num: raw.num)
            if matchedOwnRow, let apiRow { apiIDs[raw.id] = apiRow.id }
            if !matchedOwnRow, raw.forme != nil { unmatched.append(raw.name) }
            spriteIDs[raw.id] = ShowdownData.spriteID(for: e)

            let types = (e["types"]?.stringArray ?? []).compactMap(PokemonType.init(name:))
            guard !types.isEmpty else { continue }

            let abilityNames = e["abilities"]?.object ?? [:]
            func abilityID(_ slot: String) -> String? {
                guard let name = abilityNames[slot]?.string else { return nil }
                let id = ShowdownData.toID(name)
                return abilityIDs.contains(id) ? id : nil
            }
            guard let primary = abilityID("0") ?? abilityID("1") ?? abilityID("H") else { continue }
            let abilities = AbilitySet(primary: primary, secondary: abilityID("1"), hidden: abilityID("H"))

            let stats = e["baseStats"]
            let baseStats = StatBlock(hp: stats?["hp"]?.int ?? 0, attack: stats?["atk"]?.int ?? 0, defense: stats?["def"]?.int ?? 0,
                                      specialAttack: stats?["spa"]?.int ?? 0, specialDefense: stats?["spd"]?.int ?? 0,
                                      speed: stats?["spe"]?.int ?? 0)

            var maleRatio: Double? = 0.5
            if let gender = e["gender"]?.string {
                switch gender {
                case "N": maleRatio = nil
                case "M": maleRatio = 1
                case "F": maleRatio = 0
                default: break
                }
            } else if let male = e["genderRatio"]?["M"]?.double {
                maleRatio = male
            }

            let formKind = raw.forme.map(Self.formKind)
            let generation = e["gen"]?.int ?? Self.generation(forForme: raw.forme, formKind: formKind, speciesNum: raw.num, species: species)

            var evolutions: [Evolution] = []
            for childName in e["evos"]?.stringArray ?? [] {
                let childID = ShowdownData.toID(childName)
                guard included.contains(childID), let child = showdown.pokedex[childID] else { continue }
                evolutions.append(Evolution(to: childID, kind: child["evoType"]?.string, level: child["evoLevel"]?.int,
                                            item: child["evoItem"]?.string, move: child["evoMove"]?.string,
                                            condition: child["evoCondition"]?.string, region: child["evoRegion"]?.string))
            }
            let prevoID = e["prevo"]?.string.map(ShowdownData.toID)
            let evolvesFrom = prevoID.flatMap { included.contains($0) ? $0 : nil }

            let requiredItems = (e["requiredItems"]?.stringArray ?? e["requiredItem"]?.stringOrStrings ?? [])
                .map(ShowdownData.toID).filter { itemIDs.contains($0) }
            let changesFrom = e["changesFrom"]?.string.map(ShowdownData.toID).flatMap { included.contains($0) ? $0 : nil }

            var tags = e["tags"]?.stringArray ?? []
            if let species {
                if species.isLegendary, !tags.contains(where: { $0.contains("Legendary") }) { tags.append("Legendary") }
                if species.isMythical, !tags.contains("Mythical") { tags.append("Mythical") }
            }

            let dexEntries = buildDexEntries(for: raw.num)
            let locations = buildLocations(for: raw.num)
            let effort = apiRow?.effort ?? pokeapi.defaultPokemonForSpecies[raw.num].flatMap { pokeapi.pokemon[$0] }?.effort

            let displayName = Self.displayName(raw: raw, species: species, apiRow: matchedOwnRow ? apiRow : nil,
                                               nameCounts: apiNameCounts[raw.num] ?? [:])

            results.append(Pokemon(
                id: raw.id, name: raw.name, displayName: displayName, nationalDexNumber: raw.num, generation: generation,
                baseSpeciesID: raw.baseID, formName: raw.forme, formKind: formKind,
                isBattleOnly: e["battleOnly"] != nil && !(e["battleOnly"]?.isNull ?? true), changesFrom: changesFrom,
                requiredItems: requiredItems.isEmpty ? nil : requiredItems, gigantamaxMove: e["canGigantamax"]?.string,
                types: types, abilities: abilities, baseStats: baseStats,
                height: e["heightm"]?.double ?? Double(apiRow?.height ?? 0) / 10,
                weight: e["weightkg"]?.double ?? Double(apiRow?.weight ?? 0) / 10,
                maleRatio: maleRatio, genus: species?.genus.isEmpty == false ? species?.genus : nil, color: e["color"]?.string,
                eggGroups: e["eggGroups"]?.stringArray ?? [], catchRate: species?.captureRate, baseFriendship: species?.baseHappiness,
                baseExperience: apiRow?.baseExperience, growthRate: species?.growthRate, hatchCycles: species?.hatchCounter,
                evYield: (effort?.total ?? 0) > 0 ? effort : nil, dexEntries: dexEntries, evolvesFrom: evolvesFrom,
                evolutions: evolutions, otherFormIDs: (siblings[raw.baseID ?? raw.id] ?? []).filter { $0 != raw.id },
                cosmeticForms: e["cosmeticFormes"]?.stringArray ?? [], tier: e["tier"]?.string,
                availability: availability(for: e["isNonstandard"]?.string), tags: tags, locations: locations, imageID: raw.id
            ))
        }
        return (results, apiIDs, spriteIDs, unmatched)
    }

    /// Finds the PokeAPI row for a Showdown species; falls back to the species' default form.
    private func matchPokeAPIRow(name: String, num: Int) -> (PokeAPIData.PokemonRow?, matchedOwnRow: Bool) {
        let identifier = Self.pokeapiIdentifier(for: name)
        let candidates = [Self.formAliases[identifier], identifier].compactMap { $0 }
        for candidate in candidates {
            if let id = pokeapi.pokemonByIdentifier[candidate], let row = pokeapi.pokemon[id], row.speciesID == num {
                return (row, true)
            }
        }
        if let defaultID = pokeapi.defaultPokemonForSpecies[num], let row = pokeapi.pokemon[defaultID] {
            // A base form resolving to its species' default row is a proper match.
            let isBaseForm = showdown.pokedex[ShowdownData.toID(name)]?["baseSpecies"] == nil
            return (row, isBaseForm)
        }
        return (nil, false)
    }

    static func formKind(forForme forme: String) -> FormKind {
        let lower = forme.lowercased()
        if lower.hasPrefix("mega") { return .mega }
        if lower == "gmax" || lower.hasSuffix("-gmax") { return .gigantamax }
        if lower.hasPrefix("primal") { return .primal }
        if lower.hasPrefix("alola") { return .alolan }
        if lower.hasPrefix("galar") { return .galarian }
        if lower.hasPrefix("hisui") { return .hisuian }
        if lower.hasPrefix("paldea") { return .paldean }
        if lower.contains("totem") { return .totem }
        if lower.hasSuffix("tera") || lower == "terastal" || lower == "stellar" { return .terastal }
        return .other
    }

    static func generation(forForme forme: String?, formKind: FormKind?, speciesNum: Int, species: PokeAPIData.Species?) -> Int {
        let speciesGeneration = species?.generation ?? generation(forDexNumber: speciesNum)
        switch formKind {
        case .mega, .primal: return max(6, speciesGeneration)
        case .alolan, .totem: return 7
        case .galarian, .gigantamax, .hisuian: return 8
        case .paldean, .terastal: return 9
        default: return speciesGeneration
        }
    }

    static func generation(forDexNumber num: Int) -> Int {
        switch num {
        case ...151: 1
        case ...251: 2
        case ...386: 3
        case ...493: 4
        case ...649: 5
        case ...721: 6
        case ...809: 7
        case ...905: 8
        default: 9
        }
    }

    private static func displayName(raw: RawSpecies, species: PokeAPIData.Species?, apiRow: PokeAPIData.PokemonRow?,
                                    nameCounts: [String: Int]) -> String {
        let speciesName = species?.name ?? raw.name.components(separatedBy: "-").first ?? raw.name
        guard let forme = raw.forme else { return speciesName }
        if let apiName = apiRow?.pokemonName, !apiName.isEmpty {
            if (nameCounts[apiName] ?? 0) > 1, let formName = apiRow?.formName, !formName.isEmpty {
                return "\(apiName) (\(formName))"
            }
            return apiName
        }
        let parts = forme.components(separatedBy: "-")
        switch parts[0] {
        case "Mega": return (["Mega", speciesName] + parts.dropFirst()).joined(separator: " ")
        case "Gmax": return "Gigantamax \(speciesName)"
        case "Primal": return "Primal \(speciesName)"
        case "Alola": return "Alolan \(speciesName)" + suffix(parts.dropFirst())
        case "Galar": return "Galarian \(speciesName)" + suffix(parts.dropFirst())
        case "Hisui": return "Hisuian \(speciesName)" + suffix(parts.dropFirst())
        case "Paldea": return "Paldean \(speciesName)" + suffix(parts.dropFirst())
        default: return "\(speciesName) (\(parts.joined(separator: " ")))"
        }
    }

    private static func suffix(_ parts: ArraySlice<String>) -> String {
        parts.isEmpty ? "" : " (\(parts.joined(separator: " ")))"
    }

    private func buildDexEntries(for speciesID: Int) -> [DexEntry] {
        guard let texts = pokeapi.flavorTexts[speciesID] else { return [] }
        var order: [String] = []
        var games: [String: [String]] = [:]
        var canonical: [String: String] = [:]
        for flavor in texts {
            let key = flavor.text.lowercased().filter { $0.isLetter || $0.isNumber }
            guard !key.isEmpty, let version = pokeapi.versions[flavor.versionID] else { continue }
            if games[key] == nil { order.append(key); canonical[key] = flavor.text }
            let game = "Pokémon \(version.name)"
            if !(games[key]?.contains(game) ?? false) { games[key, default: []].append(game) }
        }
        return order.compactMap { key in canonical[key].map { DexEntry(text: $0, games: games[key] ?? []) } }
    }

    private func buildLocations(for speciesID: Int) -> GameLocations? {
        guard let byVersion = pokeapi.locations[speciesID], !byVersion.isEmpty else { return nil }
        let best = byVersion.max { lhs, rhs in
            let l = pokeapi.versions[lhs.key], r = pokeapi.versions[rhs.key]
            return (l?.order ?? 0, lhs.value.count, lhs.key) < (r?.order ?? 0, rhs.value.count, rhs.key)
        }
        guard let best, let version = pokeapi.versions[best.key] else { return nil }
        return GameLocations(game: "Pokémon \(version.name)", areas: best.value.sorted())
    }

    // MARK: - Moves

    private func buildMoves() -> [Move] {
        var moves: [Move] = []
        for (id, m) in showdown.moves {
            guard let name = m["name"]?.string, let typeName = m["type"]?.string, let type = PokemonType(name: typeName) else { continue }
            if shouldSkip(nonstandard: m["isNonstandard"]?.string) { continue }
            if name.hasPrefix("Hidden Power ") { continue }
            guard let category = m["category"]?.string.flatMap(MoveCategory.init(rawValue:)) else { continue }
            let num = m["num"]?.int ?? 0
            let text = showdown.movesText[id]
            let api = pokeapi.moves[ShowdownID.make(name)]

            var kind = MoveKind.standard
            if let isZ = m["isZ"], !isZ.isNull, isZ.bool != false { kind = .zMove }
            if let isMax = m["isMax"], !isMax.isNull {
                kind = isMax.string != nil ? .gigantamaxMove : (isMax.isTrue ? .maxMove : kind)
            }

            var statChanges: [StatChange] = []
            let selfTargets: Set<String> = ["self", "adjacentAllyOrSelf", "allySide", "allyTeam", "allies"]
            let target = m["target"]?.string ?? "normal"
            func add(_ boosts: JSONValue?, affectsUser: Bool) {
                for (key, value) in boosts?.object ?? [:] {
                    guard let stat = Stat(rawValue: key), let stages = value.int, stages != 0 else { continue }
                    statChanges.append(StatChange(stat: stat, stages: stages, affectsUser: affectsUser))
                }
            }
            add(m["boosts"], affectsUser: selfTargets.contains(target))
            add(m["self"]?["boosts"], affectsUser: true)
            add(m["secondary"]?["self"]?["boosts"], affectsUser: true)
            add(m["secondary"]?["boosts"], affectsUser: false)
            statChanges.sort { Stat.allCases.firstIndex(of: $0.stat)! < Stat.allCases.firstIndex(of: $1.stat)! }

            var multiHit: [Int]?
            if let hits = m["multihit"]?.int { multiHit = [hits, hits] }
            else if let hits = m["multihit"]?.array?.compactMap(\.int), hits.count == 2 { multiHit = hits }

            let effectChance = m["secondary"]?["chance"]?.int ?? m["secondaries"]?.array?.first?["chance"]?.int ?? api?.effectChance

            moves.append(Move(
                id: id, name: name, type: type, category: category, basePower: m["basePower"]?.int ?? 0,
                accuracy: m["accuracy"]?.int, pp: m["pp"]?.int ?? 0, priority: m["priority"]?.int ?? 0, target: target,
                flags: (m["flags"]?.object?.keys).map { Array($0).sorted() } ?? [], description: api?.flavorText,
                shortDescription: text?["shortDesc"]?.string, longDescription: text?["desc"]?.string,
                effectChance: effectChance, tmNumber: api?.tmNumber, generation: api?.generation ?? Self.moveGeneration(num: num),
                availability: availability(for: m["isNonstandard"]?.string), kind: kind,
                critRatio: (m["critRatio"]?.int ?? 1) > 1 ? m["critRatio"]?.int : nil,
                drain: m["drain"]?.array?.compactMap(\.int), recoil: m["recoil"]?.array?.compactMap(\.int), multiHit: multiHit,
                isOneHitKO: m["ohko"].map { !$0.isNull && $0.bool != false } ?? false,
                statChanges: statChanges.isEmpty ? nil : statChanges
            ))
        }
        return moves.sorted { $0.name < $1.name }
    }

    static func moveGeneration(num: Int) -> Int {
        switch num {
        case ...165: 1
        case ...251: 2
        case ...354: 3
        case ...467: 4
        case ...559: 5
        case ...621: 6
        case ...742: 7
        case ...826: 8
        default: 9
        }
    }

    // MARK: - Abilities

    private func buildAbilities() -> [Ability] {
        var abilities: [Ability] = []
        for (id, a) in showdown.abilities {
            guard let name = a["name"]?.string, id != "noability" else { continue }
            if shouldSkip(nonstandard: a["isNonstandard"]?.string) { continue }
            let text = showdown.abilitiesText[id]
            let api = pokeapi.abilities[ShowdownID.make(name)]
            abilities.append(Ability(
                id: id, name: name, description: api?.flavorText, shortDescription: text?["shortDesc"]?.string,
                longDescription: text?["desc"]?.string, rating: a["rating"]?.double,
                generation: api?.generation ?? Self.abilityGeneration(num: a["num"]?.int ?? 0),
                availability: availability(for: a["isNonstandard"]?.string)
            ))
        }
        return abilities.sorted { $0.name < $1.name }
    }

    static func abilityGeneration(num: Int) -> Int {
        switch num {
        case ...76: 3
        case ...123: 4
        case ...164: 5
        case ...191: 6
        case ...233: 7
        case ...267: 8
        default: 9
        }
    }

    // MARK: - Items

    private func buildItems() -> [Item] {
        var items: [Item] = []
        for (id, i) in showdown.items {
            guard let name = i["name"]?.string else { continue }
            if shouldSkip(nonstandard: i["isNonstandard"]?.string) { continue }
            let text = showdown.itemsText[id]
            let api = pokeapi.items[ShowdownID.make(name)]

            var category = ItemCategory.held
            var associatedType: PokemonType?
            if i["isBerry"]?.isTrue == true { category = .berry }
            else if i["megaStone"] != nil { category = .megaStone }
            else if let z = i["zMove"], !z.isNull { category = .zCrystal; associatedType = i["zMoveType"]?.string.flatMap(PokemonType.init(name:)) }
            else if i["isChoice"]?.isTrue == true { category = .choice }
            else if let plate = i["onPlate"]?.string { category = .plate; associatedType = PokemonType(name: plate) }
            else if let memory = i["onMemory"]?.string { category = .memory; associatedType = PokemonType(name: memory) }
            else if let drive = i["onDrive"]?.string { category = .drive; associatedType = PokemonType(name: drive) }
            else if i["isGem"]?.isTrue == true { category = .gem }
            else if i["isPokeball"]?.isTrue == true { category = .pokeBall }
            else if name.hasSuffix("Tera Shard") { category = .teraShard }
            else if let apiCategory = api?.category, ["evolution", "mega-stones"].contains(apiCategory) { category = .evolution }
            else if let users = i["itemUser"]?.stringArray, !users.isEmpty { category = .signature }

            // The client data omits `megaEvolves`; derive it from the stone's user or the resulting forme name.
            var megaEvolves = i["megaEvolves"]?.string
            if megaEvolves == nil, i["megaStone"] != nil {
                megaEvolves = i["itemUser"]?.stringArray?.first ?? i["megaStone"]?.string?.components(separatedBy: "-Mega").first
            }

            var naturalGift: NaturalGift?
            if let gift = i["naturalGift"], let power = gift["basePower"]?.int, let type = gift["type"]?.string.flatMap(PokemonType.init(name:)) {
                naturalGift = NaturalGift(basePower: power, type: type)
            }

            items.append(Item(
                id: id, name: name, description: api?.flavorText, shortDescription: text?["shortDesc"]?.string ?? text?["desc"]?.string,
                category: category, generation: i["gen"]?.int ?? 9, availability: availability(for: i["isNonstandard"]?.string),
                flingPower: i["fling"]?["basePower"]?.int, naturalGift: naturalGift, megaEvolves: megaEvolves,
                users: i["itemUser"]?.stringArray, associatedType: associatedType, spriteIndex: i["spritenum"]?.int
            ))
        }
        return items.sorted { $0.name < $1.name }
    }

    // MARK: - Learnsets

    private func buildLearnsets(pokemonIDs: Set<String>, moveIDs: Set<String>) -> [String: Learnset] {
        var result: [String: Learnset] = [:]
        for (id, entry) in showdown.learnsets {
            guard pokemonIDs.contains(id), let learnset = entry["learnset"]?.object, !learnset.isEmpty else { continue }
            var moves: [String: [LearnSource]] = [:]
            for (moveID, codes) in learnset {
                guard moveIDs.contains(moveID) else { continue }
                let sources = (codes.stringArray ?? []).compactMap(LearnSource.init(code:))
                guard let latest = sources.map(\.generation).max() else { continue }
                var kept = sources.filter { $0.generation == latest }
                // Keep one entry per method; level-up keeps every level it is learned at.
                var seen = Set<String>()
                kept = kept.filter { seen.insert($0.code).inserted }
                moves[moveID] = kept.sorted()
            }
            if !moves.isEmpty { result[id] = Learnset(moves: moves) }
        }
        return result
    }
}
