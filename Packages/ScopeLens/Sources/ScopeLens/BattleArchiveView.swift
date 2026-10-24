//
//  BattleArchiveView.swift
//  Scope Lens
//
//  Phase 3, m13-C: the post-battle review window (⇧⌘A). Lists every
//  archived battle (BattleArchiveStore) and replays it: outcome, teams,
//  the preview scout's call, each turn's committed play with its
//  why-trace, and the full narrated log. This is the spec §1 learning
//  loop's first surface — and the raw material the eval-set milestone
//  will mine for decision points.
//

import SwiftUI
import Combine

public struct BattleArchiveView: View {
    @State private var records: [BattleRecord] = []
    @State private var selection: UUID?
    @State private var pendingDelete: BattleRecord?


    public init() {}
    public var body: some View {
        NavigationSplitView {
            List(records, selection: $selection) { record in
                row(record)
                    .tag(record.id)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 230, ideal: 270)
            .accessibilityLabel("Archived battles")
        } detail: {
            if let record = records.first(where: { $0.id == selection }) {
                BattleRecordDetailView(record: record) {
                    pendingDelete = record
                }
            } else {
                ContentUnavailableView(
                    "Battle Archive",
                    systemImage: "archivebox",
                    description: Text(records.isEmpty
                        ? "Battles archive themselves when they finish (or are reset/replaced mid-run). Play one with the Live Tracker on and it appears here."
                        : "Select a battle to replay its decisions."))
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .onAppear(perform: reload)
        // Live refresh: the tracker archives on the battle's final tick.
        .onReceive(NotificationCenter.default
            .publisher(for: BattleArchiveStore.changed)
            .receive(on: DispatchQueue.main)) { _ in reload() }
        .confirmationDialog(
            "Delete this battle record?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let record = pendingDelete {
                    BattleArchiveStore.delete(record)
                    if selection == record.id { selection = nil }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This removes the archived log and advice traces permanently.")
        }
    }

    private func reload() {
        records = BattleArchiveStore.list()
        if selection == nil { selection = records.first?.id }
    }

    private func row(_ record: BattleRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(record.isAbandoned ? "🚪" : record.isWin ? "🏆" : "💀")
                    .accessibilityHidden(true)
                Text(record.startedAt, format: .dateTime.month().day().hour().minute())
                    .font(.callout.weight(.semibold))
                Spacer(minLength: 0)
                if record.turns > 0 {
                    Text("T\(record.turns)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(record.opponentSpecies.isEmpty
                 ? "opponent unknown"
                 : "vs " + record.opponentSpecies.prefix(3).joined(separator: " · ")
                   + (record.opponentSpecies.count > 3 ? " …" : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(record.isAbandoned ? "Abandoned" : record.isWin ? "Won" : "Lost") battle, "
            + "\(record.startedAt.formatted(.dateTime.month().day().hour().minute())), "
            + (record.opponentSpecies.isEmpty ? "opponent unknown"
               : "versus \(record.opponentSpecies.prefix(3).joined(separator: ", "))"))
    }
}

// MARK: - Detail

private struct BattleRecordDetailView: View {
    let record: BattleRecord
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                teams
                if let preview = record.previewAdvice {
                    previewCard(preview, meta: record.previewAdviceMeta)
                }
                if !record.advice.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Decision points")
                            .font(.title3.weight(.semibold))
                        // m15-A: the label supply is the eval set's ground
                        // truth — nudge until every decision is labeled.
                        let unlabeled = record.advice.filter { $0.verdict == nil }.count
                        if unlabeled > 0 {
                            Text("\(unlabeled) awaiting your 👍/👎")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(record.advice) { entry in
                        AdviceCardView(recordID: record.id, entry: entry)
                    }
                }
                logSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(record.isAbandoned ? "🚪 ABANDONED" : record.isWin ? "🏆 WON" : "💀 LOST")
                .font(.title3.bold())
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(
                    record.isAbandoned ? .gray.opacity(0.18)
                    : record.isWin ? .green.opacity(0.18) : .orange.opacity(0.18)))
                .accessibilityLabel("Outcome: \(record.outcome)")
            VStack(alignment: .leading, spacing: 1) {
                Text(record.startedAt, format: .dateTime.weekday().month().day().hour().minute())
                    .font(.callout)
                Text("\(duration) · \(record.turns) turn\(record.turns == 1 ? "" : "s") · \(record.advice.count) advised")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let build = record.appBuild {
                    // m15-A stale-instance discipline: which build watched.
                    Text(build)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button("Copy Log") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.logMarkdown, forType: .string)
            }
            .disabled(record.logMarkdown.isEmpty)
            .accessibilityLabel("Copy the battle log as Markdown")
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete this battle record")
            .help("Remove this battle from the archive")
        }
    }

    private var duration: String {
        let s = max(0, Int(record.endedAt.timeIntervalSince(record.startedAt)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var teams: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !record.yourTeam.isEmpty {
                Text("You: \(record.yourTeam.joined(separator: " · "))")
                    .font(.caption)
            }
            if !record.opponentSpecies.isEmpty {
                Text("Opponent: \(record.opponentSpecies.joined(separator: " · "))")
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func previewCard(_ text: String, meta: String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "binoculars")
                .foregroundStyle(.purple)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Preview scout")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.callout)
                    .textSelection(.enabled)
                if let meta {
                    Text(meta)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.purple.opacity(0.07)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview scout said: \(text)")
    }

    @ViewBuilder
    private var logSection: some View {
        Text("Battle log")
            .font(.title3.weight(.semibold))
        Text(record.logMarkdown.isEmpty ? "(no log captured)" : record.logMarkdown)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
            .accessibilityLabel("Full battle log")
    }
}

// MARK: - One decision point (m13-C card + m15-A verdict capture)

/// The advice card, now a verdict-collecting surface: 👍/👎 toggles plus an
/// optional one-line note, persisted straight onto the record's JSON via
/// BattleArchiveStore.setVerdict (the store's changed notification reloads
/// the window, so the fresh label flows back down). The pilot's labels are
/// the eval set's ground truth — this is deliberately a two-click habit.
private struct AdviceCardView: View {
    let recordID: UUID
    let entry: BattleRecord.AdviceEntry
    @State private var note: String
    @FocusState private var noteFocused: Bool

    init(recordID: UUID, entry: BattleRecord.AdviceEntry) {
        self.recordID = recordID
        self.entry = entry
        _note = State(initialValue: entry.verdictNote ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Turn \(entry.turn)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                verdictButton(icon: "hand.thumbsup", value: "good", tint: .green,
                              label: "Mark this advice as good")
                verdictButton(icon: "hand.thumbsdown", value: "bad", tint: .orange,
                              label: "Mark this advice as bad")
            }
            ForEach(Array(entry.playLines.enumerated()), id: \.offset) { _, line in
                Text("▶︎ \(line)")
                    .font(.callout.weight(.bold))
                    .textSelection(.enabled)
            }
            Text(entry.text)
                .font(.callout)
                .textSelection(.enabled)
            if let meta = entry.meta {
                Text(meta)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            // m15-C: what the rule check said about this play — the
            // archive keeps the lint verdict beside the pilot's.
            ForEach(Array((entry.lintFindings ?? []).enumerated()), id: \.offset) { _, finding in
                Label("\(finding.rule): \(finding.message)",
                      systemImage: finding.severity == .violation
                          ? "exclamationmark.triangle.fill" : "info.circle")
                    .font(.caption2)
                    .foregroundStyle(finding.severity == .violation
                        ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .textSelection(.enabled)
                    .accessibilityLabel("\(finding.severity == .violation ? "Rule violation" : "Advisory"): \(finding.message)")
            }
            if entry.verdict != nil {
                TextField("Why? (optional — bad calls become eval cases)",
                          text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .focused($noteFocused)
                    .onSubmit { persist(verdict: entry.verdict) }
                    .accessibilityLabel("Note explaining your verdict")
            }
            if !entry.trace.isEmpty || !entry.thoughts.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(entry.thoughts.enumerated()), id: \.offset) { _, thought in
                            Text("🧠 \(thought)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        ForEach(Array(entry.trace.enumerated()), id: \.offset) { _, check in
                            VStack(alignment: .leading, spacing: 1) {
                                Text("⚙️ \(check.tool)\(check.isError ? " — errored" : "")")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(check.isError ? .orange : .secondary)
                                Text(check.input)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Text("→ \(check.result)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 2)
                } label: {
                    Text("why — \(entry.trace.count) engine check\(entry.trace.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Show this turn's reasoning and engine checks")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.purple.opacity(0.05)))
        .accessibilityElement(children: .contain)
        // Focus loss commits the note (the pilot tabs away mid-review).
        .onChange(of: noteFocused) { _, focused in
            if !focused, entry.verdict != nil, note != (entry.verdictNote ?? "") {
                persist(verdict: entry.verdict)
            }
        }
    }

    private func verdictButton(icon: String, value: String, tint: Color,
                               label: String) -> some View {
        let isOn = entry.verdict == value
        return Button {
            // Tap toggles: picking the same verdict again clears the label.
            persist(verdict: isOn ? nil : value)
            if !isOn, value == "bad" { noteFocused = true }
        } label: {
            Image(systemName: isOn ? "\(icon).fill" : icon)
                .foregroundStyle(isOn ? tint : .secondary)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func persist(verdict: String?) {
        BattleArchiveStore.setVerdict(
            recordID: recordID, askedAt: entry.askedAt,
            verdict: verdict, note: verdict == nil ? nil : note)
    }
}

// MARK: - Preview (mocked record)

#Preview("Battle Archive — detail") {
    BattleRecordDetailView(record: BattleRecord(
        id: UUID(),
        startedAt: Date(timeIntervalSinceNow: -540),
        endedAt: Date(),
        outcome: "won — opponent's team fainted",
        turns: 7,
        yourTeam: ["Charizard", "Incineroar", "Rotom-Wash", "Garchomp", "Amoonguss", "Dondozo"],
        opponentSpecies: ["Gengar", "Politoed", "Froslass", "Incineroar", "Scrafty", "Armarouge"],
        stateLines: ["Turn 7", "[you] Charizard 64%  ·  Garchomp 100%", "[opp] —   (4 fainted)"],
        logMarkdown: "# Live battle\n- 00:12 [you] Charizard used Heat Wave!\n- 00:14 [opp] Gengar fainted!",
        previewAdvice: "Bring Charizard, Incineroar, Rotom-Wash, Garchomp — lead Incineroar + Rotom-Wash into the likely Gengar/Politoed.",
        previewAdviceMeta: "2 round-trips · 4 engine checks · 26.3s",
        advice: [
            .init(turn: 1, askedAt: Date(timeIntervalSinceNow: -500),
                  text: "Fake Out the Gengar while Rotom threatens Politoed with Thunderbolt.",
                  playLines: ["Incineroar: Fake Out → Gengar",
                              "Rotom-Wash: Thunderbolt → Politoed — watch for Protect"],
                  thoughts: ["Gengar is the speed-control threat; flinching it buys the Thunderbolt."],
                  trace: [.init(tool: "damage_calc",
                                input: "Rotom-Wash Thunderbolt → Politoed",
                                result: "82–97%, no KO", isError: false)],
                  meta: "2 round-trips · 1 engine check · 9.8s"),
            .init(turn: 3, askedAt: Date(timeIntervalSinceNow: -320),
                  text: "Cash in Charizard with Solar Beam before it drops.",
                  playLines: ["Charizard: Solar Beam → Politoed"],
                  thoughts: [],
                  trace: [],
                  meta: "1 round-trip · no checks needed · 6.2s",
                  verdict: "bad",
                  verdictNote: "Charizard was outsped and KO'd — the Beam never fired.",
                  model: "claude-opus-4-8"),
        ],
        appBuild: "1.0 · binary 2026-07-13T16:22:00Z"),
        onDelete: {})
}
