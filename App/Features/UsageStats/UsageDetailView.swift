import NeodexKit
import SwiftUI

/// Detailed Smogon usage data for one Pokémon in one format.
struct UsageDetailView: View {
    @Environment(\.database) private var database
    var selection: UsageSelection
    var name: String

    @State private var detail: UsageDetail?
    @State private var error: Error?
    @State private var isLoading = true

    private var pokemon: Pokemon? { database.pokemon(named: name) }

    var body: some View {
        List {
            if let detail {
                Section {
                    let header = HStack(spacing: 14) {
                        if let pokemon {
                            PokemonImage(pokemon: pokemon, kind: .thumbnail).frame(width: 72, height: 72)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pokemon?.displayName ?? name).font(.title2.weight(.bold))
                            Text("\(detail.usagePercent.formatted(.number.precision(.fractionLength(2))))% usage · \(detail.rawCount.formatted()) sets")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(UsageFormat.displayName(for: selection.format)) · \(UsageStatsModel.displayMonth(selection.month)) · \(selection.rating == 0 ? "all ratings" : "\(selection.rating)+")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    if let pokemon {
                        NavigationLink(value: AppRoute.pokemon(pokemon.id)) { header }
                    } else {
                        header
                    }
                }
                UsageTrendChart(selection: selection, name: detail.name)
                entries("Abilities", detail.abilities.prefix(6)) { database.ability(id: $0)?.name ?? $0 }
                entries("Items", detail.items.prefix(8)) { $0 == "nothing" ? "No item" : database.item(id: $0)?.name ?? $0 }
                entries("Moves", detail.moves.prefix(12)) { database.move(id: $0)?.name ?? $0 }
                entries("Tera Types", detail.teraTypes.prefix(8)) { $0 }
                spreads(detail.spreads.prefix(8))
                teammates(detail.teammates.prefix(10))
                checks(detail.checksAndCounters.prefix(10))
            }
        }
        .navigationTitle(pokemon?.displayName ?? name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView("Loading details…")
            } else if let error {
                ContentUnavailableView("Couldn't Load Details", systemImage: "wifi.exclamationmark", description: Text(error.localizedDescription))
            } else if detail == nil {
                ContentUnavailableView("No Details", systemImage: "chart.bar", description: Text("Smogon has no detailed data for \(name) in this format."))
            }
        }
        .task(id: selection) {
            isLoading = true
            defer { isLoading = false }
            do {
                let report = try await SmogonStatsClient.shared.chaos(for: selection)
                detail = report.details[name] ?? report.details.first { ShowdownID.make($0.key) == ShowdownID.make(name) }?.value
            } catch {
                self.error = error
            }
        }
    }

    private func entries(_ title: LocalizedStringKey, _ items: ArraySlice<UsageDetail.Entry>, label: @escaping (String) -> String) -> some View {
        Group {
            if !items.isEmpty {
                Section(title) {
                    ForEach(Array(items)) { entry in
                        PercentRow(label: label(entry.key), percent: entry.percent, tint: .blue)
                    }
                }
            }
        }
    }

    private func spreads(_ items: ArraySlice<UsageDetail.Entry>) -> some View {
        Group {
            if !items.isEmpty {
                Section("EV Spreads") {
                    ForEach(Array(items)) { entry in
                        PercentRow(label: Self.describeSpread(entry.key), percent: entry.percent, tint: .purple)
                    }
                }
            }
        }
    }

    private func teammates(_ items: ArraySlice<UsageDetail.Entry>) -> some View {
        Group {
            if !items.isEmpty {
                Section("Teammates") {
                    ForEach(Array(items)) { entry in
                        if let teammate = database.pokemon(named: entry.key) {
                            NavigationLink(value: AppRoute.usageDetail(selection, name: entry.key)) {
                                HStack(spacing: 10) {
                                    PokemonImage(pokemon: teammate, kind: .sprite).frame(width: 36, height: 36)
                                    PercentRow(label: teammate.displayName, percent: entry.percent, tint: .green)
                                }
                            }
                        } else {
                            PercentRow(label: entry.key, percent: entry.percent, tint: .green)
                        }
                    }
                }
            }
        }
    }

    private func checks(_ items: ArraySlice<UsageDetail.Check>) -> some View {
        Group {
            if !items.isEmpty {
                Section {
                    ForEach(Array(items)) { check in
                        if let threat = database.pokemon(named: check.name) {
                            NavigationLink(value: AppRoute.usageDetail(selection, name: check.name)) {
                                HStack(spacing: 10) {
                                    PokemonImage(pokemon: threat, kind: .sprite).frame(width: 36, height: 36)
                                    PercentRow(label: threat.displayName, percent: check.probability * 100, tint: .red)
                                }
                            }
                        } else {
                            PercentRow(label: check.name, percent: check.probability * 100, tint: .red)
                        }
                    }
                } header: {
                    Text("Checks and Counters")
                } footer: {
                    Text("How often each Pokémon knocks out or forces out \(pokemon?.displayName ?? name).")
                }
            }
        }
    }

    /// `"Jolly:0/252/4/0/0/252"` → `"Jolly · 252 Atk / 4 Def / 252 Spe"`.
    static func describeSpread(_ spread: String) -> String {
        let parts = spread.split(separator: ":")
        guard parts.count == 2 else { return spread }
        let values = parts[1].split(separator: "/").compactMap { Int($0) }
        guard values.count == 6 else { return spread }
        let evs = zip(Stat.allCases, values).filter { $0.1 > 0 }.map { "\($0.1) \($0.0.showdownAbbreviation)" }
        return "\(parts[0]) · " + (evs.isEmpty ? "no EVs" : evs.joined(separator: " / "))
    }
}

/// A label with a percentage and a proportional bar.
struct PercentRow: View {
    var label: String
    var percent: Double
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                Text(percent.formatted(.number.precision(.fractionLength(1))) + "%")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint).frame(width: geometry.size.width * min(1, percent / 100))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
    }
}
