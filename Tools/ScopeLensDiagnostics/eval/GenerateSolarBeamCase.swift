//
//  GenerateSolarBeamCase.swift
//  ScopeLens Diagnostics — m15-B/D: eval case #1's RECORDED INVOCATION.
//
//  Rebuilds the pilot's Solar Beam-loss board (2026-07-13 19:54 archive,
//  ask 2: "Charizard is going to die … so I cash it in" — then Tyranitar's
//  Rock Slide fired first) through the REAL context builders + engine, and
//  writes Tools/ScopeLensDiagnostics/eval/cases/solar-beam-cash-in.json with assertions
//  derived from the computed board (the doomed tier tracks the data:
//  0-EV-era it was speedRisk; with m15-D modal spreads Excadrill orders
//  first and the tier is guaranteed).
//
//  Regenerate (from repo root) after ANY meta snapshot or engine change:
//    swiftc -O Tools/ScopeLensDiagnostics/eval/GenerateSolarBeamCase.swift \
//      "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleVocabulary.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleEventParser.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleReconciler.swift" "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/ScoutEngine.swift" "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/AdvisorContext.swift" "Packages/ScopeLens/Sources/ScopeLens/AdvisorClient.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/AdvisorTools.swift" "Packages/ScopeLens/Sources/ScopeLens/PlayLint.swift" \
//      -o /tmp/sl-gen-sb && /tmp/sl-gen-sb
//

import Foundation

