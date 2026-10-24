//
//  AdvisorClient.swift
//  Scope Lens
//
//  Phase 3, m8→m11: the opt-in LLM layer (spec §4.1), rebuilt as an AGENTIC
//  tool-use loop — the pilot's requested direction (battle 6, verbatim):
//  "this Pokémon likely uses X, so I should do Y if that speed checks — run
//  that tool — okay it does… now check this damage and think about future
//  turns." The model consults the six deterministic engine tools (the same
//  schemas the MCP server exposes) executed in-app against JavaScriptCore,
//  then answers in ≤3 sentences. The tool trace comes back for the UI's
//  "why" disclosure.
//
//  Prompt caching: tools + system prompt + the battle-static context block
//  are byte-stable within a battle, with cache_control breakpoints after
//  system (covers tools+system), after the static block, and rolling on the
//  newest tool_results — every call after the first reads the prefix from
//  cache instead of re-paying it.
//
//  Key resolution order:
//    1. Keychain (saved via the app's Settings pane)
//    2. ANTHROPIC_API_KEY in the process environment (Xcode scheme / CLI)
//  The key is never logged or included in errors.
//
//  Networking: plain URLSession; the app target enables the sandbox's
//  outgoing-connections entitlement (ENABLE_OUTGOING_NETWORK_CONNECTIONS).
//

import Foundation
import Security

// MARK: - Tool-loop data types

