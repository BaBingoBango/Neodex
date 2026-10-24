import NeodexKit
import SwiftUI

/// Data sources, credits and the fan-project disclaimer.
struct AboutView: View {
    @Environment(\.database) private var database

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Neodex")
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    Text("An offline Pokédex for iPhone, iPad, Mac and Apple Watch with Pokémon Showdown teambuilding. Browse every Pokémon, move, Ability and item, check type matchups, build and share teams, and follow Smogon's usage statistics.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section {
                DatasetCard()
            } header: {
                Text("Dataset")
            } footer: {
                Text("The Pokédex ships inside the app, so everything works offline. A fresh dataset arrives with each app update.")
            }
            Section {
                RecognizerCard()
            } header: {
                Text("Scanner")
            } footer: {
                Text("The camera scanner runs entirely on this device. Frames and photos never leave it.")
            }
            #if os(macOS)
            Section {
                Text("Scope Lens watches a mirrored Pokémon Champions battle through ScreenCaptureKit, reads it with on-device OCR and image matching, and advises with deterministic type and damage math. The optional “what's the play” advisor sends the battle state to the Claude API with your own key; nothing else leaves the Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Scope Lens")
            } footer: {
                Text("Usage priors come from Pikalytics' Pokémon Champions ranked data; damage math from the community @smogon/calc.")
            }
            #endif
            if let manifest = database.manifest {
                Section {
                    ForEach(manifest.sources) { source in
                        if let url = URL(string: source.url) {
                            Link(destination: url) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                                    Text(source.license).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Data Sources")
                } footer: {
                    Text("Competitive data comes from Pokémon Showdown; in-game descriptions, Pokédex entries and artwork come from PokeAPI. Usage statistics are fetched live from Smogon.")
                }
            }
            Section {
                Text("Neodex is a fan-made reference. Pokémon and all related names are trademarks of Nintendo, Game Freak and The Pokémon Company. Neodex is not affiliated with or endorsed by them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
    }
}

#if DEBUG
#Preview { PreviewHost { AboutView() } }
#endif
