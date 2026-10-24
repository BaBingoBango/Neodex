//
//  PlayLintHarness.swift
//  ScopeLens Diagnostics — m15-B: PlayLint unit cases.
//
//  Deterministic, offline, fast: synthetic boards + committed plays →
//  expected findings, one line per case. The lint is the eval set's
//  objective scoring tier AND (m15-C) the live repair trigger, so its
//  rules get the same pinning discipline as the parser fixtures.
//
//  Build & run (from repo root — verify-all stage 7):
//    swiftc -O Tools/ScopeLensDiagnostics/PlayLintHarness.swift \
//      "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleVocabulary.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleEventParser.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleReconciler.swift" "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/ScoutEngine.swift" "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/AdvisorContext.swift" "Packages/ScopeLens/Sources/ScopeLens/AdvisorClient.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/AdvisorTools.swift" "Packages/ScopeLens/Sources/ScopeLens/PlayLint.swift" \
//      -o /tmp/sl-verify-playlint && /tmp/sl-verify-playlint
//

import Foundation

@main
struct PlayLintHarness {

    struct Case {
        let name: String
        let context: LintContext
        let play: AdvisorPlay
        let expectViolations: [String]
        let expectAdvisories: [String]

        init(_ name: String, context: LintContext, play: AdvisorPlay,
             violations: [String] = [], advisories: [String] = []) {
            self.name = name
            self.context = context
            self.play = play
            self.expectViolations = violations
            self.expectAdvisories = advisories
        }
    }

    // MARK: Board builders (the pilot's real teams keep cases legible)

    /// Charizard + Incineroar vs opposing Garchomp + Rotom-Wash, benches
    /// stocked — the Solar Beam battle's shape.
    static func board(weather: String? = nil,
                      doomed: [AdvisorContext.DoomedSlot] = [],
                      fakeOutLegal: Bool = true,
                      charizardItem: String? = "Charizardite Y",
                      choiceLock: String? = nil,
                      oppObservedBlocker: String? = nil,
                      oppLikelyBlocker: String? = nil,
                      guaranteedKOs: [LintContext.KOLine] = []) -> LintContext {
        var context = LintContext()
        context.turn = 3
        context.weather = weather
        context.yourActives = [
            LintContext.Active(species: "Charizard", fakeOutLegal: false,
                               item: charizardItem,
                               knownMoves: ["Solar Beam", "Heat Wave", "Air Slash", "Protect"]),
            LintContext.Active(species: "Incineroar", fakeOutLegal: fakeOutLegal,
                               choiceLockedMove: choiceLock, item: "Sitrus Berry",
                               knownMoves: ["Fake Out", "Flare Blitz", "Knock Off", "Parting Shot"]),
        ]
        context.oppActives = [
            LintContext.Active(species: "Garchomp",
                               observedBlocker: nil, likelyBlocker: nil),
            LintContext.Active(species: "Rotom-Wash",
                               observedBlocker: oppObservedBlocker,
                               likelyBlocker: oppLikelyBlocker),
        ]
        context.yourBench = [
            LintContext.BenchMon(species: "Garchomp"),
            LintContext.BenchMon(species: "Venusaur", fainted: true),
        ]
        context.doomed = doomed
        context.yourGuaranteedKOs = guaranteedKOs
        return context
    }

    static func move(_ pokemon: String, _ move: String, target: String? = nil,
                     mega: Bool = false) -> AdvisorPlay.Action {
        AdvisorPlay.Action(pokemon: pokemon, verb: "move", move: move,
                           target: target, mega: mega)
    }

    static func switchOut(_ pokemon: String, to bench: String) -> AdvisorPlay.Action {
        AdvisorPlay.Action(pokemon: pokemon, verb: "switch", switchTo: bench)
    }

    static let charizardDoomedGuaranteed = AdvisorContext.DoomedSlot(
        species: "Charizard", killer: "Garchomp", killerMove: "Rock Slide",
        tier: .guaranteed)
    static let charizardDoomedRange = AdvisorContext.DoomedSlot(
        species: "Charizard", killer: "Garchomp", killerMove: "Rock Slide",
        tier: .range)
    static let charizardDoomedPriority = AdvisorContext.DoomedSlot(
        species: "Charizard", killer: "Metagross", killerMove: "Bullet Punch",
        tier: .priorityKiller)
    static let charizardSpeedRisk = AdvisorContext.DoomedSlot(
        species: "Charizard", killer: "Excadrill", killerMove: "Rock Slide",
        tier: .speedRisk, killerCeiling: 154, yourSpeed: 136)

    // MARK: The table

