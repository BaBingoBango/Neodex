import NeodexKit
import SwiftUI

/// Everything about one move.
struct MoveDetailView: View {
    @Environment(\.database) private var database
    var move: Move

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsRow
                descriptions
                effects
                learners
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(move.name)
        .navigationBarTitleDisplayMode(.inline)
        .recordsHistory(.move, id: move.id)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                NavigationLink(value: AppRoute.type(move.type)) { TypeBadge(type: move.type) }
                    .buttonStyle(.plain)
                Label(move.category.name, systemImage: move.category.systemImage)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(move.category.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                if move.kind != .standard {
                    Text(move.kind.name)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Spacer()
                if let tm = move.tmLabel {
                    Text(tm)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(move.name)
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            if move.availability != .current {
                Text(move.availability.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatPill(label: "Power", value: move.basePowerText)
            StatPill(label: "Accuracy", value: move.accuracyText)
            StatPill(label: "PP", value: "\(move.pp)")
            StatPill(label: "Priority", value: move.priority > 0 ? "+\(move.priority)" : "\(move.priority)")
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var descriptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let description = move.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In-Game Description").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(description).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let competitive = move.longDescription ?? move.shortDescription, competitive != move.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Competitive Effect").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(competitive).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var effects: some View {
        let facts = effectFacts
        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Details")
                ForEach(facts, id: \.0) { label, value in
                    LabeledContent(label, value: value)
                }
            }
            .padding(.horizontal)
        }
    }

    private var effectFacts: [(String, String)] {
        var facts: [(String, String)] = []
        facts.append(("Target", move.targetDescription))
        facts.append(("Generation", "Gen \(move.generation)"))
        if let chance = move.effectChance, chance < 100 { facts.append(("Effect chance", "\(chance)%")) }
        if let changes = move.statChanges, !changes.isEmpty {
            let text = changes.map { change in
                let direction = change.stages > 0 ? "+" : ""
                return "\(direction)\(change.stages) \(change.stat.shortName) (\(change.affectsUser ? "user" : "target"))"
            }.joined(separator: ", ")
            facts.append(("Stat changes", text))
        }
        if let crit = move.critRatio { facts.append(("Critical hit", "High ratio (+\(crit))")) }
        if let drain = move.drain, drain.count == 2 { facts.append(("Drain", "Heals \(drain[0])/\(drain[1]) of damage dealt")) }
        if let recoil = move.recoil, recoil.count == 2 { facts.append(("Recoil", "\(recoil[0])/\(recoil[1]) of damage dealt")) }
        if let hits = move.multiHit, hits.count == 2 { facts.append(("Hits", hits[0] == hits[1] ? "\(hits[0]) times" : "\(hits[0])–\(hits[1]) times")) }
        if move.isOneHitKO { facts.append(("One-hit KO", "Yes")) }
        let flagNames: [(String, String)] = [("contact", "Makes contact"), ("sound", "Sound-based"), ("punch", "Punching move"),
                                             ("bite", "Biting move"), ("bullet", "Ballistic"), ("wind", "Wind move"), ("slicing", "Slicing move"),
                                             ("dance", "Dance move"), ("powder", "Powder move"), ("pulse", "Pulse move"), ("heal", "Healing"),
                                             ("snatch", "Can be Snatched"), ("reflectable", "Reflected by Magic Coat"), ("bypasssub", "Bypasses Substitute"),
                                             ("charge", "Charges for a turn"), ("recharge", "Needs to recharge"), ("gravity", "Disabled by Gravity"),
                                             ("defrost", "Thaws the user")]
        let flags = flagNames.filter { move.flags.contains($0.0) }.map(\.1)
        if !flags.isEmpty { facts.append(("Properties", flags.joined(separator: ", "))) }
        if !move.flags.contains("protect"), move.category != .status || move.target != "self" {
            facts.append(("Protect", "Bypasses Protect"))
        }
        return facts
    }

    private var learners: some View {
        let count = database.learners(of: move).count
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Learned By")
            if count == 0 {
                Text("No Pokémon can currently learn this move.")
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink(value: AppRoute.moveLearners(move.id)) {
                    HStack {
                        Text("\(count) Pokémon")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .card()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

/// Every Pokémon that can learn a move, with how.
struct MoveLearnersView: View {
    @Environment(\.database) private var database
    var move: Move
    @State private var searchText = ""

    private var learners: [(pokemon: Pokemon, sources: [LearnSource])] {
        let all = database.learners(of: move)
        let query = SearchNormalizer.normalize(searchText)
        guard !query.isEmpty else { return all }
        return all.filter { SearchNormalizer.normalize($0.pokemon.displayName).contains(query) }
    }

    var body: some View {
        List(learners, id: \.pokemon.id) { entry in
            NavigationLink(value: AppRoute.pokemon(entry.pokemon.id)) {
                HStack(spacing: 12) {
                    PokemonImage(pokemon: entry.pokemon, kind: .sprite)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.pokemon.displayName).font(.body.weight(.medium))
                        Text(entry.sources.map(\.label).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TypeBadgeRow(types: entry.pokemon.types, size: .small)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Filter Pokémon")
        .navigationTitle("\(move.name) Learners")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Flamethrower") {
    PreviewHost {
        if let move = PokedexDatabase.preview.move(named: "Flamethrower") { MoveDetailView(move: move) }
    }
}

#Preview("Learners") {
    PreviewHost {
        if let move = PokedexDatabase.preview.move(named: "Earthquake") { MoveLearnersView(move: move) }
    }
}
#endif
