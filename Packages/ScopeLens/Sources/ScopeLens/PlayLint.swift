//
//  PlayLint.swift
//  Scope Lens
//
//  Phase 3, m15-B: the deterministic verifier over commit_play — the
//  session-10 answer to "heuristics all day isn't the way". Doctrine text
//  in the system prompt is prompted HOPE; this file is checked CONSTRAINT.
//  Every rule is an objective game-rule breach (never a meta opinion), so
//  a finding is unarguable evidence, cheap to compute, and usable three
//  ways: scoring replayed decisions in the eval harness, sweeping archived
//  plays offline, and (m15-C) bouncing a violating commit back to the
//  model for one repair round-trip.
//
//  Severity doctrine: `violation` = the committed action breaks a stated
//  game rule or contradicts a deterministic board fact (fails the eval);
//  `advisory` = strongly dominated but situationally defensible (reported,
//  never fails). When in doubt a rule ships as advisory — lint credibility
//  IS the product; one false violation teaches the pilot to ignore it.
//
//  Shared file: Foundation-only, everything nonisolated (app + harnesses).
//

import Foundation

// MARK: - The board facts the lint needs

/// A compact, Codable snapshot of the deterministic facts a play is
/// checked against. Built in ONE place (`LintContext.build`) from the same
/// inputs `AdvisorContext.buildTurn` renders, archived on each AdviceEntry
/// (m15-A companion) so any archived decision can be re-linted offline —
/// no engine, no video, no API.
nonisolated public struct LintContext: Codable, Sendable {

    nonisolated public struct Active: Codable, Sendable {
        public var species: String
        public var display: String
        public var fainted: Bool = false
        public var fakeOutLegal: Bool = false
        public var choiceLockedMove: String? = nil
        public var item: String? = nil
        /// Moves this mon can legally be told to use (configured ∪
        /// revealed for YOUR side). Empty = unknown → the rule skips.
        public var knownMoves: [String] = []
        /// Observed priority-blocking ability (Armor Tail, Dazzling,
        /// Queenly Majesty) — protects its whole side. Observation tier.
        public var observedBlocker: String? = nil
        /// Capsule-likely blocker — prior, not observation. Advisory tier.
        public var likelyBlocker: String? = nil

        public init(species: String, display: String? = nil,
                    fainted: Bool = false, fakeOutLegal: Bool = false,
                    choiceLockedMove: String? = nil, item: String? = nil,
                    knownMoves: [String] = [], observedBlocker: String? = nil,
                    likelyBlocker: String? = nil) {
            self.species = species
            self.display = display ?? species
            self.fainted = fainted
            self.fakeOutLegal = fakeOutLegal
            self.choiceLockedMove = choiceLockedMove
            self.item = item
            self.knownMoves = knownMoves
            self.observedBlocker = observedBlocker
            self.likelyBlocker = likelyBlocker
        }
    }

    nonisolated public struct BenchMon: Codable, Sendable {
        public var species: String
        public var display: String
        public var fainted: Bool
        public init(species: String, display: String? = nil, fainted: Bool = false) {
            self.species = species
            self.display = display ?? species
            self.fainted = fainted
        }
    }

    /// One of YOUR guaranteed-KO lines (redundant double-up advisory).
    nonisolated public struct KOLine: Codable, Sendable {
        public var attacker: String
        public var move: String
        public var defender: String
        public init(attacker: String, move: String, defender: String) {
            self.attacker = attacker
            self.move = move
            self.defender = defender
        }
    }

    public var turn: Int = 0
    public var weather: String? = nil
    public var yourActives: [Active] = []
    public var oppActives: [Active] = []
    public var yourBench: [BenchMon] = []
    public var doomed: [AdvisorContext.DoomedSlot] = []
    public var yourGuaranteedKOs: [KOLine] = []

    public init() {}
}

// MARK: - Findings

