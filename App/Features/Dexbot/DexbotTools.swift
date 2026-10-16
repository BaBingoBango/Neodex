import Foundation
import FoundationModels
import NeodexKit

/// The facts Dexbot is allowed to use. Every tool answers from Neodex's own dataset (or Smogon's
/// published statistics), so the model phrases and reasons but never invents data.
nonisolated enum DexbotTools {
    static func all(database: PokedexDatabase) -> [any Tool] {
        [
            PokemonLookupTool(database: database),
            TypeMatchupTool(),
            MoveLookupTool(database: database),
            AbilityLookupTool(database: database),
            ItemLookupTool(database: database),
            PokemonMovesTool(database: database),
            UsageStatsTool(database: database),
            DamageCalcTool(database: database),
            MyTeamsTool(database: database),
            TeamLegalityTool(database: database),
        ]
    }

    static func notFound(_ kind: String, _ query: String, suggestions: [String]) -> String {
        var text = "No \(kind) called '\(query)' is in the Pokédex."
        if !suggestions.isEmpty { text += " Closest matches: " + suggestions.joined(separator: ", ") + "." }
        return text
    }

    static func stats(_ block: StatBlock) -> String {
        "HP \(block.hp), Atk \(block.attack), Def \(block.defense), SpA \(block.specialAttack), SpD \(block.specialDefense), Spe \(block.speed) (total \(block.total))"
    }
}

// MARK: - Pokémon

nonisolated struct PokemonLookupTool: Tool {
    let name = "lookUpPokemon"
    let description = "Looks up one Pokémon by name or National Dex number: types, abilities, base stats, weaknesses and resistances, Smogon tier, evolutions, size and a Pokédex entry."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "The Pokémon's name, including any form (e.g. 'Garchomp', 'Mega Charizard X', 'Ogerpon-Wellspring'), or its National Dex number.")
        var pokemon: String
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        guard let pokemon = database.resolvePokemon(arguments.pokemon) else {
            return DexbotTools.notFound("Pokémon", arguments.pokemon, suggestions: database.search(arguments.pokemon, limitPerCategory: 4).pokemon.map(\.displayName))
        }
        return database.factSheet(for: pokemon)
    }
}

