import NeodexKit
import SwiftUI

/// Defensive and offensive analysis for a single type or a type combination.
struct TypeDetailView: View {
    @Environment(\.database) private var database
    var types: [PokemonType]

    private var profile: TypeMatchup.DefensiveProfile { TypeMatchup.defensiveProfile(for: types) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    TypeBadgeRow(types: types, size: .large)
                    Spacer()
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Defense")
                    Text("How much damage a \(types.map(\.name).joined(separator: "/")) Pokémon takes from each attacking type.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    DefensiveProfileView(profile: profile, compact: false)
                }
                .padding(.horizontal)

                if types.count == 1, let type = types.first {
                    let offense = TypeMatchup.offensiveProfile(for: type)
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Offense")
                        Text("How effective \(type.name)-type moves are against each defending type.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        MatchupGroup(title: "Super effective (2×)", types: offense.superEffective, tint: .green)
                        MatchupGroup(title: "Not very effective (½×)", types: offense.notVeryEffective, tint: .orange)
                        MatchupGroup(title: "No effect (0×)", types: offense.noEffect, tint: .gray)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("In the Pokédex")
                        NavigationLink {
                            TypePokemonListView(type: type)
                        } label: {
                            LabeledContent("\(type.name)-type Pokémon", value: database.pokemon(ofType: type).count.formatted())
                                .card()
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            TypeMoveListView(type: type)
                        } label: {
                            LabeledContent("\(type.name)-type moves", value: database.moves(ofType: type).count.formatted())
                                .card()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(types.map(\.name).joined(separator: " / "))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Weaknesses, resistances and immunities, grouped by multiplier.
struct DefensiveProfileView: View {
    var profile: TypeMatchup.DefensiveProfile
    var compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MatchupGroup(title: "Weak (4×)", types: profile.doubleWeaknesses, tint: .red)
            MatchupGroup(title: "Weak (2×)", types: profile.weaknesses, tint: .orange)
            if !compact { MatchupGroup(title: "Neutral (1×)", types: profile.neutral, tint: .secondary) }
            MatchupGroup(title: "Resists (½×)", types: profile.resistances, tint: .green)
            MatchupGroup(title: "Resists (¼×)", types: profile.doubleResistances, tint: .teal)
            MatchupGroup(title: "Immune (0×)", types: profile.immunities, tint: .gray)
        }
    }
}

struct MatchupGroup: View {
    var title: LocalizedStringKey
    var types: [PokemonType]
    var tint: Color

    var body: some View {
        if !types.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
                FlowLayout(spacing: 6) {
                    ForEach(types) { type in
                        NavigationLink(value: AppRoute.type(type)) {
                            TypeBadge(type: type, size: .small)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct TypePokemonListView: View {
    @Environment(\.database) private var database
    var type: PokemonType

    var body: some View {
        List(database.pokemon(ofType: type)) { pokemon in
            NavigationLink(value: AppRoute.pokemon(pokemon.id)) { PokemonRow(pokemon: pokemon) }
        }
        .listStyle(.plain)
        .navigationTitle("\(type.name) Pokémon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TypeMoveListView: View {
    @Environment(\.database) private var database
    var type: PokemonType

    var body: some View {
        List(database.moves(ofType: type).filter { $0.kind == .standard }) { move in
            NavigationLink(value: AppRoute.move(move.id)) { MoveRow(move: move, trailing: move.tmLabel) }
        }
        .listStyle(.plain)
        .navigationTitle("\(type.name) Moves")
        .navigationBarTitleDisplayMode(.inline)
    }
}
