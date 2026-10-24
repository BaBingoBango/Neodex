//
//  ScreenStateClassifier.swift
//  Scope Lens
//
//  Phase 2, milestone 1: classifies a captured Champions frame into a screen
//  state — the router that every downstream parser depends on (region maps are
//  state-dependent; see spec §4.4).
//
//  Design:
//  - `classify(tokens:)` is the pure, deterministic core: weighted positional
//    text signatures → argmax over modes, with `unknown` below threshold.
//    Signature positions come from the labeled fixture set (see
//    Diagnostics/ClassifierHarness.swift) in normalized 0–1 coordinates,
//    origin top-left — never absolute pixels.
//  - `FrameObserver` is the seam between "frame" and "tokens". v1 is full
//    Vision OCR (`VisionFrameObserver`); a cheaper pixel-probe pass can slot
//    in behind the same protocol later without touching classification.
//  - Overlays (ability chip, summary panel) co-occur with a primary mode and
//    are detected independently, gated by compatible primaries.
//

import Foundation
import CoreGraphics
import Vision

// MARK: - Screen states

/// Primary screen mode. Extends the spec §4.5 `ScreenState` contract with the
/// lifecycle-only modes (lobby, matchup, communicating) that the live tracker
/// needs to route around; they never mutate battle state.
nonisolated public enum ScreenState: String, CaseIterable, Codable, Sendable {
    case lobby            // ranked-battles menu incl. matchmaking / opponent-found dialogs
    case matchup          // pre-battle VS splash (tiers, ratings)
    case teamPreview      // select-4 screen, both sub-layouts (pre-submit + submitted)
    case command          // FIGHT / POKÉMON action buttons visible
    case moveSelect       // move list with PP on the right column
    case switchSelect     // party list with exact-HP fractions on the left column
    case targetSelect     // per-target effectiveness card
    case communicating    // "Communicating..." — dedicated screen or floating over the arena
    case narration        // message banner over the arena (faints, switches, effects)
    case result           // WON / LOST splash
    case ratingUpdate     // post-battle rank/placement/rating-delta card
    case unknown          // no signature fired (e.g. mid-animation cutscene frames)
}

/// Overlay elements that co-occur with a primary mode.
nonisolated public enum ScreenOverlay: String, CaseIterable, Codable, Sendable {
    case activationChip   // "<Species>'s / <Ability|Item>" proc chip, fixed position at left
                          // mid-screen. Ability and item procs share the SAME chip UI —
                          // positional detection cannot separate them; the BattleState layer
                          // discriminates by text against the closed vocabularies (m4).
    case summaryPanel     // Moves & More / Stats panel with "Hide Summary" button
}

/// Classification result for one frame.
nonisolated public struct ScreenStateClassification: Codable, Sendable {
    public let primary: ScreenState
    public let overlays: Set<ScreenOverlay>
    /// 0–1; blends absolute signal strength with the margin over the runner-up.
    /// Single-weak-signal modes (narration) legitimately sit near ~0.4.
    public let confidence: Double
    /// Per-mode raw scores, for diagnostics and frame-voting later.
    public let scores: [String: Double]
    /// Human-readable signal hits, for diagnostics reports.
    public let matchedSignals: [String]
}

// MARK: - Observation input

/// One recognized text token in normalized 0–1 coordinates, origin top-left.
nonisolated public struct OCRToken: Sendable {
    public let text: String
    public let confidence: Float
    public let center: CGPoint
    public let size: CGSize

    public init(text: String, confidence: Float, center: CGPoint, size: CGSize) {
        self.text = text
        self.confidence = confidence
        self.center = center
        self.size = size
    }
}

/// Seam between frame pixels and classifier input (spec §4.2: the classifier
/// never knows how frames arrive). v1 implementation is full Vision OCR; a
/// cheaper first pass (pixel probes, cached region hashes) can replace or
/// front-run it behind this protocol.
nonisolated public protocol FrameObserver {
    func observe(_ image: CGImage) throws -> [OCRToken]
}

/// Full Vision text recognition, configured identically to the diagnostics
/// OCR dump so fixture-derived signatures transfer 1:1.
nonisolated public final class VisionFrameObserver: FrameObserver {
    public init() {}

    public func observe(_ image: CGImage) throws -> [OCRToken] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [
            "en-US", "ja", "ko", "zh-Hans", "zh-Hant",
            "fr-FR", "de-DE", "es-ES", "it-IT",
        ]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox // normalized, origin bottom-left
            return OCRToken(
                text: candidate.string,
                confidence: candidate.confidence,
                center: CGPoint(x: box.midX, y: 1.0 - box.midY), // flip to top-left origin
                size: CGSize(width: box.width, height: box.height)
            )
        }
    }
}

// MARK: - Classifier

