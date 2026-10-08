import NeodexKit
import SwiftUI

/// A Pokémon's complete learnset, grouped by how each move is learned.
struct PokemonMovesView: View {
    @Environment(\.database) private var database
    var pokemon: Pokemon

    @State private var method: LearnMethod = .levelUp
    @State private var searchText = ""

    private var learnset: [LearnedMove] { database.learnset(for: pokemon) }

    private var availableMethods: [LearnMethod] {
        LearnMethod.allCases.filter { method in learnset.contains { $0.learned(by: method) } }
    }

    private var rows: [LearnedMove] {
        let filtered = learnset.filter { $0.learned(by: method) }
        let searched = searchText.isEmpty ? filtered : filtered.filter {
            SearchNormalizer.normalize($0.move.name).contains(SearchNormalizer.normalize(searchText))
        }
        switch method {
        case .levelUp:
            return searched.sorted { ($0.levelUpLevel() ?? 0, $0.move.name) < ($1.levelUpLevel() ?? 0, $1.move.name) }
        case .machine:
            return searched.sorted { ($0.move.tmNumber ?? .max, $0.move.name) < ($1.move.tmNumber ?? .max, $1.move.name) }
        default:
            return searched.sorted { $0.move.name < $1.move.name }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(rows) { learned in
                    NavigationLink(value: AppRoute.move(learned.move.id)) {
                        MoveRow(move: learned.move, trailing: trailingLabel(for: learned))
                    }
                }
            } header: {
                if let generation = rows.first?.sources.first?.generation {
                    Text("\(rows.count) moves · Generation \(generation) data")
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Filter moves")
        .safeAreaInset(edge: .top, spacing: 0) {
            if availableMethods.count > 1 {
                Picker("Method", selection: $method) {
                    ForEach(availableMethods, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .navigationTitle("\(pokemon.displayName) Moves")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !availableMethods.contains(method), let first = availableMethods.first { method = first }
        }
        .overlay {
            if rows.isEmpty { ContentUnavailableView.search(text: searchText) }
        }
    }

    private func trailingLabel(for learned: LearnedMove) -> String? {
        switch method {
        case .levelUp: learned.levelUpLevel().map { $0 <= 1 ? "Start" : "Lv. \($0)" }
        case .machine: learned.move.tmLabel ?? "TM"
        default: nil
        }
    }
}
