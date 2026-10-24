//
//  BattleLogView.swift
//  Scope Lens
//
//  Phase 2, milestone 5b: the live battle log — the in-app face of the m4
//  BattleState layer. While the live tracker runs, narration/chip/plate
//  observations reconcile into events and this window narrates the battle as
//  it happens, with the running §4.5 state summarized up top.
//
//  Offline twin: Diagnostics/BattleReplayHarness `replay` (same code path,
//  recorded video instead of the mirror).
//

import SwiftUI

public struct BattleLogView: View {
    @ObservedObject private var model = LiveTrackerModel.shared
    /// Nickname whose full-vocab picker popover is open (m13-D).
    @State private var bindPickerNick: String?


    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            stateSummary
            opponentNotepad
            nicknameBindPanel
            matchupPanel
            advisorPanel
            eventList
        }
        .padding(14)
        .frame(minWidth: 460, minHeight: 420)
    }

    // MARK: The opponent notepad (m14-A — the digital player's notepad)

    /// True while the notepad board is rendering the opponent roster —
    /// the plain "[opp]" summary line hides to avoid saying it twice.
    private var notepadActive: Bool {
        model.battleOutcome == nil && model.battleRoster.contains { $0.side == "opp" }
    }

    /// Showdown-tooltip-style observed facts for the WHOLE opponent
    /// roster: actives, revealed bench, and the still-unseen preview rows.
    /// Everything here was watched, never assumed — the dossier window
    /// (⇧⌘K) carries the meta priors.
    @ViewBuilder
    private var opponentNotepad: some View {
        if notepadActive {
            VStack(alignment: .leading, spacing: 5) {
                Text("Opponent — seen this battle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ForEach(model.battleRoster.filter { $0.side == "opp" }) { mon in
                    NotepadRow(mon: mon)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.teal.opacity(0.06)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Opponent notepad: observed facts for each opposing Pokémon")
        }
    }

    // MARK: Nickname bind card (m13-D)

    /// A nicknamed opponent hides its species from every text path until
    /// it uses a signature move — but the pilot can SEE it. One tap on an
    /// unclaimed-preview candidate (or the full-vocab picker) resolves it,
    /// and capsules/matchup/dossier light up on the same tick.
    @ViewBuilder
    private var nicknameBindPanel: some View {
        if let binds = model.nicknameBinds, model.battleOutcome == nil {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(binds.unresolved, id: \.self) { nick in
                    HStack(spacing: 6) {
                        Text("❓ \(nick) is…")
                            .font(.callout.weight(.semibold))
                        ForEach(binds.candidates, id: \.self) { species in
                            Button(species) {
                                model.bindNickname(display: nick, species: species)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("Identify \(nick) as \(species)")
                        }
                        Button {
                            bindPickerNick = nick
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("None of these? The preview read can miss — pick any species.")
                        .accessibilityLabel("Search all species for \(nick)")
                        .popover(isPresented: Binding(
                            get: { bindPickerNick == nick },
                            set: { if !$0 { bindPickerNick = nil } }
                        )) {
                            SpeciesSearchPicker(
                                current: "",
                                allSpecies: model.previewSpeciesUniverse
                            ) { species in
                                bindPickerNick = nil
                                model.bindNickname(display: nick, species: species)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                Text("A nickname hides the species until it reveals itself — or you tell the tracker.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.08)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Unidentified opponents: \(binds.unresolved.joined(separator: ", "))")
        }
    }

    // MARK: "What's the play" advisor (Phase 3 m8 — the opt-in LLM layer)

    @ViewBuilder
    private var advisorPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    model.requestAdvice()
                } label: {
                    Label("What's the play?", systemImage: "brain")
                }
                .disabled(model.battleEvents.isEmpty || model.battleOutcome != nil)
                .accessibilityLabel("Ask the advisor for this turn's play")

                Toggle("Auto", isOn: $model.autoAdvise)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Ask automatically at the start of each turn (one API call per turn).")
                    .accessibilityLabel("Automatically advise every turn")

                if let status = model.adviceStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            // Live loop readout (m12-E): what the advisor is doing right
            // now — streamed thinking, tool calls forming, round-trips.
            if !model.adviceProgress.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(model.adviceProgress.suffix(6).enumerated()),
                            id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(.purple.opacity(0.05)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Advisor working: \(model.adviceProgress.last ?? "")")
            }
            if let advice = model.adviceText {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain")
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        // m12-F: the committed play FIRST — glanceable
                        // actions the pilot mirrors into the game; the
                        // reasoning prose reads after.
                        if let play = model.advicePlay {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(play.actions) { action in
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("▶︎ \(action.displayLine)")
                                            .font(.callout.weight(.bold))
                                            .textSelection(.enabled)
                                        if let note = action.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .padding(.leading, 14)
                                        }
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Committed play: "
                                + play.actions.map(\.displayLine).joined(separator: "; "))
                        }
                        // m15-C: the play was bounced once and STILL breaks
                        // a deterministic rule — the pilot sees exactly
                        // which one before mirroring it into the game.
                        ForEach(Array(model.adviceLintWarnings.enumerated()),
                                id: \.offset) { _, warning in
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .textSelection(.enabled)
                                .accessibilityLabel("Rule warning: \(warning)")
                        }
                        Text(advice)
                            .font(.callout)
                            .textSelection(.enabled)
                        if let turn = model.adviceTurn {
                            // BACKLOG P2 belt-and-braces: an answer that
                            // outlived its turn says so, loudly.
                            let stale = model.battleTurn > 0 && turn != model.battleTurn
                                && model.battleOutcome == nil
                            Text((stale ? "⚠︎ for turn \(turn) — it's now turn \(model.battleTurn)"
                                        : "for turn \(turn)")
                                 + "\(model.adviceMeta.map { " · \($0)" } ?? "") · deterministic math is authoritative")
                                .font(.caption2)
                                .foregroundStyle(stale ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                                .accessibilityLabel(stale
                                    ? "Stale: this play was for turn \(turn); it is now turn \(model.battleTurn)"
                                    : "Play for turn \(turn)")
                        }
                        // The "why" trace (m11; thinking since m12-E): the
                        // reasoning + every engine tool consulted.
                        if !model.adviceTrace.isEmpty || !model.adviceThoughts.isEmpty {
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(model.adviceThoughts.enumerated()),
                                            id: \.offset) { _, thought in
                                        Text("🧠 \(thought)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                    ForEach(model.adviceTrace) { entry in
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("⚙️ \(entry.tool)\(entry.isError ? " — errored" : "")")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(entry.isError ? .orange : .secondary)
                                            Text(entry.inputSummary)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(2)
                                            Text("→ \(entry.resultSummary)")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(3)
                                        }
                                        .textSelection(.enabled)
                                    }
                                }
                                .padding(.top, 2)
                            } label: {
                                Text(model.adviceTrace.isEmpty
                                     ? "why — the advisor's reasoning"
                                     : "why — \(model.adviceTrace.count) engine check\(model.adviceTrace.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Show the advisor's reasoning and engine checks")
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(.purple.opacity(0.07)))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Advisor says: \(advice)")
            }
        }
    }

    // MARK: Live matchup (Phase 3 m7 — the deterministic advisor)

    @ViewBuilder
    private var matchupPanel: some View {
        if let m = model.liveMatchup, model.battleOutcome == nil {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Matchup")
                        .font(.headline)
                    Text(speedLine(m))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                ForEach(Array(m.incoming.prefix(3).enumerated()), id: \.offset) { _, pair in
                    matchupRow(pair, glyph: "⚠️")
                }
                Divider()
                ForEach(Array(m.outgoing.prefix(3).enumerated()), id: \.offset) { _, pair in
                    matchupRow(pair, glyph: "🎯")
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.blue.opacity(0.06)))
            .help(m.assumptions)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Live matchup panel")
        }
    }

    private func matchupRow(_ pair: LiveMatchupData.Pair, glyph: String) -> some View {
        HStack(spacing: 6) {
            Text(glyph)
                .accessibilityHidden(true)
            Text("\(pair.attacker) \(pair.move)")
                .font(.callout.weight(pair.koNow ? .semibold : .regular))
            Text("→ \(pair.defender)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("\(fmtPct(pair.minPct))–\(fmtPct(pair.maxPct))%")
                .font(.system(.callout, design: .monospaced))
            if pair.guaranteedKo {
                badge("KO", .red)
            } else if pair.koNow {
                badge("KO range", .orange)
            }
            if pair.setSource != "observed" {
                Text(pair.setSource == "usage" ? "prior" : pair.setSource)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if pair.approx {
                Text("~stats")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(pair.attacker) \(pair.move) into \(pair.defender): \(Int(pair.minPct)) to \(Int(pair.maxPct)) percent"
            + (pair.guaranteedKo ? ", guaranteed knockout" : pair.koNow ? ", knockout range" : ""))
    }

    private func badge(_ label: String, _ tint: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
    }

    private func speedLine(_ m: LiveMatchupData) -> String {
        let order = m.speeds
            .map { "\($0.side == "you" ? "🟦" : "🟥")\($0.species) \($0.spe)\($0.approx ? "~" : "")" }
            .joined(separator: "  ›  ")
        return (m.trickRoom ? "🌀 TR order: " : "order: ") + order
    }

    private func fmtPct(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Battle Log")
                .font(.title3.weight(.semibold))
            if let outcome = model.battleOutcome {
                Text(outcome.uppercased())
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(outcome.hasPrefix("won") ? .green.opacity(0.2) : .orange.opacity(0.2)))
                    .accessibilityLabel("Battle outcome: \(outcome)")
            } else if !model.battleEvents.isEmpty {
                Text("LIVE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
            }
            Spacer()
            Button("Copy Markdown") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.battleLogMarkdown, forType: .string)
            }
            .disabled(model.battleLogMarkdown.isEmpty)
            .accessibilityLabel("Copy the battle log as Markdown")
            Button("Reset") { model.resetBattleLog() }
                .disabled(model.battleEvents.isEmpty)
                .accessibilityLabel("Reset the battle log")
        }
    }

    @ViewBuilder
    private var stateSummary: some View {
        if !model.battleStateLines.isEmpty {
            // The notepad board says everything the "[opp]" line says and
            // more — hide the line while the board is up (m14-A).
            let lines = notepadActive
                ? model.battleStateLines.filter { !$0.hasPrefix("[opp]") }
                : model.battleStateLines
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.callout, design: line.hasPrefix("Turn") ? .rounded : .monospaced))
                        .fontWeight(line.hasPrefix("Turn") ? .bold : .regular)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Battle state: \(lines.joined(separator: ", "))")
        }
    }

    @ViewBuilder
    private var eventList: some View {
        if model.battleEvents.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 34))
                    .foregroundStyle(.tertiary)
                Text("Waiting for a battle…")
                    .foregroundStyle(.secondary)
                Text("Start the Live Tracker (⇧⌘L) with the QuickTime mirror up; events appear as the battle narrates itself.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                // Live diagnostics (m11-B, battle 7's silent stall): what the
                // tracker THINKS it's seeing, so a missed battle start is
                // visible the moment it happens — not after the battle.
                if model.isRunning {
                    VStack(spacing: 2) {
                        Text("tracker sees: " + (model.current.map {
                            "\($0.primary.rawValue) (conf \(String(format: "%.2f", $0.confidence)))"
                        } ?? "no frames yet"))
                        if model.opponentFrameCount > 0 {
                            Text("team preview: \(model.opponentFrameCount) frames voted"
                                 + (model.opponentRead.count == 6 ? " · 6 rows read" : " · \(model.opponentRead.count) rows"))
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Tracker diagnostics")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                List(Array(model.battleEvents.enumerated()), id: \.offset) { i, event in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(BattleEvent.mmss(event.t))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(event.displayLine)
                            .font(event.kind == .turnStart
                                  ? .system(.body, design: .rounded).weight(.bold)
                                  : .system(.body))
                    }
                    .id(i)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(BattleEvent.mmss(event.t)): \(event.displayLine)")
                }
                .listStyle(.inset)
                .onChange(of: model.battleEvents.count) { _, count in
                    guard count > 0 else { return }
                    withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }
        }
    }
}

