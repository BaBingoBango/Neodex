import NeodexKit
import SwiftUI

/// Your Teambuilder teams, as the iPhone last sent them. Nothing to configure: build a team on the
/// phone and it appears here.
struct WatchTeamsView: View {
    var database: PokedexDatabase
    @Environment(PhoneLink.self) private var link

    var body: some View {
        Group {
            if link.teams.isEmpty {
                ContentUnavailableView {
                    Label("No Teams Yet", systemImage: "rectangle.stack.person.crop")
                } description: {
                    Text(link.isCompanionInstalled
                         ? "Build a team in Neodex on your iPhone and it appears here on its own."
                         : "Install Neodex on your iPhone to see your teams here.")
                }
            } else {
                List(link.teams) { team in
                    NavigationLink(value: WatchRoute.team(team.id)) {
                        WatchTeamRow(team: team, database: database)
                    }
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("Teams")
        .containerBackground(WatchTheme.teams, for: .navigation)
        .watchDestinations(database: database)
    }
}

/// A team's name and its six sprites in a row, like the Teambuilder's list.
struct WatchTeamRow: View {
    var team: WatchTeamSnapshot.Team
    var database: PokedexDatabase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(team.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 2) {
                ForEach(team.members) { member in
                    if let pokemon = database.pokemon(id: member.pokemonID) {
                        WatchPokemonImage(pokemon: pokemon)
                            .frame(width: 24, height: 24)
                    }
                }
                Spacer(minLength: 0)
            }
            if let format = team.format, !format.isEmpty {
                Text(format)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// One team, member by member: the set as the Teambuilder saved it, each a tap away from its Pokédex entry.
struct WatchTeamDetailView: View {
    var team: WatchTeamSnapshot.Team
    var database: PokedexDatabase

    private var leadTypes: [PokemonType] {
        team.members.first.flatMap { database.pokemon(id: $0.pokemonID) }?.types ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let format = team.format, !format.isEmpty {
                    Text(format)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(team.members) { member in
                    if let pokemon = database.pokemon(id: member.pokemonID) {
                        NavigationLink(value: WatchRoute.pokemon(pokemon.id)) {
                            WatchTeamMemberCard(member: member, pokemon: pokemon, database: database)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Updated \(team.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(WatchTheme.background(leadTypes), for: .navigation)
    }
}

/// A set on a card: sprite, name, item and ability, the moves, and the nature and spread.
struct WatchTeamMemberCard: View {
    var member: TeamMember
    var pokemon: Pokemon
    var database: PokedexDatabase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                WatchPokemonImage(pokemon: pokemon)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.nickname?.isEmpty == false ? "\(member.nickname!) (\(pokemon.displayName))" : pokemon.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        ForEach(pokemon.types, id: \.self) { TypeBadge(type: $0, size: .small) }
                    }
                    .fixedSize()
                }
                Spacer(minLength: 0)
            }
            Text(setLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !member.chosenMoveIDs.isEmpty {
                Text(member.chosenMoveIDs.compactMap { database.move(id: $0)?.name }.joined(separator: " · "))
                    .font(.footnote)
                    .lineLimit(3)
            }
            Text(spreadLine)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .watchCard()
    }

    /// "Leftovers · Rough Skin · Tera Steel", or whichever parts are set.
    private var setLine: String {
        let item = member.itemID.flatMap { database.item(id: $0)?.name }
        let ability = member.abilityID.flatMap { database.ability(id: $0)?.name }
        let tera = member.teraType.map { "Tera \($0.name)" }
        let parts = [item, ability, tera].compactMap(\.self)
        return parts.isEmpty ? "No item or ability set" : parts.joined(separator: " · ")
    }

    /// "Jolly · 252 Atk / 4 SpD / 252 Spe"
    private var spreadLine: String {
        let nature = database.nature(id: member.natureID)?.name ?? "Serious"
        let evs = member.evs
        let spread = [("HP", evs.hp), ("Atk", evs.attack), ("Def", evs.defense), ("SpA", evs.specialAttack), ("SpD", evs.specialDefense), ("Spe", evs.speed)]
            .filter { $0.1 > 0 }
            .map { "\($0.1) \($0.0)" }
        return spread.isEmpty ? nature : nature + " · " + spread.joined(separator: " / ")
    }
}
