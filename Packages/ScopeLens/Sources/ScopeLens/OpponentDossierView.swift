//
//  OpponentDossierView.swift
//  Scope Lens
//
//  Phase 3, m12-C: the Opponent Dossier — "google the enemy, at a glance."
//  One card per known opponent: likely ability/moves/items with usage %
//  AND plain-English effects (engine dexInfo), defensive typing, speed
//  bracket, priority-blocker warning. Pure views over plain data (mock-
//  previewable, like OverlayContentView); LiveTrackerModel owns the feed.
//
//  Data doctrine: everything on a card is a USAGE PRIOR (Reg M-B ranked
//  data), not an observation — the caption says so. Observed facts live in
//  the Battle Log / matchup panel; this window answers "what does that do?"
//

import SwiftUI

// MARK: - Dossier data (plain, Sendable — built on the engine actor)

/// Everything one card renders, composed from an `OpponentCapsule` (usage
/// priors + typing + speed, m11) and the engine's `dexInfo` effect text
/// (m12-C). Plain data so the card previews without a live tracker.
nonisolated public struct OpponentDossier: Identifiable, Sendable {
    nonisolated public struct MoveLine: Identifiable, Sendable {
        public let name: String
        public let pct: Double
        public let info: DexInfo.MoveInfo?   // nil / known=false ⇒ no dex entry
        public var id: String { name }
    }
    nonisolated public struct ItemLine: Identifiable, Sendable {
        public let name: String
        public let pct: Double
        public let shortDesc: String?        // top item only (glance economy)
        public var id: String { name }
    }
    public let capsule: OpponentCapsule
    public let isActive: Bool                // on the field right now
    public let abilityDesc: String?          // top ability's effect text
    public let moves: [MoveLine]
    public let items: [ItemLine]
    public var id: String { capsule.species }
}

nonisolated extension OpponentDossier {

    /// Compose dossiers for the given species in DISPLAY order (actives
    /// first, then bench — the caller's order is preserved). Internally
    /// `buildCapsules` dedups + sorts by name for prompt-cache stability;
    /// this reorders its output back to the on-screen order and attaches
    /// effect text with ONE engine call for all cards.
    static func build(ordered: [(species: String, active: Bool)],
                      executor: AdvisorToolExecutor) throws -> [OpponentDossier] {
        guard !ordered.isEmpty else { return [] }
        let capsules = executor.buildCapsules(species: ordered.map(\.species))
        let bySpecies = Dictionary(capsules.map { ($0.species, $0) }) { a, _ in a }

        var seen = Set<String>()
        var orderedCapsules: [(capsule: OpponentCapsule, active: Bool)] = []
        for (raw, active) in ordered {
            let canonical = executor.resolve(raw)?.name ?? raw
            guard seen.insert(canonical).inserted,
                  let capsule = bySpecies[canonical] else { continue }
            orderedCapsules.append((capsule, active))
        }

        let moveNames = orderedCapsules.flatMap { $0.capsule.topMoves.map(\.name) }
        let abilityNames = orderedCapsules.compactMap { $0.capsule.topAbility?.name }
        let itemNames = orderedCapsules.flatMap { $0.capsule.topItems.map(\.name) }
        let dex = try executor.engine.dexInfo(moves: moveNames,
                                              abilities: abilityNames,
                                              items: itemNames)
        // dexInfo answers in input order — zip back into name-keyed tables.
        let moveInfo = Dictionary(zip(moveNames, dex.moves)) { a, _ in a }
        let abilityInfo = Dictionary(zip(abilityNames, dex.abilities)) { a, _ in a }
        let itemInfo = Dictionary(zip(itemNames, dex.items)) { a, _ in a }

        return orderedCapsules.map { entry in
            OpponentDossier(
                capsule: entry.capsule,
                isActive: entry.active,
                abilityDesc: entry.capsule.topAbility.flatMap {
                    abilityInfo[$0.name].flatMap { $0.known ? $0.shortDesc : nil }
                },
                moves: entry.capsule.topMoves.map {
                    MoveLine(name: $0.name, pct: $0.pct,
                             info: moveInfo[$0.name].flatMap { $0.known ? $0 : nil })
                },
                items: entry.capsule.topItems.enumerated().map { i, stat in
                    ItemLine(name: stat.name, pct: stat.pct,
                             shortDesc: i == 0
                                ? itemInfo[stat.name].flatMap { $0.known ? $0.shortDesc : nil }
                                : nil)
                })
        }
    }
}

