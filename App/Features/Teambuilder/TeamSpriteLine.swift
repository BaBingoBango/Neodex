import NeodexKit
import SwiftData
import SwiftUI

/// The team lined up like a battle preview: six overlapping, animated sprites, with Poké Balls for empty slots.
struct TeamSpriteLine: View {
    @Environment(\.database) private var database
    var team: SavedTeam

    var body: some View {
        // Six equal slots share the width; wide sprites spill over their neighbours like a battle preview.
        HStack(spacing: 0) {
            ForEach(0..<SavedTeam.maximumMembers, id: \.self) { slot in
                Group {
                    if slot < team.members.count, let pokemon = database.pokemon(id: team.members[slot].pokemonID) {
                        AnimatedSpriteView(pokemon: pokemon, shiny: team.members[slot].shiny, maxHeight: 64)
                            .zIndex(Double(SavedTeam.maximumMembers - slot))
                    } else {
                        PokeBallIcon()
                            .frame(width: 28, height: 28)
                            .opacity(0.22)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 72)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(team.members.isEmpty ? "No Pokémon yet" : "\(team.members.count) of six Pokémon")
    }
}

/// A simple Poké Ball drawn with shapes.
struct PokeBallIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let line = max(2, size * 0.09)
            ZStack {
                Circle().fill(.white)
                Circle()
                    .trim(from: 0.5, to: 1)
                    .fill(.red)
                Rectangle()
                    .fill(.black)
                    .frame(height: line)
                Circle()
                    .strokeBorder(.black, lineWidth: line)
                Circle()
                    .fill(.white)
                    .strokeBorder(.black, lineWidth: line)
                    .frame(width: size * 0.34, height: size * 0.34)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    HStack { PokeBallIcon().frame(width: 60); PokeBallIcon().frame(width: 30) }.padding()
}
