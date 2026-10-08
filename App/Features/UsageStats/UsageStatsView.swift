import NeodexKit
import SwiftUI

/// Global Stats: Smogon usage rankings for any format and month.
struct UsageStatsView: View {
    @Environment(\.database) private var database
    @State private var model = UsageStatsModel()
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
        .searchable(text: $searchText, prompt: "Filter Pokémon")
        .navigationTitle("Global Stats")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) { selectionBar }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.reload() } }
                    .disabled(model.isLoading)
            }
        }
        .overlay { stateOverlay }
        .task { await model.loadIfNeeded() }
        .sheet(isPresented: $showingFormats) {
            UsageFormatPicker(formats: model.formats, selected: model.selection?.format) { format in
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
                    Button { showingFormats = true } label: {
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
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)
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

/// Searchable list of formats for a month.
struct UsageFormatPicker: View {
    @Environment(\.dismiss) private var dismiss
    var formats: [UsageFormat]
    var selected: String?
    var onPick: (UsageFormat) -> Void
    @State private var searchText = ""

    private var results: [UsageFormat] {
        let query = SearchNormalizer.normalize(searchText)
        let sorted = formats.sorted { lhs, rhs in
            // Newest generation first, then alphabetically.
            if lhs.generation != rhs.generation { return (lhs.generation ?? 0) > (rhs.generation ?? 0) }
            return lhs.displayName < rhs.displayName
        }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { SearchNormalizer.normalize($0.displayName).contains(query) || $0.id.contains(query) }
    }

    var body: some View {
        NavigationStack {
            List(results) { format in
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
                }
            }
            .searchable(text: $searchText, prompt: "Format")
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

/// Drives the Global Stats screen.
@Observable
@MainActor
final class UsageStatsModel {
    private(set) var months: [String] = []
    private(set) var formats: [UsageFormat] = []
    private(set) var selection: UsageSelection?
    private(set) var report: UsageRankingsReport?
    private(set) var isLoading = false
    private(set) var error: Error?

    private let client = SmogonStatsClient.shared
    private var hasLoaded = false

    var currentFormat: UsageFormat? { formats.first { $0.id == selection?.format } }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
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

    /// Smogon's "standard" cutoff is 1695 for OU-style formats and 1630 elsewhere.
    static func defaultRating(for format: UsageFormat) -> Int {
        for preferred in [1695, 1630, 1760, 1500] where format.ratingCutoffs.contains(preferred) { return preferred }
        return format.ratingCutoffs.first ?? 0
    }

    static func displayMonth(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count >= 2, let year = Int(parts[0]), let monthNumber = Int(parts[1]) else { return month }
        var components = DateComponents()
        components.year = year
        components.month = monthNumber
        guard let date = Calendar.current.date(from: components) else { return month }
        return date.formatted(.dateTime.month(.wide).year())
    }
}

#if DEBUG
#Preview { PreviewHost { UsageStatsView() } }
#endif
