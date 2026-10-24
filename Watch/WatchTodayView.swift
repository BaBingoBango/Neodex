import NeodexKit
import SwiftUI
import WidgetKit

/// The same Pokémon of the Day and Who's That Pokémon? as the iPhone widgets, picked deterministically
/// from the date so every device agrees.
struct WatchTodayView: View {
    var database: PokedexDatabase

    /// Shared with the Who's That Pokémon? complication through the App Group.
    @AppStorage(SharedContainer.DefaultsKey.mysteryRevealedDay, store: SharedContainer.defaults) private var revealedDay = 0

    private var today: Int { DailyPick.dayOrdinal() }
    private var pick: Pokemon? { DailyPick.pokemonOfTheDay(database.species) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let pick {
                    sectionTitle("Pokémon of the Day")
                    NavigationLink(value: WatchRoute.pokemon(pick.id)) {
                        HStack(spacing: 10) {
                            WatchPokemonImage(pokemon: pick)
                                .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pick.displayName)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                HStack(spacing: 4) {
                                    ForEach(pick.types, id: \.self) { TypeBadge(type: $0, size: .small) }
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .watchCard()
                    if let entry = pick.dexEntries.first {
                        Text(entry.text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let mystery = DailyPick.mystery(database.species) {
                    sectionTitle("Who's That Pokémon?")
                    let revealed = revealedDay == today
                    Button {
                        withAnimation(.snappy) { revealedDay = today }
                        WidgetCenter.shared.reloadTimelines(ofKind: WatchComplicationKind.mystery)
                    } label: {
                        HStack(spacing: 10) {
                            WatchPokemonImage(pokemon: mystery, silhouette: !revealed)
                                .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(revealed ? mystery.displayName : "???")
                                    .font(.headline)
                                Text(revealed ? "#\(String(format: "%04d", mystery.nationalDexNumber))" : "Tap to reveal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .watchCard()
                    if revealed {
                        NavigationLink("Open \(mystery.displayName)", value: WatchRoute.pokemon(mystery.id))
                            .font(.footnote)
                            .buttonStyle(.glass)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Today")
        .containerBackground(WatchTheme.background(pick?.types ?? []), for: .navigation)
        .watchDestinations(database: database)
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
