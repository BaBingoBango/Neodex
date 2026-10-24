//
//  BattleEventParser.swift
//  Scope Lens
//
//  Phase 2, milestone 4: per-frame extraction of battle observations from the
//  classifier's tokens. Pure and stateless — one frame in, structured reads
//  out; the reconciler owns time (dedup, legality, state mutation).
//
//  Every template here was derived from REAL narration banners in the three
//  recorded battles (see Tools/ScopeLensDiagnostics/README.md m4 notes) — not from mainline
//  Pokémon lore. Wobble tolerance lives in the vocabulary snap, not in the
//  templates: structure is matched loosely ("fainte[dr]", optional prefixes),
//  names/moves are snapped to the closed vocab afterwards.
//
//  Sides: the opponent's mons are always narrated with a "The opposing …"
//  prefix; ours are bare names ("Rotom used Thunderbolt!"). Activation chips
//  render at a left anchor for our procs and a right anchor (variable y) for
//  the opponent's — both are detected here by stacked-possessive geometry,
//  independent of the classifier's overlay flag.
//

import Foundation
import CoreGraphics

// MARK: - Observation model

nonisolated public struct FrameObservation: Sendable {
    public struct ChipRead: Sendable {
        public let subjectRaw: String      // "Incineroar" (possessive stripped)
        public let thingRaw: String        // "Intimidate" | "Sitrus Berry" | …
        public let sideHint: String        // "you" (left anchor) | "opp" (right anchor)
    }
    public struct HPRead: Sendable {
        public let nameRaw: String
        public let side: String            // "you" (exact) | "opp" (percent)
        public let hp: PokemonState.HP
        public let bench: Bool             // read from the switchSelect party list
    }
    public struct FieldStatusRead: Sendable {
        public let name: String            // "Harsh Sunlight", "Rain", "Trick Room", …
        public let remaining: Int
        public let total: Int
    }
    /// The browsable summary panel's LEFT card (m9-C): one mon's exact
    /// sheet — name, exact HP, type badges, ability, item, and ABSOLUTE
    /// stat stages decoded from the ×multiplier column. Observations beat
    /// priors: these reads re-sync the reconciler for ANY mon the user
    /// browses to, benched ones included.
    public struct SummaryRead: Sendable {
        public let nameRaw: String         // plate text — resolution is the reconciler's job
        public let hp: PokemonState.HP?    // exact fraction when shown (ours are)
        public let types: [String]         // badge tokens, canonical caps ("Grass")
        public let ability: String?        // vocab-snapped
        public let item: String?           // vocab-snapped
        public let stages: [String: Int]   // atk/def/spa/spd/spe — ABSOLUTE stages
    }

    public let t: Double
    public let primary: ScreenState
    public let confidence: Double
    public let banner: String?
    public let chips: [ChipRead]
    public let hpReads: [HPRead]
    public let fieldStatuses: [FieldStatusRead]
    public let summary: SummaryRead?
    public let resultOutcome: String?      // "won" | "lost" when the result splash is up
}

// MARK: - Parser

