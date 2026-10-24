# ScopeLens — m12-C brief: the Opponent Dossier ("google the enemy, at a glance")

A bite-sized, low-risk task (pilot-requested). Paste this whole file into a
fresh Claude Code session and go. Read project memory + `Diagnostics/README.md`
(m11-A capsules, m12-A/B) first — do not rediscover what's written down.

## The pilot's ask (verbatim intent)

Mid-battle and at team preview, the pilot keeps googling the same things about
the opponents on screen: their common **abilities, moves, types — and what
those actually do**. ScopeLens should just surface that at a glance, so the
pilot never leaves the app to look up "what does Armor Tail do again?"

## The key realization: NO pokedex plugin needed — the engine already is one

Everything here already exists in the bundle. This is a **surfacing** task, not
a data-acquisition task. Do not add a network call, a crawler, or a plugin.

**What already exists (reuse it):**
- **`OpponentCapsule`** (`AdvisorTools.swift`) + `AdvisorToolExecutor.buildCapsules(species:)`
  already compute, per opponent species: `types`, `winrate`, `topMoves` (name + %),
  `topItems` (name + %), `topAbility` (name + %), `speedMin/Max` + `scarfPossible`,
  `priorityBlockerLikely`, and `defensive` (which attacking types hit it 4×/2×/½/¼/0).
  This is 90% of what the pilot googles — already built, already deduped + sorted (m12-A).
- **`ScoutEngine`** bridges `metaProfile` / `typeEffect` / `speedBrackets` /
  `defensiveProfile` into the app; the JSC engine bundles `@pkmn/dex` data.
- **`LiveTrackerModel`** knows who's on screen: `advisorState.oppSide.active + .bench`
  (in-battle, corroboration-corrected) and `opponentRead` / `scoutReport` (preview).
- **`ScoutReportView`** already renders opponent cards with move %s — a proven layout to build on.

**The ONE thing missing:** effect/flavor text (move `shortDesc`, ability `shortDesc`,
item `shortDesc`) and per-move mechanical fields (type, category, base power, accuracy,
priority). These live in `@pkmn/dex`, which is **already an Engine devDependency**
(`build-vocab.js` and `build-learnset-fallback.js` both use it). So we bake them into a
data file the same way we already bake vocab, learnsets, and meta stats — no new dependency,
no runtime bloat beyond a JSON.

## Task 1 — Engine: a dex-effects data layer (the only new "data")

