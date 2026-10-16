import AppIntents
import NeodexKit
import SwiftUI
import WidgetKit

/// A saved team's six Pokémon at a glance.
struct TeamWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.team, intent: SelectTeamIntent.self, provider: TeamProvider()) { entry in
            TeamWidgetView(entry: entry)
        }
        .configurationDisplayName("Team")
        .description("One of your teams, lined up like a battle preview.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SelectTeamIntent: WidgetConfigurationIntent {
    nonisolated static let title: LocalizedStringResource = "Choose Team"
    nonisolated static let description = IntentDescription("Which team the widget shows.")

    @Parameter(title: "Team")
    var team: TeamEntity?
}

nonisolated struct TeamEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Team")
    static let defaultQuery = TeamQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ summary: TeamSummary) {
        id = summary.id
        name = summary.name
    }
}

nonisolated struct TeamQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TeamEntity] {
        await TeamReader.teams().filter { identifiers.contains($0.id) }.map(TeamEntity.init)
    }

    func suggestedEntities() async throws -> [TeamEntity] {
        await TeamReader.teams().map(TeamEntity.init)
    }

    func defaultResult() async -> TeamEntity? {
        await TeamReader.teams().first.map(TeamEntity.init)
    }
}

nonisolated struct TeamEntry: TimelineEntry {
    var date: Date
    var team: TeamSummary?
    var pokemon: [WidgetPokemon?]
}

nonisolated struct TeamProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TeamEntry {
        TeamEntry(date: .now, team: TeamSummary(id: "placeholder", name: "My Team", format: "gen9ou", pokemonIDs: [], shiny: [], updatedAt: .now),
                  pokemon: Array(WidgetStore.index().filter(\.isSpecies).prefix(6)))
    }

    func snapshot(for configuration: SelectTeamIntent, in context: Context) async -> TeamEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: SelectTeamIntent, in context: Context) async -> Timeline<TeamEntry> {
        Timeline(entries: [await entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectTeamIntent) async -> TeamEntry {
        let teams = await TeamReader.teams()
        let team = teams.first { $0.id == configuration.team?.id } ?? teams.first
        let index = WidgetStore.index()
        let pokemon = (team?.pokemonIDs ?? []).map { id in index.first { $0.id == id } }
        return TeamEntry(date: .now, team: team, pokemon: pokemon)
    }
}

struct TeamWidgetView: View {
    var entry: TeamEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let team = entry.team {
                content(team)
                    .widgetURL(SharedContainer.deepLink("team/\(team.id)"))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.person.crop").font(.title2)
                    Text("Build a team in Neodex to show it here.").font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    @ViewBuilder
    private func content(_ team: TeamSummary) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(team.name).font(family == .systemSmall ? .subheadline.weight(.bold) : .headline).lineLimit(1)
                Spacer()
                if family != .systemSmall, let format = team.format {
                    Text(UsageFormat.displayName(for: format)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if family == .systemSmall {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<6, id: \.self) { slot in slotView(slot, size: 36) }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { slot in
                        slotView(slot, size: 56).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func slotView(_ slot: Int, size: CGFloat) -> some View {
        if slot < entry.pokemon.count, let pokemon = entry.pokemon[slot] {
            SpriteImage(imageID: pokemon.imageID, size: size)
        } else {
            Circle()
                .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [3]))
                .frame(width: size * 0.6, height: size * 0.6)
                .frame(width: size, height: size)
        }
    }
}
