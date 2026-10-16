import NeodexKit
import SwiftData
import SwiftUI

/// Neodex's front door: where you left off, every feature, picks based on your browsing, a daily
/// Pokémon, and what's popular on Showdown.
struct HomeView: View {
    @Environment(\.database) private var database
    @Query(sort: \BrowsingRecord.viewedAt, order: .reverse) private var records: [BrowsingRecord]

    @AppStorage("popularFormat") private var popularFormat = "gen9ou"
    @State private var showingSettings = false
    @State private var popular: [Pokemon] = []
    @State private var popularSelection: UsageSelection?
    @State private var popularFormats: [UsageFormat] = []
    @State private var choosingPopularFormat = false
    @State private var shuffled: Pokemon?
    @State private var explainer = PickExplainer.shared

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 10)]

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
                        explainedPicks
                    }
                    spotlightSection
                    popularSection
                    footer
                }
                .padding(.vertical)
            }
            .background {
                ZStack(alignment: .top) {
                    Color(.systemGroupedBackground)
                    AmbientBackground(colors: ambientColors)
                        .frame(height: 440)
                }
                .ignoresSafeArea()
            }
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
            .sheet(isPresented: $choosingPopularFormat) {
                UsageFormatPicker(formats: popularFormats, selected: popularFormat) { format in
                    popularFormat = format.id
                }
            }
            .task(id: popularFormat) { await loadPopular() }
            .task(id: picks.prefix(3).map(\.id).joined()) {
                await explainer.explain(picks: picks, basedOn: recentPokemon)
            }
        }
    }

    /// Apple Intelligence's one-line reasons for the first picks, when the on-device model is available.
    @ViewBuilder
    private var explainedPicks: some View {
        let blurbs = explainer.blurbs.filter { blurb in picks.contains { $0.id == blurb.pokemonID } }
        if !blurbs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Why these picks", systemImage: "apple.intelligence")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(blurbs) { blurb in
                    if let pokemon = database.pokemon(id: blurb.pokemonID) {
                        NavigationLink(value: AppRoute.pokemon(pokemon.id)) {
                            HStack(alignment: .top, spacing: 10) {
                                PokemonImage(pokemon: pokemon, kind: .sprite).frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pokemon.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(blurb.text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Written on your device by Apple Intelligence from this Pokémon's types and egg groups.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.4), .orange.opacity(0.4)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .padding(.horizontal)
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

    /// The wash behind the top of Home takes its colours from the Pokémon of the Day.
    private var ambientColors: [Color] {
        guard let spotlight else { return [.accentColor, .purple] }
        return [spotlight.primaryType.color, (spotlight.secondaryType ?? spotlight.primaryType).color, .accentColor]
    }

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
                                .shelfTransition()
                        case .move(let move):
                            NavigationLink(value: AppRoute.move(move.id)) { RecentMoveCard(move: move) }
                                .buttonStyle(.plain)
                                .shelfTransition()
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
            LazyVGrid(columns: columns, spacing: 10) {
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
                            .shelfTransition()
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
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionTitle("Popular on Showdown")
                        Text("\(UsageFormat.displayName(for: popularSelection.format)) · \(UsageStatsModel.displayMonth(popularSelection.month))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        choosingPopularFormat = true
                    } label: {
                        Label("Format", systemImage: "chevron.up.chevron.down")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(popularFormats.isEmpty)
                }
                .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(popular.enumerated()), id: \.element.id) { index, entry in
                            NavigationLink(value: AppRoute.usageDetail(popularSelection, name: entry.name)) {
                                PokemonShelfCard(pokemon: entry, badge: "#\(index + 1)")
                            }
                            .buttonStyle(.plain)
                            .shelfTransition()
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
        if let popularSelection, popularSelection.format == popularFormat, !popular.isEmpty { return }
        do {
            let client = SmogonStatsClient.shared
            guard let month = try await client.months().first else { return }
            let formats = try await client.formats(for: month)
            popularFormats = formats
            guard let format = formats.first(where: { $0.id == popularFormat }) ?? formats.first(where: { $0.id == "gen9ou" }) ?? formats.first else { return }
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

/// A feature card on Home: compact, so the grid leaves room for what's below it.
struct FeatureCard: View {
    var tab: AppTab

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tab.tint)
                .frame(width: 36, height: 36)
                .background(tab.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(tab.cardTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(tab.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