nonisolated struct TypeMatchupTool: Tool {
    let name = "typeMatchups"
    let description = "Defensive matchups for a type or a pair of types: what deals double, quadruple, half, quarter or no damage to that combination, and what the types hit super-effectively."

    @Generable
    struct Arguments {
        @Guide(description: "One or two type names, e.g. ['Fire', 'Flying'].", .count(1...2))
        var types: [String]
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        let types = arguments.types.compactMap { PokemonType(name: $0) }
        guard !types.isEmpty else { return "Unknown type. Types are: " + PokemonType.allCases.map(\.name).joined(separator: ", ") + "." }
        let profile = TypeMatchup.defensiveProfile(for: types)
        var lines = ["Defensively, a \(types.map(\.name).joined(separator: "/")) type: " + TypeMatchupSummary.compact(profile: profile)]
        for type in types {
            let offense = TypeMatchup.offensiveProfile(for: type)
            lines.append("\(type.name) attacks hit super-effectively: \(offense.superEffective.map(\.name).joined(separator: ", ")); resisted by: \(offense.notVeryEffective.map(\.name).joined(separator: ", "))"
                         + (offense.noEffect.isEmpty ? "." : "; no effect on: \(offense.noEffect.map(\.name).joined(separator: ", "))."))
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Moves, abilities, items

nonisolated struct MoveLookupTool: Tool {
    let name = "lookUpMove"
    let description = "Looks up a move: type, category, power, accuracy, PP, priority, effect, and how many Pokémon learn it with a few examples."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "The move's name, e.g. 'Earthquake'.")
        var move: String
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        guard let move = database.move(named: arguments.move) ?? database.search(arguments.move, limitPerCategory: 1).moves.first else {
            return DexbotTools.notFound("move", arguments.move, suggestions: database.search(arguments.move, limitPerCategory: 4).moves.map(\.name))
        }
        let learners = database.learners(of: move)
        var text = "\(move.name): \(move.type.name)-type \(move.category.name) move, power \(move.basePowerText), accuracy \(move.accuracyText), \(move.pp) PP"
        if move.priority != 0 { text += ", priority \(move.priority > 0 ? "+" : "")\(move.priority)" }
        text += ". " + (move.shortDescription ?? move.description ?? "")
        if let tm = move.tmLabel { text += " Available as \(tm)." }
        if move.availability != .current { text += " Not available in the current games." }
        text += " Learned by \(learners.count) Pokémon"
        if !learners.isEmpty { text += ", e.g. " + learners.prefix(6).map(\.pokemon.displayName).joined(separator: ", ") }
        return text + "."
    }
}

nonisolated struct AbilityLookupTool: Tool {
    let name = "lookUpAbility"
    let description = "Looks up an Ability: what it does, Showdown's competitive rating, and which Pokémon can have it."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "The Ability's name, e.g. 'Intimidate'.")
        var ability: String
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        guard let ability = database.ability(named: arguments.ability) ?? database.search(arguments.ability, limitPerCategory: 1).abilities.first else {
            return DexbotTools.notFound("Ability", arguments.ability, suggestions: database.search(arguments.ability, limitPerCategory: 4).abilities.map(\.name))
        }
        let holders = database.pokemon(withAbility: ability.id)
        var text = "\(ability.name): \(ability.shortDescription ?? ability.description ?? "")"
        if let rating = ability.rating { text += " Competitive rating \(rating.formatted())/5." }
        text += " Pokémon with it (\(holders.count)): " + holders.prefix(10).map(\.displayName).joined(separator: ", ")
        return text + (holders.count > 10 ? ", and more." : ".")
    }
}

nonisolated struct ItemLookupTool: Tool {
    let name = "lookUpItem"
    let description = "Looks up a held item: what it does and its category."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "The item's name, e.g. 'Choice Scarf'.")
        var item: String
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        guard let item = database.item(named: arguments.item) ?? database.search(arguments.item, limitPerCategory: 1).items.first else {
            return DexbotTools.notFound("item", arguments.item, suggestions: database.search(arguments.item, limitPerCategory: 4).items.map(\.name))
        }
        var text = "\(item.name) (\(item.category.name)): \(item.shortDescription ?? item.description ?? "")"
        if item.availability != .current { text += " Not available in the current games." }
        return text
    }
}

