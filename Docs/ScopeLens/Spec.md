# ScopeLens — Product & Engineering Spec (v0.1)
*A live "observer & advisor" for Pokémon Champions (VGC doubles)*

> Companion doc: **ScopeLens — Architecture & State Contract (v0.1)**, which is
> authoritative for the screen states, parsing conventions, and full state schema.
> This document is the master spec; the contract is the detailed reference.

---

## 1. Overview
ScopeLens is a macOS app that watches a live Pokémon Champions battle by capturing a
mirrored view of wherever the game is running, reads the screen with on-device OCR
and image matching, and advises the player in real time — surfacing meta patterns,
matchup threats, and damage math. Its purpose is **learning**: helping a returning
VGC player rebuild intuition for the current metagame by making the game's hidden
structure visible ("this Incineroar almost certainly has Fake Out"; "their
Aerodactyl's Rock Slide is a KO roll on your Charizard").

It is explicitly an **observer**: Champions runs the game; ScopeLens watches the
outcomes and interprets them. It never simulates the battle itself.

---

## 2. Goals & non-goals

**Goals**
- Read the live battle state from the screen (both teams, HP, field) with no manual
  data entry or menu-clicking.
- Surface meta knowledge: likely moves / items / roles per Pokémon, from usage data.
- Compute matchups: type advantages, vulnerabilities, and real damage rolls.
- Produce a team-preview **scout report**: opponent roles + threat matrix + a
  suggested safe 4 and leads.
- Offer an optional, slower **LLM "what's the play"** layer that can be toggled on.
- Be portable across capture sources (BYOD): phone mirror, iPad, emulator, Switch
  capture card.

**Non-goals / scope boundary**
- **Not a bot or autoplayer.** It advises; the human plays.
- **Not for official / sanctioned tournament use.** A deterministic damage + usage
  tool is the same family as Pikalytics and the community damage calculator — fine
  for laddering, practice, and review. A live auto-move-recommender is external
  assistance and does not belong in official play. Build it to *learn from*, not to
  lean on; be thoughtful about autopilot even in serious ranked, and leave it off
  for anything official.
- **Not a battle simulator.** We mirror observed state; we don't re-implement hidden
  game mechanics.

---

## 3. Core design principles
1. **Observer, not simulator.** Mirror what Champions displays; never simulate.
2. **Schema is a known contract, defined top-down.** The state model is designed up
   front around what the advisor needs to reason with; OCR/matching are best-effort
   populators. We do not grow the schema from whatever OCR happens to emit.
3. **Normalized 0–1 coordinates, never absolute pixels.** Inputs span many
   resolutions and aspect ratios; everything is relative to the detected game viewport.
4. **Quarantine messiness at the edges.** Device-specific capture and
   language-specific text are handled at the boundary; the core operates on
   canonical, resolution- and language-independent data.
5. **Identity from pixels, not text.** Species are identified by sprite + type icons,
   never by the on-screen name (opponents nickname their Pokémon, in many languages).
6. **Two speeds.** A fast deterministic layer that's always right and always on; a
   slower LLM layer that's toggle-on. The on-screen move timer (~40s) is the latency
   budget that motivates the split.

---

## 4. System architecture

### 4.1 Two-layer model
- **Deterministic engine** — type matchups, usage priors, and damage calcs. Local,
  instant, mathematically exact, no network. Runs every turn with no timer stress.
  This is the "statistical recommendation," and the default.
- **LLM layer** — holistic, fuzzy reads ("they'll likely lead Whimsicott for Tailwind
  into your slow side; consider doubling it turn one"). A couple of seconds
  round-trip, so it's the *toggle-on* layer for when there's time. This is the "LLM
  recommendation."

Most of the product's value lives in the fast engine, so the latency problem largely
evaporates — patterns, matchups, and vulnerabilities are all deterministic.

### 4.2 Capture & normalization layer
A single boundary sits between the frame source and the engine so **the engine never
knows how frames arrive.** One capture adapter per source; one shared pipeline after.
- **Sources (BYOD):** wired iPhone mirror via QuickTime; Android emulator window;
  Switch capture card. (Native Mac run is unavailable — Champions opted out of
  Apple-Silicon iOS-on-Mac. Emulators may be detected by the game; the real-device
  routes sidestep that.)
- **The layer:** detect the game viewport inside the frame (ignore device-specific
  letterboxing/borders), convert to normalized 0–1 coordinates inside it, and
  auto-calibrate the layout once per source when it's plugged in.

### 4.3 The engine / tool surface
The deterministic functions below *are* the engine. They double as **MCP tools** (so
Claude can call them for "teach me this matchup") and as the direct API the live
overlay calls.

- `resolve_team(image | names[]) → species[]` — identify a team from the preview
  screen or a typed list.
- `meta_profile(species) → { ability, items%, moves%, role }` — the pattern lookup
  and the learning core ("Incineroar → Intimidate, ~99% Fake Out, glue").
- `type_calc(move|types, target) → multiplier` — instant type effectiveness.
- `damage(attacker, move, defender, field) → { roll%, koChance }` — wraps
  @smogon/calc; `field` carries sun / rain / Tailwind / Trick Room.
- `threat_matrix(mine, theirs, field) → per-mon threats + rolls` — chains the above
  against each opponent's *likely* moves.
- `safe_four(mine, theirs) → { bring4, leads, why }` — heuristic first; the LLM layer
  can produce the nuanced version.

**Scout report** = `resolve_team → meta_profile ×6 → threat_matrix → safe_four`.

### 4.4 OCR + identification pipeline
On-device, deterministic, **no model in the loop** (so state never flickers
frame-to-frame):
1. **Recognize.** Apple Vision (`VNRecognizeTextRequest`, `.accurate`,
   `usesLanguageCorrection = false`, multi-script recognition languages) returns each
   string with a normalized bounding box and a confidence.
2. **Normalize.** Boxes are already normalized; account for letterboxing to get true
   viewport-relative coordinates.
3. **Route by region.** Layout is fixed per screen state, so each token is assigned to
   a field by where its box lands (`\d{1,3}%` top-right → opponent HP; bottom move
   panel → your moves).
4. **Snap to a closed vocabulary.** The legal set of species, moves, and statuses is
   finite, so tokens fuzzy-match to the nearest valid value ("Protct" → "Protect");
   anything matching nothing in its region is rejected as noise.
5. **Identify species from pixels.** Opponents have no reliable name, so species come
   from **sprite matching, constrained by the two on-screen type icons** (an
   18-template type match narrows ~1000 candidates to a handful).
6. **Reconcile against game rules.** Only apply changes legal for the running state
   (HP can't rise except via known healing; a fainted Pokémon stays fainted; weather
   runs on a timer). Illegal readings are discarded — free glitch protection.

A **state classifier** runs first each frame, since region maps are state-dependent.

### 4.5 State contract (schema summary)
Full per-screen detail and parsing conventions live in the companion contract doc.
Condensed shapes:

```
ScreenState = teamPreview | command | moveSelect | narration
            | switchSelect | targetSelect | result | unknown

PreviewReport { you: TeamMember[6], opponent: OppPreviewMon[6] }
OppPreviewMon { speciesId?, types:[Type,Type], gender, spriteCropRef, idConfidence }

BattleState {
  turn, weather{ kind, turnsLeft? },
  field{ trickRoom?, tailwind{ you?, opp? }, screens? },
  yourSide{ active: PokemonState[1..2], bench: PokemonState[] },
  oppSide { active: PokemonState[1..2], bench: PokemonState[] }   // bench from preview
}
PokemonState {
  speciesId,                       // from sprite match — the identity key
  displayName?,                    // on-screen text; may be nickname/foreign — UI ONLY
  hp{ kind:'exact'|'percent', cur?, max?, pct? },
  status?,                         // par|psn|brn|slp|frz
  boosts{ atk,def,spa,spd,spe },   // -6..+6; INFERRED from events, not always shown
  revealedMoves[], item?, megaEvolved?, teraType?
}
MoveContext { moves:[ { name, pp{cur,max}, effectiveness? } ] }
```

**Why the schema ≠ the screen:** the screen shows only a subset (exact boosts, an
opponent's item, an Intimidate drop you watched happen aren't printed). A reconciler
*infers* these from observed events and defaults the rest to unknown. This is why the
schema is defined top-down, not grown from OCR output.

---

## 5. Technology stack & key decisions
- **App shell: native macOS** — SwiftUI, Swift, minimum deployment macOS 14. Native
  is required because the capture + OCR stack (ScreenCaptureKit + Vision) is
  Apple-native; a browser is sandboxed and can't do persistent screen capture or
  reach Vision.
- **Engine: portable TypeScript**, embedded in the native shell via **JavaScriptCore**.
  Writing the engine in TS lets us use the community damage calculator directly, and
  the same code *is* the MCP server. (If a JS-first shell is ever preferred, a Tauri
  app with a small Swift capture/OCR helper is the alternative.)
- **OCR: Apple Vision** (on-device, fast, free). **Capture: ScreenCaptureKit**
  (real-time window capture).
- **Damage math: @smogon/calc.** **Pokémon data: @pkmn/dex + @pkmn/data** (they wrap
  Showdown's type chart, move data, and damage formula).
- **Showdown is not in the live loop** — it's only the static rulebook, accessed
  through those libraries. We OCR *Champions*; we borrow *rules*.
- **Champions overrides layer.** Champions differs from mainline (Mega Evolutions are
  back; e.g. Swampert gained Wave Crash). A small delta patch sits on top of the
  libraries, accumulated as discrepancies surface — not a rewrite.

---

## 6. Data sources
- **PokeAPI** — localized species/move names (the multilingual name map) and general
  data.
- **@pkmn / @smogon** — types, moves, abilities, damage formula.
- **Usage data (`meta_profile`)** — RESOLVED: Pikalytics hosts full Champions
  Reg M-B ranked data, and its per-Pokémon pages embed machine-readable JSON-LD
  (moves/items/abilities with usage %, winrate). Snapshotted by
  `Engine/fetch-meta.js` → `Engine/data/meta-regmbs3.json` (validation:
  Incineroar Fake Out 99.9%). Scraping ToS caveat still acknowledged; refresh
  cadence TBD.

---

## 7. Screen anatomy & findings (from diagnostics)
Seven real screenshots (5 battle + 2 team preview, 2868×1320) were run through the
pipeline. Findings that shaped the contract:
- **The HUD is state-dependent.** Full HUD (HP, buttons, timers) appears only in the
  command and move-select states; narration frames show just a message banner; team
  preview is a separate screen → a state classifier is required first. Cheap
  discriminator: opponent `%` tokens present ⇒ HUD state.
- **HP is asymmetric.** Your Pokémon show exact HP (`154/154`); opponents show a
  percentage (`100%`). Both are OCR-readable. Vision misreads the slash
  (`154/154` → `1547154`), so HP is parsed from digit runs, not the slash.
- **Species need pixels, confirmed twice.** In battle, opponent names are Japanese
  nicknames (ガエン, ラル) matching no species; in team preview, the opponent's team has
  *no name text at all* — only sprite + two type icons + gender.
- **Type icons are the identification unlock.** The two type badges per opponent
  (invisible to text OCR) are a cheap 18-template match that collapses the species
  search space and are advice-worthy on their own.
- **Anchoring beats color.** Global HP-bar color detection false-fires on the arena's
  red divider and stadium lights; anchoring icon crops off reliable `%`/name tokens
  is clean and robust.
- **Move-select is a bonus signal.** Your move names, PP, and effectiveness labels all
  OCR at full confidence.

---

## 8. Development workflow
- **Roles.** User = pilot & integrator (runs, deploys, verifies, relays messages).
  Claude = architect (writes task briefs, reviews output, holds the overall map).
  Claude Code = implementation.
- **Loop.** Architect hands a tight, self-contained brief → user pastes it into Claude
  Code → CC builds, runs, reads its own output, and self-verifies against a
  "done when" → user relays the result → architect reviews and issues the next brief.
- **Autonomy.** Claude Code owns the full *build → run → read-own-output → verify →
  iterate* loop within a brief. Architect checkpoints happen only at **design forks**
  (schema shape, identification strategy, region maps), because those ripple. (The
  team-preview screen is the canonical example: an unchecked CC would have built a
  text-based species matcher that fails on every nicknamed/foreign opponent — looking
  first caught it.)
- **Brief format.** Every brief opens with a context block (what ScopeLens is, the
  principles, the current state) + explicit guardrails + a verifiable "done when."
  That context block is the first draft of a reusable **"ScopeLens conventions" skill**,
  to be lifted into a real skill file once the patterns are concrete code.
- **Fixtures are the bottleneck.** A folder of real Champions screenshots unblocks
  every OCR/parsing task — more valuable than any connector.

---

## 9. Tooling
- **Connected:** GitHub MCP, Xcode MCP.
- **Add at Phase 1:** an **Apple/Swift documentation MCP** (ScreenCaptureKit and Vision
  APIs shift between versions; live docs cut hallucinated calls) — the priority one. A
  **filesystem MCP** if the Xcode server doesn't already grant read/write outside the
  project bundle (the TS engine and usage-data JSON may live in a sibling folder).
- **Skills:** none required to start; the "ScopeLens conventions" skill once the
  architecture is concrete code rather than a plan.
- **Fixtures:** real preview + battle screenshots, committed as test data.

---

## 10. Model note
Current models handle the deterministic engine well — wrapping @smogon/calc, a type
chart, a usage JSON, and an MCP server are well-trodden patterns a model can largely
write from a tight spec. The vision / live-tracking layer does **not** one-shot: it's
a write-a-pass, run-on-real-footage, see-what-breaks, refine loop, because you can't
robustly parse a UI you can't see. So: engine ≈ mostly model-written; vision ≈ genuinely
collaborative iteration. Spec quality is the determinant — which is what this document
is for.

*Model availability (for reference):* Claude Fable 5 is a Mythos-tier model not
currently available to the public — access was suspended under an export-control
directive — so Claude Opus 4.8 is the practical choice today, and it's more than
capable here. That status may have changed; check Anthropic's announcements.

---

## 11. Phasing / roadmap
- **Phase 0 — OCR spike. ✅ Done.** A macOS window that takes a screenshot, runs
  Vision, and overlays recognized strings + confidences + boxes. Verified end-to-end.
- **Phase 0.5 — Screen-anatomy diagnostic. ✅ Done.** OCR dump + icon isolation across
  7 fixtures; state-dependent region model derived; icon-anchoring validated; the
  contract's parsing conventions established.
- **Phase 1 — Scout report. ✅ Done (as diagnostic CLIs; in-app UI pending).**
  - 1a Type-icon classifier: templates for 16/18 types (Electric & Ice pending a
    fixture), 12/12 on a held-out fixture; low-margin flag marks laser-degraded
    reads for frame voting later.
  - 1b Species identifier: type-constrained candidates, pixel-icon + HOME-render
    **rank-fusion** ensemble; stills top-1 14/25, top-3 22/25 → the report shows
    top-3 with thumbnails and one tap confirms. Ceiling identified: Champions-
    native reference art (Phase-2 harvest) + frame voting.
  - 1c Engine + scout report: the §4.3 engine as TypeScript in JavaScriptCore
    (@smogon/calc, gen-9 chart, meta priors; megas auto-resolve from stones; sun
    inferred from Charizardite Y); `Diagnostics/ScoutReport.swift` chains
    pipeline output → report (likely sets with %, KO-range threats, best
    answers, heuristic bring-4). Sample:
    `Fixtures/preview/Team_Preview_Initial_scout.md`.
- **Phase 2 — Live tracker / "battle streamer" (next).** ScreenCaptureKit
  continuous capture + screen-state machine + running `BattleState` + reconciler.
  All-mode fixtures exist (18 across lobby/matchup/preview/battle/result). Should
  auto-harvest keyframes as fixtures and confirmed sprite→species crops as a
  native reference set — species ID improves as a byproduct of playing.
- **Phase 3 — Live overlay + toggle-able LLM advisor.** The always-on engine readouts
  plus the opt-in LLM "what's the play" layer, over the live feed.

---

## 12. Current status
Phases 0–1 are complete and merged (PRs #1–#5): OCR spike; screen-anatomy
diagnostic over all-mode fixtures; team-preview opponent reader (6/6 rows on five
fixtures, including two cold tests); type-icon classifier; species identifier;
TypeScript engine + JavaScriptCore scout report. Everything Phase-1 lives as
diagnostic CLIs under `Diagnostics/` with committed outputs under `Fixtures/`;
parsing conventions and hard-won findings are recorded in `Diagnostics/README.md`.
**Next: Phase 2** — the ScreenCaptureKit live tracker ("battle streamer"), plus
promoting the scout report from CLI to an in-app window.

---

## 13. Open questions / pending decisions
- **Species-sprite matching approach** — RESOLVED for stills (type-constrained
  rank fusion of pixel icons + HOME renders); remaining open item is the
  Champions-native reference harvest + frame voting in Phase 2.
- **Usage-data source for Champions Reg M-B** — RESOLVED (Pikalytics JSON-LD
  snapshot; see §6). Remaining: refresh cadence and ToS posture.
- **Capture route** — real-device (phone / Switch) vs emulator; resolved per user via
  BYOD, pending a check of Champions' emulator stance.
- **Champions overrides** — the delta layer's contents, accumulated as discrepancies
  surface.
- **Public repo** — if the repo is ever opened, scrub / regenerate the fixture
  screenshots (they contain trainer names).
