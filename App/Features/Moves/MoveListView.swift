import NeodexKit
import SwiftUI

/// Moves tab root.
struct MoveListView: View {
    var body: some View {
        NavigationStack {
            MoveListContent()
                .appDestinations()
        }
    }
}

/// The Move Dex: every move, searchable, filterable by type and category.
struct MoveListContent: View {
    @Environment(\.database) private var database
    @State private var searchText = ""
    @State private var typeFilter: PokemonType?
    @State private var categoryFilter: MoveCategory?
    @State private var includeSpecialMoves = false
    @State private var sort: MoveSort = .name

    enum MoveSort: String, CaseIterable, Identifiable {
        case name = "Name", power = "Power", accuracy = "Accuracy", pp = "PP", tm = "TM Number"
        var id: String { rawValue }
    }

    private var results: [Move] {
        var moves = database.moves
        if !includeSpecialMoves { moves = moves.filter { $0.kind == .standard } }
        if let typeFilter { moves = moves.filter { $0.type == typeFilter } }
        if let categoryFilter { moves = moves.filter { $0.category == categoryFilter } }
        let query = SearchNormalizer.normalize(searchText)
        if !query.isEmpty {
            moves = moves.filter { SearchNormalizer.match(SearchNormalizer.normalize($0.name), query: query) != .none }
        }
        switch sort {
        case .name: break
        case .power: moves.sort { ($0.basePower, $1.name) > ($1.basePower, $0.name) }
        case .accuracy: moves.sort { ($0.accuracy ?? 101, $1.name) > ($1.accuracy ?? 101, $0.name) }
        case .pp: moves.sort { ($0.pp, $1.name) > ($1.pp, $0.name) }
        case .tm:
            moves = moves.filter { $0.tmNumber != nil }.sorted { ($0.tmNumber ?? 0) < ($1.tmNumber ?? 0) }
        }
        return moves
    }

    var body: some View {
        List(results) { move in
            NavigationLink(value: AppRoute.move(move.id)) {
                MoveRow(move: move, trailing: trailing(for: move))
            }
        }
        .listStyle(.plain)
        .navigationTitle("Moves")
        .searchable(text: $searchText, prompt: "Move name")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(MoveSort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Category", selection: $categoryFilter) {
                        Text("All Categories").tag(MoveCategory?.none)
                        ForEach(MoveCategory.allCases) { Text($0.name).tag(MoveCategory?.some($0)) }
                    }
                    Picker("Type", selection: $typeFilter) {
                        Text("All Types").tag(PokemonType?.none)
                        ForEach(PokemonType.allCases) { Text($0.name).tag(PokemonType?.some($0)) }
                    }
                    Toggle("Include Z-Moves & Max Moves", isOn: $includeSpecialMoves)
                } label: {
                    Label("Filter", systemImage: hasFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .overlay {
            if results.isEmpty { ContentUnavailableView.search(text: searchText) }
        }
    }

    private var hasFilters: Bool { typeFilter != nil || categoryFilter != nil || includeSpecialMoves || sort != .name }

    private func trailing(for move: Move) -> String? {
        switch sort {
        case .name, .tm: move.tmLabel
        case .power: move.basePowerText
        case .accuracy: move.accuracyText
        case .pp: "\(move.pp) PP"
        }
    }
}

#if DEBUG
#Preview { MoveListView().previewEnvironment() }
#endif
