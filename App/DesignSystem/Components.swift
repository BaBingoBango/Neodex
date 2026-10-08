import NeodexKit
import SwiftUI

/// Large section title used inside detail screens.
struct SectionTitle: View {
    var title: LocalizedStringKey
    var trailing: AnyView? = nil

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A tinted tile with an icon, a caption and a value — the "Characteristics" grid.
struct InfoTile: View {
    var systemImage: String
    var label: LocalizedStringKey
    var value: String
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A rounded card background matching Neodex's feature gallery.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// A compact labelled value, e.g. "Power 90".
struct StatPill: View {
    var label: LocalizedStringKey
    var value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Small move row used in Pokémon learnsets, move lists and team editors.
struct MoveRow: View {
    var move: Move
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            TypeBadge(type: move.type, size: .small)
                .frame(width: 78, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(move.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Image(systemName: move.category.systemImage)
                        .foregroundStyle(move.category.color)
                        .font(.caption2)
                        .accessibilityLabel(move.category.name)
                    Text("\(move.basePowerText) · \(move.accuracyText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

/// Measurement formatting shared by detail screens.
enum Measurements {
    static func height(_ meters: Double) -> String {
        let totalInches = meters * 39.3701
        let feet = Int(totalInches / 12)
        let inches = Int((totalInches - Double(feet) * 12).rounded())
        let metric = meters.formatted(.number.precision(.fractionLength(1)))
        return "\(metric) m · \(feet)′\(String(format: "%02d", inches))″"
    }

    static func weight(_ kilograms: Double) -> String {
        let pounds = kilograms * 2.20462
        return "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg · \(pounds.formatted(.number.precision(.fractionLength(1)))) lbs"
    }

    static func genderRatio(_ maleRatio: Double?) -> String {
        guard let maleRatio else { return "Genderless" }
        let male = (maleRatio * 100).formatted(.number.precision(.fractionLength(0...1)))
        let female = ((1 - maleRatio) * 100).formatted(.number.precision(.fractionLength(0...1)))
        return "\(male)% ♂ · \(female)% ♀"
    }

    static func evYield(_ block: StatBlock?) -> String {
        guard let block, block.total > 0 else { return "—" }
        return block.nonZero.map { "\($0.value) \($0.stat.shortName)" }.joined(separator: ", ")
    }
}
