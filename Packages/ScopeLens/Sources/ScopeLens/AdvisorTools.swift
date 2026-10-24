//
//  AdvisorTools.swift
//  Scope Lens
//
//  Phase 3, m11: the agentic advisor's tool surface. The six §4.3 engine
//  tools (Engine/tool-schemas.json — the SAME definitions the MCP server
//  lists) become Anthropic tool definitions, executed in-app against the
//  same JavaScriptCore engine, so "run that damage calc" costs milliseconds
//  and matches the scout CLI by construction.
//
//  Also home of the OPPONENT META CAPSULE builder: the battle-static facts
//  (usage priors, speed brackets, defensive typing, priority-blocker flags)
//  pre-computed once per battle into the advisor's cacheable context prefix.
//

import Foundation

// MARK: - Tool catalog (shared schemas → Anthropic tool definitions)

nonisolated public enum AdvisorToolCatalog {

    /// Tool definitions in Anthropic Messages shape (`input_schema`), mapped
    /// from the MCP-shaped shared file (`inputSchema`) — plus `commit_play`
    /// appended last. Order preserved — the tools array is part of the
    /// cached prompt prefix, so it must be byte-stable across requests.
    public static func anthropicTools(from data: Data) throws -> [[String: Any]] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tools = root["tools"] as? [[String: Any]] else {
            throw NSError(domain: "AdvisorTools", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "tool-schemas.json: missing tools array"])
        }
        return tools.map { tool in
            var mapped: [String: Any] = [:]
            mapped["name"] = tool["name"]
            mapped["description"] = tool["description"]
            mapped["input_schema"] = tool["inputSchema"]
            return mapped
        } + [commitPlayTool]
    }

    /// m12-F: the advisor's OUTPUT protocol — not an engine check, and
    /// deliberately NOT in tool-schemas.json (the MCP server must never
    /// list it). The model commits its final per-active decision as
    /// structured data; the client intercepts it locally and the UI
    /// renders action chips the pilot can mirror into the game.
    static let commitPlayTool: [String: Any] = [
        "name": "commit_play",
        "description": "Record your FINAL decision for the CURRENT TURN, one entry per YOUR "
            + "active Pokémon. The pilot inputs these actions into the game verbatim — use "
            + "exact move and Pokémon names as they appear in the context. Call it once you "
            + "have decided, in the SAME response as your reasoning text; if a later check "
            + "changes your mind, call it again — the latest call wins. Never used for TEAM "
            + "PREVIEW answers.",
        "input_schema": [
            "type": "object",
            "properties": [
                "actions": [
                    "type": "array",
                    "description": "One entry per YOUR active Pokémon, in on-field order.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "pokemon": [
                                "type": "string",
                                "description": "Your active Pokémon performing this action",
                            ],
                            "action": [
                                "type": "string",
                                "enum": ["move", "switch"],
                            ],
                            "move": [
                                "type": "string",
                                "description": "Exact move name (when action is move)",
                            ],
                            "target": [
                                "type": "string",
                                "description": "Target Pokémon name; or \"both\", \"self\", "
                                    + "or \"field\" for spread, self-targeted and field moves",
                            ],
                            "switch_to": [
                                "type": "string",
                                "description": "Bench Pokémon to bring in (when action is switch)",
                            ],
                            "mega": [
                                "type": "boolean",
                                "description": "Also Mega Evolve this turn",
                            ],
                            "note": [
                                "type": "string",
                                "description": "Optional short rider, ≤10 words (e.g. \"if they Protect, double into Gengar\")",
                            ],
                        ] as [String: Any],
                        "required": ["pokemon", "action"],
                    ] as [String: Any],
                ] as [String: Any],
            ] as [String: Any],
            "required": ["actions"],
        ] as [String: Any],
    ]

    /// App-bundle copy (Resources/Engine/tool-schemas.json).
    public static func bundled() throws -> [[String: Any]] {
        guard let url = Bundle.module.url(forResource: "tool-schemas", withExtension: "json") else {
            throw NSError(domain: "AdvisorTools", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "bundled tool-schemas.json missing"])
        }
        return try anthropicTools(from: Data(contentsOf: url))
    }

    /// Repo copy for diagnostics CLIs (run from the repo root).
    public static func fromRepo(root: String = ".") throws -> [[String: Any]] {
        try anthropicTools(from: Data(contentsOf:
            URL(fileURLWithPath: "\(root)/Engine/tool-schemas.json")))
    }
}

