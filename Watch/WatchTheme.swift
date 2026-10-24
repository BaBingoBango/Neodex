import NeodexKit
import SwiftUI

/// The watchOS look: a full-screen colour that fades to black behind each screen, tinted by what the
/// screen is about, so a Fire type's page feels warm and a Water type's feels cool. Cards float on it
/// as material, and the few actions live in glass buttons in the corners.
enum WatchTheme {
    /// Neodex blue, for screens that aren't about one Pokémon.
    static let neutral = LinearGradient(colors: [Color(red: 0.10, green: 0.24, blue: 0.62), Color(red: 0.03, green: 0.06, blue: 0.16), .black],
                                        startPoint: .top, endPoint: .bottom)

    /// A gradient from the types' colours down to black.
    static func background(_ types: [PokemonType]) -> LinearGradient {
        let colors: [Color]
        switch types.count {
        case 0: return neutral
        case 1: colors = [types[0].color.opacity(0.8), types[0].color.opacity(0.25), .black]
        default: colors = [types[0].color.opacity(0.8), types[1].color.opacity(0.45), .black]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// A translucent card over the coloured background.
    func watchCard() -> some View {
        padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
