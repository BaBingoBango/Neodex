import NeodexKit
import SwiftUI

/// A Pokédex entry sized for the wrist: picture, types, entry text, stats, abilities, matchups and
/// evolutions, each a short scroll away.
struct WatchPokemonDetailView: View {
    var pokemon: Pokemon
    var database: PokedexDatabase

    private var profile: TypeMatchup.DefensiveProfile { TypeMatchup.defensiveProfile(for: pokemon.types) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let entry = pokemon.dexEntries.first {
                    Text(entry.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                stats
                abilities
                matchups
                evolutions
                forms
                Text(String(format: "%.1f m · %.1f kg", pokemon.height, pokemon.weight))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(pokemon.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 6) {
            WatchPokemonImage(pokemon: pokemon)
                .frame(height: 90)
                .frame(maxWidth: .infinity)
            Text("#\(String(format: "%04d", pokemon.nationalDexNumber))" + (pokemon.genus.map { " · \($0)" } ?? ""))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                ForEach(pokemon.types, id: \.self) { TypeBadge(type: $0, size: .small) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 6) {
            title("Base Stats · \(pokemon.baseStats.total)")
            ForEach(pokemon.baseStats.values, id: \.stat) { entry in
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Text(entry.stat.shortName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text("\(entry.value)")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                    }
                    .lineLimit(1)
                    Gauge(value: Double(entry.value), in: 0...255) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(statColor(entry.value))
                }
            }
        }
    }

    private var abilities: some View {
        VStack(alignment: .leading, spacing: 6) {
            title("Abilities")
            abilityLink(pokemon.abilities.primary, hidden: false)
            if let secondary = pokemon.abilities.secondary { abilityLink(secondary, hidden: false) }
            if let hidden = pokemon.abilities.hidden { abilityLink(hidden, hidden: true) }
        }
    }

    @ViewBuilder
    private func abilityLink(_ id: String, hidden: Bool) -> some View {
        if let ability = database.ability(id: id) {
            NavigationLink(value: WatchRoute.ability(ability.id)) {
                HStack {
                    Text(ability.name).font(.footnote)
                    if hidden {
                        Text("Hidden")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var matchups: some View {
        VStack(alignment: .leading, spacing: 8) {
            typeGroup("Weak to", strong: profile.doubleWeaknesses, strongLabel: "×4", normal: profile.weaknesses)
            typeGroup("Resists", strong: profile.doubleResistances, strongLabel: "×¼", normal: profile.resistances)
            if !profile.immunities.isEmpty {
                typeGroup("Immune to", strong: [], strongLabel: "", normal: profile.immunities)
            }
        }
    }

    @ViewBuilder
    private func typeGroup(_ heading: LocalizedStringKey, strong: [PokemonType], strongLabel: String, normal: [PokemonType]) -> some View {
        if !strong.isEmpty || !normal.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                title(heading)
                TypeChips(types: strong + normal, emphasised: Set(strong), label: strongLabel)
            }
        }
    }

    @ViewBuilder
    private var evolutions: some View {
        let from = pokemon.evolvesFrom.flatMap(database.pokemon(id:))
        if from != nil || !pokemon.evolutions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                title("Evolution")
                if let from {
                    link(to: from, caption: "Evolves from")
                }
                ForEach(pokemon.evolutions, id: \.to) { evolution in
                    if let target = database.pokemon(id: evolution.to) {
                        link(to: target, caption: evolutionCaption(evolution))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var forms: some View {
        let others = pokemon.otherFormIDs.compactMap(database.pokemon(id:))
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                title("Forms")
                ForEach(others) { form in link(to: form, caption: form.formName ?? "Form") }
            }
        }
    }

    private func link(to target: Pokemon, caption: String) -> some View {
        NavigationLink(value: WatchRoute.pokemon(target.id)) {
            HStack(spacing: 8) {
                WatchPokemonImage(pokemon: target).frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(target.displayName).font(.footnote).lineLimit(1).minimumScaleFactor(0.8)
                    Text(caption).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .padding(6)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func evolutionCaption(_ evolution: Evolution) -> String {
        if let level = evolution.level { return "Level \(level)" }
        if let item = evolution.item, let name = database.item(id: item)?.name { return name }
        return evolution.kind.map { $0.replacingOccurrences(of: "-", with: " ").capitalized } ?? "Evolves"
    }

    private func title(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func statColor(_ value: Int) -> Color {
        switch value {
        case ..<50: .red
        case ..<80: .orange
        case ..<110: .yellow
        case ..<140: .green
        default: .teal
        }
    }
}

/// Type pills that wrap onto as many lines as the small screen needs.
struct TypeChips: View {
    var types: [PokemonType]
    var emphasised: Set<PokemonType> = []
    var label = ""

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 4, alignment: .leading)], alignment: .leading, spacing: 4) {
            ForEach(types, id: \.self) { type in
                HStack(spacing: 2) {
                    TypeBadge(type: type, size: .small)
                    if emphasised.contains(type), !label.isEmpty {
                        Text(label).font(.caption2.weight(.bold))
                    }
                }
            }
        }
    }
}

/// An Ability's description.
struct WatchAbilityView: View {
    var ability: Ability

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(ability.description ?? ability.shortDescription ?? "No description.")
                    .font(.footnote)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(ability.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