nonisolated public enum PlayLint {

    nonisolated public struct Finding: Codable, Sendable, Equatable {
        nonisolated public enum Severity: String, Codable, Sendable, Equatable {
            case violation, advisory
        }
        public let severity: Severity
        /// Stable kebab-case rule id — eval assertions and fixtures key on
        /// it, so renaming one is a breaking change.
        public let rule: String
        /// Human-readable, carries the evidence (the m13-E lesson: a bare
        /// verdict with no facts costs a live diagnosis).
        public let message: String
        public init(severity: Severity, rule: String, message: String) {
            self.severity = severity
            self.rule = rule
            self.message = message
        }
    }

    // MARK: Move classes (closed vocab keeps static sets viable)

    /// Actions that still do their job when the user is doomed to be KO'd
    /// before normal move order: priority attacks, the protect family,
    /// redirection, repositioning, and priority support.
    static let slotSavingMoves: Set<String> = AdvisorContext.priorityMoves.union([
        "Protect", "Detect", "Wide Guard", "Quick Guard", "Spiky Shield",
        "Baneful Bunker", "Burning Bulwark", "Silk Trap", "Obstruct", "Endure",
        "Helping Hand", "Ally Switch", "Follow Me", "Rage Powder", "Feint",
    ])

    /// Moves that beat a priority killer (the doomed .priorityKiller tier):
    /// blocking, not racing.
    static let protectFamily: Set<String> = [
        "Protect", "Detect", "Spiky Shield", "Baneful Bunker",
        "Burning Bulwark", "Silk Trap", "Obstruct", "Endure",
    ]

    /// Sun-charge moves: without sun the whole turn is spent charging.
    static let sunChargeMoves: Set<String> = ["Solar Beam", "Solar Blade"]

    /// Target strings that never name a Pokémon.
    static let specialTargets: Set<String> = ["both", "self", "field", "ally", "all", ""]

    // MARK: The check

    /// Pure function: committed play + board facts → findings, violations
    /// first. Never throws; an empty result is a clean play.
    public static func lint(play: AdvisorPlay, context: LintContext) -> [Finding] {
        var findings: [Finding] = []
        var resolvedActors: [String] = []   // species, for duplicate detection
        var attackTargets: [(actor: String, move: String, target: String)] = []

        let onField = context.yourActives.map(\.display).joined(separator: ", ")

        for action in play.actions {
            // ── the actor must be one of YOUR actives ──────────────────
            guard let actor = resolve(action.pokemon, in: context.yourActives) else {
                findings.append(Finding(
                    severity: .violation, rule: "actor-not-your-active",
                    message: "\"\(action.pokemon)\" is not one of your actives (on field: \(onField)) — commit_play takes one action per YOUR active."))
                continue
            }
            resolvedActors.append(actor.species)

            if action.verb == "switch" {
                lintSwitch(action, actor: actor, context: context, into: &findings)
                continue
            }

            // ── move actions ───────────────────────────────────────────
            guard let move = action.move, !move.isEmpty else {
                findings.append(Finding(
                    severity: .violation, rule: "move-missing",
                    message: "\(actor.display)'s action is \"move\" but names no move."))
                continue
            }

            // Your configured set is ground truth (m9): a move outside
            // configured ∪ revealed cannot be input into the game.
            if !actor.knownMoves.isEmpty,
               !actor.knownMoves.contains(where: { matchKey($0) == matchKey(move) }) {
                findings.append(Finding(
                    severity: .violation, rule: "unknown-move",
                    message: "\(actor.display) doesn't know \(move) — its moves: \(actor.knownMoves.joined(separator: ", "))."))
            }

            if ["Fake Out", "First Impression"].contains(where: { matchKey($0) == matchKey(move) }),
               !actor.fakeOutLegal {
                findings.append(Finding(
                    severity: .violation, rule: "illegal-fake-out",
                    message: "\(actor.display)'s \(move) only works on its first turn after entering — its window is closed (turn \(context.turn))."))
            }

            if let locked = actor.choiceLockedMove, matchKey(locked) != matchKey(move) {
                findings.append(Finding(
                    severity: .violation, rule: "choice-lock-contradiction",
                    message: "\(actor.display) is Choice-locked into \(locked) — it cannot use \(move) without switching out first."))
            }

            lintDoomed(move: move, actor: actor, context: context, into: &findings)
            lintBlocker(move: move, action: action, actor: actor, context: context, into: &findings)

            if sunChargeMoves.contains(where: { matchKey($0) == matchKey(move) }),
               context.weather != "Sun", !action.mega {
                findings.append(Finding(
                    severity: .advisory, rule: "sun-charge-risk",
                    message: "\(move) without active sun spends the whole turn charging (weather now: \(context.weather ?? "clear")) — only right if the sun arrives before it fires (e.g. a Drought mega this turn)."))
            }

            if action.mega, let item = actor.item,
               !(item.hasSuffix("ite") || item.hasSuffix("ite X") || item.hasSuffix("ite Y")) {
                findings.append(Finding(
                    severity: .violation, rule: "mega-without-stone",
                    message: "\(actor.display) holds \(item), not a Mega Stone — it cannot Mega Evolve."))
            }

            lintTarget(action, actor: actor, move: move, context: context,
                       into: &findings, attackTargets: &attackTargets)
        }

        // ── play-level checks ──────────────────────────────────────────
        let dupes = Dictionary(grouping: resolvedActors, by: { $0 }).filter { $1.count > 1 }
        for (species, _) in dupes.sorted(by: { $0.key < $1.key }) {
            findings.append(Finding(
                severity: .violation, rule: "duplicate-actor",
                message: "Two committed actions for \(species) — one action per active."))
        }

        if play.actions.filter(\.mega).count > 1 {
            findings.append(Finding(
                severity: .violation, rule: "double-mega",
                message: "Both actions Mega Evolve — only one Mega Evolution per turn."))
        }

        lintRedundantDoubleUp(attackTargets, context: context, into: &findings)

        return findings.sorted {
            ($0.severity == .violation ? 0 : 1, $0.rule) < ($1.severity == .violation ? 0 : 1, $1.rule)
        }
    }

    // MARK: Rule bodies

    private static func lintSwitch(_ action: AdvisorPlay.Action,
                                   actor: LintContext.Active,
                                   context: LintContext,
                                   into findings: inout [Finding]) {
        guard let rawTarget = action.switchTo, !rawTarget.isEmpty else {
            findings.append(Finding(
                severity: .violation, rule: "switch-target-missing",
                message: "\(actor.display)'s action is \"switch\" but names no bench Pokémon."))
            return
        }
        let benchNames = context.yourBench
            .map { $0.fainted ? "\($0.display) (fainted)" : $0.display }
            .joined(separator: ", ")
        if let benched = resolveBench(rawTarget, in: context.yourBench) {
            if benched.fainted {
                findings.append(Finding(
                    severity: .violation, rule: "switch-to-fainted",
                    message: "\(actor.display) cannot switch to \(benched.display) — it has fainted (bench: \(benchNames))."))
            }
        } else if resolve(rawTarget, in: context.yourActives) != nil {
            findings.append(Finding(
                severity: .violation, rule: "switch-to-active",
                message: "\(rawTarget) is already on the field — a switch must name a bench Pokémon (bench: \(benchNames))."))
        } else {
            findings.append(Finding(
                severity: .violation, rule: "switch-target-unknown",
                message: "\"\(rawTarget)\" is not on your bench (bench: \(benchNames))."))
        }
    }

    private static func lintDoomed(move: String, actor: LintContext.Active,
                                   context: LintContext,
                                   into findings: inout [Finding]) {
        guard let slot = context.doomed.first(where: { $0.species == actor.species }) else { return }
        let saves = slotSavingMoves.contains { matchKey($0) == matchKey(move) }
        switch slot.tier {
        case .guaranteed where !saves:
            findings.append(Finding(
                severity: .violation, rule: "doomed-slot-attack",
                message: "\(actor.display) acts AFTER \(slot.killer), whose \(slot.killerMove) is a guaranteed KO — \(move) has no priority and NEVER executes. Switch, Protect, use priority, or play the partner instead."))
        case .range where !saves:
            findings.append(Finding(
                severity: .advisory, rule: "doomed-slot-risk",
                message: "\(actor.display) acts after \(slot.killer), whose \(slot.killerMove) is in KO range — \(move) likely never executes unless the roll misses."))
        case .priorityKiller where !protectFamily.contains(where: { matchKey($0) == matchKey(move) }):
            findings.append(Finding(
                severity: .advisory, rule: "priority-threat",
                message: "\(slot.killer)'s \(slot.killerMove) (priority) guaranteed-KOs \(actor.display) before any non-priority action — only Protect-family reliably beats it."))
        case .speedRisk where !saves:
            let evidence = slot.killerCeiling.flatMap { ceiling in
                slot.yourSpeed.map { "ceiling ~\(ceiling) vs \($0)" }
            } ?? "bracket ceiling beats its speed"
            findings.append(Finding(
                severity: .advisory, rule: "speed-risk-attack",
                message: "\(actor.display)'s order vs \(slot.killer) rests on a 0-EV estimate (\(evidence)) — an invested/Scarfed \(slot.killer) KOs first and \(move) never fires. Deliberate gamble at best."))
        default:
            break
        }
    }

    private static func lintBlocker(move: String, action: AdvisorPlay.Action,
                                    actor: LintContext.Active,
                                    context: LintContext,
                                    into findings: inout [Finding]) {
        guard AdvisorContext.priorityMoves.contains(where: { matchKey($0) == matchKey(move) }) else { return }
        // A blocker protects its whole side; the check applies when the
        // priority move is aimed at ANY opposing slot (spread priority
        // doesn't exist in this vocab, so a named target or "both" is
        // always into their side unless it names your own partner).
        let target = (action.target ?? "").trimmingCharacters(in: .whitespaces)
        if !specialTargets.contains(target.lowercased()),
           resolve(target, in: context.yourActives) != nil { return }   // ally-aimed
        if let blocker = context.oppActives.compactMap(\.observedBlocker).first {
            findings.append(Finding(
                severity: .violation, rule: "priority-into-blocker",
                message: "\(move) is a priority move and the opponent's \(blocker) is OBSERVED — priority into that side fails outright."))
        } else if let likely = context.oppActives.compactMap(\.likelyBlocker).first {
            findings.append(Finding(
                severity: .advisory, rule: "priority-into-likely-blocker",
                message: "\(move) is priority and the opponent's likely ability is \(likely) (usage prior) — if it's real, this fails."))
        }
    }

    private static func lintTarget(_ action: AdvisorPlay.Action,
                                   actor: LintContext.Active, move: String,
                                   context: LintContext,
                                   into findings: inout [Finding],
                                   attackTargets: inout [(actor: String, move: String, target: String)]) {
        let raw = (action.target ?? "").trimmingCharacters(in: .whitespaces)
        guard !specialTargets.contains(raw.lowercased()) else { return }
        let everyone = context.yourActives + context.oppActives
        guard let target = resolve(raw, in: everyone) else {
            findings.append(Finding(
                severity: .advisory, rule: "target-unresolved",
                message: "\"\(raw)\" doesn't match anyone on the field (\(everyone.map(\.display).joined(separator: ", "))) — the pilot can't input this target."))
            return
        }
        if target.fainted {
            findings.append(Finding(
                severity: .violation, rule: "target-fainted",
                message: "\(move) targets \(target.display), which has already fainted."))
        }
        if resolve(raw, in: context.oppActives) != nil {
            attackTargets.append((actor: actor.species, move: move, target: target.species))
        }
    }

    private static func lintRedundantDoubleUp(
        _ attackTargets: [(actor: String, move: String, target: String)],
        context: LintContext,
        into findings: inout [Finding]) {
        guard attackTargets.count == 2,
              attackTargets[0].target == attackTargets[1].target,
              attackTargets[0].actor != attackTargets[1].actor else { return }
        let target = attackTargets[0].target
        let guaranteed = attackTargets.first { entry in
            context.yourGuaranteedKOs.contains {
                $0.attacker == entry.actor && $0.defender == target
                    && matchKey($0.move) == matchKey(entry.move)
            }
        }
        if let sure = guaranteed {
            findings.append(Finding(
                severity: .advisory, rule: "redundant-double-up",
                message: "\(sure.actor)'s \(sure.move) alone guaranteed-KOs \(target) — doubling both attacks into it is only right against a Protect/Sash risk; consider spreading the second attack."))
        }
    }

    // MARK: Name resolution (the m13-F unique-prefix convention)

    /// Case/punctuation-insensitive key — the same convention as
    /// AdvisorToolExecutor.matchKey (kept local so the lint stays
    /// dependency-free for offline re-linting).
    static func matchKey(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) && $0.isASCII
        })
    }

    /// Exact key match on species or display first; then a UNIQUE prefix
    /// ("Rotom" → Rotom-Wash when it's the only Rotom on the board —
    /// commit_play text follows the model's shorthand, not the calc name).
    static func resolve(_ raw: String, in actives: [LintContext.Active]) -> LintContext.Active? {
        let k = matchKey(raw)
        guard !k.isEmpty else { return nil }
        if let exact = actives.first(where: { matchKey($0.species) == k || matchKey($0.display) == k }) {
            return exact
        }
        let prefixed = actives.filter {
            matchKey($0.species).hasPrefix(k) || matchKey($0.display).hasPrefix(k)
        }
        return prefixed.count == 1 ? prefixed.first : nil
    }

    static func resolveBench(_ raw: String, in bench: [LintContext.BenchMon]) -> LintContext.BenchMon? {
        let k = matchKey(raw)
        guard !k.isEmpty else { return nil }
        if let exact = bench.first(where: { matchKey($0.species) == k || matchKey($0.display) == k }) {
            return exact
        }
        let prefixed = bench.filter {
            matchKey($0.species).hasPrefix(k) || matchKey($0.display).hasPrefix(k)
        }
        return prefixed.count == 1 ? prefixed.first : nil
    }
}

