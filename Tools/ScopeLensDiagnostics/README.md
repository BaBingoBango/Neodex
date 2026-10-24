# ScopeLens Diagnostics

> **Moved into Neodex on 2026-10-24.** These harnesses now compile the sources in
> `Packages/ScopeLens/Sources/ScopeLens/` and read the engine from `Tools/ScopeLensEngine/`; run
> them from the Neodex root (`Tools/ScopeLensDiagnostics/verify-all.sh`). The fixtures, real
> Champions screenshots that carry other trainers' names, stay in the private Scope Lens checkout:
> set `SCOPELENS_FIXTURES` to its `Fixtures` folder (the scripts default to `../Scope Lens/Fixtures`).
> The historical notes below keep the old layout's paths: `Scope Lens/` is now
> `Packages/ScopeLens/Sources/ScopeLens/`, `Engine/` is `Tools/ScopeLensEngine/`, and `Diagnostics/`
> is `Tools/ScopeLensDiagnostics/`.

Standalone Swift CLI tools for discovering parsing details from **real** Champions
screenshots. These run **outside the app sandbox** (so they can read fixtures and
write to the repo), and are **not** part of the app target. Nothing here simulates
battle logic — it only observes what the screen shows.

## Scripts

- **`OCRDump.swift`** — runs Apple Vision text recognition over every fixture under
  `Fixtures/screenshots/**` and writes `ocr-dump.txt` at the repo root
  (also echoed to stdout).
  Columns: `string | confidence | script | center(x,y) | size(w,h)`.
  Coordinates are normalized 0–1 with **origin top-left**. Settings:
  `recognitionLevel = .accurate`, `usesLanguageCorrection = false`,
  `recognitionLanguages = [en-US, ja, ko, zh-Hans, zh-Hant, fr-FR, de-DE, es-ES, it-IT]`.

- **`IconIsolation.swift`** — saves a crop of each **in-battle HUD** species icon to
  `Fixtures/icons/<file>_<slot>.png`. Anchors off reliable OCR tokens (opponent `%`,
  my plate name) rather than HP-bar color, because global color detection is too
  noisy against the stadium background (red arena divider, lights).

- **`TeamPreviewReader.swift`** — isolates the six **opponent rows on the Team
  Preview screen** into `{plate, sprite, typeBand, type1, type2, gender}` crops under
  `Fixtures/preview/<fixture>/row<n>_*.png`, plus a per-fixture contact sheet and
  `Fixtures/preview/manifest.json` (normalized geometry + a heuristic gender guess).
  Modes: `probe` (print sampled colors) / `extract` (default).

- **`TypeIconClassifier.swift`** — classifies each opponent row's 1–2 **type icons**
  using templates harvested from verified fixture crops (`Fixtures/type-templates/`).
  Modes: `harvest` (rebuild templates from the labeled slots) / `classify` (default;
  writes `Fixtures/preview/types.json`) / `debug <fixture> <row> <slot>`.
  Feature = largest connected component of icon-colored pixels → median color
  compared in **chromaticity** (brightness-normalized, laser-robust) + a 24×24
  white-glyph mask IoU. Empty type1 slot ⇒ mono-type. Scores 12/12 on a held-out
  fixture and 40/41 slots overall; the output's `margin` field flags unreliable
  reads (≤ ~0.05 ⇒ re-read next frame live). Nearest-pair confusions: Dark↔Ghost,
  Steel↔Flying — both only under laser overlays. **Template coverage: 18/18 —
  COMPLETE** (Electric harvested 2026-07-02 from the user's mono-Electric
  Raichu fixture "Team with Electric Type"; pre-harvest the icon read as Bug
  at margin 0.03, i.e. correctly flagged unreliable). Species baselines with
  the new fixture's truth rows: top-1 16/29, top-3 24/29 — Raichu and Milotic
  are reference-art misses (Raichu → Eelektross/Pincurchin/Electivire;
  Milotic → Feebas, the evolution-neighbor class): confirm-taps handle them
  live; the m4 native-reference harvest is the structural fix.

- **`SpeciesIdentifier.swift`** — matches each opponent preview sprite against
  reference art, constrained by the classified type pair (a low-margin type slot
  *widens* the candidate set rather than discarding the prediction; mono-type is
  structural). Two reference styles are ensembled by Borda rank fusion, because
  they fail differently: the **pixel menu-icon sheet** shares the box-icon *poses*
  Champions uses, while Showdown **"dex" sprites** (120×120 HOME renders, fetched
  by `fetch-reference-sprites.js`, gitignored) share the modern *palette*.
  Feature = largest connected component → 24×24 aspect-preserved grid; score =
  per-cell color + silhouette IoU. Current stills accuracy: **top-1 14/25,
  top-3 22/25 (88%)** — the scout report should present top-3 with sprite
  thumbnails, and live capture adds frame voting. Known ceiling: neither
  reference is Champions' actual menu-icon art; the Phase-2 streamer should
  auto-harvest confirmed sprite→species pairs into a native reference set.
  Evolution-stage neighbors (Girafarig/Farigiraf) and same-shape legendaries
  (Ho-Oh/Charizard, Archaludon/Dialga) are the persistent confusions.

## Run

```sh
swiftc -O Diagnostics/OCRDump.swift            -o /tmp/ocrdump  && /tmp/ocrdump
swiftc -O Diagnostics/IconIsolation.swift      -o /tmp/icons    && /tmp/icons
swiftc -O Diagnostics/TeamPreviewReader.swift  -o /tmp/preview  && /tmp/preview extract
```

## Key findings (2026-07-01, 18 iPhone 17 Pro Max fixtures — all screen modes)

**In-battle HUD (from the OCR dump + icon isolation):**
- The HUD is state-dependent: full HUD only in command/move-select; narration frames
  show just a message banner. Cheap discriminator: opponent `%` tokens ⇒ HUD state.
- HP is asymmetric: yours exact (`154/154`), opponent's `%`. Vision misreads the
  slash (`154/154` → `1547154`) — parse digit runs.
- Opponent species identity needs pixels: battle nicknames are e.g. Japanese
  katakana; when the opponent doesn't nickname, English species names do appear —
  usable as a *weak corroborating* signal only.
- Anchoring beats color: OCR-token anchors are robust; raw color detection
  false-fires on the arena divider/lights.
- `switchSelect` shows opponent **bench HP%**; `targetSelect` shows **status
  conditions** ("Burned", "Poisoned") and per-target effectiveness; `communicating`
  keeps both HP plates on screen with mini status icons.

**Team Preview (from TeamPreviewReader):**
- The opponent column is detected dynamically by its crimson plate color — required,
  because the column sits at different x per sub-layout (pre-submit ≈ 0.754–0.880,
  submitted/"Preparing for Battle" ≈ 0.669–0.796 on these fixtures).
- Rows anchor on plate **bottom edges** (the one transition that is always crisp);
  missing edges are synthesized from the median plate height (≈ 0.107·h, pitch
  ≈ 0.117·h). Plate interiors keep ≥ ~0.42 crimson density; **floor reflections**
  (~0.26) below the last plate are rejected by a mean-density filter.
- **The two sub-layouts differ in vertical anchoring.** Submitted: entry content
  (sprite, icons, gender) sits *inside* its plate. Pre-submit: each entry's sprite +
  type icons anchor to the plate's **top seam and overhang upward** (the icons that
  visually appear "in" a plate's lower half belong to the *next* entry).
- **Mono-type Pokémon show one icon in the type2 (right) slot**; type1 is empty.
  `typeBand` spans both slots so a classifier can segment 1-vs-2 icons.
- Opponent rows have **no name text in any variant** — sprite + type icons + gender
  are the complete identity evidence. (Type icons verified crisp: Grass/Fairy,
  Normal/Psychic, Fire/Flying, Water/Flying, Steel/Dragon, Grass/Poison across the
  first fixture.)
- Gender heuristic (red vs blue circle) scores 16/18 on current fixtures. Known
  limitation: genderless entries (e.g. Dialga) show no icon, and an overlapping
  pink laser can read as a false ♀ — live capture should vote across frames, and
  the app-side classifier owns the authoritative call.

**Screen-state classification (2026-07-02, 21 stills + the full 10-min recorded battle):**
- Approach: weighted positional text signatures over the OCR tokens → argmax;
  top score < 1.0 ⇒ `unknown`. Confidence blends signal strength with the
  margin over the runner-up (narration-only frames legitimately sit ≈0.4).
- Decisive signals per mode: FIGHT/POKÉMON buttons (command); "Move Info"
  (moveSelect); ≥2 exact-HP fractions in the left column band x∈[0.08,0.30],
  y∈[0.12,0.75] (switchSelect — bottom-plate HP in command/moveSelect sits at
  y≈0.94, outside it); "Close" + mid-screen effectiveness labels (targetSelect);
  "Communicating" at (0.5, 0.28) (communicating — ALSO floats over the live
  arena with full HP plates, not just the dedicated screen); message banner in
  y∈[0.66,0.76], x∈[0.22,0.68] as a deliberately weak signal (narration);
  "Begin Matchmaking" (lobby); giant "VS" (matchup); giant WON/LOST (result —
  OCR reads the stylized text as "WOND"/"LOST..."); Select-4 text /
  "Preparing for Battle" / "Done"+"n/4" (teamPreview).
- **"Back" is NOT a moveSelect signal** — a voluntary switchSelect shows it too.
- Stadium billboard ads OCR as garbage Latin tokens at y < 0.12 — position-gate
  everything; never match on unanchored text.
- The **ability chip is fixed-position** ("Species's"/"Ability" stacked at
  x≈0.16, y≈0.50/0.54) but that geometry exactly matches teamPreview's
  species/item rows → the overlay detector gates on primary ∈ {narration,
  command, communicating, unknown} (chips persist over animation frames).
- summaryPanel = "Hide Summary" OR the "Moves & More"+"Stats" tab pair.
  "Show Summary" is the closed-state button — not the overlay.
- **Real ranked flow: lobby → teamPreview → VS/matchup → battle** (team preview
  comes BEFORE the VS splash) → …turn loops… → result.
- Animation/cutscene frames carry no text → `unknown` is the *correct* per-frame
  answer (~34% of battle samples). The recorder's 2-sample debounce + segments
  view absorb it; persistent (≥3s) unknowns in the full-battle run were all
  verified as attack/switch-in animations, not missing screen modes.
- Result screen is a WON/LOST split — **your side is the LEFT half** (verified
  in both a win and a loss).
- QuickTime mirror recordings are **variable frame rate** (60 fps nominal,
  ~37 avg) — sample by presentation timestamp, never by frame count.
- Full-battle validation: 1211 samples → 193 transitions, structurally clean
  turn loops (command → moveSelect → targetSelect → communicating → narration),
  0 low-confidence non-unknown samples, result caught at 10:00.5. The video's
  opponent brought **no Electric-type** → type templates remain **17/18
  (Electric pending)**; the auto-harvested teamPreview keyframe is crisp enough
  to harvest from once an Electric opponent appears.

**Live capture (2026-07-02, ScreenCaptureKit vs the real QuickTime mirror):**
- The QuickTime "Movie Recording" mirror window is **effectively chrome-free**:
  captured content is the phone screen aspect-exact (± a few px), so viewport
  detection trims almost nothing. Captured 1470×678 pt → 2940×1356 px (Retina
  2×) — above fixture resolution.
- **Live behavior is identical to offline**: same confidence profile per state
  (lobby 0.78, menus 1.00, communicating 0.75, narration 0.40), a full ranked
  battle tracked end-to-end at 2 fps with ~0.25s capture+OCR per sample.
- SCK gotchas, hard-won: window **discovery must use `onScreenWindowsOnly:
  false`** (the mirror usually lives on another Space → `isOnScreen == false`,
  and desktop-independent capture works there anyway); CLI processes need
  `_ = NSApplication.shared` before `SCScreenshotManager` or CG asserts
  (`CGS_REQUIRE_INIT`); Screen Recording TCC attributes to the **host process**
  (terminal/Claude) for CLIs — the app bundle needs its own grant.