nonisolated struct PokemonMovesTool: Tool {
    let name = "movesForPokemon"
    let description = "Lists moves a Pokémon can learn: its strongest attacks, optionally filtered to one type or category, or checks whether it can learn a specific move and how."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "The Pokémon's name.")
        var pokemon: String
        @Guide(description: "A specific move to check, e.g. 'Earthquake'. Leave empty to list the strongest attacks.")
        var move: String?
        @Guide(description: "Only moves of this type, e.g. 'Fire'.")
        var type: String?
        @Guide(description: "'Physical', 'Special' or 'Status'.")
        var category: String?
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        guard let pokemon = database.resolvePokemon(arguments.pokemon) else {
            return DexbotTools.notFound("Pokémon", arguments.pokemon, suggestions: database.search(arguments.pokemon, limitPerCategory: 4).pokemon.map(\.displayName))
        }
        let learnset = database.learnset(for: pokemon)
        if let moveName = arguments.move, !moveName.isEmpty {
            guard let move = database.move(named: moveName) else { return DexbotTools.notFound("move", moveName, suggestions: []) }
            guard let sources = database.learnSources(for: pokemon, moveID: move.id) else {
                return "\(pokemon.displayName) cannot learn \(move.name)."
            }
            let methods = Set(sources.map(\.label)).sorted()
            return "\(pokemon.displayName) can learn \(move.name) (\(move.type.name), \(move.category.name), power \(move.basePowerText)) via: \(methods.joined(separator: ", "))."
        }
        let type = arguments.type.flatMap { PokemonType(name: $0) }
        let category = arguments.category.flatMap { MoveCategory(rawValue: $0.capitalized) }
        var moves = learnset.map(\.move).filter { $0.availability == .current && $0.kind == .standard }
        if let type { moves = moves.filter { $0.type == type } }
        if let category { moves = moves.filter { $0.category == category } }
        if category != .status { moves = moves.filter { $0.basePower > 0 || category == nil } }
        let attacks = moves.filter { $0.basePower > 0 }.sorted { $0.basePower != $1.basePower ? $0.basePower > $1.basePower : $0.name < $1.name }
        let statuses = moves.filter { $0.basePower == 0 }
        var text = "\(pokemon.displayName) learns \(learnset.count) moves."
        if !attacks.isEmpty {
            text += " Strongest attacks: " + attacks.prefix(12).map { "\($0.name) (\($0.type.name) \($0.category.name) \($0.basePower)\(pokemon.types.contains($0.type) ? ", STAB" : ""))" }.joined(separator: "; ") + "."
        }
        if !statuses.isEmpty, category == .status || attacks.isEmpty || category == nil {
            text += " Notable status moves: " + statuses.prefix(10).map(\.name).joined(separator: ", ") + "."
        }
        return text
    }
}

// MARK: - Smogon

nonisolated struct UsageStatsTool: Tool {
    let name = "smogonUsage"
    let description = "Smogon's latest usage statistics for a competitive format: the most-used Pokémon, or one Pokémon's usage with its common items, moves, abilities, Tera types, teammates and checks. Needs internet."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "Showdown format ID such as 'gen9ou', 'gen9ubers', 'gen9uu' or 'gen9vgc2026'. Defaults to Gen 9 OU.")
        var format: String?
        @Guide(description: "A Pokémon to get details for. Leave empty for the top of the format.")
        var pokemon: String?
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        let client = SmogonStatsClient.shared
        let formatID = ShowdownID.make(arguments.format?.isEmpty == false ? arguments.format! : "gen9ou")
        guard let month = try await client.months().first else { return "Smogon's statistics aren't reachable right now." }
        let formats = try await client.formats(for: month)
        guard let format = formats.first(where: { $0.id == formatID }) ?? formats.first(where: { $0.id.hasPrefix(formatID) }) else {
            return "Smogon has no format '\(formatID)' for \(UsageDefaults.displayMonth(month)). Formats include: " + formats.prefix(12).map(\.id).joined(separator: ", ") + "."
        }
        let selection = UsageSelection(month: month, format: format.id, rating: UsageDefaults.defaultRating(for: format))
        let formatName = "\(format.displayName) (\(UsageDefaults.displayMonth(month)), \(selection.rating)+ rating)"

        if let name = arguments.pokemon, !name.isEmpty {
            let report = try await client.chaos(for: selection)
            let key = ShowdownID.make(database.resolvePokemon(name)?.name ?? name)
            guard let detail = report.details.first(where: { ShowdownID.make($0.key) == key })?.value else {
                return "\(name) has no recorded usage in \(formatName)."
            }
            func top(_ entries: [UsageDetail.Entry], _ count: Int, label: (String) -> String) -> String {
                entries.prefix(count).map { "\(label($0.key)) \($0.percent.formatted(.number.precision(.fractionLength(0))))%" }.joined(separator: ", ")
            }
            return """
            \(detail.name) in \(formatName): \(detail.usagePercent.formatted(.number.precision(.fractionLength(1))))% usage (\(detail.rawCount.formatted()) sets).
            Items: \(top(detail.items, 4) { database.item(id: $0)?.name ?? $0 }).
            Moves: \(top(detail.moves, 6) { database.move(id: $0)?.name ?? $0 }).
            Abilities: \(top(detail.abilities, 3) { database.ability(id: $0)?.name ?? $0 }).
            Tera types: \(top(detail.teraTypes, 3) { $0 }).
            Teammates: \(top(detail.teammates, 5) { $0 }).
            Checks and counters: \(detail.checksAndCounters.prefix(5).map(\.name).joined(separator: ", ")).
            """
        }
        let report = try await client.rankings(for: selection)
        let rows = report.rankings.prefix(15).map { "\($0.rank). \($0.name) \($0.usagePercent.formatted(.number.precision(.fractionLength(1))))%" }
        return "Most used in \(formatName): " + rows.joined(separator: "; ") + "."
    }
}