nonisolated public final class ScreenStateClassifier {

    private let observer: FrameObserver

    public init(observer: FrameObserver = VisionFrameObserver()) {
        self.observer = observer
    }

    /// Convenience: observe + classify. The image should already be cropped to
    /// the game viewport (v1 capture sources are full-screen, so callers pass
    /// the whole frame; the crop becomes real when letterboxed sources appear).
    public func classify(image: CGImage) throws -> ScreenStateClassification {
        try classify(tokens: observer.observe(image))
    }

    /// Pure core: weighted positional signatures → argmax.
    public func classify(tokens: [OCRToken]) -> ScreenStateClassification {
        var scores: [ScreenState: Double] = [:]
        var signals: [String] = []

        func add(_ state: ScreenState, _ weight: Double, _ note: String) {
            scores[state, default: 0] += weight
            signals.append("\(state.rawValue)+\(String(format: "%.1f", weight)): \(note)")
        }

        // ---- lobby ------------------------------------------------------
        for t in tokens {
            if t.fuzzyContains("begin matchmaking"), t.inRegion(x: 0.55...0.85, y: 0.76...0.92) {
                add(.lobby, 3.0, "'Begin Matchmaking'")
            }
            if t.fuzzyContains("matchmaking in progress") { add(.lobby, 2.0, "'Matchmaking in Progress'") }
            if t.fuzzyContains("opponent has been found") { add(.lobby, 2.0, "'opponent has been found'") }
            if t.fuzzyContains("check rules") { add(.lobby, 1.0, "'Check Rules'") }
            if t.fuzzyContains("season m") { add(.lobby, 1.0, "'Season M-'") }
        }

        // ---- matchup ----------------------------------------------------
        for t in tokens {
            if t.normalized == "vs", t.size.height >= 0.10, t.inRegion(x: 0.35...0.65, y: 0.30...0.65) {
                add(.matchup, 3.0, "giant 'VS'")
            }
            if t.fuzzyContains("rating") { add(.matchup, 1.5, "'Rating'") }
            if t.fuzzyContains("ball tier") { add(.matchup, 0.75, "'Ball Tier'") }
        }

        // ---- teamPreview --------------------------------------------------
        var sawDone = false, sawOfFourCounter = false
        for t in tokens {
            if t.fuzzyContains("select 4 pok"), t.inRegion(x: 0.30...0.60, y: 0.12...0.32) {
                add(.teamPreview, 3.0, "'Select 4 Pokémon'")
            }
            if t.fuzzyContains("send into battle"), t.inRegion(x: 0.30...0.60, y: 0.15...0.35) {
                add(.teamPreview, 2.0, "'to send into battle'")
            }
            if t.fuzzyContains("preparing for battle"), t.center.y < 0.20 {
                add(.teamPreview, 3.0, "'Preparing for Battle'")
            }
            if t.fuzzyContains("standing by"), t.inRegion(x: 0.12...0.45, y: 0.80...0.95) {
                add(.teamPreview, 2.0, "'Standing By'")
            }
            if t.normalized == "done", t.inRegion(x: 0.18...0.38, y: 0.80...0.92) { sawDone = true }
            if t.normalized.range(of: #"^[0-4]/4$"#, options: .regularExpression) != nil,
               t.inRegion(x: 0.12...0.32, y: 0.80...0.92) { sawOfFourCounter = true }
            if t.fuzzyContains("show summary"), t.center.y > 0.85 {
                add(.teamPreview, 0.5, "'Show Summary'")
            }
        }
        if sawDone && sawOfFourCounter { add(.teamPreview, 2.5, "'Done' + 'n/4' counter") }

        // ---- command ------------------------------------------------------
        for t in tokens {
            if t.normalized == "fight", t.inRegion(x: 0.80...0.96, y: 0.58...0.74) {
                add(.command, 3.0, "'FIGHT' button")
            }
            if t.normalized == "pokemon", t.inRegion(x: 0.76...0.94, y: 0.78...0.92) {
                add(.command, 3.0, "'POKÉMON' button")
            }
        }

        // ---- moveSelect ---------------------------------------------------
        for t in tokens {
            if t.fuzzyContains("move info"), t.inRegion(x: 0.78...0.95, y: 0.30...0.44) {
                add(.moveSelect, 3.0, "'Move Info' button")
            }
            if t.isEffectivenessLabel, t.center.x > 0.70 {
                add(.moveSelect, 0.75, "effectiveness in move column")
            }
        }

        // ---- switchSelect ---------------------------------------------------
        // Party rows: exact-HP fractions down the left column. (Bottom-plate HP
        // in command/moveSelect sits at y≈0.94 — outside this band.)
        let partyHPFractions = tokens.filter {
            $0.isHPFraction && $0.inRegion(x: 0.08...0.30, y: 0.12...0.75)
        }
        if partyHPFractions.count >= 2 {
            add(.switchSelect, 3.0, "\(partyHPFractions.count) party HP fractions in left column")
        }
        let benchPercents = tokens.filter {
            $0.isPercent && $0.inRegion(x: 0.80...0.94, y: 0.30...0.88)
        }
        if !benchPercents.isEmpty, partyHPFractions.count >= 2 {
            add(.switchSelect, 1.0, "\(benchPercents.count) opponent bench % on right")
        }

        // ---- targetSelect ---------------------------------------------------
        for t in tokens {
            if t.normalized == "close", t.inRegion(x: 0.58...0.80, y: 0.86...0.96) {
                add(.targetSelect, 2.5, "'Close' button")
            }
        }
        let targetEffectiveness = tokens.filter {
            $0.isEffectivenessLabel && $0.inRegion(x: 0.22...0.72, y: 0.06...0.64)
        }
        if !targetEffectiveness.isEmpty {
            add(.targetSelect, min(3.0, Double(targetEffectiveness.count) * 1.5),
                "\(targetEffectiveness.count) per-target effectiveness labels")
        }

        // ---- communicating --------------------------------------------------
        for t in tokens {
            if t.fuzzyContains("communicating"), t.inRegion(x: 0.38...0.62, y: 0.20...0.36) {
                add(.communicating, 3.0, "'Communicating...'")
            }
        }

        // ---- result ---------------------------------------------------------
        for t in tokens where t.size.height >= 0.10 {
            let n = t.normalized
            // OCR renders the stylized splash as e.g. "WOND" / "LOST...".
            if n.contains("won") || n.contains("lost") {
                add(.result, 3.0, "giant '\(t.text)'")
            }
        }

        // ---- ratingUpdate ---------------------------------------------------
        // Post-battle rank card. "Placement" ALSO appears on the live lobby's
        // ranked card, so lobby's own signals (Begin Matchmaking etc., ≥5.0)
        // must keep outranking this 3.0; the signed rating delta under the
        // card is the post-battle-only corroborator.
        for t in tokens {
            if t.fuzzyContains("placement") {
                add(.ratingUpdate, 3.0, "'Placement'")
            }
            if t.isRatingDelta {
                add(.ratingUpdate, 1.0, "rating delta '\(t.text)'")
            }
        }

        // ---- narration (deliberately weak: wins only when nothing else fires)
        // Sparse-frame gate: every real narration fixture carries ≤8 tokens,
        // while generic game menus are text-dense (20–40) and always drop
        // something into the banner band — without the gate they'd read as
        // narration instead of unknown (seen live while menu-browsing).
        let bannerTokens = tokens.filter {
            $0.confidence >= 0.8
                && $0.size.width >= 0.04
                && $0.inRegion(x: 0.22...0.68, y: 0.66...0.76)
        }
        if !bannerTokens.isEmpty, tokens.count <= 14 {
            add(.narration, 1.2, "banner text: '\(bannerTokens[0].text.prefix(40))'")
        }

        // ---- argmax + confidence -------------------------------------------
        let ranked = scores.sorted { $0.value > $1.value }
        let top = ranked.first
        let runnerUp = ranked.dropFirst().first?.value ?? 0

        let primary: ScreenState
        let confidence: Double
        if let top, top.value >= 1.0 {
            primary = top.key
            let strength = min(1.0, top.value / 3.0)
            let margin = 1.0 - min(1.0, runnerUp / max(top.value, .ulpOfOne)) / 2.0
            confidence = strength * margin
        } else {
            primary = .unknown
            // Zero signals = confidently "not a known screen"; stray sub-threshold
            // signals lower that a bit.
            confidence = top == nil ? 1.0 : 0.6
        }

        let overlays = detectOverlays(tokens: tokens, primary: primary, signals: &signals)

        return ScreenStateClassification(
            primary: primary,
            overlays: overlays,
            confidence: (confidence * 100).rounded() / 100,
            scores: Dictionary(uniqueKeysWithValues: scores.map { ($0.key.rawValue, $0.value) }),
            matchedSignals: signals
        )
    }

    // MARK: Overlays

    private func detectOverlays(
        tokens: [OCRToken], primary: ScreenState, signals: inout [String]
    ) -> Set<ScreenOverlay> {
        var overlays: Set<ScreenOverlay> = []

        // Summary panel: "Hide Summary" button, or the Moves & More / Stats tab
        // pair (belt and braces — the button can be laser-washed).
        let hideSummary = tokens.contains {
            $0.fuzzyContains("hide summary") && $0.center.y > 0.85
        }
        let movesTab = tokens.contains { $0.fuzzyContains("moves & more") && $0.center.y < 0.16 }
        let statsTab = tokens.contains { $0.normalized == "stats" && $0.center.y < 0.16 }
        if hideSummary || (movesTab && statsTab) {
            overlays.insert(.summaryPanel)
            signals.append("overlay summaryPanel: \(hideSummary ? "'Hide Summary'" : "tab pair")")
        }

        // Activation chip (ability OR item proc): two stacked short tokens at a
        // fixed left-of-center spot.
        // Positional-only detection collides with teamPreview's species/item rows
        // (same geometry), so gate on primaries the chip can actually appear over:
        // battle-arena frames, including text-free animation frames (unknown).
        let chipCompatible: Set<ScreenState> = [.narration, .command, .communicating, .unknown]
        if chipCompatible.contains(primary) {
            let tops = tokens.filter {
                $0.inRegion(x: 0.08...0.28, y: 0.44...0.53) && $0.size.width <= 0.16
            }
            let bottoms = tokens.filter {
                $0.inRegion(x: 0.08...0.28, y: 0.51...0.60) && $0.size.width <= 0.16
            }
            for a in tops {
                for b in bottoms {
                    let dy = b.center.y - a.center.y
                    guard dy >= 0.02, dy <= 0.08, abs(a.center.x - b.center.x) <= 0.06 else { continue }
                    overlays.insert(.activationChip)
                    signals.append("overlay activationChip: '\(a.text)' / '\(b.text)'")
                }
            }
        }

        return overlays
    }
}

// MARK: - Token matching helpers

nonisolated extension OCRToken {
    /// Lowercased, diacritic-stripped, punctuation-trimmed text.
    var normalized: String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
    }

    func inRegion(x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>) -> Bool {
        x.contains(center.x) && y.contains(center.y)
    }

    /// True when `needle` appears in the normalized text, tolerating small OCR
    /// wobble (≤1 edit for short needles, ≤2 for longer) at any alignment.
    func fuzzyContains(_ needle: String) -> Bool {
        let haystack = normalized
        if haystack.contains(needle) { return true }
        let maxEdits = needle.count <= 8 ? 1 : 2
        return haystack.containsWithinEdits(needle, maxEdits: maxEdits)
    }

    /// "154/154"-style exact HP. Vision misreads the slash as '7' or '1', so an
    /// odd-length pure digit run splits at the middle (spec §7: parse digit runs).
    var isHPFraction: Bool {
        let n = normalized.replacingOccurrences(of: " ", with: "")
        if let slash = n.firstIndex(of: "/") {
            let cur = n[n.startIndex..<slash], max = n[n.index(after: slash)...]
            return !cur.isEmpty && !max.isEmpty
                && cur.allSatisfy(\.isNumber) && max.allSatisfy(\.isNumber)
                && max.count <= 4 && cur.count <= 4
        }
        // Slashless misread: odd length, all digits, middle digit '7' or '1'.
        guard n.count >= 5, n.count <= 9, n.count % 2 == 1, n.allSatisfy(\.isNumber) else { return false }
        let mid = n[n.index(n.startIndex, offsetBy: n.count / 2)]
        return mid == "7" || mid == "1"
    }

    var isPercent: Bool {
        normalized.range(of: #"^\d{1,3}\s?%?\)?$"#, options: .regularExpression) != nil
            && text.contains("%")
    }

    var isEffectivenessLabel: Bool {
        // Leading glyph OCRs as "O"/"A"/"®"; match on the word itself.
        fuzzyContains("effective")
    }

    /// "−17.464"-style post-battle rating change (sign renders as -, −, –, or +).
    var isRatingDelta: Bool {
        text.trimmingCharacters(in: .whitespaces)
            .range(of: #"^[-−–+]\d{1,3}[.,]\d{3}$"#, options: .regularExpression) != nil
    }
}

nonisolated private extension String {
    /// Approximate substring search (Sellers' algorithm): does any substring of
    /// `self` match `needle` within `maxEdits` Levenshtein edits? Match start
    /// and end float freely in the haystack; O(|self|·|needle|) per token.
    func containsWithinEdits(_ needle: String, maxEdits: Int) -> Bool {
        let hay = Array(self), pat = Array(needle)
        guard !pat.isEmpty else { return true }
        guard !hay.isEmpty else { return pat.count <= maxEdits }
        var prev = Array(0...pat.count)
        var cur = [Int](repeating: 0, count: pat.count + 1)
        for i in 1...hay.count {
            cur[0] = 0 // a match may start at any haystack position for free
            for j in 1...pat.count {
                let cost = hay[i - 1] == pat[j - 1] ? 0 : 1
                cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            if cur[pat.count] <= maxEdits { return true } // ...and end anywhere
            swap(&prev, &cur)
        }
        return false
    }
}
