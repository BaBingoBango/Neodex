import Foundation
import FoundationModels
import NeodexKit
import SwiftData

/// Dexbot's teambuilding. Dexbot names the Pokémon the team is built around and may write their sets in
/// Pokémon Showdown's export format. Neodex adds a Pokémon to set the weather for a weather team, fills the
/// empty slots with the Pokémon Smogon's players pair with the rest, completes every set with Smogon's
/// most common choices for the format, swaps anything the format doesn't allow for the next most common
/// legal choice, and saves the team to the Teambuilder. A small model that only picks one Pokémon still
/// hands over a full team the user can play.
@MainActor
enum DexbotTeamBuilder {
    /// Smogon's usage details for a format, by Pokémon name, or nil when they can't be fetched.
    typealias UsageLookup = @Sendable (_ formatID: String) async -> [String: UsageDetail]?

    /// Teams Dexbot has saved or updated since launch, oldest first. The chat shows a card for each one
    /// touched while a reply was being written.
    private(set) static var savedTeamIDs: [UUID] = []

    /// Builds and saves a team around the named Pokémon, with full sets for any the model wrote out.
    /// The result is written for the model to read.
    static func build(name: String, format rawFormat: String, pokemon names: [String] = [], weather: Weather? = nil,
                      sets text: String = "", database: PokedexDatabase, usage: UsageLookup = smogonUsage,
                      context: ModelContext? = nil) async -> String {
        let formatID = normalizedFormatID(rawFormat)
        let format = SmogonFormat(formatID: formatID)
        // Formats Neodex has no rules for still get the basics: real, obtainable Pokémon, moves,
        // Abilities and items.
        let rules = format ?? .anythingGoes
        let formatName = UsageFormat.displayName(for: formatID)
        let details = Dictionary((await usage(formatID) ?? [:]).map { (ShowdownID.make($0.key), $0.value) },
                                 uniquingKeysWith: { first, _ in first })
        // Showdown plays VGC and Battle Stadium at level 50 and Little Cup at level 5.
        let level = defaultLevel(for: formatID)

        var sets = teamSets(names: names, text: text)
        var additions: [String] = []
        // Reported as an addition, so its set doesn't also count as one Neodex completed.
        var setter: ShowdownSet?
        if let weather, let added = addWeatherSetter(weather, to: &sets, details: details, rules: rules,
                                                     level: level ?? 100, database: database) {
            setter = sets.first
            additions.append(added)
        }

        var members: [TeamMember] = []
        var changes: [String] = []
        var completed: [String] = []
        var species: Set<String> = []
        func add(_ set: ShowdownSet, _ pokemon: Pokemon) -> [String] {
            var member = TeamConversion.member(from: set, pokemon: pokemon, database: database, warnings: &changes)
            if set.level == 100, let level { member.level = level }
            let parts = complete(&member, from: set, pokemon: pokemon, usage: details[pokemon.id], rules: rules,
                                 database: database, changes: &changes)
            if member.chosenMoveIDs.isEmpty {
                changes.append("\(pokemon.displayName) has no moves yet, since Smogon has no \(formatName) data for it; pick them in the Teambuilder.")
            }
            members.append(member)
            species.insert(pokemon.speciesID)
            return parts
        }

        for set in sets {
            guard let pokemon = database.pokemon(named: set.species) ?? database.resolvePokemon(set.species) else {
                changes.append("Left out “\(set.species)”, which isn't in the Pokédex.")
                continue
            }
            if let problem = FormatLegality.check(pokemon: pokemon, format: rules).first {
                changes.append("Left out \(pokemon.displayName): \(problem.message)")
                continue
            }
            guard !species.contains(pokemon.speciesID) else {
                changes.append("Left out the second \(pokemon.displayName): a team can't have two of the same Pokémon.")
                continue
            }
            guard members.count < SavedTeam.maximumMembers else {
                changes.append("Left out \(pokemon.displayName): a team has room for six.")
                continue
            }
            let parts = add(set, pokemon)
            // Without statistics only the Ability can be filled in, from the Pokédex.
            if !parts.isEmpty, set.species != setter?.species, details[pokemon.id] != nil { completed.append(pokemon.displayName) }
        }
        guard !members.isEmpty else {
            return "Not saved: none of those Pokémon can go on a \(formatName) team. " + changes.joined(separator: " ")
        }

        var partners: [String] = []
        while members.count < SavedTeam.maximumMembers,
              let pokemon = bestPartner(for: members, details: details, excluding: species, rules: rules, database: database) {
            _ = add(ShowdownSet(species: pokemon.name), pokemon)
            partners.append(pokemon.displayName)
        }
        if !partners.isEmpty {
            additions.append("Neodex filled the empty slots with \(partners.formatted(.list(type: .and))), which Smogon's players most often use alongside the rest.")
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let teamName = trimmedName.isEmpty ? "Dexbot Team" : trimmedName
        let context = context ?? PersistenceContainer.shared.mainContext
        let team: SavedTeam
        let verb: String
        if let existing = recentTeam(named: teamName, in: context) {
            existing.members = members
            existing.format = formatID
            team = existing
            verb = "Updated"
        } else {
            team = SavedTeam(name: teamName, format: formatID, members: members)
            context.insert(team)
            verb = "Saved"
        }
        try? context.save()
        team.touch()
        savedTeamIDs.append(team.id)

        // Small models sometimes repeat a tool's result word for word, so it's all written to make sense
        // to the user too; what to do with it is in Dexbot's instructions.
        var notes = additions
        if !completed.isEmpty {
            notes.append("Neodex completed the sets for \(completed.formatted(.list(type: .and))) with Smogon's most common \(formatName) choices.")
        }
        if !changes.isEmpty { notes.append("Changes Neodex made: " + changes.joined(separator: " ")) }
        if members.count < SavedTeam.maximumMembers, details.isEmpty {
            notes.append("Smogon's statistics aren't reachable right now, so Neodex couldn't fill the empty slots.")
        }
        let remaining = FormatLegality.check(team.legalitySets, format: rules, database: database)
        if !remaining.isEmpty {
            notes.append("Still to fix in the Teambuilder: " + remaining.map(\.message).joined(separator: " "))
        } else if let format {
            notes.append("Every set is legal in \(format.name).")
        } else {
            notes.append("Every Pokémon, move, Ability and item is real and obtainable, but Neodex can't check \(formatName)'s own rules.")
        }
        let roster = members.map { "- " + summary(of: $0, database: database) }.joined(separator: "\n")
        return "\(verb) “\(team.name)” for \(formatName) to Teams with exactly these \(members.count) Pokémon:\n\(roster)\n"
            + notes.joined(separator: " ")
    }

    /// One line per member for the model to describe: "Pelipper @ Damp Rock (Drizzle): Hurricane, Surf, U-turn, Roost".
    private static func summary(of member: TeamMember, database: PokedexDatabase) -> String {
        var text = database.pokemon(id: member.pokemonID)?.displayName ?? member.pokemonID
        if let item = member.itemID.flatMap({ database.item(id: $0)?.name }) { text += " @ \(item)" }
        if let ability = member.abilityID.flatMap({ database.ability(id: $0)?.name }) { text += " (\(ability))" }
        let moves = member.chosenMoveIDs.compactMap { database.move(id: $0)?.name }
        return moves.isEmpty ? text : text + ": " + moves.joined(separator: ", ")
    }

    /// The Abilities that bring each weather in with the Pokémon.
    nonisolated static func weatherAbilities(_ weather: Weather) -> [String] {
        switch weather {
        case .rain: ["drizzle"]
        case .sun: ["drought", "orichalcumpulse"]
        case .sandstorm: ["sandstream"]
        case .snow: ["snowwarning"]
        case .none: []
        }
    }

    /// Makes sure a weather team has a Pokémon to set the weather: one of the team's own with the right
    /// Ability, or else the one that sets it most often in the format (the strongest the format allows,
    /// without statistics) at the front of the team. Returns a sentence for the model when it adds one.
    private static func addWeatherSetter(_ weather: Weather, to sets: inout [ShowdownSet], details: [String: UsageDetail],
                                         rules: SmogonFormat, level: Int, database: PokedexDatabase) -> String? {
        let abilities = weatherAbilities(weather)
        guard !abilities.isEmpty else { return nil }
        for index in sets.indices {
            guard let pokemon = database.pokemon(named: sets[index].species) ?? database.resolvePokemon(sets[index].species),
                  let ability = abilities.first(where: pokemon.abilities.contains) else { continue }
            if let written = sets[index].ability {
                if abilities.contains(ShowdownID.make(written)) { return nil }
            } else {
                sets[index].ability = database.ability(id: ability)?.name
                return nil
            }
        }

        let candidates = abilities.flatMap { ability in database.pokemon(withAbility: ability).map { (pokemon: $0, ability: ability) } }
            .filter { candidate in
                let probe = LegalitySet(id: "probe", pokemonID: candidate.pokemon.id, abilityID: candidate.ability, level: level)
                return FormatLegality.check([probe], format: rules, database: database).allSatisfy { $0.kind == .team }
            }
        func setsWeather(_ candidate: (pokemon: Pokemon, ability: String)) -> Double {
            guard let detail = details[candidate.pokemon.id] else { return 0 }
            return detail.usagePercent * (detail.abilities.first { $0.key == candidate.ability }?.percent ?? 0)
        }
        guard let setter = candidates.max(by: { (setsWeather($0), $0.pokemon.baseStats.total) < (setsWeather($1), $1.pokemon.baseStats.total) }),
              let ability = database.ability(id: setter.ability) else { return nil }
        var set = ShowdownSet(species: setter.pokemon.name)
        set.ability = ability.name
        sets.insert(set, at: 0)
        return "Neodex added \(setter.pokemon.displayName) to set up \(weather.name.lowercased()) with \(ability.name)."
    }

    /// The Pokémon Smogon's players pair with these members far more than its popularity alone explains
    /// (Barraskewda with Pelipper, not the format's most used Pokémon with everyone), or the format's most
    /// used when the members have no recorded teammates, that the team has room for.
    private static func bestPartner(for members: [TeamMember], details: [String: UsageDetail], excluding species: Set<String>,
                                    rules: SmogonFormat, database: PokedexDatabase) -> Pokemon? {
        var scores: [String: Double] = [:]
        for detail in members.compactMap({ details[$0.pokemonID] }) {
            for teammate in detail.teammates {
                let id = ShowdownID.make(teammate.key)
                scores[id, default: 0] += teammate.percent - (details[id]?.usagePercent ?? 0)
            }
        }
        let paired = scores.filter { $0.value > 0 }.sorted { $0.value > $1.value }.map { $0.key }
        let popular = details.sorted { $0.value.usagePercent > $1.value.usagePercent }.map { $0.key }
        return (paired + popular).lazy.compactMap { database.pokemon(id: $0) }.first { pokemon in
            !species.contains(pokemon.speciesID) && FormatLegality.check(pokemon: pokemon, format: rules).isEmpty
        }
    }

    /// Fills in the parts a set left out with Smogon's most common choices for the Pokémon, and replaces
    /// any the format doesn't allow. Returns the names of the parts it filled in.
    private static func complete(_ member: inout TeamMember, from set: ShowdownSet, pokemon: Pokemon, usage: UsageDetail?,
                                 rules: SmogonFormat, database: PokedexDatabase, changes: inout [String]) -> [String] {
        let name = pokemon.displayName
        let level = member.level
        // One part at a time through the legality checker, so every rule it knows applies.
        func problem(ability: String? = nil, item: String? = nil, move: String? = nil) -> LegalityIssue? {
            let probe = LegalitySet(id: "probe", pokemonID: pokemon.id, abilityID: ability, itemID: item,
                                    moveIDs: move.map { [$0] } ?? [], level: level)
            return FormatLegality.check([probe], format: rules, database: database).first { $0.kind != .pokemon && $0.kind != .team }
        }
        var parts: [String] = []

        let givenAbility = set.ability.flatMap { database.ability(named: $0) }
        if givenAbility == nil || problem(ability: member.abilityID) != nil {
            let candidates = (usage?.abilities.map(\.key) ?? []) + pokemon.abilities.all
            if let replacement = candidates.first(where: { pokemon.abilities.contains($0) && problem(ability: $0) == nil }) {
                if let givenAbility, let issue = problem(ability: givenAbility.id) {
                    changes.append("\(issue.message) \(name) has \(database.ability(id: replacement)?.name ?? replacement) instead.")
                }
                member.abilityID = replacement
            }
            if set.ability == nil { parts.append("Ability") }
        }

        if member.itemID == nil || problem(item: member.itemID) != nil {
            if let itemID = member.itemID, let issue = problem(item: itemID) { changes.append("\(name): \(issue.message)") }
            member.itemID = usage?.items.map(\.key).first { database.item(id: $0) != nil && problem(item: $0) == nil }
            if set.item == nil, member.itemID != nil { parts.append("item") }
        }

        var moves = member.chosenMoveIDs
        for move in moves {
            if let issue = problem(move: move) { changes.append("\(name): \(issue.message)") }
        }
        moves.removeAll { problem(move: $0) != nil }
        let missing = 4 - moves.count
        if missing > 0, let usage {
            let additions = usage.moves.map(\.key)
                .filter { database.move(id: $0) != nil && !moves.contains($0) && problem(move: $0) == nil }
                .prefix(missing)
            moves += additions
            if !additions.isEmpty { parts.append("moves") }
        }
        member.moveIDs = moves.map(Optional.some) + Array(repeating: nil, count: max(0, 4 - moves.count))

        if set.nature == nil, set.evs == .zero, let spread = usage?.spreads.lazy.compactMap({ parseSpread($0.key) }).first {
            member.natureID = spread.nature.id
            member.evs = spread.evs
            parts.append("nature and EVs")
        }
        if set.teraType == nil, let tera = usage?.teraTypes.lazy.compactMap({ PokemonType(name: $0.key) }).first {
            member.teraType = tera
            parts.append("Tera Type")
        }
        return parts
    }

    /// A team Dexbot saved earlier with this name, so asking again refines it instead of adding a copy.
    private static func recentTeam(named name: String, in context: ModelContext) -> SavedTeam? {
        for id in savedTeamIDs.reversed() {
            var descriptor = FetchDescriptor<SavedTeam>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            if let team = try? context.fetch(descriptor).first, team.name.localizedCaseInsensitiveCompare(name) == .orderedSame {
                return team
            }
        }
        return nil
    }

    /// The latest month's usage details for a format at its usual rating cutoff.
    nonisolated static let smogonUsage: UsageLookup = { formatID in
        let client = SmogonStatsClient.shared
        guard let month = try? await client.months().first, let formats = try? await client.formats(for: month),
              let format = formats.first(where: { $0.id == formatID }) ?? formats.first(where: { $0.id.hasPrefix(formatID) }) else { return nil }
        let selection = UsageSelection(month: month, format: format.id, rating: UsageDefaults.defaultRating(for: format))
        return try? await client.chaos(for: selection).details
    }

    /// A Showdown format ID from however the format was written: "OU", "Gen 9 OU" and "gen9ou" are all Gen 9 OU.
    nonisolated static func normalizedFormatID(_ raw: String) -> String {
        let aliases = ["littlecup": "lc", "anythinggoes": "ag", "uber": "ubers"]
        var key = ShowdownID.make(raw)
        if key.isEmpty { return SmogonFormat.ou.rawValue }
        if !key.hasPrefix("gen") { key = "gen9" + (aliases[key] ?? key) }
        return key
    }

    nonisolated static func defaultLevel(for formatID: String) -> Int? {
        if formatID == SmogonFormat.lc.rawValue { return 5 }
        if formatID.contains("vgc") || formatID.contains("bss") || formatID.contains("battlestadium") { return 50 }
        return nil
    }

    /// The sets to build: one per name, using the written set for that Pokémon when there is one, then
    /// any written sets for Pokémon the names left out.
    nonisolated static func teamSets(names: [String], text: String) -> [ShowdownSet] {
        var written = ShowdownTeamCodec.parseTeams(setsText(from: text)).first?.sets ?? []
        var sets: [ShowdownSet] = []
        for name in names.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !name.isEmpty {
            let key = ShowdownID.make(name)
            if let index = written.firstIndex(where: { ShowdownID.make($0.species) == key || ShowdownID.make($0.nickname ?? "") == key }) {
                sets.append(written.remove(at: index))
            } else {
                sets.append(ShowdownSet(species: name))
            }
        }
        return sets + written
    }

    /// Showdown's export format needs a blank line between sets; a plain list of names ("Pelipper,
    /// Barraskewda", or one per line with or without bullets) becomes one set per name, and sets written
    /// without the blank lines get them back.
    nonisolated static func setsText(from text: String) -> String {
        let bullet = /^(?:[-•*]|\d+[.)])\s*/
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let hasSetLines = lines.contains { $0.contains(":") || $0.contains("@") || $0.hasSuffix(" Nature") }
        // "- Move" lines under a species line are a set; a list that starts with a bullet is just names.
        let hasMoveLines = lines.first.map { $0.firstMatch(of: bullet) == nil } == true && lines.contains { $0.hasPrefix("-") }
        guard !hasSetLines, !hasMoveLines else { return separatingSets(lines) }
        let names = lines.flatMap { $0.split(separator: ",") }.map { item in
            item.trimmingCharacters(in: .whitespaces).replacing(bullet, with: "")
        }
        return names.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// Every line that isn't a move, nature or "Key: value" line starts a set.
    private nonisolated static func separatingSets(_ lines: [String]) -> String {
        let attribute = /^(?i:ability|evs|ivs|tera type|level|shiny|happiness|gigantamax|dynamax level|hidden power|pokeball|gender)\s*:/
        var output: [String] = []
        for line in lines {
            let isSetLine = line.hasPrefix("-") || line.hasSuffix(" Nature") || line.firstMatch(of: attribute) != nil
            if !isSetLine, !output.isEmpty { output.append("") }
            output.append(line)
        }
        return output.joined(separator: "\n")
    }

    /// A Smogon spread such as "Jolly:0/252/4/0/0/252" (HP/Atk/Def/SpA/SpD/Spe).
    nonisolated static func parseSpread(_ spread: String) -> (nature: Nature, evs: StatBlock)? {
        let halves = spread.split(separator: ":")
        guard halves.count == 2, let nature = Nature.named(String(halves[0])) else { return nil }
        let values = halves[1].split(separator: "/").compactMap { Int($0) }
        guard values.count == 6 else { return nil }
        return (nature, StatBlock(hp: values[0], attack: values[1], defense: values[2],
                                  specialAttack: values[3], specialDefense: values[4], speed: values[5]))
    }
}

/// A team Dexbot saved, carried at the end of its reply as a Markdown link (`neodex://team/<id>`), which the
/// chat turns into a card. Keeping it in the text means saved chats need no new fields.
nonisolated enum DexbotTeamLink {
    static func markdown(id: UUID, name: String) -> String {
        "[\(name)](\(SharedContainer.deepLink("team/\(id.uuidString)").absoluteString))"
    }

    /// A reply's text without its team links, and the teams they point to.
    static func split(_ text: String) -> (text: String, teamIDs: [UUID]) {
        var teamIDs: [UUID] = []
        var kept: [Substring] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let id = teamID(in: line) {
                if !teamIDs.contains(id) { teamIDs.append(id) }
            } else {
                kept.append(line)
            }
        }
        return (kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), teamIDs)
    }

    private static func teamID(in line: Substring) -> UUID? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let marker = "](\(SharedContainer.urlScheme)://team/"
        guard trimmed.hasPrefix("["), trimmed.hasSuffix(")"), let range = trimmed.range(of: marker) else { return nil }
        return UUID(uuidString: String(trimmed[range.upperBound...].dropLast()))
    }
}