// MARK: - Your team's type matchups (m12-C+: the switch-decision aid)

/// One configured team member's type picture: base typing + defensive
/// profile, plus the post-mega typing when a held stone CHANGES it
/// (Zard-X class). Plain data, built on the engine actor like the
/// dossiers. No Tera anywhere — Champions has no Terastallization
/// (pilot-confirmed 2026-07-09).
nonisolated public struct TeamTypeEntry: Sendable {
    public let species: String
    public let types: [String]
    public let defensive: [String: [String]]
    public let isActive: Bool                     // on the field right now
    public let megaTypes: [String]?               // only when ≠ base typing
    public let megaDefensive: [String: [String]]?
}

nonisolated extension TeamTypeEntry {

    /// Build the your-team rows: actives first (stable team order within
    /// each group). `activeKeys` are lowercased species/display names of
    /// your current on-field mons (empty outside a battle).
    static func build(members: [TeamMember], activeKeys: Set<String>,
                      executor: AdvisorToolExecutor) -> [TeamTypeEntry] {
        let entries = members.map { member -> TeamTypeEntry in
            let resolved = executor.resolve(member.species)
            let species = resolved?.name ?? member.species
            let types = resolved?.types ?? []
            let defensive = types.isEmpty
                ? [:] : (try? executor.engine.defensiveProfile(types: types)) ?? [:]

            // Held mega stone → the post-mega typing, shown only when it
            // actually changes the type picture (same stone convention as
            // engine.ts calcSpecies).
            var megaTypes: [String]?
            var megaDefensive: [String: [String]]?
            if let megaName = megaForme(species: species, item: member.item),
               let mega = executor.resolve(megaName),
               !mega.types.isEmpty, Set(mega.types) != Set(types) {
                megaTypes = mega.types
                megaDefensive = (try? executor.engine.defensiveProfile(types: mega.types)) ?? [:]
            }

            let keys = [member.species, species, resolved?.display ?? ""]
                .map { $0.lowercased() }
            return TeamTypeEntry(
                species: species, types: types, defensive: defensive,
                isActive: keys.contains { activeKeys.contains($0) },
                megaTypes: megaTypes, megaDefensive: megaDefensive)
        }
        return entries.filter(\.isActive) + entries.filter { !$0.isActive }
    }

    /// Mega-stone → forme name, mirroring engine.ts calcSpecies ("…ite Y"
    /// → -Mega-Y, "…ite X" → -Mega-X, other "…ite" except Eviolite → -Mega).
    private static func megaForme(species: String, item: String?) -> String? {
        guard let item, item != "Eviolite" else { return nil }
        if item.hasSuffix("ite Y") { return "\(species)-Mega-Y" }
        if item.hasSuffix("ite X") { return "\(species)-Mega-X" }
        if item.hasSuffix("ite") { return "\(species)-Mega" }
        return nil
    }
}

// MARK: - One opponent, at a glance

struct OpponentDossierCard: View {
    let dossier: OpponentDossier

