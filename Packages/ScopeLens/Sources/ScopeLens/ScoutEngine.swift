//
//  ScoutEngine.swift
//  Scope Lens
//
//  Phase 2, milestone 3b: the deterministic TypeScript engine (type math, meta
//  priors, @smogon/calc damage rolls — spec §4.3) running in JavaScriptCore
//  inside the app. Bridges the live tracker's frame-voted opponent consensus
//  to `ScopeEngine.scoutReportData` and decodes the structured report the
//  scout window renders.
//
//  The engine bundle (Resources/Engine/engine.js) is built from Tools/ScopeLensEngine/src
//  with the pinned esbuild (see Tools/ScopeLensEngine/package.json); meta priors are baked in
//  at build time. Tools/ScopeLensDiagnostics/ScoutEngineHarness.swift proves this bridge
//  matches the Phase-1 CLI on identical inputs.
//

import Foundation
import JavaScriptCore

// MARK: - Report model (mirror of engine.ts scoutReportData)

nonisolated public struct ScoutReportData: Codable, Sendable {
    public struct OpponentSet: Codable, Sendable {
        public struct MoveRead: Codable, Sendable {
            public let name: String
            public let pct: Double?
        }
        public let species: String
        public let item: String?
        public let ability: String?
        public let assumed: Bool     // set came from priors, not observation
        public let hasMeta: Bool     // false ⇒ species missing from usage data
        public let setSource: String? // observed | usage | learnset | none (m4)
        public let moves: [MoveRead]
    }
    public struct ThreatRead: Codable, Sendable {
        public let attacker: String
        public let defender: String
        public let move: String
        public let minPct: Double
        public let maxPct: Double
        public let ko: Bool
    }
    public struct AnswerRead: Codable, Sendable {
        public let mine: String
        public let move: String
        public let target: String
        public let minPct: Double
        public let maxPct: Double
    }
    public let opponents: [OpponentSet]
    public let threats: [ThreatRead]
    public let answers: [AnswerRead]
    public let safeFour: [String]
    public let leads: [String]
    public let assumptions: String
}

/// Input spec for one Pokémon (ours are known; opponents are species-only and
/// the engine fills sets from meta priors). Live-battle extras (boosts,
/// current HP, status) ride along for liveMatchup and are ignored by the
/// scout report.
nonisolated public struct MonSpec: Sendable {
    public let species: String
    public var item: String?
    public var ability: String?
    public var moves: [String]?
    public var boosts: [String: Int]?
    public var curPct: Double?
    public var status: String?
    // Real spread (m9 team management) — engine uses it verbatim when set,
    // synthetic 252s otherwise. teraType rides the model only (not calc'd).
    public var evs: [String: Int]?
    public var ivs: [String: Int]?
    public var nature: String?
    public var level: Int?
    public var teraType: String?

    public init(species: String, item: String? = nil, ability: String? = nil,
                moves: [String]? = nil, boosts: [String: Int]? = nil,
                curPct: Double? = nil, status: String? = nil,
                evs: [String: Int]? = nil, ivs: [String: Int]? = nil,
                nature: String? = nil, level: Int? = nil, teraType: String? = nil) {
        self.species = species
        self.item = item
        self.ability = ability
        self.moves = moves
        self.boosts = boosts
        self.curPct = curPct
        self.status = status
        self.evs = evs
        self.ivs = ivs
        self.nature = nature
        self.level = level
        self.teraType = teraType
    }

    var asDictionary: [String: Any] {
        var d: [String: Any] = ["species": species]
        if let item { d["item"] = item }
        if let ability { d["ability"] = ability }
        if let moves { d["moves"] = moves }
        if let boosts, !boosts.isEmpty { d["boosts"] = boosts }
        if let curPct { d["curPct"] = curPct }
        if let status { d["status"] = status }
        if let evs, !evs.isEmpty { d["evs"] = evs }
        if let ivs, !ivs.isEmpty { d["ivs"] = ivs }
        if let nature { d["nature"] = nature }
        if let level { d["level"] = level }
        if let teraType { d["teraType"] = teraType }
        return d
    }
}

