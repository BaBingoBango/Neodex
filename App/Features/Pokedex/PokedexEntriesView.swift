import NeodexKit
import SwiftUI

/// Every Pokédex entry for a Pokémon, newest game first, with the games each one appeared in.
struct PokedexEntriesView: View {
    var pokemon: Pokemon

    @State private var speaker = DexSpeaker()

    var body: some View {
        List {
            ForEach(Array(pokemon.dexEntries.enumerated()), id: \.offset) { _, entry in
                VStack(alignment: .leading, spacing: 10) {
                    FlowLayout(spacing: 6) {
                        ForEach(entry.games, id: \.self) { game in
                            Text(game)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(pokemon.primaryType.color.opacity(0.18), in: Capsule())
                        }
                    }
                    Text(entry.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
                .contextMenu {
                    Button("Read Aloud", systemImage: "speaker.wave.2") { speaker.speak(entry: entry.text, for: pokemon) }
                    Button("Copy", systemImage: "doc.on.doc") { Clipboard.string = entry.text }
                }
            }
        }
        .navigationTitle("Pokédex Entries")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
                Button {
                    if speaker.isSpeaking {
                        speaker.stop()
                    } else {
                        speaker.speak(entry: pokemon.dexEntries.map(\.text).joined(separator: " "), for: pokemon)
                    }
                } label: {
                    Label("Read All", systemImage: "speaker.wave.2.fill")
                        .symbolEffect(.variableColor.iterative, isActive: speaker.isSpeaking)
                }
            }
        }
        .onDisappear { speaker.stop() }
    }
}

#if DEBUG
#Preview { PreviewHost { PokedexEntriesView(pokemon: PokedexDatabase.preview.previewPokemon("Garchomp")) } }
#endif
