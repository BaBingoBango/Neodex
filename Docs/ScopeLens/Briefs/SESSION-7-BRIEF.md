# ScopeLens — Session 7 kickoff (m12: the preview scout goes agentic + the engine learns to read damage)

Context (read in order — do not rediscover what's written down):
1. Project memory (auto-loads; current through PR #35 + the session-6 postscript).
2. `ScopeLens-Spec-v0.1.md` §1–2 (the grand vision) + §4.1 two-speed doctrine.
3. `Diagnostics/README.md` — m4 through m11-C sections are the project's memory;
   m11-A/B/C are the freshest and describe everything session 6 built.
4. KEY ASSETS unchanged (battle .movs, native crops, harvest dirs — local,
   gitignored; `.env.local` key for CLI harnesses only).

## Where we are on the journey (read this framing first)

The grand vision (spec §1) is a **real-time, meta-aware battle analyzer and
assistant**. After session 6 the foundation is thick: the full pipeline
(capture → OCR → state machine → reconciler → deterministic engine → AGENTIC
LLM advisor → overlay) is built, offline-proven, and self-refreshing (meta),
with the parser hardened against everything battles 1–7 threw at it. What's
NOT built yet is the frontier: the highest-leverage decision of every battle
(team preview) still runs on a crude m3 heuristic, and the engine never
LEARNS from what it watches (observed damage carries spread/item information
nobody extracts). This is still capability-building time, not polish time.

**Working elements (verified; battles 1–7 + offline proofs):**
- QuickTime-mirror capture at 2fps; classifier 23/23 ×2 scales; preview
  species voting + confirm-tap banking + `import-live` (27 species / 114
  features; 4 known eval misses await real taps).
- Parser + reconciler: **44/44 fixtures** — m11-B added moveBlocked,
  blocked-drop, adverb-either-side stat changes, targeted crit, "its
  poisoning", suffix-truncation resolution, mega legality dedup; battle-start
  diagnostics ("tracker sees: …" in Battle Log + overlay) and defined
  Reset-mid-battle semantics (re-seed from current consensus iff the old
  reconciler had a preview seed).
- Team management (Showdown paste, Settings ⌘, → Team; real EVs everywhere).
- Live Matchup (@smogon/calc, KO flags vs current HP, TR-aware speeds).
- **AGENTIC advisor (m11-A)**: Anthropic tool-use loop (claude-opus-4-8,
  adaptive thinking explicit, ≤6 round-trips, 18s soft deadline) over the six
  engine tools executed in-app (JSC); battle-static META CAPSULES for every
  known opponent (top-4 moves %, top-2 items, top ability, winrate, L50 speed
  BRACKETS + Scarf flag, defensive typing, priority-blocker flags); why-trace
  in Battle Log ("why — N engine checks") + overlay 🔧 line. Offline-proven:
  zero-tool fast path 9–11s; nudged 3-parallel-damage_calc round 18.9s;
  prompt cache measured (6,553-token prefix: write once, read thereafter,
  cross-battle tools+system reuse 5,128).
- Overlay HUD — **seen live once (pilot liked it)**; formal glanceability
  verdict still open.
- Engine-as-MCP-server (six tools; schemas now in `Engine/tool-schemas.json`,
  the single source both the server and the app load) = verify-all stage 6.
- **Runtime meta refresh (m11-C)**: Settings ⌘, → Meta tab — regulation
  DISCOVERED from Pikalytics' format selector (never hardcoded), polite
  crawl (2×200ms, 400-page fuse, pilot-action only), App Support cache with
  <40-profile clobber guard, `setMeta` hot swap into the live JSC engine,
  staleness badge. Committed snapshot stays the harness pin.
- Build stamp (executable mtime) in Live Tracker header + Meta tab footer —
  the stale-instance detector (that failure mode ate two feature reveals).
- `verify-all.sh` = 6 stages, all green, app build warning-free.

**Known gaps ledger (carry forward; grow/shrink honestly):**
- **The AGENTIC advisor has never run live.** The pilot's July-6 app process
  survived the July-8 rebuild — what he saw was the m8 single-shot advisor.
  First live agentic battle = validation of loop latency under real Wi-Fi,
  capsule quality, why-trace usefulness, forced-answer path.
- **The Meta tab's full crawl has never run** (only the bounded 8-page smoke).
- **Preview bring-4/leads is still the m3 heuristic** (`safe_four` damage-
  trade average) — the m12-A core below.
- **Observed damage is thrown away** — no spread/item inference (m12-B).
- teraType modeled but not calc'd; PP tracking + Protect-pressure absent.
- No battle persistence: logs/advice/traces vanish when the window closes
  (the spec's stated purpose is LEARNING — a review surface is missing).
- Opponent summary-panel deep-parse mappings still unmapped (HP format,
  status-chip durations) — need frames of browsing an opponent ACTIVE's
  summary mid-battle (pilot action, recorded).
- Species bank: Scizor/Sylveon/Raichu/Milotic misses await live taps.
- 3 heavy-wobble unrecognized banners in battle-5 replay ("fellito 2",
  "thteenturn", "clive on") — wobble-tolerance candidates, low priority.
- Battle-7's missed battle start: root cause still unknown (no recording);
  the new diagnostics exist precisely to catch the next occurrence live.

## Task A — m12 core: the agentic PREVIEW scout ("what do I bring?")

Team selection is the highest-leverage decision of the battle, made once,
with ~60–90s of thinking time — and it currently gets the crudest heuristic
in the codebase. All the plumbing from m11-A exists; point it at preview:

1. **A preview-mode advisor call**: when the consensus stabilizes (the same
   ≥5-frame bar that seeds the reconciler), build the SAME battle-static
   capsule block, plus a preview question instead of a turn block: recommend
   **bring 4 + leads + a turn-1 plan** (~4 sentences; latency budget can be
   ~30s — preview is long). Tools shine here: scout_report for the damage
   matrix, live_matchup to stress-test the proposed LEAD PAIRING vs their
   likely leads, meta_profile for bench detail.
2. **Surfaces**: an advice card in the Scout Report window (Ask + Auto-once-
   per-preview toggle, default off — API cost is the pilot's) and the same
   why-trace disclosure as the Battle Log. The overlay's waiting state can
   show the bring-4 line once computed.
3. **Offline proof first** (AdvisorHarness `--preview` mode): replay battles
   3/4/5 to preview end, run the preview call, print capsules + trace +
   recommendation; eyeball against the heuristic's picks AND what the pilot
   actually brought. Not in verify-all (network/cost).
4. Keep the deterministic `safe_four` as the always-on instant answer
   (two-speed doctrine §4.1) — the agentic scout is the toggle-on layer.

## Task B — reverse damage inference (the engine learns from watching)

When a known move lands for an observed %, the roll range constrains the
attacker's investment/item — information no human extracts under a timer:

1. **Engine addition** (`inferAttack` in engine.ts): given attacker species/
   move, defender spec (ours = full ground truth from the team paste), field,
   and the observed damage %, test hypothesis grid {0/128/252 EVs} ×
   {neutral/+nature} × {none/Life Orb/Choice/boosting-item from the species'
   top items} → return which hypotheses are CONSISTENT with the roll
   (honest ranges, never point estimates).
2. **Reconciler hook**: attribute damage via the existing lastMove window +
   HP-delta reads; emit a 🔎 `inference` event ("Kingambit hits like ≥252
   Atk; Life Orb consistent") and store hints on the entity.
3. **Feed it forward**: hints ride the advisor's turn context (and sharpen
   the matchup's set assumptions where they contradict priors).
4. **Fixture-first + honest v1 scope**: single-target, non-crit (skip when a
   crit note landed), no spread-move modifiers, OUR side as defender first
   (our exact HP + known spreads make the math clean). Fixtures derive from
   battle-4/5 hits where the committed team spread is ground truth;
   engine-side pins go in ScoutEngineHarness (stage 3).

## Stretch C / D (gate on time; both are real capability, pick by appetite)

- **C — tera-in-calcs + Protect pressure**: apply `teraType` to calcs when a
  tera is observed (and as a tool hypothesis: "damage_calc with tera");
  track consecutive-Protect per active and say so in the turn context.
- **D — battle archive + review window**: persist each battle's log +
  matchups + advice traces to App Support; a Review window lists past
  battles and replays the decision points (spec §1's learning purpose).

## Pilot actions (fold into the next battles — no code needed)

1. Quit + relaunch, check the **build stamp** matches the rebuild, then take
   the AGENTIC advisor into ranked: note latency feel, advice quality, and
   whether the why-trace earns its place.
2. Give the overlay its formal glanceability verdict.
3. Press **Refresh** in Settings → Meta once (first full crawl; ~3–5 min).
4. While recording, **browse an opponent ACTIVE's summary mid-battle**
   (unblocks the m10-C mappings).
5. Confirm-tap any Scizor/Sylveon/Raichu/Milotic met; run `import-live`.
6. If a battle start is ever missed again: read the "tracker sees:" line and
   report it — that's the battle-7 root-cause evidence.

## Guardrails (all earned, m0–m11)

- verify-all (6 stages) green after every shared-code change; update
  fixture-count echoes (currently 44/44).
- LOOK at real frames/reads/pages before designing parsers or crawlers;
  fixtures from exact recorded text; committed-sample regeneration uses its
  exact recorded invocation (`1=Farigiraf 2=Charizard 3=Pelipper
  4=Archaludon`).
- Shared files Foundation-only; **`nonisolated` on every shared-file TYPE,
  EXTENSION, and nested-type conformance** (three strikes: m9 extensions,
  m11 top-level types, m11-C nested Codable).
- Engine rebuilds: pinned esbuild
  (`node_modules/.bin/esbuild src/engine.ts --bundle --format=iife
  --global-name=ScopeEngine --banner:js="var console={log:function(){},warn:function(){},error:function(){}};"
  --outfile=dist/engine.js`); copy dist to Resources. Meta/vocab refreshes
  are data swaps, never rebuilds.
- claude-api skill BEFORE Anthropic-API code; adaptive thinking EXPLICIT;
  parallel tool_results in ONE user message; `.sortedKeys` on request
  bodies (cache-stable bytes); thinking blocks echoed verbatim.
- Stale-instance discipline: a pilot report of "feature missing" starts with
  the build stamp / `ps -o lstart` vs binary mtime; on debug builds grep
  `<App>.debug.dylib`, never the stub executable.
- `swiftc … | head` and `xcodebuild … | grep` mask exit codes — write to a
  log file and check `$?` separately.
- TCC: container reads from CLIs can hang uninterruptibly — escape is Xcode
  RunCodeSnippet (runs in the APP's context); `import-live` has `--from`.
- Ethan's conversational reports are real bugs — 8 for 8 across sessions
  (the "no Meta tab" report root-caused to the stale instance).
- Branch + PR per milestone; standing merge authorization in AGENTS.md.
  Externalize findings to Diagnostics/README.md + memory AS YOU GO.