// MARK: - Tool executor (in-app twin of mcp-server.js's handlers)

/// Executes the six tools against the JSC engine. Mirrors the MCP server's
/// handlers: same result shapes, same graceful tool-level errors (text +
/// isError, so the model reads the message and adapts). NOT thread-safe —
/// the owner (ScoutEngineBox actor in the app; the single-threaded harness
/// offline) serializes access, because JSContext is single-threaded.
nonisolated public struct AdvisorToolExecutor {

    public let engine: ScoutEngine
    /// matchKey → vocab entry, the case/punctuation-insensitive species
    /// lookup (same convention as the MCP server and TeamVocab).
    private let speciesByKey: [String: BattleVocabulary.SpeciesEntry]
    /// The pilot's configured team — scout_report's default `mine`.
    public var configuredTeam: [MonSpec]

    public init(engine: ScoutEngine, vocabulary: BattleVocabulary,
                configuredTeam: [MonSpec]) {
        self.engine = engine
        var byKey: [String: BattleVocabulary.SpeciesEntry] = [:]
        for entry in vocabulary.species {
            byKey[Self.matchKey(entry.name)] = entry
        }
        self.speciesByKey = byKey
        self.configuredTeam = configuredTeam
    }

    public static func matchKey(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) && $0.isASCII
        })
    }

    public func resolve(_ raw: String) -> BattleVocabulary.SpeciesEntry? {
        speciesByKey[Self.matchKey(raw)]
    }

    /// Run one tool call. Never throws: failures come back as (message,
    /// isError: true) for the model, exactly like the MCP server's
    /// tool-level errors.
    public func execute(name: String, arguments: [String: Any]) -> (text: String, isError: Bool) {
        do {
            switch name {
            case "resolve_species": return (try resolveSpecies(arguments), false)
            case "meta_profile": return (try metaProfileTool(arguments), false)
            case "type_calc": return (try typeCalc(arguments), false)
            case "damage_calc": return (try damageCalc(arguments), false)
            case "scout_report": return (try scoutReport(arguments), false)
            case "live_matchup": return (try liveMatchupTool(arguments), false)
            default: return ("Error: unknown tool: \(name)", true)
            }
        } catch {
            let message = (error as? ToolError)?.message ?? error.localizedDescription
            return ("Error: \(message)", true)
        }
    }

    struct ToolError: Error { let message: String }

    private func json(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func resolveOne(_ raw: String) -> [String: Any] {
        if let hit = resolve(raw) {
            return ["input": raw, "matched": true, "species": hit.name,
                    "display": hit.display, "types": hit.types]
        }
        return ["input": raw, "matched": false, "input_key": Self.matchKey(raw)]
    }

    private func resolveSpecies(_ args: [String: Any]) throws -> String {
        guard let names = args["names"] as? [String] else {
            throw ToolError(message: "resolve_species needs `names` (array of strings)")
        }
        return try json(["resolutions": names.map(resolveOne)])
    }

    private func metaProfileTool(_ args: [String: Any]) throws -> String {
        guard let raw = args["species"] as? String else {
            throw ToolError(message: "meta_profile needs `species`")
        }
        let species = resolve(raw)?.name ?? raw
        guard let profile = try engine.metaProfile(species: species) else {
            return try json([
                "species": species, "hasMeta": false,
                "note": "No Reg M-B ranked usage data for this species (off-ladder); damage tools fall back to learnset-derived movesets.",
            ])
        }
        return try json(["species": species, "hasMeta": true, "profile": profile])
    }

    private func typeCalc(_ args: [String: Any]) throws -> String {
        guard let moveType = args["moveType"] as? String,
              let defenderTypes = args["defenderTypes"] as? [String] else {
            throw ToolError(message: "type_calc needs `moveType` and `defenderTypes`")
        }
        let multiplier = try engine.typeEffect(moveType: moveType, defenderTypes: defenderTypes)
        return try json(["moveType": moveType, "defenderTypes": defenderTypes,
                         "multiplier": multiplier])
    }

    private func damageCalc(_ args: [String: Any]) throws -> String {
        guard var attacker = args["attacker"] as? [String: Any],
              let move = args["move"] as? String,
              let defender = args["defender"] as? [String: Any] else {
            throw ToolError(message: "damage_calc needs `attacker`, `move`, `defender`")
        }
        attacker["moves"] = [move]
        let field = args["field"] as? [String: Any] ?? [:]
        let result = try engine.callJSON("liveMatchup",
                                         args: [[attacker], [defender], field]) as? [String: Any]
        guard let hit = (result?["outgoing"] as? [[String: Any]])?.first else {
            throw ToolError(message: "no damage result — \"\(move)\" may be a status move, unknown to the calc, or the species names may need resolve_species first")
        }
        return try json([
            "attacker": attacker["species"] ?? "?", "move": move,
            "defender": defender["species"] ?? "?",
            "minPct": hit["minPct"] ?? 0, "maxPct": hit["maxPct"] ?? 0,
            "koNow": hit["koNow"] ?? false, "guaranteedKo": hit["guaranteedKo"] ?? false,
            "defenderCurrentHpPct": defender["curPct"] ?? 100,
            "approxStats": hit["approx"] ?? false,
            "assumptions": result?["assumptions"] ?? "",
        ])
    }

    private func scoutReport(_ args: [String: Any]) throws -> String {
        guard let theirs = args["theirs"] as? [String], !theirs.isEmpty else {
            throw ToolError(message: "scout_report needs `theirs` (opponent species)")
        }
        var mine = args["mine"] as? [[String: Any]] ?? []
        var mineSource = "caller-provided"
        if mine.isEmpty {
            mine = configuredTeam.map(\.asDictionary)
            mineSource = "configured ScopeLens team"
            guard !mine.isEmpty else {
                throw ToolError(message: "no `mine` given and no team is configured — pass `mine` explicitly")
            }
        }
        let result = try engine.callJSON("scoutReport", args: [
            mine, theirs.map { ["species": $0] },
        ]) as? [String: Any]
        guard let markdown = result?["markdown"] as? String else {
            throw ToolError(message: "scoutReport returned no markdown")
        }
        let safeFour = (result?["safeFour"] as? [String]) ?? []
        return markdown + "\n\n_(mine: \(mineSource); bring 4: \(safeFour.joined(separator: ", ")))_"
    }

    private func liveMatchupTool(_ args: [String: Any]) throws -> String {
        guard let mine = args["mine"] as? [[String: Any]],
              let theirs = args["theirs"] as? [[String: Any]] else {
            throw ToolError(message: "live_matchup needs `mine` and `theirs`")
        }
        let field = args["field"] as? [String: Any] ?? [:]
        guard let result = try engine.callJSON("liveMatchup",
                                               args: [mine, theirs, field]) else {
            throw ToolError(message: "liveMatchup returned nothing")
        }
        return try json(result)
    }
}

