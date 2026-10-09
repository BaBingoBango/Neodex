import NeodexKit
import SwiftUI

/// The feature gallery: Neodex's front door.
struct HomeView: View {
    @Environment(\.database) private var database
    @State private var showingSettings = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Feature.allCases) { feature in
                        NavigationLink(value: feature) {
                            FeatureCard(feature: feature)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neodex")
            .navigationDestination(for: Feature.self) { $0.destination }
            .appDestinations()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

/// Every feature reachable from Home.
enum Feature: String, CaseIterable, Identifiable, Hashable {
    case pokedex, moves, abilities, items, types, natures, teambuilder, faceOff, damageCalc, usageStats, explore, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pokedex: "Pokédex"
        case .moves: "Move Dex"
        case .abilities: "Ability Dex"
        case .items: "Item Dex"
        case .types: "Type-O-Matic"
        case .natures: "Natures"
        case .teambuilder: "Teambuilder"
        case .faceOff: "Face-Off"
        case .damageCalc: "Damage Calculator"
        case .usageStats: "Global Stats"
        case .explore: "Explore"
        case .about: "About"
        }
    }

    var subtitle: String {
        switch self {
        case .pokedex: "Every species and form"
        case .moves: "Power, accuracy, learners"
        case .abilities: "What each Ability does"
        case .items: "Held items and more"
        case .types: "Weaknesses and resistances"
        case .natures: "All 25 natures"
        case .teambuilder: "Build and share Showdown teams"
        case .faceOff: "Compare two Pokémon"
        case .damageCalc: "Showdown-style damage calcs"
        case .usageStats: "Smogon usage statistics"
        case .explore: "Picks based on your browsing"
        case .about: "Data sources and credits"
        }
    }

    var systemImage: String {
        switch self {
        case .pokedex: "person.fill"
        case .moves: "burst.fill"
        case .abilities: "sparkles"
        case .items: "cube.fill"
        case .types: "circle.grid.cross.fill"
        case .natures: "leaf.fill"
        case .teambuilder: "rectangle.stack.person.crop.fill"
        case .faceOff: "bolt.circle.fill"
        case .damageCalc: "function"
        case .usageStats: "network"
        case .explore: "wand.and.stars"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pokedex: .blue
        case .moves: .red
        case .abilities: .gold
        case .items: PokemonType.flying.color
        case .types: PokemonType.psychic.color
        case .natures: .green
        case .teambuilder: PokemonType.ice.color
        case .faceOff: PokemonType.dragon.color
        case .damageCalc: PokemonType.fire.color
        case .usageStats: .blue
        case .explore: .bronze
        case .about: .gray
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .pokedex: PokedexListContent()
        case .moves: MoveListContent()
        case .abilities: AbilityListView()
        case .items: ItemListView()
        case .types: TypeMatchupView()
        case .natures: NatureListView()
        case .teambuilder: TeamsContent()
        case .faceOff: FaceOffView()
        case .damageCalc: DamageCalculatorView()
        case .usageStats: UsageStatsView()
        case .explore: ExploreView()
        case .about: AboutView()
        }
    }
}

struct FeatureCard: View {
    var feature: Feature

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: feature.systemImage)
                .font(.title)
                .foregroundStyle(feature.tint)
                .frame(width: 44, height: 44)
                .background(feature.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview { HomeView().previewEnvironment() }
#endif
