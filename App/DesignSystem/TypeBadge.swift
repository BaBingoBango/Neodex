import NeodexKit
import SwiftUI

/// The monospaced, uppercase type pill used throughout Neodex.
struct TypeBadge: View {
    var type: PokemonType
    var size: Size = .regular

    enum Size {
        case small, regular, large

        var font: Font {
            switch self {
            case .small: .system(.caption, design: .monospaced).weight(.semibold)
            case .regular: .system(.subheadline, design: .monospaced).weight(.semibold)
            case .large: .system(.title3, design: .monospaced).weight(.semibold)
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
            case .regular: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
            case .large: EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18)
            }
        }
    }

    var body: some View {
        Text(type.name.uppercased())
            .font(size.font)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(size.padding)
            .foregroundStyle(type.contrastingTextColor)
            .background(type.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel("\(type.name) type")
    }
}

/// A horizontal row of type badges.
struct TypeBadgeRow: View {
    var types: [PokemonType]
    var size: TypeBadge.Size = .regular

    var body: some View {
        HStack(spacing: 6) {
            ForEach(types) { TypeBadge(type: $0, size: size) }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TypeBadgeRow(types: [.grass, .poison], size: .small)
        TypeBadgeRow(types: [.fire, .flying])
        TypeBadgeRow(types: [.electric], size: .large)
        TypeBadgeRow(types: PokemonType.allCases.prefix(9).map { $0 }, size: .small)
    }
    .padding()
}