nonisolated extension TeamMember {
    /// The engine-facing view of a configured team slot. Lives here (not in
    /// TeamStore.swift) so harnesses that avoid JavaScriptCore never see
    /// MonSpec. Explicitly nonisolated — the app target defaults to
    /// MainActor isolation (Xcode 26).
    public var monSpec: MonSpec {
        MonSpec(species: species, item: item, ability: ability,
                moves: moves.isEmpty ? nil : moves,
                evs: evs, ivs: ivs, nature: nature, level: level,
                teraType: teraType)
    }
}

// MARK: - Live matchup model (mirror of engine.ts liveMatchup — Phase 3 m7)

nonisolated public struct LiveMatchupData: Codable, Sendable {
    public struct Pair: Codable, Sendable {
        public let attacker: String
        public let defender: String
        public let dir: String            // incoming | outgoing
        public let move: String
        public let minPct: Double
        public let maxPct: Double
        public let koNow: Bool            // max roll clears the defender's CURRENT HP
        public let guaranteedKo: Bool     // min roll clears it
        public let setSource: String      // observed | usage | learnset | none
        public let approx: Bool           // stats approximated (unknown forme fallback)
    }
    public struct SpeedRead: Codable, Sendable {
        public let species: String
        public let side: String
        public let spe: Int
        public let approx: Bool
    }
    public let incoming: [Pair]
    public let outgoing: [Pair]
    public let speeds: [SpeedRead]        // pre-sorted for the live field (TR-aware)
    public let trickRoom: Bool
    public let assumptions: String
}

// MARK: - Dex effect info (mirror of engine.ts dexInfo — m12-C)

/// Effect text + mechanical facts for moves/abilities/items, resolved from
/// the bundled dex-info data (baked from @pkmn/dex, scoped to the closed
/// vocab). Entries come back in input order; unknown names degrade to
/// `known == false` with only the echoed name.
nonisolated public struct DexInfo: Codable, Sendable {
    nonisolated public struct MoveInfo: Codable, Sendable {
        public let name: String
        public let known: Bool
        public let type: String?
        public let category: String?    // Physical | Special | Status
        public let basePower: Int?
        public let accuracy: Int?       // nil = never misses (or unknown)
        public let priority: Int?
        public let shortDesc: String?
    }
    nonisolated public struct EffectInfo: Codable, Sendable {
        public let name: String
        public let known: Bool
        public let shortDesc: String?
    }
    public let moves: [MoveInfo]
    public let abilities: [EffectInfo]
    public let items: [EffectInfo]
}

// MARK: - Engine bridge

