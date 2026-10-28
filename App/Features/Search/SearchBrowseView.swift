import NeodexKit
import SwiftUI

/// What Search shows before you type: a tile for each part of the dex and one for every type, in the
/// style of Apple Music's Search.
struct SearchBrowseView: View {
    @Environment(\.database) private var database

    /// The dex sections, each fronted by a Pokémon that suits it.
    private static let sections: [(tab: AppTab, face: Pokemon.ID)] = [
        (.pokedex, "bulbasaur"), (.moves, "smeargle"), (.abilities, "ditto"),
        (.items, "meowth"), (.types, "eevee"), (.natures, "slowpoke"),
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
                            BrowseTile(title: section.tab.title, color: section.tab.tint,
                                       pokemon: database.pokemon(id: section.face))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Types")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(PokemonType.allCases) { type in
                            NavigationLink(value: AppRoute.type(type)) {
                                BrowseTile(title: type.name, color: type.color,
                                           pokemon: Self.typeFaces[type].flatMap(database.pokemon(id:)))
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

/// A colored tile with a Pokémon bleeding off its corner and a bold title.
struct BrowseTile: View {
    @Environment(\.self) private var environment
    var title: String
    var color: Color
    var pokemon: Pokemon?

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
                if let pokemon {
                    GeometryReader { proxy in
                        let side = proxy.size.height * 1.05
                        PokemonImage(pokemon: pokemon)
                            .frame(width: side, height: side)
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                            .position(x: proxy.size.width - side * 0.36, y: proxy.size.height * 0.56)
                    }
                    .accessibilityHidden(true)
                }
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
