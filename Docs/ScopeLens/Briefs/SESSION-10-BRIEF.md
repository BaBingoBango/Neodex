# ScopeLens — Session 10 kickoff (m15: the advisor becomes a meta expert)

Context (read in order — do not rediscover what's written down):
1. Project memory (auto-loads; current through PR #55 / m14-B).
2. `Diagnostics/README.md` — m13-A through m14-B are the freshest sections;
   m13-E (thinking-budget drift) and m14-B (doomed-slot axiom) are REQUIRED
   reading for this arc.
3. `BACKLOG.md` — the dev queue this session executes.
4. KEY ASSETS: battle .movs (local, gitignored), `.env.local` key for CLI
   harnesses, and NEW since m13-C — **the pilot's live BattleArchive records**
   (`~/Library/Containers/com.ethan-marshall.Scope-Lens/Data/Library/`
   `Application Support/BattleArchive/*.json`; TCC applies — read via Xcode
   RunCodeSnippet or ask the pilot to export).

## Why this session exists (the pilot's ask, 2026-07-13)

> "…bizarre moves from the advisor like it trying to 'cash in' my Charizard
> by having it use Solar Beam while at the same time understanding that it
> was going to get 'outsped' and die anyway (exactly what happened) …
> maybe the advisor deserves its own session … to help it become more of a
> meta expert."

m14-B shipped the immediate axiom (doomed-slot flag + turn-order doctrine,
proven on battle-5 t=260 real-API). But that was ONE failure class, patched
reactively. The agreed dev queue's next items exist precisely to make this
systematic: **an eval set turns advisor quality from anecdotes into a
number**, and every doctrine/prompt/effort change thereafter is gated on
that number instead of vibes. This is capability work, not polish.

## Task A — the eval set (dev queue item 2; unblocked by m13-C)

1. **Verdict capture first** (small app feature, do it before anything
   else so every pilot battle starts producing labels): 👍/👎 (+ optional
   one-line note) per decision point in the Battle Archive review window,
   persisted onto the `BattleRecord.AdviceEntry` (schema: add
   `verdict: String?` + `verdictNote: String?`; store needs an update/
   re-save API — records are single JSON files, decode-mutate-rewrite).
2. **EvalHarness** (`Diagnostics/`): replays archived decision points —
   rebuild the ask (static context from the record's rosters + the turn
   context from its log tail) → run the REAL advisor loop → score. Two
   scoring tiers: (a) pilot verdicts where present (ground truth), (b)
   deterministic assertions where derivable (committed play must not
   violate: doomed-slot attacks, illegal Fake Out, priority into a blocker,
   Choice-lock contradictions, attacking a mon that's already guaranteed
   dead to your partner's committed KO…). Tier (b) is a LINT over
   commit_play — cheap, objective, and runs on every archived decision
   even without verdicts.
3. **Seed cases**: the Solar Beam battle (pilot's archive should hold it —
   eval case #1); battle-5 t=260 (doomed slot, now-fixed — the regression
   pin); battle-4 t=240 (correctly-unflagged control); battle-9's dead-ask
   board (m13-E budget regression pin, cheap to keep).
4. **Report format**: pass/fail per case + a one-line reason, echoed like
   verify-all stages. NOT in verify-all (network/cost) — a separate
   `Diagnostics/eval-advisor.sh`, run deliberately.

## Task B — eval-gated expertise (the "deep ruleset" the pilot asked for in m12-F)

With the eval green as the floor, THEN deepen: expand DOUBLES DOCTRINE
(positioning, sack-vs-preserve math, Tailwind race timing, redirection
value, when to double-Protect), richer capsule facts if the eval shows
misses (e.g. common EV benchmarks), and commit_play lint rules promoted
into the system prompt where the model keeps tripping them. EVERY change
must move the eval or it reverts — that's the whole discipline. Watch the
prompt-cache: the system prompt is one cached block; batch doctrine edits.

## Task C — effort A/B (dev queue item 4; m13-E made it urgent)

Thinking length drifted long (39–53s asks on hard boards vs the ~40s move
timer). A/B on the eval set: adaptive-low (current) vs
`thinking: enabled + budget_tokens` tiers (e.g. 1200/2500) vs higher
effort — score × latency. Consult the claude-api skill BEFORE touching
request shapes. Deliverable: a chosen default + a written latency budget.

## Stretch — archetype playbooks / follow-up dialogue (queue items 3+5)

Only if A–C land green: per-archetype capsule addenda (rain, TR,
perish-trap — battle 5 IS the perish playbook case), and the "why not
Protect here?" follow-up turn (needs conversation continuity on the same
cached prefix — cheap tokens, new UI).

## Pilot actions

1. Play with the m14-B build; note any remaining "bizarre move" verbatim —
   each one becomes an eval case.
2. Once Task A.1 lands: 👍/👎 the archived decision points after each
   session (30 seconds; it's the label supply).
3. The archive export question: if TCC blocks the harness from reading the
   container, use the archive window's Copy/… affordances or approve the
   one-time consent.

## Guardrails (all earned; the m13/m14 additions in bold)

- verify-all 6/6 after every shared-code change (fixtures currently 57/57);
  **the gate itself was caught lying in m13-C — if you touch it, sim-prove
  a failing stage trips it (errexit AND-list exemption + pipefail lesson)**.
- **Model behavior drifts across weeks (m13-E): a passing real-API proof
  from N days ago does not pin today's behavior — re-repro offline before
  code archaeology, and make error strings carry the evidence (stop
  reason + block census).**
- Fixture-first from EXACT reads for anything parser-adjacent; committed
  samples regenerate only with their recorded invocations.
- claude-api skill BEFORE Anthropic-API changes; adaptive thinking
  explicit; parallel tool_results in ONE user message; `.sortedKeys`
  bodies; thinking blocks echoed verbatim — **and truncated thinking can
  NEVER be echoed (unsigned): discard the turn, retry fresh on the warm
  cache (m13-E)**.
- Shared files Foundation-only; `nonisolated` on every shared-file type,
  extension, and nested conformance.
- Stale-instance discipline: pilot reports of "missing feature" start at
  the build stamp.
- Ethan's conversational reports are real bugs — 10-for-10 across sessions
  (battle 9's "unexpected shape" + the Solar Beam forfeit both root-caused
  same-day).
- Branch + PR per milestone; findings to Diagnostics/README.md + memory AS
  YOU GO; BACKLOG.md is the deferred-work ledger.