    static let cases: [Case] = [
        // The Solar Beam forfeit, distilled: guaranteed-doomed slot spends
        // its action on a non-priority attack → the flag's exact violation.
        Case("doomed-guaranteed attack flags",
             context: board(weather: "Sun", doomed: [charizardDoomedGuaranteed]),
             play: AdvisorPlay(actions: [move("Charizard", "Solar Beam", target: "Rotom-Wash"),
                                         move("Incineroar", "Fake Out", target: "Garchomp")]),
             violations: ["doomed-slot-attack"]),

        Case("doomed slot saved by Protect stays clean",
             context: board(doomed: [charizardDoomedGuaranteed]),
             play: AdvisorPlay(actions: [move("Charizard", "Protect"),
                                         move("Incineroar", "Knock Off", target: "Garchomp")])),

        Case("doomed-range attack is advisory only",
             context: board(weather: "Sun", doomed: [charizardDoomedRange]),
             play: AdvisorPlay(actions: [move("Charizard", "Solar Beam", target: "Rotom-Wash")]),
             advisories: ["doomed-slot-risk"]),

        Case("priority-killer tier warns unless protected",
             context: board(weather: "Sun", doomed: [charizardDoomedPriority]),
             play: AdvisorPlay(actions: [move("Charizard", "Solar Beam", target: "Rotom-Wash")]),
             advisories: ["priority-threat"]),

        Case("priority-killer tier satisfied by Protect",
             context: board(doomed: [charizardDoomedPriority]),
             play: AdvisorPlay(actions: [move("Charizard", "Protect")])),

        Case("doomed slot escaped by switching stays clean",
             context: board(doomed: [charizardDoomedGuaranteed]),
             play: AdvisorPlay(actions: [switchOut("Charizard", to: "Garchomp")])),

        // The Solar Beam LOSS, distilled (m15-B speedRisk tier): the
        // estimated order says you act first, but the killer's bracket
        // ceiling says maybe not — attacking is a flagged gamble.
        Case("speed-risk cash-in is advisory",
             context: board(weather: "Sun", doomed: [charizardSpeedRisk]),
             play: AdvisorPlay(actions: [move("Charizard", "Solar Beam", target: "Garchomp")]),
             advisories: ["speed-risk-attack"]),

        Case("speed-risk slot saved by priority or Protect",
             context: board(doomed: [charizardSpeedRisk]),
             play: AdvisorPlay(actions: [move("Charizard", "Protect")])),

        Case("Fake Out outside its window",
             context: board(fakeOutLegal: false),
             play: AdvisorPlay(actions: [move("Incineroar", "Fake Out", target: "Garchomp")]),
             violations: ["illegal-fake-out"]),

        Case("Choice lock contradiction",
             context: board(choiceLock: "Flare Blitz"),
             play: AdvisorPlay(actions: [move("Incineroar", "Knock Off", target: "Garchomp")]),
             violations: ["choice-lock-contradiction"]),

        Case("Choice-locked mon may switch out",
             context: board(choiceLock: "Flare Blitz"),
             play: AdvisorPlay(actions: [switchOut("Incineroar", to: "Garchomp")])),

        Case("move outside the configured set",
             context: board(),
             play: AdvisorPlay(actions: [move("Charizard", "Overheat", target: "Garchomp")]),
             violations: ["unknown-move"]),

        Case("priority into an OBSERVED blocker",
             context: board(oppObservedBlocker: "Armor Tail"),
             play: AdvisorPlay(actions: [move("Incineroar", "Fake Out", target: "Garchomp")]),
             violations: ["priority-into-blocker"]),

        Case("priority into a LIKELY blocker is advisory",
             context: board(oppLikelyBlocker: "Armor Tail"),
             play: AdvisorPlay(actions: [move("Incineroar", "Fake Out", target: "Garchomp")]),
             advisories: ["priority-into-likely-blocker"]),

        Case("switch to a fainted bench mon",
             context: board(),
             play: AdvisorPlay(actions: [switchOut("Charizard", to: "Venusaur")]),
             violations: ["switch-to-fainted"]),

        Case("switch to a mon not on the bench",
             context: board(),
             play: AdvisorPlay(actions: [switchOut("Charizard", to: "Dondozo")]),
             violations: ["switch-target-unknown"]),

        Case("switch to an already-active mon",
             context: board(),
             play: AdvisorPlay(actions: [switchOut("Charizard", to: "Incineroar")]),
             violations: ["switch-to-active"]),

        Case("actor is not one of your actives",
             context: board(),
             play: AdvisorPlay(actions: [move("Rotom-Wash", "Hydro Pump", target: "Charizard")]),
             violations: ["actor-not-your-active"]),

        Case("mega without a stone",
             context: board(charizardItem: "Life Orb"),
             play: AdvisorPlay(actions: [move("Charizard", "Heat Wave", target: "both", mega: true)]),
             violations: ["mega-without-stone"]),

        Case("mega with its stone stays clean",
             context: board(weather: "Sun"),
             play: AdvisorPlay(actions: [move("Charizard", "Solar Beam", target: "Rotom-Wash", mega: true)])),

        Case("Solar Beam without sun is advisory unless mega",
             context: board(),
             play: AdvisorPlay(actions: [move("Charizard", "Solar Beam", target: "Rotom-Wash")]),
             advisories: ["sun-charge-risk"]),

        Case("Solar Beam with a Drought mega this turn stays quiet",
             context: board(),
             play: AdvisorPlay(actions: [move("Charizard", "Solar Beam", target: "Rotom-Wash", mega: true)])),

        Case("target already fainted",
             context: board().withOppFainted("Rotom-Wash"),
             play: AdvisorPlay(actions: [move("Charizard", "Heat Wave", target: "Rotom-Wash")]),
             violations: ["target-fainted"]),

        Case("unresolvable target is advisory",
             context: board(),
             play: AdvisorPlay(actions: [move("Charizard", "Heat Wave", target: "Gholdengo")]),
             advisories: ["target-unresolved"]),

        Case("duplicate actor",
             context: board(weather: "Sun"),
             play: AdvisorPlay(actions: [move("Charizard", "Heat Wave", target: "both"),
                                         move("Charizard", "Protect")]),
             violations: ["duplicate-actor"]),

        Case("double mega",
             context: board(weather: "Sun").withIncineroarStone(),
             play: AdvisorPlay(actions: [move("Charizard", "Heat Wave", target: "both", mega: true),
                                         move("Incineroar", "Knock Off", target: "Garchomp", mega: true)]),
             violations: ["double-mega"]),

        Case("redundant double-up onto a guaranteed KO",
             context: board(guaranteedKOs: [.init(attacker: "Charizard",
                                                  move: "Heat Wave",
                                                  defender: "Rotom-Wash")]),
             play: AdvisorPlay(actions: [move("Charizard", "Heat Wave", target: "Rotom-Wash"),
                                         move("Incineroar", "Knock Off", target: "Rotom-Wash")]),
             advisories: ["redundant-double-up"]),

        // Name resolution: shorthand and unique prefixes must land.
        Case("prefix shorthand resolves (Rotom → Rotom-Wash)",
             context: board(guaranteedKOs: []),
             play: AdvisorPlay(actions: [move("Charizard", "Heat Wave", target: "Rotom"),
                                         move("Incineroar", "Knock Off", target: "Garchomp")])),

        Case("clean realistic turn produces no findings",
             context: board(weather: "Sun"),
             play: AdvisorPlay(actions: [move("Charizard", "Heat Wave", target: "both"),
                                         move("Incineroar", "Fake Out", target: "Rotom-Wash")])),
    ]