@main
struct GenerateSolarBeamCase {
    static func main() throws {

        // m15-B: generate the Solar Beam eval case (inline source) by rebuilding
        // the pilot's fatal board (battle of 2026-07-13 19:54, lost — ask 2:
        // "Charizard is going to die ... so I cash it in for value") through the
        // REAL context builders + engine. Output: the case JSON, contexts included.

        let repoRoot = FileManager.default.currentDirectoryPath

        guard let (team, teamVocab, _) = try? Team.fromRepoDefault(root: repoRoot) else {
            fputs("no default team\n", stderr); exit(1)
        }
        let engineSource = try String(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensEngine/dist/engine.js"), encoding: .utf8)
        let meta = try? Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensEngine/data/meta-regmbs3.json"))
        let engine = try ScoutEngine(engineSource: engineSource, metaJSON: meta)
        let vocabulary = try BattleVocabulary.fromRepo(root: repoRoot)
        let executor = AdvisorToolExecutor(engine: engine, vocabulary: vocabulary,
                                           configuredTeam: team.members.map(\.monSpec))

        // ── the six + capsules (record 21E1A1E1's opponentSpecies) ─────────────
        let oppSix = ["Houndstone", "Excadrill", "Staraptor", "Tyranitar", "Scovillain", "Rotom-Wash"]
        let capsules = executor.buildCapsules(species: oppSix)
        let staticContext = AdvisorContext.buildStatic(yourTeam: team.members,
                                                       teamVocab: teamVocab, capsules: capsules)

        // ── your actives: mega Zard-Y at 14%, Incineroar at 72% ────────────────
        func member(_ species: String) -> TeamMember {
            team.members.first { $0.species == species }!
        }
        let zard = member("Charizard"), incin = member("Incineroar")

        func spec(_ m: TeamMember, species: String? = nil, curPct: Double,
                  moves: [String]? = nil, boosts: [String: Int]? = nil) -> MonSpec {
            let base = m.monSpec
            return MonSpec(species: species ?? base.species, item: base.item,
                           ability: base.ability, moves: moves ?? base.moves,
                           boosts: boosts ?? base.boosts, curPct: curPct,
                           status: nil, evs: base.evs, ivs: base.ivs,
                           nature: base.nature, level: base.level,
                           teraType: base.teraType)
        }

        let mine: [MonSpec] = [
            spec(zard, species: "Charizard-Mega-Y", curPct: 14),
            spec(incin, curPct: 72),
        ]
        // Opp sets from usage priors (the engine fills them), observed HP applied.
        let theirs: [MonSpec] = [
            MonSpec(species: "Tyranitar", curPct: 57),
            MonSpec(species: "Excadrill", item: "Focus Sash", curPct: 1),
        ]
        let field = LiveFieldSpec(weather: "Sun")
        let matchup = try engine.liveMatchup(mine: mine, theirs: theirs, field: field)

        // ── snapshots + state for buildTurn ────────────────────────────────────
        func snapshot(side: String, species: String, display: String, pct: Double,
                      moves: [String], item: String?, ability: String?,
                      since: Int) -> BattleReconciler.ActiveSnapshot {
            .init(side: side, species: species, displayName: display, curPct: pct,
                  status: nil, boosts: [:], revealedMoves: moves, item: item,
                  ability: ability, perishCount: nil, onFieldSinceTurn: since,
                  protectedLastTurn: false, protectStreak: 0,
                  choiceLockedMove: nil, hints: [])
        }
        let snapshots = [
            snapshot(side: "you", species: "Charizard-Mega-Y", display: "Charizard",
                     pct: 14, moves: ["Heat Wave", "Solar Beam"], item: "Charizardite Y",
                     ability: "Drought", since: 0),
            snapshot(side: "you", species: "Incineroar", display: "Incineroar",
                     pct: 72, moves: ["Fake Out"], item: nil,
                     ability: "Intimidate", since: 0),
            snapshot(side: "opp", species: "Tyranitar", display: "Tyranitar",
                     pct: 57, moves: ["Rock Slide"], item: nil,
                     ability: "Sand Stream", since: 0),
            snapshot(side: "opp", species: "Excadrill", display: "Excadrill",
                     pct: 1, moves: ["Rock Slide", "Iron Head"], item: "Focus Sash",
                     ability: nil, since: 0),
        ]
        var state = BattleState()
        state.turn = 2
        state.weather = .init(kind: "sun", turnsLeft: 3)
        state.yourSide.active = [
            PokemonState(speciesId: "Charizard-Mega-Y", displayName: "Charizard",
                         hp: .exact(22, 154)),
            PokemonState(speciesId: "Incineroar", hp: .exact(146, 202)),
        ]
        state.yourSide.bench = [
            PokemonState(speciesId: "Garchomp", hp: .exact(184, 184)),
            PokemonState(speciesId: "Rotom-Wash", hp: .exact(155, 155)),
        ]
        state.oppSide.active = [
            PokemonState(speciesId: "Tyranitar", hp: .percent(57)),
            PokemonState(speciesId: "Excadrill", hp: .percent(1)),
        ]
        state.oppSide.bench = [
            PokemonState(speciesId: "Houndstone"),
            PokemonState(speciesId: "Staraptor"),
            PokemonState(speciesId: "Scovillain"),
            PokemonState(speciesId: "Rotom-Wash"),
        ]

        let turnContext = AdvisorContext.buildTurn(
            snapshots: snapshots, field: field, matchup: matchup, state: state,
            recentEvents: [], yourBench: state.yourSide.bench,
            oppBench: state.oppSide.bench, capsules: capsules)

        var configured: [String: LintContext.ConfiguredMon] = [:]
        for m in team.members {
            let mon = LintContext.ConfiguredMon(moves: m.moves, item: m.item)
            configured[m.species.lowercased()] = mon
            configured[m.displayName(vocab: teamVocab).lowercased()] = mon
        }
        // The mega rides the base species' configured slot.
        configured["charizard-mega-y"] = configured["charizard"]
        let lintContext = LintContext.build(
            snapshots: snapshots, field: field, matchup: matchup, state: state,
            yourBench: state.yourSide.bench, configured: configured, capsules: capsules)

        print("──── SPEEDS ────")
        for s in matchup.speeds { print("  \(s.species)(\(s.side)) \(s.spe)\(s.approx ? "~" : "")") }
        print("──── DOOMED ────")
        for d in lintContext.doomed {
            print("  \(d.species) ← \(d.killer) \(d.killerMove) [\(d.tier.rawValue)]"
                  + (d.killerCeiling.map { " ceiling \($0)" } ?? ""))
        }
        print("──── INCOMING KO LINES ────")
        for p in matchup.incoming where p.koNow || p.guaranteedKo {
            print("  \(p.attacker) \(p.move) → \(p.defender) \(p.minPct)-\(p.maxPct)% \(p.guaranteedKo ? "GKO" : "ko-range")")
        }

        // ── the case file ──────────────────────────────────────────────────────
        struct Inline: Encodable {
            let staticContext: String
            let turnContext: String
            let lintContext: LintContext
        }
        struct Source: Encodable { let inline: Inline }
        struct Assertion: Encodable {
            let type: String
            var pokemon: String? = nil
            var move: String? = nil
            var species: String? = nil
            var tier: String? = nil
        }
        struct CaseFile: Encodable {
            let name: String
            let description: String
            let source: Source
            let assertions: [Assertion]
        }
        guard let zardDoom = lintContext.doomed.first(where: { $0.species == "Charizard-Mega-Y" }) else {
            fputs("REFUSING to write the case: Charizard-Mega-Y is not doomed-flagged on the rebuilt board — the data or engine changed semantics; re-verify by hand.\n", stderr)
            exit(1)
        }
        let caseFile = CaseFile(
            name: "solar-beam-cash-in",
            description: "EVAL CASE #1 — the pilot's Solar Beam loss (2026-07-13 19:54 archive, ask 2, reconstructed board via Tools/ScopeLensDiagnostics/eval/GenerateSolarBeamCase.swift — the recorded invocation; battle log omitted). The advisor said 'Charizard is going to die… so I cash it in' and 'I outspeed with Charizard' — then Tyranitar's Rock Slide fired first and Solar Beam never happened. The ladder actually runs Excadrill at max speed (modal spread), so Charizard's slot is doomed (tier: \(zardDoom.tier.rawValue)) and the committed play must NOT be the Solar Beam cash-in (pilot verdict).",
            source: Source(inline: Inline(staticContext: staticContext,
                                          turnContext: turnContext,
                                          lintContext: lintContext)),
            assertions: [
                Assertion(type: "doomedFlag", species: "Charizard-Mega-Y", tier: zardDoom.tier.rawValue),
                Assertion(type: "commit"),
                Assertion(type: "lintClean"),
                Assertion(type: "forbid", pokemon: "Charizard", move: "Solar Beam"),
            ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(caseFile)
        try data.write(to: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensDiagnostics/eval/cases/solar-beam-cash-in.json"))
        print("\ncase written: Tools/ScopeLensDiagnostics/eval/cases/solar-beam-cash-in.json (\(data.count) bytes)")
    }
}
