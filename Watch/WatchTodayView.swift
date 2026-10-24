import NeodexKit
import SwiftUI

/// The same Pokémon of the Day and Who's That Pokémon? as the iPhone widgets, picked deterministically
/// from the date so every device agrees.
struct WatchTodayView: View {
    var database: PokedexDatabase

    @AppStorage("mysteryRevealedDay") private var revealedDay = 0

    private var today: Int { DailyPick.dayOrdinal() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let pick = DailyPick.pokemonOfTheDay(database.species) {
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
                    .padding(10)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .padding(10)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if revealed {
                        NavigationLink("Open \(mystery.displayName)", value: WatchRoute.pokemon(mystery.id))
                            .font(.footnote)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Today")
        .watchDestinations(database: database)
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
