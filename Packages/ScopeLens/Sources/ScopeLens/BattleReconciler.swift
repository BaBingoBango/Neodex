//
//  BattleReconciler.swift
//  Scope Lens
//
//  Phase 2, milestone 4: turns the per-frame observation stream into a
//  running §4.5 BattleState + event log, applying only changes that are legal
//  for the running state (spec §4.4 step 6 — free glitch protection):
//
//    • HP can't rise except via a known healing cause (drain, item proc,
//      narrated heal) — EXCEPT at re-sync checkpoints: menu-grade frames
//      (command/moveSelect/targetSelect/switchSelect) are authoritative after
//      two agreeing reads, which catches un-narrated healing (Leftovers).
//    • A fainted Pokémon stays fainted — later nonzero reads for it are
//      discarded as misattribution.
//    • Weather runs on a timer (default 5 turns, exact after a summary-panel
//      re-sync) and only changes via weather events.
//
//  State-mutation doctrine (m4 brief): narration / activation-chip /
//  teamPreview / result frames MUTATE; command-family frames re-sync;
//  lobby / matchup / communicating are lifecycle-only.
//
//  Identity: our side resolves against the known team; the opponent's mons
//  resolve display names against the species vocabulary, fall back to
//  nickname entities, and can be resolved later by a signature move
//  ("Matcha Gotcha" ⇒ Sinistcha). Every resolved species is corroborated
//  against the team-preview read; mismatches are logged as corrections —
//  the ground truth the native sprite harvest (stretch D) trains on.
//

import Foundation

