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

/// A tinted tile with an icon, a caption and a one-line value — the "Characteristics" grid. The value's
/// line keeps its height when a long value shrinks to fit, so every tile is the same size.
struct InfoTile: View {
    var systemImage: String
    var label: LocalizedStringKey
    var value: String
    var tint: Color
    @ScaledMetric(relativeTo: .body) private var valueLineHeight: CGFloat = 22

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
                    .frame(height: valueLineHeight)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        // The gap before the trailing label is part of the row, so a tap there opens the move too.
        .contentShape(Rectangle())
    }
}

/// How heights and weights appear across Neodex, chosen in Settings. Until it's set, the locale decides.
nonisolated enum MeasurementUnits: String, CaseIterable, Identifiable {
    case metric, imperial

    static let storageKey = "measurementUnits"

    static var localeDefault: MeasurementUnits { Locale.current.measurementSystem == .us ? .imperial : .metric }

    /// The current choice, for code outside a view; views read `storageKey` with `@AppStorage` so they redraw.
    static var current: MeasurementUnits {
        UserDefaults.standard.string(forKey: storageKey).flatMap(MeasurementUnits.init(rawValue:)) ?? localeDefault
    }

    var id: String { rawValue }

    var name: String {
        switch self {
        case .metric: "Metric (m, kg)"
        case .imperial: "Imperial (ft, lb)"
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

    /// "1.9 m" or "6′03″".
    static func height(_ meters: Double, in units: MeasurementUnits = .current) -> String {
        switch units {
        case .metric: "\(meters.formatted(.number.precision(.fractionLength(1)))) m"
        case .imperial: feetAndInches(meters)
        }
    }

    /// "95.0 kg" or "209.4 lbs".
    static func weight(_ kilograms: Double, in units: MeasurementUnits = .current) -> String {
        switch units {
        case .metric: "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
        case .imperial: "\((kilograms * 2.20462).formatted(.number.precision(.fractionLength(1)))) lbs"
        }
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
