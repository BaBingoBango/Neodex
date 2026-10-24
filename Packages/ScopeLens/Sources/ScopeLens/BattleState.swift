//
//  BattleState.swift
//  Scope Lens
//
//  Phase 2, milestone 4: the running battle-state schema — spec §4.5,
//  implemented exactly as contracted (top-down; OCR/matching are best-effort
//  populators, never the schema's author). The screen shows only a subset of
//  this; the reconciler infers the rest from observed events and defaults the
//  remainder to unknown.
//
//  Identity convention: `speciesId` is the canonical species name when known
//  ("Garchomp", "Rotom-Wash"); "unknown" when the mon is only known by a
//  nickname (the nickname rides in `displayName`, which is UI-only per spec).
//

import Foundation

// MARK: - §4.5 BattleState

nonisolated public struct BattleState: Codable, Sendable {

    public struct Weather: Codable, Sendable {
        public var kind: String            // none | sun | rain | sand | snow
        public var turnsLeft: Int?         // best-effort; exact after a summary-panel re-sync
        public init(kind: String = "none", turnsLeft: Int? = nil) {
            self.kind = kind
            self.turnsLeft = turnsLeft
        }
    }

    public struct Tailwind: Codable, Sendable {
        public var you: Bool?
        public var opp: Bool?
        public init(you: Bool? = nil, opp: Bool? = nil) { self.you = you; self.opp = opp }
    }

    public struct Field: Codable, Sendable {
        public var trickRoom: Bool?
        public var tailwind: Tailwind
        public var screens: Screens?
        public init(trickRoom: Bool? = nil, tailwind: Tailwind = Tailwind(), screens: Screens? = nil) {
            self.trickRoom = trickRoom
            self.tailwind = tailwind
            self.screens = screens
        }
    }

    public struct Screens: Codable, Sendable {
        public var you: [String]           // active screen names: Light Screen / Reflect / Aurora Veil
        public var opp: [String]
        public init(you: [String] = [], opp: [String] = []) { self.you = you; self.opp = opp }
    }

    public struct Side: Codable, Sendable {
        public var active: [PokemonState]  // 1–2 filled as revealed
        public var bench: [PokemonState]   // opp bench seeded from team preview
        public init(active: [PokemonState] = [], bench: [PokemonState] = []) {
            self.active = active
            self.bench = bench
        }
    }

    public var turn: Int
    public var weather: Weather
    public var field: Field
    public var yourSide: Side
    public var oppSide: Side

    public init(turn: Int = 0, weather: Weather = Weather(), field: Field = Field(),
                yourSide: Side = Side(), oppSide: Side = Side()) {
        self.turn = turn
        self.weather = weather
        self.field = field
        self.yourSide = yourSide
        self.oppSide = oppSide
    }
}

// MARK: - §4.5 PokemonState

nonisolated public struct PokemonState: Codable, Sendable {

    public struct HP: Codable, Sendable {
        public var kind: String            // exact | percent
        public var cur: Int?
        public var max: Int?
        public var pct: Double?
        public init(kind: String, cur: Int? = nil, max: Int? = nil, pct: Double? = nil) {
            self.kind = kind
            self.cur = cur
            self.max = max
            self.pct = pct
        }
        public static func exact(_ cur: Int, _ max: Int) -> HP { HP(kind: "exact", cur: cur, max: max) }
        public static func percent(_ pct: Double) -> HP { HP(kind: "percent", pct: pct) }
        public var isFainted: Bool { (cur ?? Int(pct ?? 100)) <= 0 && (cur != nil || pct != nil) }
        public var display: String {
            switch kind {
            case "exact" where cur != nil && max != nil: "\(cur!)/\(max!)"
            case "percent" where pct != nil: "\(Int(pct!))%"
            default: "?"
            }
        }
    }

    public struct Boosts: Codable, Sendable, Equatable {
        public var atk = 0, def = 0, spa = 0, spd = 0, spe = 0   // -6…+6
        public init() {}
        public var isNeutral: Bool { atk == 0 && def == 0 && spa == 0 && spd == 0 && spe == 0 }
        public var display: String {
            [("Atk", atk), ("Def", def), ("SpA", spa), ("SpD", spd), ("Spe", spe)]
                .filter { $0.1 != 0 }
                .map { "\($0.0)\($0.1 > 0 ? "+" : "")\($0.1)" }
                .joined(separator: " ")
        }
    }

    public var speciesId: String           // canonical species, or "unknown"
    public var displayName: String?        // on-screen text (may be nickname) — UI only
    public var hp: HP?
    public var status: String?             // par | psn | brn | slp | frz (spec set)
    public var boosts: Boosts
    public var revealedMoves: [String]
    public var item: String?
    public var megaEvolved: Bool?
    public var teraType: String?

    public init(speciesId: String, displayName: String? = nil, hp: HP? = nil,
                status: String? = nil, boosts: Boosts = Boosts(),
                revealedMoves: [String] = [], item: String? = nil,
                megaEvolved: Bool? = nil, teraType: String? = nil) {
        self.speciesId = speciesId
        self.displayName = displayName
        self.hp = hp
        self.status = status
        self.boosts = boosts
        self.revealedMoves = revealedMoves
        self.item = item
        self.megaEvolved = megaEvolved
        self.teraType = teraType
    }

    /// "Garchomp" or "Matcha Latte (species unknown)" — for logs.
    public var describeName: String {
        if speciesId != "unknown" { return speciesId }
        if let displayName { return "\(displayName) (species unknown)" }
        return "unknown"
    }
}