nonisolated public final class BattleReconciler {

    // MARK: Seeds

    public struct TeamSeed: Sendable {
        public let species: String        // canonical: "Rotom-Wash"
        public let display: String        // narrated: "Rotom"
        public init(species: String, display: String) {
            self.species = species
            self.display = display
        }
        public init(species: String, vocabulary: BattleVocabulary) {
            self.species = species
            self.display = vocabulary.species.first { $0.name == species }?.display ?? species
        }
    }

    public struct PreviewSeed: Sendable {
        public let row: Int
        public let speciesTop: [String]   // vote order, best first
        public let types: [String]
        public init(row: Int, speciesTop: [String], types: [String]) {
            self.row = row
            self.speciesTop = speciesTop
            self.types = types
        }
    }

    // MARK: Tracked entity (internal source of truth; BattleState is a render)

    private final class Entity {
        let key: String
        let side: String                  // "you" | "opp"
        var displayName: String           // as narrated (species display or nickname)
        var speciesId: String?            // canonical when resolved
        var isNickname = false
        var hp: PokemonState.HP?
        var status: String?
        var boosts = PokemonState.Boosts()
        var revealedMoves: [String] = []
        var item: String?
        var ability: String?
        var mega = false
        var fainted = false
        var previewRow: Int?
        var perishCount: Int?              // Perish Song doom clock (clears on switch-out)
        var sentOutTurn: Int = 0           // turn it entered the field (Fake Out legality)
        // Protect pressure (m12-D): turn of the last SUCCESSFUL protect
        // ("X protected itself!" — the success banner, not the attempt;
        // a FAILED attempt resets the in-game odds counter, and our flag
        // self-corrects through the turn arithmetic) + the consecutive-
        // success streak. The switch-out reset mirrors the game's counter.
        var lastProtectTurn: Int?
        var protectStreak = 0
        // Choice lock (m12-E): the most recent move this mon COMMITTED to
        // (used or blocked-but-selected). With an OBSERVED Choice item,
        // that's what it's locked into until it switches out.
        var lastMoveUsed: String?
        /// m14-A: how often each revealed move has been USED (the notepad's
        /// "Protect ×3" — blocked attempts don't count, PP wasn't spent).
        var moveUseCounts: [String: Int] = [:]
        var lastPlateSeen: Double = -1
        var hints: [String] = []           // m12-B inference verdicts ("Psychic: item boost implied…")

        init(key: String, side: String, displayName: String) {
            self.key = key
            self.side = side
            self.displayName = displayName
        }
    }

    // MARK: Configuration & outputs

    public let vocabulary: BattleVocabulary
    private let yourTeam: [TeamSeed]
    private var oppPreview: [PreviewSeed]

    public private(set) var events: [BattleEvent] = []
    public private(set) var corrections: [String] = []
    public private(set) var anomalies: [String] = []
    public private(set) var opponentTrainer: String?
    public private(set) var outcome: String?     // won | lost | forfeit
    public private(set) var turn = 0

    // MARK: Temporal machinery

    private var entities: [String: Entity] = [:]
    private var activeKeys: [String: [String]] = ["you": [], "opp": []]
    private var confirmedPrimary: ScreenState = .unknown
    private var candidatePrimary: (state: ScreenState, count: Int)?
    private var sawResolutionSinceCommand = false
    private var battleStarted = false
    private var battleEnded = false
    private var sawPreBattleLifecycle = false
    private var lastBanner: (text: String, t: Double)?
    private var recentParseKeys: [String: Double] = [:]
    private var chipMemory: [String: Double] = [:]
    private var healWindow: [String: Double] = [:]
    private var lastMove: (key: String, move: String, t: Double)?
    private var pendingRise: [String: (hp: PokemonState.HP, t: Double)] = [:]
    private var weatherGuess = true               // turnsLeft is a default, not a panel read

    // m12-B: damage attribution. A hit's plate animation spans several
    // samples (the same coalescing the 🔻 events do), so an observation
    // FINALIZES only after the 2.5s settle window closes with no further
    // fall — recording at first sight would capture partial damage.
    private struct PendingDamage {
        let attackerKey: String
        let move: String
        let moveT: Double
        let attackerBoosts: [String: Int]  // stages when the hit landed
        let startHP: Int
        var latestHP: Int
        let maxHP: Int
        var lastT: Double
        var critSeen: Bool
        var spreadSuspect: Bool
    }
    private var pendingDamage: [String: PendingDamage] = [:]   // by defender key
    private var lastCritT = -100.0
    private var observationCounter = 0

    private static let checkpointStates: Set<ScreenState> = [
        .command, .moveSelect, .targetSelect, .switchSelect,
    ]
    private static let healingItems: Set<String> = [
        "Sitrus Berry", "Leftovers", "Oran Berry", "Berry Juice", "Figy Berry",
        "Wiki Berry", "Mago Berry", "Aguav Berry", "Iapapa Berry", "Enigma Berry",
    ]

    public init(vocabulary: BattleVocabulary, yourTeam: [TeamSeed],
                oppPreview: [PreviewSeed] = []) {
        self.vocabulary = vocabulary
        self.yourTeam = yourTeam
        self.oppPreview = oppPreview
        for seed in yourTeam {
            let e = Entity(key: "you|\(seed.display.lowercased())", side: "you",
                           displayName: seed.display)
            e.speciesId = seed.species
            entities[e.key] = e
        }
    }

    /// Whether a team-preview seed was ever applied — drives the mid-battle
    /// Reset re-seed decision (m11-B): a fresh reconciler for the SAME
    /// battle should get the same preview back, not degrade to nicknames.
    public var hasPreviewSeed: Bool { !oppPreview.isEmpty }

    /// Seed (or replace) the opponent-preview read. Live consensus KEEPS
    /// improving while the preview is up (early frames are laser-degraded —
    /// battle 4's Scrafty froze as "Krokorok" from a 5-frame early vote), so
    /// re-seeding refines in place: the existing teamPreviewRead event is
    /// updated, not duplicated. Safe any time before opponents are bound.
    public func seedPreview(_ seeds: [PreviewSeed], t: Double) {
        oppPreview = seeds
        let summary = seeds
            .map { "row\($0.row) \($0.types.joined(separator: "/")) → \($0.speciesTop.first ?? "?")" }
            .joined(separator: "; ")
        if let i = events.lastIndex(where: { $0.kind == .teamPreviewRead }) {
            events[i] = BattleEvent(t: events[i].t, turn: events[i].turn,
                                    kind: .teamPreviewRead, side: "opp", detail: summary)
        } else {
            emit(.init(t: t, turn: turn, kind: .teamPreviewRead, side: "opp", detail: summary))
        }
        for e in entities.values where e.side == "opp" && e.previewRow == nil && e.speciesId != nil {
            bindToPreviewRow(e, t: t)
        }
    }

    // MARK: Ingest

    public func ingest(_ obs: FrameObservation) {
        // The WON/LOST splash follows the ending narration — it may refine a
        // "forfeit" outcome, so it processes even after the battle ended.
        if let outcome = obs.resultOutcome { endBattle(outcome, t: obs.t) }
        guard !battleEnded else { return }
        finalizeSettledDamage(t: obs.t)
        let parser = BattleEventParser(vocabulary: vocabulary)

        confirmPrimary(obs)

        if let banner = obs.banner, !isFragmentOfLastBanner(banner, t: obs.t) {
            let parse = parser.parseBanner(banner)
            if isNewParse(parse, t: obs.t) { apply(parse, t: obs.t) }
        }
        for chip in obs.chips { apply(chip, t: obs.t) }
        for read in obs.hpReads { apply(read, t: obs.t, primary: obs.primary) }
        for status in obs.fieldStatuses { applyFieldStatus(status, t: obs.t) }
        if let summary = obs.summary { apply(summary, t: obs.t, primary: obs.primary) }
    }

    // MARK: Primary debounce → turn machinery

    private func confirmPrimary(_ obs: FrameObservation) {
        let p = obs.primary
        guard p != confirmedPrimary else { candidatePrimary = nil; return }
        if candidatePrimary?.state == p {
            candidatePrimary!.count += 1
            guard candidatePrimary!.count >= 2 else { return }
        } else {
            candidatePrimary = (p, 1)
            return
        }
        candidatePrimary = nil
        confirmedPrimary = p

        if [.lobby, .teamPreview, .matchup].contains(p) { sawPreBattleLifecycle = true }
        if !battleStarted, [.command, .moveSelect, .narration, .communicating].contains(p) {
            battleStarted = true
            emit(.init(t: obs.t, turn: turn, kind: .battleStart,
                       detail: sawPreBattleLifecycle ? nil
                           : "joined mid-battle — turn numbers are relative"))
        }
        switch p {
        case .command where sawResolutionSinceCommand || turn == 0:
            turn += 1
            sawResolutionSinceCommand = false
            emit(.init(t: obs.t, turn: turn, kind: .turnStart))
            if let w = decrementWeather() { emit(.init(t: obs.t, turn: turn, kind: .note, detail: w)) }
        case .narration, .communicating:
            sawResolutionSinceCommand = true
        default:
            break
        }
    }

    /// Weather turn timer: tick down at each new command checkpoint; expire
    /// quietly only if we never saw the "faded" narration (belt and braces).
    private func decrementWeather() -> String? {
        guard weather.kind != "none", let left = weather.turnsLeft else { return nil }
        weather.turnsLeft = max(left - 1, 0)
        if left - 1 <= 0 {
            let kind = weather.kind
            weather = BattleState.Weather()
            return "\(kind) timer expired\(weatherGuess ? " (estimated)" : "")"
        }
        return nil
    }

    // MARK: Banner application

    /// Mid-fade frames read a *truncated* window of the outgoing banner
    /// ("Jarchomp used Rock Tomb" from "The opposing Garchomp used Rock
    /// Tomb!"). Losing the "The opposing" prefix flips side attribution, so
    /// fragments must die before parsing: a strictly-shorter fuzzy substring
    /// of the recent banner is the fade, not a new message.
    private func isFragmentOfLastBanner(_ text: String, t: Double) -> Bool {
        guard let last = lastBanner, t - last.t <= 3.5 else {
            lastBanner = (text, t)
            return false
        }
        let a = BattleVocabulary.normalize(text)
        let b = BattleVocabulary.normalize(last.text)
        if a.count < b.count - 3 && b.fuzzilyContains(a, maxEdits: 2) {
            // Fade of the banner we already processed: keep the long text
            // alive (fades shrink monotonically) and swallow the fragment.
            lastBanner!.t = t
            return true
        }
        // A genuinely new banner — even a SHORTER one — replaces the memory.
        // ("Longest wins" must never let an old long line shadow a new short
        // one, or fragments get compared against the wrong banner.)
        lastBanner = (text, t)
        return false
    }

    /// Wobbled re-reads of one banner parse to the same structure — dedupe
    /// on the parse, not the raw text ("Rotorn used Thunderboltl" ≡ "Rotom
    /// used Thunderbolt!"). Keyed over a WINDOW of recent parses, not just
    /// the last one: an unrecognized fragment sandwiched between two clean
    /// reads must not break the chain (battle 5's ×3 Mega Evolved / ×3
    /// Thunderbolt). Unrecognized lines fall back to raw fuzziness.
    private func isNewParse(_ parse: BannerParse, t: Double) -> Bool {
        recentParseKeys = recentParseKeys.filter { t - $0.value <= 3.5 }
        let key: String
        if parse.template == .unrecognized {
            key = "raw|\(BattleVocabulary.normalize(parse.raw))"
        } else {
            key = parse.semanticKey
        }
        defer { recentParseKeys[key] = t }
        if recentParseKeys[key] != nil { return false }
        if parse.template == .unrecognized {
            let normalized = BattleVocabulary.normalize(parse.raw)
            for (recent, _) in recentParseKeys where recent.hasPrefix("raw|") {
                if BattleVocabulary.levenshtein(String(recent.dropFirst(4)), normalized, cap: 2) <= 2 {
                    return false
                }
            }
        }
        return true
    }

    private func apply(_ parse: BannerParse, t: Double) {
        switch parse.template {

        case .sendOutOpp:
            // Longest read wins: mid-fade truncation clipped a live trainer
            // name to "In" (battle 4) — later cleaner banners refine it.
            if let trainer = parse.trainer, trainer.count > (opponentTrainer?.count ?? 0) {
                opponentTrainer = trainer
            }
            for name in parse.subjects { sendOut(name, side: "opp", t: t, raw: parse.raw) }

        case .sendOutYou:
            for name in parse.subjects { sendOut(name, side: "you", t: t, raw: parse.raw) }

        case .withdrawOpp, .withdrawYou:
            let side = parse.template == .withdrawOpp ? "opp" : "you"
            for name in parse.subjects {
                guard let e = resolve(name, side: side, t: t) else { continue }
                activeKeys[side]!.removeAll { $0 == e.key }
                e.boosts = PokemonState.Boosts()   // stat stages reset on switch-out
                e.perishCount = nil                // …and the perish clock stops
                e.lastProtectTurn = nil            // …and the Protect odds counter resets
                e.protectStreak = 0
                e.lastMoveUsed = nil               // …and the Choice lock releases
                emit(.init(t: t, turn: turn, kind: .withdraw, side: side,
                           subject: e.displayName, species: e.speciesId, raw: parse.raw))
            }

        case .moveUsed:
            guard let move = parse.detail, let name = parse.subjects.first,
                  let e = resolve(name, side: parse.side ?? "you", t: t,
                                  canCreate: !parse.fuzzy) else { return }
            if !e.revealedMoves.contains(move) {
                e.revealedMoves.append(move)
                if e.revealedMoves.count > 4 {
                    anomalies.append("\(BattleEvent.mmss(t)) \(e.displayName) revealed a 5th move (\(move)) — likely misattribution")
                }
            }
            lastMove = (e.key, move, t)
            e.lastMoveUsed = move
            e.moveUseCounts[move, default: 0] += 1
            emit(.init(t: t, turn: turn, kind: .moveUsed, side: e.side,
                       subject: e.displayName, species: e.speciesId, detail: move, raw: parse.raw))
            resolveNicknameIfSignature(e, move: move, t: t)

        case .moveBlocked:
            // A blocked attempt still PROVES the mon carries the move
            // (battle 7: Armor Tail stopped Fake Out — reveal it, but no
            // lastMove window: nothing landed).
            guard let move = parse.detail, let name = parse.subjects.first,
                  let e = resolve(name, side: parse.side ?? "you", t: t,
                                  canCreate: !parse.fuzzy) else { return }
            if !e.revealedMoves.contains(move) { e.revealedMoves.append(move) }
            e.lastMoveUsed = move   // choice lock applies once SELECTED, even blocked
            emit(.init(t: t, turn: turn, kind: .moveBlocked, side: e.side,
                       subject: e.displayName, species: e.speciesId, detail: move,
                       raw: parse.raw))

        case .protected:
            // Side-wide protection (Wide Guard set message) has no subject.
            guard let name = parse.subjects.first else {
                emit(.init(t: t, turn: turn, kind: .protected, side: parse.side,
                           detail: parse.detail, raw: parse.raw))
                return
            }
            // A side guard's per-hit line (Wide Guard m6, Quick Guard
            // battle 9) names the BENEFICIARY, not the user — lookup-only,
            // and never credit it as a revealed move. Self-protects carry
            // no detail.
            let sideGuard = parse.detail != nil
            guard let e = resolve(name, side: parse.side ?? "you", t: t,
                                  canCreate: !parse.fuzzy && !sideGuard) else { return }
            if !sideGuard, !e.revealedMoves.contains("Protect") {
                e.revealedMoves.append("Protect")
            }
            // Protect pressure (m12-D): a SUCCESSFUL self-protect arms the
            // consecutive-use odds drop. Side guards are excluded twice
            // over: their per-hit lines name beneficiaries, and they don't
            // share Protect's failure counter.
            if !sideGuard, e.lastProtectTurn != turn {
                e.protectStreak = (e.lastProtectTurn == turn - 1) ? e.protectStreak + 1 : 1
                e.lastProtectTurn = turn
            }
            emit(.init(t: t, turn: turn, kind: .protected, side: e.side,
                       subject: e.displayName, species: e.speciesId,
                       detail: parse.detail, raw: parse.raw))

        case .fainted:
            for name in parse.subjects {
                guard let e = resolve(name, side: parse.side ?? "you", t: t) else { continue }
                e.fainted = true
                e.status = nil
                e.boosts = PokemonState.Boosts()
                e.perishCount = nil
                e.hp = e.hp.map { $0.kind == "exact" ? .exact(0, $0.max ?? 0) : .percent(0) }
                    ?? .percent(0)
                activeKeys[e.side]!.removeAll { $0 == e.key }
                emit(.init(t: t, turn: turn, kind: .fainted, side: e.side,
                           subject: e.displayName, species: e.speciesId, raw: parse.raw))
            }

        case .effectiveness:
            // Lookup-only: a compound/garbled target must never mint entities.
            let names = parse.subjects.map {
                resolve($0, side: parse.side ?? "you", t: t, canCreate: false)?.displayName ?? $0
            }
            emit(.init(t: t, turn: turn, kind: .effectiveness, side: parse.side,
                       subject: names.joined(separator: ", "), detail: parse.detail, raw: parse.raw))

        case .statChange:
            guard let stats = parse.detail, let delta = parse.magnitude else { return }
            for name in parse.subjects {
                guard let e = resolve(name, side: parse.side ?? "you", t: t) else { continue }
                for stat in stats.components(separatedBy: " and ") { bump(e, stat: stat, by: delta) }
                emit(.init(t: t, turn: turn, kind: .statChange, side: e.side,
                           subject: e.displayName, species: e.speciesId, detail: stats,
                           value: String(format: "%+d", delta), raw: parse.raw))
            }

        case .statusInflicted:
            guard let status = parse.detail else { return }
            for name in parse.subjects {
                guard let e = resolve(name, side: parse.side ?? "you", t: t) else { continue }
                e.status = status
                emit(.init(t: t, turn: turn, kind: .statusInflicted, side: e.side,
                           subject: e.displayName, species: e.speciesId, detail: status, raw: parse.raw))
            }

        case .statusTick:
            guard let name = parse.subjects.first,
                  let e = resolve(name, side: parse.side ?? "you", t: t, canCreate: false)
            else { return }
            if let status = parse.detail, e.status == nil { e.status = status } // missed the infliction
            emit(.init(t: t, turn: turn, kind: .statusTick, side: e.side,
                       subject: e.displayName, species: e.speciesId, detail: parse.detail, raw: parse.raw))

        case .statusCleared:
            guard let name = parse.subjects.first,
                  let e = resolve(name, side: parse.side ?? "you", t: t, canCreate: false)
            else { return }
            e.status = nil
            emit(.init(t: t, turn: turn, kind: .statusCleared, side: e.side,
                       subject: e.displayName, species: e.speciesId, raw: parse.raw))

        case .statsRestored:
            // White Herb (battle 9): NEGATIVE stages clear, positives stay.
            // Also an item reveal when nothing else showed it (the item
            // chip usually fires first and already set it).
            guard let name = parse.subjects.first,
                  let e = resolve(name, side: parse.side ?? "you", t: t, canCreate: false)
            else { return }
            var b = e.boosts
            b.atk = max(0, b.atk); b.def = max(0, b.def); b.spa = max(0, b.spa)
            b.spd = max(0, b.spd); b.spe = max(0, b.spe)
            e.boosts = b
            if e.item == nil, let item = parse.detail {
                e.item = item
                emit(.init(t: t, turn: turn, kind: .itemRevealed, side: e.side,
                           subject: e.displayName, species: e.speciesId,
                           detail: item, raw: parse.raw))
            }
            emit(.init(t: t, turn: turn, kind: .boostsRestored, side: e.side,
                       subject: e.displayName, species: e.speciesId,
                       detail: parse.detail, raw: parse.raw))

        case .drained:
            guard let name = parse.subjects.first,
                  let victim = resolve(name, side: parse.side ?? "you", t: t,
                                       canCreate: !parse.fuzzy) else { return }
            // The drainer (healer) is whoever last moved — their HP may now
            // rise. 10s window: attack + drain animations lag the move
            // narration by ~7s live (battle 4's Drain Punch just missed 6s).
            if let last = lastMove, t - last.t <= 10 { healWindow[last.key] = t }
            emit(.init(t: t, turn: turn, kind: .drained, side: victim.side,
                       subject: victim.displayName, species: victim.speciesId, raw: parse.raw))

        case .recoil:
            guard let name = parse.subjects.first,
                  let e = resolve(name, side: parse.side ?? "you", t: t, canCreate: false)
            else { return }
            emit(.init(t: t, turn: turn, kind: .recoil, side: e.side,
                       subject: e.displayName, species: e.speciesId,
                       detail: parse.detail, raw: parse.raw))

        case .healedByItem:
            guard let name = parse.subjects.first,
                  let e = resolve(name, side: parse.side ?? "you", t: t) else { return }
            healWindow[e.key] = t
            emit(.init(t: t, turn: turn, kind: .healed, side: e.side,
                       subject: e.displayName, species: e.speciesId, detail: parse.detail, raw: parse.raw))

        case .itemHungOn:
            guard let name = parse.subjects.first, let item = parse.detail,
                  let e = resolve(name, side: parse.side ?? "you", t: t) else { return }
            e.item = item                      // Focus Sash class: reveal, no heal
            emit(.init(t: t, turn: turn, kind: .itemActivated, side: e.side,
                       subject: e.displayName, species: e.speciesId, detail: item, raw: parse.raw))

        case .chargingTurn:
            emit(.init(t: t, turn: turn, kind: .note, side: parse.side,
                       subject: parse.subjects.first, detail: "charging", raw: parse.raw))

        case .megaStoneReacting:
            guard let name = parse.subjects.first, let item = parse.detail,
                  let e = resolve(name, side: parse.side ?? "you", t: t) else { return }
            if e.item != item {
                e.item = item
                emit(.init(t: t, turn: turn, kind: .itemRevealed, side: e.side,
                           subject: e.displayName, species: e.speciesId, detail: item, raw: parse.raw))
            }

        case .megaEvolved:
            guard let name = parse.subjects.first,
                  let e = resolve(name, side: parse.side ?? "you", t: t) else { return }
            // Legality dedup (battle 7: "Laemo Mega Evolved" ×2, 1.5s apart):
            // differently-wobbled re-reads produce different semantic keys,
            // so the parse window can't catch them — state legality can.
            // A mon that already Mega Evolved stays Mega Evolved.
            guard !e.mega else { return }
            e.mega = true
            if let base = e.speciesId {
                let suffix: String = switch e.item {
                case .some(let i) where i.hasSuffix("ite X"): "-Mega-X"
                case .some(let i) where i.hasSuffix("ite Y"): "-Mega-Y"
                default: "-Mega"
                }
                if !base.contains("-Mega") { e.speciesId = base + suffix }
            }
            emit(.init(t: t, turn: turn, kind: .megaEvolved, side: e.side,
                       subject: e.displayName, species: e.speciesId, raw: parse.raw))

        case .weatherStart:
            guard let kind = parse.detail else { return }
            if weather.kind != kind {
                weather = BattleState.Weather(kind: kind, turnsLeft: 5)
                weatherGuess = true
                emit(.init(t: t, turn: turn, kind: .weatherStart, detail: kind, raw: parse.raw))
            }

        case .weatherEnd:
            if weather.kind != "none" {
                emit(.init(t: t, turn: turn, kind: .weatherEnd, detail: weather.kind, raw: parse.raw))
                weather = BattleState.Weather()
            }

        case .screenUp, .screenDown:
            guard let screen = parse.detail, let side = parse.side else { return }
            var screens = field.screens ?? BattleState.Screens()
            if parse.template == .screenUp {
                if side == "you", !screens.you.contains(screen) { screens.you.append(screen) }
                if side == "opp", !screens.opp.contains(screen) { screens.opp.append(screen) }
            } else {
                if side == "you" { screens.you.removeAll { $0 == screen } }
                else { screens.opp.removeAll { $0 == screen } }
            }
            field.screens = screens
            emit(.init(t: t, turn: turn, kind: parse.template == .screenUp ? .screenUp : .screenDown,
                       side: side, detail: screen, raw: parse.raw))

        case .trickRoomStart, .trickRoomEnd:
            field.trickRoom = parse.template == .trickRoomStart
            emit(.init(t: t, turn: turn, kind: .trickRoom, side: parse.side,
                       subject: parse.subjects.first,
                       value: field.trickRoom == true ? "on" : "off", raw: parse.raw))

        case .tailwindStart, .tailwindEnd:
            let on = parse.template == .tailwindStart
            if parse.side == "you" { field.tailwind.you = on } else { field.tailwind.opp = on }
            emit(.init(t: t, turn: turn, kind: .tailwind, side: parse.side,
                       value: on ? "on" : "off", raw: parse.raw))

        case .resultLine:
            if opponentTrainer == nil { opponentTrainer = parse.trainer }
            endBattle(parse.detail ?? "unknown", t: t, raw: parse.raw)

        case .forfeit:
            endBattle("forfeit", t: t, raw: parse.raw)

        case .perishSong:
            // Everyone on the field when the song lands is on the clock.
            for side in ["you", "opp"] {
                for key in activeKeys[side]! {
                    entities[key]?.perishCount = 3
                }
            }
            emit(.init(t: t, turn: turn, kind: .note,
                       detail: "Perish Song — all active Pokémon faint in 3 turns",
                       raw: parse.raw))

        case .perishCount:
            guard let name = parse.subjects.first, let n = parse.magnitude,
                  let e = resolve(name, side: parse.side ?? "you", t: t, canCreate: false),
                  activeKeys[e.side]!.contains(e.key)   // benched mons don't tick — misattribution guard
            else { return }
            e.perishCount = n
            emit(.init(t: t, turn: turn, kind: .perishCount, side: e.side,
                       subject: e.displayName, species: e.speciesId,
                       value: String(n), raw: parse.raw))

        case .missedOrAvoided:
            emit(.init(t: t, turn: turn, kind: .note, side: parse.side,
                       subject: parse.subjects.first,
                       detail: parse.detail ?? "avoided/missed", raw: parse.raw))

        case .noteworthy:
            // m12-B: a crit poisons damage attribution — the 1.5× modifier
            // would masquerade as investment. Mark every in-flight
            // observation and remember the moment (the note can precede the
            // plate animation it belongs to).
            if parse.detail == "critical hit" {
                lastCritT = t
                for key in pendingDamage.keys { pendingDamage[key]!.critSeen = true }
            }
            let subject = parse.subjects.first.flatMap {
                resolve($0, side: parse.side ?? "you", t: t, canCreate: false)?.displayName
            } ?? parse.subjects.first
            emit(.init(t: t, turn: turn, kind: .note, side: parse.side,
                       subject: subject, detail: parse.detail, raw: parse.raw))

        case .unrecognized:
            emit(.init(t: t, turn: turn, kind: .note, raw: parse.raw))
        }
    }

    // MARK: Chips

    private func apply(_ chip: FrameObservation.ChipRead, t: Double) {
        // Ability vs item is a vocabulary question (same chip UI serves both).
        let ability = vocabulary.snapAbility(chip.thingRaw)
        let item = vocabulary.snapItem(chip.thingRaw)
        let kind: BattleEvent.Kind
        let thing: String
        switch (ability, item) {
        case let (.some(a), .some(i)): (kind, thing) = i.edits < a.edits
            ? (.itemActivated, i.value) : (.abilityActivated, a.value)
        case let (.some(a), nil): (kind, thing) = (.abilityActivated, a.value)
        case let (nil, .some(i)): (kind, thing) = (.itemActivated, i.value)
        case (nil, nil): return                       // not a proc chip — reject as noise
        }

        let memoryKey = "\(chip.sideHint)|\(thing)"
        if let last = chipMemory[memoryKey], t - last <= 6 { chipMemory[memoryKey] = t; return }
        chipMemory[memoryKey] = t

        guard let e = resolve(chip.subjectRaw, side: chip.sideHint, t: t) else { return }
        if kind == .abilityActivated {
            e.ability = thing
        } else {
            e.item = thing
            if Self.healingItems.contains(thing) { healWindow[e.key] = t }
        }
        emit(.init(t: t, turn: turn, kind: kind, side: e.side,
                   subject: e.displayName, species: e.speciesId, detail: thing,
                   raw: "\(chip.subjectRaw)'s \(chip.thingRaw)"))
    }

    // MARK: HP legality

    private func apply(_ read: FrameObservation.HPRead, t: Double, primary: ScreenState) {
        guard let e = resolveForPlate(read.nameRaw, side: read.side, t: t) else { return }
        e.lastPlateSeen = t
        applyHP(to: e, hp: read.hp, t: t, primary: primary)
    }

    /// The HP legality core, shared by plate reads and summary-panel reads
    /// (m9-C). The caller owns entity resolution; this owns falls/rises/
    /// coalescing/max-consistency.
    private func applyHP(to e: Entity, hp: PokemonState.HP, t: Double, primary: ScreenState) {
        if e.fainted {
            let value = hp.cur ?? Int(hp.pct ?? 0)
            if value > 0 {
                anomalies.append("\(BattleEvent.mmss(t)) nonzero HP read for fainted \(e.displayName) discarded (fainted stays fainted)")
            }
            return
        }

        guard let old = e.hp, old.kind == hp.kind else {
            e.hp = hp                                   // first sighting — learn it
            return
        }

        // exact max-HP consistency: a different max is a misread or a
        // misattributed plate — reject rather than corrupt.
        if hp.kind == "exact", let m0 = old.max, let m1 = hp.max, m0 != m1 {
            anomalies.append("\(BattleEvent.mmss(t)) \(e.displayName) max-HP mismatch \(m1) vs \(m0) — read discarded")
            return
        }

        let oldValue = old.cur ?? Int(old.pct ?? 0)
        let newValue = hp.cur ?? Int(hp.pct ?? 0)
        if newValue == oldValue { pendingRise[e.key] = nil; return }

        if newValue < oldValue {                        // damage: always legal
            e.hp = hp
            pendingRise[e.key] = nil
            emitHPChange(.damageTaken, entity: e, from: old, to: hp, t: t)
            trackDamage(for: e, from: oldValue, to: newValue, hp: hp, t: t)
            return
        }

        // Rise: legal with a recent healing cause; otherwise needs
        // corroboration — two agreeing reads (checkpoint frames included:
        // that's the un-narrated-Leftovers catcher).
        let cause = healWindow[e.key].map { t - $0 <= 8 } ?? false
        let pending = pendingRise[e.key]
        let corroborated = pending.map {
            $0.hp.cur == hp.cur && $0.hp.pct == hp.pct && t - $0.t <= 5
        } ?? false

        if cause || corroborated {
            e.hp = hp
            pendingRise[e.key] = nil
            emitHPChange(cause ? .healed : .hpResync, entity: e, from: old, to: hp, t: t,
                         detail: cause ? nil : (Self.checkpointStates.contains(primary)
                             ? "checkpoint re-sync" : "corroborated rise (unnarrated heal?)"))
        } else {
            pendingRise[e.key] = (hp, t)
        }
    }

    // MARK: Damage attribution (m12-B)

    /// An observed hit, attribution-complete and ready for the engine's
    /// `inferAttack` — HP POINTS (exact plates), attacker stages at impact,
    /// and the live field, all frozen at finalize time. The reconciler stays
    /// engine-free: whoever owns a JSC engine (app poll loop, AdvisorHarness)
    /// drains these, runs the inference, and posts the verdict back via
    /// `recordInferenceVerdict`.
    public struct DamageObservation: Sendable {
        public let eventIndex: Int          // the 🔎 event to annotate
        public let attackerKey: String
        public let attackerSpecies: String  // calc-ready (mega suffix applied)
        public let attackerDisplay: String
        public let attackerBoosts: [String: Int]
        public let attackerMega: Bool
        public let move: String
        public let defenderSpecies: String
        public let defenderDisplay: String
        public let defenderBoosts: [String: Int]
        public let defenderStatus: String?
        public let observedDamage: Int      // HP points
        public let field: LiveFieldSpec
        public let t: Double
    }
    public private(set) var pendingInferences: [DamageObservation] = []

    /// Hand the settled observations to the engine owner (clears the queue).
    public func drainPendingInferences() -> [DamageObservation] {
        defer { pendingInferences = [] }
        return pendingInferences
    }

    /// Start or extend the pending observation for a you-side exact-HP fall.
    /// Attribution = the opponent's most recent move within 10s (the drain
    /// window's animation-lag bound). A second you-side active falling to
    /// the SAME move marks both spread-suspect (per-target modifiers make
    /// the math dishonest — v1 skips them, as does the engine's own gate).
    private func trackDamage(for e: Entity, from oldValue: Int, to newValue: Int,
                             hp: PokemonState.HP, t: Double) {
        guard e.side == "you", hp.kind == "exact", let mx = hp.max, mx > 0,
              let last = lastMove, let mover = entities[last.key],
              mover.side == "opp", t - last.t <= 10 else { return }

        if var p = pendingDamage[e.key], p.attackerKey == last.key,
           p.moveT == last.t, t - p.lastT <= 2.5 {
            p.latestHP = newValue                      // animation continues
            p.lastT = t
            pendingDamage[e.key] = p
            return
        }
        finalizeDamage(for: e.key)                     // a stale one never settled
        let sameHit = pendingDamage.keys.filter {
            pendingDamage[$0]!.attackerKey == last.key && pendingDamage[$0]!.moveT == last.t
        }
        for key in sameHit { pendingDamage[key]!.spreadSuspect = true }
        pendingDamage[e.key] = PendingDamage(
            attackerKey: last.key, move: last.move, moveT: last.t,
            attackerBoosts: boostsDictionary(mover.boosts),
            startHP: oldValue, latestHP: newValue, maxHP: mx, lastT: t,
            critSeen: t - lastCritT <= 5, spreadSuspect: !sameHit.isEmpty)
    }

    /// Observations settle when the coalescing window closes with no
    /// further fall — the same 2.5s the 🔻 events use.
    private func finalizeSettledDamage(t: Double) {
        for key in Array(pendingDamage.keys)
        where t - pendingDamage[key]!.lastT > 2.5 {
            finalizeDamage(for: key)
        }
    }

    private func finalizeDamage(for key: String) {
        guard let p = pendingDamage.removeValue(forKey: key) else { return }
        // Honesty gates (the brief's v1 scope): no crits, no spread hits,
        // no lethal hits (a KO only bounds the roll from below).
        guard !p.critSeen, !p.spreadSuspect, p.latestHP > 0,
              p.startHP > p.latestHP,
              let defender = entities[key], let defenderSpecies = defender.speciesId,
              let attacker = entities[p.attackerKey],
              let attackerSpecies = attacker.speciesId else { return }
        let damage = p.startHP - p.latestHP
        observationCounter += 1
        let eventIndex = events.count
        emit(.init(t: p.lastT, turn: turn, kind: .damageObserved, side: "opp",
                   subject: attacker.displayName, species: attackerSpecies,
                   detail: p.move,
                   value: "\(damage) HP into \(defender.displayName)"))
        pendingInferences.append(DamageObservation(
            eventIndex: eventIndex,
            attackerKey: p.attackerKey,
            attackerSpecies: attackerSpecies,
            attackerDisplay: attacker.displayName,
            attackerBoosts: p.attackerBoosts,
            attackerMega: attacker.mega,
            move: p.move,
            defenderSpecies: defenderSpecies,
            defenderDisplay: defender.displayName,
            defenderBoosts: boostsDictionary(defender.boosts),
            defenderStatus: defender.status,
            observedDamage: damage,
            field: liveFieldSpec(),
            t: p.lastT))
    }

    /// Post the engine's verdict back: the 🔎 event grows the summary and
    /// the ATTACKER carries the hint forward (advisor turn context, m12-B).
    public func recordInferenceVerdict(for obs: DamageObservation, summary: String) {
        if events.indices.contains(obs.eventIndex),
           events[obs.eventIndex].kind == .damageObserved {
            let e = events[obs.eventIndex]
            events[obs.eventIndex] = BattleEvent(
                t: e.t, turn: e.turn, kind: .damageObserved, side: e.side,
                subject: e.subject, species: e.species, detail: e.detail,
                value: "\(e.value ?? "") — \(summary)", raw: e.raw)
        }
        guard let attacker = entities[obs.attackerKey] else { return }
        attacker.hints.append("\(obs.move): \(summary)")
        if attacker.hints.count > 3 { attacker.hints.removeFirst() }
    }

    private func boostsDictionary(_ b: PokemonState.Boosts) -> [String: Int] {
        var out: [String: Int] = [:]
        for (k, v) in [("atk", b.atk), ("def", b.def), ("spa", b.spa),
                       ("spd", b.spd), ("spe", b.spe)] where v != 0 {
            out[k] = v
        }
        return out
    }

    /// HP plates animate toward their new value across several samples; the
    /// intermediate reads are the same hit, so consecutive same-direction
    /// changes for one mon coalesce into a single event ("202 → 28" instead
    /// of four stair-steps).
    private func emitHPChange(_ kind: BattleEvent.Kind, entity e: Entity,
                              from old: PokemonState.HP, to new: PokemonState.HP,
                              t: Double, detail: String? = nil) {
        if let i = events.lastIndex(where: { $0.kind == kind && $0.subject == e.displayName && $0.side == e.side }),
           t - events[i].t <= 2.5,
           let priorStart = events[i].value?.components(separatedBy: " → ").first {
            events[i] = BattleEvent(t: events[i].t, turn: events[i].turn, kind: kind,
                                    side: e.side, subject: e.displayName, species: e.speciesId,
                                    detail: detail ?? events[i].detail,
                                    value: "\(priorStart) → \(new.display)")
            return
        }
        emit(.init(t: t, turn: turn, kind: kind, side: e.side,
                   subject: e.displayName, species: e.speciesId, detail: detail,
                   value: "\(old.display) → \(new.display)"))
    }

    // MARK: Field-status re-sync (summary panel)

    private func applyFieldStatus(_ read: FrameObservation.FieldStatusRead, t: Double) {
        let kindMap = ["Harsh Sunlight": "sun", "Rain": "rain", "Sandstorm": "sand",
                       "Snow": "snow", "Hail": "snow"]
        if let kind = kindMap[read.name] {
            if weather.kind != kind {
                emit(.init(t: t, turn: turn, kind: .hpResync, detail:
                    "weather re-sync: \(weather.kind) → \(kind) \(read.remaining)/\(read.total) (summary panel)"))
            }
            weather = BattleState.Weather(kind: kind, turnsLeft: read.remaining)
            weatherGuess = false
        } else if read.name == "Trick Room" {
            if field.trickRoom != true {
                emit(.init(t: t, turn: turn, kind: .trickRoom,
                           detail: "summary panel re-sync",
                           value: "active \(read.remaining)/\(read.total)"))
            }
            field.trickRoom = true
        }
    }

    // MARK: Summary-panel mon card (m9-C)

    /// The browsable panel is an exact sheet for ANY mon — benched ones
    /// included, which plates never show. Observations beat priors: ability,
    /// item, absolute stat stages, and exact HP all re-sync here. Every
    /// write is change-gated (the panel persists across many frames).
    private func apply(_ read: FrameObservation.SummaryRead, t: Double,
                       primary: ScreenState) {
        guard let e = resolveForSummary(read) else { return }

        if let ability = read.ability, e.ability != ability {
            let previous = e.ability
            e.ability = ability
            emit(.init(t: t, turn: turn, kind: .abilityActivated, side: e.side,
                       subject: e.displayName, species: e.speciesId,
                       detail: ability + " (summary panel"
                           + (previous.map { ", was \($0)" } ?? "") + ")"))
        }
        if let item = read.item, e.item != item {
            e.item = item
            emit(.init(t: t, turn: turn, kind: .itemRevealed, side: e.side,
                       subject: e.displayName, species: e.speciesId,
                       detail: "\(item) (summary panel)"))
        }
        if !read.stages.isEmpty {
            var target = e.boosts   // unread rows keep their tracked value
            for (stat, stage) in read.stages {
                switch stat {
                case "atk": target.atk = stage
                case "def": target.def = stage
                case "spa": target.spa = stage
                case "spd": target.spd = stage
                case "spe": target.spe = stage
                default: break
                }
            }
            if target != e.boosts {
                let before = e.boosts
                e.boosts = target
                emit(.init(t: t, turn: turn, kind: .boostSync, side: e.side,
                           subject: e.displayName, species: e.speciesId,
                           detail: "was \(before.isNeutral ? "neutral" : before.display)",
                           value: target.isNeutral ? "neutral" : target.display))
            }
        }
        if let hp = read.hp { applyHP(to: e, hp: hp, t: t, primary: primary) }
    }

    /// Panel names follow the plate doctrine: an existing display name or a
    /// species-vocab snap onto an existing entity — garble binds nothing and
    /// the panel never mints entities. Mirror species (both sides own an
    /// Incineroar — battle 5 was real) disambiguate by consistency with
    /// already-known facts: matching max HP, ability, item; our side wins
    /// ties because its facts are complete.
    private func resolveForSummary(_ read: FrameObservation.SummaryRead) -> Entity? {
        let norm = BattleVocabulary.normalize(read.nameRaw)
        guard norm.count >= 3 else { return nil }
        var candidates = entities.values.filter {
            BattleVocabulary.normalize($0.displayName) == norm && !$0.fainted
        }
        if candidates.isEmpty,
           let species = vocabulary.species.first(where: {
               BattleVocabulary.normalize($0.display) == norm
                   || BattleVocabulary.normalize($0.name) == norm
           })?.name {
            candidates = entities.values.filter { $0.speciesId == species && !$0.fainted }
        }
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates[0] }
        func consistency(_ e: Entity) -> Int {
            var score = 0
            if let m = read.hp?.max, let known = e.hp?.max { score += m == known ? 4 : -4 }
            if let a = read.ability, let known = e.ability { score += a == known ? 2 : -2 }
            if let i = read.item, let known = e.item { score += i == known ? 2 : -2 }
            if e.side == "you" { score += 1 }
            return score
        }
        return candidates.max(by: { consistency($0) < consistency($1) })
    }

    // MARK: Battle end

    private func endBattle(_ how: String, t: Double, raw: String? = nil) {
        guard !battleEnded else {
            // "forfeit" is how it ended; the splash says who won — merge.
            if outcome == "forfeit", how == "won" || how == "lost",
               let i = events.lastIndex(where: { $0.kind == .battleEnd }) {
                outcome = "\(how) (by forfeit)"
                events[i] = BattleEvent(t: events[i].t, turn: events[i].turn,
                                        kind: .battleEnd, detail: outcome, raw: events[i].raw)
            }
            return
        }
        battleEnded = true
        outcome = how
        pendingDamage.removeAll()      // m12-B: don't finalize post-battle noise
        emit(.init(t: t, turn: turn, kind: .battleEnd, detail: how, raw: raw))
    }

    // MARK: Identity resolution

    /// Find-or-create the entity a narrated name refers to. Our side snaps to
    /// the known team; the opponent snaps to species display names, then to
    /// already-known nicknames, then becomes a new nickname entity.
    ///
    /// `canCreate: false` (effectiveness targets, damage ticks, fuzzy parses)
    /// looks up only — unknown names return nil so garbled subjects can never
    /// mint phantom entities ("Garchomp or Charizard").
    private func resolve(_ raw: String, side: String, t: Double,
                         canCreate: Bool = true) -> Entity? {
        let sided = entities.values.filter { $0.side == side }
        // 1. an existing entity (species display or nickname), wobble-tolerant
        if let snap = BattleVocabulary.snap(raw, to: sided.map(\.displayName)),
           let hit = sided.first(where: { $0.displayName == snap.value }) {
            return hit
        }
        // 1a. Truncation: a ≥6-char PREFIX of exactly one existing name is
        //     that mon ("Incinero" → Incineroar) — banners lose tails mid-fade.
        //     Fade-INS eat leading characters instead ("cineroar used Fake
        //     Out!" minted a phantom in battle 7), so a unique SUFFIX match
        //     resolves the same way; ≥6 chars keeps short real nicknames
        //     from colliding with species-name tails.
        if raw.count >= 6 {
            let lowered = raw.lowercased()
            let prefixHits = sided.filter { $0.displayName.lowercased().hasPrefix(lowered) }
            if prefixHits.count == 1 { return prefixHits[0] }
            let suffixHits = sided.filter { $0.displayName.lowercased().hasSuffix(lowered) }
            if suffixHits.count == 1 { return suffixHits[0] }
        }
        // 1b. Some narrations drop the "opposing" prefix for their side
        //     ("Archaludon drank down all the matcha…"). A bare name that
        //     is NOT ours but matches a known opponent is the opponent's.
        //     (Our team is fully seeded, so step 1 already claimed real
        //     you-side subjects — mirror matches stay ours.)
        if side == "you" {
            let opposing = entities.values.filter { $0.side == "opp" }
            if let snap = BattleVocabulary.snap(raw, to: opposing.map(\.displayName)),
               let hit = opposing.first(where: { $0.displayName == snap.value }) {
                return hit
            }
        }
        // 1c. Champions EPITHETS ride some narrations ("Garchomp of the
        //     Distant Past" — battle 8's lost send-out; 5 words would also
        //     trip the nickname guard below): strip the title and retry.
        //     No species name or plausible nickname contains " of the ".
        if let range = raw.range(of: " of the ", options: .caseInsensitive) {
            return resolve(String(raw[..<range.lowerBound]), side: side, t: t,
                           canCreate: canCreate)
        }
        guard canCreate else { return nil }
        // 2. a species display name from the closed vocabulary
        if let snap = vocabulary.snapDisplayName(raw) {
            let e = Entity(key: "\(side)|\(snap.value.lowercased())", side: side,
                           displayName: snap.value)
            e.speciesId = canonicalSpecies(forDisplay: snap.value, side: side)
            entities[e.key] = e
            if side == "opp" { bindToPreviewRow(e, t: t) }
            return e
        }
        // 3. a nickname — species unknown until a signature move or pixels
        //    say otherwise. Sentence-shaped "names" are parser junk, not
        //    nicknames: refuse to track them.
        let words = raw.split(separator: " ").count
        guard raw.count <= 20, words <= 3 else { return nil }
        let e = Entity(key: "\(side)|nick:\(raw.lowercased())", side: side, displayName: raw)
        e.isNickname = true
        entities[e.key] = e
        return e
    }

    /// Plate names are lower-stakes than narration (no sentence context), so
    /// unmatched names DON'T create entities — misreads stay quarantined.
    private func resolveForPlate(_ raw: String, side: String, t: Double) -> Entity? {
        let sided = entities.values.filter { $0.side == side }
        if let snap = BattleVocabulary.snap(raw, to: sided.map(\.displayName)) {
            return sided.first { $0.displayName == snap.value }
        }
        if side == "opp", let snap = vocabulary.snapDisplayName(raw) {
            return resolve(snap.value, side: side, t: t)   // species-named plate — trustworthy
        }
        return nil
    }

    /// Display name → canonical species. Multi-forme displays (Rotom) pick
    /// the forme: ours from the team seed, the opponent's from the bound
    /// preview row's voted type pair when available.
    private func canonicalSpecies(forDisplay display: String, side: String) -> String {
        if side == "you", let seed = yourTeam.first(where: { $0.display == display }) {
            return seed.species
        }
        let formes = vocabulary.formes(ofDisplay: display)
        guard formes.count > 1 else { return formes.first?.name ?? display }
        if side == "opp" {
            for seed in oppPreview {
                if let match = formes.first(where: { Set($0.types) == Set(seed.types) }),
                   seed.speciesTop.first.map({ $0.hasPrefix(display) }) == true {
                    return match.name
                }
            }
        }
        return formes.first { $0.name == display }?.name ?? formes[0].name  // base forme default
    }

    private func resolveNicknameIfSignature(_ e: Entity, move: String, t: Double) {
        guard e.isNickname, e.speciesId == nil,
              let species = vocabulary.signatureMoves[move] else { return }
        e.speciesId = species
        emit(.init(t: t, turn: turn, kind: .identityResolved, side: e.side,
                   subject: e.displayName, species: species,
                   detail: "signature move \(move)"))
        if e.side == "opp" { bindToPreviewRow(e, t: t) }
    }

    // MARK: Manual nickname bind (m13-D)

    /// The bind card's model: nicknamed opponents nothing has resolved,
    /// plus the preview rows no battle evidence has claimed. The opponent's
    /// team IS the six preview rows, so the unclaimed ones are the likely
    /// answers — but they stay SUGGESTIONS (a misread row can hide the
    /// truth, the P1 lesson; the full-vocab picker is the guarantee).
    nonisolated public struct NicknameBindState: Sendable {
        public let unresolved: [String]    // actives first
        public let candidates: [String]    // unclaimed preview top-1 species
    }

    /// Non-nil while any living nicknamed opponent has no species — the
    /// signal for the Battle Log's bind card.
    public func nicknameBindState() -> NicknameBindState? {
        var names: [String] = []
        for key in activeKeys["opp"]! {
            if let e = entities[key], e.isNickname, e.speciesId == nil, !e.fainted {
                names.append(e.displayName)
            }
        }
        for e in entities.values.sorted(by: { $0.displayName < $1.displayName })
            where e.side == "opp" && e.isNickname && e.speciesId == nil
                && !e.fainted && !names.contains(e.displayName) {
            names.append(e.displayName)
        }
        guard !names.isEmpty else { return nil }
        let bound = Set(entities.values.compactMap(\.previewRow))
        let candidates = oppPreview
            .filter { !bound.contains($0.row) }
            .compactMap { $0.speciesTop.first }
        return NicknameBindState(unresolved: names, candidates: candidates)
    }

    /// m13-D: the pilot's bind. Signature moves are the only AUTOMATIC
    /// nickname resolver (elimination can't conclude — the two unbrought
    /// preview rows stay unclaimed all battle), but the pilot SEES the
    /// answer on screen. `species` arrives canonical (a preview-candidate
    /// chip or the vocab picker); everything downstream — preview-row
    /// claim, capsules, matchup, dossier — flows exactly as if narration
    /// had resolved it.
    public func bindNickname(displayName: String, species: String, t: Double) {
        guard let e = entities.values.first(where: {
            $0.side == "opp" && $0.isNickname && $0.speciesId == nil
                && $0.displayName == displayName
        }) else { return }
        e.speciesId = species
        emit(.init(t: t, turn: turn, kind: .identityResolved, side: "opp",
                   subject: e.displayName, species: species,
                   detail: "pilot confirmed"))
        bindToPreviewRow(e, t: t)
    }

    /// Corroborate a resolved opponent species against the preview read:
    /// exact species match binds silently; a type-compatible row whose top
    /// vote DISAGREES binds with a correction (the D-harvest ground truth).
    /// A row sharing only ONE type still binds when it's the sole candidate —
    /// type-icon misreads (Fighting↔Ground, battle 4's Scrafty) would
    /// otherwise strand the mon unbound next to its own preview ghost.
    private func bindToPreviewRow(_ e: Entity, t: Double) {
        guard e.previewRow == nil, let species = e.speciesId, !oppPreview.isEmpty else { return }
        let bound = Set(entities.values.compactMap(\.previewRow))
        let free = oppPreview.filter { !bound.contains($0.row) }

        if let exact = free.first(where: { $0.speciesTop.first == species }) {
            e.previewRow = exact.row
            return
        }
        let display = vocabulary.species.first { $0.name == species }
        let types = Set(display?.types ?? [])
        guard !types.isEmpty else { return }

        func bind(_ row: PreviewSeed, note: String) {
            e.previewRow = row.row
            let was = row.speciesTop.first ?? "?"
            guard was != species else { return }
            corrections.append("preview row \(row.row) read “\(was)” — battle shows **\(species)** (\(note))")
            emit(.init(t: t, turn: turn, kind: .identityResolved, side: "opp",
                       subject: e.displayName, species: species,
                       detail: "corrects preview row \(row.row) “\(was)”"))
        }

        if let typeMatch = free.first(where: { Set($0.types) == types }) {
            bind(typeMatch, note: "types \(typeMatch.types.joined(separator: "/")) match")
            return
        }
        // Partial-type fallback: unambiguous single candidate only.
        let partial = free.filter { !Set($0.types).isDisjoint(with: types) }
        if partial.count == 1 {
            let row = partial[0]
            bind(row, note: "shares \(Set(row.types).intersection(types).sorted().joined(separator: "/"))"
                + " — a type slot was likely misread (\(row.types.joined(separator: "/"))"
                + " vs actual \(types.sorted().joined(separator: "/")))")
        }
    }

    private func sendOut(_ name: String, side: String, t: Double, raw: String) {
        guard let e = resolve(name, side: side, t: t), entities[e.key] != nil else { return }
        if e.fainted {
            anomalies.append("\(BattleEvent.mmss(t)) fainted \(e.displayName) narrated as sent out — misattribution?")
            return
        }
        var keys = activeKeys[side]!
        guard !keys.contains(e.key) else { return }
        e.sentOutTurn = turn
        if keys.count >= 2 {
            // We missed a withdraw/faint — evict the active least recently
            // seen on a plate.
            let evict = keys.min {
                (entities[$0]?.lastPlateSeen ?? -1) < (entities[$1]?.lastPlateSeen ?? -1)
            }!
            keys.removeAll { $0 == evict }
            anomalies.append("\(BattleEvent.mmss(t)) \(entities[evict]?.displayName ?? evict) evicted from actives without an observed exit")
        }
        keys.append(e.key)
        activeKeys[side] = keys
        emit(.init(t: t, turn: turn, kind: .sendOut, side: side,
                   subject: e.displayName, species: e.speciesId, raw: raw))
    }

    // MARK: Boosts

    private func bump(_ e: Entity, stat: String, by delta: Int) {
        func clamp(_ v: Int) -> Int { min(6, max(-6, v)) }
        switch BattleVocabulary.normalize(stat) {
        case "attack": e.boosts.atk = clamp(e.boosts.atk + delta)
        case "defense": e.boosts.def = clamp(e.boosts.def + delta)
        case "sp atk": e.boosts.spa = clamp(e.boosts.spa + delta)
        case "sp def": e.boosts.spd = clamp(e.boosts.spd + delta)
        case "speed": e.boosts.spe = clamp(e.boosts.spe + delta)
        default: break                                  // accuracy/evasion: outside the §4.5 boost block
        }
    }

    // MARK: Live-advisor snapshots (m7)

    /// Everything the live matchup calc needs about one ACTIVE mon —
    /// including observations (ability, boosts, status) that ride outside
    /// the §4.5 contract types. Engine-agnostic so diagnostics builds don't
    /// pull in JavaScriptCore.
    public struct ActiveSnapshot: Sendable {
        public let side: String            // "you" | "opp"
        public let species: String         // best-known calc name ("unknown" possible)
        public let displayName: String
        public let curPct: Double?         // 0–100, from exact or percent HP
        public let status: String?
        public let boosts: [String: Int]   // only non-zero stages
        public let revealedMoves: [String]
        public let item: String?
        public let ability: String?
        public let perishCount: Int?       // Perish Song turns left (0 = faints this turn)
        public let onFieldSinceTurn: Int    // sendOut turn; Fake Out legal iff turn <= this+1
        /// Successful Protect this turn or last (m12-D): a repeat succeeds
        /// only ~33% (streak 2: ~11%). False once a turn passes without one.
        public let protectedLastTurn: Bool
        public let protectStreak: Int      // consecutive successes behind the flag (0 when off)
        /// Choice lock (m12-E): set iff the OBSERVED item is a Choice item
        /// and a move has been committed since it last entered — the move
        /// it must repeat until it switches out.
        public let choiceLockedMove: String?
        public let hints: [String]         // m12-B inference verdicts (newest last)
    }

    /// Current actives, both sides, with observed live context.
    public func activeSnapshots() -> [ActiveSnapshot] {
        var out: [ActiveSnapshot] = []
        for side in ["you", "opp"] {
            for key in activeKeys[side]! {
                guard let e = entities[key] else { continue }
                var pct: Double?
                if let hp = e.hp {
                    if hp.kind == "exact", let c = hp.cur, let m = hp.max, m > 0 {
                        pct = Double(c) / Double(m) * 100
                    } else {
                        pct = hp.pct
                    }
                }
                var boosts: [String: Int] = [:]
                let b = e.boosts
                for (k, v) in [("atk", b.atk), ("def", b.def), ("spa", b.spa),
                               ("spd", b.spd), ("spe", b.spe)] where v != 0 {
                    boosts[k] = v
                }
                let protectedRecently = e.lastProtectTurn.map { $0 >= turn - 1 } ?? false
                let choiceLock = (e.item?.hasPrefix("Choice") == true) ? e.lastMoveUsed : nil
                out.append(ActiveSnapshot(
                    side: side, species: e.speciesId ?? "unknown",
                    displayName: e.displayName, curPct: pct, status: e.status,
                    boosts: boosts, revealedMoves: e.revealedMoves,
                    item: e.item, ability: e.ability, perishCount: e.perishCount,
                    onFieldSinceTurn: e.sentOutTurn,
                    protectedLastTurn: protectedRecently,
                    protectStreak: protectedRecently ? e.protectStreak : 0,
                    choiceLockedMove: choiceLock,
                    hints: e.hints))
            }
        }
        return out
    }

    /// m14-A: one roster row for the notepad board — everything the battle
    /// has SHOWN about a mon (no priors; the dossier window covers those).
    nonisolated public struct RosterEntry: Sendable, Identifiable {
        public let side: String
        public let species: String         // "unknown" until resolved
        public let displayName: String
        public let isActive: Bool
        public let fainted: Bool
        public let mega: Bool
        public let curPct: Double?
        public let status: String?
        public let boosts: [String: Int]   // non-zero stages only
        /// Moves seen this battle, reveal order, with use counts
        /// ("Protect ×3"); blocked-only reveals count 0.
        public let moves: [(name: String, uses: Int)]
        public let item: String?           // revealed only
        public let ability: String?        // revealed only
        public let perishCount: Int?
        public let protectedLastTurn: Bool
        public let protectStreak: Int
        public let choiceLockedMove: String?
        public let hints: [String]         // m12-B inference verdicts
        /// An unclaimed preview row — identity is the voted guess and
        /// nothing has been observed yet.
        public let previewGhost: Bool
        public var id: String { side + "|" + displayName }
    }

    /// The full known roster, both sides: actives first (field order),
    /// then revealed bench, then (opponent) the unclaimed preview rows as
    /// ghosts — the Showdown-tooltip notepad, assembled from observations
    /// the reconciler already carries.
    public func rosterSnapshots() -> [RosterEntry] {
        func entry(_ e: Entity, active: Bool) -> RosterEntry {
            var pct: Double?
            if let hp = e.hp {
                if hp.kind == "exact", let c = hp.cur, let m = hp.max, m > 0 {
                    pct = Double(c) / Double(m) * 100
                } else {
                    pct = hp.pct
                }
            }
            var boosts: [String: Int] = [:]
            let b = e.boosts
            for (k, v) in [("Atk", b.atk), ("Def", b.def), ("SpA", b.spa),
                           ("SpD", b.spd), ("Spe", b.spe)] where v != 0 {
                boosts[k] = v
            }
            let protectedRecently = e.lastProtectTurn.map { $0 >= turn - 1 } ?? false
            return RosterEntry(
                side: e.side, species: e.speciesId ?? "unknown",
                displayName: e.displayName, isActive: active, fainted: e.fainted,
                mega: e.mega, curPct: pct, status: e.status, boosts: boosts,
                moves: e.revealedMoves.map { ($0, e.moveUseCounts[$0] ?? 0) },
                item: e.item, ability: e.ability, perishCount: e.perishCount,
                protectedLastTurn: protectedRecently,
                protectStreak: protectedRecently ? e.protectStreak : 0,
                choiceLockedMove: (e.item?.hasPrefix("Choice") == true) ? e.lastMoveUsed : nil,
                hints: e.hints, previewGhost: false)
        }
        var out: [RosterEntry] = []
        for side in ["you", "opp"] {
            let activeSet = Set(activeKeys[side]!)
            for key in activeKeys[side]! {
                if let e = entities[key] { out.append(entry(e, active: true)) }
            }
            for e in entities.values
                .filter({ $0.side == side && !activeSet.contains($0.key) })
                .sorted(by: { $0.displayName < $1.displayName }) {
                out.append(entry(e, active: false))
            }
            if side == "opp" {
                let bound = Set(entities.values.compactMap(\.previewRow))
                for seed in oppPreview.sorted(by: { $0.row < $1.row })
                    where !bound.contains(seed.row) {
                    let guess = seed.speciesTop.first ?? "unknown"
                    out.append(RosterEntry(
                        side: "opp", species: guess, displayName: guess,
                        isActive: false, fainted: false, mega: false,
                        curPct: nil, status: nil, boosts: [:], moves: [],
                        item: nil, ability: nil, perishCount: nil,
                        protectedLastTurn: false, protectStreak: 0,
                        choiceLockedMove: nil, hints: [], previewGhost: true))
                }
            }
        }
        return out
    }

    /// The live field, engine-shaped (weather/TR/tailwind/screens).
    public func liveFieldSpec() -> LiveFieldSpec {
        LiveFieldSpec(
            weather: weather.kind == "none" ? nil : weather.kind,
            trickRoom: field.trickRoom == true,
            tailwindYou: field.tailwind.you == true,
            tailwindOpp: field.tailwind.opp == true,
            screensYou: field.screens?.you ?? [],
            screensOpp: field.screens?.opp ?? [])
    }

    // MARK: State rendering

    private var weather = BattleState.Weather()
    private var field = BattleState.Field()

    public var state: BattleState {
        func pokemonState(_ e: Entity) -> PokemonState {
            PokemonState(speciesId: e.speciesId ?? "unknown",
                         displayName: e.isNickname ? e.displayName : nil,
                         hp: e.hp, status: e.status, boosts: e.boosts,
                         revealedMoves: e.revealedMoves, item: e.item,
                         megaEvolved: e.mega ? true : nil)
        }
        func side(_ name: String) -> BattleState.Side {
            let active = activeKeys[name]!.compactMap { entities[$0] }.map(pokemonState)
            var bench = entities.values
                .filter { $0.side == name && !activeKeys[name]!.contains($0.key) }
                .sorted { $0.displayName < $1.displayName }
                .map(pokemonState)
            if name == "opp" {
                // preview-seeded rows nothing has claimed yet — best-guess identities
                let bound = Set(entities.values.compactMap(\.previewRow))
                for seed in oppPreview where !bound.contains(seed.row) {
                    bench.append(PokemonState(speciesId: seed.speciesTop.first ?? "unknown"))
                }
            }
            return BattleState.Side(active: active, bench: bench)
        }
        return BattleState(turn: turn, weather: weather, field: field,
                           yourSide: side("you"), oppSide: side("opp"))
    }

    private func emit(_ event: BattleEvent) { events.append(event) }
}

