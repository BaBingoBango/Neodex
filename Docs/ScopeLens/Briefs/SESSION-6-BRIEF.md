# ScopeLens — Session 6 kickoff (m11: the meta-aware agentic advisor)

Context (read in order — do not rediscover what's written down):
1. Project memory (auto-loads; current through PR #29 + battles 6–7).
2. `ScopeLens-Spec-v0.1.md` §1–2 (the grand vision) + §4.1 two-speed doctrine.
3. `Diagnostics/README.md` — m4 through m10 sections are the project's memory.
4. KEY ASSETS unchanged (battle .movs, native crops, harvest dirs — local,
   gitignored; `.env.local` key for CLI harnesses only).

## Where we are on the journey (read this framing first)

The grand vision (spec §1) is a **real-time, meta-aware battle analyzer and
assistant** — an observer that makes the game's hidden structure visible and
coaches genuinely good lines under the move timer. What exists today is the
**FOUNDATION, not the product**: the full pipeline (capture → OCR → state
machine → reconciler → deterministic engine → LLM advisor → overlay) runs
live end-to-end and has won real battles, but every layer is v1. This is NOT
polishing time — core capability gaps remain, and sessions should keep
building capability, not buffing chrome.

**Working elements (verified live, battles 4–7):** QuickTime-mirror capture
at 2fps; screen-state classifier (23/23 ×2 scales); team-preview species
voting with confirm-tap banking + `import-live` (bank: 27 species / 114
features); narration parser + legality-filter reconciler (37/37 fixtures;
auto-corrections proven twice in battle 6); Showdown-paste team management
feeding every surface with real EVs; @smogon/calc live matchup with KO
flags; single-shot Opus advisor with deterministic Fake-Out-legality +
priority callouts (PR #29); overlay HUD (built, unvalidated by pilot);
engine-as-MCP-server (6 tools, verify-all stage 6). `verify-all.sh` = 6
stages, all green.

**Known gaps ledger (carry this forward; grow/shrink it honestly):**
- Advisor is single-shot and shallowly meta-aware (the m11 core, below).
- Advisor doesn't know priority-BLOCKING abilities — battle 7's Farigiraf
  **Armor Tail stopped Fake Out cold** (also Dazzling, Queenly Majesty).
- Meta is a STATIC committed snapshot (Reg M-B S3, crawled 2026-07-02) —
  regulations rotate; see the new roadmap item below.
- Battle-start robustness: battle 7's tracker sat on "Waiting for a
  battle…" through team preview; the mid-battle narration bootstrap
  eventually caught it but with NO preview seed → all opponents were
  nickname-only entities and the matchup/advisor were degraded. Pilot also
  pressed Reset mid-battle (semantics under a live battle need defining).
- Suffix-truncated narration subjects mint phantom entities ("cineroar
  used Fake Out" → a duplicate entity beside Incineroar; m8's prefix-match
  doesn't cover suffix truncation).
- Duplicate `megaEvolved` events slipped the dedup window (battle 7,
  "Laemo Mega Evolved" ×2, 1.5s apart — investigate the parse key).
- Parser template gaps from battles 6–7 (exact texts below).
- Opponent summary-panel deep-parse mappings unmapped (HP format, status
  chips) — CORRECTION from the pilot: opponent summaries are NOT browsable
  in Team Preview; they ARE browsable in-battle → the frame-capture ask is
  "browse an opponent ACTIVE's summary during a battle."
- Species bank: 4 known eval misses (Scizor/Sylveon/Raichu/Milotic) +
  whatever new battles surface; taps + import-live are the pipe.
- teraType modeled but not calc'd; PP tracking absent; overlay
  glanceability verdict pending; advisor prompt-caching not yet done
  (folded into m11).

## Task A — m11 core: the agentic, meta-aware advisor

Pilot's vision (verbatim, battle 6): "this Pokémon likely uses X, so I
should do Y if that speed checks — run that tool — okay it does… now check
this damage and think about future turns." Pilot's architecture guidance
(adopted): pre-compute everything always-relevant into CACHED context;
tools for the combinatorial/hypothetical.

1. **Enrich the deterministic context** (AdvisorContext; battle-static
   prefix FIRST for prompt caching):
   - **Meta capsules for ALL SIX opponent preview mons** (bench included),
     from `metaProfile` at preview-seed time: top-4 moves w/ %, top-2
     items, top ability, winrate. Static per battle → byte-identical →
     cacheable. (Battle-6 proof: Kingambit runs Sucker Punch **99.5%** —
     the capsule makes that unmissable.)
   - **Speed brackets** for opponents (0-EV neutral min → 252 +nature max;
     flag Scarf when a top item) instead of the current false-precision
     point estimate.
   - **Defensive type profiles** per active (weak/resist/immune via
     typeEffect).
   - **Priority-blocker awareness** (battle 7): when an opposing active's
     known/likely ability ∈ {Armor Tail, Dazzling, Queenly Majesty},
     annotate "priority moves against this side FAIL" and carry the rule
     in the system prompt beside PR #29's Fake-Out/priority rules.
2. **Tool loop** (AdvisorClient): Anthropic Messages API tool-use loop
   reusing `Engine/mcp-server.js`'s six tool schemas as tool definitions,
   executed in-app against the same JSC engine. CONSULT THE claude-api
   SKILL FIRST (guardrail; m8 precedent). claude-opus-4-8, thinking
   adaptive EXPLICIT, parallel tool_results in ONE user message, max ~6
   iterations, cache_control on the stable prefix. Latency <25s; answer
   ≤3 sentences; return the tool trace for a "why" disclosure in Battle
   Log + overlay.
3. **Offline proof first**: extend AdvisorHarness — replay battle 5/6 to a
   decision point, real API call (.env.local), print capsule context +
   tool trace + advice. Not in verify-all (network/cost).

## Task B — parser + robustness gaps (battles 6–7, fixture-first)

Templates (fixtures from these EXACT reads; suite currently 37/37):
- "Incineroar cannot use Fake Out!" (move blocked — pair with the Armor
  Tail chip that precedes it)
- "The opposing Oranguru's Attack was not lowered!" (blocked stat drop)
- "The opposing Kingambit's Attack rose sharply!" (possessive +2 rise went
  UNRECOGNIZED while Defiant chip carried it — root-cause)
- "A critical hit on the opposing Oranguru!" (targeted crit note)
- "The opposing Sylveon was hurt by its poisoning!" (poison-tick wording)
Robustness:
- Suffix-truncation entity resolution ("cineroar" → Incineroar, not a
  phantom; extend m8's prefix-match doctrine, mind the nickname rules)
- megaEvolved dedup gap (battle 7 ×2) — inspect the parse key
- Battle-start detection: why did battle 7 never leave "Waiting for a
  battle…" until mid-battle? (Pilot lacks a recording — add diagnostics:
  the tracker should surface classifier state + preview-frame count live
  so the pilot can SEE what it thinks during preview.) Define Reset
  semantics during a live battle (fresh reconciler mid-battle should
  re-bootstrap cleanly, no phantom carry-over).

## Task C — NEW ROADMAP ITEM (pilot-requested): runtime meta refresh

Regulations rotate; a hardcoded snapshot goes stale. The injection seam
already exists (`ScopeEngine.setMeta`, built in m3 exactly for this) — the
missing pieces are fetch + cache + UI:
- Port/invoke the `Engine/fetch-meta.js` teammate-graph crawl from the app
  (politely: 2-concurrent, 200ms spacing, ToS posture documented) OR a
  scheduled CLI producing a cache the app watches.
- App Support cache with the bundled snapshot as fallback; staleness
  indicator + "Refresh meta" control in Settings; regulation label
  surfaced (current: Reg M-B S3).
- Keep the committed snapshot for harness reproducibility (pins in
  ScoutEngineHarness/mcp-server-test reference it — refreshing must not
  break parity checks; decouple "harness snapshot" from "app snapshot").

## Guardrails (all earned, m0–m10)

- verify-all (6 stages) green after every shared-code change; update
  fixture-count echoes.
- LOOK at real frames/reads before designing parsers; fixtures from exact
  recorded text; committed-sample regeneration uses its exact recorded
  invocation (`1=Farigiraf 2=Charizard 3=Pelipper 4=Archaludon`).
- Shared files Foundation-only; `nonisolated extension` in shared files
  (MainActor default isolation captures extensions silently).
- Engine rebuilds: pinned esbuild; copy dist to Resources. Meta/vocab
  refreshes are data swaps.
- claude-api skill BEFORE Anthropic-API code; adaptive thinking EXPLICIT.
- TCC: container reads from CLIs can hang uninterruptibly — the escape is
  Xcode RunCodeSnippet (runs in the APP's context); import-live has
  `--from`.
- `swiftc … | head` masks failures; never `&&` a harness onto a piped
  compile.
- Ethan's conversational reports are real bugs — 7 for 7 across sessions.
- Branch + PR per milestone; standing merge authorization in AGENTS.md.
  Externalize findings to Diagnostics/README.md + memory AS YOU GO.
