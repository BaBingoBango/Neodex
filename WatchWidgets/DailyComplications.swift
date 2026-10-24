import AppIntents
import NeodexKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

nonisolated struct WatchDailyEntry: TimelineEntry {
    var date: Date
    var pokemon: WidgetPokemon?
    var revealed: Bool
}

/// One entry per day for the coming week, picked with the same arithmetic as the app and the iPhone
/// widgets, so every screen agrees on the day's Pokémon.
nonisolated struct WatchDailyProvider: TimelineProvider {
    var mystery: Bool

    func placeholder(in context: Context) -> WatchDailyEntry {
        WatchDailyEntry(date: .now, pokemon: WatchWidgetStore.species.first { $0.id == "pikachu" }, revealed: !mystery)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchDailyEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchDailyEntry>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries = [entry(for: .now)]
        for offset in 1...7 {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) { entries.append(entry(for: date)) }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date) -> WatchDailyEntry {
        let species = WatchWidgetStore.species
        let pokemon = mystery ? DailyPick.mystery(species, on: date) : DailyPick.pokemonOfTheDay(species, on: date)
        return WatchDailyEntry(date: date, pokemon: pokemon, revealed: !mystery || WatchWidgetStore.isMysteryRevealed(on: date))
    }
}

// MARK: - Pokémon of the Day

struct PokemonOfTheDayComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WatchComplicationKind.pokemonOfTheDay, provider: WatchDailyProvider(mystery: false)) { entry in
            PokemonOfTheDayComplicationView(entry: entry)
        }
        .configurationDisplayName("Pokémon of the Day")
        .description("A different Pokémon every day. Tap to open its entry.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct PokemonOfTheDayComplicationView: View {
    var entry: WatchDailyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let pokemon = entry.pokemon {
                switch family {
                case .accessoryCircular:
                    ZStack {
                        AccessoryWidgetBackground()
                        PokemonThumb(imageID: pokemon.imageID).padding(3)
                    }
                case .accessoryCorner:
                    PokemonThumb(imageID: pokemon.imageID)
                        .widgetLabel { Text(pokemon.displayName) }
                case .accessoryInline:
                    Label {
                        Text(pokemon.displayName)
                    } icon: {
                        PokemonThumb(imageID: pokemon.imageID)
                    }
                default:
                    HStack(spacing: 8) {
                        PokemonThumb(imageID: pokemon.imageID)
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pokemon.displayName)
                                .font(.headline)
                                .widgetAccentable()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(pokemon.formattedDexNumber + (pokemon.genus.map { " · \($0)" } ?? ""))
                                .font(.caption2)
                                .lineLimit(1)
                            Text(pokemon.types.map(\.name).joined(separator: " / "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            } else {
                Text("Neodex")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(SharedContainer.deepLink(entry.pokemon.map { "pokemon/\($0.id)" } ?? "today"))
    }
}

// MARK: - Who's That Pokémon?

struct MysteryComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WatchComplicationKind.mystery, provider: WatchDailyProvider(mystery: true)) { entry in
            MysteryComplicationView(entry: entry)
        }
        .configurationDisplayName("Who's That Pokémon?")
        .description("A new silhouette every day. Tap to reveal it in Neodex.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}

struct MysteryComplicationView: View {
    var entry: WatchDailyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let pokemon = entry.pokemon {
                switch family {
                case .accessoryCircular:
                    ZStack {
                        AccessoryWidgetBackground()
                        PokemonThumb(imageID: pokemon.imageID, silhouette: !entry.revealed).padding(3)
                        if !entry.revealed {
                            Text("?")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .widgetAccentable()
                        }
                    }
                case .accessoryCorner:
                    PokemonThumb(imageID: pokemon.imageID, silhouette: !entry.revealed)
                        .widgetLabel { Text(entry.revealed ? pokemon.displayName : "Who's that?") }
                default:
                    HStack(spacing: 8) {
                        PokemonThumb(imageID: pokemon.imageID, silhouette: !entry.revealed)
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            if entry.revealed {
                                Text("It's \(pokemon.displayName)!")
                                    .font(.headline)
                                    .widgetAccentable()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(pokemon.types.map(\.name).joined(separator: " / "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Who's that Pokémon?")
                                    .font(.headline)
                                    .widgetAccentable()
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                Button(intent: WatchRevealMysteryIntent()) {
                                    Text("Reveal")
                                        .font(.caption2.weight(.bold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            } else {
                Text("Neodex")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(SharedContainer.deepLink(entry.revealed ? entry.pokemon.map { "pokemon/\($0.id)" } ?? "mystery" : "mystery"))
    }
}

/// Reveals today's mystery Pokémon from the Smart Stack; the complication then redraws with the answer.
nonisolated struct WatchRevealMysteryIntent: AppIntent {
    static let title: LocalizedStringResource = "Reveal the Mystery Pokémon"
    static let description = IntentDescription("Reveals today's Who's That Pokémon? complication.")

    func perform() async throws -> some IntentResult {
        WatchWidgetStore.revealMystery()
        WidgetCenter.shared.reloadTimelines(ofKind: WatchComplicationKind.mystery)
        return .result()
    }
}

// MARK: - Open Neodex

/// A Poké Ball that opens the app, for faces that just want a launcher.
struct OpenNeodexComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WatchComplicationKind.open, provider: OpenProvider()) { _ in
            OpenNeodexComplicationView()
        }
        .configurationDisplayName("Neodex")
        .description("Opens the Pokédex.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

nonisolated struct OpenEntry: TimelineEntry {
    var date: Date
}

nonisolated struct OpenProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenEntry { OpenEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (OpenEntry) -> Void) { completion(OpenEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenEntry>) -> Void) {
        completion(Timeline(entries: [OpenEntry(date: .now)], policy: .never))
    }
}

struct OpenNeodexComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("Neodex", systemImage: "circle.circle")
            case .accessoryCorner:
                PokeBallIcon()
                    .widgetLabel { Text("Neodex") }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    PokeBallIcon().padding(6)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(SharedContainer.deepLink("today"))
    }
}

// MARK: - Shared pieces

/// A thumbnail from the extension's `thumbs` folder, in full colour on faces that allow it, or as a
/// silhouette for Who's That Pokémon?.
struct PokemonThumb: View {
    var imageID: String
    var silhouette = false

    var body: some View {
        if let image = WatchWidgetStore.thumbnail(imageID) {
            if silhouette {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
            }
        } else {
            Image(systemName: "questionmark.circle")
                .resizable()
                .scaledToFit()
        }
    }
}
