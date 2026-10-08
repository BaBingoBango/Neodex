import NeodexKit
import SwiftUI

extension PokemonType {
    /// Neodex's type palette. Fire, Water, Electric and Grass use the system colors so they adapt to
    /// dark mode and accessibility settings; the rest come from the asset catalog.
    var color: Color {
        switch self {
        case .fire: .red
        case .water: .blue
        case .electric: .yellow
        case .grass: .green
        default: Color(rawValue)
        }
    }

    /// A readable foreground for text drawn on top of `color`.
    var contrastingTextColor: Color {
        switch self {
        case .electric, .ice, .normal, .ground, .fairy, .flying, .bug, .steel: .black
        default: .white
        }
    }
}

extension MoveCategory {
    var color: Color {
        switch self {
        case .physical: .orange
        case .special: .blue
        case .status: .gray
        }
    }

    var systemImage: String {
        switch self {
        case .physical: "burst.fill"
        case .special: "sparkles"
        case .status: "circle.dashed"
        }
    }
}

extension Stat {
    /// Colors used for stat bars and the stats donut, matching the original Neodex palette.
    var color: Color {
        switch self {
        case .hp: .green
        case .attack: .orange
        case .defense: .gray
        case .specialAttack: .pink
        case .specialDefense: Color("gold")
        case .speed: Color("flying")
        }
    }
}
