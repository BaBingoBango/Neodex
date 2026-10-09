import NeodexKit
import SwiftData
import SwiftUI

@MainActor
extension SavedTeam {
    /// The team as the legality checker sees it.
    var legalitySets: [LegalitySet] {
        members.map {
            LegalitySet(id: $0.id.uuidString, pokemonID: $0.pokemonID, abilityID: $0.abilityID, itemID: $0.itemID,
                        moveIDs: $0.chosenMoveIDs, level: $0.level)
        }
    }

    /// The Smogon tier, when `format` names one of the standard Gen 9 singles formats.
    var smogonFormat: SmogonFormat? { format.flatMap(SmogonFormat.init(formatID:)) }
}

/// Checks a team against a Smogon tier: species, abilities, items, moves and the standard clauses.
struct TeamLegalityView: View {
    @Environment(\.database) private var database
    @Bindable var team: SavedTeam
    var issues: [LegalityIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle("Format Legality")
                Menu {
                    ForEach(SmogonFormat.allCases) { format in
                        Button {
                            team.format = format.id
                            team.touch()
                        } label: {
                            if team.smogonFormat == format {
                                Label(format.name, systemImage: "checkmark")
                            } else {
                                Text(format.name)
                            }
                        }
                    }
                } label: {
                    Label(team.smogonFormat?.name ?? "Choose Tier", systemImage: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
            }
            if let format = team.smogonFormat {
                if issues.isEmpty {
                    Label("Legal in \(format.name)", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(groupedIssues, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                    .font(.subheadline.weight(.semibold))
                                ForEach(group.issues) { issue in
                                    Label(issue.message, systemImage: icon(for: issue.kind))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                Text("Pick a Smogon tier to check tiers, moves, items and clauses. Other formats, like VGC, can still be typed above but aren't checked.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct IssueGroup {
        var title: String
        var issues: [LegalityIssue]
    }

    private var groupedIssues: [IssueGroup] {
        var groups: [IssueGroup] = []
        for member in team.members {
            let mine = issues.filter { $0.setID == member.id.uuidString }
            guard !mine.isEmpty else { continue }
            groups.append(IssueGroup(title: database.pokemon(id: member.pokemonID)?.name ?? member.pokemonID, issues: mine))
        }
        let teamWide = issues.filter { $0.setID == nil }
        if !teamWide.isEmpty { groups.append(IssueGroup(title: "Team", issues: teamWide)) }
        return groups
    }

    private func icon(for kind: LegalityIssue.Kind) -> String {
        switch kind {
        case .pokemon: "person.crop.circle.badge.exclamationmark"
        case .ability: "sparkles"
        case .item: "cube"
        case .move: "burst"
        case .team: "person.3"
        }
    }
}