    private var capsule: OpponentCapsule { dossier.capsule }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            if let blocker = capsule.priorityBlockerLikely {
                Text("⚠️ likely \(blocker) — priority moves into its side fail")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            defensiveLine
            if !capsule.hasMeta {
                Text("no usage data (off-ladder) — typing and speed only")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let ability = capsule.topAbility {
                section("Ability") {
                    VStack(alignment: .leading, spacing: 1) {
                        statLine(name: ability.name, pct: ability.pct, kind: .ability)
                        effectText(dossier.abilityDesc)
                    }
                }
            }
            if !dossier.moves.isEmpty {
                section("Moves") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(dossier.moves) { moveRow($0) }
                    }
                }
            }
            if !dossier.items.isEmpty {
                section("Items") {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            ForEach(Array(dossier.items.enumerated()), id: \.offset) { index, item in
                                if index > 0 { Text("·").foregroundStyle(.tertiary) }
                                statLine(name: item.name, pct: item.pct, kind: .item)
                            }
                        }
                        effectText(dossier.items.first?.shortDesc)
                    }
                }
            }
            footer
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dossier for \(capsule.species)"
                            + (dossier.isActive ? ", currently on the field" : ""))
    }

    private var header: some View {
        HStack(spacing: 8) {
            EntryLink(name: capsule.species, kind: .species, font: .title3, weight: .bold)
            if !capsule.types.isEmpty {
                Text(capsule.types.joined(separator: " / "))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
            }
            if let bias = capsule.offenseBias {
                // m12-G: which defensive stat matters against it, at a glance.
                Text("\(bias) atk")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(bias == "physical" ? .orange
                                     : bias == "special" ? .blue : .purple)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(.quaternary))
                    .accessibilityLabel("\(bias) attacker")
            }
            if let winrate = capsule.winrate {
                Text("\(fmt(winrate))% winrate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if dossier.isActive {
                Text("ACTIVE")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(.green))
                    .accessibilityLabel("Currently active")
            }
        }
    }

    /// "What do I hit it with" — the defensive typing in one line.
    private var defensiveLine: some View {
        let joined = TypeMatchupLine.text(for: capsule.defensive)
        return joined
            .font(.callout)
            .accessibilityLabel(Text("Type matchups. \(joined)"))
    }

    private func moveRow(_ move: OpponentDossier.MoveLine) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 8) {
                statLine(name: move.name, pct: move.pct, kind: .move)
                if let mech = mechanics(move.info) {
                    Text(mech)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            effectText(move.info?.shortDesc)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Fire · Physical · 120 BP · 90% · +1 priority" — accuracy omitted
    /// when the move can't miss, priority only when it jumps the order.
    private func mechanics(_ info: DexInfo.MoveInfo?) -> String? {
        guard let info else { return nil }
        var bits: [String] = []
        if let type = info.type { bits.append(type) }
        if let category = info.category { bits.append(category) }
        if let bp = info.basePower, bp > 0 { bits.append("\(bp) BP") }
        if let accuracy = info.accuracy { bits.append("\(accuracy)%") }
        if let priority = info.priority, priority != 0 {
            bits.append("\(priority > 0 ? "+" : "")\(priority) priority")
        }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let mn = capsule.speedMin, let mx = capsule.speedMax {
                Text("Spe \(mn)–\(mx)"
                     + (capsule.scarfPossible ? " (Scarf → \(Int(Double(mx) * 1.5)))" : ""))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .accessibilityLabel("Speed \(mn) to \(mx)"
                        + (capsule.scarfPossible
                           ? ", up to \(Int(Double(mx) * 1.5)) with Choice Scarf" : ""))
            }
            Spacer(minLength: 0)
            Text("usage priors, not observed")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: small pieces

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            content()
        }
        .accessibilityElement(children: .combine)
    }

    /// A name and its usage share; the name opens its Neodex entry when Neodex hosts Scope Lens.
    private func statLine(name: String, pct: Double, kind: NeodexBridge.EntryKind? = nil) -> some View {
        HStack(spacing: 6) {
            if let kind {
                EntryLink(name: name, kind: kind, font: .callout, weight: .semibold)
            } else {
                Text(name).font(.callout.weight(.semibold))
            }
            Text("\(fmt(pct))%")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func effectText(_ desc: String?) -> some View {
        if let desc, !desc.isEmpty {
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - Shared defensive-typing line

/// Renders a defensive profile ({x4/x2/x05/x025/x0} → type lists) as one
/// colored line — shared by the opponent cards and the your-team rows.
enum TypeMatchupLine {
    static func text(for d: [String: [String]]) -> Text {
        var segments: [Text] = []
        func add(_ label: String, _ types: [String], _ color: Color) {
            guard !types.isEmpty else { return }
            segments.append(Text(
                "\(Text("\(label): ").foregroundStyle(color).bold())\(types.joined(separator: ", "))"))
        }
        add("4× weak", d["x4"] ?? [], .red)
        add("weak", d["x2"] ?? [], .red)
        add("resists", (d["x05"] ?? []) + (d["x025"] ?? []), .green)
        add("immune", d["x0"] ?? [], .blue)
        return joined(segments,
                      separator: Text("  ·  ").foregroundStyle(.tertiary),
                      empty: Text("no notable type matchups"))
    }

    /// Text concatenation via interpolation (the `+` operator is deprecated
    /// on macOS 26; interpolation preserves per-segment styling).
    static func joined(_ segments: [Text], separator: Text, empty: Text) -> Text {
        guard var out = segments.first else { return empty }
        for segment in segments.dropFirst() {
            out = Text("\(out)\(separator)\(segment)")
        }
        return out
    }
}

// MARK: - Your team, at a glance (m12-C+)

/// The switch-decision card: every configured team member's typing and
/// defensive matchups in one compact block — actives first mid-battle.
struct TeamTypeCard: View {
    let entries: [TeamTypeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR TEAM — TYPE MATCHUPS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                row(entry)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your team's type matchups")
    }

    private func row(_ entry: TeamTypeEntry) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 8) {
                Text(entry.species)
                    .font(.callout.weight(.bold))
                if !entry.types.isEmpty {
                    Text(entry.types.joined(separator: " / "))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(.quaternary))
                }
                Spacer(minLength: 0)
                if entry.isActive {
                    Text("ACTIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(.green))
                        .accessibilityLabel("Currently active")
                }
            }
            TypeMatchupLine.text(for: entry.defensive)
                .font(.caption)
            if let megaTypes = entry.megaTypes, let megaDefensive = entry.megaDefensive {
                Text("\(Text("Mega (\(megaTypes.joined(separator: "/"))): ").foregroundStyle(.secondary).bold())\(TypeMatchupLine.text(for: megaDefensive))")
                    .font(.caption)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The window (⇧⌘K)

public struct DossierWindowView: View {
    @ObservedObject private var model = LiveTrackerModel.shared


    public init() {}
    public var body: some View {
        Group {
            if model.dossiers.isEmpty && model.teamTypes.isEmpty {
                ContentUnavailableView(
                    "Nothing on file yet",
                    systemImage: "text.book.closed",
                    description: Text("Add your team in Settings (⌘,) to always "
                        + "see its type matchups here. Opponent dossiers appear "
                        + "at team preview and refresh as the battle reveals "
                        + "who's really out there."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if !model.teamTypes.isEmpty {
                            TeamTypeCard(entries: model.teamTypes)
                        }
                        if !model.dossiers.isEmpty {
                            Text(model.dossiers.contains(where: \.isActive)
                                 ? "Opponents — actives first, then bench. Reg M-B ranked usage priors."
                                 : "Opponents — team preview read. Reg M-B ranked usage priors.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(model.dossiers) { OpponentDossierCard(dossier: $0) }
                        } else if !model.teamTypes.isEmpty {
                            Text("Opponent dossiers appear at team preview.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(minWidth: 430, minHeight: 420)
    }
}

// MARK: - Mock previews (the layout is verifiable without a live battle)

private enum DossierMock {
    static let farigiraf = OpponentDossier(
        capsule: OpponentCapsule(
            species: "Farigiraf", types: ["Normal", "Psychic"], hasMeta: true,
            winrate: 52.4,
            topMoves: [.init(name: "Trick Room", pct: 95.7),
                       .init(name: "Foul Play", pct: 74.9),
                       .init(name: "Helping Hand", pct: 64.9),
                       .init(name: "Psychic", pct: 38.2)],
            topItems: [.init(name: "Sitrus Berry", pct: 43.4),
                       .init(name: "Electric Seed", pct: 22.1)],
            topAbility: .init(name: "Armor Tail", pct: 91.2),
            offenseBias: "mixed",
            speedMin: 60, speedMax: 123,
            speedModal: 92, speedModalPct: 31.4,
            teammates: ["Ursaluna", "Indeedee-F", "Torkoal"],
            scarfPossible: false,
            priorityBlockerLikely: "Armor Tail",
            defensive: ["x4": [], "x2": ["Bug", "Dark"],
                        "x05": [], "x025": [], "x0": ["Ghost"]]),
        isActive: true,
        abilityDesc: "This Pokemon and its allies are protected from opposing priority moves.",
        moves: [
            .init(name: "Trick Room", pct: 95.7,
                  info: .init(name: "Trick Room", known: true, type: "Psychic",
                              category: "Status", basePower: 0, accuracy: nil,
                              priority: -7,
                              shortDesc: "Goes last. For 5 turns, turn order is reversed.")),
            .init(name: "Foul Play", pct: 74.9,
                  info: .init(name: "Foul Play", known: true, type: "Dark",
                              category: "Physical", basePower: 95, accuracy: 100,
                              priority: 0,
                              shortDesc: "Uses target's Attack stat in damage calculation.")),
            .init(name: "Helping Hand", pct: 64.9,
                  info: .init(name: "Helping Hand", known: true, type: "Normal",
                              category: "Status", basePower: 0, accuracy: nil,
                              priority: 5,
                              shortDesc: "Goes first. The target's move power is 1.5x.")),
            .init(name: "Psychic", pct: 38.2,
                  info: .init(name: "Psychic", known: true, type: "Psychic",
                              category: "Special", basePower: 90, accuracy: 100,
                              priority: 0,
                              shortDesc: "10% chance to lower the target's Sp. Def by 1.")),
        ],
        items: [.init(name: "Sitrus Berry", pct: 43.4,
                      shortDesc: "Restores 1/4 max HP when at 1/2 max HP or less. Single use."),
                .init(name: "Electric Seed", pct: 22.1, shortDesc: nil)])

    static let offLadder = OpponentDossier(
        capsule: OpponentCapsule(
            species: "Ho-Oh", types: ["Fire", "Flying"], hasMeta: false,
            winrate: nil, topMoves: [], topItems: [], topAbility: nil,
            offenseBias: nil,
            speedMin: 110, speedMax: 156,
            speedModal: nil, speedModalPct: nil, teammates: [],
            scarfPossible: false,
            priorityBlockerLikely: nil,
            defensive: ["x4": ["Rock"], "x2": ["Water", "Electric"],
                        "x05": ["Fire", "Grass", "Fighting", "Bug", "Steel", "Fairy"],
                        "x025": [], "x0": ["Ground"]]),
        isActive: false, abilityDesc: nil, moves: [], items: [])
}

#Preview("Dossier cards") {
    ScrollView {
        VStack(spacing: 10) {
            OpponentDossierCard(dossier: DossierMock.farigiraf)
            OpponentDossierCard(dossier: DossierMock.offLadder)
        }
        .padding(14)
    }
    .frame(width: 470, height: 640)
}

private enum TeamTypeMock {
    static let entries: [TeamTypeEntry] = [
        TeamTypeEntry(
            species: "Charizard", types: ["Fire", "Flying"],
            defensive: ["x4": ["Rock"], "x2": ["Water", "Electric"],
                        "x05": ["Fire", "Grass", "Fighting", "Bug", "Steel", "Fairy"],
                        "x025": [], "x0": ["Ground"]],
            isActive: true,
            megaTypes: ["Fire", "Dragon"],
            megaDefensive: ["x4": [], "x2": ["Rock", "Ground", "Dragon"],
                            "x05": ["Electric", "Bug", "Steel"],
                            "x025": ["Fire", "Grass"], "x0": []]),
        TeamTypeEntry(
            species: "Rotom-Wash", types: ["Electric", "Water"],
            defensive: ["x4": [], "x2": ["Grass"],
                        "x05": ["Fire", "Water", "Ice", "Flying", "Steel"],
                        "x025": [], "x0": ["Ground"]],
            isActive: false, megaTypes: nil, megaDefensive: nil),
        TeamTypeEntry(
            species: "Incineroar", types: ["Fire", "Dark"],
            defensive: ["x4": [], "x2": ["Water", "Fighting", "Ground", "Rock"],
                        "x05": ["Fire", "Grass", "Ice", "Ghost", "Steel", "Dark"],
                        "x025": [], "x0": ["Psychic"]],
            isActive: false, megaTypes: nil, megaDefensive: nil),
    ]
}

#Preview("Your team card") {
    ScrollView {
        TeamTypeCard(entries: TeamTypeMock.entries)
            .padding(14)
    }
    .frame(width: 470, height: 420)
}
