import NeodexKit
import SwiftUI

/// The monospaced, uppercase type pill used throughout Neodex.
struct TypeBadge: View {
    var type: PokemonType
    var size: Size = .regular

    enum Size {
        /// For narrow cards, such as Home's shelves.
        case compact
        case small, regular, large

        var font: Font {
            switch self {
            case .compact: .system(.caption2, design: .monospaced).weight(.semibold)
            case .small: .system(.caption, design: .monospaced).weight(.semibold)
            case .regular: .system(.subheadline, design: .monospaced).weight(.semibold)
            case .large: .system(.title3, design: .monospaced).weight(.semibold)
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .compact: EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
            case .small: EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
            case .regular: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
            case .large: EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18)
            }
        }

        /// The gap between badges in a row.
        var spacing: CGFloat { self == .compact ? 4 : 6 }
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

    /// Stacks the badges when they don't fit side by side, instead of shrinking or truncating them
    /// one by one (FIGHTING and POISON don't fit across a 130-point card).
    var stacksWhenNarrow = false

    var body: some View {
        if stacksWhenNarrow {
            ViewThatFits(in: .horizontal) {
                row
                VStack(spacing: size.spacing) { badges }
            }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: size.spacing) { badges }
    }

    private var badges: some View {
        ForEach(types) { TypeBadge(type: $0, size: size) }
    }
}

#Preview {
    VStack(spacing: 12) {
        TypeBadgeRow(types: [.grass, .poison], size: .small)
        TypeBadgeRow(types: [.fire, .flying])
        TypeBadgeRow(types: [.electric], size: .large)
        TypeBadgeRow(types: PokemonType.allCases.prefix(9).map { $0 }, size: .small)
        TypeBadgeRow(types: [.fighting, .poison], size: .compact, stacksWhenNarrow: true)
            .frame(width: 110)
    }
    .padding()
}