/// One notepad line: everything the battle has shown about one opposing
/// mon (m14-A). Pure over RosterEntry so the mock preview below renders
/// without live state.
private struct NotepadRow: View {
    let mon: BattleReconciler.RosterEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(mon.fainted ? "💀" : mon.isActive ? "▶︎" : "·")
                    .font(.caption)
                    .frame(width: 14, alignment: .center)
                    .accessibilityHidden(true)
                Text(name)
                    .font(.callout.weight(mon.isActive ? .semibold : .regular))
                    .italic(mon.previewGhost)
                if mon.mega {
                    Text("mega")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(.purple.opacity(0.2)))
                }
                if let pct = mon.curPct {
                    Text("\(Int(pct))%")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(hpColor(pct))
                }
                if let status = mon.status {
                    Text(status)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(.yellow.opacity(0.25)))
                }
                ForEach(mon.boosts.sorted(by: { $0.key < $1.key }), id: \.key) { stat, stage in
                    Text("\(stat)\(stage > 0 ? "+" : "")\(stage)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(stage > 0 ? .green.opacity(0.2) : .red.opacity(0.18)))
                }
                if let perish = mon.perishCount {
                    Text("⏳\(perish)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.purple)
                }
                if mon.protectedLastTurn {
                    Text("🛡\(mon.protectStreak > 1 ? "×\(mon.protectStreak)" : "")")
                        .font(.caption2)
                        .help("Protected last turn — a repeat only lands ~33%")
                }
                Spacer(minLength: 0)
            }
            if let secondLine {
                HStack(spacing: 4) {
                    Text(secondLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !mon.hints.isEmpty {
                        Text("🔎")
                            .font(.caption2)
                            .help(mon.hints.joined(separator: "\n"))
                            .accessibilityLabel("Damage inference: \(mon.hints.joined(separator: "; "))")
                    }
                }
                .padding(.leading, 20)
            }
        }
        .opacity(mon.fainted ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var name: String {
        if mon.previewGhost { return mon.displayName }
        if mon.species != "unknown", mon.displayName != mon.species,
           !mon.species.hasPrefix(mon.displayName) {
            return "\(mon.displayName) (\(mon.species))"
        }
        return mon.species == "unknown" ? "\(mon.displayName) (?)" : mon.species
    }

    /// Item · ability · moves with use counts — or the not-seen note.
    private var secondLine: String? {
        if mon.previewGhost { return "not seen yet" }
        var bits: [String] = []
        if let item = mon.item { bits.append("@ \(item)") }
        if let ability = mon.ability { bits.append(ability) }
        if !mon.moves.isEmpty {
            bits.append(mon.moves.map { $0.uses > 1 ? "\($0.name) ×\($0.uses)" : $0.name }
                .joined(separator: " · "))
        }
        if let lock = mon.choiceLockedMove { bits.append("🔒 \(lock)") }
        return bits.isEmpty ? nil : bits.joined(separator: "  ·  ")
    }

    private func hpColor(_ pct: Double) -> Color {
        pct > 50 ? .green : pct > 20 ? .orange : .red
    }

    private var accessibilitySummary: String {
        var parts: [String] = [name]
        parts.append(mon.fainted ? "fainted" : mon.isActive ? "active" : "benched")
        if let pct = mon.curPct { parts.append("\(Int(pct)) percent") }
        if let status = mon.status { parts.append(status) }
        if let line = secondLine { parts.append(line) }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    BattleLogView()
}

#Preview("Opponent notepad — battle 9 shape") {
    VStack(alignment: .leading, spacing: 5) {
        NotepadRow(mon: .init(
            side: "opp", species: "Aerodactyl-Mega", displayName: "Aerodactyl",
            isActive: true, fainted: false, mega: true, curPct: 37, status: "slp",
            boosts: [:], moves: [("Rock Slide", 2)], item: "Aerodactylite",
            ability: "Pressure", perishCount: nil, protectedLastTurn: false,
            protectStreak: 0, choiceLockedMove: nil, hints: [], previewGhost: false))
        NotepadRow(mon: .init(
            side: "opp", species: "Sneasler", displayName: "Sneasler",
            isActive: true, fainted: false, mega: false, curPct: 6, status: nil,
            boosts: ["Def": -1, "SpD": -1],
            moves: [("Quick Guard", 1), ("Close Combat", 1), ("Poison Jab", 1)],
            item: "White Herb", ability: nil, perishCount: nil,
            protectedLastTurn: false, protectStreak: 0, choiceLockedMove: nil,
            hints: ["Poison Jab: item boost implied — Choice Band or Life Orb"],
            previewGhost: false))
        NotepadRow(mon: .init(
            side: "opp", species: "Kingambit", displayName: "Kingambit",
            isActive: false, fainted: false, mega: false, curPct: 100, status: nil,
            boosts: [:], moves: [("Protect", 3), ("Sucker Punch", 1)], item: nil,
            ability: nil, perishCount: nil, protectedLastTurn: true,
            protectStreak: 2, choiceLockedMove: nil, hints: [], previewGhost: false))
        NotepadRow(mon: .init(
            side: "opp", species: "Garchomp", displayName: "Garchomp",
            isActive: false, fainted: true, mega: false, curPct: 0, status: nil,
            boosts: [:], moves: [("Protect", 4), ("Rock Slide", 1)], item: nil,
            ability: "Rough Skin", perishCount: nil, protectedLastTurn: false,
            protectStreak: 0, choiceLockedMove: nil, hints: [], previewGhost: false))
        NotepadRow(mon: .init(
            side: "opp", species: "Alcremie-Ruby-Swirl", displayName: "Alcremie-Ruby-Swirl",
            isActive: false, fainted: false, mega: false, curPct: nil, status: nil,
            boosts: [:], moves: [], item: nil, ability: nil, perishCount: nil,
            protectedLastTurn: false, protectStreak: 0, choiceLockedMove: nil,
            hints: [], previewGhost: true))
    }
    .padding(16)
    .frame(width: 440)
}
