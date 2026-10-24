//
//  ScoutReportView.swift
//  Scope Lens
//
//  Phase 2, milestone 3b: the live scout report window — the spec §1 payoff
//  ("this Incineroar almost certainly has Fake Out"). Renders the engine's
//  structured report for the frame-voted opponent consensus, with tap-to-
//  confirm species chips that recompute the report on override.
//

import SwiftUI
import Combine

public struct ScoutReportView: View {
    @ObservedObject private var model = LiveTrackerModel.shared
    @Environment(\.openWindow) private var openWindow
    /// Row whose manual-entry species picker popover is open (BACKLOG P1).
    @State private var pickerRow: Int?


    public init() {}
    public var body: some View {
        Group {
            if let report = model.scoutReport {
                reportBody(report)
            } else {
                ContentUnavailableView(
                    "Waiting for a team preview…",
                    systemImage: "binoculars",
                    description: Text("Start the Live Tracker and queue into a battle. "
                                      + "The report appears as soon as the opponent read stabilizes.")
                )
            }
        }
        .frame(minWidth: 700, minHeight: 520)
    }

    private func reportBody(_ report: ScoutReportData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                bringFourBanner(report)
                previewScoutPanel

                if let status = model.scoutStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("Opponent — likely sets")
                    .font(.title3.weight(.semibold))
                ForEach(Array(report.opponents.enumerated()), id: \.offset) { row, opp in
                    opponentCard(row: row, opp: opp)
                }

                Text("Biggest threats to you")
                    .font(.title3.weight(.semibold))
                ForEach(Array(report.threats.prefix(6).enumerated()), id: \.offset) { _, threat in
                    threatRow(threat)
                }

                Text("Your best answers")
                    .font(.title3.weight(.semibold))
                ForEach(Array(report.answers.enumerated()), id: \.offset) { _, answer in
                    HStack(spacing: 0) {
                        EntryLink(name: answer.mine, kind: .species)
                        Text(": ")
                        EntryLink(name: answer.move, kind: .move, weight: .bold)
                        Text(" vs ")
                        EntryLink(name: answer.target, kind: .species)
                        Text(" for \(fmt(answer.minPct))–\(fmt(answer.maxPct))%")
                    }
                    .font(.callout)
                }

                Text(report.assumptions)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Agentic preview scout (m12-A — the toggle-on layer)

    /// Ask card for the tool-loop preview scout. The heuristic banner above
    /// stays the always-on instant answer (two-speed doctrine §4.1); this
    /// layer verifies lead pairings and threat lines with real engine
    /// checks before recommending — ~30s, one API call, pilot-triggered.
    @ViewBuilder
    private var previewScoutPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    model.requestPreviewAdvice()
                } label: {
                    Label("Scout this matchup", systemImage: "sparkles")
                }
                .disabled(model.scoutReport == nil)
                .accessibilityLabel("Ask the agentic scout what to bring")
                .help("Runs the tool-loop advisor on this preview (~30s, one API call).")

                Toggle("Auto once per preview", isOn: $model.autoPreviewScout)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Ask automatically when each battle's opponent read stabilizes (one API call per preview).")
                    .accessibilityLabel("Automatically scout every preview")

