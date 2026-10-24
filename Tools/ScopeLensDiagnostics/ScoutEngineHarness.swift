//
//  ScoutEngineHarness.swift
//  ScopeLens Diagnostics — proves the app-target ScoutEngine bridge produces
//  the same numbers as the Phase-1 CLI on identical inputs, then smoke-runs
//  the Example Battle 3 live consensus through it.
//
//  Build & run (from repo root):
//    swiftc -O Tools/ScopeLensDiagnostics/ScoutEngineHarness.swift "Packages/ScopeLens/Sources/ScopeLens/ScoutEngine.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
//      -o /tmp/scoutengineharness && /tmp/scoutengineharness
//

import Foundation

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

@main
struct ScoutEngineHarness {
    static func main() throws {
        let engineSrc = try String(
            contentsOfFile: "Tools/ScopeLensEngine/dist/engine.js", encoding: .utf8)
        // Mirror the app path: inject the meta data file via setMeta (the
        // baked snapshot is the fallback when no file is present).
        let metaJSON = try Data(contentsOf: URL(fileURLWithPath: "Tools/ScopeLensEngine/data/meta-regmbs3.json"))
        let engine = try ScoutEngine(engineSource: engineSrc, metaJSON: metaJSON)

        // ---- the team comes from the committed default paste (m9) ----------
        let root = FileManager.default.currentDirectoryPath
        let (team, teamVocab, teamIssues) = try Team.fromRepoDefault(root: root)
        precondition(!teamIssues.contains { $0.severity == .error },
                     "default team paste has errors: \(teamIssues.map(\.message))")
        let mine = team.members.map(\.monSpec)

        // ---- parity vs the committed CLI sample (same inputs incl. taps) ----
        let theirs = ["Whimsicott", "Farigiraf", "Charizard", "Pelipper", "Archaludon", "Venusaur"]
        let report = try engine.report(mine: mine, theirs: theirs)

        let sample = try String(
            contentsOfFile: "\(scopeLensFixturesRoot)/preview/Team_Preview_Initial_scout.md", encoding: .utf8)
        func sampleLine(_ prefix: String) -> String? {
            sample.split(separator: "\n").first { $0.hasPrefix(prefix) }.map(String.init)
        }

        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String) {
            print("  \(ok ? "✅" : "❌") \(name): \(detail)")
            if !ok { failures += 1 }
        }

        // bring-4 + leads must match the CLI sample's suggestion line
        let suggestion = sampleLine("**") ?? ""
        check("safeFour", suggestion.contains(report.safeFour.joined(separator: ", ")),
              report.safeFour.joined(separator: ", "))
        check("leads", suggestion.contains(report.leads.joined(separator: " + ")),
              report.leads.joined(separator: " + "))

        // Farigiraf's meta set must match the sample's move percentages
        let fari = report.opponents.first { $0.species == "Farigiraf" }
        let trickRoomPct: Double = fari.flatMap { o in
            o.moves.first { $0.name == "Trick Room" }?.pct
        } ?? -1
        check("Farigiraf Trick Room pct",
              trickRoomPct == 95.7 && sample.contains("Trick Room (95.7%)"),
              String(trickRoomPct))

        // top threat must equal the sample's first threat line
        if let topThreat = report.threats.first,
           let sampleThreat = sampleLine("- \(topThreat.attacker)'s") {
            check("top threat",
                  sampleThreat.contains(topThreat.move)
                    && sampleThreat.contains("\(topThreat.minPct)–\(topThreat.maxPct)%"),
                  "\(topThreat.attacker) \(topThreat.move) \(topThreat.minPct)–\(topThreat.maxPct)%")
        } else {
            check("top threat", false, "missing")
        }

        // Dialga turned out to HAVE a meta entry (the phase-1 "absent from
        // ladder" note was stale) — Ho-Oh is a genuinely absent species.
        let hoOh = try engine.report(mine: mine, theirs: ["Ho-Oh"])
        check("no-meta flag (Ho-Oh)",
              hoOh.opponents.first?.hasMeta == false,
              "hasMeta=\(hoOh.opponents.first?.hasMeta.description ?? "nil")")