1. **Step 0, verify first:** check whether the bundled `@smogon/calc` gen already
   carries `shortDesc` — in `Engine/`, `node -e "const {Generations}=require('@smogon/calc'); const g=Generations.get(9); console.log(g.moves.get('fakeout'))"`.
   - If `shortDesc` is present on moves AND `g.abilities`/`g.items` exist with it →
     a thin runtime export is enough (skip the build script; read from `gen` directly).
   - If NOT (likely — @smogon/calc's data is damage-focused) → bake a JSON, per below.
2. **`Engine/build-dex-info.js`** (new; mirror `build-vocab.js`): use `@pkmn/dex`
   (`Dex.forGen(9)`) to emit `Engine/data/dex-info.json`:
   ```
   { "moves":     { "<slug>": { "name","type","category","basePower","accuracy","priority","shortDesc" } },
     "abilities": { "<slug>": { "name","shortDesc" } },
     "items":     { "<slug>": { "name","shortDesc" } } }
   ```
   Scope to the closed vocab's known moves/abilities/items (read `data/vocab.json`) to
   stay lean; all gen-9 moves+abilities is also acceptable if simpler (~a few hundred KB).
   **Gotcha:** `accuracy` is `true` for never-miss moves — emit `null` (renders "—"),
   a number otherwise. `slugify` exactly as engine.ts does (`toLowerCase().replace(/[^a-z0-9]+/g,'-')`).
3. **`engine.ts`**: `import dexInfoJSON from '../data/dex-info.json'` (like `learnsetFallbackJSON`),
   and export:
   ```ts
   export function dexInfo(input: {moves?: string[], abilities?: string[], items?: string[]}): any
   ```
   returning the resolved entries (unknown names → `{name, known:false}` so the UI degrades).
4. **Rebuild** with the PINNED esbuild (see README m3b / the guardrails below) and copy
   `dist/engine.js` → `Scope Lens/Resources/Engine/engine.js`. Copy `dex-info.json` →
   `Scope Lens/Resources/Engine/` too (bundled data file, like `meta-regmbs3.json`).
5. **`ScoutEngine.swift`**: add `func dexInfo(moves:abilities:items:) throws -> …` over the
   existing `callJSON` surface (mirror `defensiveProfile`).
6. **Pin it** in `ScoutEngineHarness.swift` (verify-all stage 3): e.g. Fake Out returns a
   `shortDesc` mentioning flinch/first-turn, category Physical, priority > 0; Armor Tail's
   `shortDesc` mentions priority immunity; an unknown name returns `known:false`.

## Task 2 — A reusable `OpponentDossierCard` view (the glance)

One SwiftUI view, `OpponentDossierCard`, that renders ONE opponent at a glance.
Make it a **pure view over plain data** (previewable with mock data, like
`OverlayContentView`) so it needs no live tracker to preview. It composes an
`OpponentCapsule` (meta + typing + speed + blocker — build via `buildCapsules`)
with the `dexInfo` effects. Show, top to bottom:
- **Header**: species · types · winrate · ⚠️ priority-blocker flag if any.
- **Defensive typing** (from `capsule.defensive`): a compact "weak: Fire, Rock ·
  resists: Water… · immune: …" line — this is the "what do I hit it with" answer.
- **Top ability** (name + %) **with its effect** (`shortDesc`).
- **Top moves** (name + %) each with **type · category · BP** and the **effect**
  (`shortDesc`) — the core "what does this move do" lookup. 4 moves is plenty.
- **Top items** (name + %); optionally the item's `shortDesc` on the top one.
- **Speed bracket** ("Spe 105–150 (Scarf → 225)") and a "usage priors, not observed" caption.
Keep it dense but scannable — the pilot is glancing under a timer. Accessibility +
light/dark per house rules.

## Task 3 — Surface it

**Primary — a dedicated Dossier window** (`⇧⌘K`, "Scouting Dex" or "Dossiers"):
lists `OpponentDossierCard`s for the opponents ScopeLens knows, **actives first,
then bench** (source from the reconciler like the advisor's `capsuleSpecies()`
does, so battle-corroboration corrections flow in; fall back to `opponentRead`
at preview before any battle event). Add the window like the Battle Log / Scout
Report windows (`Scope_LensApp.swift` scene + a header button in the Live Tracker).
It works at BOTH preview and mid-battle — that's the whole point.

**Nice-to-have (do if quick):** enrich the existing `ScoutReportView` opponent
cards with the same effect text (tap-to-expand a move → its `shortDesc`), reusing
the dossier card. Skip if it balloons scope — the dedicated window is the deliverable.

## Guardrails (all earned — do not skip)

- **No network, no plugin, no live-capture changes.** This is additive read + UI over
  bundled data. The reconciler, parser, and capture loop are untouched.
- Engine rebuilds use the **pinned esbuild** only (`Engine/node_modules/.bin/esbuild …`,
  the exact invocation in `Diagnostics/README.md` m3b) — never bare `npx esbuild`. Copy
  `dist/engine.js` AND `dex-info.json` into `Scope Lens/Resources/Engine/`.
- Shared/engine-facing Swift stays **Foundation-only** and `nonisolated` on every TYPE,
  EXTENSION, and nested Codable (three prior strikes — grep the app build for
  "main actor-isolated" after adding types).
- `Diagnostics/verify-all.sh` **6/6 green** after the change; bump the dex-info pin in
  stage 3. Fixtures stay 46/46 (this task adds none — no parser change).
- Keep bulky data OUT of "Scope Lens/" except deliberate `Resources/` files (the .app-bloat lesson).
- Branch `feature/m12c-opponent-dossier` + PR; standing merge authorization in AGENTS.md.
  Write findings into `Diagnostics/README.md` + memory as you go.

## Done when

1. A **Dossier window** shows, for each on-screen/known opponent, its likely ability +
   moves + items with **usage %** AND **plain-English effects**, plus its **type
   weaknesses** and **speed bracket** — no browser needed. Works at preview and in battle.
2. `dexInfo` is engine-exported, bundled as data (no new dependency, no network), and
   **pinned in verify-all stage 3**; suite 6/6 green, app build warning-free.
3. `OpponentDossierCard` previews with mock data (RenderPreview / #Preview), so the layout
   is verifiable without a live battle.

## Why this is the right "no brainer"

It's pure surfacing over data ScopeLens already has, it touches none of the risky
live-tracking machinery (spec §10: the vision layer is where bugs live — this isn't that),
and it directly serves the spec's stated purpose (§1: *learning* — making the game's
hidden structure visible at a glance). The capsule builder already did the hard part in m11;
this just points a clean window at it and adds the effect text that was one field away.