                if let status = model.previewAdviceStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            // Live loop readout (m12-E) while the scout works.
            if !model.previewAdviceProgress.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(model.previewAdviceProgress.suffix(6).enumerated()),
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
                .accessibilityLabel("Scout working: \(model.previewAdviceProgress.last ?? "")")
            }
            if let advice = model.previewAdviceText {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(advice)
                            .font(.callout)
                            .textSelection(.enabled)
                        if let meta = model.previewAdviceMeta {
                            Text("\(meta) · deterministic math is authoritative")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !model.previewAdviceTrace.isEmpty || !model.previewAdviceThoughts.isEmpty {
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(model.previewAdviceThoughts.enumerated()),
                                            id: \.offset) { _, thought in
                                        Text("🧠 \(thought)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                    ForEach(model.previewAdviceTrace) { entry in
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
                                Text(model.previewAdviceTrace.isEmpty
                                     ? "why — the scout's reasoning"
                                     : "why — \(model.previewAdviceTrace.count) engine check\(model.previewAdviceTrace.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Show the scout's reasoning and engine checks")
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(.purple.opacity(0.07)))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Scout says: \(advice)")
            }
        }
    }

    private func bringFourBanner(_ report: ScoutReportData) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Bring: \(report.safeFour.joined(separator: " · "))")
                    .font(.title2.weight(.bold))
                Text("Suggested leads: \(report.leads.joined(separator: " + "))  (heuristic)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            // m12-C: the "what does that even do" companion window.
            Button("Dossiers") { openWindow(id: "dossier") }
                .accessibilityLabel("Open the opponent dossier window")
                .help("Likely sets with plain-English effects for these opponents (⇧⌘K)")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.12)))
    }

    private func opponentCard(row: Int, opp: ScoutReportData.OpponentSet) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let sprite = model.opponentSprites[row] {
                Image(decorative: sprite, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            VStack(alignment: .leading, spacing: 4) {
                // Species chips: consensus top-3, tap to pin/unpin an override.
                HStack(spacing: 6) {
                    ForEach(chipNames(row: row, chosen: opp.species), id: \.self) { name in
                        let chosen = name == opp.species
                        Button {
                            model.confirmSpecies(row: row, name: name)
                        } label: {
                            Text(name)
                                .font(chosen ? .callout.weight(.bold) : .callout)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(chosen ? .blue.opacity(0.25) : .gray.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(chosen ? "Selected" : "Select") species \(name) for row \(row + 1)")
                    }
                    // BACKLOG P1: the escape hatch — the voted chips can
                    // miss the true species entirely; this pins ANY
                    // closed-vocab species (and banks the crop, so the
                    // matcher learns the miss).
                    Button {
                        pickerRow = row
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("None of these right? Pin any species — a manual pin also teaches the matcher this row's crop.")
                    .accessibilityLabel("Search all species for row \(row + 1)")
                    .popover(isPresented: Binding(
                        get: { pickerRow == row },
                        set: { if !$0 { pickerRow = nil } }
                    )) {
                        SpeciesSearchPicker(
                            current: opp.species,
                            allSpecies: model.previewSpeciesUniverse
                        ) { name in
                            pickerRow = nil
                            if model.speciesOverrides[row] != name {
                                model.confirmSpecies(row: row, name: name)
                            }
                        }
                    }
                    if model.speciesOverrides[row] != nil {
                        Text("pinned")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if NeodexBridge.openEntry != nil {
                        Button {
                            NeodexBridge.openEntry?(.species, opp.species)
                        } label: {
                            Image(systemName: "book.pages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open \(opp.species) in Neodex")
                        .accessibilityLabel("Open \(opp.species) in Neodex")
                    }
                    if !opp.hasMeta {
                        Text(opp.setSource == "learnset" ? "learnset guess" : "no meta data")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .help(opp.setSource == "learnset"
                                  ? "No ladder usage data — moves are plausible STAB attacks from this species' learnset, not observed sets."
                                  : "No ladder usage data for this species.")
                    }
                }
                if opp.item != nil || opp.ability != nil {
                    HStack(spacing: 6) {
                        if let item = opp.item {
                            Text("@")
                            EntryLink(name: item, kind: .item, font: .caption)
                        }
                        if opp.item != nil, opp.ability != nil { Text("·").foregroundStyle(.tertiary) }
                        if let ability = opp.ability {
                            EntryLink(name: ability, kind: .ability, font: .caption)
                        }
                        if opp.assumed { Text("(meta prior)") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if !opp.moves.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(opp.moves, id: \.name) { move in
                            HStack(spacing: 3) {
                                EntryLink(name: move.name, kind: .move, font: .caption)
                                if let pct = move.pct {
                                    Text("\(fmt(pct))%").font(.caption)
                                }
                            }
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.purple.opacity(0.10)))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
    }

    private func threatRow(_ threat: ScoutReportData.ThreatRead) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 0) {
                EntryLink(name: threat.attacker, kind: .species)
                Text("’s ")
                EntryLink(name: threat.move, kind: .move, weight: .bold)
                Text(" vs ")
                EntryLink(name: threat.defender, kind: .species)
                Text(": \(fmt(threat.minPct))–\(fmt(threat.maxPct))%")
            }
            .font(.callout)
            if threat.ko {
                Text("KO range")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(.red))
                    .accessibilityLabel("KO range")
            }
            Spacer(minLength: 0)
        }
    }

    /// Chip list for a row: voted top-3 plus the current pick (override may
    /// not be in the top-3), de-duplicated, stable order.
    private func chipNames(row: Int, chosen: String) -> [String] {
        var names = model.opponentRead.first { $0.row == row }?.speciesTop.map(\.name) ?? []
        if !names.contains(chosen) { names.append(chosen) }
        return names
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

/// BACKLOG P1: the manual-entry escape hatch. The chips only surface the
/// voted top-3 — when the true species ranks lower (or is a known
/// no-cross-source-crop class like Scizor/Sylveon/Raichu/Milotic), the
/// pilot was stuck with a wrong auto-pick. This searches the matcher's
/// FULL closed vocabulary; picks flow through confirmSpecies, so a manual
/// rescue also banks the row's crop as a native reference.
/// Reused by the Battle Log's nickname bind card (m13-D) — same guarantee,
/// mid-battle (no crop banking there; battle models aren't menu sprites).
struct SpeciesSearchPicker: View {
    let current: String
    let allSpecies: [String]
    let onPick: (String) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    /// Prefix matches outrank substring matches; ties alphabetize.
    private var matches: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allSpecies }
        return allSpecies
            .filter { $0.lowercased().contains(q) }
            .sorted { a, b in
                let ap = a.lowercased().hasPrefix(q)
                let bp = b.lowercased().hasPrefix(q)
                return ap == bp ? a < b : ap
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if allSpecies.isEmpty {
                Text("Species index unavailable — rebuild the app bundle.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(4)
            } else {
                TextField("Species name…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .onSubmit { if let first = matches.first { onPick(first) } }
                    .accessibilityLabel("Type a species name; Return pins the top match")
                if matches.isEmpty {
                    Text("No species matches “\(query)”.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(matches, id: \.self) { name in
                                Button { onPick(name) } label: {
                                    HStack {
                                        Text(name)
                                            .font(.callout)
                                        Spacer()
                                        if name == current {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(name == current ? "\(name), current pick" : name)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
                Text("Pinning teaches the matcher this row's crop.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(width: 250)
        .onAppear { searchFocused = true }
    }
}

#Preview {
    ScoutReportView()
}

#Preview("Species picker") {
    SpeciesSearchPicker(
        current: "Krokorok",
        allSpecies: ["Krokorok", "Krookodile", "Milotic", "Raichu",
                     "Scizor", "Scrafty", "Sylveon"],
        onPick: { _ in })
    .padding(12)
}