// MARK: - Building the context (the ONE assembly point)

nonisolated extension LintContext {

    /// One configured team slot's lint-relevant ground truth (m9: your
    /// side's sets are known, not inferred).
    nonisolated public struct ConfiguredMon: Sendable {
        public let moves: [String]
        public let item: String?
        public init(moves: [String], item: String?) {
            self.moves = moves
            self.item = item
        }
    }

    /// Assemble the lint's facts from the same inputs buildTurn renders.
    /// `configured` maps lowercased identity (species AND display) → the
    /// configured slot (m9 ground truth); `capsules` supply the
    /// likely-blocker priors for opponent actives.
    public static func build(snapshots: [BattleReconciler.ActiveSnapshot],
                             field: LiveFieldSpec,
                             matchup: LiveMatchupData?,
                             state: BattleState,
                             yourBench: [PokemonState],
                             configured: [String: ConfiguredMon],
                             capsules: [OpponentCapsule]) -> LintContext {
        var context = LintContext()
        context.turn = state.turn
        context.weather = field.weather

        for snapshot in snapshots where snapshot.species != "unknown" {
            var active = Active(species: snapshot.species, display: snapshot.displayName)
            active.fainted = (snapshot.curPct ?? 100) <= 0
            active.fakeOutLegal = state.turn <= snapshot.onFieldSinceTurn + 1
            active.choiceLockedMove = snapshot.choiceLockedMove
            active.item = snapshot.item

            if snapshot.side == "you" {
                let slot = configured[snapshot.species.lowercased()]
                    ?? configured[snapshot.displayName.lowercased()]
                let configuredMoves = slot?.moves ?? []
                active.knownMoves = configuredMoves
                    + snapshot.revealedMoves.filter { !configuredMoves.contains($0) }
                if active.item == nil {
                    // The configured slot's item is ground truth when
                    // observation hasn't revealed one (mega-stone check).
                    active.item = slot?.item
                }
                context.yourActives.append(active)
            } else {
                if let ability = snapshot.ability,
                   AdvisorContext.priorityBlockingAbilities.contains(ability) {
                    active.observedBlocker = ability
                } else if snapshot.ability == nil,
                          let capsule = capsules.first(where: { $0.species == snapshot.species }),
                          let likely = capsule.priorityBlockerLikely {
                    active.likelyBlocker = likely
                }
                context.oppActives.append(active)
            }
        }

        context.yourBench = yourBench.map {
            BenchMon(species: $0.speciesId, display: $0.describeName,
                     fainted: $0.hp?.isFainted == true)
        }

        if let matchup {
            context.doomed = AdvisorContext.doomedSlots(
                matchup: matchup,
                opponentCeilings: AdvisorContext.speedCeilings(capsules: capsules))
            context.yourGuaranteedKOs = matchup.outgoing
                .filter(\.guaranteedKo)
                .map { KOLine(attacker: $0.attacker, move: $0.move, defender: $0.defender) }
        }
        return context
    }
}