// MARK: - Damage

nonisolated struct DamageCalcTool: Tool {
    let name = "calculateDamage"
    let description = "Runs a Pokémon Showdown-style damage calculation for one move from an attacker against a defender, with optional item, nature, EVs, Tera type and field conditions. Returns the damage range, percentages and KO chance."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "The attacking Pokémon.")
        var attacker: String
        @Guide(description: "The move used.")
        var move: String
        @Guide(description: "The defending Pokémon.")
        var defender: String
        @Guide(description: "Attacker's held item, e.g. 'Choice Band'.")
        var attackerItem: String?
        @Guide(description: "Attacker's nature, e.g. 'Adamant'. Defaults to a neutral nature with 252 EVs in the attacking stat.")
        var attackerNature: String?
        @Guide(description: "Attacker's Tera type if Terastallized.")
        var attackerTeraType: String?
        @Guide(description: "Defender's held item, e.g. 'Assault Vest'.")
        var defenderItem: String?
        @Guide(description: "Defender's EVs in HP, 0–252. Defaults to 0.")
        var defenderHPEVs: Int?
        @Guide(description: "Defender's EVs in the defending stat, 0–252. Defaults to 0.")
        var defenderDefenseEVs: Int?
        @Guide(description: "Weather: 'Sun', 'Rain', 'Sandstorm' or 'Snow'.")
        var weather: String?
        @Guide(description: "Terrain: 'Electric', 'Grassy', 'Psychic' or 'Misty'.")
        var terrain: String?
        @Guide(description: "Whether the hit is a critical hit.")
        var criticalHit: Bool?
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        guard let attackerPokemon = database.resolvePokemon(arguments.attacker) else { return DexbotTools.notFound("Pokémon", arguments.attacker, suggestions: []) }
        guard let defenderPokemon = database.resolvePokemon(arguments.defender) else { return DexbotTools.notFound("Pokémon", arguments.defender, suggestions: []) }
        guard let move = database.move(named: arguments.move) else { return DexbotTools.notFound("move", arguments.move, suggestions: []) }

        let attackingStat: Stat = move.category == .physical ? .attack : .specialAttack
        var attackerEVs = StatBlock()
        attackerEVs[attackingStat] = 252
        let nature = arguments.attackerNature.flatMap { Nature.named($0) } ?? .serious
        let attacker = BattleCombatant(
            pokemon: attackerPokemon, ability: database.ability(id: attackerPokemon.abilities.primary) ?? Ability(id: "none", name: "None", generation: 9),
            nature: nature, evs: attackerEVs, item: arguments.attackerItem.flatMap { database.item(named: $0) },
            teraType: arguments.attackerTeraType.flatMap { PokemonType(name: $0) })
        var defenderEVs = StatBlock()
        defenderEVs.hp = min(252, max(0, arguments.defenderHPEVs ?? 0))
        defenderEVs[move.category == .physical ? .defense : .specialDefense] = min(252, max(0, arguments.defenderDefenseEVs ?? 0))
        let defender = BattleCombatant(
            pokemon: defenderPokemon, ability: database.ability(id: defenderPokemon.abilities.primary) ?? Ability(id: "none", name: "None", generation: 9),
            evs: defenderEVs, item: arguments.defenderItem.flatMap { database.item(named: $0) })
        let field = BattleField(weather: Weather(rawValue: (arguments.weather ?? "none").lowercased()) ?? .none,
                                terrain: Terrain(rawValue: (arguments.terrain ?? "none").lowercased()) ?? .none,
                                isCritical: arguments.criticalHit ?? false)
        let result = DamageCalculator.calculate(attacker: attacker, defender: defender, move: move, field: field)
        var text = result.summary(moveName: move.name)
        text += " Assumptions: level 100, the attacker's first ability (\(attacker.ability.name)), the defender's first ability (\(defender.ability.name)), 31 IVs, and no stat stages."
        return text
    }
}