// MARK: - Opponent meta capsules (the battle-static advisor prefix, m11)

/// Everything always-relevant about one opponent PREVIEW mon, pre-computed
/// at seed time (pilot's architecture guidance: deterministic context for
/// the always-relevant, tools for the combinatorial). Static per battle →
/// the rendered block is byte-identical across turns → prompt-cacheable.
nonisolated public struct OpponentCapsule: Sendable {
    public struct Stat: Sendable {
        public let name: String
        public let pct: Double
    }
    public let species: String
    public let types: [String]
    public let hasMeta: Bool
    public let winrate: Double?
    public let topMoves: [Stat]        // top 4 by usage
    public let topItems: [Stat]        // top 2
    public let topAbility: Stat?
    /// "physical" | "special" | "mixed" from the top meta moves' dex
    /// categories (m12-G) — what this species' ladder sets actually
    /// attack with; nil when no damaging meta moves are known.
    public let offenseBias: String?
    public let speedMin: Int?          // L50, 0 EVs, neutral nature
    public let speedMax: Int?          // L50, 252 EVs, +Spe nature
    /// m15-D: what the ladder ACTUALLY runs — top usage spread × top
    /// nature (the honest point between floor and ceiling), + its share.
    public let speedModal: Int?
    public let speedModalPct: Double?
    /// m15-D: ranked common partners from usage data (archetype signal —
    /// a Politoed whose partners are Ludicolo/Archaludon IS the rain core).
    public let teammates: [String]
    public let scarfPossible: Bool     // Choice Scarf ≥5% of usage items
    /// Set when the LIKELY ability blocks priority moves (Armor Tail,
    /// Dazzling, Queenly Majesty — battle 7's Farigiraf lesson).
    public let priorityBlockerLikely: String?
    public let defensive: [String: [String]]  // x4 / x2 / x05 / x025 / x0
}