nonisolated public struct BattleEventParser {

    public let vocabulary: BattleVocabulary

    public init(vocabulary: BattleVocabulary) {
        self.vocabulary = vocabulary
    }

    /// States over which battle UI elements (banner, chips, HUD plates) can
    /// legitimately appear. teamPreview is excluded: its species/item rows
    /// share the chip geometry (earned classifier lesson).
    private static let battleFrameStates: Set<ScreenState> = [
        .command, .moveSelect, .targetSelect, .switchSelect,
        .communicating, .narration, .unknown,
    ]
    private static let chipStates: Set<ScreenState> = [
        .narration, .command, .communicating, .unknown,
    ]

    public func observe(tokens: [OCRToken], classification: ScreenStateClassification,
                        t: Double) -> FrameObservation {
        let primary = classification.primary
        let inBattle = Self.battleFrameStates.contains(primary)

        return FrameObservation(
            t: t,
            primary: primary,
            confidence: classification.confidence,
            banner: bannerText(tokens: tokens, primary: primary),
            chips: Self.chipStates.contains(primary) ? chipReads(tokens: tokens) : [],
            hpReads: inBattle ? hpReads(tokens: tokens, primary: primary) : [],
            fieldStatuses: fieldStatusReads(tokens: tokens),
            // teamPreview excluded: its own summary panel shares header text
            // but shows stat VALUES, not ×multipliers — the stage column gate
            // would reject it anyway; the state gate makes it structural.
            summary: primary == .teamPreview ? nil : summaryRead(tokens: tokens),
            resultOutcome: primary == .result ? resultOutcome(tokens: tokens) : nil
        )
    }

    // MARK: Banner

    /// The narration banner: widest confident token in the banner band, plus
    /// any non-overlapping continuation tokens (Vision occasionally re-reads a
    /// fragment of the same line — overlapping duplicates are dropped).
    private func bannerText(tokens: [OCRToken], primary: ScreenState) -> String? {
        // Narration frames always; unknown frames only when sparse (dense
        // menus drop stray tokens into the band — same lesson as the
        // classifier's ≤14-token narration gate).
        guard primary == .narration || (primary == .unknown && tokens.count <= 14) else { return nil }
        let band = tokens.filter {
            $0.confidence >= 0.5 && $0.size.width >= 0.04
                && $0.inRegion(x: 0.22...0.68, y: 0.66...0.76)
        }
        guard let widest = band.max(by: { $0.size.width < $1.size.width }) else { return nil }
        var parts = [widest]
        for t in band where t.text != widest.text {
            let overlaps = parts.contains { existing in
                let a = existing.center.x - existing.size.width / 2 ... existing.center.x + existing.size.width / 2
                let lo = t.center.x - t.size.width / 2, hi = t.center.x + t.size.width / 2
                return a.overlaps(lo...hi) && min(a.upperBound, hi) - max(a.lowerBound, lo) > 0.3 * t.size.width
            }
            if !overlaps { parts.append(t) }
        }
        let text = parts.sorted { $0.center.x < $1.center.x }.map(\.text).joined(separator: " ")
        // Trim leading OCR artifacts (bullets, stars) but keep the raw casing.
        return text.trimmingCharacters(in: CharacterSet(charactersIn: "•*· ")).nilIfEmpty
    }

    // MARK: Chips

    /// Activation chips: two stacked short tokens, x-aligned, top one a
    /// possessive ("Staraptor's" / "Incineroar's"). Left anchor = our proc;
    /// right anchor = opponent's (y varies with their plate, so the band is
    /// tall). Ability vs item is NOT decided here — that's vocabulary work.
    private func chipReads(tokens: [OCRToken]) -> [FrameObservation.ChipRead] {
        var reads: [FrameObservation.ChipRead] = []
        for (xBand, side) in [(0.06...0.30, "you"), (0.74...0.96, "opp")] {
            let zone = tokens.filter {
                $0.confidence >= 0.5 && $0.size.width <= 0.18
                    && $0.inRegion(x: CGFloat(xBand.lowerBound)...CGFloat(xBand.upperBound), y: 0.28...0.66)
            }
            for top in zone where top.text.hasSuffix("'s") || top.text.hasSuffix("’s") {
                for bottom in zone where bottom.text != top.text {
                    let dy = bottom.center.y - top.center.y
                    guard dy >= 0.02, dy <= 0.09, abs(top.center.x - bottom.center.x) <= 0.07 else { continue }
                    let subject = String(top.text.dropLast(2))
                    reads.append(.init(subjectRaw: subject, thingRaw: bottom.text, sideHint: side))
                }
            }
        }
        return reads
    }

    // MARK: HP plates

    /// In-battle HUD plates. Ours: name ~y0.87 over an exact fraction ~y0.94,
    /// bottom-left half. Opponent's: name ~y0.07 over a percent ~y0.14,
    /// top-right. Names pair with the nearest readout by x — attribution by
    /// name, never by slot position. switchSelect adds our party list (exact
    /// fractions down the left column).
    private func hpReads(tokens: [OCRToken], primary: ScreenState) -> [FrameObservation.HPRead] {
        var reads: [FrameObservation.HPRead] = []

        func pair(names: [OCRToken], readouts: [(OCRToken, PokemonState.HP)],
                  maxDX: CGFloat, maxDY: CGFloat, side: String, bench: Bool) {
            for (readout, hp) in readouts {
                let name = names
                    .filter { abs($0.center.x - readout.center.x) <= maxDX
                        && readout.center.y - $0.center.y > 0.01
                        && readout.center.y - $0.center.y <= maxDY }
                    .min { abs($0.center.x - readout.center.x) < abs($1.center.x - readout.center.x) }
                guard let name else { continue }
                reads.append(.init(nameRaw: name.text, side: side, hp: hp, bench: bench))
            }
        }

        // Our active plates (all battle frames).
        let ourNames = tokens.filter {
            $0.confidence >= 0.5 && $0.inRegion(x: 0.08...0.48, y: 0.84...0.905) && $0.size.width <= 0.12
        }
        let ourHP = tokens
            .filter { $0.inRegion(x: 0.08...0.48, y: 0.905...0.975) }
            .compactMap { t in Self.exactHP(t.text).map { (t, $0) } }
        pair(names: ourNames, readouts: ourHP, maxDX: 0.09, maxDY: 0.09, side: "you", bench: false)

        // Opponent plates.
        let oppNames = tokens.filter {
            $0.confidence >= 0.5 && $0.inRegion(x: 0.58...0.95, y: 0.03...0.105) && $0.size.width <= 0.13
        }
        let oppHP = tokens
            .filter { $0.inRegion(x: 0.58...0.95, y: 0.105...0.175) }
            .compactMap { t in Self.percentHP(t.text).map { (t, $0) } }
        pair(names: oppNames, readouts: oppHP, maxDX: 0.10, maxDY: 0.09, side: "opp", bench: false)

        // Our party list on switchSelect: exact fractions in the left column.
        if primary == .switchSelect {
            let partyNames = tokens.filter {
                $0.confidence >= 0.5 && $0.inRegion(x: 0.06...0.34, y: 0.10...0.78) && $0.size.width <= 0.14
                    && Self.exactHP($0.text) == nil
            }
            let partyHP = tokens
                .filter { $0.inRegion(x: 0.06...0.34, y: 0.10...0.80) }
                .compactMap { t in Self.exactHP(t.text).map { (t, $0) } }
            pair(names: partyNames, readouts: partyHP, maxDX: 0.12, maxDY: 0.07, side: "you", bench: true)
        }

        return reads
    }

    /// "154/154", "91 /156", and the slash-misread forms "1447154"/"1791202"
    /// (odd all-digit run whose middle digit OCR'd from the slash — spec §7).
    static func exactHP(_ raw: String) -> PokemonState.HP? {
        let s = raw.replacingOccurrences(of: " ", with: "")
        if let slash = s.firstIndex(of: "/") {
            let cur = s[s.startIndex..<slash], max = s[s.index(after: slash)...]
            guard !cur.isEmpty, !max.isEmpty, cur.count <= 4, max.count <= 4,
                  cur.allSatisfy(\.isNumber), max.allSatisfy(\.isNumber),
                  let c = Int(cur), let m = Int(max), m > 0, c <= m else { return nil }
            return .exact(c, m)
        }
        guard s.count >= 5, s.count <= 9, s.count % 2 == 1, s.allSatisfy(\.isNumber) else { return nil }
        let midIndex = s.index(s.startIndex, offsetBy: s.count / 2)
        guard s[midIndex] == "7" || s[midIndex] == "1" else { return nil }
        guard let c = Int(s[s.startIndex..<midIndex]), let m = Int(s[s.index(after: midIndex)...]),
              m > 0, c <= m else { return nil }
        return .exact(c, m)
    }

    static func percentHP(_ raw: String) -> PokemonState.HP? {
        guard raw.contains("%") else { return nil }
        let digits = raw.replacingOccurrences(of: " ", with: "").prefix(while: \.isNumber)
        guard let v = Int(digits), v >= 0, v <= 100 else { return nil }
        return .percent(Double(v))
    }

    // MARK: Summary-panel field statuses

    /// The user-opened summary panel lists "Active Statuses & Effects" with
    /// exact remaining/total counters ("Harsh Sunlight 4/5", "Rain 1/5") —
    /// a free re-sync for the weather timer. Only global effects are
    /// consumed; side-scoped rows (screens, Tailwind) are left to events.
    private func fieldStatusReads(tokens: [OCRToken]) -> [FrameObservation.FieldStatusRead] {
        guard tokens.contains(where: {
            $0.fuzzyContains("active statuses") && $0.center.y < 0.30
        }) else { return [] }
        let globals = ["Harsh Sunlight", "Rain", "Sandstorm", "Snow", "Hail", "Trick Room"]
        var reads: [FrameObservation.FieldStatusRead] = []
        for name in tokens where name.inRegion(x: 0.48...0.74, y: 0.26...0.86) {
            guard let matched = globals.first(where: {
                BattleVocabulary.normalize(name.text) == BattleVocabulary.normalize($0)
            }) else { continue }
            let counter = tokens.first {
                $0.inRegion(x: 0.72...0.84, y: (name.center.y - 0.025)...(name.center.y + 0.025))
                    && $0.text.range(of: #"^\d{1,2}/\d{1,2}$"#, options: .regularExpression) != nil
            }
            guard let counter else { continue }
            let parts = counter.text.split(separator: "/").compactMap { Int($0) }
            guard parts.count == 2 else { continue }
            reads.append(.init(name: matched, remaining: parts[0], total: parts[1]))
        }
        return reads
    }

    // MARK: Summary-panel mon card (m9-C)

    /// Geometry from battle-1 harvest keyframes 104/124 (the LOOK reference):
    /// name plate x∈[0.22,0.37] y∈[0.185,0.25]; exact HP right of the bar
    /// y∈[0.24,0.30]; type badges y∈[0.30,0.36]; "Ability <value>" row
    /// y∈[0.35,0.42]; item row (icon + name, no label) y∈[0.42,0.48];
    /// stat rows Attack→Speed y∈[0.46,0.75] with ×multipliers x∈[0.37,0.46].
    /// The stage column (≥2 decoded rows) is the panel's structural
    /// signature — narration/menus never produce it.
    private func summaryRead(tokens: [OCRToken]) -> FrameObservation.SummaryRead? {
        guard tokens.contains(where: {
            $0.fuzzyContains("active statuses") && $0.center.y < 0.30
        }) else { return nil }

        // Stat stages from the ×multiplier column (the decisive gate).
        var stages: [String: Int] = [:]
        let statRows: [(label: String, key: String)] = [
            ("attack", "atk"), ("defense", "def"), ("sp atk", "spa"),
            ("sp def", "spd"), ("speed", "spe"),
        ]
        for row in statRows {
            guard let label = tokens.first(where: {
                $0.inRegion(x: 0.14...0.28, y: 0.45...0.76)
                    && BattleVocabulary.normalize($0.text) == BattleVocabulary.normalize(row.label)
            }) else { continue }
            guard let mult = tokens.first(where: {
                $0.inRegion(x: 0.36...0.47,
                            y: (label.center.y - 0.02)...(label.center.y + 0.02))
                    && $0.text.range(of: #"^[x×X*]?\s?\d(\.\d)?$"#,
                                     options: .regularExpression) != nil
            }) else { continue }
            let numeric = mult.text.drop(while: { !$0.isNumber })
            if let value = Double(numeric), let stage = Self.stage(forMultiplier: value) {
                stages[row.key] = stage
            }
        }
        guard stages.count >= 2 else { return nil }

        // Identity: the name-plate token. Resolution (display / species /
        // garble) is the reconciler's doctrine, not ours.
        guard let name = tokens
            .filter({ $0.inRegion(x: 0.20...0.38, y: 0.18...0.25)
                && $0.confidence >= 0.5 && $0.text.count >= 3 })
            .max(by: { $0.size.height < $1.size.height }) else { return nil }

        let hp = tokens
            .filter { $0.inRegion(x: 0.32...0.46, y: 0.235...0.305) }
            .compactMap { Self.exactHP($0.text) }
            .first

        let typeNames = ["Normal", "Fire", "Water", "Electric", "Grass", "Ice",
                         "Fighting", "Poison", "Ground", "Flying", "Psychic",
                         "Bug", "Rock", "Ghost", "Dragon", "Dark", "Steel", "Fairy"]
        let types = tokens
            .filter { $0.inRegion(x: 0.24...0.46, y: 0.295...0.365) }
            .compactMap { tok in typeNames.first {
                BattleVocabulary.normalize(tok.text) == BattleVocabulary.normalize($0)
            } }

        var ability: String?
        if let label = tokens.first(where: {
            $0.inRegion(x: 0.23...0.33, y: 0.35...0.425)
                && BattleVocabulary.normalize($0.text) == "ability"
        }) {
            ability = tokens
                .filter { $0.inRegion(x: 0.32...0.47,
                                      y: (label.center.y - 0.02)...(label.center.y + 0.02)) }
                .compactMap { vocabulary.snapAbility($0.text) }
                .min(by: { $0.edits < $1.edits })
                .flatMap { $0.edits <= 2 ? $0.value : nil }
        }

        let item = tokens
            .filter { $0.inRegion(x: 0.27...0.47, y: 0.42...0.48) }
            .compactMap { vocabulary.snapItem($0.text) }
            .min(by: { $0.edits < $1.edits })
            .flatMap { $0.edits <= 2 ? $0.value : nil }

        return FrameObservation.SummaryRead(
            nameRaw: name.text.trimmingCharacters(in: .whitespaces),
            hp: hp, types: types, ability: ability, item: item, stages: stages)
    }

    /// Panel multiplier → stage: (2+s)/2 above neutral, 2/(2−s) below, as
    /// rendered to one decimal. −4 and −5 both display ×0.3 — mapped to −4
    /// (no engine decision changes at that depth); ×0.25 (if ever rendered
    /// two-decimal) is −6.
    static func stage(forMultiplier m: Double) -> Int? {
        let table: [(mult: Double, stage: Int)] = [
            (4.0, 6), (3.5, 5), (3.0, 4), (2.5, 3), (2.0, 2), (1.5, 1), (1.0, 0),
            (0.7, -1), (0.5, -2), (0.4, -3), (0.3, -4), (0.25, -6),
        ]
        return table.first(where: { abs($0.mult - m) < 0.06 })?.stage
    }

    // MARK: Result splash

    private func resultOutcome(tokens: [OCRToken]) -> String? {
        // Giant WON/LOST; your side is the LEFT half (verified in a win and a
        // loss). OCR renders the stylized text as "WOND" / "LOST...".
        for t in tokens where t.size.height >= 0.10 && t.center.x < 0.55 {
            let n = t.normalized
            if n.contains("won") { return "won" }
            if n.contains("lost") { return "lost" }
        }
        return nil
    }
}

// MARK: - Banner grammar

/// One parsed banner: a template hit with its extracted, vocab-snapped slots.
/// `subjects` keep narration order; `side` is nil for field-wide lines.
nonisolated public struct BannerParse: Sendable {
    public enum Template: String, Sendable {
        case sendOutOpp, sendOutYou, withdrawOpp, withdrawYou
        case moveUsed, moveBlocked, protected, fainted, effectiveness
        case statChange, statusInflicted, statusTick, statusCleared
        case statsRestored       // White Herb: negative stages clear (battle 9)
        case drained, recoil, healedByItem, itemHungOn, chargingTurn
        case megaStoneReacting, megaEvolved
        case weatherStart, weatherEnd
        case screenUp, screenDown, trickRoomStart, trickRoomEnd, tailwindStart, tailwindEnd
        case resultLine, forfeit
        case missedOrAvoided
        case noteworthy          // recognized flavor worth a labeled note (crit, ability flare)
        case perishSong          // "All Pokémon that heard the song will faint in three turns!"
        case perishCount         // "<Subj>'s perish count fell to N!"
        case unrecognized
    }

    public let template: Template
    public let side: String?               // "you" | "opp" | nil
    public let subjects: [String]          // raw names as narrated
    public let detail: String?             // move / stat list / weather kind / item / screen
    public let magnitude: Int?             // stat stages (±1..3), effectiveness class
    public let trainer: String?            // opp trainer name when narrated
    public let fuzzy: Bool                 // matched via a degraded-text fallback —
                                           // subjects may only LOOK UP entities, never create
    public let raw: String

    /// Dedup key: wobbled re-reads of one banner parse to the same structure.
    public var semanticKey: String {
        "\(template.rawValue)|\(side ?? "")|\(subjects.joined(separator: ","))|\(detail ?? "")|\(magnitude.map(String.init) ?? "")"
    }
}

nonisolated extension BattleEventParser {

    /// Closed-vocab move resolution with truncation tolerance: the fuzzy
    /// snap first (≤1–2 edits by length), then a unique ≥5-char PREFIX of
    /// exactly one move ("Prote" → Protect — the m8/m11-B subject rules,
    /// applied to the move slot). nil = garble ("Roda"): the caller rejects
    /// the parse rather than minting a phantom move (battle 9).
    private func resolveMove(_ raw: String) -> String? {
        if let snap = vocabulary.snapMove(raw) { return snap.value }
        let needle = BattleVocabulary.normalize(raw)
        guard needle.count >= 5 else { return nil }
        let hits = vocabulary.moves.filter {
            BattleVocabulary.normalize($0).hasPrefix(needle)
        }
        return hits.count == 1 ? hits[0] : nil
    }

    /// Parse one deduplicated banner line into a structured event candidate.
    /// Returns `.unrecognized` (never nil) — unparsed real text must stay
    /// visible downstream, not silently vanish.
    public func parseBanner(_ raw: String) -> BannerParse {
        let text = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
        func p(_ template: BannerParse.Template, side: String? = nil, subjects: [String] = [],
               detail: String? = nil, magnitude: Int? = nil, trainer: String? = nil,
               fuzzy: Bool = false) -> BannerParse {
            BannerParse(template: template, side: side, subjects: subjects, detail: detail,
                        magnitude: magnitude, trainer: trainer, fuzzy: fuzzy, raw: raw)
        }

        // -- subject helpers ------------------------------------------------
        // "The opposing X and the opposing Y" / "X and Y" / "X" (OCR may drop
        // leading letters: "he opposing …").
        func subjects(_ phrase: String) -> (names: [String], side: String) {
            var side = "you"
            let names = phrase
                .components(separatedBy: " and ")
                .map { part -> String in
                    var s = part.trimmingCharacters(in: .whitespaces)
                    // Any short mangled residue of "The" before "opposing"
                    // still means OPPONENT ("le opposing Raichu" minted a
                    // you-side phantom in battle 8) — "opposing" is the
                    // load-bearing word; no real subject ever contains it.
                    // Fade-ins also clip the marker WORD itself ("pposing
                    // ArLodecad", battle 9): any ≥5-char SUFFIX of
                    // "opposing" carries the same meaning.
                    if let r = s.range(of: #"^(?:[a-z']{0,4}\s+)?(?:opposing|pposing|posing|osing)\s+"#,
                                       options: [.regularExpression, .caseInsensitive]) {
                        side = "opp"
                        s.removeSubrange(r)
                    }
                    if s.hasSuffix("'s") { s = String(s.dropLast(2)) }
                    return s.trimmingCharacters(in: .whitespaces)
                }
                .filter { !$0.isEmpty }
            return (names, side)
        }

        func match(_ pattern: String) -> [String]? {
            guard let regex = try? NSRegularExpression(pattern: pattern,
                                                       options: [.caseInsensitive]) else { return nil }
            let range = NSRange(text.startIndex..., in: text)
            guard let m = regex.firstMatch(in: text, range: range) else { return nil }
            return (1..<m.numberOfRanges).map {
                guard let r = Range(m.range(at: $0), in: text) else { return "" }
                return String(text[r])
            }
        }

        // -- field-wide fixed lines (checked before subject templates) ------
        // Cores are matched contains-style: mid-fade reads drop leading words
        // ("sunlight turned harsh" without "The") and single characters
        // wobble — whole-line equality missed real reads in battle 4.
        let normalized = BattleVocabulary.normalize(text)
        let weatherEnds: [(String, String)] = [
            ("sunlight faded", "sun"), ("rain stopped", "rain"),
            ("sandstorm subsided", "sand"), ("snow stopped", "snow"),
            ("hail stopped", "snow"),
        ]
        let weatherStarts: [(String, String)] = [
            ("sunlight turned harsh", "sun"), ("started to rain", "rain"),
            ("sandstorm kicked up", "sand"), ("started to snow", "snow"),
            ("started to hail", "snow"),
        ]
        for (core, kind) in weatherEnds where normalized.fuzzilyContains(core, maxEdits: 1) {
            return p(.weatherEnd, detail: kind)
        }
        for (core, kind) in weatherStarts where normalized.fuzzilyContains(core, maxEdits: 1) {
            return p(.weatherStart, detail: kind)
        }
        // TR end before TR start: both mention "dimensions" ("The wwisted
        // dimensions-retuined to notge" is a real battle-4 read).
        if normalized.fuzzilyContains("dimensions returned", maxEdits: 2)
            || fuzzyEqual(normalized, "the twisted dimensions returned to normal") {
            return p(.trickRoomEnd)
        }
        if normalized.contains("twisted the dimensions") {
            let subj = subjects(String(text.prefix(upTo: text.range(
                of: " twisted", options: .caseInsensitive)?.lowerBound ?? text.endIndex)))
            return p(.trickRoomStart, side: subj.side, subjects: subj.names)
        }
        if normalized.contains("tailwind blew from behind") {
            return p(.tailwindStart, side: normalized.contains("opposing") ? "opp" : "you")
        }
        if normalized.contains("tailwind petered out") {
            return p(.tailwindEnd, side: normalized.contains("opposing") ? "opp" : "you")
        }
        if let g = match(#"^(Light Screen|Reflect|Aurora Veil) made (the '?opposing side|your team) stronger"#) {
            return p(.screenUp, side: g[1].lowercased().contains("opposing") ? "opp" : "you", detail: g[0])
        }
        // Wide/Quick Guard: side-wide protection (set + per-hit block
        // messages; Quick Guard = battle 9, blocking Fake Out). The set
        // message names a SIDE (often truncated: "…the opposing sid");
        // only the per-hit block names a mon.
        if let g = match(#"^(Wide Guard|Quick Guard) (?:now )?protect(?:s|ed) (.+?)[!.]?$"#) {
            let side = normalized.contains("opposing") ? "opp" : "you"
            let s = subjects(g[1])
            let sideWords: Set<String> = ["side", "sid", "team", "tea"]
            let named = s.names.filter { !sideWords.contains($0.lowercased()) }
            return p(.protected, side: side, subjects: named, detail: g[0].capitalized)
        }
        if let g = match(#"^(The opposing side's|Your team's) (Light Screen|Reflect|Aurora Veil) wore off"#) {
            return p(.screenDown, side: g[0].lowercased().contains("opposing") ? "opp" : "you", detail: g[1])
        }
        // Wobbled screen-up fallback ("Aurora Yeilmade the opposing side
        // strongoragainst…" is a real battle-4 read).
        for screen in ["Aurora Veil", "Light Screen", "Reflect"] {
            if normalized.fuzzilyContains(screen.lowercased(), maxEdits: 2),
               normalized.fuzzilyContains("stronger", maxEdits: 2) {
                return p(.screenUp, side: normalized.contains("opposing") ? "opp" : "you",
                         detail: screen, fuzzy: true)
            }
        }
        if normalized.contains("ended due to a forfeit") { return p(.forfeit) }
        if let g = match(#"^You lost to (.+?)[!.]?$"#) {
            return p(.resultLine, detail: "lost", trainer: g[0])
        }
        if let g = match(#"^You defeated (.+?)[!.]?$"#) {
            return p(.resultLine, detail: "won", trainer: g[0])
        }

        // -- switching -------------------------------------------------------
        // Optional space: a fade can glue the trainer name to the verb
        // ("IDontPlayVGCsent out Garchomp…" — battle 8's lost send-out).
        if let g = match(#"^(.+?) ?sent out (.+?)[!.]?$"#) {
            let s = subjects(g[1])
            return p(.sendOutOpp, side: "opp", subjects: s.names, trainer: g[0])
        }
        // Fade-in can eat the trainer name entirely ("sent out Armarouge and
        // Scrafty!" — battle 4); still an opponent send-out.
        if let g = match(#"^sent out (.+?)[!.]?$"#) {
            return p(.sendOutOpp, side: "opp", subjects: subjects(g[0]).names)
        }
        if let g = match(#"^Go[!l1.]? (.+?)[!.]?$"#) {   // "Go!" OCRs as "Gol"/"Go1" mid-fade
            return p(.sendOutYou, side: "you", subjects: subjects(g[0]).names)
        }
        if let g = match(#"^(.+?) withdrew (.+?)[!.]?$"#) {
            return p(.withdrawOpp, side: "opp", subjects: subjects(g[1]).names, trainer: g[0])
        }
        if let g = match(#"^(.+?), come back"#) {   // tail is OCR-junk-prone ("backl", trailing quote)
            return p(.withdrawYou, side: "you", subjects: subjects(g[0]).names)
        }
        // Opponent recall variant: "The opposing X went back to <trainer>!"
        if let g = match(#"^(.+?) went back to"#) {
            let s = subjects(g[0])
            return p(.withdrawOpp, side: "opp", subjects: s.names)
        }

        // -- mega ------------------------------------------------------------
        // "reacting to" wobbles ("reacting fo" is a real battle-4 read).
        if let g = match(#"^(.+?)'s (.+?) is reacting [tf]o (.+?)'s"#) {
            let s = subjects(g[0])
            let item = vocabulary.snapItem(g[1])?.value ?? g[1]
            return p(.megaStoneReacting, side: s.side, subjects: s.names, detail: item)
        }
        if let g = match(#"^(.+?) has[ ,.]+Mega Evolved into (?:a |an )?Mega (.+?)[!.]?$"#) {
            let s = subjects(g[0])
            return p(.megaEvolved, side: s.side, subjects: s.names, detail: "Mega " + g[1])
        }

        // -- Perish Song (battle 5: Mega Gengar's doom clock) ----------------
        if normalized.fuzzilyContains("will faint in three turns", maxEdits: 2) {
            return p(.perishSong)
        }
        // Count wobbles: zero reads as "O"; the count is REQUIRED (a truncated
        // "count-fel" read must never default to 0 — that means "dies now").
        if let g = match(#"^(.+?)'s perish count[- ]fell to ([0-9O])[!.]?$"#) {
            let s = subjects(g[0])
            let n = g[1].uppercased() == "O" ? 0 : Int(g[1]) ?? 3
            return p(.perishCount, side: s.side, subjects: s.names, magnitude: n)
        }

        // -- moves & protection ----------------------------------------------
        // Blocked move (battle 7: Farigiraf's Armor Tail stopped Fake Out —
        // "Incineroar cannot use Fake Out!"). The attempt still PROVES the
        // mon carries the move; the block itself is the tactical signal.
        // Both move templates REQUIRE the move to resolve in the closed
        // vocabulary (battle 9: the old `?? raw` fallback let "Roda" and
        // "Prote" ride through as moves — a phantom entity and a polluted
        // revealedMoves list); unresolvable garble falls through to the
        // unrecognized note and a cleaner re-read parses moments later.
        if let g = match(#"^(.+?) cannot use (.+?)[!.]?$"#), let move = resolveMove(g[1]) {
            let s = subjects(g[0])
            return p(.moveBlocked, side: s.side, subjects: s.names, detail: move)
        }
        // " used " wobbles to "used." (battle 5's "used.Rage Powder").
        if let g = match(#"^(.+?) used[ .](.+?)[!.]?$"#), let move = resolveMove(g[1]) {
            let s = subjects(g[0])
            return p(.moveUsed, side: s.side, subjects: s.names, detail: move)
        }
        // White Herb (battle 9): the stat-drop cure. Missing it left a
        // stale Atk-1 on the herb's user — wrong matchup math AND a
        // damage inference computed "(at Atk-1)" on a restored attacker.
        if normalized.fuzzilyContains("returned its stats to normal", maxEdits: 2),
           let g = match(#"^(.+?) returned its stats"#) {
            let s = subjects(g[0])
            return p(.statsRestored, side: s.side, subjects: s.names, detail: "White Herb")
        }
        if let g = match(#"^(.+?) protected itself[!.]?$"#) {
            let s = subjects(g[0])
            return p(.protected, side: s.side, subjects: s.names)
        }
        if let g = match(#"^(.+?) fainte[dr]+[!.]?$"#) {
            let s = subjects(g[0])
            return p(.fainted, side: s.side, subjects: s.names)
        }

        // -- effectiveness ----------------------------------------------------
        // The leading "It's" is often lost mid-fade and "effective" wobbles
        // ("super ettective on …"), so this template is keyword-driven: a
        // fuzzy "effective"/"ineffective" hit + the "on <target>" tail.
        if normalized.fuzzilyContains("effective on ", maxEdits: 1),
           let g = match(#"on ((?:t?he )?opposing .+?|[A-Z].+?)[!.]?$"#) {
            let s = subjects(g[0])
            let magnitude: String = if normalized.fuzzilyContains("mostly ineffective", maxEdits: 2) {
                "0.25x"
            } else if normalized.fuzzilyContains("not very effective", maxEdits: 2) {
                "0.5x"
            } else if normalized.contains("extremely") {
                "4x"
            } else {
                "2x"
            }
            return p(.effectiveness, side: s.side, subjects: s.names, detail: magnitude)
        }
        if let g = match(#"^It doesn'?t affect (.+?)[!.]?$"#) {
            let s = subjects(g[0])
            return p(.effectiveness, side: s.side, subjects: s.names, detail: "0x")
        }

        // -- stat stages -------------------------------------------------------
        // "Charizard and Incineroar's Attack fell!" — possessive on the last
        // subject; stats can compound ("Defense and Sp. Def rose!").
        let statNames = #"(?:Attack|Defense|Sp\.? ?Atk|Sp\.? ?Def|Speed|Accuracy|Evasiveness)"#
        // Blocked drop ("The opposing Oranguru's Attack was not lowered!" —
        // battle 6, Clear Amulet/ability class). No state change; keep the
        // signal visible instead of an unrecognized note.
        if let g = match(#"^(.+?)'s (\#(statNames)) (?:was|were) not lowered[!.]?$"#) {
            let s = subjects(g[0])
            return p(.noteworthy, side: s.side, subjects: s.names,
                     detail: "\(g[1]) drop blocked")
        }
        // "fell" truncates mid-fade ("Attack fel" is a real battle-4 read);
        // the adverb rides EITHER side of the verb ("sharply rose" AND
        // "rose sharply!" — battle 7's Kingambit Defiant read used the
        // latter and went unrecognized until m11-B).
        if let g = match(#"^(.+?)'s (\#(statNames)(?: and \#(statNames))*) (sharply |harshly |drastically |severely )?(rose|fell?)( sharply| harshly| drastically| severely)?[!.]?$"#) {
            let s = subjects(g[0])
            let stats = g[1]
            let modifier = (g[2].isEmpty ? g[4] : g[2])
                .trimmingCharacters(in: .whitespaces).lowercased()
            let direction = g[3].lowercased().hasPrefix("rose") ? 1 : -1
            let stages: Int = switch modifier {
            case "sharply", "harshly": 2
            case "drastically", "severely": 3
            default: 1
            }
            return p(.statChange, side: s.side, subjects: s.names,
                     detail: stats, magnitude: direction * stages)
        }

        // -- status ------------------------------------------------------------
        let statusMap: [(String, String, BannerParse.Template)] = [
            ("was burned", "brn", .statusInflicted),
            ("was badly poisoned", "psn", .statusInflicted),
            ("was poisoned", "psn", .statusInflicted),
            ("was paralyzed", "par", .statusInflicted),
            // Champions' Zap Cannon-class application wording (battle 8:
            // "Venusaur is paralyzed, so it may be unable to move!" —
            // distinct from the mainline TICK "is paralyzed! It can't move").
            ("is paralyzed, so it may", "par", .statusInflicted),
            ("fell asleep", "slp", .statusInflicted),
            ("was frozen solid", "frz", .statusInflicted),
            ("is fast asleep", "slp", .statusTick),
            ("was hurt by its burn", "brn", .statusTick),
            ("was hurt by poison", "psn", .statusTick),
            ("was hurt by its poisoning", "psn", .statusTick),   // battle-6 wording
            ("is paralyzed! It can't move", "par", .statusTick),
            ("woke up", "slp", .statusCleared),
            ("thawed out", "frz", .statusCleared),
            ("was cured of its", "", .statusCleared),
        ]
        for (phrase, status, template) in statusMap {
            guard let range = text.range(of: phrase, options: .caseInsensitive) else { continue }
            let s = subjects(String(text[..<range.lowerBound]))
            guard !s.names.isEmpty else { continue }
            return p(template, side: s.side, subjects: s.names, detail: status.nilIfEmpty)
        }

        // -- drains / recoil / item heals ---------------------------------------
        if let g = match(#"^(.+?) had its energy drained[!.]?$"#) {
            let s = subjects(g[0])
            return p(.drained, side: s.side, subjects: s.names)
        }
        if let g = match(#"^(.+?) was damaged by the recoil[!.]?$"#) {
            let s = subjects(g[0])
            return p(.recoil, side: s.side, subjects: s.names)
        }
        // Life Orb (and similar) self-damage tick.
        if let g = match(#"^(.+?) lost some of its HP[!.]?$"#) {
            let s = subjects(g[0])
            return p(.recoil, side: s.side, subjects: s.names, detail: "lost some HP")
        }
        // Focus Sash / Sturdy-class survival — reveals the item, no heal.
        if let g = match(#"^(.+?) hung on using its (.+?)[!.]?$"#) {
            let s = subjects(g[0])
            let item = vocabulary.snapItem(g[1])?.value ?? g[1]
            return p(.itemHungOn, side: s.side, subjects: s.names, detail: item)
        }
        // Charge-turn flavor ("absorbed light" / "absorbed electricity").
        if let g = match(#"^(.+?) absorbed \w+[!.]?$"#) {
            let s = subjects(g[0])
            return p(.chargingTurn, side: s.side, subjects: s.names)
        }
        if let g = match(#"^(.+?) restored (?:a little |some )?(?:of )?(?:its )?(?:HP|health) (?:using|with) its (.+?)[!.]?$"#) {
            let s = subjects(g[0])
            let item = vocabulary.snapItem(g[1])?.value ?? g[1]
            return p(.healedByItem, side: s.side, subjects: s.names, detail: item)
        }
        if let g = match(#"^(.+?) drank down all the matcha"#) {
            let s = subjects(g[0])
            return p(.healedByItem, side: s.side, subjects: s.names, detail: "Matcha Gotcha")
        }

        // -- misses ---------------------------------------------------------------
        if let g = match(#"^(.+?) avoided the attack[!.]?$"#) {
            let s = subjects(g[0])
            return p(.missedOrAvoided, side: s.side, subjects: s.names)
        }
        if normalized.contains("attack missed") { return p(.missedOrAvoided) }
        if fuzzyEqual(normalized, "but it failed") { return p(.missedOrAvoided, detail: "failed") }
        if let g = match(#"^(.+?)[ -]flinched"#) {   // hyphen wobble: "Incineroar-flinched"
            let s = subjects(g[0])
            return p(.missedOrAvoided, side: s.side, subjects: s.names, detail: "flinched")
        }
        if normalized.fuzzilyContains("became the center of attention", maxEdits: 2) {
            let subject = text.components(separatedBy: " became").first.map { subjects($0) }
            return p(.noteworthy, side: subject?.side, subjects: subject?.names ?? [],
                     detail: "redirecting (Rage Powder / Follow Me)")
        }
        // Targeted crit note ("A critical hit on the opposing Oranguru!" —
        // battle 6; the bare "A critical hit!" form stays below).
        if let g = match(#"^A critical hit on (.+?)[!.]?$"#) {
            let s = subjects(g[0])
            return p(.noteworthy, side: s.side, subjects: s.names, detail: "critical hit")
        }
        if fuzzyEqual(normalized, "a critical hit") {
            return p(.noteworthy, detail: "critical hit")
        }
        // Ability flavor ("The power of the opposing Armarouge's Fire-type
        // moves rose!" — Flash Fire; the chip already carried the reveal).
        if let g = match(#"^The power of (.+?)'s .*moves rose"#) {
            let s = subjects(g[0])
            return p(.noteworthy, side: s.side, subjects: s.names, detail: "move power rose (ability)")
        }

        // -- degraded-text fallbacks (fuzzy: lookup-only subjects) ----------------
        // Heavily wobbled full-width banners ("harizard protedied itsell") still
        // carry a recognizable verb phrase; the subject is whatever precedes it.
        let fuzzyPhrases: [(String, Int, BannerParse.Template)] = [
            ("protected itself", 3, .protected),        // "protedied itsell" is a real read
            ("had its energy drained", 2, .drained),
        ]
        for (phrase, maxEdits, template) in fuzzyPhrases {
            guard normalized.fuzzilyContains(phrase, maxEdits: maxEdits) else { continue }
            let words = text.components(separatedBy: " ")
            let phraseWords = phrase.components(separatedBy: " ").count
            guard words.count > phraseWords else { continue }
            let s = subjects(words.prefix(words.count - phraseWords).joined(separator: " "))
            guard !s.names.isEmpty else { continue }
            return p(template, side: s.side, subjects: s.names, fuzzy: true)
        }

        return p(.unrecognized)
    }

    /// Whole-line fuzzy equality for fixed narration lines (≤2 edits absorbs
    /// dropped/duplicated characters without letting distinct lines collide).
    func fuzzyEqual(_ a: String, _ b: String) -> Bool {
        BattleVocabulary.levenshtein(a, b, cap: 2) <= 2
    }
}

nonisolated extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }

    /// Approximate substring search (Sellers): does any substring of `self`
    /// match `needle` within `maxEdits` Levenshtein edits? The mid-fade
    /// fragment detector and degraded-banner fallbacks live on this.
    /// (A separate name from the classifier's file-private helper.)
    func fuzzilyContains(_ needle: String, maxEdits: Int) -> Bool {
        if contains(needle) { return true }
        let hay = Array(self), pat = Array(needle)
        guard !pat.isEmpty else { return true }
        guard !hay.isEmpty else { return pat.count <= maxEdits }
        var prev = Array(0...pat.count)
        var cur = [Int](repeating: 0, count: pat.count + 1)
        for i in 1...hay.count {
            cur[0] = 0
            for j in 1...pat.count {
                let cost = hay[i - 1] == pat[j - 1] ? 0 : 1
                cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            if cur[pat.count] <= maxEdits { return true }
            swap(&prev, &cur)
        }
        return false
    }
}
