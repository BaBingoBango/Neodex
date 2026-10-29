import NeodexKit
import os
import SwiftUI

/// Global Stats: Smogon usage rankings for any format and month.
struct UsageStatsView: View {
    @Environment(\.database) private var database
    @State private var model = UsageStatsModel.shared
    @State private var searchText = ""
    @State private var showingFormats = false

    private var rows: [UsageRanking] {
        guard let report = model.report else { return [] }
        let query = SearchNormalizer.normalize(searchText)
        guard !query.isEmpty else { return report.rankings }
        return report.rankings.filter { SearchNormalizer.normalize($0.name).contains(query) }
    }

    var body: some View {
        List {
            // The chips scroll with the rankings. Held in a bar above the list instead, they changed
            // the list's insets whenever the search field collapsed, and the two fed back into a jitter.
            selectionBar
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            if let report = model.report, let selection = model.selection {
                Section {
                    ForEach(rows) { ranking in
                        NavigationLink(value: AppRoute.usageDetail(selection, name: ranking.name)) {
                            UsageRankingRow(ranking: ranking, pokemon: database.pokemon(named: ranking.name))
                        }
                    }
                } header: {
                    if let battles = report.totalBattles {
                        Text("\(battles.formatted()) battles · \(report.rankings.count) Pokémon")
                    }
                }
            }
        }
        .listStyle(.plain)
        .pullToRefresh { await model.refresh() }
        .searchable(text: $searchText, prompt: "Filter Pokémon")
        .navigationTitle("Global Stats")
        .inlineNavigationTitle()
        .toolbar {
            #if os(macOS)
            // The Mac has no pull to refresh.
            ToolbarItem(placement: .trailingBar) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.isLoading)
            }
            #endif
        }
        .overlay { stateOverlay }
        .task { await model.loadIfNeeded() }
        .sheet(isPresented: $showingFormats) {
            UsageFormatPicker(formats: model.formats, selected: model.selection?.format, month: model.selection?.month) { format in
                Task { await model.select(format: format) }
            }
        }
    }

    @ViewBuilder
    private var selectionBar: some View {
        if let selection = model.selection {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(model.months, id: \.self) { month in
                            Button(UsageStatsModel.displayMonth(month)) { Task { await model.select(month: month) } }
                        }
                    } label: {
                        chip(UsageStatsModel.displayMonth(selection.month), systemImage: "calendar")
                    }
                    FavoriteFormatMenu(formats: model.formats, selected: selection.format, month: selection.month,
                                       onPick: { format in Task { await model.select(format: format) } },
                                       onShowAll: { showingFormats = true }) {
                        chip(UsageFormat.displayName(for: selection.format), systemImage: "trophy")
                    }
                    Menu {
                        ForEach(model.currentFormat?.ratingCutoffs ?? [selection.rating], id: \.self) { rating in
                            Button(rating == 0 ? "All ratings" : "\(rating)+") { Task { await model.select(rating: rating) } }
                        }
                    } label: {
                        chip(selection.rating == 0 ? "All ratings" : "Rating \(selection.rating)+", systemImage: "chart.bar")
                    }
                }
                .chipControls()
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.tint.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var stateOverlay: some View {
        if model.isLoading, model.report == nil {
            ProgressView("Loading usage statistics…")
        } else if let error = model.error, model.report == nil {
            ContentUnavailableView {
                Label("Couldn't Load Statistics", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try Again") { Task { await model.reload() } }
                    .buttonStyle(.borderedProminent)
            }
        } else if model.report != nil, rows.isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

struct UsageRankingRow: View {
    var ranking: UsageRanking
    var pokemon: Pokemon?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(ranking.rank)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(rankColor)
                .frame(width: 34, alignment: .trailing)
            if let pokemon {
                PokemonImage(pokemon: pokemon, kind: .sprite).frame(width: 44, height: 44)
            } else {
                Image(systemName: "questionmark.circle").frame(width: 44, height: 44).foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pokemon?.displayName ?? ranking.name).font(.body.weight(.medium))
                if let pokemon { TypeBadgeRow(types: pokemon.types, size: .small) }
            }
            Spacer()
            Text(ranking.usagePercent.formatted(.number.precision(.fractionLength(2))) + "%")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var rankColor: Color {
        switch ranking.rank {
        case 1: .gold
        case 2: .silver
        case 3: .bronze
        default: .secondary
        }
    }
}

/// Searchable list of formats for a month, with favorites starred and pinned at the top.
struct UsageFormatPicker: View {
    @Environment(\.dismiss) private var dismiss
    var formats: [UsageFormat]
    var selected: String?
    /// The month the formats belong to, for explaining favorites it doesn't include.
    var month: String? = nil
    var onPick: (UsageFormat) -> Void
    @State private var searchText = ""
    @State private var favorites = FavoriteFormats.shared

    /// A starred format, and the month's format for it if the month has one.
    private struct FavoriteRow: Identifiable {
        var id: String
        var format: UsageFormat?
    }

    private func matches(id: String, name: String, query: String) -> Bool {
        query.isEmpty || SearchNormalizer.normalize(name).contains(query) || id.contains(query)
    }

    /// Favorites in the order they were starred, matching the search.
    private var favoriteRows: [FavoriteRow] {
        let query = SearchNormalizer.normalize(searchText)
        return favorites.ids
            .map { id in FavoriteRow(id: id, format: formats.first { $0.id == id }) }
            .filter { matches(id: $0.id, name: $0.format?.displayName ?? UsageFormat.displayName(for: $0.id), query: query) }
    }

    private var results: [UsageFormat] {
        let query = SearchNormalizer.normalize(searchText)
        let sorted = formats.sorted { lhs, rhs in
            // Newest generation first, then alphabetically.
            if lhs.generation != rhs.generation { return (lhs.generation ?? 0) > (rhs.generation ?? 0) }
            return lhs.displayName < rhs.displayName
        }
        return sorted.filter { matches(id: $0.id, name: $0.displayName, query: query) }
    }

    var body: some View {
        NavigationStack {
            List {
                let starred = favoriteRows
                if !starred.isEmpty {
                    Section("Favorites") {
                        ForEach(starred) { row in
                            if let format = row.format {
                                formatRow(format)
                            } else {
                                unavailableRow(row.id)
                            }
                        }
                    }
                }
                Section {
                    ForEach(results) { formatRow($0) }
                } header: {
                    if !starred.isEmpty { Text("All Formats") }
                }
            }
            .animation(.default, value: favorites.ids)
            .searchable(text: $searchText, prompt: "Format")
            .navigationTitle("Format")
            .inlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .macSheetFrame()
    }

    private func formatRow(_ format: UsageFormat) -> some View {
        HStack(spacing: 8) {
            Button {
                onPick(format)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(format.displayName).foregroundStyle(.primary)
                        Text(format.id).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if format.id == selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            starButton(format.id)
        }
    }

    /// A favorite this month's statistics don't include: kept, explained, and still possible to unstar.
    private func unavailableRow(_ id: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(UsageFormat.displayName(for: id)).foregroundStyle(.secondary)
                Text(FavoriteFormats.unavailableNote(month: month)).font(.caption).foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            starButton(id)
        }
    }

    private func starButton(_ id: String) -> some View {
        let isFavorite = favorites.contains(id)
        return Button {
            favorites.toggle(id)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

/// Drives the Global Stats screen. One shared instance keeps the loaded rankings and the chosen
/// month, format and rating for the whole app session, and the selection is remembered across launches.
@Observable
@MainActor
final class UsageStatsModel {
    static let shared = UsageStatsModel()
    static let selectionKey = "usageSelection"
    private static let log = Logger(subsystem: "Neodex", category: "UsageStats")

    private(set) var months: [String] = []
    private(set) var formats: [UsageFormat] = []
    private(set) var selection: UsageSelection? {
        didSet { Self.store(selection) }
    }
    private(set) var report: UsageRankingsReport?
    private(set) var isLoading = false
    private(set) var error: Error?

    private let client = SmogonStatsClient.shared
    private var hasLoaded = false
    /// A format requested by a deep link before the format list has loaded.
    private var preferredFormatID: String?

    /// Shows `formatID` as soon as possible: now if the formats are known, otherwise on the next load.
    func prefer(formatID: String) async {
        if let format = formats.first(where: { $0.id == formatID }) {
            await select(format: format)
        } else {
            preferredFormatID = formatID
            if hasLoaded { await reload() }
        }
    }

    init() {
        selection = Self.storedSelection()
    }

    private static func storedSelection() -> UsageSelection? {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else { return nil }
        return try? JSONDecoder().decode(UsageSelection.self, from: data)
    }

    private static func store(_ selection: UsageSelection?) {
        guard let selection, let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: selectionKey)
    }

    var currentFormat: UsageFormat? { formats.first { $0.id == selection?.format } }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    /// Pull to refresh: asks Smogon for the month list again, then reloads.
    func refresh() async {
        Self.log.info("Refreshing usage statistics")
        await client.forgetMonths()
        await reload()
    }

    func reload() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            months = try await client.months()
            let month = selection?.month ?? months.first ?? ""
            formats = try await client.formats(for: month)
            SharedContainer.defaults?.set(formats.map(\.id), forKey: SharedContainer.DefaultsKey.usageFormats)
            if let preferredFormatID, formats.contains(where: { $0.id == preferredFormatID }) {
                selection = UsageSelection(month: month, format: preferredFormatID, rating: 0)
                self.preferredFormatID = nil
            }
            let format = formats.first { $0.id == selection?.format } ?? formats.first { $0.id == "gen9ou" } ?? formats[0]
            let rating = selection.map { $0.rating } ?? Self.defaultRating(for: format)
            selection = UsageSelection(month: month, format: format.id, rating: format.ratingCutoffs.contains(rating) ? rating : Self.defaultRating(for: format))
            await loadRankings()
        } catch {
            self.error = error
        }
    }

    func select(month: String) async {
        guard var selection, selection.month != month else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            formats = try await client.formats(for: month)
            selection.month = month
            if let same = formats.first(where: { $0.id == selection.format }) {
                if !same.ratingCutoffs.contains(selection.rating) { selection.rating = Self.defaultRating(for: same) }
            } else if let fallback = formats.first(where: { $0.id == "gen9ou" }) ?? formats.first {
                selection.format = fallback.id
                selection.rating = Self.defaultRating(for: fallback)
            }
            self.selection = selection
            await loadRankings()
        } catch {
            self.error = error
        }
    }

    func select(format: UsageFormat) async {
        guard var selection, selection.format != format.id else { return }
        selection.format = format.id
        if !format.ratingCutoffs.contains(selection.rating) { selection.rating = Self.defaultRating(for: format) }
        self.selection = selection
        await loadRankings()
    }

    func select(rating: Int) async {
        guard var selection, selection.rating != rating else { return }
        selection.rating = rating
        self.selection = selection
        await loadRankings()
    }

    private func loadRankings() async {
        guard let selection else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            report = try await client.rankings(for: selection)
        } catch {
            report = nil
            self.error = error
        }
    }

    static func defaultRating(for format: UsageFormat) -> Int { UsageDefaults.defaultRating(for: format) }
    static func displayMonth(_ month: String) -> String { UsageDefaults.displayMonth(month) }
}

#if DEBUG
#Preview { PreviewHost { UsageStatsView() } }
#endif