// MARK: - Human-readable battle log

nonisolated extension BattleReconciler {

    /// The paper-replay deliverable: a chronological, eyeball-checkable
    /// battle log with the final reconciled state and every correction /
    /// anomaly the legality filter produced.
    public func renderLog(title: String) -> String {
        var md = "# Battle log — \(title)\n\n"
        if let opponentTrainer { md += "- opponent: **\(opponentTrainer)**\n" }
        md += "- your team: \(yourTeam.map(\.species).joined(separator: ", "))\n"
        if let outcome { md += "- outcome: **\(outcome.uppercased())** (turn \(turn))\n" }
        md += "\n## Timeline\n\n"

        for e in events {
            let line = e.kind == .turnStart ? "\n**\(e.displayLine)**" : e.displayLine
            md += "`\(BattleEvent.mmss(e.t))` \(line)\n"
        }

        md += "\n## Final state\n\n"
        let final = state
        md += "- turn \(final.turn) · weather \(final.weather.kind)"
        if let left = final.weather.turnsLeft { md += " (\(left) left)" }
        if final.field.trickRoom == true { md += " · Trick Room" }
        md += "\n"
        for (label, side) in [("You", final.yourSide), ("Opponent", final.oppSide)] {
            md += "\n### \(label)\n\n"
            for (group, mons) in [("active", side.active), ("bench", side.bench)] where !mons.isEmpty {
                for m in mons {
                    var bits: [String] = []
                    if let hp = m.hp { bits.append(hp.display) }
                    if m.hp?.isFainted == true { bits.append("FNT") }
                    if let s = m.status { bits.append(s) }
                    if !m.boosts.isNeutral { bits.append(m.boosts.display) }
                    if let i = m.item { bits.append("@ \(i)") }
                    if m.megaEvolved == true { bits.append("mega") }
                    if !m.revealedMoves.isEmpty { bits.append("moves: \(m.revealedMoves.joined(separator: ", "))") }
                    md += "- \(group == "active" ? "▶︎" : "·") **\(m.describeName)** — \(bits.isEmpty ? "nothing observed" : bits.joined(separator: " · "))\n"
                }
            }
        }

        if !corrections.isEmpty {
            md += "\n## Preview corrections (battle corroboration)\n\n"
            for c in corrections { md += "- \(c)\n" }
        }
        if !anomalies.isEmpty {
            md += "\n## Anomalies (discarded / suspicious reads)\n\n"
            for a in anomalies.prefix(30) { md += "- \(a)\n" }
        }
        let unparsed = events.filter { $0.kind == .note && $0.detail == nil }
        if !unparsed.isEmpty {
            md += "\n## Unrecognized banners (template gaps to close)\n\n"
            for e in unparsed { md += "- `\(BattleEvent.mmss(e.t))` \(e.raw ?? "")\n" }
        }
        return md
    }
}
