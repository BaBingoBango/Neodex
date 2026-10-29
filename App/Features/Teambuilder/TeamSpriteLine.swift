import NeodexKit
import SwiftData
import SwiftUI

/// The team lined up like a battle preview: six overlapping, animated sprites, with Poké Balls for empty slots.
/// Tapping a sprite opens that member, like its card, and tapping an empty slot adds one.
struct TeamSpriteLine: View {
    @Environment(\.database) private var database
    var team: SavedTeam
    var onOpen: (TeamMember) -> Void
    var onAdd: () -> Void

    var body: some View {
        // Six equal slots share the width; wide sprites spill over their neighbours like a battle preview.
        HStack(spacing: 0) {
            ForEach(0..<SavedTeam.maximumMembers, id: \.self) { slot in
                let member = slot < team.members.count ? team.members[slot] : nil
                let pokemon = member.flatMap { database.pokemon(id: $0.pokemonID) }
                Button {
                    if let member { onOpen(member) } else { onAdd() }
                } label: {
                    Group {
                        if let member, let pokemon {
                            AnimatedSpriteView(pokemon: pokemon, shiny: member.shiny, maxHeight: 64)
                        } else {
                            PokeBallIcon()
                                .frame(width: 28, height: 28)
                                .opacity(0.22)
                        }
                    }
                    // Each slot takes taps across its own share of the width, even where a neighbour's sprite spills over.
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(pokemon?.displayName ?? (member == nil ? "Add Pokémon" : "Pokémon"))
                // VoiceOver needs only one of the empty slots.
                .accessibilityHidden(slot > team.members.count)
                .zIndex(Double(SavedTeam.maximumMembers - slot))
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// A simple Poké Ball drawn with shapes.
