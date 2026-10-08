import NeodexKit
import SwiftUI

/// Type-O-Matic: pick one or two types and see the full defensive profile.
struct TypeMatchupView: View {
    @State private var selected: [PokemonType] = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selected.isEmpty ? "Choose up to two types" : selected.map(\.name).joined(separator: " / "))
                        .font(.title2.weight(.bold))
                    Text("Tap types to combine them and see what a Pokémon with that typing is weak to and resists.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(PokemonType.allCases) { type in
                        Button {
                            toggle(type)
                        } label: {
                            HStack(spacing: 4) {
                                if selected.contains(type) {
                                    Image(systemName: "checkmark.circle.fill").font(.caption)
                                }
                                Text(type.name.uppercased())
                                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(type.contrastingTextColor)
                            .background(type.color.opacity(selected.isEmpty || selected.contains(type) ? 1 : 0.35),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(type.name)
                        .accessibilityAddTraits(selected.contains(type) ? .isSelected : [])
                    }
                }
                .padding(.horizontal)

                if !selected.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionTitle("Defense")
                            NavigationLink(value: AppRoute.typeMatchup(selected)) {
                                Label("Details", systemImage: "chevron.right").font(.subheadline.weight(.semibold))
                            }
                        }
                        DefensiveProfileView(profile: TypeMatchup.defensiveProfile(for: selected), compact: false)
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                }
            }
            .padding(.vertical)
        }
        .animation(.default, value: selected)
        .navigationTitle("Type-O-Matic")
        .toolbar {
            if !selected.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { selected.removeAll() }
                }
            }
        }
    }

    private func toggle(_ type: PokemonType) {
        if let index = selected.firstIndex(of: type) {
            selected.remove(at: index)
        } else if selected.count < 2 {
            selected.append(type)
        } else {
            selected[1] = type
        }
    }
}

#if DEBUG
#Preview { PreviewHost { TypeMatchupView() } }
#endif
