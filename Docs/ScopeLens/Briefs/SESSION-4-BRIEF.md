# ScopeLens — Session 4 kickoff (m9: Team Management + closing the flywheel)

Context (read in order — do not rediscover what's written down):
1. Project memory (auto-loads; current through PR #20 — trust it).
2. `ScopeLens-Spec-v0.1.md` §2 goals, §4.3 engine surface, §11 roadmap.
3. `Diagnostics/README.md` — every hard-won finding; the m4–m8 sections are
   the project's memory of what actually bit us.
4. KEY ASSETS (LOCAL, gitignored — never commit): FIVE recorded battles at
   `Fixtures/screenshots/iPhone 17 Pro Max/*.mov` (battles 4 & 5 have
   committed live-log `.md` twins beside them); native sprite crops under
   `Fixtures/reference/native/`; harvest/replay sessions under
   `Fixtures/harvest/`. `.env.local` holds ANTHROPIC_API_KEY for CLI
   harnesses ONLY (the app uses Keychain via Settings ⌘,) — never print or
   commit it.

## State of play

Phases 0–2 complete. Phase 3 shipped its first two layers and BOTH are
live-validated by Ethan: the deterministic Live Matchup panel (KO flags vs
current HP, boost/status/field-aware) and the "What's the play" advisor
(Opus 4.8, ~12s, advice matched the pilot's actual winning play). The
species matcher self-improves (native references at 25 species / 112
features; confirm-taps bank permanently). The one structural embarrassment
left: **the pilot's team is hardcoded in three places**
(`ScoutEngine.ethansTeam`, `BattleReplayHarness.yourTeamSeeds`,
`AdvisorHarness.yourTeamSeeds`) and every damage calc assumes 252/252
neutral spreads.

## Tasks

**A — Team management (m9 core).** Showdown-paste import — the format VGC
players already have — parsed into a persisted team (App Support JSON;
Codable member: species/item/ability/moves/EVs/nature/tera), edited via a
small Team window or Settings tab, validated against `vocab.json`. Feed it
EVERYWHERE the hardcoded six lives: ScoutEngine report inputs, reconciler
`yourTeam` seeds, matchup MonSpecs, advisor context, and both CLI harnesses
(give them a repo-side team file for parity — decide the path, document it).
Pass EVs/natures through MonSpec into @smogon/calc so damage numbers use the
REAL spread (additive fields; update the assumptions strings). The committed
scout sample will change legitimately → regenerate with its exact recorded
invocation and re-pin parity. Done when: paste a team → every surface uses
it; verify-all green end-to-end.

**B — Close the species flywheel.** `NativeReferenceHarvest import-live`
mode: pull the app's live-tap crops + overlay JSON out of Application
Support into the repo bank, rebuild `native-features.json`, re-run the LOFO
measurement, raise the verify-all floors if warranted. Done when: a tap made
live in a past session measurably improves the committed matcher.

**C — Summary-panel deep parse.** The user-browsable summary panel shows
EXACT ability, item, per-stat boost multipliers, and status durations for
ANY mon — "Rain 1/5" already re-syncs weather; extend to the rest. LOOK at
real panel frames first (battle-1 harvest keyframes 104/124 are the
reference; geometry notes in the m4 README section). Re-sync doctrine:
observations beat priors; reveals feed matchup + advisor.

**Stretch D — Advisor polish.** Only if Ethan reports friction: prompt-cache
the system prompt + stable context prefix (consult the claude-api skill —
cache_control breakpoints), effort/model knobs in Settings, a "why" expander
showing the context block that was sent.

## Guardrails (all earned, m0–m8)

- LOOK at real frames/data before designing any parser. (Battle 4's
  "type-template bug" was actually live early-seed freezing — the offline
  replay exonerated the templates.)
- Reproduce temporal/stateful bugs as committed fixtures BEFORE deeper
  code-reading — replay `--dump observations.jsonl` is the bridge from
  symptom to fixture, and the fixture stays as the regression guard
  (35/35 today; keep growing it).
- Run `Diagnostics/verify-all.sh` after every shared-code change — all FIVE
  stages stay green. The fixture-count echoes in the script drift; update
  them when counts change.
- Engine rebuilds use the PINNED esbuild
  (`Engine/node_modules/.bin/esbuild`) and copy dist to
  `Scope Lens/Resources/Engine/`. Vocab/meta refreshes are data-file swaps,
  no rebuild.
- Committed-sample regeneration requires its EXACT recorded invocation —
  currently `1=Farigiraf 2=Charizard 3=Pelipper 4=Archaludon` (row 4 was
  corrected from a session-1 mislabel; the native-crop calibrator caught
  it — cross-label distance collisions are label bugs until proven
  otherwise).
- Consult the claude-api skill BEFORE writing any Anthropic-API code. It
  corrected the advisor's model choice AND thinking config — adaptive
  thinking bills into max_tokens (a 300 cap returned an empty answer), and
  omitting `thinking` on Opus 4.8 runs thinking-OFF.
- `swiftc … 2>&1 | head` masks compile failures (pipe exit code = head's) —
  never `&&` a harness run onto a piped compile.
- Diagnostics harnesses compile shared app files WITHOUT app-only symbols —
  keep Keychain/SwiftUI/sandbox references out of shared files; pass data in
  as parameters (the NativeReferenceStore/bundled() split is the pattern).
- Ethan's conversational reports are real bugs — 5 for 5 across sessions.
  Confirm against footage, fix at the root, add the fixture.
- The app is sandboxed: it cannot read repo paths or `.env.local`; writable
  state lives in Application Support; outbound network needs the
  entitlement (already on).
- Never commit: battle videos, `Fixtures/reference/dex-sprites|native/`,
  `Fixtures/harvest/`, `.env.local`. The live battle-log `.md` files ARE
  committed (private repo; scrub trainer names if ever public).
- Branch + PR per milestone; standing merge authorization in AGENTS.md.
  Externalize findings to `Diagnostics/README.md` + memory AS YOU GO.