// MARK: - The user's teams

nonisolated struct MyTeamsTool: Tool {
    let name = "myTeams"
    let description = "Lists the user's saved Teambuilder teams, or the full sets (items, abilities, natures, EVs, moves) of one team."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "The team's name to see its full sets. Leave empty to list all teams.")
        var team: String?
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        let teams = await TeamReader.teamSets()
        guard !teams.isEmpty else { return "The user has no saved teams yet." }
        if let name = arguments.team, !name.isEmpty {
            let key = ShowdownID.make(name)
            guard let match = teams.first(where: { ShowdownID.make($0.team.name) == key }) ?? teams.first(where: { ShowdownID.make($0.team.name).contains(key) }) else {
                return "No team called '\(name)'. Teams: " + teams.map(\.team.name).joined(separator: ", ") + "."
            }
            let sets = match.sets.map { set -> String in
                let pokemon = database.pokemon(id: set.pokemonID)?.name ?? set.pokemonID
                let item = set.itemID.flatMap { database.item(id: $0)?.name } ?? "no item"
                let ability = set.abilityID.flatMap { database.ability(id: $0)?.name } ?? "—"
                let moves = set.moveIDs.compactMap { database.move(id: $0)?.name }.joined(separator: " / ")
                let evs = set.evs.map { "\($0.value) \($0.key)" }.joined(separator: " / ")
                return "\(pokemon) @ \(item); \(ability); \(Nature.named(set.natureID)?.name ?? set.natureID)\(set.teraType.map { "; Tera \($0.capitalized)" } ?? ""); EVs \(evs.isEmpty ? "none" : evs); moves: \(moves.isEmpty ? "none" : moves)"
            }
            return "Team '\(match.team.name)'" + (match.team.format.map { " (\(UsageFormat.displayName(for: $0)))" } ?? "") + ":\n" + sets.joined(separator: "\n")
        }
        return "Saved teams: " + teams.map { entry in
            let members = entry.team.pokemonIDs.compactMap { database.pokemon(id: $0)?.name }.joined(separator: ", ")
            return "'\(entry.team.name)'" + (entry.team.format.map { " (\(UsageFormat.displayName(for: $0)))" } ?? "") + ": \(members.isEmpty ? "empty" : members)"
        }.joined(separator: "; ") + "."
    }
}

