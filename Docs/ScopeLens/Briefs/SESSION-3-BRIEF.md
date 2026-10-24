# ScopeLens — Session 3 kickoff (Phase 2 m4: BattleState)

Context (read in order — do not rediscover what's written down):
1. Project memory (auto-loads; current through PR #13 — trust it).
2. `ScopeLens-Spec-v0.1.md` §4.4–4.5 (pipeline + state contract), §11 roadmap.
3. `Diagnostics/README.md` — every hard-won finding, incl. the drift lessons.
4. KEY ASSETS (LOCAL, gitignored — never commit): 3 recorded battles at
   `Fixtures/screenshots/iPhone 17 Pro Max/*.mov`, plus session timelines and
   keyframes under `Fixtures/harvest/`. Build and verify m4 OFFLINE against
   these before touching live capture.

## Tasks

**A — BattleState + event parsing.** Implement the §4.5 `BattleState` schema
(STOP AND PROPOSE if the shape needs changing — spec §8 design-fork rule).
Parse narration banners + `activationChip` text against closed vocabularies
(119-species meta + moves/items/abilities data; chips discriminate
ability-vs-item BY VOCAB — same chip UI serves both). Only
narration / chip / teamPreview / result frames MUTATE state; `command` frames
are HP re-sync checkpoints (catches un-narrated Leftovers healing etc.).

**B — Reconciler + paper replay.** Legal-transition filtering (HP can't rise
except known healing; fainted stays fainted; weather runs on a timer) over
the classifier timeline → a human-readable battle log.
Done when: battles 2 & 3 produce plausible logs Ethan can eyeball.

**C — Learnset fallback for unranked species.** True off-ladder opponents
(the real Zygardes of the world) currently contribute zero threats to the
scout report. Give them plausible STAB movesets via @pkmn/dex so the report
degrades gracefully instead of going blind.

**Stretch D — Native sprite-reference harvest.** Confirmed species reads
(confirm-taps + battle corroboration) → save preview sprite crops as a
Champions-native reference set; measure top-1/top-3 improvement.
Validation targets (all user-confirmed misses): Raichu→Arrokuda,
Milotic→Feebas, and Battle 3's Dragon/Ground row read as Zygarde
(user is certain there was no Zygarde; almost certainly Garchomp).

## Guardrails (all earned this project)

- LOOK at real frames before designing any parser.
- Derived JSONs are the spec: regenerate + re-score the full chain after any
  geometry/output change (the committed scout sample needs its FOUR taps:
  `1=Farigiraf 2=Charizard 3=Pelipper 4=Dialga`).
- Run `Diagnostics/verify-all.sh` after every change that touches shared
  code — all four stages must stay green.
- Engine rebuilds use the PINNED esbuild (`Engine/node_modules/.bin/esbuild`),
  never bare `npx esbuild`; copy dist to `Scope Lens/Resources/Engine/`.
- Meta refreshes are a data-file swap (`meta-regmbs3.json` in app resources;
  `ScopeEngine.setMeta` injects at init) — no engine rebuild needed.
- Never commit: battle videos, `Fixtures/reference/dex-sprites/`,
  `Fixtures/harvest/`.
- Branch + PR per milestone; standing merge authorization is in AGENTS.md.
- Externalize findings to `Diagnostics/README.md` + memory as you go.
