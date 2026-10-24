import SwiftUI

/// What Neodex plugs into Scope Lens when it hosts it: a way to open Neodex's own entry for a name
/// Scope Lens shows, and a way to hand a question about the live battle to Dexbot. Both stay nil in
/// the standalone app, and every affordance that uses them renders as plain text there.
public enum NeodexBridge {
    public enum EntryKind: String, Sendable {
        case species, move, ability, item
    }

    /// Opens the Neodex entry for a Scope Lens name, in the engine's spelling ("Charizard-Mega-Y").
    public static var openEntry: ((EntryKind, String) -> Void)?

    /// Hands a question about the battle on screen to Dexbot, Neodex's on-device assistant.
    public static var askDexbot: ((String) -> Void)?
}

/// A name that opens its Neodex entry when Neodex hosts Scope Lens, and is plain text otherwise.
/// `display` is what the user sees when it differs from the name to look up (a nickname).
struct EntryLink: View {
    let name: String
    let kind: NeodexBridge.EntryKind
    var font: Font = .callout
    var weight: Font.Weight? = nil
    var display: String? = nil

    @State private var hovering = false

    var body: some View {
        if let open = NeodexBridge.openEntry {
            Button {
                open(kind, name)
            } label: {
                label.underline(hovering, color: .secondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help("Open \(name) in Neodex")
            .accessibilityHint("Opens the Neodex entry")
        } else {
            label
        }
    }

    private var label: Text {
        var text = Text(display ?? name).font(font)
        if let weight { text = text.fontWeight(weight) }
        return text
    }
}

extension LiveTrackerModel {
    /// The battle as Scope Lens sees it, in plain text for an assistant: the board, what the opponent
    /// has shown, the usage-based likely sets, the live matchup and the recent log. Nil when nothing is
    /// being tracked. Built from the same published state the Battle Log renders, kept short enough
    /// for Apple's on-device model.
    public func liveBattleSummary() -> String? {
        let inBattle = !battleEvents.isEmpty
        guard isRunning || inBattle || scoutReport != nil else { return nil }
        var sections: [String] = []

        var intro = "Scope Lens is watching a Pokémon Champions battle (VGC doubles: two Pokémon per side, Mega Evolution exists, no Terastallization). Names use Showdown spellings."
        if let current { intro += " Screen: \(current.primary.rawValue)." }
        if let outcome = battleOutcome { intro += " Outcome: \(outcome)." }
        if !isRunning { intro += " The tracker is stopped; this is the last state it saw." }
        sections.append(intro)

        let team = TeamManager.shared.team
        if !team.members.isEmpty {
            let lines = team.members.map { member -> String in
                var line = "- \(member.species)"
                if let item = member.item { line += " @ \(item)" }
                if let ability = member.ability { line += " (\(ability))" }
                if !member.moves.isEmpty { line += ": " + member.moves.joined(separator: " / ") }
                return line
            }
            sections.append("YOUR TEAM (configured):\n" + lines.joined(separator: "\n"))
        }

        if !battleStateLines.isEmpty {
            sections.append("BOARD:\n" + battleStateLines.joined(separator: "\n"))
        }

        let opponents = battleRoster.filter { $0.side == "opp" }
        if !opponents.isEmpty {
            let lines = opponents.map { mon -> String in
                var line = "- " + (mon.species == "unknown" ? mon.displayName : mon.species)
                if mon.species != "unknown", mon.displayName.lowercased() != mon.species.lowercased() { line += " (nicknamed \(mon.displayName))" }
                if mon.fainted { line += ", fainted" } else if mon.isActive { line += ", on the field" } else { line += ", in the back" }
                if mon.mega { line += ", Mega Evolved" }
                if let pct = mon.curPct { line += ", \(Int(pct))% HP" }
                if let status = mon.status { line += ", \(status)" }
                let boosts = mon.boosts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value > 0 ? "+" : "")\($0.value)" }
                if !boosts.isEmpty { line += ", boosts " + boosts.joined(separator: " ") }
                if !mon.moves.isEmpty { line += "; moves seen: " + mon.moves.map { "\($0.name)×\($0.uses)" }.joined(separator: ", ") }
                if let item = mon.item { line += "; item \(item)" }
                if let ability = mon.ability { line += "; ability \(ability)" }
                if let perish = mon.perishCount { line += "; Perish count \(perish)" }
                if mon.protectedLastTurn { line += "; Protected last turn" }
                return line
            }
            sections.append("OPPONENT, OBSERVED THIS BATTLE:\n" + lines.joined(separator: "\n"))
        }

        if let matchup = liveMatchup {
            var lines: [String] = []
            if !matchup.speeds.isEmpty {
                lines.append("Speed order" + (matchup.trickRoom ? " under Trick Room" : "") + ": "
                             + matchup.speeds.map { "\($0.species) (\($0.side == "you" ? "yours" : "theirs"), \($0.spe)\($0.approx ? "~" : ""))" }.joined(separator: " > "))
            }
            for pair in matchup.incoming.prefix(8) {
                lines.append("Their \(pair.attacker) \(pair.move) into your \(pair.defender): \(Self.pct(pair.minPct))–\(Self.pct(pair.maxPct))%"
                             + (pair.guaranteedKo ? " (guaranteed KO)" : pair.koNow ? " (KO roll)" : "") + (pair.setSource == "observed" ? "" : " [\(pair.setSource) set]"))
            }
            for pair in matchup.outgoing.prefix(8) {
                lines.append("Your \(pair.attacker) \(pair.move) into their \(pair.defender): \(Self.pct(pair.minPct))–\(Self.pct(pair.maxPct))%"
                             + (pair.guaranteedKo ? " (guaranteed KO)" : pair.koNow ? " (KO roll)" : ""))
            }
            if !lines.isEmpty { sections.append("LIVE MATCHUP (engine math):\n" + lines.joined(separator: "\n")) }
        }

        if !dossiers.isEmpty {
            let lines = dossiers.prefix(6).map { dossier -> String in
                let capsule = dossier.capsule
                var line = "- \(capsule.species)"
                if !capsule.types.isEmpty { line += " (\(capsule.types.joined(separator: "/")))" }
                if let ability = capsule.topAbility { line += ": ability \(ability.name) \(Self.pct(ability.pct))%" }
                if !capsule.topMoves.isEmpty { line += "; moves " + capsule.topMoves.map { "\($0.name) \(Self.pct($0.pct))%" }.joined(separator: ", ") }
                if !capsule.topItems.isEmpty { line += "; items " + capsule.topItems.map { "\($0.name) \(Self.pct($0.pct))%" }.joined(separator: ", ") }
                if let lo = capsule.speedMin, let hi = capsule.speedMax { line += "; Speed \(lo)–\(hi)" + (capsule.scarfPossible ? " (Choice Scarf possible)" : "") }
                if let blocker = capsule.priorityBlockerLikely { line += "; likely \(blocker), blocks priority" }
                if !capsule.hasMeta { line += "; no usage data" }
                return line
            }
            sections.append("OPPONENT LIKELY SETS (usage priors, not observed):\n" + lines.joined(separator: "\n"))
        }

        if let report = scoutReport {
            if inBattle {
                let threats = report.threats.prefix(4).map { "\($0.attacker) \($0.move) into \($0.defender): \(Self.pct($0.minPct))–\(Self.pct($0.maxPct))%" + ($0.ko ? " (KO range)" : "") }
                var text = "TEAM PREVIEW SCOUT: bring " + report.safeFour.joined(separator: ", ") + "; lead " + report.leads.joined(separator: " + ") + "."
                if !threats.isEmpty { text += "\nThreats: " + threats.joined(separator: "; ") }
                sections.append(text)
            } else {
                sections.append(AdvisorContext.buildPreview(scout: report))
            }
        }

        if inBattle {
            let recent = battleLogMarkdown.split(separator: "\n").map(String.init).filter { !$0.isEmpty }.suffix(14)
            if !recent.isEmpty { sections.append("RECENT LOG:\n" + recent.joined(separator: "\n")) }
        }

        // The on-device model has a small window; keep the whole thing under about 7,000 characters,
        // dropping the latest sections (the log, the preview) first.
        var text = sections.joined(separator: "\n\n")
        while text.count > 7000, sections.count > 2 {
            sections.removeLast()
            text = sections.joined(separator: "\n\n")
        }
        return text
    }

    private static func pct(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
