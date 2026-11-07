import NeodexKit
import SwiftUI

/// Why Home picked these Pokémon, and where that reasoning happens, behind the info button next to
/// Picks for You: a popover on iPad and the Mac, a half sheet on iPhone.
struct PickReasonsView: View {
    @Environment(\.database) private var database
    var picks: [Pokemon]
    var explainer: PickExplainer

    private var blurbs: [PickExplainer.Blurb] {
        explainer.blurbs.filter { blurb in picks.contains { $0.id == blurb.pokemonID } }
    }

    var body: some View {
        // The reasons fit a popover as they are; a half sheet scrolls them when it's shorter.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Why these picks", systemImage: "apple.intelligence")
                .font(.headline)
            if !blurbs.isEmpty {
                ForEach(blurbs) { blurb in
                    if let pokemon = database.pokemon(id: blurb.pokemonID) {
                        HStack(alignment: .top, spacing: 10) {
                            PokemonImage(pokemon: pokemon, kind: .sprite)
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pokemon.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(blurb.text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else if explainer.isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Writing reasons…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Picks share types and egg groups with the Pokémon you've looked at recently.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Label {
                Text(privacyNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(idealWidth: 320, maxWidth: .infinity, alignment: .leading)
    }

    /// Accurate either way: picks are computed from history kept on the device, and the reasons come
    /// from the on-device model, never a server.
    private var privacyNote: String {
        explainer.isAvailable
            ? "All on this device. Picks come from your browsing history, which never leaves it, and Apple Intelligence writes these reasons on device."
            : "All on this device. Picks come from your browsing history, which never leaves it."
    }
}
