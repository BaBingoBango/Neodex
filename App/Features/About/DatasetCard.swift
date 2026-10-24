import NeodexKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The bundled dataset, presented like an App Store update with the blueprint developer icon.
/// On iOS, tapping the icon is a small easter egg: it switches the Home Screen icon to the blueprint version and back.
struct DatasetCard: View {
    @Environment(\.database) private var database
    @State private var usingDevIcon = Self.devIconActive
    @State private var showsAllNotes = false

    private var manifest: DataManifest? { database.manifest }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                icon
                VStack(alignment: .leading, spacing: 3) {
                    Text("Neodex Dataset")
                        .font(.headline)
                    Text("Version \(manifest?.displayVersion ?? "—")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let generated = manifest?.generatedAt {
                        Text(generated.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                Text("INSTALLED")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            if let notes = manifest?.releaseNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What's New")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(notes.prefix(showsAllNotes ? notes.count : 2).enumerated()), id: \.offset) { _, note in
                        Text("• " + note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if notes.count > 2 {
                        Button(showsAllNotes ? "less" : "more") {
                            withAnimation { showsAllNotes.toggle() }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            countsGrid
        }
        .padding(.vertical, 6)
    }

    private var countsGrid: some View {
        let counts: [(label: LocalizedStringKey, value: Int)] = [
            ("Pokémon", database.pokemon.count), ("Species", database.species.count), ("Moves", database.moves.count),
            ("Abilities", database.abilities.count), ("Items", database.items.count),
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(counts.indices, id: \.self) { index in
                StatPill(label: counts[index].label, value: counts[index].value.formatted())
            }
        }
    }

    /// On iOS the icon is a button that swaps the Home Screen icon; the Mac just shows it.
    @ViewBuilder
    private var icon: some View {
        #if os(iOS)
        Button(action: toggleIcon) { iconArtwork }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact, trigger: usingDevIcon)
            .accessibilityLabel(usingDevIcon ? "Switch back to the standard app icon" : "Switch to the blueprint app icon")
        #else
        iconArtwork
            .accessibilityLabel("Neodex developer icon")
        #endif
    }

    private var iconArtwork: some View {
        Image(.devIconArtwork)
            .resizable()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14.5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14.5, style: .continuous).strokeBorder(.quaternary, lineWidth: 0.5))
    }

    private static var devIconActive: Bool {
        #if os(iOS)
        UIApplication.shared.alternateIconName == "DevIcon"
        #else
        false
        #endif
    }

    private func toggleIcon() {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let target: String? = usingDevIcon ? nil : "DevIcon"
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(target)
                usingDevIcon = target != nil
            } catch {
                // The system shows its own alert; nothing else to do.
            }
        }
        #endif
    }
}

#if DEBUG
#Preview { PreviewHost { AboutView() } }
#endif
