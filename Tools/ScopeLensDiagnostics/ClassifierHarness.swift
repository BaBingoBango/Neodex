//
//  ClassifierHarness.swift
//  ScopeLens Diagnostics — verifies ScreenStateClassifier against the labeled
//  still fixtures (folder structure = ground truth; battle sub-modes labeled
//  from eyeballed frames).
//
//  Build & run (from repo root — compiles the app-target classifier alongside):
//    swiftc -O Tools/ScopeLensDiagnostics/ClassifierHarness.swift "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" \
//      -o /tmp/classifierharness && /tmp/classifierharness
//
//  Runs every fixture at full resolution AND at 0.5 scale (the offline session
//  recorder OCRs half-res frames for speed — both must pass before trusting it).
//  Exit code: 0 iff all fixtures match at both scales.
//

import Foundation
import CoreGraphics
import ImageIO

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

// MARK: - Ground truth

struct Expectation {
    let primary: ScreenState
    let overlays: Set<ScreenOverlay>
    init(_ primary: ScreenState, _ overlays: Set<ScreenOverlay> = []) {
        self.primary = primary
        self.overlays = overlays
    }
}

/// Keyed by "<mode folder>/<file stem>". Folder = truth for the mode family;
/// battle sub-modes were pinned by looking at the frames (session 2 kickoff).
let groundTruth: [String: Expectation] = [
    "Lobby/Matchmaking": .init(.lobby),
    "Lobby/Opponent Found": .init(.lobby),
    "Matchup/Matchup": .init(.matchup),
    "Team Preview/Team Preview Initial": .init(.teamPreview),
    "Team Preview/Extra Team Example 1": .init(.teamPreview),
    "Team Preview/Extra Team Example 2": .init(.teamPreview),
    "Team Preview/Team with Ice Type": .init(.teamPreview),
    "Team Preview/Team with Electric Type": .init(.teamPreview),
    "Team Preview/Team Preview Selected with Summary": .init(.teamPreview, [.summaryPanel]),
    "Team Preview/Team Preview Submitted": .init(.teamPreview),
    "Battle/IMG_6036": .init(.command),
    "Battle/IMG_6038": .init(.moveSelect),
    "Battle/Switch Menu": .init(.switchSelect, [.summaryPanel]),
    "Battle/Move Target": .init(.targetSelect),
    "Battle/Communicating": .init(.communicating),
    "Battle/Faint Narration": .init(.narration),
    "Battle/Switch Narration": .init(.narration),
    "Battle/IMG_6034": .init(.narration),
    "Battle/IMG_6037": .init(.narration),
    "Battle/Ability Chip With Narration": .init(.narration, [.activationChip]),
    "Battle/IMG_6035": .init(.narration, [.activationChip]),
    "Result/Result": .init(.result),
    // Auto-harvested by the live-capture probe (2026-07-02 ranked battle) —
    // the viewport crop of the post-battle rank card, promoted to a fixture.
    "Rating Update/Rating Update": .init(.ratingUpdate),
]

// MARK: - Image loading

func loadCGImage(url: URL, scale: CGFloat) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let full = CGImageSourceCreateImageAtIndex(source, 0, [
              kCGImageSourceShouldCache: false
          ] as CFDictionary)
    else { return nil }
    if scale >= 1.0 { return full }

    let w = Int(CGFloat(full.width) * scale), h = Int(CGFloat(full.height) * scale)
    guard let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .medium
    ctx.draw(full, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()
}

// MARK: - Run

@main
struct ClassifierHarness {
    static func main() {
        let fixturesRoot = URL(fileURLWithPath: "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max")
        guard FileManager.default.fileExists(atPath: fixturesRoot.path) else {
            fputs("error: run from the repo root ('Scope Lens' project directory)\n", stderr)
            exit(2)
        }

        let heics = (FileManager.default.enumerator(at: fixturesRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { ["heic", "png"].contains($0.pathExtension.lowercased()) } ?? [])
            .sorted { $0.path < $1.path }

        let classifier = ScreenStateClassifier()
        var failures = 0

        for scale in [CGFloat(1.0), 0.5] {
            print("═══ scale \(scale) ═══")
            var passed = 0, total = 0

            for url in heics {
                let key = url.deletingPathExtension().path
                    .replacingOccurrences(of: fixturesRoot.path + "/", with: "")
                guard let expected = groundTruth[key] else {
                    print("  ⚠️ no ground truth for \(key) — add it to the manifest")
                    failures += 1
                    continue
                }
                total += 1

                guard let image = loadCGImage(url: url, scale: scale) else {
                    print("  ❌ \(key): failed to load image")
                    failures += 1
                    continue
                }

                do {
                    let got = try classifier.classify(image: image)
                    let primaryOK = got.primary == expected.primary
                    let overlaysOK = got.overlays == expected.overlays
                    let overlayStr = got.overlays.isEmpty
                        ? "" : " +[\(got.overlays.map(\.rawValue).sorted().joined(separator: ","))]"

                    if primaryOK && overlaysOK {
                        passed += 1
                        print("  ✅ \(key.padded(48)) → \(got.primary.rawValue)\(overlayStr) (conf \(String(format: "%.2f", got.confidence)))")
                    } else {
                        failures += 1
                        let expOverlay = expected.overlays.isEmpty
                            ? "" : " +[\(expected.overlays.map(\.rawValue).sorted().joined(separator: ","))]"
                        print("  ❌ \(key.padded(48)) → \(got.primary.rawValue)\(overlayStr) (conf \(String(format: "%.2f", got.confidence))), expected \(expected.primary.rawValue)\(expOverlay)")
                        for s in got.matchedSignals { print("       signal: \(s)") }
                        let ranked = got.scores.sorted { $0.value > $1.value }.prefix(4)
                        print("       scores: \(ranked.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }.joined(separator: " "))")
                    }
                } catch {
                    failures += 1
                    print("  ❌ \(key): classify threw \(error)")
                }
            }
            print("  — \(passed)/\(total) at scale \(scale)\n")
        }

        exit(failures == 0 ? 0 : 1)
    }
}

private extension String {
    func padded(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