nonisolated struct BuildTeamTool: Tool {
    let name = "buildTeam"
    let description = "Builds a team of six around the Pokémon you name and saves it to the user's Teambuilder. Neodex adds a Pokémon to set the weather for a weather team, fills the empty slots with the Pokémon Smogon's players most often use alongside the rest, completes every set with Smogon's most common choices for the format, fixes anything the format doesn't allow, and reports exactly what it saved. Saving again under the same name updates that team."
    let database: PokedexDatabase

    @Generable
    enum TeamWeather {
        case rain, sun, sand, snow
    }

    @Generable
    struct Arguments {
        @Guide(description: "A short name for the team, e.g. 'Rain Offense'.")
        var name: String
        @Guide(description: "Showdown format ID: gen9ou, gen9ubers, gen9uu, gen9ru, gen9nu, gen9pu, gen9zu, gen9lc or gen9ag for singles, or a VGC ID such as gen9vgc2026 for doubles.")
        var format: String
        @Guide(description: "The Pokémon the user asked for, or else one or two the team is built around, e.g. ['Kingambit'].", .count(1...6))
        var pokemon: [String]
        @Guide(description: "For a weather team only: the weather it's built around.")
        var weather: TeamWeather?
        @Guide(description: "Optional full sets for any of those Pokémon in Pokémon Showdown's export format, separated by blank lines. Leave empty to use Smogon's most common sets.")
        var sets: String?
    }

    @concurrent
    func call(arguments: Arguments) async throws -> String {
        let weather: Weather? = switch arguments.weather {
        case .rain: .rain
        case .sun: .sun
        case .sand: .sandstorm
        case .snow: .snow
        case nil: nil
        }
        return await DexbotTeamBuilder.build(name: arguments.name, format: arguments.format, pokemon: arguments.pokemon,
                                             weather: weather, sets: arguments.sets ?? "", database: database)
    }
}
