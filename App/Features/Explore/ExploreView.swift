import NeodexKit
import SwiftData
import SwiftUI

/// Explore: recent history, personalised picks and what's popular on Showdown.
struct ExploreView: View {
    @Environment(\.database) private var database
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrowsingRecord.viewedAt, order: .reverse) private var records: [BrowsingRecord]

    @State private var popular: [Pokemon] = []
    @State private var popularSelection: UsageSelection?
    @State private var randomPick: Pokemon?

    private var recentPokemon: [Pokemon] {
        var seen = Set<String>()
        return records.filter { $0.kind == BrowsingRecord.Kind.pokemon.rawValue && seen.insert($0.entityID).inserted }
            .prefix(20)
            .compactMap { database.pokemon(id: $0.entityID) }
    }

    private var recentMoves: [Move] {
        var seen = Set<String>()
        return records.filter { $0.kind == BrowsingRecord.Kind.move.rawValue && seen.insert($0.entityID).inserted }
            .prefix(12)
            .compactMap { database.move(id: $0.entityID) }
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
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return scored.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return (lhs.0.nationalDexNumber &* 2654435761 &+ day) % 997 < (rhs.0.nationalDexNumber &* 2654435761 &+ day) % 997
        }
        .prefix(16)
        .map(\.0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                randomSection
                if !picks.isEmpty { shelf("Picks for You", subtitle: "Based on what you've been exploring", pokemon: picks) }
                if !recentPokemon.isEmpty { shelf("Recently Viewed", subtitle: nil, pokemon: recentPokemon) }
                if !recentMoves.isEmpty { movesShelf }
                popularSection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Explore")
        .task { await loadPopular() }
        .onAppear { if randomPick == nil { randomPick = database.species.randomElement() } }
    }

    private var randomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let randomPick {
                NavigationLink(value: AppRoute.pokemon(randomPick.id)) {
                    HStack(spacing: 14) {
                        PokemonImage(pokemon: randomPick, kind: .artwork).frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Random Pokémon").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
                            Text(randomPick.displayName).font(.title2.weight(.bold)).foregroundStyle(.primary)
                            TypeBadgeRow(types: randomPick.types, size: .small)
                        }
                        Spacer()
                        Button("Shuffle", systemImage: "shuffle") { self.randomPick = database.species.randomElement() }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(randomPick.primaryType.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func shelf(_ title: LocalizedStringKey, subtitle: String?, pokemon: [Pokemon]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                SectionTitle(title)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(pokemon) { entry in
                        NavigationLink(value: AppRoute.pokemon(entry.id)) { ExploreCard(pokemon: entry) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var movesShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Recent Moves").padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentMoves) { move in
                        NavigationLink(value: AppRoute.move(move.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                TypeBadge(type: move.type, size: .small)
                                Text(move.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                                Text("\(move.basePowerText) · \(move.accuracyText)").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(width: 140, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var popularSection: some View {
        if !popular.isEmpty, let popularSelection {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionTitle("Popular on Showdown")
                    Text("\(UsageFormat.displayName(for: popularSelection.format)) · \(UsageStatsModel.displayMonth(popularSelection.month))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(popular.enumerated()), id: \.element.id) { index, entry in
                            NavigationLink(value: AppRoute.usageDetail(popularSelection, name: entry.name)) {
                                ExploreCard(pokemon: entry, badge: "#\(index + 1)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
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

struct ExploreCard: View {
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
                Text(badge).font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.tint, in: Capsule()).foregroundStyle(.white).padding(6)
            }
        }
    }
}

#if DEBUG
#Preview { PreviewHost { ExploreView() } }
#endif
