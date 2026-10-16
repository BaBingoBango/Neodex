import AppIntents
import NeodexKit
import SwiftUI
import WidgetKit

// MARK: - Shared provider

nonisolated struct DailyEntry: TimelineEntry {
    var date: Date
    var pokemon: WidgetPokemon?
    var revealed: Bool
}

/// One entry per day for the next week; the mystery variant also tracks whether today's was revealed.
nonisolated struct DailyProvider: TimelineProvider {
    var mystery: Bool

    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: .now, pokemon: WidgetStore.index().first(where: { $0.id == "pikachu" }), revealed: !mystery)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(entry(for: .now, index: WidgetStore.index()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let index = WidgetStore.index()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries = [entry(for: .now, index: index)]
        for offset in 1...7 {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                entries.append(entry(for: date, index: index))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// The gallery preview shows the silhouette too, so the widget never gives today's answer away.
    private func entry(for date: Date, index: [WidgetPokemon]) -> DailyEntry {
        let pokemon = WidgetStore.pick(on: date, mystery: mystery, index: index)
        let revealed = !mystery || WidgetStore.isMysteryRevealed(on: date)
        return DailyEntry(date: date, pokemon: pokemon, revealed: revealed)
    }
}

// MARK: - Pokémon of the Day

struct PokemonOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.pokemonOfTheDay, provider: DailyProvider(mystery: false)) { entry in
            PokemonOfTheDayView(entry: entry)
        }
        .configurationDisplayName("Pokémon of the Day")
        .description("A different Pokémon every day, with its Pokédex entry.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct PokemonOfTheDayView: View {
    var entry: DailyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let pokemon = entry.pokemon {
                content(pokemon)
                    .widgetURL(SharedContainer.deepLink("pokemon/\(pokemon.id)"))
            } else {
                OpenAppPrompt()
            }
        }
        .containerBackground(for: .widget) {
            if let pokemon = entry.pokemon, !family.isAccessory {
                TypeGradient(types: pokemon.types)
            } else {
                Color(.systemBackground)
            }
        }
    }

    @ViewBuilder
    private func content(_ pokemon: WidgetPokemon) -> some View {
        switch family {
        case .accessoryCircular:
            SpriteImage(imageID: pokemon.imageID, size: 48)
        case .accessoryInline:
            Label("\(pokemon.formattedDexNumber) \(pokemon.displayName)", systemImage: "sparkle")
        case .accessoryRectangular:
            HStack(spacing: 6) {
                SpriteImage(imageID: pokemon.imageID, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pokémon of the Day").font(.caption2).foregroundStyle(.secondary)
                    Text(pokemon.displayName).font(.headline).lineLimit(1)
                    Text(pokemon.types.map(\.name).joined(separator: " · ")).font(.caption).lineLimit(1)
                }
            }
        case .systemSmall:
            VStack(spacing: 4) {
                ArtworkImage(pokemon: pokemon).frame(maxHeight: .infinity)
                Text(pokemon.displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(pokemon.formattedDexNumber)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .systemMedium:
            HStack(spacing: 12) {
                ArtworkImage(pokemon: pokemon).frame(width: 110)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pokémon of the Day".uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(pokemon.displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    WidgetTypeRow(types: pokemon.types)
                    if let entry = pokemon.entry {
                        Text(entry)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pokémon of the Day".uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(pokemon.displayName)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let genus = pokemon.genus {
                            Text("\(genus) Pokémon · \(pokemon.formattedDexNumber)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Spacer()
                    WidgetTypeRow(types: pokemon.types)
                }
                ArtworkImage(pokemon: pokemon).frame(maxWidth: .infinity, maxHeight: .infinity)
                if let entry = pokemon.entry {
                    Text(entry)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(4)
                }
            }
        }
    }
}

// MARK: - Who's that Pokémon?

struct MysteryPokemonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.mystery, provider: DailyProvider(mystery: true)) { entry in
            MysteryPokemonView(entry: entry)
        }
        .configurationDisplayName("Who's That Pokémon?")
        .description("A new silhouette every day. Tap to reveal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MysteryPokemonView: View {
    var entry: DailyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let pokemon = entry.pokemon {
                if family == .systemSmall { small(pokemon) } else { medium(pokemon) }
            } else {
                OpenAppPrompt()
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.08, green: 0.16, blue: 0.42), Color(red: 0.16, green: 0.08, blue: 0.36)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func small(_ pokemon: WidgetPokemon) -> some View {
        VStack(spacing: 4) {
            silhouette(pokemon).frame(maxHeight: .infinity)
            if entry.revealed {
                Text(pokemon.displayName).font(.headline.weight(.bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            } else {
                revealButton
            }
        }
        .widgetURL(SharedContainer.deepLink(entry.revealed ? "pokemon/\(pokemon.id)" : "mystery"))
    }

    private func medium(_ pokemon: WidgetPokemon) -> some View {
        HStack(spacing: 12) {
            silhouette(pokemon).frame(width: 110)
            VStack(alignment: .leading, spacing: 6) {
                Text("Who's that Pokémon?")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                if entry.revealed {
                    Text("It's \(pokemon.displayName)!")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.yellow)
                    WidgetTypeRow(types: pokemon.types)
                } else {
                    Text(pokemon.genus.map { "Hint: the \($0) Pokémon." } ?? "A new silhouette every day.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    revealButton
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(SharedContainer.deepLink(entry.revealed ? "pokemon/\(pokemon.id)" : "mystery"))
    }

    private func silhouette(_ pokemon: WidgetPokemon) -> some View {
        ZStack {
            if entry.revealed {
                ArtworkImage(pokemon: pokemon)
            } else {
                ArtworkImage(pokemon: pokemon, silhouette: true)
                Text("?")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                    .shadow(radius: 4)
            }
        }
    }

    private var revealButton: some View {
        Button(intent: RevealMysteryIntent()) {
            Label("Reveal", systemImage: "eye.fill")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.yellow, in: Capsule())
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
    }
}

/// Marks today's mystery Pokémon as revealed; the widget then redraws with the answer.
nonisolated struct RevealMysteryIntent: AppIntent {
    static let title: LocalizedStringResource = "Reveal the Mystery Pokémon"
    static let description = IntentDescription("Reveals today's Who's That Pokémon? widget.")

    func perform() async throws -> some IntentResult {
        SharedContainer.defaults?.set(DailyPick.dayOrdinal(), forKey: SharedContainer.DefaultsKey.mysteryRevealedDay)
        return .result()
    }
}

// MARK: - Pieces

struct ArtworkImage: View {
    var pokemon: WidgetPokemon
    var silhouette = false

    var body: some View {
        if let image = WidgetStore.artwork(pokemon.imageID) ?? WidgetStore.sprite(pokemon.imageID) {
            if silhouette {
                Image(uiImage: image).renderingMode(.template).resizable().scaledToFit().foregroundStyle(.black.opacity(0.85))
            } else {
                Image(uiImage: image).resizable().scaledToFit().shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            }
        } else {
            Image(systemName: "questionmark.circle.dashed").resizable().scaledToFit().foregroundStyle(.white.opacity(0.6)).padding(12)
        }
    }
}

struct SpriteImage: View {
    var imageID: String
    var size: CGFloat

    var body: some View {
        if let image = WidgetStore.sprite(imageID) {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image(systemName: "questionmark.circle").resizable().scaledToFit().frame(width: size * 0.7, height: size * 0.7)
        }
    }
}

struct WidgetTypeRow: View {
    var types: [PokemonType]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(types) { type in
                Text(type.name.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(type.color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .foregroundStyle(type.contrastingTextColor)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
            }
        }
    }
}

struct TypeGradient: View {
    var types: [PokemonType]

    var body: some View {
        let first = types.first?.color ?? .accentColor
        let second = (types.count > 1 ? types[1] : types.first)?.color ?? .accentColor
        LinearGradient(colors: [first, second.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Shown until the app has been opened once and stocked the shared container.
struct OpenAppPrompt: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "book.closed.fill").font(.title2)
            Text("Open Neodex once to set up this widget.")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .padding()
    }
}

extension WidgetFamily {
    var isAccessory: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: true
        default: false
        }
    }
}