nonisolated public final class ScoutEngine {

    public enum EngineError: Error, LocalizedError {
        case loadFailed(String)
        case callFailed(String)
        public var errorDescription: String? {
            switch self {
            case .loadFailed(let s): "engine load failed: \(s)"
            case .callFailed(let s): "engine call failed: \(s)"
            }
        }
    }

    private let context: JSContext
    private let reportFn: JSValue
    private let matchupFn: JSValue?

    /// `metaJSON`, when provided, replaces the engine's baked-in usage
    /// snapshot at runtime (ScopeEngine.setMeta) — refreshing stats becomes a
    /// data-file swap with no engine rebuild.
    public init(engineSource: String, metaJSON: Data? = nil) throws {
        guard let ctx = JSContext() else { throw EngineError.loadFailed("no JSContext") }
        var jsError: String?
        ctx.exceptionHandler = { _, ex in jsError = ex?.toString() }
        ctx.evaluateScript(engineSource)
        if let jsError { throw EngineError.loadFailed(jsError) }
        guard let engine = ctx.objectForKeyedSubscript("ScopeEngine"),
              let fn = engine.objectForKeyedSubscript("scoutReportData"), fn.isObject else {
            throw EngineError.loadFailed("ScopeEngine.scoutReportData not found")
        }
        let matchup = engine.objectForKeyedSubscript("liveMatchup")
        self.matchupFn = (matchup?.isObject == true) ? matchup : nil
        if let metaJSON {
            guard let parsed = try? JSONSerialization.jsonObject(with: metaJSON),
                  let setMeta = engine.objectForKeyedSubscript("setMeta"), setMeta.isObject else {
                throw EngineError.loadFailed("meta injection failed")
            }
            setMeta.call(withArguments: [parsed])
            if let jsError { throw EngineError.loadFailed(jsError) }
        }
        self.context = ctx
        self.reportFn = fn
    }

    /// Load from the app bundle (Resources/Engine/): engine.js + the meta
    /// data file (authoritative when present; baked snapshot is the fallback).
    public static func bundled() throws -> ScoutEngine {
        guard let url = Bundle.scopeLens.url(forResource: "engine", withExtension: "js") else {
            throw EngineError.loadFailed("bundled engine.js missing")
        }
        let meta = Bundle.scopeLens.url(forResource: "meta-regmbs3", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
        return try ScoutEngine(engineSource: try String(contentsOf: url, encoding: .utf8),
                               metaJSON: meta)
    }

    /// Run the structured scout report. `theirs` is species-only (the live
    /// consensus); overrides have already been applied by the caller.
    public func report(mine: [MonSpec], theirs: [String]) throws -> ScoutReportData {
        var jsError: String?
        context.exceptionHandler = { _, ex in jsError = ex?.toString() }
        let args: [Any] = [
            mine.map(\.asDictionary),
            theirs.map { ["species": $0] },
        ]
        guard let result = reportFn.call(withArguments: args) else {
            throw EngineError.callFailed(jsError ?? "no result")
        }
        if let jsError { throw EngineError.callFailed(jsError) }
        // JSON round-trip: exact one decode path, no Any-casting.
        guard let json = context.objectForKeyedSubscript("JSON")?
            .invokeMethod("stringify", withArguments: [result])?.toString(),
              let data = json.data(using: .utf8) else {
            throw EngineError.callFailed("stringify failed")
        }
        return try JSONDecoder().decode(ScoutReportData.self, from: data)
    }

    /// Hot-swap the usage snapshot (m11-C runtime meta refresh) — the same
    /// ScopeEngine.setMeta seam the initializer uses, callable any time.
    /// A refresh is a data swap; the JSC engine never rebuilds.
    public func setMeta(_ metaJSON: Data) throws {
        guard let parsed = try? JSONSerialization.jsonObject(with: metaJSON),
              let dict = parsed as? [String: Any], !dict.isEmpty else {
            throw EngineError.callFailed("setMeta: not a meta snapshot")
        }
        _ = try callJSON("setMeta", args: [dict])
    }

    // MARK: Generic call surface (m11 — the agentic advisor's tool loop)

    /// Call any exported `ScopeEngine.<name>(…)` and return the result as a
    /// JSON-round-tripped Foundation object ([String: Any] / [Any] / scalar).
    /// One decode path for the advisor tools; the typed wrappers above stay
    /// for the app's structured surfaces.
    public func callJSON(_ name: String, args: [Any]) throws -> Any? {
        var jsError: String?
        context.exceptionHandler = { _, ex in jsError = ex?.toString() }
        guard let engine = context.objectForKeyedSubscript("ScopeEngine"),
              let fn = engine.objectForKeyedSubscript(name), fn.isObject else {
            throw EngineError.callFailed("ScopeEngine.\(name) not found")
        }
        guard let result = fn.call(withArguments: args) else {
            throw EngineError.callFailed(jsError ?? "no result")
        }
        if let jsError { throw EngineError.callFailed(jsError) }
        if result.isNull || result.isUndefined { return nil }
        guard let json = context.objectForKeyedSubscript("JSON")?
            .invokeMethod("stringify", withArguments: [result])?.toString(),
              json != "undefined",
              let data = json.data(using: .utf8) else {
            throw EngineError.callFailed("stringify failed")
        }
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// Usage-stats profile (moves/items/abilities % + winrate) or nil when
    /// the species is off-ladder.
    public func metaProfile(species: String) throws -> [String: Any]? {
        try callJSON("metaProfile", args: [species]) as? [String: Any]
    }

    /// Type-effectiveness multiplier of one attacking type into a typing.
    public func typeEffect(moveType: String, defenderTypes: [String]) throws -> Double {
        (try callJSON("typeEffect", args: [moveType, defenderTypes]) as? Double) ?? 1
    }

    /// L50 speed range per species: 0-EV neutral floor → 252-EV +nature
    /// ceiling. Species unknown to the dex are omitted.
    public func speedBrackets(species: [String]) throws -> [[String: Any]] {
        (try callJSON("speedBrackets", args: [species]) as? [[String: Any]]) ?? []
    }

    /// Which attacking types hit this typing for 4×/2×/½/¼/0.
    public func defensiveProfile(types: [String]) throws -> [String: [String]] {
        ((try callJSON("defensiveProfile", args: [types]) as? [String: Any]) ?? [:])
            .compactMapValues { $0 as? [String] }
    }

    /// Effect text + mechanical facts for moves/abilities/items (m12-C —
    /// the Opponent Dossier's "what does that do" layer). One JSC call for
    /// any mix of the three kinds; results ride back in input order.
    public func dexInfo(moves: [String] = [], abilities: [String] = [],
                        items: [String] = []) throws -> DexInfo {
        var input: [String: Any] = [:]
        if !moves.isEmpty { input["moves"] = moves }
        if !abilities.isEmpty { input["abilities"] = abilities }
        if !items.isEmpty { input["items"] = items }
        guard let result = try callJSON("dexInfo", args: [input]) else {
            throw EngineError.callFailed("dexInfo returned nothing")
        }
        let data = try JSONSerialization.data(withJSONObject: result)
        return try JSONDecoder().decode(DexInfo.self, from: data)
    }

    /// Reverse damage inference (m12-B): which attacker sets are consistent
    /// with an observed hit. Input is the engine's single-dict shape; the
    /// result carries `summary` (or `skipped`) plus the hypothesis grid.
    public func inferAttack(_ input: [String: Any]) throws -> [String: Any]? {
        try callJSON("inferAttack", args: [input]) as? [String: Any]
    }

    /// The markdown scout report (the CLI/MCP rendering — the advisor's
    /// scout_report tool returns this same text).
    public func scoutReportMarkdown(mine: [MonSpec], theirs: [String])
        throws -> (markdown: String, safeFour: [String]) {
        let result = try callJSON("scoutReport", args: [
            mine.map(\.asDictionary), theirs.map { ["species": $0] },
        ]) as? [String: Any]
        guard let markdown = result?["markdown"] as? String else {
            throw EngineError.callFailed("scoutReport returned no markdown")
        }
        return (markdown, result?["safeFour"] as? [String] ?? [])
    }

    /// Live in-battle matchup: current actives both sides + the live field
    /// (Phase 3 m7).
    public func liveMatchup(mine: [MonSpec], theirs: [MonSpec],
                            field: LiveFieldSpec) throws -> LiveMatchupData {
        guard let matchupFn else { throw EngineError.callFailed("liveMatchup missing from engine bundle") }
        var jsError: String?
        context.exceptionHandler = { _, ex in jsError = ex?.toString() }
        var fieldDict: [String: Any] = [:]
        if let w = field.weather { fieldDict["weather"] = w }
        if field.trickRoom { fieldDict["trickRoom"] = true }
        if field.tailwindYou { fieldDict["tailwindYou"] = true }
        if field.tailwindOpp { fieldDict["tailwindOpp"] = true }
        if !field.screensYou.isEmpty { fieldDict["screensYou"] = field.screensYou }
        if !field.screensOpp.isEmpty { fieldDict["screensOpp"] = field.screensOpp }
        let args: [Any] = [mine.map(\.asDictionary), theirs.map(\.asDictionary), fieldDict]
        guard let result = matchupFn.call(withArguments: args) else {
            throw EngineError.callFailed(jsError ?? "no result")
        }
        if let jsError { throw EngineError.callFailed(jsError) }
        guard let json = context.objectForKeyedSubscript("JSON")?
            .invokeMethod("stringify", withArguments: [result])?.toString(),
              let data = json.data(using: .utf8) else {
            throw EngineError.callFailed("stringify failed")
        }
        return try JSONDecoder().decode(LiveMatchupData.self, from: data)
    }

}