        // setMeta injection: a synthetic snapshot must override the baked one.
        let synthetic = """
        {"ho-oh": {"winrate": 50, "moves": {"Sacred Fire": 99.9}, "items": {"Life Orb": 90}, "abilities": {"Pressure": 100}}}
        """.data(using: .utf8)!
        let injected = try ScoutEngine(engineSource: engineSrc, metaJSON: synthetic)
        let sacred = try injected.report(mine: mine, theirs: ["Ho-Oh"])
        check("setMeta injection",
              sacred.opponents.first?.hasMeta == true
                && sacred.opponents.first?.moves.first?.name == "Sacred Fire",
              sacred.opponents.first?.moves.first?.name ?? "nil")

        // Expanded-snapshot coverage (full-ladder crawl, 2026-07-02).
        let mausholdReport = try engine.report(mine: mine, theirs: ["Maushold", "Annihilape"])
        check("expanded coverage (Maushold, Annihilape)",
              mausholdReport.opponents.allSatisfy(\.hasMeta),
              mausholdReport.opponents.map { "\($0.species):\($0.hasMeta)" }.joined(separator: " "))

        // ---- smoke: Example Battle 3 live consensus -------------------------
        let battle3 = ["Farfetch’d", "Typhlosion-Hisui", "Gholdengo",
                       "Zygarde", "Whimsicott", "Basculegion"]
        let smoke = try engine.report(mine: mine, theirs: battle3)
        print("\n  Example Battle 3 consensus → report:")
        print("    bring 4: \(smoke.safeFour.joined(separator: ", "))  · leads: \(smoke.leads.joined(separator: " + "))")
        for o in smoke.opponents {
            let mv = o.moves.prefix(2).map { $0.pct != nil ? "\($0.name) (\($0.pct!)%)" : $0.name }
            print("    \(o.species)\(o.hasMeta ? "" : " (no meta)"): \(mv.joined(separator: ", "))")
        }
        if let t = smoke.threats.first {
            print("    top threat: \(t.attacker)'s \(t.move) vs \(t.defender) \(t.minPct)–\(t.maxPct)%\(t.ko ? " KO" : "")")
        }
        check("smoke report shape",
              smoke.opponents.count == 6 && !smoke.safeFour.isEmpty && !smoke.assumptions.isEmpty,
              "\(smoke.opponents.count) opponents, \(smoke.threats.count) threats")

        // ---- liveMatchup bridge (Phase 3 m7) — battle-4's turn-6 board ----
        // Champions megas resolve to REAL stats (@smogon/calc carries them):
        // Scrafty-Mega must NOT be flagged approx. KO logic is deterministic:
        // a 1%-HP defender is always koNow for any landed hit.
        let matchup = try engine.liveMatchup(
            mine: [MonSpec(species: "Charizard", item: "Charizardite Y",
                           moves: ["Heat Wave", "Weather Ball"], curPct: 1),
                   MonSpec(species: "Incineroar", moves: ["Darkest Lariat"],
                           boosts: ["atk": -1], curPct: 60)],
            theirs: [MonSpec(species: "Scrafty-Mega", moves: ["Rock Slide", "Drain Punch"], curPct: 55),
                     MonSpec(species: "Armarouge", ability: "Flash Fire",
                             moves: ["Psychic"], curPct: 19)],
            field: LiveFieldSpec(weather: "sun", trickRoom: true, screensOpp: ["Aurora Veil"]))
        let vsChar = matchup.incoming.filter { $0.defender == "Charizard" }
        let scraftyReal = matchup.speeds.first { $0.species == "Scrafty-Mega" }.map { !$0.approx } ?? false
        print("\n  liveMatchup: \(matchup.incoming.count) incoming / \(matchup.outgoing.count) outgoing"
              + " · order: \(matchup.speeds.map { "\($0.species) \($0.spe)" }.joined(separator: " › "))")
        check("liveMatchup shape + TR order",
              !matchup.incoming.isEmpty && !matchup.outgoing.isEmpty && matchup.trickRoom
                && matchup.speeds.count == 4
                && matchup.speeds.first!.spe <= matchup.speeds.last!.spe,
              "\(matchup.speeds.map(\.spe))")
        check("liveMatchup KO-now on 1% defender",
              vsChar.allSatisfy(\.koNow) && !vsChar.isEmpty,
              vsChar.map { "\($0.attacker) \($0.move) \($0.maxPct)%" }.joined(separator: " | "))
        check("Champions mega = real stats (not approx)",
              scraftyReal, "Scrafty-Mega approx flag")

