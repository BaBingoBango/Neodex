import AppIntents
import NeodexKit
import SwiftUI
import WidgetKit

/// Smogon's most-used Pokémon in a format you choose.
struct LeaderboardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.leaderboard, intent: SelectFormatIntent.self, provider: LeaderboardProvider()) { entry in
            LeaderboardView(entry: entry)
        }
        .configurationDisplayName("Popular on Showdown")
        .description("The most-used Pokémon in a Smogon format this month.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct SelectFormatIntent: WidgetConfigurationIntent {
    nonisolated static let title: LocalizedStringResource = "Choose Format"
    nonisolated static let description = IntentDescription("Which Smogon format to rank.")

    @Parameter(title: "Format")
    var format: UsageFormatEntity?
}

nonisolated struct UsageFormatEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Format")
    static let defaultQuery = UsageFormatQuery()

    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(UsageFormat.displayName(for: id))", subtitle: "\(id)")
    }
}

nonisolated struct UsageFormatQuery: EntityStringQuery {
    private var known: [String] {
        let fetched = SharedContainer.defaults?.stringArray(forKey: SharedContainer.DefaultsKey.usageFormats) ?? []
        return fetched.isEmpty ? UsageDefaults.fallbackFormats : fetched
    }

    func entities(for identifiers: [String]) async throws -> [UsageFormatEntity] {
        identifiers.map(UsageFormatEntity.init)
    }

    func entities(matching string: String) async throws -> [UsageFormatEntity] {
        let query = ShowdownID.make(string)
        return known.filter { $0.contains(query) || ShowdownID.make(UsageFormat.displayName(for: $0)).contains(query) }.map(UsageFormatEntity.init)
    }

    func suggestedEntities() async throws -> [UsageFormatEntity] {
        known.map(UsageFormatEntity.init)
    }

    func defaultResult() async -> UsageFormatEntity? {
        UsageFormatEntity(id: SharedContainer.defaults?.string(forKey: SharedContainer.DefaultsKey.popularFormat) ?? "gen9ou")
    }
}

nonisolated struct LeaderboardEntry: TimelineEntry {
    struct Row: Sendable, Identifiable {
        var rank: Int
        var name: String
        var percent: Double
        var pokemon: WidgetPokemon?
        var id: Int { rank }
    }

    var date: Date
    var formatID: String
    var month: String?
    var rows: [Row]
    var failed: Bool
}

nonisolated struct LeaderboardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LeaderboardEntry {
        let index = WidgetStore.index()
        let rows = ["Great Tusk", "Kingambit", "Gholdengo", "Ogerpon-Wellspring", "Zamazenta", "Dragonite", "Raging Bolt", "Iron Valiant", "Slowking-Galar", "Landorus-Therian"]
            .enumerated().map { offset, name in
                LeaderboardEntry.Row(rank: offset + 1, name: name, percent: 35 - Double(offset) * 2.5, pokemon: WidgetStore.pokemon(named: name, in: index))
            }
        return LeaderboardEntry(date: .now, formatID: "gen9ou", month: nil, rows: rows, failed: false)
    }

    func snapshot(for configuration: SelectFormatIntent, in context: Context) async -> LeaderboardEntry {
        context.isPreview ? placeholder(in: context) : await load(formatID(for: configuration))
    }

    func timeline(for configuration: SelectFormatIntent, in context: Context) async -> Timeline<LeaderboardEntry> {
        let entry = await load(formatID(for: configuration))
        let next = Date.now.addingTimeInterval(entry.failed ? 3600 : 6 * 3600)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func formatID(for configuration: SelectFormatIntent) -> String {
        configuration.format?.id ?? SharedContainer.defaults?.string(forKey: SharedContainer.DefaultsKey.popularFormat) ?? "gen9ou"
    }

    private func load(_ formatID: String) async -> LeaderboardEntry {
        let client = SmogonStatsClient.shared
        guard let month = try? await client.months().first,
              let formats = try? await client.formats(for: month),
              let format = formats.first(where: { $0.id == formatID }) ?? formats.first,
              let report = try? await client.rankings(for: UsageSelection(month: month, format: format.id, rating: UsageDefaults.defaultRating(for: format))) else {
            return LeaderboardEntry(date: .now, formatID: formatID, month: nil, rows: [], failed: true)
        }
        let index = WidgetStore.index()
        let rows = report.rankings.prefix(10).map { ranking in
            LeaderboardEntry.Row(rank: ranking.rank, name: ranking.name, percent: ranking.usagePercent,
                                 pokemon: WidgetStore.pokemon(named: ranking.name, in: index))
        }
        return LeaderboardEntry(date: .now, formatID: format.id, month: month, rows: rows, failed: false)
    }
}

struct LeaderboardView: View {
    var entry: LeaderboardEntry
    @Environment(\.widgetFamily) private var family

    private var isLarge: Bool { family == .systemLarge }
    private var rows: ArraySlice<LeaderboardEntry.Row> { entry.rows.prefix(isLarge ? 10 : 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 6 : 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(UsageFormat.displayName(for: entry.formatID))
                    .font(isLarge ? .headline : .subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if let month = entry.month {
                    Text(UsageDefaults.displayMonth(month)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if rows.isEmpty {
                Spacer()
                Text(entry.failed ? "Smogon's stats aren't reachable right now." : "No rankings yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        Text("\(row.rank)")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(row.rank <= 3 ? Color.orange : .secondary)
                            .frame(width: 18, alignment: .trailing)
                        if let pokemon = row.pokemon {
                            SpriteImage(imageID: pokemon.imageID, size: isLarge ? 28 : 24)
                        }
                        Text(row.pokemon?.name ?? row.name)
                            .font(isLarge ? .subheadline.weight(.medium) : .footnote.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Text(row.percent.formatted(.number.precision(.fractionLength(1))) + "%")
                            .font(isLarge ? .subheadline.weight(.semibold) : .footnote.weight(.semibold))
                            .monospacedDigit()
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .widgetURL(SharedContainer.deepLink("stats/\(entry.formatID)"))
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}