nonisolated extension AdvisorToolExecutor {

    /// Build capsules for the opponent's preview species (bench included —
    /// the advisor should never be surprised by a switch-in).
    ///
    /// Output is DEDUPLICATED (a misread preview can repeat a species) and
    /// SORTED by canonical species name: the rendered static block must be
    /// byte-identical no matter which surface asks — preview consensus (row
    /// order) or reconciler (actives+bench order) — so a preview ask warms
    /// the same prompt cache every turn ask reads (m12-A).
    public func buildCapsules(species rawList: [String]) -> [OpponentCapsule] {
        var seen = Set<String>()
        let speciesList = rawList
            .map { resolve($0)?.name ?? $0 }
            .filter { seen.insert($0).inserted }
            .sorted()
        let brackets: [String: (min: Int, max: Int, modal: Int?, modalPct: Double?)] = {
            guard let rows = try? engine.speedBrackets(species: speciesList) else { return [:] }
            var out: [String: (min: Int, max: Int, modal: Int?, modalPct: Double?)] = [:]
            for row in rows {
                guard let s = row["species"] as? String,
                      let mn = row["min"] as? Int ?? (row["min"] as? Double).map(Int.init),
                      let mx = row["max"] as? Int ?? (row["max"] as? Double).map(Int.init)
                else { continue }
                let modal = row["modal"] as? Int ?? (row["modal"] as? Double).map(Int.init)
                let modalPct = row["modalPct"] as? Double ?? (row["modalPct"] as? Int).map(Double.init)
                out[s] = (mn, mx, modal, modalPct)
            }
            return out
        }()

        func topStats(_ dict: [String: Any]?, count: Int) -> [OpponentCapsule.Stat] {
            (dict ?? [:]).compactMap { key, value -> OpponentCapsule.Stat? in
                guard let pct = value as? Double ?? (value as? Int).map(Double.init) else { return nil }
                return .init(name: key, pct: pct)
            }
            // Deterministic order: usage desc, then name — the rendered block
            // must be byte-stable for prompt caching.
            .sorted { $0.pct != $1.pct ? $0.pct > $1.pct : $0.name < $1.name }
            .prefix(count).map { $0 }
        }

        return speciesList.map { raw in
            let entry = resolve(raw)
            let species = entry?.name ?? raw
            let types = entry?.types ?? []
            let profile = (try? engine.metaProfile(species: species)) ?? nil
            let moves = topStats(profile?["moves"] as? [String: Any], count: 4)
            let items = topStats(profile?["items"] as? [String: Any], count: 2)
            let ability = topStats(profile?["abilities"] as? [String: Any], count: 1).first
            // m15-B (the Solar Beam loss): Scarf tails hide OUTSIDE the
            // top-2 rendered items (Tyranitar's Scarf is 5.8%, #3) — scan
            // the FULL usage list, with a ≥5% floor so a trace share on an
            // overwhelmingly mega-stone mon (Gengar 2.1%) doesn't cry wolf.
            let scarfShare = (profile?["items"] as? [String: Any])?["Choice Scarf"]
                .flatMap { $0 as? Double ?? ($0 as? Int).map(Double.init) } ?? 0
            let defensive = types.isEmpty
                ? [:] : (try? engine.defensiveProfile(types: types)) ?? [:]
            // m12-G: which side of the special/physical split its ladder
            // sets attack from — dex categories of the damaging top moves.
            let damaging = (moves.isEmpty ? []
                : (try? engine.dexInfo(moves: moves.map(\.name)))?.moves ?? [])
                .filter { $0.known && $0.category != nil && $0.category != "Status" }
            let physical = damaging.filter { $0.category == "Physical" }.count
            let special = damaging.count - physical
            let offenseBias: String? = damaging.isEmpty ? nil
                : physical == 0 ? "special"
                : special == 0 ? "physical"
                : "mixed"
            return OpponentCapsule(
                species: species,
                types: types,
                hasMeta: profile != nil,
                winrate: profile?["winrate"] as? Double,
                topMoves: moves,
                topItems: items,
                topAbility: ability,
                offenseBias: offenseBias,
                speedMin: brackets[species]?.min,
                speedMax: brackets[species]?.max,
                speedModal: brackets[species]?.modal,
                speedModalPct: brackets[species]?.modalPct,
                teammates: (profile?["teammates"] as? [String])?.prefix(3).map { $0 } ?? [],
                scarfPossible: scarfShare >= 5,
                priorityBlockerLikely: ability.flatMap {
                    AdvisorContext.priorityBlockingAbilities.contains($0.name) ? $0.name : nil
                },
                defensive: defensive)
        }
    }
}
