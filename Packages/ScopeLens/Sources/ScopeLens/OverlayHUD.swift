//
//  OverlayHUD.swift
//  Scope Lens
//
//  Phase 3, m10-A: the glanceable overlay — Phase 3's remaining spec item
//  ("live overlay + toggle-able LLM advisor"). A compact always-on-top
//  panel the pilot can park next to the QuickTime mirror and steer by
//  during the ~40s move timer: top matchup lines with KO badges, speed
//  order, perish clocks, and the latest advice.
//
//  Window mechanics: a borderless NON-ACTIVATING NSPanel (clicking Ask
//  never steals focus from the game), floating level, joins all Spaces and
//  full-screen auxiliary, draggable by background, frame position persisted
//  via autosave. Content feeds off LiveTrackerModel.shared — the same
//  published state the Battle Log renders.
//

import SwiftUI
import AppKit

// MARK: - Panel controller

@MainActor
public final class OverlayHUDController {

    public static let shared = OverlayHUDController()

    private var panel: NSPanel?

    public var isVisible: Bool { panel?.isVisible ?? false }

    public func toggle() {
        if isVisible { hide() } else { show() }
    }

    public func show() {
        if panel == nil { panel = Self.makePanel() }
        panel?.orderFrontRegardless()
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    private static func makePanel() -> NSPanel {
        let hosting = NSHostingView(rootView: OverlayHUDView())
        hosting.sizingOptions = [.preferredContentSize]

        let panel = NSPanel(
            contentRect: NSRect(x: 120, y: 140, width: 360, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.setFrameAutosaveName("ScopeLensOverlayHUD")
        return panel
    }
}

// MARK: - Live wrapper (model → content)

struct OverlayHUDView: View {
    @ObservedObject private var model = LiveTrackerModel.shared
    @AppStorage("overlayAutoOpensOnBattle") private var autoOpen = true

    var body: some View {
        OverlayContentView(
            stateLines: model.battleStateLines,
            outcome: model.battleOutcome,
            matchup: model.liveMatchup,
            snapshots: model.advisorSnapshots,
            adviceText: model.adviceText,
            adviceStatus: model.adviceStatus,
            adviceTurn: model.adviceTurn,
            adviceIsStale: model.adviceTurn.map {
                model.battleTurn > 0 && $0 != model.battleTurn
            } ?? false,
            advicePlayLines: model.advicePlay?.actions.map(\.displayLine) ?? [],
            adviceMeta: model.adviceMeta,
            adviceWhy: model.adviceTrace.map {
                "⚙️ \($0.tool): \($0.resultSummary)"
            }.joined(separator: "\n"),
            autoAdvise: Binding(
                get: { model.autoAdvise },
                set: { model.autoAdvise = $0 }),
            autoOpen: $autoOpen,
            isTracking: model.isRunning,
            trackerSees: model.current.map {
                $0.primary.rawValue
                    + (model.opponentFrameCount > 0
                       ? " · preview \(model.opponentFrameCount) frames" : "")
            },
            previewLine: model.previewAdviceText.map { "🔭 \($0)" }
                ?? model.scoutReport.map {
                    "🔭 Bring \($0.safeFour.joined(separator: " · ")) — leads \($0.leads.joined(separator: " + ")) (heuristic)"
                },
            onAsk: { model.requestAdvice() },
            onClose: { OverlayHUDController.shared.hide() })
    }
}

// MARK: - Pure content (previewable with mocked data)

struct OverlayContentView: View {
    let stateLines: [String]
    let outcome: String?
    let matchup: LiveMatchupData?
    let snapshots: [BattleReconciler.ActiveSnapshot]
    let adviceText: String?
    let adviceStatus: String?
    let adviceTurn: Int?
    /// BACKLOG P2: true when the shown advice outlived its turn (defaulted
    /// so mock previews stay unchanged).
    var adviceIsStale: Bool = false
    /// m12-F: the committed play as pre-formatted lines — rendered bold
    /// above the prose (defaulted so mock previews stay unchanged).
    var advicePlayLines: [String] = []
    /// m11 loop stats ("2 round-trips · 3 engine checks · 9.1s").
    let adviceMeta: String?
    /// Newline-joined tool trace for the hover tooltip (empty = none).
    let adviceWhy: String
    @Binding var autoAdvise: Bool
    @Binding var autoOpen: Bool
    let isTracking: Bool
    /// Classifier's live read ("teamPreview · preview 7 frames") — shown
    /// while waiting so a missed battle start is visible (battle 7).
    let trackerSees: String?
    /// m12-A: the preview scout's line for the waiting state — the agentic
    /// recommendation once computed, the heuristic bring-4 until then.
    let previewLine: String?
    let onAsk: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let outcome {
                Text(outcome == "won" ? "🏆 WON" : outcome == "lost" ? "💀 LOST" : "🏁 \(outcome)")
                    .font(.title3.bold())
            } else if let matchup {
                matchupSection(matchup)
            } else {
                Text(isTracking ? "Waiting for a battle…" : "Tracker idle — Start it in Live Tracker (⇧⌘L).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                // Battle-7 lesson: show what the tracker thinks it sees, so
                // a missed battle start is diagnosable AT preview time.
                if isTracking, let trackerSees {
                    Text("sees: \(trackerSees)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                // m12-A: the bring-4 while the battle hasn't started —
                // heuristic instantly, agentic once the scout answers.
                if let previewLine {
                    Text(previewLine)
                        .font(.callout)
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            if outcome == nil { adviceSection }

            footer
        }
        .padding(12)
        .frame(width: 360, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15)))
        .preferredColorScheme(.dark)
    }

    // Turn/weather headline comes from the reconciler's summary lines; the
    // perish clocks ride the snapshots (they can decide a game — always show).
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(stateLines.first ?? "ScopeLens")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 4)
            ForEach(clockChips, id: \.self) { chip in
                Text(chip)
                    .font(.caption.bold())
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(.purple.opacity(0.45)))
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close overlay")
        }
    }

    /// Perish clocks + Protect-pressure markers — the per-mon "clock" facts
    /// that can decide a turn, always visible in the header.
    private var clockChips: [String] {
        snapshots.compactMap { s in
            s.perishCount.map { "⏳\(s.displayName) \($0)" }
        }
        // m12-D: who just Protected — a repeat is ~1/3 (streak 2: ~1/9),
        // i.e. their block is probably down this turn (and so is yours).
        + snapshots.compactMap { s in
            s.protectedLastTurn
                ? "🛡\(s.displayName)\(s.protectStreak > 1 ? " ×\(s.protectStreak)" : "")"
                : nil
        }
        // m12-E: observed Choice item + committed move = locked until switch.
        + snapshots.compactMap { s in
            s.choiceLockedMove.map { "🔒\(s.displayName)→\($0)" }
        }
    }

    @ViewBuilder
    private func matchupSection(_ m: LiveMatchupData) -> some View {
        if !m.incoming.isEmpty {
            pairRows(title: "THREATS", pairs: Array(m.incoming.prefix(2)), badge: .red)
        }
        if !m.outgoing.isEmpty {
            pairRows(title: "ANSWERS", pairs: Array(m.outgoing.prefix(2)), badge: .green)
        }
        if !m.speeds.isEmpty {
            speedStrip(m)
        }
    }

    private func pairRows(title: String, pairs: [LiveMatchupData.Pair],
                          badge: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, p in
                HStack(spacing: 5) {
                    Text("\(p.attacker) \(p.move)")
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(p.defender)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(Int(p.minPct))–\(Int(p.maxPct))%")
                        .font(.system(.callout, design: .monospaced).weight(.bold))
                    if p.guaranteedKo || p.koNow {
                        Text(p.guaranteedKo ? "KO" : "KO?")
                            .font(.caption2.bold())
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(badge.opacity(p.guaranteedKo ? 0.85 : 0.5)))
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func speedStrip(_ m: LiveMatchupData) -> some View {
        HStack(spacing: 4) {
            Text(m.trickRoom ? "🌀" : "⚡️")
                .font(.caption)
                .accessibilityLabel(m.trickRoom ? "Trick Room order" : "Speed order")
            ForEach(Array(m.speeds.enumerated()), id: \.offset) { i, s in
                if i > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
                Text(s.species)
                    .font(.caption2.weight(s.side == "you" ? .bold : .regular))
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Capsule().fill(s.side == "you"
                        ? Color.blue.opacity(0.45) : Color.white.opacity(0.10)))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: onAsk) {
                    Label("What's the play?", systemImage: "sparkles")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Toggle("Auto", isOn: $autoAdvise)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help("Ask automatically once per turn")
                Spacer()
                if let adviceTurn {
                    Text(adviceIsStale ? "T\(adviceTurn) ⚠︎ stale" : "T\(adviceTurn)")
                        .font(.caption2)
                        .foregroundStyle(adviceIsStale ? AnyShapeStyle(.orange)
                                                       : AnyShapeStyle(.secondary))
                        .accessibilityLabel(adviceIsStale
                            ? "Stale advice from turn \(adviceTurn)"
                            : "Advice for turn \(adviceTurn)")
                }
            }
            if !advicePlayLines.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(advicePlayLines, id: \.self) { line in
                        Text("▶︎ \(line)")
                            .font(.callout.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Committed play: \(advicePlayLines.joined(separator: "; "))")
            }
            if let adviceText {
                Text(adviceText)
                    .font(.callout)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                // Glanceable "why": stats inline, full trace on hover
                // (the Battle Log has the expandable version).
                if let adviceMeta {
                    Text("🔧 \(adviceMeta)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help(adviceWhy.isEmpty ? "No engine checks were needed." : adviceWhy)
                        .accessibilityLabel("Advisor consulted: \(adviceWhy.isEmpty ? "no engine tools" : adviceWhy)")
                }
            }
            if let adviceStatus {
                Text(adviceStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Open when a battle starts", isOn: $autoOpen)
                .toggleStyle(.checkbox)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("drag to move")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Preview (mocked board: battle-4's turn-6 shape)

#Preview("Overlay — live board") {
    OverlayContentView(
        stateLines: ["Turn 6 · sun (3) · Trick Room"],
        outcome: nil,
        matchup: LiveMatchupData(
            incoming: [
                .init(attacker: "Scrafty-Mega", defender: "Charizard", dir: "incoming",
                      move: "Rock Slide", minPct: 84.3, maxPct: 101.6,
                      koNow: true, guaranteedKo: false, setSource: "observed", approx: false),
                .init(attacker: "Armarouge", defender: "Incineroar", dir: "incoming",
                      move: "Psychic", minPct: 31.2, maxPct: 42.7,
                      koNow: false, guaranteedKo: false, setSource: "usage", approx: false),
            ],
            outgoing: [
                .init(attacker: "Charizard", defender: "Armarouge", dir: "outgoing",
                      move: "Heat Wave", minPct: 88.0, maxPct: 104.5,
                      koNow: true, guaranteedKo: false, setSource: "observed", approx: false),
                .init(attacker: "Incineroar", defender: "Scrafty-Mega", dir: "outgoing",
                      move: "Darkest Lariat", minPct: 24.1, maxPct: 28.9,
                      koNow: false, guaranteedKo: false, setSource: "observed", approx: false),
            ],
            speeds: [
                .init(species: "Incineroar", side: "you", spe: 80, approx: false),
                .init(species: "Scrafty-Mega", side: "opp", spe: 88, approx: false),
                .init(species: "Armarouge", side: "opp", spe: 95, approx: false),
                .init(species: "Charizard", side: "you", spe: 120, approx: false),
            ],
            trickRoom: true,
            assumptions: ""),
        snapshots: [],
        adviceText: "Heat Wave into Armarouge is the line — it clears its current HP and removes the Psychic threat; Incineroar Fake Out the Scrafty to buy the turn.",
        adviceStatus: nil,
        adviceTurn: 6,
        adviceMeta: "2 round-trips · 3 engine checks · 9.1s",
        adviceWhy: "⚙️ damage_calc: Heat Wave 88–104.5% into Armarouge\n⚙️ meta_profile: Scrafty-Mega top moves",
        autoAdvise: .constant(true),
        autoOpen: .constant(true),
        isTracking: true,
        trackerSees: "narration",
        previewLine: nil,
        onAsk: {}, onClose: {})
    .padding(24)
}

#Preview("Overlay — idle") {
    OverlayContentView(
        stateLines: [], outcome: nil, matchup: nil, snapshots: [],
        adviceText: nil, adviceStatus: nil, adviceTurn: nil,
        adviceMeta: nil, adviceWhy: "",
        autoAdvise: .constant(false), autoOpen: .constant(true),
        isTracking: false, trackerSees: nil, previewLine: nil,
        onAsk: {}, onClose: {})
    .padding(24)
}

#Preview("Overlay — preview scouted") {
    OverlayContentView(
        stateLines: [], outcome: nil, matchup: nil, snapshots: [],
        adviceText: nil, adviceStatus: nil, adviceTurn: nil,
        adviceMeta: nil, adviceWhy: "",
        autoAdvise: .constant(false), autoOpen: .constant(true),
        isTracking: true, trackerSees: "teamPreview · preview 12 frames",
        previewLine: "🔭 Bring Charizard, Incineroar, Rotom-Wash, Garchomp — lead Incineroar + Rotom-Wash: Fake Out the Gengar while Rotom threatens Politoed, and keep Garchomp back until the Froslass reveals its item.",
        onAsk: {}, onClose: {})
    .padding(24)
}
