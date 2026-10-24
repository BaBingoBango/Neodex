# ScopeLens — Session 5 kickoff (m10: the glanceable overlay + data flywheel)

> STATUS UPDATE (2026-07-06, same session — pilot said "press on"): Tasks A
> and B below are DONE. **A (PR #27)**: the overlay HUD shipped — floating
> non-activating panel, KO badges, TR-aware speed strip, perish chips,
> advice card; auto-opens on battle start; RenderPreview-verified; awaiting
> the pilot glanceability verdict. **B (PR #26)**: the MCP server shipped —
> six §4.3 tools over zero-dep stdio JSON-RPC; verify-all stage 6 pins
> protocol + scout-CLI parity; Ethan adds the one-line .mcp.json entry
> (snippet in Diagnostics/README m10-B). Remaining: the pilot actions
> below, frame-gated Task C, and friction-gated Stretch D.

Context (read in order — do not rediscover what's written down):
1. Project memory (auto-loads; current through PR #24 — trust it).
2. `ScopeLens-Spec-v0.1.md` §2 goals, §4.1 two-speed doctrine, §4.3 engine
   surface, §11 roadmap.
3. `Diagnostics/README.md` — the m9/m9-B/m9-C sections are this session's
   memory of what actually bit us (extension isolation, TCC container
   hangs, LOFO-honest simulation).
4. KEY ASSETS unchanged (five battle .movs local, native crops, harvest
   sessions — all gitignored; `.env.local` key for CLI harnesses only).

## State of play

Phases 0–2 complete; Phase 3 has BOTH live-validated layers (deterministic
matchup + Opus advisor) AND m9's team management: a Showdown paste drives
every surface (scout, reconciler seeds, matchup, advisor, all four CLIs),
with EVs/IVs/natures/level flowing into @smogon/calc when configured. The
species flywheel's last pipe (`import-live`) exists and is sim-proven; the
summary panel deep-parses ability/item/absolute-stages/exact-HP for any
browsed mon. verify-all = 5 stages, 37/37 battle fixtures, all green.

## Pilot actions first (they unblock the rest — no code needed)

1. **Paste the real team** (Settings ⌘, → Team) with actual EV spreads —
   every damage number and speed estimate sharpens immediately. If any
   import issue looks wrong, that's a bug report.
2. **Confirm-tap during ranked** (pin rows in the Opponent read panel),
   especially any Raichu/Milotic/Scizor/Sylveon sightings, then run
   `import-live` (build line in Diagnostics/README) — the LOFO floors
   (currently 22/24) should finally rise on real cross-source taps.
3. **Browse the summary panel of an OPPONENT mon** during any battle and
   keep the recording — the opp-card HP format and status-chip durations
   are unmapped (m9-C deferred list) purely for lack of frames.

## Tasks

**A — Glanceable overlay HUD (Phase 3's remaining spec item).** The Battle
Log window is a debug surface; during a real 40s move timer the pilot needs
a compact always-on-top panel: current matchup's top incoming/outgoing
lines with KO badges, speed order, perish clocks, and the latest advice —
readable at a glance next to the mirror window. NSPanel-style floating
window (non-activating, joins all Spaces), toggle from the tracker, and a
Settings knob for size/position persistence. Done when: Ethan plays a
ranked battle steering only by the overlay and reports it usable.

**B — MCP server surface (spec §4.3's unbuilt promise).** The engine
functions double as MCP tools: `resolve_team`, `meta_profile`, `type_calc`,
`damage`, `threat_matrix`, `safe_four` — a small Node stdio MCP server
reusing `Engine/dist/engine.js` + the data files, so Claude can be asked
"teach me this matchup" against the real meta snapshot. Wire it into
`.mcp.json` (env-var pattern, no secrets committed). Done when: a Claude
session answers a matchup question through the server with numbers matching
the scout CLI.

**C — Deep-parse follow-ups (gated on the frames from pilot action 3).**
Map the opponent summary card (HP format!), per-mon status-chip durations
("Burned n/m"?), and side-scoped chips (Tailwind/screens) — the generic
(name, n/m) extraction already reads them; add the mappings + fixtures from
REAL tokens only.

**Stretch D — Advisor polish (still gated on pilot friction).** Prompt-cache
the system prompt + stable context prefix (consult the claude-api skill —
cache_control breakpoints), effort/model knobs in Settings, a "why"
expander showing the sent context.

## Guardrails (all earned, m0–m9)

- LOOK at real frames/data before designing any parser; fixtures from real
  tokens (fixture 37's synthetic multiplier flips are the labeled
  exception, awaiting a real boosted panel).
- Reproduce temporal bugs as committed fixtures BEFORE deeper code-reading;
  `--dump observations.jsonl` bridges symptom → fixture (37/37 today).
- Run `Diagnostics/verify-all.sh` after every shared-code change; update
  the fixture-count echoes when counts change.
- Engine rebuilds: PINNED esbuild only; copy dist to
  `Scope Lens/Resources/Engine/`. Data refreshes are file swaps.
- Committed-sample regeneration: exact recorded invocation
  (`1=Farigiraf 2=Charizard 3=Pelipper 4=Archaludon`).
- Shared files: Foundation-only, no app symbols — and mark EXTENSIONS
  `nonisolated` explicitly (the app's MainActor default isolation captures
  them silently; CLI builds mask it — m9's recurrence).
- Reading the app's sandbox container from a CLI can hang uninterruptibly
  on TCC consent — `import-live` has `--from`; don't fight the dialog.
- Never commit: battle videos, dex-sprites/native crops, harvest sessions,
  `.env.local`, or sim-derived native features (same-source features let an
  eval fixture match its own pixels — the LOFO cheat).
- Consult the claude-api skill BEFORE any Anthropic-API code (it fixed the
  advisor's model + thinking config in m8).
- `swiftc … 2>&1 | head` masks compile failures — never `&&` a harness run
  onto a piped compile.
- Ethan's conversational reports are real bugs — 5 for 5 across sessions.
  Confirm against footage, fix at the root, add the fixture.
- Branch + PR per milestone; standing merge authorization in AGENTS.md.
  Externalize findings to `Diagnostics/README.md` + memory AS YOU GO.
