import NeodexKit
import SwiftData
import SwiftUI

/// Neodex's front door: where you left off, every feature, picks based on your browsing, a daily
/// Pokémon, and what's popular on Showdown.
struct HomeView: View {
    @Environment(\.database) private var database
    @Query(sort: \BrowsingRecord.viewedAt, order: .reverse) private var records: [BrowsingRecord]

    @State private var showingSettings = false
    @State private var popular: [Pokemon] = []
    @State private var popularSelection: UsageSelection?
    @State private var shuffled: Pokemon?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !recentItems.isEmpty { jumpBackIn }
                    ForEach(AppTab.Group.allCases) { group in
                        featureSection(group)
                    }
                    if !picks.isEmpty {
                        shelf("Picks for You", subtitle: "Based on what you've been exploring", pokemon: picks)
                    }
                    spotlightSection
                    popularSection
                    footer
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neodex")
            .navigationDestination(for: AppTab.self) { $0.content }
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
            .task { await loadPopular() }
        }
    }

    // MARK: - History

    /// What the user looked at most recently, Pokémon and moves interleaved, newest first.
    private var recentItems: [RecentItem] {
        var seen = Set<String>()
        var items: [RecentItem] = []
        for record in records where seen.insert(record.kind + record.entityID).inserted {
            switch BrowsingRecord.Kind(rawValue: record.kind) {
            case .pokemon:
                if let pokemon = database.pokemon(id: record.entityID) { items.append(.pokemon(pokemon)) }
            case .move:
                if let move = database.move(id: record.entityID) { items.append(.move(move)) }
            default:
                continue
            }
            if items.count == 12 { break }
        }
        return items
    }

    private var recentPokemon: [Pokemon] {
        recentItems.compactMap { if case .pokemon(let pokemon) = $0 { pokemon } else { nil } }
    }

    /// Pokémon sharing types or egg groups with what the user has been reading about.
    private var picks: [Pokemon] {
        let recent = recentPokemon
        guard !recent.isEmpty else { return [] }
        let recentIDs = Set(recent.map(\.speciesID))
        var typeScores: [PokemonType: Int] = [:]
        var eggScores: [String: Int] = [:]
        for pokemon in recent {
            for type in pokemon.types { typeScores[type, default: 0] += 1 }
            for group in pokemon.eggGroups { eggScores[group, default: 0] += 1 }
        }
        let scored = database.species.filter { !recentIDs.contains($0.id) }.map { pokemon -> (Pokemon, Int) in
            let score = pokemon.types.reduce(0) { $0 + (typeScores[$1] ?? 0) * 2 } + pokemon.eggGroups.reduce(0) { $0 + (eggScores[$1] ?? 0) }
            return (pokemon, score)
        }
        .filter { $0.1 > 0 }
        // Deterministic shuffle per day so the shelf changes daily but not on every redraw.
        let day = Self.dayOrdinal
        return scored.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return (lhs.0.nationalDexNumber &* 2654435761 &+ day) % 997 < (rhs.0.nationalDexNumber &* 2654435761 &+ day) % 997
        }
        .prefix(16)
        .map(\.0)
    }

    /// The same Pokémon all day for everyone, until the user shuffles.
    private var spotlight: Pokemon? {
        if let shuffled { return shuffled }
        let species = database.species
        guard !species.isEmpty else { return nil }
        return species[(Self.dayOrdinal &* 7919) % species.count]
    }

    private static var dayOrdinal: Int { Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0 }

    // MARK: - Sections

    private var jumpBackIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Jump Back In").padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentItems) { item in
                        switch item {
                        case .pokemon(let pokemon):
                            NavigationLink(value: AppRoute.pokemon(pokemon.id)) { RecentPokemonCard(pokemon: pokemon) }
                                .buttonStyle(.plain)
                        case .move(let move):
                            NavigationLink(value: AppRoute.move(move.id)) { RecentMoveCard(move: move) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func featureSection(_ group: AppTab.Group) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(LocalizedStringKey(group.title)).padding(.horizontal)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(group.tabs) { tab in
                    NavigationLink(value: tab) {
                        FeatureCard(tab: tab)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func shelf(_ title: LocalizedStringKey, subtitle: String?, pokemon: [Pokemon]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                SectionTitle(title)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(pokemon) { entry in
                        NavigationLink(value: AppRoute.pokemon(entry.id)) { PokemonShelfCard(pokemon: entry) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var spotlightSection: some View {
        if let spotlight {
            NavigationLink(value: AppRoute.pokemon(spotlight.id)) {
                HStack(spacing: 14) {
                    PokemonImage(pokemon: spotlight, kind: .artwork).frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shuffled == nil ? "Pokémon of the Day" : "Random Pokémon")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text(spotlight.displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        TypeBadgeRow(types: spotlight.types, size: .small)
                    }
                    Spacer()
                    Button("Shuffle", systemImage: "shuffle") { shuffled = database.species.randomElement() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                }
                .padding()
                .background(spotlight.primaryType.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var popularSection: some View {
        if !popular.isEmpty, let popularSelection {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionTitle("Popular on Showdown")
                    Text("\(UsageFormat.displayName(for: popularSelection.format)) · \(UsageStatsModel.displayMonth(popularSelection.month))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(popular.enumerated()), id: \.element.id) { index, entry in
                            NavigationLink(value: AppRoute.usageDetail(popularSelection, name: entry.name)) {
                                PokemonShelfCard(pokemon: entry, badge: "#\(index + 1)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var footer: some View {
        NavigationLink {
            AboutView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("About Neodex").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("Dataset \(database.manifest?.displayVersion ?? "—") · \(database.pokemon.count.formatted()) Pokémon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func loadPopular() async {
        guard popular.isEmpty else { return }
        do {
            let client = SmogonStatsClient.shared
            guard let month = try await client.months().first else { return }
            let formats = try await client.formats(for: month)
            guard let format = formats.first(where: { $0.id == "gen9ou" }) ?? formats.first else { return }
            let selection = UsageSelection(month: month, format: format.id, rating: UsageStatsModel.defaultRating(for: format))
            let report = try await client.rankings(for: selection)
            popular = report.rankings.prefix(12).compactMap { database.pokemon(named: $0.name) }
            popularSelection = selection
        } catch {
            // Popular picks are a bonus; stay quiet when offline.
        }
    }
}

/// A recently viewed Pokémon or move.
enum RecentItem: Identifiable {
    case pokemon(Pokemon)
    case move(Move)

    var id: String {
        switch self {
        case .pokemon(let pokemon): "pokemon:\(pokemon.id)"
        case .move(let move): "move:\(move.id)"
        }
    }
}

/// A feature card on Home.
struct FeatureCard: View {
    var tab: AppTab

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: tab.systemImage)
                .font(.title3)
                .foregroundStyle(tab.tint)
                .frame(width: 38, height: 38)
                .background(tab.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.cardTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(tab.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A compact Pokémon card for horizontal shelves.
struct PokemonShelfCard: View {
    var pokemon: Pokemon
    var badge: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            PokemonImage(pokemon: pokemon, kind: .thumbnail).frame(width: 84, height: 84)
            Text(pokemon.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 110)
            TypeBadgeRow(types: pokemon.types, size: .small)
        }
        .padding(10)
        .frame(width: 130)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            if let badge {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(6)
            }
        }
    }
}

/// A small recently-viewed Pokémon tile.
struct RecentPokemonCard: View {
    var pokemon: Pokemon

    var body: some View {
        HStack(spacing: 8) {
            PokemonImage(pokemon: pokemon, kind: .sprite).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(pokemon.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                TypeBadgeRow(types: pokemon.types, size: .small)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A small recently-viewed move tile.
struct RecentMoveCard: View {
    var move: Move

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: move.category.systemImage)
                .foregroundStyle(move.category.color)
                .frame(width: 44, height: 44)
                .background(move.type.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(move.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                TypeBadge(type: move.type, size: .small)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#if DEBUG
#Preview { HomeView().previewEnvironment() }
#endif