        // ---- m9: team paste + real-spread plumb through the bridge ----------
        check("team paste: 6 members named", team.members.count == 6
                && team.name == "Zheng's Sun",
              "\(team.members.count) · \(team.name ?? "unnamed")")
        check("team seeds: forme display names",
              team.teamSeeds(vocab: teamVocab).map(\.display)
                == ["Charizard", "Venusaur", "Garchomp", "Rotom", "Sneasler", "Incineroar"],
              team.teamSeeds(vocab: teamVocab).map(\.display).joined(separator: ","))

        // EVs/natures ride MonSpec.asDictionary into the calc: Mega Charizard Y
        // (base 100 Spe) at L50 is 167 Timid/252 configured — exact stat math,
        // so any dictionary-plumb regression trips this. The UNCONFIGURED
        // baseline is the MODAL ladder spread since m15-D (Modest 32-pt Spe →
        // 152), no longer the 0-EV floor (120) — the Solar Beam lesson.
        func chariSpeed(_ spec: MonSpec) throws -> Int? {
            try engine.liveMatchup(mine: [spec],
                                   theirs: [MonSpec(species: "Incineroar")],
                                   field: LiveFieldSpec())
                .speeds.first { $0.species == "Charizard" }?.spe
        }
        let base = MonSpec(species: "Charizard", item: "Charizardite Y", moves: ["Heat Wave"])
        var invested = base
        invested.evs = ["spe": 252]
        invested.nature = "Timid"
        let neutralSpe = try chariSpeed(base)
        let investedSpe = try chariSpeed(invested)
        check("EV/nature speed plumb (modal 152 → configured 167)",
              neutralSpe == 152 && investedSpe == 167,
              "\(neutralSpe ?? -1) → \(investedSpe ?? -1)")

        var bulky = MonSpec(species: "Incineroar")
        bulky.evs = ["hp": 252, "spd": 252]
        bulky.nature = "Calm"
        let vsNeutral = try engine.liveMatchup(mine: [base],
                                               theirs: [MonSpec(species: "Incineroar")],
                                               field: LiveFieldSpec()).outgoing.first
        let vsBulky = try engine.liveMatchup(mine: [base], theirs: [bulky],
                                             field: LiveFieldSpec()).outgoing.first
        check("real defensive spread reduces damage",
              (vsBulky?.maxPct ?? 999) < (vsNeutral?.maxPct ?? 0),
              "\(vsBulky?.maxPct ?? -1)% vs \(vsNeutral?.maxPct ?? -1)%")
        check("assumptions mention configured spreads",
              matchup.assumptions.contains("configured"),
              String(matchup.assumptions.prefix(60)))

        // ---- m12-B: reverse damage inference pins (battle-4 ground truth) ---
        // Armarouge Psychic → our Charizard-Mega-Y for 105 HP (battle 4,
        // 04:14): every no-item hypothesis tops out below the observation —
        // the engine must call the item boost.
        let psychic = try engine.inferAttack([
            "attacker": "Armarouge", "move": "Psychic",
            "defender": ["species": "Charizard-Mega-Y"],
            "observedDamage": 105,
        ]) ?? [:]
        let psychicSummary = psychic["summary"] as? String ?? "nil"
        check("inferAttack: Armarouge Psychic 105 ⇒ item boost implied",
              psychicSummary.hasPrefix("item boost implied")
                && psychicSummary.contains("Choice Specs")
                && psychic["conclusive"] as? Bool == true,
              psychicSummary)
        // A tainted observation (partial animation tail — battle 4's 4-HP
        // Drain Punch fragment) must come back INCONCLUSIVE so consumers
        // stay silent instead of surfacing noise.
        let fragment = try engine.inferAttack([
            "attacker": "Scrafty-Mega", "move": "Drain Punch",
            "defender": ["species": "Incineroar"], "observedDamage": 4,
        ]) ?? [:]
        check("inferAttack: partial-tail fragment ⇒ inconclusive",
              fragment["conclusive"] as? Bool == false,
              fragment["summary"] as? String ?? "nil")
        let psychicHyps = psychic["hypotheses"] as? [[String: Any]] ?? []
        check("inferAttack: no-item hypotheses all inconsistent",
              !psychicHyps.isEmpty && psychicHyps
                .filter { $0["item"] is NSNull }
                .allSatisfy { ($0["consistent"] as? Bool) == false },
              "\(psychicHyps.count) hypotheses")