/// One tool invocation the model requested.
nonisolated public struct AdvisorToolCall: @unchecked Sendable {
    public let id: String
    public let name: String
    public let input: [String: Any]   // JSON-safe value types only
    public init(id: String, name: String, input: [String: Any]) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// The executed result for one call (mirrors a tool_result block).
nonisolated public struct AdvisorToolResult: Sendable {
    public let id: String
    public let text: String
    public let isError: Bool
    public init(id: String, text: String, isError: Bool) {
        self.id = id
        self.text = text
        self.isError = isError
    }
}

/// One line of the "why" trace: what the model checked and what came back.
nonisolated public struct AdvisorTraceEntry: Sendable, Identifiable {
    public let id = UUID()
    public let tool: String
    public let inputSummary: String
    public let resultSummary: String
    public let isError: Bool
}

/// One live readout event from the loop (m12-E): a display-ready line.
/// `replacesPrevious` marks a streaming update of the SAME activity — the
/// UI swaps its last line in place instead of appending (thinking/answer
/// text grows; tool calls and round-trip markers append).
nonisolated public struct AdvisorProgress: Sendable {
    public let line: String
    public let replacesPrevious: Bool
    public init(line: String, replacesPrevious: Bool) {
        self.line = line
        self.replacesPrevious = replacesPrevious
    }
}

/// The structured decision from `commit_play` (m12-F): what to input into
/// the game, one action per active — the UI renders these as bold chips
/// ABOVE the prose, so the pilot reads the play first and the why after.
/// Codable since m15-B: the archive stores the structured play (not just
/// display lines) so PlayLint can re-check archived decisions offline.
nonisolated public struct AdvisorPlay: Sendable, Codable {
    nonisolated public struct Action: Sendable, Identifiable, Codable {
        public let pokemon: String
        public let verb: String          // "move" | "switch"
        public let move: String?
        public let target: String?
        public let switchTo: String?
        public let mega: Bool
        public let note: String?
        public var id: String { pokemon + "·" + (move ?? switchTo ?? verb) }
        public init(pokemon: String, verb: String, move: String? = nil,
                    target: String? = nil, switchTo: String? = nil,
                    mega: Bool = false, note: String? = nil) {
            self.pokemon = pokemon
            self.verb = verb
            self.move = move
            self.target = target
            self.switchTo = switchTo
            self.mega = mega
            self.note = note
        }
        /// One glanceable line: "Charizard: Weather Ball → Gengar · Mega Evolve".
        public var displayLine: String {
            if verb == "switch" { return "\(pokemon): switch → \(switchTo ?? "?")" }
            var line = "\(pokemon): \(move ?? "?")"
            if let target, !target.isEmpty { line += " → \(target)" }
            if mega { line += " · Mega Evolve" }
            return line
        }
    }
    public let actions: [Action]

    public init(actions: [Action]) {
        self.actions = actions
    }

    /// Lenient decode — a malformed commit degrades to prose-only, never
    /// an error.
    init?(json: [String: Any]) {
        let actions = (json["actions"] as? [[String: Any]] ?? [])
            .compactMap { entry -> Action? in
                guard let pokemon = entry["pokemon"] as? String, !pokemon.isEmpty else {
                    return nil
                }
                return Action(
                    pokemon: pokemon,
                    verb: entry["action"] as? String ?? "move",
                    move: entry["move"] as? String,
                    target: entry["target"] as? String,
                    switchTo: entry["switch_to"] as? String,
                    mega: entry["mega"] as? Bool ?? false,
                    note: entry["note"] as? String)
            }
        guard !actions.isEmpty else { return nil }
        self.actions = actions
    }
}

/// The loop's outcome: the advice plus everything the UI and harness want
/// to disclose about how it was reached.
nonisolated public struct AgenticAdvice: Sendable {
    public let text: String
    /// The committed per-active decision (m12-F) — nil when the model
    /// answered in prose only (the UI falls back to text).
    public let play: AdvisorPlay?
    public let trace: [AdvisorTraceEntry]
    /// Thinking summaries, one per round-trip that thought (m12-E — the
    /// model's visible reasoning, `display: "summarized"`).
    public let thoughts: [String]
    /// m15-C: PlayLint findings for the FINAL committed play (empty when
    /// clean, prose-only, or no lint hook was supplied) — and whether a
    /// violating commit was bounced back for the one repair round-trip.
    public var lintFindings: [PlayLint.Finding] = []
    public var lintRepaired: Bool = false
    public let iterations: Int          // API round-trips
    public let elapsed: TimeInterval
    public let inputTokens: Int         // uncached input across the loop
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let cacheWriteTokens: Int
}

nonisolated public struct AdvisorClient: Sendable {

    public enum AdvisorError: Error, LocalizedError {
        case noAPIKey
        case httpError(Int, String)
        /// The detail names the actual shape (stop_reason + block mix) —
        /// "unexpected shape" with no detail cost a live-battle diagnosis
        /// (battle 9: every ask died and the pilot could only paraphrase).
        case badResponse(String)
        case refused

        public var errorDescription: String? {
            switch self {
            case .noAPIKey:
                "No API key — add your Anthropic key in Settings (⌘,) or set ANTHROPIC_API_KEY."
            case .httpError(let code, let message):
                "API error \(code): \(message)"
            case .badResponse(let detail):
                "Unexpected API response shape (\(detail))."
            case .refused:
                "The model declined to answer this request."
            }
        }
    }

    /// Opus 4.8 with adaptive thinking at low effort: sharp advice inside
    /// the ~40s move-timer budget. max_tokens leaves headroom for (billed,
    /// full-length) thinking + tool-call JSON per iteration; the system
    /// prompt caps the visible answer at 3 sentences. Battle 9 (m13-E):
    /// adaptive thinking's LENGTH is not pinned by effort — a complex board
    /// thought past the old 2000 before emitting any answer block, killing
    /// every ask with stop max_tokens (the m8 lesson, third recurrence).
    /// The loop also retries ONCE with a doubled budget if truncation
    /// still hits.
    public var model: String = "claude-opus-4-8"
    public var maxTokens = 4000
    /// m15-E A/B RESULT (2026-07-13, two 4/4 eval passes): TURN asks run
    /// with thinking DISABLED — the only arm that never breached the ~40s
    /// move timer (5.5–23.6s incl. repair bounces, vs 19.8–136s adaptive)
    /// AND went 4/4. With m15's flags + lint doing the deterministic
    /// deliberation, the model doesn't need private thinking on a 40s
    /// clock; PREVIEW keeps adaptive (90s budget, deliberation earns it —
    /// see forPreview). budget_tokens is REMOVED on Opus 4.8/Sonnet 5
    /// (400) — effort is the only depth lever. Changing these mid-battle
    /// only invalidates the messages cache tier, not tools+system.
    public var thinkingMode: String = "disabled"
    public var effort: String = "low"
    /// Round-trip cap for the tool loop (the brief's ~6).
    public var maxIterations = 6
    /// Wall-clock budget. Past `softDeadline` the next request forces a
    /// final answer (tool_choice: none); each REQUEST times out at
    /// `hardTimeout` (a single round-trip must be allowed to run past the
    /// soft deadline — the preview scout's first response can think for
    /// 20s+ before its tool calls arrive).
    public var softDeadline: TimeInterval = 18
    public var hardTimeout: TimeInterval = 25

    public init() {}

    /// Budgets for a TEAM PREVIEW ask (m12-A): preview is decided once with
    /// ~90s of game-side thinking time, so the loop gets more round-trips
    /// and wall-clock than a mid-battle turn. Effort stays low — the same
    /// request shape as turn asks keeps round-trips snappy and the prompt
    /// cache shared across both modes.
    public static func forPreview() -> AdvisorClient {
        var client = AdvisorClient()
        client.maxIterations = 8
        client.softDeadline = 28
        client.hardTimeout = 35
        client.maxTokens = 6000   // preview boards legitimately think longer
        // m15-E: preview KEEPS adaptive thinking — the 90s preview budget
        // affords deliberation, and preview has no commit_play timer risk.
        client.thinkingMode = "adaptive"
        return client
    }

    // MARK: Key storage (Keychain)

    static let keychainService = "com.babingobango.ScopeLens.advisor"
    static let keychainAccount = "anthropic-api-key"

    public static func savedKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    public static func saveKey(_ key: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(base as CFDictionary)
        guard !key.isEmpty else { return true }   // empty = clear
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    /// Keychain first, environment second (dev runs / CLI harness).
    public static func resolveKey() -> String? {
        savedKey() ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"].flatMap {
            $0.isEmpty ? nil : $0
        }
    }

    public static var hasKey: Bool { resolveKey() != nil }

    // MARK: The agentic call (m11)

    /// One advisor tool-use loop — a "what's the play" turn ask by default;
    /// the preview scout passes its own label/question (m12-A).
    ///
    /// - Parameters:
    ///   - staticContext: the battle-static block (team + meta capsules) —
    ///     byte-identical across a battle's asks, so it prompt-caches (and
    ///     is SHARED between preview and turn asks).
    ///   - turnContext: the volatile block (turn state, or the preview
    ///     baseline block).
    ///   - tools: Anthropic-shaped tool definitions (AdvisorToolCatalog).
    ///   - volatileLabel: heading for the volatile block — matches the two
    ///     modes the system prompt defines.
    ///   - question: the ask appended after the volatile block.
    ///   - apiKey: overrides resolution (the CLI harness passes .env.local's).
    ///   - lintPlay: m15-C, the verify-and-repair hook — deterministic
    ///     PlayLint findings for a committed play. A commit with VIOLATIONS
    ///     is bounced back ONCE in its own tool_result ("REJECTED — …") for
    ///     a repair round-trip on the warm cache; a still-violating
    ///     re-commit ships with the findings attached (surfaced, never
    ///     looped). Advisories never bounce.
    ///   - onProgress: live readout events (m12-E) — thinking summaries as
    ///     they stream, tool calls as they form, round-trip markers. Called
    ///     on the streaming task; hop actors in the closure if needed.
    ///   - runTools: executes a batch of tool calls (the app hops onto the
    ///     engine actor; the harness calls the executor directly).
    public func advise(staticContext: String,
                       turnContext: String,
                       tools: [[String: Any]],
                       volatileLabel: String = "CURRENT TURN",
                       question: String = "What's the play?",
                       apiKey: String? = nil,
                       lintPlay: (@Sendable (AdvisorPlay) -> [PlayLint.Finding])? = nil,
                       onProgress: (@Sendable (AdvisorProgress) -> Void)? = nil,
                       runTools: @Sendable ([AdvisorToolCall]) async -> [AdvisorToolResult])
        async throws -> AgenticAdvice {
        guard let key = apiKey ?? Self.resolveKey() else { throw AdvisorError.noAPIKey }
        let start = Date()

        // The first user turn: static prefix block (cache breakpoint 2 —
        // breakpoint 1 rides the system prompt and covers the tools array
        // too), then the volatile block.
        var messages: [[String: Any]] = [[
            "role": "user",
            "content": [
                [
                    "type": "text",
                    "text": "BATTLE-STATIC CONTEXT\n\(staticContext)",
                    "cache_control": ["type": "ephemeral"],
                ],
                [
                    "type": "text",
                    "text": "\(volatileLabel)\n\(turnContext)\n\n\(question)",
                ],
            ],
        ]]

        var trace: [AdvisorTraceEntry] = []
        var thoughts: [String] = []
        var committedPlay: AdvisorPlay?
        var iterations = 0
        var inputTokens = 0, outputTokens = 0, cacheRead = 0, cacheWrite = 0
        var forceAnswer = false
        // m13-E: one budget-doubling retry when thinking eats max_tokens
        // before any answer block (battle 9's live failure mode).
        var tokenBudget = maxTokens
        var budgetRetried = false
        // m15-C: the verify-and-repair state — findings for the standing
        // play, and whether the single rejection bounce is spent.
        var lintFindings: [PlayLint.Finding] = []
        var lintRepairUsed = false

        while true {
            iterations += 1
            onProgress?(AdvisorProgress(
                line: "→ round-trip \(iterations)…", replacesPrevious: false))
            let response = try await postStreaming(
                key: key, tools: tools, messages: messages,
                toolChoice: forceAnswer ? ["type": "none"] : nil,
                budget: tokenBudget,
                onProgress: onProgress)

            if let usage = response["usage"] as? [String: Any] {
                inputTokens += usage["input_tokens"] as? Int ?? 0
                outputTokens += usage["output_tokens"] as? Int ?? 0
                cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
                cacheWrite += usage["cache_creation_input_tokens"] as? Int ?? 0
            }
            let stopReason = response["stop_reason"] as? String ?? ""
            let content = response["content"] as? [[String: Any]] ?? []
            let text = content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // The round-trip's visible reasoning (display: summarized) —
            // kept for the post-hoc why-trace.
            thoughts.append(contentsOf: content
                .filter { $0["type"] as? String == "thinking" }
                .compactMap { $0["thinking"] as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })

            switch stopReason {
            case "refusal":
                throw AdvisorError.refused

            case "tool_use":
                let calls = content
                    .filter { $0["type"] as? String == "tool_use" }
                    .compactMap { block -> AdvisorToolCall? in
                        guard let id = block["id"] as? String,
                              let name = block["name"] as? String else { return nil }
                        return AdvisorToolCall(
                            id: id, name: name,
                            input: block["input"] as? [String: Any] ?? [:])
                    }
                guard !calls.isEmpty else {
                    throw AdvisorError.badResponse("stop tool_use, no parseable calls; blocks: "
                        + Self.blockMix(content))
                }

                // Echo the assistant content VERBATIM (thinking blocks and
                // their signatures included — the API requires them intact
                // when continuing on the same model).
                messages.append(["role": "assistant", "content": content])

                // m12-F: commit_play is OURS — record it locally (latest
                // call wins), never send it to the engine.
                let commits = calls.filter { $0.name == "commit_play" }
                let engineCalls = calls.filter { $0.name != "commit_play" }
                if let commit = commits.last {
                    committedPlay = AdvisorPlay(json: commit.input) ?? committedPlay
                    onProgress?(AdvisorProgress(line: "🎯 play committed", replacesPrevious: false))
                    for call in commits {
                        trace.append(AdvisorTraceEntry(
                            tool: "commit_play",
                            inputSummary: Self.compactJSON(call.input, limit: 160),
                            resultSummary: AdvisorPlay(json: call.input) == nil
                                ? "unparseable — falling back to prose" : "recorded",
                            isError: false))
                    }
                }

                // m15-C: verify the fresh commit against the deterministic
                // rules. Violations bounce ONCE — the rejection rides the
                // commit's own tool_result, so the repair costs a single
                // round-trip on the warm cache. A repeat offender ships
                // with its findings attached (surfaced, never looped).
                var rejection: String?
                if !commits.isEmpty, let play = committedPlay, let lintPlay {
                    lintFindings = lintPlay(play)
                    let violations = lintFindings.filter { $0.severity == .violation }
                    if !violations.isEmpty, !lintRepairUsed {
                        lintRepairUsed = true
                        rejection = "REJECTED — this play violates deterministic game rules:\n"
                            + violations.map { "• [\($0.rule)] \($0.message)" }.joined(separator: "\n")
                            + "\nReconsider and call commit_play again (the latest call wins). "
                            + "These are rule violations, not style notes — the flagged action "
                            + "will not do what you intend."
                        trace.append(AdvisorTraceEntry(
                            tool: "play_lint",
                            inputSummary: violations.map(\.rule).joined(separator: ", "),
                            resultSummary: "rejected — repair round-trip requested",
                            isError: true))
                        onProgress?(AdvisorProgress(
                            line: "🧯 play breaks \(violations.count) rule\(violations.count == 1 ? "" : "s") — asking for a repair",
                            replacesPrevious: false))
                    } else if !violations.isEmpty {
                        trace.append(AdvisorTraceEntry(
                            tool: "play_lint",
                            inputSummary: violations.map(\.rule).joined(separator: ", "),
                            resultSummary: "still violating after repair — shipping with warnings",
                            isError: true))
                    }
                }

                // Decision committed, no checks pending, reasoning already
                // in the same response → DONE, zero extra round-trips (the
                // instructed fast path). A rejected play skips the fast
                // path — the repair round-trip must happen.
                if engineCalls.isEmpty, committedPlay != nil, !text.isEmpty, rejection == nil {
                    return AgenticAdvice(
                        text: text, play: committedPlay, trace: trace,
                        thoughts: thoughts,
                        lintFindings: lintFindings, lintRepaired: lintRepairUsed,
                        iterations: iterations,
                        elapsed: Date().timeIntervalSince(start),
                        inputTokens: inputTokens, outputTokens: outputTokens,
                        cacheReadTokens: cacheRead, cacheWriteTokens: cacheWrite)
                }

                let results = await runTools(engineCalls)
                if !engineCalls.isEmpty {
                    onProgress?(AdvisorProgress(
                        line: "⚙️ \(engineCalls.count) engine check\(engineCalls.count == 1 ? "" : "s") ran — results returned",
                        replacesPrevious: false))
                }
                for (call, result) in zip(engineCalls, results) {
                    trace.append(AdvisorTraceEntry(
                        tool: call.name,
                        inputSummary: Self.compactJSON(call.input, limit: 160),
                        resultSummary: Self.summarize(result.text, limit: 220),
                        isError: result.isError))
                }

                // ALL results in ONE user message (parallel tool use), in
                // the ORIGINAL call order — every tool_use id must get a
                // result, commit_play included (answered locally).
                // Rolling cache breakpoint on the newest results; the prior
                // rolling marker is stripped so the request never exceeds
                // the 4-breakpoint cap (system + static + this one = 3).
                stripRollingBreakpoint(&messages)
                let resultById = Dictionary(results.map { ($0.id, $0) }) { a, _ in a }
                let lastCommitID = commits.last?.id
                var blocks: [[String: Any]] = calls.map { call in
                    if call.name == "commit_play" {
                        // m15-C: a rejected play's verdict rides the LAST
                        // commit's tool_result (that's the standing play);
                        // earlier same-response commits stay "recorded".
                        var content = engineCalls.isEmpty
                            ? "Recorded. Now give your reasoning — nothing else to run."
                            : "Recorded — if the pending check results change your mind, call commit_play again (the latest call wins)."
                        if let rejection, call.id == lastCommitID {
                            content = rejection
                        }
                        return [
                            "type": "tool_result",
                            "tool_use_id": call.id,
                            "content": content,
                        ]
                    }
                    var block: [String: Any] = [
                        "type": "tool_result",
                        "tool_use_id": call.id,
                        "content": resultById[call.id]?.text ?? "Error: tool produced no result",
                    ]
                    if resultById[call.id]?.isError == true { block["is_error"] = true }
                    return block
                }
                // Out of budget or iterations → demand the answer alongside
                // the last results, with tools disabled on the next call.
                // A rejection round keeps tools ENABLED (the repair needs
                // commit_play); the one-bounce cap bounds the extra cost.
                forceAnswer = rejection == nil
                    && (iterations >= maxIterations - 1
                        || Date().timeIntervalSince(start) > softDeadline)
                if forceAnswer {
                    onProgress?(AdvisorProgress(
                        line: "⏱ budget reached — requesting the final answer",
                        replacesPrevious: false))
                    blocks.append(["type": "text",
                                   "text": "No more tool calls — give your final answer now with what you have."])
                }
                if var last = blocks.last {
                    last["cache_control"] = ["type": "ephemeral"]
                    blocks[blocks.count - 1] = last
                }
                messages.append(["role": "user", "content": blocks])

            case "pause_turn":
                // Server paused mid-turn (no client tools pending) — echo
                // the assistant content and continue.
                messages.append(["role": "assistant", "content": content])

            default:
                // end_turn (or max_tokens with usable text) — done.
                guard !text.isEmpty else {
                    // Truncated mid-thinking (or mid-tool-JSON): nothing
                    // usable AND nothing echoable — an unfinished thinking
                    // block has no signature, so the turn is DISCARDED and
                    // re-asked once with double the budget. The warm prompt
                    // cache makes the retry's input nearly free.
                    if stopReason == "max_tokens", !budgetRetried {
                        budgetRetried = true
                        tokenBudget *= 2
                        onProgress?(AdvisorProgress(
                            line: "⚠️ thinking ate the token budget — retrying at \(tokenBudget)",
                            replacesPrevious: false))
                        continue
                    }
                    throw AdvisorError.badResponse("stop \(stopReason.isEmpty ? "none" : stopReason), "
                        + "empty answer; blocks: " + Self.blockMix(content))
                }
                return AgenticAdvice(
                    text: text, play: committedPlay, trace: trace,
                    thoughts: thoughts,
                    lintFindings: lintFindings, lintRepaired: lintRepairUsed,
                    iterations: iterations,
                    elapsed: Date().timeIntervalSince(start),
                    inputTokens: inputTokens, outputTokens: outputTokens,
                    cacheReadTokens: cacheRead, cacheWriteTokens: cacheWrite)
            }

            // Backstop: never loop past the iteration cap + the forced turn
            // (+1 headroom when a lint repair spent a round-trip).
            if iterations > maxIterations + (lintRepairUsed ? 2 : 1) {
                throw AdvisorError.badResponse("loop exceeded \(maxIterations + (lintRepairUsed ? 2 : 1)) round-trips")
            }
        }
    }

    // MARK: Request plumbing (SSE streaming since m12-E)

    /// One streaming Messages request. Accumulates the SSE events back into
    /// the exact `{content, stop_reason, usage}` shape the non-streaming
    /// response had, so the loop above is unchanged — and emits live
    /// progress while blocks stream in. Accumulation rules (per the API):
    /// `thinking_delta` grows `thinking`, `signature_delta` grows the
    /// block's `signature` (echoed verbatim on the next round-trip),
    /// `input_json_delta` buffers `partial_json` until `content_block_stop`
    /// parses it into the tool_use `input`.
    private func postStreaming(key: String, tools: [[String: Any]],
                               messages: [[String: Any]],
                               toolChoice: [String: Any]?,
                               budget: Int,
                               onProgress: (@Sendable (AdvisorProgress) -> Void)?)
        async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        // With SSE this is an IDLE timeout between chunks, not wall-clock —
        // tokens flow continuously, so a stall past this means a dead link.
        request.timeoutInterval = hardTimeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": model,
            "max_tokens": budget,
            "stream": true,
            // Adaptive thinking, explicitly: on Opus 4.8 omitting the field
            // runs WITHOUT thinking; low effort keeps each round-trip snappy
            // and the tool calls consolidated. display: summarized makes the
            // reasoning VISIBLE (the Opus 4.8 default is "omitted" — empty
            // thinking text), which feeds the live readout and why-trace.
            // m15-E: mode and effort are knobs now — the eval A/B measures
            // them; the defaults above ship.
            "thinking": thinkingMode == "disabled"
                ? ["type": "disabled"]
                : ["type": "adaptive", "display": "summarized"],
            "output_config": ["effort": effort],
            "tools": tools,
            // Breakpoint 1 on the system block caches tools + system
            // together (render order is tools → system → messages).
            "system": [[
                "type": "text",
                "text": AdvisorContext.systemPrompt,
                "cache_control": ["type": "ephemeral"],
            ]],
            "messages": messages,
        ]
        if let toolChoice { body["tool_choice"] = toolChoice }
        // sortedKeys: deterministic bytes — a silently reordered JSON body
        // is the classic prompt-cache invalidator.
        request.httpBody = try JSONSerialization.data(
            withJSONObject: body, options: [.sortedKeys])

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AdvisorError.badResponse("non-HTTP transport response")
        }
        guard http.statusCode == 200 else {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count > 65_536 { break }
            }
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? "no detail"
            throw AdvisorError.httpError(http.statusCode, message)
        }

        var blocks: [[String: Any]] = []
        var toolJSON: [Int: String] = [:]
        var stopReason = ""
        var usage: [String: Any] = [:]
        var lastLiveEmit = Date.distantPast

        // Live tail of a growing string, one display line.
        func tail(_ s: String, _ limit: Int) -> String {
            let flat = s.replacingOccurrences(of: "\n", with: " ")
            return flat.count <= limit ? flat : "…" + String(flat.suffix(limit))
        }
        func emitLive(_ line: String) {
            guard Date().timeIntervalSince(lastLiveEmit) > 0.25 else { return }
            lastLiveEmit = Date()
            onProgress?(AdvisorProgress(line: line, replacesPrevious: true))
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            guard let event = try? JSONSerialization.jsonObject(
                      with: Data(line.dropFirst(6).utf8)) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "message_start":
                usage = (event["message"] as? [String: Any])?["usage"] as? [String: Any] ?? [:]

            case "content_block_start":
                guard let idx = event["index"] as? Int,
                      var block = event["content_block"] as? [String: Any] else { continue }
                if block["type"] as? String == "tool_use" {
                    toolJSON[idx] = ""
                    block["input"] = [String: Any]()
                }
                while blocks.count <= idx { blocks.append([:]) }
                blocks[idx] = block
                switch block["type"] as? String {
                case "thinking":
                    onProgress?(AdvisorProgress(line: "🧠 thinking…", replacesPrevious: false))
                case "text":
                    onProgress?(AdvisorProgress(line: "✍️ writing the answer…", replacesPrevious: false))
                case "tool_use":
                    let name = block["name"] as? String ?? "tool"
                    onProgress?(AdvisorProgress(
                        line: name == "commit_play" ? "🎯 deciding the play…" : "⚙️ \(name)…",
                        replacesPrevious: false))
                default: break
                }

            case "content_block_delta":
                guard let idx = event["index"] as? Int, idx < blocks.count,
                      let delta = event["delta"] as? [String: Any],
                      let dtype = delta["type"] as? String else { continue }
                switch dtype {
                case "thinking_delta":
                    let grown = (blocks[idx]["thinking"] as? String ?? "")
                        + (delta["thinking"] as? String ?? "")
                    blocks[idx]["thinking"] = grown
                    emitLive("🧠 \(tail(grown, 90))")
                case "signature_delta":
                    blocks[idx]["signature"] = (blocks[idx]["signature"] as? String ?? "")
                        + (delta["signature"] as? String ?? "")
                case "text_delta":
                    let grown = (blocks[idx]["text"] as? String ?? "")
                        + (delta["text"] as? String ?? "")
                    blocks[idx]["text"] = grown
                    emitLive("✍️ \(tail(grown, 90))")
                case "input_json_delta":
                    toolJSON[idx, default: ""] += delta["partial_json"] as? String ?? ""
                default:
                    break   // unknown delta kinds ride along untouched
                }

            case "content_block_stop":
                guard let idx = event["index"] as? Int, idx < blocks.count else { continue }
                if let buffered = toolJSON.removeValue(forKey: idx) {
                    let parsed = buffered.isEmpty ? [:]
                        : (try? JSONSerialization.jsonObject(with: Data(buffered.utf8)))
                            as? [String: Any] ?? [:]
                    blocks[idx]["input"] = parsed
                    let name = blocks[idx]["name"] as? String ?? "?"
                    onProgress?(AdvisorProgress(
                        line: "\(name == "commit_play" ? "🎯" : "⚙️") \(name)(\(Self.compactJSON(parsed, limit: 80)))",
                        replacesPrevious: true))
                }

            case "message_delta":
                if let delta = event["delta"] as? [String: Any],
                   let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }
                if let outputUsage = event["usage"] as? [String: Any] {
                    for (k, v) in outputUsage { usage[k] = v }
                }

            case "error":
                let message = (event["error"] as? [String: Any])?["message"] as? String
                    ?? "stream error"
                throw AdvisorError.httpError(200, message)

            default:
                break   // ping / message_stop
            }
        }

        return ["content": blocks, "stop_reason": stopReason, "usage": usage]
    }

    /// Remove the previous rolling cache_control marker (tool_result blocks
    /// only — the static-context marker in the first user message stays).
    private func stripRollingBreakpoint(_ messages: inout [[String: Any]]) {
        for i in messages.indices.dropFirst() {
            guard messages[i]["role"] as? String == "user",
                  var content = messages[i]["content"] as? [[String: Any]] else { continue }
            var changed = false
            for j in content.indices where content[j]["cache_control"] != nil {
                content[j].removeValue(forKey: "cache_control")
                changed = true
            }
            if changed { messages[i]["content"] = content }
        }
    }

    // MARK: Trace formatting

    static func compactJSON(_ object: [String: Any], limit: Int) -> String {
        let data = (try? JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys])) ?? Data()
        let s = String(data: data, encoding: .utf8) ?? ""
        return summarize(s, limit: limit)
    }

    static func summarize(_ s: String, limit: Int) -> String {
        let flat = s.replacingOccurrences(of: "\n", with: " ")
        return flat.count <= limit ? flat : String(flat.prefix(limit)) + "…"
    }

    /// Compact census of a response's content blocks for error details:
    /// "thinking(1843ch), text(0ch)".
    static func blockMix(_ content: [[String: Any]]) -> String {
        guard !content.isEmpty else { return "none" }
        return content.map { block in
            let type = block["type"] as? String ?? "?"
            let size = (block["thinking"] as? String)?.count
                ?? (block["text"] as? String)?.count
            return size.map { "\(type)(\($0)ch)" } ?? type
        }.joined(separator: ", ")
    }
}
