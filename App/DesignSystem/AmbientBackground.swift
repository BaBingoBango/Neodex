import SwiftUI

/// A slow, soft colour wash with a faint blueprint grid, used behind the top of Home.
/// The mesh drifts gently; under Reduce Motion it holds still.
struct AmbientBackground: View {
    /// Two to four colours; the mesh cycles through them.
    var colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate / 16
            ZStack {
                MeshGradient(width: 3, height: 3, points: Self.points(at: time), colors: meshColors)
                BlueprintGrid()
                    .opacity(colorScheme == .dark ? 0.07 : 0.09)
            }
        }
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Pastel versions of the palette: each colour is mixed most of the way into the background so
    /// the wash reads as a tint, not a block of colour. The background itself fills the gaps.
    private var meshColors: [Color] {
        let background = Color(.systemGroupedBackground)
        let palette = (colors.isEmpty ? [Color.accentColor] : colors).map { $0.mix(with: background, by: colorScheme == .dark ? 0.78 : 0.72) }
        return (0..<9).map { index in index == 4 || index.isMultiple(of: 2) ? palette[index % palette.count] : background }
    }

    /// Corners stay pinned and edge points slide along their edge, so the mesh always covers the
    /// whole rectangle; only the centre wanders freely.
    static func points(at time: Double) -> [SIMD2<Float>] {
        func along(_ value: Float, _ seed: Double) -> Float {
            min(max(value + Float(sin(time * 1.1 + seed) * 0.18), 0.15), 0.85)
        }
        let center = SIMD2(along(0.5, 3), min(max(0.5 + Float(cos(time * 0.9 + 5.1) * 0.18), 0.2), 0.8))
        return [
            SIMD2(0, 0), SIMD2(along(0.5, 1), 0), SIMD2(1, 0),
            SIMD2(0, along(0.5, 2)), center, SIMD2(1, along(0.5, 4)),
            SIMD2(0, 1), SIMD2(along(0.5, 5), 1), SIMD2(1, 1),
        ]
    }
}

/// Thin grid lines, like the developer icon's blueprint background.
struct BlueprintGrid: View {
    var spacing: CGFloat = 28

    var body: some View {
        Canvas { graphics, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            graphics.stroke(path, with: .color(.primary), lineWidth: 0.5)
        }
    }
}

extension View {
    /// Cards in a horizontal shelf shrink and fade as they leave the screen.
    func shelfTransition() -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                .opacity(phase.isIdentity ? 1 : 0.6)
        }
    }
}

#Preview {
    ZStack(alignment: .top) {
        Color(.systemGroupedBackground).ignoresSafeArea()
        AmbientBackground(colors: [.blue, .purple, .orange]).frame(height: 420).ignoresSafeArea()
        Text("Neodex").font(.largeTitle.bold()).padding(.top, 80)
    }
}