        // Spread + status gates (the brief's v1 honesty rules).
        let spread = try engine.inferAttack([
            "attacker": "Farigiraf", "move": "Hyper Voice",
            "defender": ["species": "Incineroar"], "observedDamage": 46,
        ]) ?? [:]
        check("inferAttack: spread move skipped",
              (spread["skipped"] as? String)?.contains("spread") == true,
              "\(spread["skipped"] ?? "nil")")
        let status = try engine.inferAttack([
            "attacker": "Gengar", "move": "Protect",
            "defender": ["species": "Rotom-Wash"], "observedDamage": 10,
        ]) ?? [:]
        check("inferAttack: status move skipped",
              status["skipped"] as? String == "status move",
              "\(status["skipped"] ?? "nil")")

        // Mega attacker (Scrafty-Mega Fake Out at −1, battle 4, 02:29):
        // the item slot is the stone, so every hypothesis is item-free.
        let mega = try engine.inferAttack([
            "attacker": "Scrafty-Mega", "move": "Fake Out",
            "defender": ["species": "Incineroar"],
            "observedDamage": 20, "attackerBoosts": ["atk": -1],
        ]) ?? [:]
        let megaHyps = mega["hypotheses"] as? [[String: Any]] ?? []
        check("inferAttack: mega item slot collapses to none",
              !megaHyps.isEmpty && megaHyps.allSatisfy { $0["item"] is NSNull }
                && (mega["summary"] as? String)?.contains("at Atk-1") == true,
              mega["summary"] as? String ?? "nil")

        // ---- m12-C: dex effect info (the Opponent Dossier's data layer) -----
        // Baked from @pkmn/dex into dex-info.json; the bridge must surface
        // effect text + mechanical fields, degrade unknowns to known:false,
        // and translate never-miss accuracy (true in the dex) to nil.
        let dex = try engine.dexInfo(moves: ["Fake Out", "Aura Sphere", "Totally Made Up"],
                                     abilities: ["Armor Tail"],
                                     items: ["Life Orb"])
        let fakeOut = dex.moves.first
        check("dexInfo: Fake Out effect + mechanics",
              fakeOut?.known == true
                && fakeOut?.category == "Physical"
                && (fakeOut?.priority ?? 0) > 0
                && fakeOut?.shortDesc?.lowercased().contains("flinch") == true
                && fakeOut?.shortDesc?.lowercased().contains("first turn") == true,
              fakeOut?.shortDesc ?? "nil")
        check("dexInfo: never-miss accuracy is nil (Aura Sphere)",
              dex.moves.count == 3 && dex.moves[1].known && dex.moves[1].accuracy == nil
                && fakeOut?.accuracy == 100,
              "aura=\(dex.moves[1].accuracy.map(String.init) ?? "nil") fakeout=\(fakeOut?.accuracy.map(String.init) ?? "nil")")
        check("dexInfo: unknown name degrades to known:false",
              dex.moves[2].known == false && dex.moves[2].name == "Totally Made Up"
                && dex.moves[2].shortDesc == nil,
              dex.moves[2].name)
        check("dexInfo: Armor Tail explains the priority block",
              dex.abilities.first?.known == true
                && dex.abilities.first?.shortDesc?.lowercased().contains("priority") == true,
              dex.abilities.first?.shortDesc ?? "nil")
        check("dexInfo: item effect text (Life Orb)",
              dex.items.first?.known == true
                && dex.items.first?.shortDesc?.contains("1.3") == true,
              dex.items.first?.shortDesc ?? "nil")

        print(failures == 0 ? "\n✅ ENGINE BRIDGE FAITHFUL" : "\n❌ BRIDGE DIVERGES")
        exit(failures == 0 ? 0 : 1)
    }
}