    static func main() {
        var passed = 0
        for testCase in cases {
            let findings = PlayLint.lint(play: testCase.play, context: testCase.context)
            let violations = Set(findings.filter { $0.severity == .violation }.map(\.rule))
            let advisories = Set(findings.filter { $0.severity == .advisory }.map(\.rule))
            let ok = violations == Set(testCase.expectViolations)
                && advisories == Set(testCase.expectAdvisories)
            if ok {
                passed += 1
            } else {
                print("❌ \(testCase.name)")
                print("   expected violations \(testCase.expectViolations.sorted()), advisories \(testCase.expectAdvisories.sorted())")
                print("   got:")
                for finding in findings {
                    print("     [\(finding.severity.rawValue)] \(finding.rule): \(finding.message)")
                }
                if findings.isEmpty { print("     (no findings)") }
            }
        }
        print("\nplaylint cases: \(passed)/\(cases.count) passed")
        exit(passed == cases.count ? 0 : 1)
    }
}

// Small context mutators keep the table declarative.
extension LintContext {
    func withOppFainted(_ species: String) -> LintContext {
        var copy = self
        copy.oppActives = copy.oppActives.map {
            var mon = $0
            if mon.species == species { mon.fainted = true }
            return mon
        }
        return copy
    }

    func withIncineroarStone() -> LintContext {
        var copy = self
        copy.yourActives = copy.yourActives.map {
            var mon = $0
            if mon.species == "Incineroar" { mon.item = "Incineroarite" }
            return mon
        }
        return copy
    }
}
