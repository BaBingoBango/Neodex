import NeodexKit
import SwiftUI

/// Type-O-Matic for the wrist: pick one or two types and read what they're weak to and resist.
struct WatchTypeMatchupView: View {
    @State private var first: PokemonType = .fire
    @State private var second: PokemonType?

    private var types: [PokemonType] { [first] + (second.map { [$0] } ?? []) }
    private var profile: TypeMatchup.DefensiveProfile { TypeMatchup.defensiveProfile(for: types) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("First type", selection: $first) {
                    ForEach(PokemonType.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: first) { _, newValue in if second == newValue { second = nil } }
                Picker("Second type", selection: $second) {
                    Text("None").tag(PokemonType?.none)
                    ForEach(PokemonType.allCases.filter { $0 != first }, id: \.self) { Text($0.name).tag(PokemonType?.some($0)) }
                }
                .pickerStyle(.navigationLink)
                HStack(spacing: 4) {
                    ForEach(types, id: \.self) { TypeBadge(type: $0, size: .small) }
                }
                group("Weak to", strong: profile.doubleWeaknesses, label: "×4", normal: profile.weaknesses)
                group("Resists", strong: profile.doubleResistances, label: "×¼", normal: profile.resistances)
                if !profile.immunities.isEmpty {
                    group("Immune to", strong: [], label: "", normal: profile.immunities)
                }
                if profile.weaknesses.isEmpty, profile.doubleWeaknesses.isEmpty {
                    Text("No weaknesses.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Type-O-Matic")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button {
                    guard let other = second else { return }
                    withAnimation(.snappy) { (first, second) = (other, first) }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .disabled(second == nil)
                .accessibilityLabel("Swap types")
            }
        }
        .containerBackground(WatchTheme.background(types), for: .navigation)
    }

    @ViewBuilder
    private func group(_ heading: LocalizedStringKey, strong: [PokemonType], label: String, normal: [PokemonType]) -> some View {
        if !strong.isEmpty || !normal.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(heading)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                TypeChips(types: strong + normal, emphasised: Set(strong), label: label)
            }
        }
    }
}
