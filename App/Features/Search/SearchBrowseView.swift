import NeodexKit
import SwiftUI

/// What Search shows before you type: a tile for each part of the dex and one for every type, in the
/// style of Apple Music's Search.
struct SearchBrowseView: View {
    @Environment(\.database) private var database

    /// The dex sections: the Pokédex fronted by a Pokémon, the rest by their tab's symbol, and Items
    /// by an item from the bag.
    private static let sections: [(tab: AppTab, title: String, artwork: BrowseTile.Artwork)] = [
        (.pokedex, "Pokémon", .pokemon("bulbasaur")), (.moves, "Moves", .symbol(AppTab.moves.systemImage)),
        (.abilities, "Abilities", .symbol(AppTab.abilities.systemImage)), (.items, "Items", .item("pokeball")),
        (.types, "Type-O-Matic", .symbol(AppTab.types.systemImage)), (.natures, "Natures", .symbol(AppTab.natures.systemImage)),
    ]

    /// A well-known Pokémon of each type.
    private static let typeFaces: [PokemonType: Pokemon.ID] = [
        .normal: "snorlax", .fire: "charizard", .water: "blastoise", .grass: "venusaur", .electric: "pikachu",
        .ice: "lapras", .fighting: "lucario", .poison: "gengar", .ground: "garchomp", .flying: "corviknight",
        .psychic: "mewtwo", .bug: "scizor", .rock: "tyranitar", .ghost: "mimikyu", .dragon: "dragonite",
        .dark: "umbreon", .steel: "gholdengo", .fairy: "gardevoir",
    ]

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Self.sections, id: \.tab) { section in
                        NavigationLink(value: section.tab) {
                            BrowseTile(title: section.title, color: section.tab.tint, artwork: section.artwork)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Types")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(PokemonType.allCases) { type in
                            NavigationLink(value: AppRoute.typePokemon(type)) {
                                BrowseTile(title: type.name, color: type.color, artwork: .pokemon(Self.typeFaces[type] ?? ""))
                            }
                        }
                    }
                }
            }
            .buttonStyle(BrowseTileButtonStyle())
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

/// A colored tile with a Pokémon, symbol or item bleeding off its corner and a bold title.
struct BrowseTile: View {
    enum Artwork {
        case pokemon(Pokemon.ID)
        case symbol(String)
        /// A bundled item sprite, by item ID.
        case item(String)
    }

    @Environment(\.self) private var environment
    @Environment(\.database) private var database
    var title: String
    var color: Color
    var artwork: Artwork

    /// Light colors are deepened, the way Apple Music's tiles are mustard rather than lemon, so a
    /// white title reads on every tile.
    private var background: Color {
        let resolved = color.resolve(in: environment)
        let luminance = 0.2126 * resolved.linearRed + 0.7152 * resolved.linearGreen + 0.0722 * resolved.linearBlue
        return luminance > 0.3 ? color.mix(with: .black, by: 0.3) : color
    }

    var body: some View {
        Color.clear
            .aspectRatio(1.7, contentMode: .fit)
            .background(background.gradient)
            .overlay {
                GeometryReader { proxy in
                    let side = proxy.size.height * 1.05
                    artworkView(side: side)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .position(x: proxy.size.width - side * 0.36, y: proxy.size.height * 0.56)
                }
                .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }

    @ViewBuilder
    private func artworkView(side: CGFloat) -> some View {
        switch artwork {
        case .pokemon(let id):
            if let pokemon = database.pokemon(id: id) {
                PokemonImage(pokemon: pokemon)
                    .frame(width: side, height: side)
            }
        case .symbol(let name):
            // Tilted like a sticker, the way Apple Music angles its artwork, and kept high enough
            // to clear a long title like "Type-O-Matic" on the smallest iPhone.
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: side * 0.56, height: side * 0.56)
                .rotationEffect(.degrees(-14))
                .offset(x: side * 0.04, y: -side * 0.14)
                .frame(width: side, height: side)
        case .item(let id):
            if let image = BundledImageStore.shared.itemImage(id) {
                Image(image, scale: 1, label: Text(title))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.72, height: side * 0.72)
                    .rotationEffect(.degrees(-14))
                    .offset(x: side * 0.04, y: -side * 0.1)
                    .frame(width: side, height: side)
            }
        }
    }
}

/// Tiles shrink a little while pressed instead of dimming.
private struct BrowseTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview { NavigationStack { SearchBrowseView().navigationTitle("Search") }.previewEnvironment() }
#endif
