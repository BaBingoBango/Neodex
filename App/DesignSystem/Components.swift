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

/// A tinted tile with an icon, a caption, a value and an optional detail line — the "Characteristics"
/// grid. Every tile reserves the detail line so the grid's rows stay the same height.
struct InfoTile: View {
    var systemImage: String
    var label: LocalizedStringKey
    var value: String
    var detail: String? = nil
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(detail ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
nonisolated enum Measurements {
    /// Feet and inches, rounding to the nearest inch first so 0.6 m is 2′00″ rather than 1′12″.
    static func feetAndInches(_ meters: Double) -> String {
        let totalInches = Int((meters * 39.3701).rounded())
        return "\(totalInches / 12)′\(String(format: "%02d", totalInches % 12))″"
    }

    static func height(_ meters: Double) -> String {
        let metric = meters.formatted(.number.precision(.fractionLength(1)))
        return "\(metric) m · \(feetAndInches(meters))"
    }

    static func weight(_ kilograms: Double) -> String {
        let pounds = kilograms * 2.20462
        return "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg · \(pounds.formatted(.number.precision(.fractionLength(1)))) lbs"
    }

    /// Height with the user's unit system first and the other second, e.g. `("6′03″", "1.9 m")`.
    static func heightParts(_ meters: Double) -> (primary: String, secondary: String) {
        let imperial = feetAndInches(meters)
        let metric = "\(meters.formatted(.number.precision(.fractionLength(1)))) m"
        return Locale.current.measurementSystem == .us ? (imperial, metric) : (metric, imperial)
    }

    /// Weight with the user's unit system first and the other second.
    static func weightParts(_ kilograms: Double) -> (primary: String, secondary: String) {
        let imperial = "\((kilograms * 2.20462).formatted(.number.precision(.fractionLength(1)))) lbs"
        let metric = "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
        return Locale.current.measurementSystem == .us ? (imperial, metric) : (metric, imperial)
    }

    /// `("87.5% ♂", "12.5% ♀")`, or `("Genderless", nil)`.
    static func genderParts(_ maleRatio: Double?) -> (primary: String, secondary: String?) {
        guard let maleRatio else { return ("Genderless", nil) }
        let male = (maleRatio * 100).formatted(.number.precision(.fractionLength(0...1)))
        let female = ((1 - maleRatio) * 100).formatted(.number.precision(.fractionLength(0...1)))
        return ("\(male)% ♂", "\(female)% ♀")
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