- The app target builds with **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`**
  (Xcode 26 default): shared pipeline types (classifier, capture, viewport) are
  explicitly `nonisolated` so in-app OCR can run off the main thread; plain
  `swiftc` CLI builds don't set that flag, which would otherwise mask the issue.
- ~~Discovered taxonomy gap (live!)~~ **RESOLVED same-day via the harvest loop**:
  battle 2's live keyframes captured the post-battle **rating-update screen**
  (rank card: tier, "RANK n", "Placement: No. …", "(Rating: …)" + signed
  delta). Added `ScreenState.ratingUpdate` — decisive signal `"Placement"`
  (3.0) + signed rating-delta token (1.0). CAUTION: the **live lobby's ranked
  card also shows "Placement"** (the still fixtures never OCR'd it) — lobby's
  own signals total ≥5.0 and must keep outranking it; verified on live lobby
  captures (lobby 5.0 vs ratingUpdate 3.0 → still lobby, conf 0.78→0.70). The
  harvested keyframe is promoted to a committed fixture
  (`Rating Update/Rating Update.png` — harness now accepts .png), 22/22 at
  both scales. `result` also confirmed live once the screen isn't tapped
  through (left half = you, again).
- **QuickTime save-flow trap**: stopping/saving a recording turns the mirror
  window into a movie *document* — its playback then classifies as live battle
  frames (a harvested "moveSelect" 12s after the rating screen was the replay).
  `findQuickTimeMirror` now prefers the "Movie Recording" title over other
  QuickTime windows. Flip side, deliberately kept: pointing capture at a saved
  movie window replays recorded footage through the live path — free offline
  replay analysis.

**Preview pipeline in-app (2026-07-02, Phase 2 m3a):**
- Fixtures now live at **`Fixtures/screenshots/`** (moved out of the app's
  synced folder — Xcode was copying every fixture AND the gitignored videos
  into the app bundle on each build: 2.3GB → 1.2MB. Folder-level
  `membershipExceptions` don't exist; relocation is the robust fix.)
- **Derived JSONs are the geometry spec.** TeamPreviewReader's sprite
  fractions had silently drifted from the committed manifest.json — species
  top-3 dropped 22/25 → 18/25 when regenerated. Fractions were restored by
  deriving them plate-relative from the committed manifest. Lesson: after ANY
  crop-fraction change, regenerate the manifest → types → species chain and
  re-score before committing.
- `PreviewPipeline` (app target) reproduces the CLI chain: type holdout
  12/12, species top-1 14/25 / top-3 22/25 — same knife-edge misses, same
  Steel↔Flying laser slot. Verified via PreviewPipelineHarness.
- **Frame voting works.** 57 preview frames of the recorded battle (heavy
  pink lasers, BOTH sub-layouts): per-frame top-1 flickers
  (Salamence/Noivern for Dragonite; Dialga-Origin for Archaludon) wash out;
  consensus reads the full team at 98–100% type stability — Dragonite /
  Sinistcha / Swampert / Pelipper / Archaludon / Sableye, three independently
  confirmed by battle footage. **Row index stays a valid identity across the
  pre-submit → submitted layout change.**
- The live tracker runs the pipeline on teamPreview frames (full-res crop,
  ≤1 Hz, lazy bundle load) and shows the voted read in an "Opponent read"
  panel as it stabilizes.

**Live-verified m3a + classifier tuning (2026-07-02 evening, Example Battle 3):**
- User ran the in-app Opponent read live ✓. Second offline aggregator
  validation on the new battle: 150 preview frames, **100% type stability on
  all six rows** (Farfetch'd / Typhlosion-Hisui / Gholdengo / Zygarde /
  Whimsicott / Basculegion).
- **The activation chip is one UI for TWO proc kinds** — frames confirm
  "Incineroar's Intimidate" (ability, species mini-sprite icon) and
  "Incineroar's Sitrus Berry" (item, item icon) at the same fixed position.
  Overlay renamed `abilityChip` → **`activationChip`**; discrimination is the
  m4 BattleState parser's job (closed vocabularies; the icon pixels are a
  fallback discriminator if ever needed).
- **Narration sparse-frame gate**: real narration frames carry ≤8 tokens;
  text-dense generic menus (20–40 tokens) always drop something into the
  banner band and previously misread as `narration` (user-observed while
  menu-browsing). Narration now additionally requires ≤14 total tokens.
  22/22 fixtures at both scales after both changes.
- `ratingUpdate` validated offline on a fresh battle (Example Battle 3,
  09:23.5). Known cosmetic flicker: the rating→lobby fade can pass through a
  1–2s `matchup`/low-conf `narration` blip (fading text density) — lifecycle
  consumers should debounce on segment level, as the recorder already does.

- **`ClassifierHarness.swift`** — verifies the app-target **`ScreenStateClassifier`**
  (`Scope Lens/ScreenStateClassifier.swift`) against all 21 labeled still
  fixtures (folder = ground truth; battle sub-modes pinned by eyeballing).
  Every fixture runs at full resolution AND 0.5 scale — the session recorder
  OCRs half-res frames, so both must stay green. Current: **21/21 at both
  scales**. Exit code 0 iff all pass.
  ```sh
  swiftc -O Diagnostics/ClassifierHarness.swift "Scope Lens/ScreenStateClassifier.swift" \
    -o /tmp/classifierharness && /tmp/classifierharness
  ```

- **`SessionRecorder.swift`** — offline "battle streamer" (Phase 2 milestone 1):
  streams a recorded battle `.mov` through the classifier (~2 fps, VFR-safe
  presentation-timestamp sampling via AVAssetReader) and writes
  `Fixtures/harvest/<session>/` (gitignored) with `timeline.json`, `report.md`,
  and a full-res keyframe PNG at every debounced state transition (state must
  hold ≥2 consecutive samples; the *confirming* frame is saved — the first frame
  of a run is usually mid-fade). `unknown` keyframes are saved half-res
  (eyeball-only; real fixtures re-extract from the .mov by timestamp). Flags:
  `--video --fps --scale --start --duration --out`.
  ```sh
  swiftc -O Diagnostics/SessionRecorder.swift "Scope Lens/ScreenStateClassifier.swift" \
    -o /tmp/sessionrecorder && /tmp/sessionrecorder
  ```

- **`LiveCaptureProbe.swift`** — live-capture spike harness (Phase 2 m2): drives
  the app-target **`MirrorCaptureSource`** (ScreenCaptureKit window discovery +
  one-shot capture + viewport detection) and the classifier against the real
  QuickTime mirror. Modes: `list` (shareable windows), `shot` (capture → raw +
  viewport PNGs + classify both), `stream [--seconds N] [--fps N]` (live states
  with SessionRecorder-style debounced keyframe harvest into
  `Fixtures/harvest/live-probe/live-<stamp>/`).
  ```sh
  swiftc -O Diagnostics/LiveCaptureProbe.swift \
    "Scope Lens/MirrorCaptureSource.swift" "Scope Lens/ScreenStateClassifier.swift" \
    -o /tmp/liveprobe && /tmp/liveprobe list
  ```

- **`PreviewPipelineHarness.swift`** — proves the app-target
  **`PreviewPipeline`** port (Phase 2 m3a) reproduces the Phase-1 CLI chain,
  and precomputes the app's dex-feature resource. Modes:
  `precompute` (Fixtures/reference/dex-sprites → 24×24 features →
  `Scope Lens/Resources/PreviewPipeline/dex-features.json`, so the app ships
  the ensemble without the 96MB sprite folder) / `verify` (port outcomes on
  the 6 preview fixtures vs the CLI truth tables; acceptance = type holdout
  12/12, species top-1 ≥14/25, top-3 ≥22/25) / `video [--start --duration]`
  (frame-voted consensus over a recorded battle's preview segment).
  ```sh
  swiftc -O Diagnostics/PreviewPipelineHarness.swift "Scope Lens/PreviewPipeline.swift" \
    -o /tmp/pipelineharness && /tmp/pipelineharness verify
  ```

- **`ScoutReport.swift`** — end-to-end Phase 1: feeds the pipeline's opponent
  reads (`species.json`, with `row=Species` override args simulating the user's
  confirm-taps) plus our team into the **TypeScript engine**
  (`Engine/dist/engine.js`) running in **JavaScriptCore**, and prints/saves the
  team-preview scout report: per-opponent meta profiles (moves/item/ability with
  usage %), biggest incoming threats and best answers as @smogon/calc damage
  ranges, and a heuristic bring-4 + leads. Assumptions are printed in the report
  footer. Engine data: `Engine/data/meta-regmbs3.json`, snapshotted from
  Pikalytics Champions Reg M-B S3 pages via `Engine/fetch-meta.js` (**119
  species — the full ladder** as of 2026-07-02). Enumeration: the ranked-list
  page lazy-loads, so the fetcher crawls the TEAMMATE GRAPH breadth-first
  from the index page's server-rendered seeds — species are discovered via
  `championssprites/<slug>.png` images and `data-candidates` attributes (NOT
  hrefs; index hrefs also carry `?l=en` variants that must be stripped).
  Converges at ~122 pages, politely (2 concurrent, 200ms spacing). Empty
  profiles (unranked, e.g. zygarde) are dropped so hasMeta stays honest.
  **Dynamic stats seam**: `ScopeEngine.setMeta(json)` swaps the usage
  snapshot at runtime; the app bundles `meta-regmbs3.json` as a DATA file
  (Resources/Engine/) and injects it at ScoutEngine init — a meta refresh is
  now a JSON swap, no engine rebuild (baked snapshot remains the fallback). Rebuild
  the engine with the PINNED esbuild (a devDependency since m3b — a bare `npx
  esbuild` resolves to whatever is newest and made builds unreproducible):
  `cd Engine && node_modules/.bin/esbuild src/engine.ts --bundle --format=iife --global-name=ScopeEngine --banner:js="var console={log:function(){},warn:function(){},error:function(){}};" --outfile=dist/engine.js`
  and copy `dist/engine.js` to `Scope Lens/Resources/Engine/` for the app.

- **`BattleReplayHarness.swift`** — Phase 2 m4: the **paper replay**. Streams a
  recorded battle through classifier → `BattleEventParser` → `BattleReconciler`
  (all app-target files) and writes `battle-log.md` + `events.json` +
  `battlestate.json` under `Fixtures/harvest/replay-<stem>/` (gitignored).
  During the video's teamPreview segment it votes a `PreviewPipeline` consensus
  (≤1 Hz, full-res) and seeds the reconciler — the offline twin of the Phase-3
  live loop. Modes: `replay [--video --fps --scale --start --duration --out
  --dump]` (`--dump` adds per-frame `observations.jsonl` — the debugging
  microscope) / `fixtures` (the committed token-fixture regression under
  `Diagnostics/fixtures/battle-events/`, stage 4 of verify-all; 24/24).
  ```sh
  swiftc -O Diagnostics/BattleReplayHarness.swift \
    "Scope Lens/ScreenStateClassifier.swift" "Scope Lens/BattleVocabulary.swift" \
    "Scope Lens/BattleState.swift" "Scope Lens/BattleEventParser.swift" \
    "Scope Lens/BattleReconciler.swift" "Scope Lens/PreviewPipeline.swift" \
    "Scope Lens/TeamStore.swift" \
    -o /tmp/battlereplay && /tmp/battlereplay fixtures
  ```

- **`NativeReferenceHarvest.swift`** — Phase 2 m5: banks Champions-native
  sprite crops from CONFIRMED reads into `Fixtures/reference/native/<Species>/`
  (gitignored) and precomputes the bundled
  `Scope Lens/Resources/PreviewPipeline/native-features.json`. Strict
  provenance: still fixtures use the committed truth tables; videos use only
  rows the m4 replay corroborated from narration. Modes:
  `still <fixtureStem> row=Species …` / `video --video PATH [--start
  --duration --every] --labels row=Species …` / `features` (rebuild the
  JSON) / `calibrate` (same-species vs cross-species distance stats +
  extreme pairs — the mislabel detector).
  ```sh
  swiftc -O Diagnostics/NativeReferenceHarvest.swift "Scope Lens/PreviewPipeline.swift" \
    -o /tmp/nativeharvest && /tmp/nativeharvest calibrate
  ```

## m5 findings (2026-07-03, Champions-native sprite-reference tier)

- **Species accuracy: top-1 16/29 → 23/29, top-3 24/29 → 25/29**, measured
  leave-one-source-out (evaluating a fixture holds out crops harvested from
  it, so every native hit means "seen this species in ANOTHER source"). Six
  rows resolved by the decisive same-art tier. All four remaining top-1
  misses (Scizor, Sylveon, Raichu, Milotic) are species with no cross-source
  crops yet — exactly the ones live confirm-taps will bank next.
- **Native crops separate cleanly**: same-species cross-source distance
  median 0.078; cross-species floor 0.450 (75 crops, 21 species). Decisive
  override: distance < 0.30 AND ≥ 0.15 margin over the nearest other
  species; otherwise the native list is a third Borda voter whose ABSENCE is
  never penalized (most species have no crops yet).
  `SpeciesCandidate.fusedRank == -1` marks decisive winners.
- **The calibrator is a mislabel detector.** First run showed
  Archaludon(video) ↔ "Dialga"(stills) pairs at 0.085–0.129 — same-art
  territory across different labels. Eyeballing proved the crops identical:
  **the session-1 confirm-tap "Dialga" was wrong; that mon is Archaludon**
  (battle-1 narration had already confirmed Archaludon via Electro Shot +
  Stamina). Fixed everywhere: truth tables (PreviewPipelineHarness,
  SpeciesIdentifier), the committed scout sample (regenerated — the recorded
  exact invocation is now `1=Farigiraf 2=Charizard 3=Pelipper 4=Archaludon`),
  native crop labels. Lesson: cross-source distance collisions between
  different labels are label bugs until proven otherwise.
- **Shiny variants are real**: Extra Team 1's Charizard is shiny (charcoal
  body) — same-species distances hit 1.19 on color alone. Multiple features
  per species with min-distance matching absorbs it; a single color-true
  reference never would. Bank shiny crops as normal features of the species.
- Laser/occlusion-degraded crops (battle-1 Sableye) sit at 1.1+ from their
  clean siblings — they never fire the decisive tier and, under
  min-over-features, only ever help.
- Battle-3 video consensus with its own crops held out now reads **Garchomp
  (468) over Zygarde (279)** on the Dragon/Ground row at preview time — the
  user-reported "Zygarde" miss is structurally fixed, not just corrected
  after the fact.

## m5b (2026-07-03, live Battle Log)

- The live tracker now runs the full m4 battle-state layer per sampled frame:
  ONE Vision pass feeds both `classify(tokens:)` and
  `BattleEventParser.observe` (no added OCR cost), and a per-battle
  `BattleReconciler` publishes events + a compact §4.5 state summary to the
  **Battle Log window (⇧⌘B, auto-opens on the first battle event)** with
  Copy-Markdown and Reset.
- Battle lifecycle: fresh reconciler on (a) user Reset, (b) a team preview
  after a >60s gap (the aggregate's new-battle rule), (c) a preview arriving
  after the previous battle ended. Preview consensus seeds the opponent
  bench at the same ≥5-frame bar the scout report uses.
- Live-validation notes for the pilot: run a ranked battle with the log
  open — or point capture at a saved battle .mov in QuickTime (the
  documented replay-through-live-path trick) to see the log narrate recorded
  footage without queueing.

## m7 (2026-07-03, Phase 3 opens: Live Matchup panel + tap banking)

- **Discovery that reshaped the plan: @smogon/calc and @pkmn/dex already
  carry Champions mega data** (Showdown implemented Champions). Scrafty-Mega
  is real in both (Dark/Fighting, 130 Atk, Shed Skin); **Mega Staraptor is
  Fighting/Flying with 140 Atk / 110 Spe** — my hand-guessed override types
  (Normal/Flying) were wrong but never shipped: build-vocab's dedup had
  preferred the dex entries all along. `champions-overrides.json` is now
  empty (sightings documented in `_sightings`); it remains the mechanism for
  genuinely-missing future content. The calc constructor THROWS for unknown
  species (verified) — the engine's fallback chains are sound.
- **`ScopeEngine.liveMatchup`** (Phase 3's deterministic advisor): current
  actives + everything observed (revealed moves, items, abilities, BOOSTS,
  status, current HP) + the live field (weather, Trick Room, Tailwind,
  screens via calc defenderSide) → best damage both directions with
  `koNow`/`guaranteedKo` vs CURRENT HP, per-pair `setSource` labels
  (observed/prior/learnset), `approx` flags for unknown-forme fallbacks, and
  a TR-aware speed order (stages, paralysis, Tailwind ×2). Harness-checked
  on battle 4's turn-6 board: Scrafty-Mega Rock Slide 84–102% into the
  32%-HP Charizard = the actual kill shot.
- The **Battle Log window now shows the Matchup panel** while a battle runs:
  top incoming threats, top outgoing answers, KO badges, speed order.
  Recompute is signature-gated (species/HP-bucketed-5%/reveals/boosts/
  status/field) so the JSC engine isn't thrashed by plate animation; the
  publish gate keys on count + last event value because HP coalescing edits
  the tail event in place.
- **m7a: confirm-taps permanently teach the matcher.** A pin banks the row's
  sprite crop + feature into Application Support (sandboxed) as a live
  overlay (`native-features-live.json`, source "live-tap") that
  `PreviewPipeline.bundled(nativeOverlayJSON:)` merges — the pipeline
  reloads on the next preview frame, so the CURRENT session already
  benefits. One bank per row per battle; crops retained for the offline
  harvest to import later. This is the path that covers the four remaining
  species misses (Raichu, Milotic, Scizor, Sylveon) and unrevealed-row
  classes (Mawile/Annihilape) as Ethan encounters them.

## m8 (2026-07-03, Perish Song + the "What's the play" advisor)

- **Battle 5 (live): a Mega Gengar Perish-trap loss** — parser gaps closed:
  Perish Song templates (`perishSong` clocks all actives at cast;
  `perishCount` with the "O"-for-zero wobble; count REQUIRED so truncated
  reads can't default to "dies now"), doom clocks clear on switch-out/faint
  and only apply to actives (misattribution guard), new `.perishCount` event
  kind (⏳ lines). "went back to <trainer>" = opponent recall wording (fixed
  the one wrong LRU eviction). Rage Powder redirect + "used." wobble.
- **Dedup-chain bug**: an unrecognized fragment BETWEEN two identical clean
  reads reset the single-slot parse memory → ×3 Mega Evolved / ×3
  Thunderbolt events. Fix: keyed recent-parses window (3.5s). Fixture
  asserts EXACT event counts (`expectExactKindCounts` harness feature).
- **mm:ss rounding**: 299.96s rendered "04:60.0" — round to tenths before
  splitting minutes. Prefix-match entity resolution ("Incinero" →
  Incineroar) stops truncated reads minting duplicate entities.
- **Advisor (Phase 3's LLM layer, opt-in per spec §4.1):**
  - `AdvisorContext` renders everything ScopeLens knows as a labeled coach's
    notepad (observed vs priors, perish clocks, KO flags, speed order,
    benches, recent events) + a 3-sentence-max system prompt: the
    deterministic math is authoritative; the model prioritizes and picks a
    line, never calculates.
  - `AdvisorClient`: URLSession → Messages API. Key: app Keychain (Settings
    pane, ⌘,) with ANTHROPIC_API_KEY env fallback; never logged. Model
    `claude-opus-4-8`, `thinking: {type: adaptive}` EXPLICIT (omitting runs
    thinking-off on Opus 4.8), `output_config.effort: low`, max_tokens 1500
    (adaptive thinking bills into the budget — a 300 cap returned an empty
    answer with stop_reason max_tokens on the first attempt).
  - `Diagnostics/AdvisorHarness.swift`: offline proof — replays a battle to
    --at seconds, builds the same context, REAL API call with the key from
    .env.local (never printed), prints advice. Battle 5 @ t=345 produced
    correct coaching ("Hydro Pump into Gengar — guaranteed KO; expect
    re-Perish") in 11.8s — matching the play the pilot actually made.
    NOT part of verify-all (network + cost); run manually.
  - Battle Log window: "What's the play?" button + per-turn Auto toggle +
    advice card. App sandbox gained ENABLE_OUTGOING_NETWORK_CONNECTIONS.

## m9 (2026-07-06, team management — the hardcoded six become data)

- **The team is a Showdown paste now.** `Scope Lens/TeamStore.swift` (shared,
  Foundation-only) parses Showdown export text → Codable `Team`/`TeamMember`
  (species/nickname/gender/item/ability/moves/nature/tera/level/EVs/IVs/shiny),
  snaps names to vocab.json canonically (case/punctuation/apostrophe-
  insensitive match keys — "farfetchd" ⇒ "Farfetch’d"), and validates
  (unknown species = error; unknown item/move/ability, EV overspend, >4
  moves = warnings). Natures are a hardcoded 25-set (game constant, not in
  vocab.json); junk natures are dropped so the calc never sees garbage.
- **Committed default paste — the parity convention:**
  `Scope Lens/Resources/Team/default-team.txt`. The app BUNDLES this file as
  its first-run fallback; every CLI (ScoutReport, ScoutEngineHarness,
  BattleReplayHarness, AdvisorHarness) reads the SAME file from the repo via
  `Team.fromRepoDefault(root:)` — app and diagnostics agree by construction.
  The app's ACTIVE team lives at Application Support/team.json (TeamManager,
  app-only), edited via Settings ⌘, → Team tab (paste import + validation +
  revert-to-default). It mirrors the current ladder team with NO EV lines
  (they were never known) — engine numbers stay identical until Ethan pastes
  real spreads.
- **EVs/IVs/natures/level now ride MonSpec** (Swift + TS) into @smogon/calc:
  used verbatim when present, synthetic 252-offense/252-HP defaults
  otherwise (additive — absent fields behave exactly as before). Speed
  estimates use configured spreads (bridge-checked: Mega-Charizard-Y 120
  neutral → 167 Timid/252, exact L50 stat math). `teraType` is carried but
  NOT applied to calcs (no live tera tracking yet). Scout `bestThreat`
  defenders also gained their item/ability (AV/Levitate-class effects) —
  the assumptions footer always claimed this; now it's true. The committed
  scout sample regenerated with its exact recorded invocation
  (`1=Farigiraf 2=Charizard 3=Pelipper 4=Archaludon`): ONLY the assumptions
  line changed — zero number drift on that matchup.
- **Live matchup merge:** your side's actives now combine the configured
  slot (full moveset, real spread) with live observations (observed
  item/ability/boosts/HP/status win where present; revealed moves the
  config doesn't list are kept via ordered union — a stale team can't hide
  a move the battle proved). Proof on battle 5 @ t=190: Charizard's best
  answer became **Weather Ball 93–110% guaranteed KO into Gengar-Mega** — a
  move the revealed-only matchup never saw. Advisor context gained a
  "YOUR TEAM (configured — full sets, ground truth)" section.
- **ScoutReport.swift is now `@main`-wrapped** (top-level script code is
  only legal in single-file compiles; it now builds with TeamStore +
  ScoutEngine + BattleState) and derives repoRoot from CWD like every other
  harness — run it from the repo root.
- **Isolation lesson recurred (extensions!):** under the app target's
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `extension Team { … }` in a
  shared file silently became MainActor-isolated even though the TYPE is
  declared `nonisolated` — CLI builds don't set the flag and stay quiet;
  only the app build warns. Mark shared-file EXTENSIONS `nonisolated
  extension` explicitly (TeamStore's Team extension, ScoutEngine's
  TeamMember.monSpec). The capture loop reads the team through
  `TeamManager.Feed` (lock-protected, nonisolated) — never hop actors
  mid-frame.

## m9-B (2026-07-06, `import-live` — the species flywheel's last pipe)

- **`NativeReferenceHarvest import-live [--from PATH] [--dry-run]
  [--skip-rebuild]`** copies the app's confirm-tap bank (sandbox container →
  `~/Library/Containers/com.ethan-marshall.Scope-Lens/Data/Library/
  Application Support/ScopeLens/native-crops/`) into the repo bank, then
  auto-runs `features` + `calibrate`. Each tap becomes its OWN source
  (`live-tap-<stamp>`), which keeps LOFO honest by construction: live
  sessions are never eval fixtures, so an imported tap can only help OTHER
  sources' reads. Unfeaturizable crops are refused (same gate the app
  applies at tap time); re-imports skip (idempotent).
- **Proven end-to-end by simulation** (no real taps exist yet — the
  container has none; Ethan hasn't pinned a row live since m7a shipped):
  a crop banked through the app's REAL `NativeReferenceStore.bank(into:)`
  (baseDir-injectable since m9-B) into a fake container, imported, and
  measured. The simulated Raichu tap flipped the eval **top-1 23→24/29,
  top-3 25→26/29, decisive rows 6→7** — then was REVERTED and the bank
  rebuilt byte-identical to the committed JSON. Same-source-derived sim
  features must never be committed (they'd let a fixture's own pixels vote
  for it — the exact self-match LOFO exists to prevent). Floors stay
  22/24; they rise when REAL taps from new battles land.
- **TCC gotcha:** enumerating another app's container from a CLI can hang
  UNINTERRUPTIBLY (not error) while macOS waits on an "access data from
  other apps" consent — approve it once (or grant the terminal Full Disk
  Access), or pass `--from` a copied folder. Direct `stat` of known paths
  answers fast even when enumeration blocks.
- **Record straightened:** battle 5's corroborated rows (Gengar,
  Incineroar, Sinistcha, Politoed) were ALREADY harvested during the m8
  session (undocumented at the time) — the committed 25-species/112-feature
  bank includes source `example-battle-5`. The bank is fully caught up
  with all recorded footage; the live-tap container is the only inflow
  that remains, and it now has its pipe.

## m9-C (2026-07-06, summary-panel deep parse — observations beat priors)

- **The browsable summary panel is an exact sheet for ANY mon** (benched
  ones included — plates never show those). LOOKed first at battle-1
  harvest keyframes 104/124 (the brief's reference): left card =
  name (x∈[0.20,0.38], y∈[0.18,0.25]) · exact HP "101/156" (y≈0.28) ·
  type badges as TEXT ("GRASS"/"POISON", y≈0.33) · "Ability <value>" row
  (y≈0.39) · item row, icon + name, NO label (y≈0.44) · stat rows
  Attack→Speed then Accuracy/Evasiveness with "x1.0"-style ×multipliers at
  x≈0.41. Right side = "Active Statuses & Effects" chips ("Rain 1/5")
  with description text below.
- **`FrameObservation.SummaryRead`** (parser) + reconciler application:
  ability (💠) and item (💡) reveals, exact-HP through the SAME legality
  core as plates (extracted `applyHP(to:)` — max-consistency, fall/rise
  corroboration all apply), and a new **`boostSync`** event (🎛) that sets
  ABSOLUTE stages from the ×multiplier column: (2+s)/2 above neutral,
  2/(2−s) below, one decimal — ×1.5=+1, ×0.5=−2; −4/−5 both render 0.3
  (mapped −4; no engine decision changes at that depth). The ≥2-decoded-
  stat-rows column is the panel's structural gate — the teamPreview
  summary (stat VALUES, no ×) can't fire it, and the state gate excludes
  teamPreview anyway.
- **Mirror species disambiguation**: the panel names a mon but not a side,
  and both sides can own the same species (battle 5's double Incineroar).
  `resolveForSummary` scores candidates by consistency with known facts —
  matching max HP (+4/−4), ability (+2/−2), item (+2/−2), you-side tie-
  break (+1). Panel reads follow plate doctrine: known display or species
  snap onto an EXISTING entity; garble binds nothing; the panel never
  mints entities.
- **Trick Room chip now emits a re-sync event** when TR was thought
  inactive (`🌀 active n/m`) — previously the chip silently set the flag.
- **Fixtures 36/37 (→ 37/37)**: kf104's REAL token stream ×2 frames proves
  each reveal fires exactly once (persistence dedup — the panel stays up
  for minutes); kf37 is kf124 geometry with SYNTHETIC ×1.5/×0.5 flips
  (labeled; replace when a real boosted panel is captured) proving the
  stage map + boostSync. Real-footage validation: replaying battle-1
  05:48–06:39 emits the Rain re-sync + Chlorophyll + Focus Sash each ONCE
  across ~180 panel-open samples, 0 anomalies.
- Deliberately NOT parsed yet (LOOK doctrine — no real frames showing
  them): per-mon status chips with durations ("Burned n/m"?), opponent-
  card HP format (exact vs %), Tailwind/screen side-scoped chips. The
  generic (name, n/m) chip extraction already reads them the moment they
  appear; mapping waits for real pixels.

## m10-B (2026-07-06, MCP server — spec §4.3's promise delivered)

- **`Engine/mcp-server.js`** exposes the engine as MCP tools over stdio:
  `resolve_species`, `meta_profile`, `type_calc`, `damage_calc`,
  `scout_report`, `live_matchup` — a Claude session can now be asked
  "teach me this matchup" against the real Reg M-B snapshot with
  @smogon/calc numbers. ZERO dependencies: MCP stdio is newline-delimited
  JSON-RPC 2.0 (initialize → initialized → tools/list → tools/call → ping),
  ~120 lines of protocol. Same pinned engine bundle + data files the app
  ships → numbers match the scout CLI by construction.
- **To connect it, add to `.mcp.json`** (path documented, file never read —
  it may hold secrets):
  `{"mcpServers": {"scopelens": {"command": "node", "args":
  ["/Users/ethan/Scope Lens/Engine/mcp-server.js"]}}}`
- `scout_report.mine` defaults to the app's persisted team
  (container `team.json`; `SCOPELENS_TEAM_JSON` overrides; explicit `mine`
  always wins) — TCC may block container reads for some host processes,
  so the error message says exactly what to do.
- **`Engine/mcp-server-test.js` = verify-all stage 6** (now 6 stages):
  spawns the server, performs the real handshake, and pins parity —
  committed-sample bring-4 + Farigiraf Trick Room 95.7%, Incineroar Fake
  Out 99.9%, Modest-252 Heat Wave 24.8% max, TR-reversed speed order,
  tool-level isError shapes, -32601 on unknown methods. 12/12.
- **Node gotcha:** under `'use strict'`, DIRECT `eval` of the IIFE bundle
  keeps `var ScopeEngine` private to the eval scope — use INDIRECT
  `(0, eval)(src)` (global scope) + `globalThis.ScopeEngine`. The bundle's
  console-no-op banner then neuters the GLOBAL console: a feature here
  (stdout must stay pure protocol; server logs use `process.stderr.write`).

## m10-A (2026-07-06, overlay HUD — Phase 3's remaining spec item)

- **`OverlayHUD.swift`**: a 360pt always-on-top card the pilot parks next
  to the mirror and steers by during the ~40s move timer — turn/weather/TR
  headline, top-2 incoming/outgoing with KO badges (solid = guaranteed,
  faded "KO?" = max-roll), TR-aware speed strip (your mons highlighted),
  perish chips, latest advice + Ask/Auto. Feeds off the SAME
  LiveTrackerModel published state as the Battle Log (advisorSnapshots is
  now `@Published` for the perish chips).
- **Panel mechanics (the part worth remembering):** borderless
  `NSPanel(styleMask: [.borderless, .nonactivatingPanel])` — NON-ACTIVATING
  means clicking Ask never steals focus from the game; `.floating` level;
  `collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary]` rides
  Spaces and full-screen; `isMovableByWindowBackground` for dragging;
  `setFrameAutosaveName` gives free position persistence;
  `NSHostingView.sizingOptions = [.preferredContentSize]` lets SwiftUI set
  the panel size.
- Toggle button in the Live Tracker header; auto-opens on the first battle
  event when the "Open when a battle starts" checkbox (footer,
  `@AppStorage overlayAutoOpensOnBattle`, default ON) is set.
- Content is a PURE view (`OverlayContentView`) with the live wrapper on
  top — previewable with mocked board data; verified via RenderPreview on
  battle-4's turn-6 shape (Scrafty-Mega Rock Slide 84–101% KO? line et al).
  AWAITING PILOT GLANCEABILITY VERDICT (the m10-A done-when).

## m11-A (2026-07-07, the meta-aware AGENTIC advisor — pilot's requested direction)

- **The advisor is a tool-use loop now** (pilot's battle-6 vision verbatim:
  "this Pokémon likely uses X, so I should do Y if that speed checks — run
  that tool — now check this damage"). `AdvisorClient.advise(staticContext:
  turnContext:tools:runTools:)` drives Anthropic Messages round-trips
  (claude-opus-4-8, adaptive thinking EXPLICIT, effort low, ≤6 iterations,
  20s/request + 18s soft deadline) where the model calls the SIX engine
  tools; `AdvisorToolExecutor` runs them in-app against the same JSC engine
  in milliseconds. Tool schemas live in **`Engine/tool-schemas.json`** — the
  single source both `mcp-server.js` (MCP `inputSchema`) and the app
  (Anthropic `input_schema`, bundled copy in Resources/Engine/) load, so
  MCP clients and the advisor reason over byte-identical tool surfaces.
- **Pre-computed meta capsules** (pilot's architecture guidance: cached
  context for the always-relevant, tools for the combinatorial):
  `AdvisorContext.buildStatic` renders your full team + capsules for ALL
  opponents the reconciler knows (actives + bench incl. unclaimed preview
  rows — corroboration corrections flow in, so battle 6's Farigiraf→Oranguru
  gets the right capsule): top-4 moves w/%, top-2 items, top ability,
  winrate, **speed brackets** (new engine export `speedBrackets`: L50 0-EV
  neutral floor → 252 +nature ceiling, ×1.5 Scarf flag when it's a top item)
  and **defensive typing** (`defensiveProfile`: 4×/2×/resist/immune in one
  JSC call). Off-ladder species degrade to bracket + typing (battle 5's
  Gengar-Mega proves it).
- **Priority blockers** (battle 7's Armor Tail lesson): capsule flags a
  likely blocker ability (Armor Tail / Dazzling / Queenly Majesty ≥ top
  usage), the turn block flags an OBSERVED one, and the system prompt
  carries the rule beside PR #29's Fake-Out/priority doctrine. Farigiraf's
  capsule reads "⚠️ likely Armor Tail: PRIORITY MOVES INTO ITS SIDE FAIL".
- **Prompt caching layout** (breakpoints ≤4 by construction): tools →
  system(+marker) → first-user-message static block(+marker) → volatile
  turn text; a rolling marker moves to each newest tool_results message.
  Request bodies serialize with `.sortedKeys` (unsorted JSON = the classic
  silent cache invalidator). MEASURED on battle 5/4 replays: call 1 wrote
  6,553 tokens; a second battle-5 ask read **6,553 / wrote 0**; a battle-4
  ask read 5,128 (the battle-agnostic tools+system span) and wrote only its
  own 1,468-token static block. Opus 4.8's minimum cacheable prefix is 4,096
  tokens — the tools+system span alone (~4.8k) clears it.
- **Offline proof (AdvisorHarness, m8 flags + `--nudge TEXT`)**: battle 5
  t=190 → 1 round-trip, ZERO tool calls (context decided it — correct
  economy), advice = the pilot's actual winning play, 10.8s. Battle 4 t=240
  → correct TR-aware line + Wide Guard warning, 9.3s. Battle 5 t=130 with a
  distrust-the-priors nudge → **3 parallel damage_calc calls in ONE
  response, results returned in ONE user message, thinking blocks echoed
  verbatim across iterations (API accepts), 18.9s** — the loop machinery
  proven end-to-end. Every reply cites the calc numbers, never recomputes.
- **Why-trace in the UI**: `AgenticAdvice.trace` (tool, input, result,
  error flag) publishes through LiveTrackerModel → Battle Log advice card
  grows a "why — N engine checks" DisclosureGroup; the overlay shows the
  compact "🔧 2 round-trips · 3 engine checks · 9.1s" line with the trace
  on hover. Auto/Ask flows unchanged.
- Gotchas for the record: MainActor default isolation captured the NEW
  top-level structs in AdvisorClient.swift exactly as m9 predicted for
  extensions — `nonisolated` must be written on every shared-file TYPE too;
  tool_choice "none" (the forced-answer escape) is compatible with adaptive
  thinking (only "any"/"tool" aren't); JSONSerialization dictionaries need
  explicit deterministic sorting anywhere bytes feed the cache.

## m11-B (2026-07-07, battle 6–7 parser + robustness gaps — fixture-first)

- **Five templates from the exact recorded reads** (fixtures 38–42, suite
  37→44): `moveBlocked` ("Incineroar cannot use Fake Out!" — the blocked
  attempt still REVEALS the move, new 🚫 event kind, no lastMove window);
  blocked stat drop ("…Attack was not lowered!" → labeled note, never a
  statChange); **adverb-after-verb stat changes** ("rose sharply!" — battle
  7's Kingambit Defiant read went unrecognized because the m4 template only
  knew "sharply rose"; the modifier now matches on EITHER side of the
  verb); targeted crit ("A critical hit on the opposing Oranguru!");
  poison-tick wording ("was hurt by its poisoning!" — Champions' phrasing;
  the m4 map only knew mainline's "was hurt by poison").
- **Suffix-truncation entity resolution** (fixture 43): fade-INS eat
  leading characters the way fade-outs eat tails — battle 7's "cineroar
  used Fake Out!" minted a phantom beside Incineroar. resolve() step 1a now
  mirrors the m8 prefix rule: a ≥6-char raw that is a unique SUFFIX of an
  existing same-side display name is that mon. Plate resolution
  (resolveForPlate) deliberately unchanged — plates stay quarantined.
- **megaEvolved dedup root cause** (fixture 44): battle 7's ×2 (1.5s apart)
  slipped BOTH text guards by construction — a near-full-length re-read
  isn't a fragment (fragment test requires strictly shorter), and a
  wobbled tail ("Mega Laemol") changes the semantic key. Text matching
  can't win that game; STATE legality can: a mon that already Mega Evolved
  stays Mega Evolved (guard `!e.mega`), same doctrine as fainted-stays-
  fainted. Battle-5 real-footage replay after all changes: 148 events, 2
  known HP-misread discards, 0 preview corrections — no drift.
- **Battle-start diagnostics** (battle 7 sat on "Waiting for a battle…"
  through preview, undiagnosable live): the Battle Log's waiting state now
  shows `tracker sees: <classifier state> (conf …)` + team-preview frame/
  row counts, and the overlay's waiting line shows the same compactly —
  the pilot can SEE a missed preview at preview time. No recording of
  battle 7 exists; these diagnostics are how the next occurrence gets
  root-caused.
- **Reset semantics mid-battle defined**: Reset builds a fresh reconciler
  (as before), and when the OLD reconciler had a preview seed, the current
  aggregate consensus re-seeds the fresh one immediately (guarded by
  hasPreviewSeed so a stale previous-battle aggregate can never leak into
  a preview-less battle). Mid-battle narration bootstrap then rebinds
  actives; no phantom carry-over, no nickname-only degradation.
- Replay tail note: 3 unrecognized banners remain in battle 5, all
  heavy-wobble fade reads whose clean duplicates parsed ("fellito 2",
  "thteenturn", "clive on") — wobble-tolerance candidates, not template
  gaps.

## m11-C (2026-07-07, runtime meta refresh — pilot-requested roadmap item)

- **Regulations rotate; the snapshot no longer has to be a rebuild.**
  `MetaStore.swift` (app-only) + Settings ⌘, → **Meta tab**: regulation
  label, source (bundled vs refreshed), species count, snapshot age with a
  staleness badge (fresh ≤14d / aging / STALE >30d), a "Refresh from
  Pikalytics" button with live progress, and "Revert to bundled".
- **The current regulation is DISCOVERED, not hardcoded**: the pokedex
  page's format selector marks the active ranked dataset `selected`
  (`<option value="battledataregmbs3-1760" selected>Pokemon Champions
  Regulation Set M-B S3 Ranked Battle Data</option>`, verified live
  2026-07-07). Champions RANKED data = `battledata…` slugs; Showdown sim
  formats are ignored. Label → short form via "Regulation Set (…) Ranked".
- **The crawl is a faithful Swift port of `Engine/fetch-meta.js`**: same
  teammate-graph BFS (index links + sprite/data-candidates references +
  seed list), same politeness (2 workers, 200ms spacing each, 400-page
  fuse, identifying UA), same SEO-text profile regexes, same engine slugs.
  Crawl state lives in an actor; only fetch+parse run concurrently.
  LIVE smoke (bounded cap 8): discovery → Reg M-B S3, 8/8 profiles,
  incineroar Fake Out 99.9% — byte-parity with the bundled snapshot's
  value. Refuses to overwrite the cache when a crawl yields <40 profiles
  (layout-change guard).
- **Cache + hot swap**: payload stays the raw {slug: profile} shape (no
  envelope — setMeta and the MCP server read it as-is) at App Support/
  `meta-current.json`, sidecar `meta-info.json` carries {regulation,
  formatSlug, fetchedAt, speciesCount}. `ScoutEngineBox` applies the cache
  over the bundled snapshot at load, and a `metaChanged` notification
  hot-swaps it into the LIVE JSC engine via the new
  `ScoutEngine.setMeta(Data)` (the m3 seam, finally exercised at runtime)
  then recomputes scout/matchup. ONLY on explicit pilot action — never a
  timer (ToS posture unchanged since m3).
- **Harness decoupling held by construction**: every CLI and
  mcp-server(-test) still pins the committed `Engine/data/meta-regmbs3.json`;
  the App Support cache is invisible to them, so a refresh can never move
  verify-all's parity pins. The committed snapshot remains the
  reproducibility anchor; `fetch-meta.js` stays the repo-maintenance tool.

## m12-A (2026-07-08, the agentic PREVIEW scout — "what do I bring?")

- **The highest-leverage decision of the battle now gets the tool loop.**
  The advisor answers a second question mode: TEAM PREVIEW. Design points:
  ONE frozen system prompt describes both modes (mode rides the user
  message, never a swapped system prompt — swapping would fork the prompt
  cache); the battle-static capsule prefix is SHARED between preview and
  turn asks; the volatile block is `AdvisorContext.buildPreview` — the
  deterministic heuristic's bring-4/leads as "the instant answer to beat"
  plus the top-6 threat lines and best answers from `scoutReportData`.
  `AdvisorClient.forPreview()`: ≤8 round-trips, 28s soft deadline, 35s
  per-request timeout, 2500 max_tokens; effort stays low (same request
  shape as turn asks keeps round-trips snappy and the cache shared).
- **`buildCapsules` now dedups + SORTS by canonical species name** — the
  static block must be byte-identical whether built from the preview
  consensus (row order) or the reconciler (actives+bench order, which
  CHANGES as the opponent switches). A preview ask now warms the exact
  prefix every turn ask reads; measured cross-battle: battle 5's preview
  ask read 12,435 cached tokens on its first round-trip.
- **Per-request timeout must cover the budget**: the preview loop's first
  round-trip can think 20s+ before its tool calls arrive; the m8-era
  hardcoded 20s `URLRequest.timeoutInterval` killed battle 4's first
  attempt. `hardTimeout` (25s turn / 35s preview) now feeds the request.
- **Offline proof (AdvisorHarness `--preview`, real API, battles 3/4/5
  replayed to t=120; consensus 80/58/28 frames, all six rows correct —
  battle 3 reads Staraptor AND Garchomp right at preview time):**
  - Battle 3: ENDORSED the heuristic with reasons — Intimidate blunts
    Garchomp/Staraptor, Charizard-Y sun + Weather Ball deletes Whimsicott;
    warned Tailwind → Scarf Typhlosion speed flip. 2 round-trips (a
    live_matchup lead stress-test + damage_calc), 27.7s.
  - Battle 4: **OVERRULED the heuristic — and matched the pilot's actual
    WINNING bring exactly** (Charizard/Incineroar/Venusaur/Garchomp; the
    heuristic had Sneasler, which the scout rejected as "OHKO'd by both
    Armarouge and Farigiraf Psychic"). Read the double-Trick-Room team
    structure from capsules, named Sleep Powder as the TR answer, and
    applied the battle-7 lesson unprompted: "don't Fake Out, Farigiraf's
    Armor Tail blocks it." 38.9s.
  - Battle 5: endorsed the heuristic bring (kill pressure into the
    Perish-trap core — the pilot's actual softer bring lost this game);
    verified Froslass Blizzard is only 36–42% into Charizard under sun
    with 3 parallel damage_calcs; named Archaludon the biggest threat
    (Electro Shot OHKO + rain flip). 31.0s. Honest note: the answer never
    says "Perish Song" even though both capsules carry it — damage-first
    framing; a future prompt nudge could name win-condition traps.
- **App surfaces**: Scout Report window gains the "Scout this matchup"
  card (Ask + "Auto once per preview" toggle, default OFF, same why-trace
  DisclosureGroup as the Battle Log); the overlay's waiting state shows a
  🔭 bring line — heuristic instantly, agentic once computed. Auto mode
  triggers from `publishScout` (exactly when the consensus stabilizes),
  once per preview (reset when a fresh preview's frame count restarts),
  gated to preview time (no battle events yet, or last battle ended).
  The deterministic safe_four banner stays always-on (two-speed doctrine).
- Not in verify-all (network + cost) — run `--preview` manually; suite
  stays 6 stages, all green after the change (fixtures 44/44).

## m12-B (2026-07-08, reverse damage inference — the engine learns from watching)

- **A landed move's observed damage constrains the attacker's set.**
  `ScopeEngine.inferAttack` tests {0/128/252 EVs} × {neutral/+nature} ×
  {none/Life Orb/Choice/top-2 meta items} against the observed hit and
  reports which combinations are CONSISTENT (honest ranges, never point
  estimates). Key design choice: our exact plates put the observation in
  **HP POINTS, not percent** — points depend only on the defender's
  Def/SpD (configured team), sidestepping the unknown HP EVs entirely.
  Non-damage items dedup into "no item" by identical roll range; a MEGA
  attacker's item slot is its stone, so the grid collapses to item-free
  (the engine caught this before I did — my manual probe had wrongly
  tested Life Orb on Scrafty-Mega).
- **Attacker boosts ride the observation**: battle 4's Fake Out landed at
  −1 (our Intimidate) — 20 HP at −1 infers "no item (≥0+ Atk) (at Atk-1)";
  ignoring the stage would have inferred a too-low EV tier.
- **Reconciler attribution** (engine-free; the app poll loop / harness own
  the JSC call): a you-side exact-HP fall within 10s of an opponent's
  lastMove opens a pending observation; animation reads extend it (the
  same 2.5s coalescing as the 🔻 events); it FINALIZES when the window
  closes quiet. Honesty gates: crit note within ±5s ⇒ discard (both
  directions — the note can precede the animation); both actives falling
  to one move ⇒ spread ⇒ discard (the engine also rejects spread moves by
  move target — belt and braces); lethal ⇒ discard (a KO only bounds the
  roll from below). Verdicts land via `recordInferenceVerdict`: the 🔎
  event grows the summary and the ATTACKER carries up to 3 hints into
  `activeSnapshots()` → the advisor turn context.
- **Real-footage finding (battle 4)**: VFR/fade jitter can start the plate
  animation BEFORE the banner confirms — in one replay the Drain Punch
  hit's 100-HP body landed unattributed (correctly dropped) and a 4-HP
  tail minted a partial observation. Fix: `conclusive:false` when NO
  hypothesis matches, and consumers stay SILENT on inconclusive results —
  a tainted fragment becomes a raw 🔎 line, never a hint. ("no tested set
  reproduces X" is a taint signal, not intel.) At AdvisorHarness sampling
  phase the same hit attributed fully (104 HP) and inferred cleanly —
  both behaviors are pinned.
- **The flagship validation**: Armarouge Psychic → our Charizard-Mega-Y
  for 105 HP inferred "item boost implied — Choice Specs (≥0+ SpA), or
  Life Orb (≥252+ SpA)" — and battle 4 later OBSERVED Armarouge's Life
  Orb through the normal reveal channel. The inference deduced a hidden
  item from damage alone and was independently confirmed.
- **Proofs**: ScoutEngineHarness +6 pins (the Psychic flagship with every
  no-item hypothesis inconsistent; spread/status skips; mega item
  collapse; boost notation; fragment ⇒ inconclusive). Fixtures 45–46
  (suite 44→46): settle-window observation from battle-4's exact Fake Out
  shape; both-actives-fall spread suppression. Battle-4 replay end to
  end: 3 conclusive inferences in the advisor context at t=280.
- v1 scope notes: OUR side as defender only; hints render for ACTIVE
  attackers (bench hints persist unrendered); matchup set-assumption
  sharpening deferred; defender accuracy improves automatically when the
  pilot pastes real EV spreads.

## m12-C (2026-07-09, the Opponent Dossier — "google the enemy, at a glance")

- **Pure surfacing, no new data source.** The pilot kept leaving the app to
  look up what opponents' abilities/moves/items DO; everything except the
  effect text already existed in `OpponentCapsule`. Step 0 verified the
  brief's hunch: @smogon/calc's gen data has NO `shortDesc` (moves carry
  only mechanics; `g.abilities`/`g.items` are `{id, name}` stubs) — so the
  text is baked, not fetched.
- **`Engine/build-dex-info.js`** (mirrors build-vocab.js) bakes
  `Engine/data/dex-info.json` from @pkmn/dex (the pinned devDependency),
  SCOPED TO THE CLOSED VOCAB: 864 moves + 316 abilities + 581 items, 0
  vocab names missing from the dex, ~295 KB. Keys are engine.ts slugs
  (`toLowerCase().replace(/[^a-z0-9]+/g,'-')` — lookups must match
  exactly); `accuracy === true` (never-miss, e.g. Aura Sphere) is emitted
  as **null**; `shortDesc || desc` fallback. Rebake after any vocab rebuild.
- **`ScopeEngine.dexInfo({moves?, abilities?, items?})`** returns entries
  in INPUT ORDER (callers zip requests to results — no slug math in
  Swift); unknown names degrade to `{name, known:false}`. Bundle grew
  1.0 → 1.3 MB (the baked JSON). `dex-info.json` is also copied to
  `Resources/Engine/` beside the other data files. Swift bridge:
  `ScoutEngine.dexInfo(moves:abilities:items:) -> DexInfo` (typed Codable
  decode, same JSON-round-trip path as the other surfaces). Five stage-3
  pins: Fake Out (flinch/first-turn text, Physical, priority > 0), Aura
  Sphere accuracy nil vs Fake Out 100, unknown → known:false, Armor Tail
  text mentions "priority", Life Orb "1.3".
- **`OpponentDossierCard`** (OpponentDossierView.swift) is a pure view
  over `OpponentDossier` — plain Sendable data composed ON THE ENGINE
  ACTOR by `OpponentDossier.build(ordered:executor:)`: capsules via
  `buildCapsules` (which sorts by name for prompt-cache stability) get
  REORDERED back to display order, then ONE dexInfo call fetches every
  card's effect text. Card: header (species/types/winrate/ACTIVE badge) →
  ⚠️ priority-blocker line → colored defensive-typing line → ability+% with
  effect → top-4 moves+% with "Type · Category · BP · acc% · ±N priority"
  and effect → items+% (top item's effect) → speed bracket + "usage
  priors, not observed" caption. Off-ladder species degrade to typing +
  speed + an orange note (mock previews pin both states, light AND dark —
  RenderPreview-verified).
- **Window: "Scouting Dex" (⇧⌘K)** + header buttons in the Live Tracker
  and the Scout Report banner. Feed = `LiveTrackerModel.dossiers`,
  recomputed only when the KNOWN-OPPONENT picture changes (signature =
  ordered species + active flags): mid-battle the reconciler is the source
  (actives first, then bench — corroboration corrections flow in, the
  capsuleSpecies doctrine), preview/idle falls back to the consensus read
  where pins beat voted top-1s. Recompute hooks: publishOpponentRead,
  confirmSpecies, recomputeMatchupIfNeeded, resetBattleLog, and
  handleTeamChange (force — a meta refresh moves usage %s without moving
  the species set).
- Gotcha for the record: SwiftUI's `Text + Text` concatenation is
  DEPRECATED on macOS 26 — styled-segment lines must use Text
  interpolation (`Text("\(styledText)…")`), which preserves per-segment
  styling. The warning only appears in the app build (the CLI harnesses
  don't compile SwiftUI), same visibility class as the isolation lesson.
- **Postscript (same day, pilot-requested): the YOUR-TEAM type card.**
  `TeamTypeEntry.build` renders every configured member's typing +
  defensive profile at the top of the window (switch decisions), actives
  flagged mid-battle (keys = lowercased species AND display names from
  you-side snapshots, the membersByIdentity convention). Two honest
  extras, both pure type math: a **Mega line** only when a held stone
  CHANGES the typing (engine.ts calcSpecies stone convention — Zard-X
  class; Zard-Y stays silent), and an **"if Tera X" line** from the
  configured Tera type's mono-type profile (Stellar stays chip-only — it
  keeps the original defensive typing; unknown types yield all-neutral
  profiles and are also skipped). The dossier signature now includes
  you-side active keys so the card re-sorts on YOUR switches too; the
  model computes it at init so the window is useful before any capture
  starts. GUARD: `ScoutEngineBox.teamTypes` passes the real MonSpec team
  into `loadedExecutor` — passing a stub would CLOBBER the executor's
  configuredTeam (the advisor's scout_report default). Empty state now
  only when no team AND no opponents.

## m12-D (2026-07-09, offline pair: Champions-has-no-Tera cleanup + Protect pressure)

- **PILOT GROUND TRUTH: Champions has NO Terastallization** ("Tera isn't in
  the game (yet?)", 2026-07-09). Every render/advisor surface is now
  tera-silent: the m12-C+ team card lost its "Tera X" chip + "if Tera X"
  line (fields removed from `TeamTypeEntry`), `AdvisorContext.buildStatic`
  no longer emits "Tera <type>" on YOUR TEAM lines (it invited the model
  to recommend an impossible action — Showdown pastes imported from other
  formats DO carry `Tera Type:` lines), and the system prompt dropped its
  "boosted/tera" example. KEPT: `TeamStore` parsing + paste round-trip
  serialization (stripping would corrupt re-exports) and the inert
  `teraType` carriage through MonSpec/PokemonState (schema compat; the
  calc always ignored it). If tera ever ships, re-adding is a render flip.
- **Protect pressure (the non-blocked half of old proposal C).** The
  reconciler now tracks, per entity, the turn of the last SUCCESSFUL
  protect and the consecutive streak. Signal = the `.protected` event
  ("X protected itself!" — the SUCCESS banner), deliberately NOT the
  `moveUsed` attempt: in-game, only a success arms the odds drop, and a
  failed attempt resets the counter (our flag self-corrects through turn
  arithmetic without parsing failure banners). Wide Guard is excluded
  twice over (its per-hit line names the BENEFICIARY; it has no
  consecutive-failure counter). Switch-out clears both fields (mirrors
  the game; streak math would also self-correct via turn gaps).
- **Surfaces:** `ActiveSnapshot.protectedLastTurn` + `protectStreak`
  (flag = lastProtectTurn ≥ turn−1, streak zeroed when the flag is off);
  `AdvisorContext.buildTurn` renders "🛡 Protected last turn — a repeat
  succeeds only ~33%" (streak n → ~(1/3)^n: 33/11/3%); the system prompt
  grew the matching rule sentence; the overlay's perish-chip row (now
  `clockChips`) adds "🛡Name" (+" ×n" on streaks).
- **Proofs:** fixtures 47–49 (suite 46→49): flag-on-next-turn +
  partner-not-flagged, back-to-back streak 2, decay after one quiet turn.
  New harness assertion block `expectSnapshots` checks FINAL
  `activeSnapshots()` state by species (only provided fields compared) —
  the first snapshot-level fixture hook. Real-footage dry-run (battle 5
  `--at 190 --dry-run`, THE perish-trap decision the pilot originally
  lost): Gengar-Mega (Perish 2) and opp Incineroar both render the 🛡
  flag, our actives don't — the context now says "their blocks are
  probably down" at exactly the moment it decides the game.
- Fixture-authoring notes for the record: synthetic turn advancement
  needs 2-frame primary confirms (command → narration → command), and
  repeat banners must sit >3.5s apart or `recentParseKeys` semantic dedup
  eats the second read (the fixtures space turns ~5s).

## m12-E (2026-07-09, advisor VGC doctrine + Choice lock + the STREAMING readout)

- **The "VGC skill" (pilot's ask: no-brainer smarts).** The frozen system
  prompt grew two doctrine sections. `CHAMPIONS RULESET`: no Tera / no
  Z-Moves / no Dynamax (the model's mainline-VGC priors WILL suggest tera
  otherwise), megas are REAL incl. cross-era ones — trust capsules over
  mainline memory. `DOUBLES DOCTRINE`: spread damage numbers already
  include the doubles 0.75× (VERIFIED in-engine before writing it: Heat
  Wave 95 BP renders 41–48.9% where Flamethrower 90 BP is 52–62.1% —
  exactly ×0.75·(95/90)); redirection vs spread vs Wide Guard; Intimidate
  re-triggers on re-entry + Defiant/Competitive/Guard Dog punishes;
  layered speed control (Tailwind ~4 turns incl. cast, TR ~5); double-up
  vs Protect-risk judgment; endgame counting. Prompt-byte change = one
  one-time cache re-write (tools+system tier), measured fine after.
- **Choice lock — the third deterministic per-active flag** (Fake Out
  legality m8, Protect pressure m12-D, now this): entity tracks
  `lastMoveUsed` (set on moveUsed AND moveBlocked — lock applies once
  SELECTED; cleared on switch-out). `ActiveSnapshot.choiceLockedMove` is
  set iff the OBSERVED item hasPrefix "Choice" — priors never lock. Turn
  context renders "🔒 Choice-locked into X until it switches"; system
  prompt carries the exploit/respect rule; overlay clockChips shows
  "🔒Name→Move". Fixture 50 (suite 50/50): the m4 right-anchor possessive
  chip stack ("Gholdengo's / Choice Specs" at x≈0.84) reveals the item
  (chip path emits `itemActivated` — ability-vs-item is a vocab question),
  Make It Rain commits the move, snapshot asserts the lock.
- **The advisor STREAMS now (SSE) — the pilot's line-by-line readout.**
  `AdvisorClient.post` → `postStreaming`: `stream: true`, parse
  `data:` lines, accumulate per block index (`thinking_delta` grows
  thinking, `signature_delta` grows the signature — echoed verbatim next
  round-trip — `input_json_delta` buffers until `content_block_stop`
  parses the tool input), then return the exact `{content, stop_reason,
  usage}` shape the non-streaming path had — THE LOOP LOGIC IS UNCHANGED.
  Usage merges message_start (input/cache) + message_delta (output).
  `timeoutInterval` becomes an idle-between-chunks guard under SSE.
- **KEY API DISCOVERY (claude-api skill): Opus 4.8 defaults thinking
  `display` to "omitted"** — the advisor's thinking blocks have been
  EMPTY text since m11 (echo still worked; the signature is what
  matters). Now `thinking: {type: adaptive, display: "summarized"}` makes
  the reasoning VISIBLE: it feeds the live readout, and
  `AgenticAdvice.thoughts` (one summary per round-trip) renders as 🧠
  lines in both why-traces.
- **Live readout protocol**: `AdvisorProgress{line, replacesPrevious}` —
  appends for round-trip markers/tool calls/"N checks ran", in-place
  replacement for growing thinking/answer tails (throttled 0.25s).
  LiveTrackerModel folds into `adviceProgress`/`previewAdviceProgress`
  (non-empty only while in flight); Battle Log advice card + Scout panel
  render the last 6 lines monospaced. Harness prints `\r`-rewriting lines.
- **Gotcha: `FileHandle.synchronizeFile()` on stdout CRASHES when stdout
  is a pipe** (fsync unsupported → ObjC exception, silent death) — the
  first streaming run died mid-round-trip on exactly this. Use
  `fflush(stdout)`.
- **Real-API proofs (harness, streaming end-to-end):** battle 5 t=190 —
  1 round-trip, zero tools, 13.1s, thinking streamed live, advice is the
  perish-race play WITH the switch-reset warning (the play the pilot's
  actual loss lacked). Battle 5 t=130 `--nudge` verify-with-tools — 2
  PARALLEL tool calls streamed in one response (input_json_delta parsed
  clean), round-trip 2 ACCEPTED the reconstructed thinking block
  (signature echo proven), cache read 15,086 tokens across separate
  processes, 13.1s; and thought[1] reads "Fake Out registers as 0% —
  Gengar is immune as a Ghost-type" — the visible reasoning the pilot
  asked to see.

## m12-F (2026-07-10, commit_play — structured plays + a wider battle tail)

- **The pilot's post-first-live-run ask: "quickly say what to do for each
  Pokémon on the field → then show reasoning after."** Implemented as the
  pattern he himself named — a TOOL. `commit_play` is a seventh tool the
  ADVISOR sees but the MCP server never lists (defined in
  AdvisorToolCatalog, appended after the six in `anthropicTools`;
  deliberately NOT in tool-schemas.json — it's an output protocol, not an
  engine check). Schema: `actions[] {pokemon, action move|switch, move?,
  target? (or "both"/"self"/"field"), switch_to?, mega?, note?}`.
- **Loop interception (AdvisorClient):** commit_play never reaches
  `runTools` — the client records it locally (LATEST call wins),
  `AdvisorPlay(json:)` decodes leniently (malformed ⇒ prose-only
  fallback, never an error). Fast path: commit + reasoning text in the
  SAME response (as instructed) ⇒ the loop returns immediately — zero
  extra round-trips. Fallback: commit-only response gets a local
  tool_result ("now give your reasoning") and one forced trip fetches
  the prose. Mixed responses (commit alongside pending engine calls)
  answer EVERY tool_use id in original order — engine results real,
  commit result "recorded — re-commit if the results change your mind".
- **UI: decision first, reasoning after.** `AgenticAdvice.play` →
  `LiveTrackerModel.advicePlay` → bold "▶︎ Charizard: Weather Ball →
  Gengar" chips ABOVE the prose in the Battle Log card AND the overlay
  (`advicePlayLines`, defaulted so mock previews compile unchanged);
  notes render as sub-captions; the streaming readout shows "🎯 deciding
  the play…" as the commit's input_json_delta forms. adviceMeta's
  "engine checks" count now excludes commit_play (it isn't one).
- **m12 idea-2 audit answer (what the advisor is fed):** current STATE is
  fully cumulative (HP/boosts/reveals/perish/Protect/Choice-lock all
  battle-long); the PLAY-BY-PLAY tail was only the last 8 events —
  widened to 20, then to the FULL battle log same day (pilot's call):
  "BATTLE SO FAR (every tracked event, oldest first)". Bounded in
  practice by event coalescing (~150 lines / 10-min battle, ≈2k tokens),
  paid uncached only on an ask's first round-trip; dry-run at battle-5
  t=190 renders all 48 events from the preview read onward.
- **Real-API proof (battle 5 t=190, streaming):** committed play
  "Charizard: Weather Ball → Gengar / Incineroar: Flare Blitz →
  Incinero(ar)" with prose that USES the m12-D/E work — "both foes
  protected last turn so a repeat only lands ~33% … I split targets so
  I'm not wasting a hit if one Protects." 2 round-trips 16.0s (the
  commit-without-prose fallback path — also proven); RT2 read the 8,200-
  token prefix RT1 wrote (within-loop caching post-tools-change ✓).
  Target names follow the tracker's display names ("Incinero" when
  that's what OCR holds) — honest to what's on screen.

## m12-G (2026-07-10, battle 8 forensics + offense-bias notes)

- **Battle 8 (FORFEIT turn 6, "tracking got lost after Garchomp came
  out") — root-caused from the pilot's pasted log, three real bugs, all
  fixture-first from the EXACT reads (suite 50→53):**
  - `IDontPlayVGCsent out Garchomp of the Distant Past!` — TWO stacked
    quirks: the fade glued the trainer to the verb (template now
    tolerates a missing space) and Champions gave the mon an EPITHET
    (resolve() strips " of the …" and retries; 5 words also tripped the
    nickname guard). The un-parsed send-out meant Garchomp NEVER joined
    the actives — matchup + advisor saw 2-v-1 for the rest of the game
    (final state showed it "benched" while it Rock Slid every turn).
    Fixture 51 asserts the snapshot: Garchomp ACTIVE.
  - `le opposing Raichu used Focus Blast!` — "The" mangled to "le";
    subjects() only tolerated "he opposing", so a YOU-side phantom
    ("le opposing Raichu") was minted into the final state. "opposing"
    after any ≤4-char residue is now the load-bearing side marker.
    Fixture 52 forbids the you-side event.
  - `Venusaur is paralyzed, so it may be unable to move!` — Champions'
    para APPLICATION wording (Zap Cannon 100%); m4 only knew mainline's
    "was paralyzed" + the tick line, so Venusaur's par (speed halving,
    full-para odds) was invisible to the matchup/advisor. Fixture 53.
  - Battle-5 real-footage replay after all three: 148 events / 3
    unrecognized / 2 anomalies — byte-for-byte the m11-B baseline, no
    drift.
- **Champions sightings for the ledger:** Mega Raichu Y + Raichunite Y
  (battle 8, tracked end-to-end live; ALREADY in @pkmn/dex, so calcs
  used real stats) and the epithet pattern — both recorded in
  champions-overrides `_sightings`.
- **Offense-bias notes (pilot's ask: "note if likely physical or
  special attacker").** `OpponentCapsule.offenseBias` =
  physical/special/mixed from the DEX CATEGORIES of the damaging top
  meta moves (what the ladder actually runs — more honest than base
  stats); nil when nothing damaging is known. Rendered as the first
  fact on each advisor capsule line ("special attacker · speed 130–178
  …") and as a tinted chip in the dossier header (orange/blue/purple).
  Battle-5 dry-run: Gengar/Politoed/Froslass special, Incineroar
  physical — correct across the board.

## m13-A (2026-07-10, BACKLOG P2 — a committed play never outlives its turn)

- **Pilot report (2026-07-10): "Committed plays don't update … has to wait
  for the current turn to complete."** Root cause was exactly the backlog
  hypothesis, two coupled holes:
  1. `advicePlay`/`adviceText` were set only by `publishAdvice` and cleared
     only by `resetBattleLog` — turn N's play stayed on screen, presenting
     as current, all through turn N+1's decision window.
  2. Auto-advise fired only from `publishMatchup`, which runs only on a
     matchup-SIGNATURE change. The turn counter isn't part of the signature,
     and it increments at the command checkpoint AFTER resolution already
     moved the HP — so the common sequence was: resolution changes signature
     (still turn N, `lastAdvisedTurn == N`, no ask) → checkpoint increments
     to N+1 with **no further signature change** → no ask until something
     else moved. With auto OFF nothing ever curtained the stale play.
- **Fix (LiveTrackerModel):** the model now tracks `battleTurn` (published);
  the moment `recomputeMatchupIfNeeded` sees the turn move, it **curtains**
  the old play (clears play/text/trace, status becomes "Turn N — ask for
  the play.") and every auto-advise trigger funnels through one
  `autoAdviseIfDue()` gate — called on turn change even when the signature
  is unchanged, from `publishMatchup` (which now also fires on engine
  hiccups, advice doesn't need the matchup to exist), and from
  `publishAdvice` when an answer lands for an already-passed turn (that
  re-ask was previously impossible: the in-flight ask blocked the
  turn-change trigger, then nothing retried).
- **Belt-and-braces staleness:** if a late answer does get displayed
  (`adviceTurn != battleTurn`), the Battle Log caption goes orange
  ("⚠︎ for turn N — it's now turn M") and the overlay's turn chip shows
  "T N ⚠︎ stale"; with auto off the status line restores the ask prompt so
  the staleness is actionable. A turn REGRESSION (new battle without Reset)
  also resets `lastAdvisedTurn` — previously a same-numbered turn in the
  next battle could silently skip its auto-ask.
- Verified: verify-all 6/6 green (fixtures 53/53; app build clean). Model
  logic only — no parser/engine surface touched.

## m13-B (2026-07-10, BACKLOG P1 — the species escape hatch)

- **Pilot report (2026-07-10): "Sometimes the Team Preview guesses don't
  actually include the right answer!"** The tap-to-confirm chips only
  surface the voted top-3; when the true species ranks 4+ or is a known
  no-cross-source-crop class (Scizor/Sylveon/Raichu/Milotic), the pilot
  was stuck with a wrong auto-pick and no override.
- **Fix — backlog direction (a), the guaranteed unblock:** each opponent
  card in the Scout Report grows a 🔍 button → popover with a species
  search field over the matcher's FULL closed vocabulary
  (`PreviewPipeline.bundledSpeciesNames()` — just the names from
  species-index.json, no sheet/feature load). Prefix matches outrank
  substring matches; Return pins the top match; the current pick is
  check-marked. Picks flow through the existing `confirmSpecies` path, so
  a manual rescue ALSO banks the row's crop as a native reference — every
  miss the pilot fixes teaches the matcher (the same flywheel as
  confirm-taps; this is how the four known no-cross-source classes get
  their first banked crops without waiting for a lucky top-3).
- Deliberately NOT taken: widening chips top-3 → top-5 (backlog option b).
  The consensus truncation feeds the eval harness and the reconciler's
  preview seeds — widening it as a rider on a UI fix would shift
  eval/corroboration semantics without fixture evidence. The picker
  strictly subsumes the benefit for the pilot.
- The picker guards the resource-missing edge ("Species index
  unavailable"), skips the confirmSpecies toggle when re-picking the
  already-pinned name (typed re-picks must not unpin), and carries
  VoiceOver labels throughout. Rendered via Xcode Preview to confirm
  layout.
- Verified: verify-all 6/6 green (fixtures 53/53; species eval untouched
  by design).

## m13-C (2026-07-10, battle archive + review — dev queue item 1)

- **Battles persist now.** `BattleArchiveStore` (new shared file,
  Foundation-only, everything `nonisolated`): one pretty-printed JSON per
  battle under Application Support/BattleArchive/. The record is Codable
  DTOs only — plays/traces flatten to display strings at capture time so
  the schema stays stable if live types evolve. Contents: outcome, turns,
  both rosters, final state lines, the FULL log markdown, the preview
  scout's call, and every answered ask as a decision point (turn, text,
  play lines, thoughts, engine checks, loop meta). These records are the
  raw material for the eval-set milestone (next in the dev queue).
- **Boundary detection** (LiveTrackerModel.publishBattle): a battle
  archives (a) when its outcome lands — the clean path, final log/state;
  (b) when the published log SHRINKS — a fresh reconciler replaced an
  unfinished battle (next preview, >60s gap) — archived as "abandoned"
  using the still-published old values BEFORE overwrite; (c) on
  mid-battle Reset (resetBattleLog archives first — battle 8's forfeit
  was exactly this shape). Outcome-less battles need ≥8 events so
  classifier misfires / accidental Resets don't clutter the archive;
  `battleArchived` guards double-saves. The preview scout's answer is
  snapshotted at battle start (its published fields survive until the
  NEXT preview clears them) and updated if the loop lands mid-battle.
- **Review window** (⇧⌘A, Live Tracker "Archive" button):
  NavigationSplitView — sidebar rows (🏆/💀/🚪, date, opponents, turn
  count), detail replays the battle: outcome header with duration,
  teams, preview-scout card, per-turn decision cards (play chips → prose
  → why-trace disclosure, same grammar as the live Battle Log), full log
  in monospace, Copy Log, Delete (confirmation dialog). Live-refreshes
  via `BattleArchiveStore.changed` notifications.
- Verified: store round-trip (save → list → field-equality → delete) run
  IN the app container via Xcode RunCodeSnippet
  (`~/Library/Containers/com.ethan-marshall.Scope-Lens/...`); detail
  view eyeballed via Preview render; verify-all 6/6 green.
- **⚠️ verify-all.sh was lying — exit-code masking, third recurrence.**
  While building this milestone, a missing `import Combine` produced
  `** BUILD FAILED **` and the gate still printed "✅ ALL VERIFICATIONS
  GREEN" with exit 0. TWO masking bugs, now fixed + sim-proven:
  1. `xcodebuild … && echo "BUILD SUCCEEDED"` — under `set -e`, a failure
     anywhere in an AND-list except its LAST command does not abort the
     script (POSIX errexit exemption). Split into two statements.
  2. No `pipefail`: every stage ends in `| tail -N`, and tail's exit 0
     replaced the harness's failure code — stages 1/2/3/4/6 could ALL
     fail silently. `set -o pipefail` added (safe here: tail never
     SIGPIPEs its producer the way `head` can).
  Lesson (joins swiftc-pipe and xcodebuild-grep in the ledger): an
  "exit 0 iff green" claim needs failure-mode PROOF, not just a green
  run — simulate a failing stage and watch the gate trip.

## m13-D (2026-07-11, the nickname bind — pilot's "Toucan sam" battle)

- **Pilot report (2026-07-11, with the full pasted log): a battle "lost
  tracking on only one opponent pokemon due to a nickname."** The preview
  even read the row correctly (row2 Flying/Normal → Toucannon), Sableye
  bound on send-out — but "Toucan sam" minted a nickname entity
  (`isNickname`, species nil) and the ONLY automatic resolver is the
  signature-move map (`resolveNicknameIfSignature`, the m4 "Matcha Latte"
  path). No signature move used ⇒ species unknown ALL BATTLE: no capsule,
  no matchup entry, no dossier, its preview row stranded as a bench ghost.
- **Why not solve it automatically?** Elimination is structurally dead in
  bring-4-of-6: the two unbrought preview rows stay unclaimed forever, so
  the nickname's candidate set never shrinks to one. Opponent HP plates
  are percent-only (no max-HP fingerprint). Move-based learnset filtering
  needs data we don't bundle (full learnsets; the fallback file is
  curated top-4s, absence ≠ evidence). The sound automatic lever — a
  vocab-scoped move→species reverse index intersected with unclaimed
  rows — is recorded in BACKLOG; it wants the eval set first.
- **Fix — the pilot's eyes (P1's mid-battle sibling):** the Battle Log
  grows a bind card whenever a living opponent nickname is unresolved:
  "❓ Toucan sam is…" + one-tap chips for each UNCLAIMED preview species
  (the opponent's team IS the six rows) + the reused P1
  `SpeciesSearchPicker` behind a 🔍 for misread-row cases. The tap queues
  through the model (`pendingNicknameBinds`, consumed by the poll loop —
  the reconciler lives on the capture task, same pattern as Reset) into
  new `BattleReconciler.bindNickname`: sets species, emits
  `identityResolved` ("pilot confirmed"), claims the preview row via the
  same `bindToPreviewRow` as automatic resolution — capsules, matchup,
  and dossiers light up on the SAME tick. Card state
  (`nicknameBindState()`: unresolved actives-first + unclaimed top-1s)
  rides `publishBattle`.
- **Fixture 54** (suite 54/54): the pilot's exact preview seeds + the
  verified battle-3 pair-send-out banner shape reworded to
  "Charles sent out Sableye and Toucan sam!", then a SCRIPTED bind —
  `Frame.bindNickname` is a new optional fixture hook that calls the same
  API as the card, mid-stream. Asserts the identityResolved event, exact
  kind counts, and the post-bind snapshot carrying species Toucannon.
- Not done deliberately: no crop banking on a bind (battle models aren't
  menu sprites — nothing comparable to bank) and no overlay-HUD bind
  affordance (the overlay stays glanceable; the Battle Log is the
  interaction surface).

## m13-E/F (2026-07-12, battle 9 forensics — dead advisor + three parser holes)

Battle 9 (WON t8 vs BossSoffy, pilot's pasted log; the m13-B species
picker "was great" — first live validation of the escape hatch).

**m13-E — every advisor ask died ("unexpected shape").** Reproduced
offline on battle 5 t=190 (real API): adaptive thinking at low effort now
runs past the old 2000-token max_tokens BEFORE any answer block streams —
stop max_tokens, content = one thinking block, empty text. The model's
thinking length drifted since the 2026-07-09/10 proofs; effort targets
don't pin it (third recurrence of m8's thinking-ate-max_tokens). Fixes:
budgets 2000→4000 (turn) / 2500→6000 (preview); ONE budget-doubling
retry on truncation (the cut turn is DISCARDED — an unfinished thinking
block has no signature and can't be echoed; the warm cache makes the
retry cheap); `badResponse` now names the actual shape ("stop
max_tokens, empty answer; blocks: thinking(1704ch)") — the bare
"unexpected shape" is why the live report couldn't be diagnosed from the
pilot's words. Proof: the dead board now completes (2 RT, committed
play, 16,460 cached tokens read, thinking measured 2310 output tokens).
Latency varies with board complexity now (39s on that perish endgame) —
thinking-length tuning belongs to the dev queue's effort A/B.

**m13-F — parser pack, fixture-first from the exact reads (54→57):**
- **The `?? raw` fallback was a closed-vocab breach**: moveUsed/
  moveBlocked kept the RAW text when the move didn't snap. Battle 9:
  "Roda" became a move on a phantom entity, "Prote" polluted Kingambit's
  revealedMoves next to the real Protect. Now `resolveMove` REQUIRES
  resolution — fuzzy snap, then unique ≥5-char PREFIX of exactly one
  move ("Prote"→Protect, the m8/m11-B subject rules applied to the move
  slot); garble rejects the parse (the clean re-read parses moments
  later). Fixture 56 pins the rejection, 57 the prefix upgrade.
- **The side-marker word itself can be clipped**: "pposing ArLodecad
  used Roda" started AT "pposing" — m12-G's residue rule assumed an
  intact "opposing", so the subject minted a YOU-side phantom. Any
  ≥5-char SUFFIX of "opposing" (pposing/posing/osing) now marks the
  opponent. Fixture 57.
- **White Herb was invisible**: "returned its stats to normal using its
  White Herb!" unparsed ⇒ Sneasler kept a stale Atk-1 through three
  turns of matchup math, and an m12-B inference reported "(at Atk-1)"
  for a restored attacker. New `statsRestored` template → negative
  stages clear (positives stay), item revealed if no chip fired, new
  `boostsRestored` event kind. Fixture 55 (+ SnapshotExpectation grew a
  `boosts` assertion).
- **Quick Guard joins Wide Guard**: same template, detail = the guard
  name; the reconciler's exclusions (no revealed move, no
  Protect-pressure — per-hit lines name BENEFICIARIES) now key on
  detail != nil. The `.protected` displayLine renders "protected by
  Quick Guard" when a guard is named.
- Battle-5 real-footage replay: 148 events / 3 unrecognized / 2
  anomalies — byte-identical to the m11-B baseline, no drift from the
  vocab enforcement.

**Reviewed and deliberately NOT actioned (battle 9's remaining noise):**
the sleep wordings ("is fast aslee", "fell asleer") and the compound
Intimidate possessive both self-healed via cleaner re-reads on adjacent
frames (status/statChange events all landed); "Switch in" and "VECT"
are UI-prompt/lobby garbage position-gating already keeps out of state;
the Garchomp 1%↔100% churn was the falls-apply-immediately design
working as intended (corroborated-rise + checkpoint re-sync healed it —
tightening it would mask real Focus-Sash-style 99% hits). The
out-of-order 🔎 timestamps in the log are the inference events carrying
their OBSERVATION time (truthful) while appending at finalize time —
cosmetic, kept.

## m14-A (2026-07-12, the Opponent Notepad — pilot's "battle status" ask)

- **Pilot request:** "players bring notepads … surface previously used
  moves, items revealed, speed orders, statuses, weather, like Showdown
  does." Everything was already TRACKED (reconciler entities carry
  moves/item/ability/status/boosts/HP/perish/protect/choice/hints/mega);
  the full per-mon picture just never assembled until the post-battle
  final-state render. Weather/TR ride the existing headline; speed order
  rides the matchup panel; the missing surface was the per-mon board.
- **`BattleReconciler.rosterSnapshots()`** → `RosterEntry` per mon, both
  sides: actives (field order), revealed bench, then the opponent's
  UNCLAIMED preview rows as italic "not seen yet" ghosts (same union
  logic as the state bench). Entities grew `moveUseCounts` — moveUsed
  increments it (blocked attempts don't: PP wasn't spent) — so the board
  shows the notepad detail players actually track: "Protect ×3".
- **The board** renders in the Battle Log between the state summary and
  the bind card, opponent side only (you don't take notes on your own
  team; your actives stay in the summary line). Per row: ▶︎/·/💀 +
  name (nickname keeps "(species)", unknowns "(?)"), mega chip, colored
  HP%, status capsule, per-stat boost capsules, ⏳ perish, 🛡 streak;
  second line: "@ item · ability · moves ×counts · 🔒 lock", with 🔎
  inference hints on hover. Fainted rows dim but KEEP their facts. The
  plain "[opp]" summary line hides while the board is up. All observed,
  never assumed — meta priors stay in the Scouting Dex (⇧⌘K).
- Board state rides `publishBattle` (roster changes always accompany
  event/HP signature changes). Mock preview committed ("battle 9 shape":
  mega-slp Aerodactyl, herb Sneasler with hints, Protect-streak
  Kingambit, fainted Garchomp, ghost Alcremie); Xcode MCP was
  disconnected this session so the preview wasn't render-verified —
  compiles warning-free, built from the same chip/caption primitives as
  the shipped panels. Pilot eyeballs it live.
- Deliberately deferred: bench SPEED brackets on the board (capsules
  have them, but they're priors — the dossier shows them per species;
  mixing priors into an "observed only" board muddies its promise) and
  any overlay-HUD variant (stays glanceable).
- verify-all 6/6 green (fixtures 57/57 — moveUseCounts rides the
  existing moveUsed path; no parser surface changed).

## m14-B (2026-07-13, the doomed-slot axiom — pilot's Solar Beam report)

- **Pilot report (battles of 2026-07-12/13): the advisor "cashed in"
  Charizard with Solar Beam while itself predicting Charizard would be
  outsped and KO'd** — which happened, so the Solar Beam never fired.
  The failure is a missing CONSEQUENCE application, not missing facts:
  the model had the speed order and the KO line, but no rule that a mon
  acting after a lethal attacker gets NO move (so "cash in damage before
  dying" is only real when you act FIRST — otherwise it forfeits the
  slot).
- **Fix, two-speed style:** (1) `buildTurn` now emits a deterministic
  ⚠️ DOOMED SLOT flag per your-active that acts after an opponent whose
  incoming line is koNow/guaranteedKo (m.speeds is move order, TR
  pre-applied; priority named as the loophole; worst killer cited).
  (2) DOUBLES DOCTRINE gains the TURN-ORDER CONSEQUENCE axiom + the
  weather-dependency line (Solar Beam without active sun charges;
  Weather Ball follows the field — the report's vehicle).
- **Verified on real footage:** battle-4 t=240 correctly UNFLAGGED
  (Intimidated Rock Slide only 56–67% into full-HP Charizard — no KO,
  no flag); battle-5 t=260/285 (the perish-trap loss) flags Incineroar
  (acts after Politoed's guaranteed-KO Weather Ball) while correctly
  NOT flagging Charizard (outspeeds Politoed). Real-API ask at t=260:
  the advisor now commits "Incineroar: switch → Rotom-Wash — reset
  perish, dodge Politoed Weather Ball" AND still cashes in Charizard
  legitimately (acts first, guaranteed KO on Gengar before end-of-turn
  perish) — the axiom's exact distinction, applied unprompted.
- System-prompt change = one-time cache invalidation on the next ask
  (8,450 tokens rewritten, then cached again). Whether one flag+axiom
  fully closes the failure class is an EVAL question — this is eval
  case #1 for the session-10 advisor-expertise arc (see
  SESSION-10-BRIEF.md).

## m15-A (2026-07-13, verdict + exact-context capture — the eval supply)

- **Session-10 arc opener** (SESSION-10-BRIEF Task A.1): every future
  pilot battle now produces BOTH eval inputs — ground-truth labels and
  byte-exact replays. `AdviceEntry` gains `verdict`/`verdictNote` (the
  pilot's 👍/👎 + one-liner, written after the fact) and
  `staticContext`/`turnContext`/`model` (the EXACT prompt blocks the ask
  sent — records previously stored only rendered text, so archived
  decisions could not be replayed faithfully; that was the schema gap
  between m13-C and the eval).
- **Schema evolution discipline:** all new fields are
  optional-with-default `var`s — memberwise call sites compile
  unchanged, synthesized Codable uses decodeIfPresent/encodeIfPresent.
  Proven against the pilot's real archive: 8/8 pre-m15 records decode
  (4 with advice), verdict round-trips, nil fields stay ABSENT from the
  JSON (records stay compact).
- **`BattleArchiveStore.setVerdict`** re-reads the record from DISK
  (never trusts a view's copy), mutates the one entry (matched by
  askedAt — ISO8601 truncates sub-second, but both sides of the compare
  are decoded values, so equality holds), re-saves, posts `changed`.
- **Review window** (⇧⌘A): 👍/👎 toggles per decision card (tap again
  to clear), optional note field appears once labeled (auto-focused on
  👎 — bad calls become eval cases), "N awaiting your 👍/👎" nudge in
  the section header. Note persists on submit AND focus loss.
- **`BattleRecord.appBuild`** (version + binary mtime): the
  stale-instance discipline, in the record — the archive shows all of
  today's battles were played BEFORE the m14-B merge (the 19:34Z
  forfeit = the pilot's Solar Beam report battle; both its asks
  committed Solar Beam plays with ZERO engine checks — eval case #1).
- verify-all 6/6 (fixtures 57/57; stage 5 covers the app-only UI).

## m15-B (2026-07-13, PlayLint + the eval set — constraints over heuristics)

- **The session's architecture thesis, delivered:** doctrine text is
  prompted HOPE; `PlayLint` is checked CONSTRAINT. A pure shared function
  (`lint(play, LintContext) → findings`) checks every commit_play against
  objective game rules — doomed-slot attacks, illegal Fake Out, priority
  into an observed blocker, Choice-lock contradictions, moves outside the
  configured set, switches to fainted/absent mons, fainted targets, mega
  without stone, duplicate actors/megas — violations (fail the eval) vs
  advisories (reported only: likely-blocker, sun-charge, redundant
  double-up, speed-risk). 29 unit cases = verify-all stage 5 (now 7
  stages; the new stage was SIM-PROVEN to trip the gate before trusting
  it — the m13-C lesson).
- **The TRUE Solar Beam anatomy (from the pilot's 19:54 archive, ask 2):**
  the advisor said "Charizard is going to die … so I cash it in" and "I
  outspeed with Charizard" — then TYRANITAR's Rock Slide fired first and
  Solar Beam never happened. Root cause is a DATA gap, not doctrine: the
  engine's opponent speeds are 0-EV floor estimates (Zard-Y 120 >
  Excadrill 108 > Tyranitar 91 said "safe"), while the bracket ceilings
  said otherwise (Excadrill 154; Scarf Tyranitar 186 — and the 5.8% Scarf
  share hid OUTSIDE the capsule's rendered top-2 items). m14-B's flag
  trusts the floor, so it stayed silent.
- **doomedSlots, one source of truth + two new tiers:** the m14-B
  computation moved out of buildTurn into `AdvisorContext.doomedSlots`
  (context flags and lint can never drift; old tiers render
  byte-identically). NEW: `.priorityKiller` (unconditional-priority
  guaranteed KO denies the slot regardless of speed; Fake Out/First
  Impression/Sucker Punch excluded as conditional) and `.speedRisk`
  (estimated order says you act first, but the killer's Scarf-adjusted
  bracket ceiling beats your exact speed — "outspeed as a gamble", made
  deterministic; skipped under Trick Room where the comparison inverts).
  Capsule `scarfPossible` now scans the FULL usage items with a ≥5%
  floor (Tyranitar 5.8% flags; Gengar's 2.1% trace on an 84% mega-stone
  mon stays quiet).
- **EvalHarness + eval-advisor.sh** (NOT in verify-all — real API cost):
  case files replay decision points from fixture VIDEO (full pipeline),
  INLINE reconstructed contexts, or m15-A+ ARCHIVE records; assertions =
  commit / lintClean / forbid / require (API tier) + doomedFlag /
  noDoomedFlag (deterministic tier — evaluated even in `--dry-run`, so
  the flag computation is pinned for free). `--sweep` lints every
  archived play offline; `--runs N` for variance; `--model` for A/B.
  Seed cases: battle5-t260 (m14-B pin), battle4-t240 (false-flag
  control), battle5-t190 (m13-E budget pin), solar-beam-cash-in
  (reconstructed via the real builders + engine — the generated board
  reproduces the fatal turn: speedRisk fires citing Tyranitar ceiling
  186 vs 120).
- **First live run: 3/4 — the eval caught a REAL regression on day
  one.** battle5-t260, the exact board whose m14-B real-API proof
  committed "Incineroar: switch → Rotom-Wash" THIS MORNING, today
  committed "Incineroar: Flare Blitz → Politoed" — a doomed-slot-attack
  violation (the attack never executes). Model drift within a day
  (m13-E's lesson quantified), plausibly interacting with the new SPEED
  RISK line on Charizard (the model bought "insurance" on Politoed with
  a slot that deterministically has no action). The m14-B axiom does NOT
  close the class alone; the m15-C repair loop is the structural fix —
  this failing case is its acceptance test. solar-beam-cash-in PASSES:
  with the speedRisk flag the advisor drops the Solar Beam line
  (commits Heat Wave→both + Incineroar switch — strictly better under
  the same gamble).
- **Schema (m15-A companion):** AdviceEntry gains `play` (structured,
  AdvisorPlay is Codable now), `lintContext`, `lintFindings` — every
  future archived decision is re-lintable offline forever. requestAdvice
  now builds BOTH context blocks + lint context inside the detached task
  (after capsules exist — buildTurn needs them for ceilings).
- Deferred to BACKLOG: mega-forme speed ceilings (Gengar-Mega base 130
  vs 110 — ceilings underestimate stone-holders' mega speed; needs a
  stone→forme map, natural m15-D companion).

## m15-C (2026-07-13, the verify-and-repair loop — violations can't ship silently)

- **The repair mechanics:** `advise()` gains a `lintPlay` hook. A fresh
  commit_play runs through PlayLint INSIDE the loop; violations come back
  in the commit's own tool_result — "REJECTED — this play violates
  deterministic game rules: … call commit_play again" — for ONE repair
  round-trip on the warm cache (advisories never bounce). The fast-path
  return skips on a rejection; forceAnswer is suppressed for that round
  (the repair needs commit_play available); the loop backstop gains +1
  headroom; a still-violating re-commit ships WITH findings attached.
  AgenticAdvice carries `lintFindings` + `lintRepaired`.
- **Acceptance test (the m15-B red case), real API:** battle5-t260 ran
  3 round-trips with "🧯 repair bounced" — first commit was the doomed
  Flare Blitz, the rejection named the rule, and the model re-committed
  EXACTLY the m14-B-proof play (Incineroar: switch → Rotom-Wash ·
  Charizard: Weather Ball → Gengar). lintClean green. The drift
  regression the eval caught this morning is structurally closed.
- **solar-beam-cash-in is now RED on `forbid` (and that's the m15-D
  gate):** run-to-run variance — one run commits Heat Wave→both (pass),
  the next takes the Solar Beam→Tyranitar gamble despite the SPEED RISK
  advisory (repair had bounced an unrelated violation first). An
  advisory-tier flag doesn't reliably steer, and shouldn't be promoted:
  the real defect is the POINT ESTIMATE — modal Focus-Sash Excadrill
  runs max speed (~154 Jolly), which actually outspeeds Zard-Y's 120,
  so the 0-EV floor is the wrong prior, not merely an uncertain one.
  m15-D's modal-spread data turns the estimate real → the doom tier
  upgrades → violation → repair enforces. Eval discipline working as
  designed: the case stays red until the data lands.
- **Surfacing:** live advice card renders unresolved violations in
  orange under the play chips; adviceMeta gains "🧯 repaired after rule
  check"; archive decision cards list their stored lintFindings; the
  play_lint trace entry records rejections in the why-disclosure.
- Latency note for m15-E: battle5-t190 ran 64.9s this pass vs 30.1s two
  hours earlier (same board, same request shape) — thinking-length
  variance dominates; the A/B needs multiple runs per cell.
- verify-all 7/7 (playlint 29/29 — cases unchanged; the loop change is
  exercised by the eval, not the unit tier).

## m15-D (2026-07-13, meta grounding — modal spreads, natures, teammates)

- **The GROUND leg of the session's architecture: meta expertise as DATA,
  not prose.** Pikalytics pages carry three sections the crawl never
  parsed: EV spreads, natures, teammates. KEY DISCOVERY: **Champions uses
  a 0–32 point training scale (~66-point budget), not mainline 0–252 EVs**
  — spreads render as sextets like `2/0/0/32/0/32` (HP/Atk/Def/SpA/SpD/
  Spe); 1 point = +1 stat at L50 ≈ 8 mainline EVs (engine converts pts×8
  clamped 252, a documented ±1). Natures are a SEPARATE distribution
  (pairing is client-side only); teammates are RANKED, no %.
- **fetch-meta.js + MetaFetcher (Swift parity)** parse all three
  (top-4 spreads, top-4 natures, top-6 teammates); snapshot regenerated
  via the recorded invocation — 119/119 species carry the new fields;
  Incineroar Fake Out 99.9% stable across five weeks. The committed
  scout sample regenerated via ITS recorded invocation (the CLI writes
  the fixture in place): usage sections unchanged (distribution
  stable), threat NUMBERS moved honestly — modal attackers carry
  +nature (old: neutral 252), and the EV-less default paste's
  defenders now get modal bulk instead of paper. Both parity pins
  (bring-4 line, Farigiraf TR 95.7%) still pass.
- **Engine: modal fill + the pessimism asymmetry.** `resolveSet` fills
  unconfigured specs with the MODAL ladder set (top spread × top nature;
  `spreadSource: configured|modal|generic`), flowing into damage, bulk,
  and the SPEEDS array. One deliberate asymmetry: **a modal ATTACKER's
  used offense floors at 252 — incoming damage stays pessimistic** (a
  missed doomed flag loses games; modal bulk/speed stay calibrated).
  `speedBrackets` gains `modal`/`modalPct`; capsules render
  "ladder-modal ~140 (39.5% spread)" + "usual partners: …" lines.
- **The eval caught MY OWN change (twice), as designed.** (1) First
  full run: battle5-t260's `guaranteed` pin failed — root-caused to a
  **pre-existing artifact**: the committed default paste has ZERO EV
  lines, so the old engine modeled the harness's OWN defenders as
  0-SpD paper (m14-B's guaranteed tier was computed against a phantom).
  Modal bulk is the honest defender prior; the case pin is now
  tier-agnostic and documents the artifact (the pilot's app-side
  imported spreads always override modal). (2) The bisect that proved
  it: same board, old bundle 107.9–128.7% vs new 83.2–99.0% — exactly
  the 0-vs-160-SpD ratio.
- **The Solar Beam case regenerated via the now-committed recorded
  invocation** (`Diagnostics/eval/GenerateSolarBeamCase.swift`, assertions
  derived from the computed board): with modal speeds the board tells the
  truth — Excadrill 140 and Mega-Tyranitar 123 both act BEFORE
  Charizard-Y 120, the doomed tier is **guaranteed**, and the killer
  named is Tyranitar's Rock Slide — the exact move that ended the real
  game. Solar Beam commits are now VIOLATIONS, not vibes.
- **EVAL: 4/4 GREEN (the m15-C red case closed).** solar-beam-cash-in
  ran 3 RT with a repair bounce and committed a full double-switch out
  of the trap; battle5-t260 re-committed the m14-B-proof play. Pins
  updated with evidence: mcp damage_calc 24.8→19.3% max (modal bulky
  Careful Incineroar defender), TR speed 120→152 (modal Charizard),
  bridge plumb baseline 120→152.
- Deferred (BACKLOG): mega-forme speed ceilings for capsules (the
  matchup speeds already resolve megas via the item — Tyranitarite →
  Mega-Ttar 123 — but capsule brackets/ceilings stay base-forme).

## m15-E (2026-07-13, effort/model A/B on the eval set — the latency budget)

- **The brief's Task C, run ON the m15-B eval (4 cases, single-run cells —
  variance-honest; two passes on the winning arm).** The claude-api skill
  was consulted first and killed the brief's proposed dimension:
  `thinking: {enabled, budget_tokens}` is REMOVED on Opus 4.8 (400) —
  the valid levers are `effort`, `thinking: disabled`, and the model
  tier. AdvisorClient grew `thinkingMode`/`effort` knobs;
  eval-advisor.sh grew `--thinking`/`--effort`.
- **The matrix (opus-4-8 unless noted):**

  | arm | cases | latency (incl. repair) | verdict |
  |---|---|---|---|
  | adaptive + low (old default) | 3/4 | 19.8–136s | breaches the 40s timer routinely; solar-beam ended PROSE-ONLY after a repair bounce (no re-commit) at 136s |
  | adaptive + medium | 2/4 | 33.5s+ then DEATH | thinking outgrew even the doubled 8k budget (7.2k-char thinking, stop max_tokens) — the m13-E failure mode at scale; not viable |
  | **disabled + low** | **4/4, twice** | **5.5–23.6s** | the only arm that never breached the timer; leaned on the m15 flags+lint for deliberation; repair bounces resolved correctly |
  | sonnet-5, adaptive + low | 3/4 | 3.5–43.8s | very fast on easy boards; hallucinated a move Incineroar doesn't carry — PlayLint caught it (unknown-move), play shipped with the violation surfaced |

- **DEFAULT CHANGED: turn asks now run `thinking: disabled`** (preview
  keeps adaptive — 90s budget, no commit timer). The architecture is
  WHY this works: doomed/speed-risk flags + damage math do the
  deterministic deliberation up front, and PlayLint+repair guarantees
  rule compliance behind — the model's job on a 40s clock is line
  selection, not private derivation. Model tier stays opus-4-8 (the
  sonnet-5 numbers are in the log for the pilot's call; a tier change
  is his decision).
- **The LATENCY BUDGET (the written deliverable):** move timer ~40s;
  pilot input margin ~5s ⇒ ask budget 35s. Turn asks: p50 target ≤10s,
  soft deadline 18s (forces the final answer), one repair bounce adds
  ~5–12s, worst acceptable ~30s. Observed at the new default: 5.5–23.6s
  across 8 case-runs. Preview asks: 28s soft / 35s hard against the
  ~90s preview window (unchanged). Any future request-shape change must
  re-run `Diagnostics/eval-advisor.sh` and stay inside these numbers.
- **Two repair-loop observations for the backlog:** (1) after a
  rejection near the soft deadline the model can answer in prose
  without re-committing (the 136s adaptive run) — acceptable (surfaced,
  prose fallback) but a `require-recommit` nudge is a candidate; (2)
  sonnet-5's unknown-move commit proves the lint's value as a model-
  portability net.

## m6 findings (2026-07-03, first LIVE Battle Log run — Example Battle 4)

- The pilot ran a full ranked battle with the live Battle Log open (WON,
  turn 8; log saved as `Example Battle 4 Log.md` next to the .mov). The
  system live-tracked a **Champions-new Mega Scrafty** (Scraftinite → the
  overrides file), Trick Room on/off, Aurora Veil, Snow Warning, Flash Fire,
  Life Orb, a Drain Punch drain-heal, and corrected preview row 5
  Delphox→Armarouge in real time.
- **User-reported miss (Scrafty shown as a Dark/Ground "Krokorok") was NOT a
  type-template failure**: the offline replay of the same video reads the
  preview perfectly (Fighting types included). Root cause: the live model
  seeded the reconciler ONCE at the ≥5-frame bar — an early, laser-degraded
  vote — and never updated. Fix: live re-seeding while the preview is up
  (`seedPreview` now refines in place, updating the existing
  teamPreviewRead event). Defense-in-depth: preview binding falls back to a
  SINGLE-shared-type match (with a correction note) so a genuinely misread
  type slot can no longer strand a narrated mon beside its own preview ghost.
- Drain-heal windows: attack + drain animations lag the move narration by
  ~7s live — the drainer's heal window is keyed off lastMove within 10s
  (was 6, which battle 4's Drain Punch missed; the corroborated-rise
  fallback caught it anyway).
- New wobble templates from real reads: "Attack fel", "reacting fo",
  "has,Mega Evolved", trainer-less "sent out X and Y!", side-truncated
  "Wide Guard now protects the opposing sid", "Aurora Yeilmade … strongor…"
  (fuzzy screen fallback), garbled "wwisted dimensions-retuined" (fuzzy TR
  end), flinch / "A critical hit!" / Flash-Fire flare as labeled notes.
  Weather lines switched from whole-line equality to contains-style cores —
  fade-ins drop leading words ("sunlight turned harsh").
- Trainer names: mid-fade truncation clipped the live opponent to "In" —
  longest-read-wins now refines it (battle 4's name genuinely OCRs short).
- Banked 32 new crops (Ninetales-Alola, Farigiraf, Scrafty, Armarouge — all
  narration-confirmed; Mawile/Annihilape stayed unrevealed → not banked).
  107 features / 24 species; cross-species floor 0.388 — still clear of the
  0.30 decisive threshold. A lasered Farigiraf crop sits 1.33 from its clean
  stills siblings — labels verified by eyeball; min-over-features absorbs it.

## m4 findings (2026-07-02, BattleState + reconciler vs all 3 recorded battles)

**Narration grammar (all templates derived from real banners — LOOK paid off):**
- Side attribution is explicit and reliable: opponent mons are always "The
  opposing X"; ours are bare names ("Rotom used Thunderbolt!"). Compound
  subjects join with "and", possessive rides the LAST subject ("Charizard and
  Incineroar's Attack fell!").
- Display names are BASE formes ("Rotom" for Rotom-Wash, "Typhlosion" for
  -Hisui) — species resolution maps display → forme via our team seed /
  preview types. Opponent nicknames are real ("Matcha Latte" = Sinistcha) and
  resolvable via **signature moves** (vocab.json `signatureMoves`: 160 moves
  with exactly one base-species learner — Matcha Gotcha ⇒ Sinistcha).
- Champions-only content appears in narration: **Mega Staraptor + Staraptite**
  (battle 3) — recorded in `Engine/data/champions-overrides.json`, merged into
  vocab.json by `Engine/build-vocab.js`. "Omni Ring" is the mega trigger.
- Effectiveness wording: "super" = 2×, "**extremely**" = 4×, "not very" = 0.5×,
  "mostly ineffective" = 0.25×; the message names the TARGET(s).
- Stat wording: rose/fell = ±1, "sharply/harshly" = ±2, "drastically/severely"
  = ±3; stats compound ("Defense and Sp. Def rose!").
- Weather lines are fixed strings ("The sunlight turned harsh!" / "The harsh
  sunlight faded." / "It started to rain!"); screens name the side ("made the
  opposing side stronger"); "You lost to <trainer>!" precedes the LOST splash;
  forfeits say "The battle has ended due to a forfeit."
- **Mid-fade fragments are the #1 parsing hazard**: the outgoing banner
  re-reads as a truncated window and losing "The opposing " FLIPS side
  attribution ("Jarchomp used Rock Tomb"). Defenses, all three needed:
  ① fragment suppression (a strictly-shorter fuzzy-substring of the recent
  banner is the fade, not a message), ② semantic dedup on the PARSE (template
  + side + subjects + detail), not raw text — wobbled re-reads collapse,
  "rose" vs "fell" never do, ③ lookup-only subject resolution for
  non-identity events (effectiveness/ticks) so garbled targets can't mint
  entities. CAUTION: banner memory must let a NEW shorter banner replace an
  old longer one immediately ("longest wins" only within one banner's fades) —
  getting this wrong resurrected the side-flip phantom (committed fixture 23).

**Chips & plates:**
- The activation chip renders at TWO anchors: ours at left (x≈0.16, y≈0.50);
  the opponent's at right with VARIABLE y (0.37–0.54 observed). The m4 parser
  detects both by stacked-possessive geometry ("Staraptor's"/"Intimidate",
  x-aligned, dy 0.02–0.09) independently of the classifier's overlay flag
  (which only knows the left anchor — kept as-is, 23/23 fixtures untouched).
- Ability-vs-item is decided by vocabulary snap alone, as designed. Healing
  items (Sitrus/Leftovers/berries) open an 8s heal-legality window.
- HP plates ride on MANY frames (narration included): ours "name over exact
  fraction" bottom-left (y≈0.87/0.94), theirs "name over percent" top-right
  (y≈0.07/0.14) — attribution by NAME token, never slot position. Names on
  plates are species names for non-nicknamed opponents (weak-signal doctrine
  upgraded: plate names may CREATE opp entities only when they snap to the
  species vocabulary; nickname-garble reads are dropped).
- Slash-misread parsing ("1447154" → 144/154) extended with cur ≤ max and
  max-consistency checks — the legality filter rejected real "754 vs 154"
  and "164 vs 154" OCR garbage in battle 3.

**Reconciler legality (spec §4.4 step 6, all verified on the replays):**
- HP falls apply immediately; consecutive same-direction changes within 2.5s
  coalesce (plates animate at 2 fps — "202 → 28" instead of stair-steps).
- HP rises need a cause (drain/item/narrated heal within 8s) OR two agreeing
  reads (any state — catches un-narrated Leftovers at command checkpoints and
  self-heals a false-fall misread).
- Fainted stays fainted: later nonzero reads for that mon are discarded.
- Boosts reset on switch-out and faint; status survives switching.
- Weather: events set kind + 5-turn estimate, ticked at each new command; the
  user-opened **summary panel is a free exact re-sync** ("Harsh Sunlight 4/5"
  under "Active Statuses & Effects" — n/m = remaining/total).
- Turn boundary = confirmed `command` after a resolution phase (narration or
  communicating) — menu bouncing does not increment.
- **Battle corroboration closes the preview loop**: a species-vocab-snapped
  narration subject is authoritative identity; binding it to a type-compatible
  preview row logs a correction when the row's top vote disagrees. Battle 3
  auto-corrected **row 0 "Farfetch'd" → Staraptor** and **row 3 "Zygarde" →
  Garchomp** (the user's exact suspicion) — these corrections are the ground
  truth the m5 native sprite harvest trains on.
- Battle 2 (recording starts MID-battle, no preview) bootstraps from narration
  alone: full log, correct outcome, opponent sets/items recovered. The
  `battleStart` event carries "joined mid-battle — turn numbers are relative".

**Learnset fallback (m4 task C):** `Engine/build-learnset-fallback.js`
(@pkmn/dex, pinned devDependency) → `Engine/data/learnset-fallback.json`
(1281 species × up to 4 moves: best STAB per type + coverage + Protect,
recharge/charge/self-KO/low-accuracy excluded). `resolveSet` uses it only when
usage data is absent; `setSource: observed|usage|learnset|none` labels every
set end-to-end (engine → ScoutReportData → "learnset guess" badge in the scout
window). Off-ladder species now contribute threats: the committed sample's
Dialga surfaced a previously invisible **Draco Meteor 132–156% KO on
Garchomp**, which legitimately changed the sample's bring-4 (regenerated with
the exact historical taps per the workflow lesson — parity green).


  bridge (JavaScriptCore) matches the Phase-1 CLI on identical inputs
  (bring-4/leads/move-%s/top-threat vs the committed sample), and smoke-runs a
  live consensus. NOTE for future sample regeneration: the committed
  `Team_Preview_Initial_scout.md` was generated with FOUR confirm-taps
  (`1=Farigiraf 2=Charizard 3=Pelipper 4=Archaludon`) — the "(confirmed by
  tap)" markers in its Pipeline-reads section record the exact invocation.
  (Row 4 was originally tapped "Dialga" in session 1; the m5 native-sprite
  calibration proved the crop is pixel-identical to battle-1's
  narration-confirmed Archaludon — a ground-truth correction, not a whim.) A parity
  check against a sample regenerated with different taps produces a false
  regression (cost 30 minutes of engine archaeology; the engine was innocent).
  ```sh
  swiftc -O Diagnostics/ScoutEngineHarness.swift "Scope Lens/ScoutEngine.swift" \
    "Scope Lens/BattleState.swift" "Scope Lens/TeamStore.swift" \
    -o /tmp/scoutengineharness && /tmp/scoutengineharness
  ```
