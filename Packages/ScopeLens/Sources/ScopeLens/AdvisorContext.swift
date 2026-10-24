//
//  AdvisorContext.swift
//  Scope Lens
//
//  Phase 3, m8→m11: the advisor's INPUT, split in two for prompt caching:
//
//  • buildStatic — the battle-static prefix: your configured team + OPPONENT
//    META CAPSULES for all six preview mons (usage priors, speed brackets,
//    defensive typing, priority-blocker flags). Byte-identical across turns
//    of one battle → cache_control makes every call after the first cheap.
//
//  • buildTurn — the volatile tail: actives with observed reveals, field,
//    deterministic matchup numbers, benches, recent events.
//
//  Deliberately text, not JSON: the model reads it like a coach's notepad,
//  and every line is labeled observed vs priors so the advice can't
//  overclaim. Built identically by the app and the offline AdvisorHarness.
//

import Foundation

nonisolated public enum AdvisorContext {

    // MARK: Battle-static prefix (m11 — cacheable)

    /// The battle-static context block. Everything here is decided the
    /// moment the preview seeds: the configured team and the meta capsules.
    /// MUST stay deterministic — same inputs, same bytes.
    public static func buildStatic(yourTeam: [TeamMember],
                                   teamVocab: TeamVocab?,
                                   capsules: [OpponentCapsule]) -> String {
        var L: [String] = []
        L.append("REGULATION: Pokémon Champions ranked doubles (VGC-style), level 50.")

        // The configured team (m9) — ground truth the model can rely on for
        // switch-in reasoning, not just what battle observation revealed.
        if !yourTeam.isEmpty {
            L.append("\nYOUR TEAM (configured — full sets, ground truth):")
            for m in yourTeam {
                var bits: [String] = []
                if let item = m.item { bits.append("@ \(item)") }
                if let ability = m.ability { bits.append(ability) }
                if let nature = m.nature { bits.append("\(nature) nature") }
                // teraType deliberately NOT rendered: Champions has no
                // Terastallization (pilot-confirmed 2026-07-09) — telling
                // the model would invite recommending an impossible action.
                if !m.moves.isEmpty { bits.append(m.moves.joined(separator: " / ")) }
                let display = m.displayName(vocab: teamVocab)
                let name = display == m.species ? m.species : "\(m.species) “\(display)”"
                L.append("- \(name)\(bits.isEmpty ? "" : ": " + bits.joined(separator: " · "))")
            }
        }

        if !capsules.isEmpty {
            L.append("\nOPPONENT META CAPSULES (all six preview mons, bench included — Reg M-B ranked usage priors, NOT observations):")
            for c in capsules { L.append(contentsOf: renderCapsule(c)) }
            L.append("Speed brackets are L50 ranges: 0-EV neutral floor → 252-EV +nature ceiling; \"ladder-modal\" is the top usage spread × nature — the single best speed estimate, and what the damage math assumes for unobserved sets. \"Outspeeds\" claims must respect the whole bracket (and Scarf where flagged).")
        }
        return L.joined(separator: "\n")
    }

    private static func renderCapsule(_ c: OpponentCapsule) -> [String] {
        var head = "- \(c.species)"
        if !c.types.isEmpty { head += " (\(c.types.joined(separator: "/")))" }
        if let w = c.winrate { head += " · winrate \(fmt(w))%" }
        if !c.hasMeta { head += " · NO usage data (off-ladder)" }
        var lines = [head]
        if !c.topMoves.isEmpty {
            lines.append("  moves: " + c.topMoves.map { "\($0.name) \(fmt($0.pct))%" }
                .joined(separator: ", "))
        }
        var kit: [String] = []
        if !c.topItems.isEmpty {
            kit.append("items: " + c.topItems.map { "\($0.name) \(fmt($0.pct))%" }
                .joined(separator: ", "))
        }
        if let a = c.topAbility { kit.append("ability: \(a.name) \(fmt(a.pct))%") }
        if !kit.isEmpty { lines.append("  " + kit.joined(separator: " · ")) }
        var facts: [String] = []
        if let bias = c.offenseBias { facts.append("\(bias) attacker") }
        if let mn = c.speedMin, let mx = c.speedMax {
            var speed = "speed \(mn)–\(mx)"
            // m15-D: the ladder-modal point — what it ACTUALLY runs.
            if let modal = c.speedModal, let pct = c.speedModalPct {
                speed += " · ladder-modal ~\(modal) (\(fmt(pct))% spread)"
            }
            if c.scarfPossible { speed += " (Scarf → \(Int(Double(mx) * 1.5)))" }
            facts.append(speed)
        }
        facts.append(contentsOf: defensiveBits(c.defensive))
        if !facts.isEmpty { lines.append("  " + facts.joined(separator: " · ")) }
        if !c.teammates.isEmpty {
            // m15-D: archetype signal — who it actually teams with.
            lines.append("  usual partners: \(c.teammates.joined(separator: ", "))")
        }
        if let blocker = c.priorityBlockerLikely {
            lines.append("  ⚠️ likely \(blocker): PRIORITY MOVES INTO ITS SIDE FAIL while it is active (Fake Out, Sucker Punch, Extreme Speed…)")
        }
        return lines
    }

    private static func defensiveBits(_ d: [String: [String]]) -> [String] {
        var bits: [String] = []
        let x4 = d["x4"] ?? [], x2 = d["x2"] ?? []
        let resist = (d["x05"] ?? []) + (d["x025"] ?? [])
        let immune = d["x0"] ?? []
        if !x4.isEmpty { bits.append("4× weak: \(x4.joined(separator: ", "))") }
        if !x2.isEmpty { bits.append("weak: \(x2.joined(separator: ", "))") }
        if !resist.isEmpty { bits.append("resists: \(resist.joined(separator: ", "))") }
        if !immune.isEmpty { bits.append("immune: \(immune.joined(separator: ", "))") }
        return bits
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    // MARK: Team-preview question (m12-A — the agentic preview scout)

    /// The volatile block for a TEAM PREVIEW ask: the deterministic
    /// heuristic's pick (the always-on baseline, spec §4.1 two-speed
    /// doctrine) plus the threat-matrix highlights the engine already
    /// computed. Rides AFTER the cached battle-static prefix, so a preview
    /// ask warms the same cache the turn asks read.
    public static func buildPreview(scout: ScoutReportData?) -> String {
        var L: [String] = []
        L.append("Team preview — pick 4 of your 6 and choose your leads. "
                 + "Nothing is observed yet; the opponent's six (capsules above) are all you know.")
        guard let scout else {
            L.append("(No deterministic baseline available — reason from the capsules and tools.)")
            return L.joined(separator: "\n")
        }
        L.append("\nDETERMINISTIC BASELINE (damage-trade heuristic — the instant answer to beat):")
        L.append("bring: \(scout.safeFour.joined(separator: ", ")) — leads: \(scout.leads.joined(separator: " + "))")
        if !scout.threats.isEmpty {
            L.append("\nTOP THREAT LINES INTO YOU (full HP, assumed sets):")
            for t in scout.threats.prefix(6) {
                L.append("- \(t.attacker)'s \(t.move) → \(t.defender): \(fmt(t.minPct))–\(fmt(t.maxPct))%"
                         + (t.ko ? " [KO range]" : ""))
            }
        }
        if !scout.answers.isEmpty {
            L.append("\nYOUR BEST ANSWERS:")
            for a in scout.answers {
                L.append("- \(a.mine): \(a.move) vs \(a.target) for \(fmt(a.minPct))–\(fmt(a.maxPct))%")
            }
        }
        L.append("\n(\(scout.assumptions))")
        return L.joined(separator: "\n")
    }

    /// The preview ask's question line (the client's turn-mode default asks
    /// "What's the play?").
    public static let previewQuestion =
        "Which four do I bring, who leads, and what's the turn-1 plan?"

    // MARK: Volatile turn state

    public static func buildTurn(snapshots: [BattleReconciler.ActiveSnapshot],
                                 field: LiveFieldSpec,
                                 matchup: LiveMatchupData?,
                                 state: BattleState,
                                 recentEvents: [BattleEvent],
                                 yourBench: [PokemonState],
                                 oppBench: [PokemonState],
                                 capsules: [OpponentCapsule] = []) -> String {
        var L: [String] = []
        L.append("TURN \(state.turn).")

        // Field
        var fieldBits: [String] = []
        if let w = field.weather { fieldBits.append("weather: \(w)\(state.weather.turnsLeft.map { " (\($0) turns left)" } ?? "")") }
        if field.trickRoom { fieldBits.append("Trick Room ACTIVE (slower moves first)") }
        if field.tailwindYou { fieldBits.append("your Tailwind up") }
        if field.tailwindOpp { fieldBits.append("opponent Tailwind up") }
        if !field.screensYou.isEmpty { fieldBits.append("your screens: \(field.screensYou.joined(separator: ", "))") }
        if !field.screensOpp.isEmpty { fieldBits.append("opponent screens: \(field.screensOpp.joined(separator: ", "))") }
        L.append("FIELD: " + (fieldBits.isEmpty ? "clear" : fieldBits.joined(separator: "; ")))

        // Actives
        func describe(_ s: BattleReconciler.ActiveSnapshot) -> String {
            var bits: [String] = []
            if let hp = s.curPct { bits.append("HP \(Int(hp))%") }
            if let status = s.status { bits.append(status) }
            if !s.boosts.isEmpty {
                bits.append(s.boosts.sorted { $0.key < $1.key }
                    .map { "\($0.key)\($0.value > 0 ? "+" : "")\($0.value)" }.joined(separator: " "))
            }
            if let p = s.perishCount { bits.append("PERISH \(p) — faints in \(p) turn\(p == 1 ? "" : "s")!") }
            let fakeOutLegal = state.turn <= s.onFieldSinceTurn + 1
            bits.append("entered turn \(s.onFieldSinceTurn)"
                + (fakeOutLegal ? " (Fake Out window OPEN)" : " (Fake Out ILLEGAL — not its first turn)"))
            if s.protectedLastTurn {
                // m12-D: consecutive-Protect odds, stated deterministically
                // (success ≈ (1/3)^streak — 33%, then 11%, …).
                let odds = max(1, Int(100.0 / pow(3.0, Double(max(1, s.protectStreak)))))
                bits.append(s.protectStreak > 1
                    ? "🛡 Protected \(s.protectStreak) turns running — another succeeds only ~\(odds)%"
                    : "🛡 Protected last turn — a repeat succeeds only ~\(odds)%")
            }
            if let item = s.item { bits.append("item: \(item) (observed)") }
            if let locked = s.choiceLockedMove {
                // m12-E: a Choice item pins the last committed move until a switch.
                bits.append("🔒 Choice-locked into \(locked) until it switches")
            }
            if let ability = s.ability {
                bits.append("ability: \(ability) (observed)")
                if priorityBlockingAbilities.contains(ability) {
                    bits.append("⚠️ \(ability) CONFIRMED — priority moves into this side FAIL")
                }
            }
            bits.append(s.revealedMoves.isEmpty
                        ? "no moves revealed yet"
                        : "revealed: \(s.revealedMoves.joined(separator: ", "))")
            if !s.hints.isEmpty {
                // m12-B: what its observed damage implies about the set —
                // engine-derived, so it outranks the capsule priors.
                bits.append("🔎 inferred from observed damage: "
                            + s.hints.joined(separator: "; "))
            }
            return "- \(s.species)\(s.displayName != s.species ? " “\(s.displayName)”" : ""): "
                + bits.joined(separator: " · ")
        }
        let you = snapshots.filter { $0.side == "you" }
        let opp = snapshots.filter { $0.side == "opp" }
        L.append("\nYOUR ACTIVES:")
        L.append(contentsOf: you.map(describe))
        L.append("\nOPPONENT ACTIVES:")
        L.append(contentsOf: opp.map(describe))

        // Benches (what's in the back matters for the play)
        func bench(_ mons: [PokemonState]) -> String {
            mons.map { m in
                var s = m.describeName
                if m.hp?.isFainted == true { s += " (FAINTED)" }
                else if let hp = m.hp { s += " (\(hp.display))" }
                return s
            }.joined(separator: ", ")
        }
        if !yourBench.isEmpty { L.append("\nYOUR BENCH: \(bench(yourBench))") }
        if !oppBench.isEmpty { L.append("OPPONENT BENCH (preview-known): \(bench(oppBench))") }

        // Deterministic math
        if let m = matchup {
            L.append("\nDAMAGE MATH (deterministic; \(m.assumptions)):")
            L.append("Incoming threats:")
            for p in m.incoming.prefix(4) {
                L.append("- \(p.attacker) \(p.move) → \(p.defender): \(p.minPct)–\(p.maxPct)%"
                    + (p.guaranteedKo ? " [GUARANTEED KO]" : p.koNow ? " [KO RANGE]" : "")
                    + (p.setSource == "observed" ? "" : " (set from \(p.setSource))")
                    + (p.approx ? " (~stats)" : ""))
            }
            L.append("Your answers:")
            for p in m.outgoing.prefix(4) {
                L.append("- \(p.attacker) \(p.move) → \(p.defender): \(p.minPct)–\(p.maxPct)%"
                    + (p.guaranteedKo ? " [GUARANTEED KO]" : p.koNow ? " [KO RANGE]" : ""))
            }
            L.append("Speed order\(m.trickRoom ? " (TRICK ROOM — reversed)" : "") — your actives' speeds are exact, opponents' are estimates (see brackets): "
                + m.speeds.map { "\($0.species)(\($0.side)) \($0.spe)" }.joined(separator: " → "))
            let priorityCallouts = (m.incoming + m.outgoing)
                .filter { Self.priorityMoves.contains($0.move) }
                .map { "\($0.attacker)'s \($0.move)" }
            if !priorityCallouts.isEmpty {
                L.append("PRIORITY (moves first, ignores speed order AND Trick Room): "
                    + Array(Set(priorityCallouts)).sorted().joined(separator: "; "))
            }
            // m14-B (the pilot's Solar Beam forfeit): a mon that acts AFTER
            // a KO-holder never gets its move — the advisor reasoned the KO
            // and still committed a slower attack. Say the consequence
            // DETERMINISTICALLY. Computed by the shared doomedSlots helper
            // (m15-B) so the context flag and PlayLint can never drift.
            for slot in doomedSlots(matchup: m, opponentCeilings: speedCeilings(capsules: capsules)) {
                switch slot.tier {
                case .guaranteed, .range:
                    L.append("⚠️ DOOMED SLOT: \(slot.species) acts AFTER \(slot.killer), "
                        + "whose \(slot.killerMove) is \(slot.tier == .guaranteed ? "a GUARANTEED KO" : "in KO range") — "
                        + "a non-priority move from \(slot.species) "
                        + "\(slot.tier == .guaranteed ? "never executes" : "likely never executes"). "
                        + "Do not spend it on a slower attack: switch it out, Protect, use priority, "
                        + "redirect with the partner, or play for the partner's best line.")
                case .priorityKiller:
                    // m15-B: the tier m14-B missed — an unconditional
                    // PRIORITY move in guaranteed-KO range denies the slot
                    // regardless of speed order; only Protect-family (or
                    // out-prioritizing it) saves the action.
                    L.append("⚠️ PRIORITY THREAT: \(slot.killer)'s \(slot.killerMove) (priority) "
                        + "guaranteed-KOs \(slot.species) BEFORE any non-priority action, even though "
                        + "\(slot.species) may outspeed — Protect-family, a faster priority move, or a "
                        + "switch are the only actions that beat it.")
                case .speedRisk:
                    // m15-B, the pilot's Solar Beam loss: "I outspeed" was
                    // a 0-EV-floor estimate; the killer's bracket ceiling
                    // said otherwise. The gamble doctrine, made a flag.
                    let evidence = slot.killerCeiling.flatMap { ceiling in
                        slot.yourSpeed.map { "bracket ceiling ~\(ceiling) vs \(slot.species)'s \($0)" }
                    } ?? "its bracket ceiling beats your speed"
                    L.append("⚠️ SPEED RISK: the order above shows \(slot.species) before \(slot.killer), "
                        + "but that is a 0-EV ESTIMATE — if \(slot.killer) is invested or Scarfed "
                        + "(\(evidence)), its \(slot.killerMove) KO fires FIRST and \(slot.species)'s "
                        + "attack never happens. Treat attacking before it as a deliberate gamble, not a "
                        + "fact: prefer Protect, a switch, priority, or the partner's line unless you "
                        + "accept the risk.")
                }
            }
        }

        // The FULL battle log (m12-F: 8 → 20 → everything, pilot's call) —
        // whole-game patterns (TR stalling, switch cycles, what already
        // traded) live in history, not state. Bounded in practice by event
        // coalescing (~150 lines for a 10-minute battle), and paid uncached
        // only on an ask's first round-trip.
        let tail = recentEvents.map { "\(BattleEvent.mmss($0.t)) \($0.displayLine)" }
        if !tail.isEmpty {
            L.append("\nBATTLE SO FAR (every tracked event, oldest first):")
            L.append(contentsOf: tail.map { "- \($0)" })
        }
        return L.joined(separator: "\n")
    }

    /// Common priority attacks — flagged deterministically so the model
    /// never has to remember which moves jump the speed order.
    static let priorityMoves: Set<String> = [
        "Fake Out", "Extreme Speed", "Sucker Punch", "Aqua Jet", "Bullet Punch",
        "Mach Punch", "Quick Attack", "Shadow Sneak", "Ice Shard", "Accelerock",
        "Jet Punch", "Grassy Glide", "Vacuum Wave", "Water Shuriken", "First Impression",
    ]

    /// Priority attacks that fire UNCONDITIONALLY (m15-B): Fake Out and
    /// First Impression need their user's first-turn window and Sucker
    /// Punch needs the target to be attacking — those can't doom a slot
    /// deterministically, so the priority-killer tier excludes them.
    static let unconditionalPriorityMoves: Set<String> =
        priorityMoves.subtracting(["Fake Out", "First Impression", "Sucker Punch"])

    /// Opponent speed ceilings for the speedRisk tier: the capsule bracket
    /// max (252 EVs, +nature), ×1.5 when Choice Scarf is a real share of
    /// its usage items (capsule.scarfPossible, ≥5%).
    public static func speedCeilings(capsules: [OpponentCapsule]) -> [String: Int] {
        var out: [String: Int] = [:]
        for capsule in capsules {
            guard let ceiling = capsule.speedMax else { continue }
            out[capsule.species] = capsule.scarfPossible
                ? Int(Double(ceiling) * 1.5) : ceiling
        }
        return out
    }

    // MARK: Doomed slots (m14-B flag; m15-B shared with PlayLint)

    /// One denied action: YOUR active whose committed non-priority move
    /// would never execute this turn.
    nonisolated public struct DoomedSlot: Sendable, Codable, Equatable {
        nonisolated public enum Tier: String, Sendable, Codable {
            /// Acts after an attacker whose incoming line min-roll KOs.
            case guaranteed
            /// Acts after an attacker whose incoming line max-roll KOs.
            case range
            /// An UNCONDITIONAL priority move guaranteed-KOs it — speed
            /// order is irrelevant; only Protect-family or faster priority
            /// beats it (the tier m14-B missed).
            case priorityKiller
            /// The estimated order says you act first, but the killer's
            /// SPEED-BRACKET CEILING (Scarf-adjusted) beats your exact
            /// speed — "I outspeed" is a 0-EV-floor assumption, not a
            /// fact. The tier behind the pilot's Solar Beam loss: the
            /// advisor cashed in Charizard past a bracket-faster killer.
            case speedRisk
        }
        public let species: String      // your active whose action is denied
        public let killer: String       // the opponent attacker
        public let killerMove: String
        public let tier: Tier
        /// speedRisk evidence: the killer's bracket ceiling vs your speed.
        public var killerCeiling: Int? = nil
        public var yourSpeed: Int? = nil
        public init(species: String, killer: String, killerMove: String, tier: Tier,
                    killerCeiling: Int? = nil, yourSpeed: Int? = nil) {
            self.species = species
            self.killer = killer
            self.killerMove = killerMove
            self.tier = tier
            self.killerCeiling = killerCeiling
            self.yourSpeed = yourSpeed
        }
    }

    /// The m14-B doomed-slot computation, ONE source of truth: buildTurn's
    /// rendered ⚠️ flags and PlayLint's LintContext both consume this.
    /// m.speeds is move order (TR pre-applied). At most one slot per
    /// your-active, most severe tier wins: the speed tiers keep m14-B's
    /// exact semantics (worst killer by maxPct decides guaranteed vs
    /// range); priorityKiller and speedRisk only fire when no speed doom
    /// exists, so boards that flagged before m15-B render byte-identically.
    /// `opponentCeilings` maps opponent species → bracket ceiling (252+
    /// nature, ×1.5 when Choice Scarf appears in its usage items) — from
    /// the capsules. speedRisk is skipped under Trick Room (the ceiling
    /// comparison inverts there; TR boards keep the exact-order tiers).
    public static func doomedSlots(matchup m: LiveMatchupData,
                                   opponentCeilings: [String: Int] = [:]) -> [DoomedSlot] {
        var out: [DoomedSlot] = []
        for yours in m.speeds.filter({ $0.side == "you" }) {
            let actsBefore = m.speeds
                .prefix { !($0.side == "you" && $0.species == yours.species) }
                .filter { $0.side == "opp" }
                .map(\.species)
            let speedKillers = m.incoming.filter {
                $0.defender == yours.species
                    && ($0.koNow || $0.guaranteedKo)
                    && actsBefore.contains($0.attacker)
            }
            let priorityKillers = m.incoming.filter {
                $0.defender == yours.species
                    && $0.guaranteedKo
                    && unconditionalPriorityMoves.contains($0.move)
            }
            // Bracket-faster killers the current estimate orders AFTER you:
            // non-priority KO lines whose attacker could out-invest your
            // exact speed (the "outspeed gamble" doctrine, made a fact).
            let bracketKillers = m.trickRoom ? [] : m.incoming.filter {
                $0.defender == yours.species
                    && ($0.koNow || $0.guaranteedKo)
                    && !actsBefore.contains($0.attacker)
                    && !priorityMoves.contains($0.move)
                    && (opponentCeilings[$0.attacker] ?? 0) >= yours.spe
            }
            if let worst = speedKillers.max(by: { $0.maxPct < $1.maxPct }) {
                out.append(DoomedSlot(species: yours.species, killer: worst.attacker,
                                      killerMove: worst.move,
                                      tier: worst.guaranteedKo ? .guaranteed : .range))
            } else if let worst = priorityKillers.max(by: { $0.maxPct < $1.maxPct }) {
                out.append(DoomedSlot(species: yours.species, killer: worst.attacker,
                                      killerMove: worst.move, tier: .priorityKiller))
            } else if let worst = bracketKillers.max(by: { $0.maxPct < $1.maxPct }) {
                out.append(DoomedSlot(species: yours.species, killer: worst.attacker,
                                      killerMove: worst.move, tier: .speedRisk,
                                      killerCeiling: opponentCeilings[worst.attacker],
                                      yourSpeed: yours.spe))
            }
        }
        return out
    }

    /// Abilities that make opposing PRIORITY moves fail against that side
    /// (battle 7: Farigiraf's Armor Tail stopped Fake Out cold). Flagged in
    /// capsules (likely ability) and per-active (observed ability).
    public static let priorityBlockingAbilities: Set<String> = [
        "Armor Tail", "Dazzling", "Queenly Majesty",
    ]

    // MARK: System prompt (m11 — the agentic coach)

    /// The advisor's system prompt. Brevity of the ANSWER is the product
    /// requirement (the on-screen move timer is ~40s, spec §3); the tool
    /// loop is where deliberation happens. The deterministic math is
    /// authoritative; the model's job is prioritization and lines, plus
    /// targeted tool checks for the hypotheticals the context can't
    /// pre-compute. Static string — byte-stable for prompt caching.
    public static let systemPrompt = """
    You are ScopeLens's VGC doubles coach for Pokémon Champions ranked ladder play. \
    You answer two kinds of questions: TEAM PREVIEW ("what do I bring?" — decided once, \
    with ~90 seconds of thinking time) and CURRENT TURN ("what's the play?" — mid-battle, \
    under a ~40-second move timer).

    HOW TO READ THE CONTEXT
    The first block is BATTLE-STATIC: the pilot's full team (ground truth) and meta \
    capsules for all six opponent preview mons — usage priors (move/item/ability %), \
    winrate, L50 speed brackets (0-EV floor → 252 +nature ceiling, Scarf flagged), and \
    defensive typing. Capsules are PRIORS, not observations. The second block is the \
    question. A TEAM PREVIEW block carries the deterministic heuristic's bring-4/leads \
    baseline plus the full-HP threat matrix highlights — nothing is observed yet. A \
    CURRENT TURN block carries the actives with everything actually observed (labeled), \
    the live field, deterministic damage math, benches, and the full battle log so far. \
    Damage numbers \
    given are exact @smogon/calc results — never recompute or contradict them; observed \
    facts outrank priors.

    YOUR TOOLS
    The six ScopeLens engine tools answer hypotheticals the context doesn't pre-compute: \
    damage_calc for a specific move the tables don't show (a likely-but-unrevealed \
    move from a capsule, a boosted line, "does X survive Y?"); live_matchup to evaluate \
    a SWITCH mid-battle (swap the incoming bench mon into `mine`/`theirs` with its current \
    HP) or to stress-test a candidate LEAD PAIRING at preview (your two leads vs their two \
    likely leads, capsule items/abilities filled in); meta_profile for full usage detail \
    beyond a capsule's top-4; type_calc for a quick coverage check; scout_report for \
    whole-team repositioning or the full preview damage matrix; resolve_species when a \
    name looks garbled. Reason like a player: "this mon likely carries X (capsule) — if that \
    speed checks (bracket), my play dies — verify the damage — pick the line that survives \
    both branches." Make every check count: at most ~5 tool calls on a turn question, ~8 at \
    team preview — and issue independent checks IN PARALLEL (multiple tool calls in one \
    response). If the context already decides the answer, answer immediately with no tool \
    calls. Never ask the user questions. One more tool is NOT an engine check: \
    commit_play records your final per-active decision for a CURRENT TURN answer — it is \
    how the pilot receives the play (see THE ANSWER below).

    CHAMPIONS RULESET (differs from mainline VGC — trust this over your priors)
    There is NO Terastallization, NO Z-Moves, and NO Dynamax in Pokémon Champions — never \
    suggest them. Mega Evolution IS real, including cross-era megas that never existed in \
    mainline games (Mega Staraptor, Mega Scrafty…) — trust the capsules and observed state \
    over mainline-era memory. Cross-generation movepools are common; the capsules reflect \
    what this ladder actually runs.

    NON-NEGOTIABLE GAME RULES
    Fake Out only works on a Pokémon's FIRST turn after entering (each active's window is \
    stated — never suggest an illegal Fake Out). First Impression likewise only on its \
    user's first turn. Priority moves (Fake Out, Sucker Punch, Extreme Speed, Aqua Jet, …) \
    strike before the speed order even under Trick Room. Sucker Punch fails unless the \
    target is using an attack. PRIORITY BLOCKERS: while a Pokémon with Armor Tail, \
    Dazzling, or Queenly Majesty is active, opposing priority moves aimed at its side \
    FAIL outright — flagged in the context both as capsule priors and as observed \
    abilities; do not recommend priority into a blocker, and remember the OPPONENT's \
    blocker also shuts off YOUR priority. Protect can't be used twice in a row reliably — \
    the context flags each active that just Protected, with the odds a repeat succeeds; \
    treat a flagged opponent as unlikely to block again, and don't lean on your own repeat. \
    CHOICE LOCK: a Pokémon whose observed item is a Choice item is locked into its last \
    committed move until it switches — the context flags this per active; exploit a bad \
    lock (free setup, safe switch-ins), and never plan a different move for a locked mon. \
    Mind Perish counts, speed brackets (an "outspeed" that only works at the 0-EV floor \
    is a gamble, not a fact), and what the opponent's bench can punish.

    DOUBLES DOCTRINE (apply silently; cite only what changes the play)
    Spread moves hit both opponents, and every damage number you are given ALREADY \
    includes the doubles 0.75× spread reduction — never re-derate it. Redirection \
    (Follow Me / Rage Powder) pulls single-target moves onto the redirector; spread moves \
    ignore it and Wide Guard blocks them. Switching re-triggers switch-in abilities \
    (Intimidate cycles on re-entry; Defiant, Competitive, and Guard Dog punish it). \
    Speed control is layered: Tailwind (~4 turns, doubles the side's speed), Trick Room \
    (~5 turns, slowest acts first), paralysis and Icy Wind-class chip — win the speed \
    layer before committing to a damage race. Doubling onto one target secures KOs but \
    loses tempo to Protect; judge the Protect risk (the flags above) before doubling up. \
    TURN-ORDER CONSEQUENCE: a Pokémon that acts AFTER a lethal attacker gets NO move that \
    turn unless it uses priority — never "cash in" damage with a slower mon that dies \
    first (its attack simply never happens; that is a forfeited action, the classic \
    misplay). The context flags these as ⚠️ DOOMED SLOT: respond with a switch, Protect, \
    priority, redirection, or by optimizing the partner instead. Weather-dependent moves \
    need the weather NOW: Solar Beam without active sun spends the whole turn charging, \
    and Weather Ball's type follows the current field — check the weather line (and its \
    turns left) before committing to either. \
    Endgames are counting exercises: mons remaining, speed order, Protect availability, \
    perish clocks — count before you commit.

    THE ANSWER
    CURRENT TURN — decide, commit, then explain. When you have decided, call commit_play \
    ONCE with the exact action for EACH of your actives (move + target, or a switch) AND \
    include your reasoning as text in the SAME response: at most 3 short sentences — \
    (1) the single biggest danger or opportunity this turn, (2) why this line, (3) only \
    if critical, one thing to watch next turn. The pilot inputs your committed actions \
    into the game directly, so use exact names; the reasoning is read after. If you \
    genuinely cannot commit a line, answer in text only.
    TEAM PREVIEW — after any tool checks, answer in AT MOST 4 short sentences: (1) the \
    FOUR to bring, (2) the lead pair, chosen to survive their likely leads, (3) the \
    turn-1 plan (moves and targets), (4) the biggest threat to play around. Endorse or \
    overrule the heuristic baseline deliberately — say why in a few words.
    Use plain move/species names. Be decisive — pick ONE line, not options.
    """
}
