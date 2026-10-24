//
//  TeamSettingsView.swift
//  Scope Lens
//
//  Phase 3, m9: Settings (⌘,) Team tab. Paste a team in Showdown export
//  format — the format VGC players already have — review the validation
//  issues, and every ScopeLens surface (scout report, reconciler seeds,
//  live matchup, advisor) uses it. Reverting restores the bundled default.
//

import SwiftUI

public struct TeamSettingsView: View {
    @ObservedObject private var manager = TeamManager.shared
    @State private var pasteText = ""
    @State private var statusLine = ""
    @State private var confirmingRevert = false


    public init() {}
    public var body: some View {
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text(manager.team.name ?? "Your Team")
                        .font(.headline)
                    Spacer()
                    Text("\(manager.team.members.count) member\(manager.team.members.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if manager.team.members.isEmpty {
                    Text("No team configured — paste one below.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    ForEach(Array(manager.team.members.enumerated()), id: \.offset) { _, m in
                        memberRow(m)
                    }
                }
                Text("Changes apply to the scout report, live matchup, and advisor immediately; battle-log name tracking picks them up from the next battle.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Import from Showdown paste")
                    .font(.headline)
                TextEditor(text: $pasteText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 140, maxHeight: 200)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3)))
                    .accessibilityLabel("Showdown paste text")

                HStack {
                    Button("Import") {
                        let issues = manager.importPaste(pasteText)
                        let errors = issues.filter { $0.severity == .error }
                        statusLine = errors.isEmpty
                            ? "Imported \(manager.team.members.count) members."
                            : "Import blocked — fix the errors below."
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Load Current as Paste") {
                        pasteText = ShowdownPaste.render(manager.team)
                        statusLine = "Current team loaded into the editor."
                    }
                    .disabled(manager.team.members.isEmpty)

                    Spacer()

                    Button("Revert to Default…", role: .destructive) {
                        confirmingRevert = true
                    }
                    .confirmationDialog(
                        "Replace your saved team with the bundled default?",
                        isPresented: $confirmingRevert) {
                        Button("Revert", role: .destructive) {
                            manager.revertToDefault()
                            pasteText = ""
                            statusLine = "Reverted to the default team."
                        }
                    }
                }

                if !statusLine.isEmpty {
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let storageError = manager.storageError {
                    Label(storageError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if !manager.lastIssues.isEmpty {
                Section {
                    ForEach(Array(manager.lastIssues.enumerated()), id: \.offset) { _, issue in
                        Label {
                            Text(issueText(issue))
                        } icon: {
                            Image(systemName: issue.severity == .error
                                  ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(issue.severity == .error ? .red : .orange)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private func memberRow(_ m: TeamMember) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(m.displayName(vocab: manager.vocab))
                    .fontWeight(.medium)
                if m.nickname != nil {
                    Text("(\(m.species))")
                        .foregroundStyle(.secondary)
                }
                if let item = m.item {
                    Text("@ \(item)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let nature = m.nature {
                    Text(nature)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(m.moves.isEmpty ? "moves from meta priors" : m.moves.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(m.moves.isEmpty ? .tertiary : .secondary)
            if let evs = m.evs, !evs.isEmpty {
                Text("EVs: " + ["hp", "atk", "def", "spa", "spd", "spe"]
                    .compactMap { key in evs[key].map { "\($0) \(key.uppercased())" } }
                    .joined(separator: " / "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Indices refer to the attempted paste (which may have been rejected),
    /// so they are rendered without cross-referencing the current team.
    private func issueText(_ issue: TeamIssue) -> String {
        issue.memberIndex.map { "Slot \($0 + 1): \(issue.message)" } ?? issue.message
    }
}

#Preview {
    TeamSettingsView()
}
