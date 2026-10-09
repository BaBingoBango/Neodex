import NeodexKit
import SwiftUI

/// Face-Off: pick two Pokémon and compare them side by side.
struct FaceOffView: View {
    @Environment(\.database) private var database
    @State private var left: Pokemon?
    @State private var right: Pokemon?
    @State private var picking: Side?

    enum Side: Identifiable { case left, right; var id: Self { self } }

    init(initial: Pokemon? = nil) {
        _left = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    slot(left, side: .left)
                    slot(right, side: .right)
                }
                .padding(.horizontal)

                if let left, let right {
                    comparison(left, right)
                } else {
                    ContentUnavailableView("Choose Two Pokémon", systemImage: "bolt.circle",
                                           description: Text("Tap a slot to pick a Pokémon and compare stats, types and more."))
                        .padding(.top, 40)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Face-Off")
        .sheet(item: $picking) { side in
            PokemonPickerSheet(title: side == .left ? "First Pokémon" : "Second Pokémon") { pokemon in
                if side == .left { left = pokemon } else { right = pokemon }
            }
        }
        .toolbar {
            if left != nil || right != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Swap", systemImage: "arrow.left.arrow.right") { swap(&left, &right) }
                }
            }
        }
    }

    private func slot(_ pokemon: Pokemon?, side: Side) -> some View {
        Button {
            picking = side
        } label: {
            VStack(spacing: 8) {
                if let pokemon {
                    PokemonImage(pokemon: pokemon, kind: .artwork)
                        .frame(height: 120)
                    Text(pokemon.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    TypeBadgeRow(types: pokemon.types, size: .small)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .frame(height: 120)
                    Text("Choose")
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 210)
            .padding(12)
            .background((pokemon?.primaryType.color ?? .gray).opacity(pokemon == nil ? 0.08 : 0.18),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if pokemon != nil {
                Button {
                    if side == .left { left = nil } else { right = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .accessibilityLabel("Clear")
            }
        }
    }

    private func comparison(_ left: Pokemon, _ right: Pokemon) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Base Stats")
                ForEach(Stat.allCases) { stat in
                    ComparisonBar(label: stat.shortName, left: left.baseStats[stat], right: right.baseStats[stat],
                                  leftColor: left.primaryType.color, rightColor: right.primaryType.color, maximum: 255)
                }
                ComparisonBar(label: "Total", left: left.baseStats.total, right: right.baseStats.total,
                              leftColor: left.primaryType.color, rightColor: right.primaryType.color, maximum: 780)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Type Matchup")
                matchupRow(attacker: left, defender: right)
                matchupRow(attacker: right, defender: left)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Details")
                detailRow("Height", Measurements.height(left.height), Measurements.height(right.height))
                detailRow("Weight", Measurements.weight(left.weight), Measurements.weight(right.weight))
                detailRow("Abilities", left.abilities.all.compactMap { database.ability(id: $0)?.name }.joined(separator: ", "),
                          right.abilities.all.compactMap { database.ability(id: $0)?.name }.joined(separator: ", "))
                detailRow("Catch rate", left.catchRate.map(String.init) ?? "—", right.catchRate.map(String.init) ?? "—")
                detailRow("Generation", "Gen \(left.generation)", "Gen \(right.generation)")
                detailRow("Tier", left.tier ?? "—", right.tier ?? "—")
            }
            .padding(.horizontal)

            HStack {
                NavigationLink(value: AppRoute.pokemon(left.id)) { Label(left.displayName, systemImage: "book") }
                Spacer()
                NavigationLink(value: AppRoute.pokemon(right.id)) { Label(right.displayName, systemImage: "book") }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal)

            NavigationLink(value: AppRoute.damageCalculator(attacker: left.id, defender: right.id)) {
                Label("Run a Damage Calc", systemImage: "function")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    private func matchupRow(attacker: Pokemon, defender: Pokemon) -> some View {
        let best = attacker.types.map { ($0, $0.multiplier(against: defender.types)) }.max { $0.1 < $1.1 }
        return HStack {
            Text("\(attacker.displayName) → \(defender.displayName)")
                .font(.subheadline)
            Spacer()
            if let best {
                TypeBadge(type: best.0, size: .small)
                Text("×\(best.1.formatted(.number.precision(.fractionLength(0...2))))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(best.1 > 1 ? .green : best.1 < 1 ? .red : .primary)
                    .monospacedDigit()
            }
        }
        .card()
    }

    private func detailRow(_ label: String, _ leftValue: String, _ rightValue: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
            HStack(alignment: .top) {
                Text(leftValue).frame(maxWidth: .infinity, alignment: .leading)
                Text(rightValue).frame(maxWidth: .infinity, alignment: .trailing).multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
        }
        .card()
    }
}

/// Two bars growing from the centre, like the original Face-Off comparison.
struct ComparisonBar: View {
    var label: String
    var left: Int
    var right: Int
    var leftColor: Color
    var rightColor: Color
    var maximum: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(left)").font(.subheadline.weight(left >= right ? .bold : .regular)).monospacedDigit()
                Spacer()
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(right)").font(.subheadline.weight(right >= left ? .bold : .regular)).monospacedDigit()
            }
            GeometryReader { geometry in
                let half = geometry.size.width / 2
                ZStack {
                    HStack(spacing: 2) {
                        HStack {
                            Spacer(minLength: 0)
                            Capsule().fill(leftColor).frame(width: max(4, half * CGFloat(left) / CGFloat(maximum)))
                        }
                        .frame(width: half)
                        HStack {
                            Capsule().fill(rightColor).frame(width: max(4, half * CGFloat(right) / CGFloat(maximum)))
                            Spacer(minLength: 0)
                        }
                        .frame(width: half)
                    }
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(left) versus \(right)")
    }
}

#if DEBUG
#Preview { PreviewHost { FaceOffView(initial: PokedexDatabase.preview.previewPokemon("Charizard")) } }
#endif