// MARK: - Live field spec (engine-shaped, Sendable — feeds liveMatchup)

nonisolated public struct LiveFieldSpec: Sendable {
    public var weather: String?
    public var trickRoom: Bool
    public var tailwindYou: Bool
    public var tailwindOpp: Bool
    public var screensYou: [String]
    public var screensOpp: [String]

    public init(weather: String? = nil, trickRoom: Bool = false,
                tailwindYou: Bool = false, tailwindOpp: Bool = false,
                screensYou: [String] = [], screensOpp: [String] = []) {
        self.weather = weather
        self.trickRoom = trickRoom
        self.tailwindYou = tailwindYou
        self.tailwindOpp = tailwindOpp
        self.screensYou = screensYou
        self.screensOpp = screensOpp
    }

    public var signature: String {
        "\(weather ?? "-")|\(trickRoom)|\(tailwindYou)|\(tailwindOpp)|\(screensYou.joined(separator: ","))|\(screensOpp.joined(separator: ","))"
    }
}

// MARK: - Battle events (reconciler output; feeds the human-readable log)

nonisolated public struct BattleEvent: Codable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case battleStart, teamPreviewRead, turnStart
        case sendOut, withdraw
        case moveUsed, moveBlocked, protected, effectiveness
        case statChange, statusInflicted, statusTick, statusCleared
        case boostsRestored            // White Herb cleared the negative stages (m13-F)
        case abilityActivated, itemActivated, itemRevealed
        case megaEvolved
        case weatherStart, weatherEnd
        case screenUp, screenDown, trickRoom, tailwind
        case damageTaken, healed, drained, recoil
        case damageObserved            // m12-B: an attributed hit, inference-ready
        case fainted
        case hpResync
        case boostSync                 // summary-panel absolute stat stages (m9-C)
        case perishCount               // the Perish Song doom clock (value = turns left)
        case identityResolved          // nickname → species (e.g. via signature move)
        case note                      // real banner text no template claimed — kept, never dropped
        case battleEnd
    }

    public let t: Double               // video/session seconds
    public let turn: Int
    public let kind: Kind
    public let side: String?           // "you" | "opp" | nil (field-wide)
    public let subject: String?        // display name as narrated
    public let species: String?        // resolved species when known
    public let detail: String?         // move/ability/item/stat/weather-kind/…
    public let value: String?          // hp readout, stage delta, …
    public let raw: String?            // the banner text as OCR'd (audit trail)

    public init(t: Double, turn: Int, kind: Kind, side: String? = nil,
                subject: String? = nil, species: String? = nil, detail: String? = nil,
                value: String? = nil, raw: String? = nil) {
        self.t = t
        self.turn = turn
        self.kind = kind
        self.side = side
        self.subject = subject
        self.species = species
        self.detail = detail
        self.value = value
        self.raw = raw
    }

    public static func mmss(_ t: Double) -> String {
        // Round to a tenth FIRST — otherwise 299.96s renders as "04:60.0".
        let tenths = (t * 10).rounded() / 10
        let minutes = Int(tenths) / 60
        let seconds = tenths - Double(minutes * 60)
        return String(format: "%02d:%04.1f", minutes, seconds)
    }

    /// One human-readable line for this event — the single formatter behind
    /// both the paper-replay markdown log and the live Battle Log window.
    public var displayLine: String {
        let sideTag = side.map { $0 == "you" ? "[you] " : "[opp] " } ?? ""
        let name = species ?? subject ?? ""
        switch kind {
        case .battleStart: return "🎬 battle tracking started" + (detail.map { " — \($0)" } ?? "")
        case .teamPreviewRead: return "🔭 preview read: \(detail ?? "")"
        case .turnStart: return "— Turn \(turn) —"
        case .sendOut: return "➡️ \(sideTag)\(name) sent out"
        case .withdraw: return "⬅️ \(sideTag)\(name) withdrawn"
        case .moveUsed: return "⚔️ \(sideTag)\(name) used \(detail ?? "?")"
        case .moveBlocked: return "🚫 \(sideTag)\(name) couldn't use \(detail ?? "?") (blocked)"
        case .protected: return detail == nil
            ? "🛡 \(sideTag)\(name) protected itself"
            : "🛡 \(sideTag)\(name.isEmpty ? "side" : name) protected by \(detail!)"
        case .effectiveness: return "✴️ \(detail ?? "") effective on \(sideTag)\(subject ?? "")"
        case .statChange: return "\((value ?? "").hasPrefix("-") ? "📉" : "📈") \(sideTag)\(name): \(detail ?? "") \(value ?? "")"
        case .statusInflicted: return "🤕 \(sideTag)\(name) → \(detail ?? "?")"
        case .statusTick: return "🩹 \(sideTag)\(name) (\(detail ?? "status") tick)"
        case .statusCleared: return "✨ \(sideTag)\(name) status cleared"
        case .boostsRestored: return "✨ \(sideTag)\(name) stat changes restored\(detail.map { " (\($0))" } ?? "")"
        case .abilityActivated: return "💠 \(sideTag)\(name)'s ability: \(detail ?? "?")"
        case .itemActivated: return "🎒 \(sideTag)\(name)'s item: \(detail ?? "?")"
        case .itemRevealed: return "💡 \(sideTag)\(name) revealed item: \(detail ?? "?")"
        case .megaEvolved: return "🔮 \(sideTag)\(name) Mega Evolved"
        case .weatherStart: return "🌦 weather: \(detail ?? "?") begins"
        case .weatherEnd: return "🌤 weather: \(detail ?? "?") ended"
        case .screenUp: return "🪟 \(sideTag)\(detail ?? "screen") up"
        case .screenDown: return "🪟 \(sideTag)\(detail ?? "screen") wore off"
        case .trickRoom: return "🌀 Trick Room \(value ?? "")"
        case .tailwind: return "🌬 \(sideTag)Tailwind \(value ?? "")"
        case .damageTaken: return "🔻 \(sideTag)\(name) \(value ?? "")"
        case .damageObserved: return "🔎 \(sideTag)\(name)'s \(detail ?? "?") → \(value ?? "")"
        case .healed: return "💚 \(sideTag)\(name) healed\(detail.map { " (\($0))" } ?? "") \(value ?? "")"
        case .drained: return "🩸 \(sideTag)\(name) had its energy drained"
        case .recoil: return "💥 \(sideTag)\(name) took recoil"
        case .fainted: return "💀 \(sideTag)\(name) fainted"
        case .hpResync: return "🔄 \(sideTag)\(name.isEmpty ? "" : name + " ")\(detail ?? "re-sync") \(value ?? "")"
        case .boostSync: return "🎛 \(sideTag)\(name) stat stages: \(value ?? "neutral") (summary panel)"
        case .perishCount: return "⏳ \(sideTag)\(name) perish count: \(value ?? "?")\(value == "0" ? " — faints now!" : "")"
        case .identityResolved: return "🧩 \(sideTag)\(subject ?? "?") identified as \(species ?? "?") (\(detail ?? ""))"
        case .note: return "📝 \(detail ?? raw ?? "")"
        case .battleEnd: return "🏁 battle ended: \(detail ?? "?")"
        }
    }
}