nonisolated struct TeamLegalityTool: Tool {
    let name = "checkTeamLegality"
    let description = "Checks one of the user's saved teams against a Smogon singles tier (gen9ag, gen9ubers, gen9ou, gen9uu, gen9ru, gen9nu, gen9pu, gen9zu, gen9lc) and lists every problem."
    let database: PokedexDatabase

    @Generable
    struct Arguments {
        @Guide(description: "The team's name.")
        var team: String
        @Guide(description: "Format ID such as 'gen9ou'. Defaults to the team's own format, else Gen 9 OU.")
        var format: String?
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        let teams = await TeamReader.teamSets()
        let key = ShowdownID.make(arguments.team)
        guard let match = teams.first(where: { ShowdownID.make($0.team.name) == key }) ?? teams.first(where: { ShowdownID.make($0.team.name).contains(key) }) else {
            return "No team called '\(arguments.team)'. Teams: " + teams.map(\.team.name).joined(separator: ", ") + "."
        }
        let formatID = arguments.format?.isEmpty == false ? arguments.format! : (match.team.format ?? "gen9ou")
        guard let format = SmogonFormat(formatID: formatID) else {
            return "'\(formatID)' isn't one of the Smogon singles tiers Neodex can check (gen9ag, gen9ubers, gen9ou, gen9uu, gen9ru, gen9nu, gen9pu, gen9zu, gen9lc)."
        }
        let sets = match.sets.enumerated().map { index, set in
            LegalitySet(id: "\(index)", pokemonID: set.pokemonID, abilityID: set.abilityID, itemID: set.itemID, moveIDs: set.moveIDs, level: set.level)
        }
        let issues = FormatLegality.check(sets, format: format, database: database)
        guard !issues.isEmpty else { return "'\(match.team.name)' is legal in \(format.name)." }
        let lines = issues.map { issue -> String in
            let who = issue.setID.flatMap { Int($0) }.flatMap { match.sets.indices.contains($0) ? database.pokemon(id: match.sets[$0].pokemonID)?.name : nil }
            return (who.map { "\($0): " } ?? "") + issue.message
        }
        return "'\(match.team.name)' has \(issues.count) issue(s) in \(format.name): " + lines.joined(separator: " ")
    }
}

// MARK: - Helpers

extension PokedexDatabase {
    /// Name, Showdown ID or dex number, tolerant of spelling.
    nonisolated func resolvePokemon(_ query: String) -> Pokemon? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if let number = Int(trimmed) { return pokemon(dexNumber: number).first }
        return pokemon(named: trimmed) ?? pokemon(id: ShowdownID.make(trimmed)) ?? search(trimmed, limitPerCategory: 1).pokemon.first
    }

    /// A compact, complete description of a Pokémon for the model to work from.
    nonisolated func factSheet(for pokemon: Pokemon) -> String {
        let abilities = pokemon.abilities.all.compactMap { ability(id: $0)?.name }
        var lines: [String] = []
        lines.append("\(pokemon.displayName) (\(pokemon.formattedDexNumber), Generation \(pokemon.generation)\(pokemon.genus.map { ", the \($0) Pokémon" } ?? "")).")
        lines.append("Types: \(pokemon.types.map(\.name).joined(separator: "/")). Abilities: \(abilities.joined(separator: ", "))\(pokemon.abilities.hidden != nil ? " (last is hidden)" : "").")
        lines.append("Base stats: \(DexbotTools.stats(pokemon.baseStats)).")
        lines.append("Matchups: \(TypeMatchupSummary.compact(profile: pokemon.defensiveProfile))")
        if let tier = pokemon.tier { lines.append("Smogon Gen 9 tier: \(tier).") }
        if pokemon.availability != .current { lines.append("Not obtainable in the current games.") }
        let family = evolutionFamily(of: pokemon)
        if family.count > 1 {
            let chain = family.map { stage -> String in
                let how = stage.evolvesFrom.flatMap { from in self.pokemon(id: from)?.evolutions.first { $0.to == stage.id }?.methodDescription }
                return stage.displayName + (how.map { " (\($0))" } ?? "")
            }
            lines.append("Evolution line: " + chain.joined(separator: " → ") + ".")
        }
        if !pokemon.otherFormIDs.isEmpty {
            lines.append("Other forms: " + pokemon.otherFormIDs.compactMap { self.pokemon(id: $0)?.displayName }.joined(separator: ", ") + ".")
        }
        lines.append("Height \(Measurements.height(pokemon.height)); weight \(Measurements.weight(pokemon.weight)). Egg groups: \(pokemon.eggGroups.isEmpty ? "none" : pokemon.eggGroups.joined(separator: ", ")).")
        if let entry = pokemon.dexEntries.first { lines.append("Pokédex entry (\(entry.gamesSummary)): \(entry.text)") }
        return lines.joined(separator: "\n")
    }
}
