import Foundation
import NeodexKit
import UIKit

/// Converts between stored team members and Showdown's text format using the loaded database.
enum TeamConversion {
    struct ImportResult {
        var teams: [SavedTeam]
        var warnings: [String]
    }

    /// Builds saved teams from pasted Showdown text. Unknown species are skipped with a warning;
    /// unknown moves, items and abilities are dropped from the set with a warning.
    static func importTeams(from text: String, database: PokedexDatabase) -> ImportResult {
        var warnings: [String] = []
        var teams: [SavedTeam] = []
        let parsed = ShowdownTeamCodec.parseTeams(text)
        for (index, team) in parsed.enumerated() {
            var members: [TeamMember] = []
            for set in team.sets.prefix(SavedTeam.maximumMembers) {
                guard let pokemon = database.pokemon(named: set.species) else {
                    warnings.append("Unknown Pokémon “\(set.species)” was skipped.")
                    continue
                }
                members.append(member(from: set, pokemon: pokemon, database: database, warnings: &warnings))
            }
            guard !members.isEmpty else { continue }
            let name = team.name ?? (parsed.count > 1 ? "Imported Team \(index + 1)" : "Imported Team")
            teams.append(SavedTeam(name: name, format: team.format, members: members))
        }
        if parsed.isEmpty { warnings.append("No Pokémon sets were found in the text.") }
        return ImportResult(teams: teams, warnings: warnings)
    }

    static func member(from set: ShowdownSet, pokemon: Pokemon, database: PokedexDatabase, warnings: inout [String]) -> TeamMember {
        var member = TeamMember(pokemon: pokemon)
        member.nickname = set.nickname == set.species ? nil : set.nickname
        member.gender = set.gender
        member.level = max(1, min(100, set.level))
        member.shiny = set.shiny
        member.evs = clamp(set.evs, max: 252)
        member.ivs = clamp(set.ivs, max: 31)
        if let item = set.item {
            if let resolved = database.item(named: item) { member.itemID = resolved.id }
            else { warnings.append("\(set.species): unknown item “\(item)”.") }
        }
        if let ability = set.ability {
            if let resolved = database.ability(named: ability) { member.abilityID = resolved.id }
            else { warnings.append("\(set.species): unknown ability “\(ability)”.") }
        }
        if let nature = set.nature {
            if let resolved = Nature.named(nature) { member.natureID = resolved.id }
            else { warnings.append("\(set.species): unknown nature “\(nature)”.") }
        }
        if let tera = set.teraType {
            if let type = PokemonType(name: tera) { member.teraType = type }
            else if tera.lowercased() != "stellar" { warnings.append("\(set.species): unknown Tera Type “\(tera)”.") }
        }
        var moves: [String?] = []
        for name in set.moves.prefix(4) {
            if let move = database.move(named: name) { moves.append(move.id) }
            else { warnings.append("\(set.species): unknown move “\(name)”.") }
        }
        while moves.count < 4 { moves.append(nil) }
        member.moveIDs = moves
        return member
    }

    static func showdownSet(for member: TeamMember, database: PokedexDatabase) -> ShowdownSet? {
        guard let pokemon = database.pokemon(id: member.pokemonID) else { return nil }
        var set = ShowdownSet(species: pokemon.name)
        set.nickname = member.nickname?.isEmpty == false ? member.nickname : nil
        set.gender = member.gender
        set.item = member.itemID.flatMap { database.item(id: $0)?.name }
        set.ability = member.abilityID.flatMap { database.ability(id: $0)?.name }
        set.level = member.level
        set.shiny = member.shiny
        set.teraType = member.teraType?.name
        set.evs = member.evs
        set.ivs = member.ivs
        set.nature = Nature.named(member.natureID)?.name
        set.moves = member.chosenMoveIDs.compactMap { database.move(id: $0)?.name }
        return set
    }

    static func exportText(for team: SavedTeam, database: PokedexDatabase, includeHeader: Bool = false) -> String {
        let sets = team.members.compactMap { showdownSet(for: $0, database: database) }
        return ShowdownTeamCodec.export(ShowdownTeam(name: team.name, format: team.format, sets: sets), includeHeader: includeHeader)
    }

    static func exportText(for member: TeamMember, database: PokedexDatabase) -> String {
        showdownSet(for: member, database: database).map(ShowdownTeamCodec.export) ?? ""
    }

    static func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private static func clamp(_ block: StatBlock, max maximum: Int) -> StatBlock {
        var result = block
        for stat in Stat.allCases { result[stat] = Swift.max(0, Swift.min(maximum, block[stat])) }
        return result
    }
}

/// Live stat calculation for a team member.
extension TeamMember {
    func calculatedStats(for pokemon: Pokemon) -> StatBlock {
        StatCalculator.calculateAll(base: pokemon.baseStats, ivs: ivs, evs: evs, level: level,
                                    nature: Nature.named(natureID) ?? .serious)
    }

    var remainingEVs: Int { StatCalculator.maximumTotalEVs - evs.total }
}
