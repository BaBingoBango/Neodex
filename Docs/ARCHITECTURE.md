# Neodex architecture

Neodex is split into three pieces that share one set of Swift types, plus Scope Lens, a fourth piece
the Mac app links (see its section below):

```
┌─────────────────────────┐     generates      ┌──────────────────────────────┐
│ Tools/NeodexData        │ ─────────────────▶ │ App/Resources                │
│ Swift CLI (macOS)       │  Data/*.json        │  Data/   pokemon.json, …     │
│ Showdown + PokeAPI →    │  Images/**          │  Images/ *-art.heic, *-thumb │
│ Neodex models           │                     │          *-sprite.png, …     │
└─────────────────────────┘                     └──────────────┬───────────────┘
            │ depends on                                       │ bundled into
            ▼                                                  ▼
┌─────────────────────────┐     depends on     ┌──────────────────────────────┐
│ Packages/NeodexKit      │ ◀───────────────── │ App (Neodex.xcodeproj)       │
│ Models · database ·     │                    │ SwiftUI, iOS 26+, Swift 6    │
│ type chart · stat math ·│                    │ SwiftData for user data      │
│ Showdown codec · Smogon │                    │ Spotlight, Smogon client     │
│ parsers · Swift Testing │                    └──────────────────────────────┘
└─────────────────────────┘
```

## NeodexKit (`Packages/NeodexKit`)

A platform-independent Swift package (iOS 26 / macOS 26) holding everything that is not UI:

- **Models** — `Pokemon`, `Move`, `Ability`, `Item`, `Nature`, `PokemonType`, `Learnset`, `StatBlock`.
  All are `Codable`, `Sendable`, `Hashable` value types. Identifiers are Pokémon Showdown IDs
  (`charizardmegax`, `flamethrower`), which makes team import/export and usage-statistics lookups
  trivial and keeps the data pipeline and the app in lock-step.
- **`PokedexDatabase`** — an immutable, `Sendable` in-memory database with indexes for every lookup
  the app needs (by ID, by tolerant name, forms of a species, evolution families, who learns a move,
  who has an ability, full-text-ish search). Loaded once at launch with `@concurrent` so decoding
  never touches the main actor.
- **Game logic** — the Gen 6+ type chart with defensive/offensive profiles, the Gen 3+ stat formulas,
  the 25 natures and their flavors, and spoken type-matchup summaries for Siri.
- **`DamageCalculator`** — a Gen 9 calculator that mirrors Pokémon Showdown's: the same modifier
  order, 4096-based modifier chaining and half-down `pokeRound` rounding, so results match the
  Showdown calculator roll for roll. It covers stat stages, STAB and Terastallization, critical hits,
  weather, terrain, screens, burns, the common abilities and items, variable-power moves and
  immunities, and reports exact KO chances. `BattleCombatant` and `BattleField` describe the inputs.
- **`FormatLegality`** — Smogon's Gen 9 singles ladder (Anything Goes down to Little Cup) from
  Showdown's tier data, plus Species, Evasion, OHKO and Baton Pass clauses, learnability and
  availability checks, returning one explained issue per problem.
- **`ShowdownTeamCodec`** — a native parser/exporter for Showdown's team text format (replacing the
  JavaScriptCore bridge the original app used).
- **Smogon parsers** — rankings tables, directory listings and the "chaos" JSON, turned into
  percentages the UI can show directly.

The package is covered by Swift Testing suites (`swift test`), including a test that validates the
generated dataset when it is present on disk.

## NeodexData (`Tools/NeodexData`)

A Swift package with a tested library (`NeodexDataCore`) and a thin command-line executable
(`neodex-data`) that rebuilds the bundled dataset from two open sources:

| Source | What we take | Why |
| --- | --- | --- |
| [Pokémon Showdown](https://github.com/smogon/pokemon-showdown) (MIT) | Species, forms, stats, abilities, moves, items, learnsets, tiers, competitive descriptions, natures, type chart | Competitive-accurate, complete through the current generation (including Legends: Z-A Megas), same naming as the Showdown teambuilder |
| [PokeAPI](https://github.com/PokeAPI/pokeapi) (BSD-3) | Pokédex entries, genus, catch rate, friendship, growth rate, egg cycles, EV yields, in-game move/ability/item descriptions, TM numbers, encounter locations, official artwork | The canonical in-game flavor that Showdown does not carry |

Showdown ships its data as JavaScript/TypeScript modules, so the tool evaluates them with
JavaScriptCore and reads the resulting JSON through a loose `JSONValue` tree (the data is
heterogeneous: a field may be a string in one entry and an array in another). PokeAPI's CSV dump is
parsed with a small RFC 4180 reader.

Steps, in order:

1. Download everything into `Tools/NeodexData/.cache` (re-runs are offline and take seconds).
2. Build models, joining Showdown entries to PokeAPI rows by National Dex number and a normalised
   form name (with an alias table for the ~60 forms the two projects spell differently).
3. Verify: dangling ability/move/item/evolution references fail the build; the hard-coded type chart
   and natures in NeodexKit are checked against Showdown's data.
4. Images: official artwork → 400 px HEIC (`-art`), 120 px HEIC thumbnail (`-thumb`), Showdown's
   96 px battle sprite (`-sprite`), and item icons sliced from Showdown's sprite sheet (`-item`).
   Forms without their own artwork borrow their species' images (recorded in `imageID`).
5. Write `Data/*.json`, a `pokemon-index.json` slice for widgets and complications, and a
   `manifest.json` with counts, timestamp and source attribution.

```bash
cd Tools/NeodexData
swift run neodex-data                    # full refresh (≈1 minute on a fresh cache)
swift run neodex-data --skip-images      # data only, a few seconds
swift run neodex-data --preview-fixture  # rebuild only the Xcode Previews fixture
swift run neodex-data --help
swift test                               # pipeline tests: CSV, JS evaluation, name mapping, join rules, fixture
```

Every full run also refreshes the preview fixture (below), so the two never drift apart.

### The Pokémon recogniser

`swift run neodex-data --train-classifier` builds the camera scanner's classifier. One class per form
that has its own artwork (totems fold into their species); training images per class come from the
bundled artwork and sprite, PokeAPI's official artwork and HOME renders (normal and shiny) and Dream
World art, frames of Showdown's animated sprites (front, back, shiny; normalised onto one canvas),
trading-card illustrations from [pokemontcg.io](https://pokemontcg.io) matched to forms by dex number
and name, and composites of the cut-outs on generated backgrounds. Every image becomes Apple's
768-value scene-print feature vector (Vision's `GenerateImageFeaturePrintRequest`, cached on disk),
and a softmax head is trained on the standardised vectors with Adam and BLAS in a few seconds per
epoch. One card in five is held out, so the reported validation accuracy means "cards the model
never saw", which is as close to a photo as the sources get. The output is
`App/Resources/PokemonClassifier.weights` (raw floats, about 4 MB) plus `Data/classifier.json` with
the class list, the standardisation and the metrics. Create ML's image classifier was the first
attempt; its revision-2 feature extractor leaks until it dies somewhere past 5,000 images, which is
why the pipeline extracts the same features itself. `--limit`, `--cards-per-class`, `--synthetic`,
`--iterations` and `--skip-cards` shape quick experiments; the download and feature caches make
re-runs cheap.

## App (`App/`)

SwiftUI, iOS 26 and macOS 26 and later, Swift 6 language mode with main-actor default isolation.
The `Neodex` (iOS) and `NeodexMac` targets compile the same `App/` and `Shared/` folders; `Mac/`
adds only what the Mac needs.

```
Shared/                    Compiled into the app and the widget extension: TypeStyle/TypeBadge,
                           PersistenceModels (SavedTeam, TeamMember, BrowsingRecord), SmogonStatsClient,
                           SharedContainer (App Group paths), WidgetModels (WidgetPokemon, snapshot,
                           DailyPick), UsageDefaults, TeamReader, WatchTeamSnapshot (the watch payload),
                           Shared.xcassets (type colours)
Widgets/                   WidgetKit extension: Pokémon of the Day, Who's That Pokémon?, Team,
                           Popular on Showdown, and two Control Center controls
Watch/                     The watchOS app: WatchRootView (vertical pages), WatchTodayView,
                           WatchDexbotView and WatchTeamsView (over the iPhone link), WatchTypeMatchupView,
                           WatchPokedexView, WatchPokemonDetailView, WatchPokemonImage (HEIC thumbnails
                           from the bundle), PhoneLink (the watch's end of WatchConnectivity)
WatchWidgets/              The watch complication extension: Pokémon of the Day, Who's That
                           Pokémon? (with a Reveal button in the Smart Stack) and an Open Neodex
                           Poké Ball, in the circular, rectangular, inline and corner families
Mac/                       Mac-only files for the NeodexMac target: Info.plist (the neodex:// scheme),
                           NeodexMac.entitlements (App Sandbox, camera, microphone, network, App Group)
                           and NeodexCommands (the Go and Pokémon menus)
App/
├── NeodexApp.swift        @main; SwiftData container for teams and history (in the App Group)
├── App/                   AppModel (load state), DatabaseProvider, DeepLinkRouter, RootView,
│                          MainTabView, AppTab, AppRoute
├── Intents/               App Intents: PokemonEntity + query, Open / Random / Type Matchup /
│                          Dex Entry intents, and the App Shortcuts phrases
├── CarPlay/               CPTemplateApplicationScene delegate: Dexbot as a voice-based conversation app
├── Features/              One folder per feature: Home, Dexbot, Pokedex, Moves, Abilities, Items, Types,
│                          Natures, Search, Teambuilder, DamageCalc, FaceOff, UsageStats, Settings,
│                          About
├── DesignSystem/          Type palette, TypeBadge, PokemonImage, shared components, Platform (the
│                          iOS/macOS shims) and ImageDecoding (ImageIO → CGImage)
├── Services/              SmogonStatsClient (actor, rankings + trends), MediaCache (actor),
│                          AnimatedSprite, CryPlayer, SpotlightIndexer, History, WatchLink (the
│                          iPhone's end of WatchConnectivity)
├── Persistence/           SwiftData models: SavedTeam, TeamMember, BrowsingRecord
├── Preview Content/       preview-*.json fixture for Xcode Previews  ← generated, debug builds only
├── PrivacyInfo.xcprivacy  Privacy manifest (UserDefaults access, no tracking, no data collection)
└── Resources/             Assets.xcassets (icon + colours), AppIcon.icon, Data/, Images/  ← generated
```

Key decisions:

- **Reference data is read-only JSON, not a database.** 5.5 MB decodes in well under a second off
  the main actor, the whole dataset fits comfortably in memory, and every lookup is a dictionary hit.
  SwiftData is used only for what the user creates (teams, browsing history).
- **Every feature is a tab.** `AppTab` declares them inside `TabSection`s (Reference, Battle) with
  `customizationID`s. iPad and the Mac show the grouped sidebar with the system's drag-to-customise
  editing; iPhone shows Home, Search and the tabs the user keeps visible. That set is stored by the app, since
  `TabViewCustomization` exposes tab-bar visibility read-only; Settings' toggles write it and reset
  sidebar edits. Home's cards push the same feature content inside Home's own stack.
- **One route type.** `AppRoute` enumerates every pushable screen; every `NavigationStack` registers
  `.appDestinations()`, so any view can link to any entity with `NavigationLink(value:)`. The same
  type doubles as the Spotlight deep-link identifier (`pokemon:bulbasaur`).
- **Images are loose bundle files with unique names.** Xcode's synchronized folders flatten resources
  into the bundle root, so files are named `pikachu-art.heic`, `pikachu-thumb.heic`,
  `pikachu-sprite.png` and loaded through a small cache (`BundledImageStore`) that decodes them with
  ImageIO straight to `CGImage`, which is `Sendable` and which iOS and macOS draw alike.
- **Concurrency.** The database is `Sendable` and shared through the environment; the Smogon client is
  an actor with a disk `URLCache`; pure value types that cross isolation boundaries (`AppRoute`,
  `UsageSelection`) are declared `nonisolated`.
- **Showdown compatibility.** Teams round-trip through `ShowdownTeamCodec`; the editor only offers
  moves the Pokémon can learn, resolves pasted sets by tolerant name matching, and reports anything it
  could not match.
- **Intents share the database.** `DatabaseProvider` (an actor) loads the dataset exactly once for
  the UI and for App Intents, which can run before any view exists; `DeepLinkRouter` is the one place
  Spotlight and Siri hand a screen to the app. `AppIntent`, `AppEntity` and `AppShortcutsProvider`
  require `Sendable`, so those types are `nonisolated` (or expose `nonisolated` static requirements)
  despite the module's main-actor default isolation.
- **Media streams on demand.** Animated sprites and cries come from Pokémon Showdown the first time
  they are shown and are kept in `Caches/ShowdownMedia`. GIFs are decoded with ImageIO and driven by
  `TimelineView`; Reduce Motion shows a single frame; the bundled still sprite is the stand-in.
- **The damage calculator reuses `TeamMember`.** A calculator side is a Teambuilder set plus battle
  state (stat stages, status, HP, Tera, screens), so sets hand over from the editor unchanged and the
  same pickers edit both.
- **On-device intelligence is optional.** `PickExplainer` asks the Foundation Models framework for one
  sentence per Home pick, with guided generation (`@Generable`) so the output is always three strings.
  It only runs when `SystemLanguageModel.default.availability` is `.available`, is given nothing but
  the Pokémon's types, genus and egg groups, and the section simply doesn't appear otherwise.
- **Dexbot is tools first.** `DexbotEngine` builds a `LanguageModelSession` with ten `Tool`s over the
  dataset (`DexbotTools`: Pokémon fact sheets, matchups, moves, abilities, items, learnsets, Smogon
  usage, the damage calculator, the user's teams and legality). The instructions tell the model to use
  them for every fact, so it phrases and reasons but never supplies data of its own. The chat screen
  streams replies and persists them as `DexbotConversation`s in the shared store; Siri's
  `AskNeodexIntent` and CarPlay use one-shot `answer` calls with spoken-style instructions. On iOS 27
  the user can prefer Apple's Private Cloud Compute model. That model needs Apple's managed
  `com.apple.developer.private-cloud-compute` entitlement, and without it the framework still reports
  the model as available and then traps on the first request, so the cloud path is compiled in only
  when the `PRIVATE_CLOUD_COMPUTE` Swift condition is set next to the entitlement; a network, quota or
  service failure mid-chat falls back to the on-device model and says so. iOS 26 runs on device only.
  Voice mode uses `SpeechAnalyzer`/`SpeechTranscriber` for on-device recognition and
  `AVSpeechSynthesizer` for replies.
- **The scanner is one actor and one matrix.** `PokemonRecognizer` asks Vision for the image's
  scene-print feature vector, standardises it with the manifest's statistics and multiplies it by the
  bundled weights (Accelerate), then reads printed names with `RecognizeTextRequest` as a second
  opinion (cards and screens). `CameraScanner` owns the capture session and hands a few frames a
  second to `ScanModel`, which smooths the probabilities over time and locks when the same Pokémon
  leads three frames in a row; photos are scanned once with both passes. The same recogniser answers
  visual intelligence: `PokemonVisualSearchQuery` is the app's `IntentValueQuery` for a
  `SemanticContentDescriptor`, `PokemonEntity` is an `IndexedEntity`, and `OpenPokemonIntent` is the
  `OpenIntent` that opens a result. The framework only exists in the device SDK, so that query is
  compiled out of simulator builds.
- **The watch app is the same data, trimmed to the wrist.** `NeodexWatch` is a watchOS target that
  compiles `Watch/` and `Shared/` against NeodexKit and runs independently of the phone
  (`WKRunsIndependentlyOfCompanionApp`). It ships the full `Data/` JSON and the 120 px thumbnails
  through Xcode folder references into `App/Resources`, so nothing is duplicated in the repository
  and the bundle has `Data/` and `thumbs/` subdirectories (about 23 MB). The screens are a vertical
  page `TabView` (blur transition) with the long Pokédex list last, since you can't page past a
  thousand rows; the daily picks come from the same `DailyPick` arithmetic as the widgets, so every
  device agrees on the day's Pokémon. `WatchTheme` gives each screen the watchOS full-screen colour
  wash (`containerBackground(_:for: .navigation)`): a gradient from the Pokémon's or chosen types'
  colours down to black, with cards as material and the few actions (random Pokémon, swap types) as
  glass buttons in the bottom corner of the toolbar. Thumbnails are decoded off the main thread into a `CGContext`, because watchOS has
  no `preparingForDisplay()`. The complication extension can't read the app's bundle, so it carries
  `pokemon-index.json` (a compact per-Pokémon index the pipeline now writes) and the thumbnails,
  downsampled to 80 px before archiving: WidgetKit refuses images above 80 points in the small
  families and fails the whole placeholder batch, after which `chronod` benches the extension for a
  day. The reveal state lives in the App Group defaults so the Today page and the complication agree,
  and complications deep-link into the watch app (`neodex://pokemon/<id>`, `neodex://mystery`).
- **The watch bridge is a pipe, not a sync service.** `Shared/WatchTeamSnapshot` is the payload both
  sides share: the saved teams as the `TeamMember` values the Teambuilder stores. `WatchLink` (iOS)
  activates `WCSession` in the app's `init`, so a question from the wrist can launch the app in the
  background; it pushes the twenty most recent teams as the application context whenever SwiftData
  saves (latest wins, delivered even while the watch sleeps) and answers questions with
  `DexbotEngine.answer(spoken: true)` under a background task. `PhoneLink` (watchOS) keeps the last
  snapshot on disk for offline use, publishes it to `WatchTeamsView`, and runs the ask for
  `WatchDexbotView`, whose page offers one-tap questions so the first ask needs no dictation. A question
  carries an id and goes out as an interactive message first (that is what wakes the iPhone app); if no
  reply arrives within twelve seconds, or the iPhone isn't reachable, the same question is queued as a
  user-info transfer and the answer comes back the same way, matched by id, with a ninety-second
  timeout. The watch now has five pages (Today, Dexbot, Teams, Type-O-Matic, Pokédex); its `open(_:)`
  also understands `neodex://dexbot` and `neodex://teams` for a future complication (watchOS apps can't
  be opened by URL from outside). Development aids, DEBUG only: `-neodexSeedSampleTeam YES` on the
  iPhone app seeds one team into an empty store, and `-watchStartPage teams` (or `dexbot`) opens the
  watch app on a page, since the simulator offers no Digital Crown.
- **The Mac is the same app with a sidebar and a menu bar.** `NeodexMac` compiles `App/` and
  `Shared/` for macOS 26 under App Sandbox and the hardened runtime; `Mac/` holds its Info.plist,
  entitlements and `NeodexCommands`. The platform differences are a handful of shims in
  `App/DesignSystem/Platform.swift` (`inlineNavigationTitle()`, `ToolbarItemPlacement.trailingBar`,
  `Color.groupedBackground`, `Clipboard`, …) so the views read the same on both, and the image path
  is `CGImage` throughout, so there is no `UIImage`/`NSImage` split. `MainTabView`'s sidebar-adaptable
  `TabView` is the Mac sidebar; the selected tab is published as a focused scene value so the Go menu
  (⌘1–⌘9) can switch it. Entries requested from Spotlight, Siri, Dexbot or the Pokémon menu open in a
  `WindowGroup(for: AppRoute.self)` window rather than a sheet, so two entries can sit side by side,
  and `handlesExternalEvents` keeps URLs flowing to the open main window. Settings is a `Settings`
  scene (General and About; the iPhone tab-bar section is left out). `CameraScanner` uses the camera
  the system prefers (built-in, Continuity or USB) behind an `NSViewRepresentable` mirrored preview
  and hands over upright frames. Not on the Mac yet: CarPlay (`#if canImport(CarPlay)`), visual
  intelligence (the macOS 27 SDK has the framework but its types need macOS 27), widgets (so
  `WidgetBridge` is skipped there) and the alternate app icon.
- **CarPlay is a scene, not a second UI.** `CarPlaySceneDelegate` shows one `CPListTemplate` with
  "Ask Dexbot" and recent chats; everything is spoken and the list only carries short status text. The
  scene is declared in `App/Info.plist`. Apple granted the
  `com.apple.developer.carplay-voice-based-conversation` entitlement in October 2026, so it is in the
  device entitlements (`App/Neodex.entitlements`); the simulator-only file
  (`App/Neodex-Simulator.entitlements`) also claims Private Cloud Compute so both can be exercised in
  the simulator before that entitlement arrives. Xcode 27's Device Hub has no CarPlay (or other external) display for
  simulators; its CarPlay Simulator plug-in pairs with a physical iPhone over USB. To see the scene
  without the entitlement, run an iOS 26.4+ simulator from Xcode 26's Simulator app and choose
  I/O › External Displays › CarPlay.
- **The dataset is versioned.** The pipeline writes a calendar version (`2026.10.9`) and "what's
  new" notes into the manifest; About shows them in an App Store-style card.
- **Widgets read a snapshot, not the bundle.** An app extension cannot read the app's bundle, so
  `WidgetBridge` stocks the App Group after each launch: a 270 KB index of every Pokémon
  (`WidgetPokemon`), every battle sprite (5 MB, once per dataset version), artwork for two weeks of
  daily picks, and the pick schedule itself. `DailyPick` is the one formula Home and the widgets both
  use for the Pokémon of the Day. The SwiftData store lives in the group too, so the Team widget reads
  teams directly (hopping to the main actor, since `@Model` classes are isolated there); the app
  migrates an existing store into the group on first launch. Widgets deep-link with `neodex://`
  URLs that `DeepLinkRouter` turns into routes; picks that need the database (`random`, `today`,
  `mystery`) are resolved by `MainTabView`. Controls open the app through `OpenURLIntent`.
- **Previews run on real data.** `App/Preview Content` holds a 0.7 MB slice of the generated dataset
  (14 seed species, their whole evolution families and forms, and every move, ability and item they
  reference). `PokedexDatabase.preview` loads it synchronously and `PreviewHost` wraps any screen with
  it plus an in-memory SwiftData store seeded with a sample team. The folder is a development asset,
  so archives never ship it.

## Scope Lens (`Packages/ScopeLens`)

Scope Lens is a live observer and advisor for Pokémon Champions (VGC doubles) battles that grew up
as its own macOS app and was merged in on 2026-10-24 as a Swift package the Mac target links. It
watches a mirrored game (an iPhone over QuickTime, or a capture card) with ScreenCaptureKit, reads
the screen with Vision OCR and template matching, and advises with deterministic math; it never
simulates the battle. This repository is its home now: the code here, the engine and its data in
`Tools/ScopeLensEngine`, the diagnostics harnesses, verification gate and advisor eval in
`Tools/ScopeLensDiagnostics`, and the spec, briefs and backlog in `Docs/ScopeLens`. Only the fixtures
(real Champions screenshots and recordings, which carry other trainers' names) stay in the private
standalone checkout; the scripts read them through `SCOPELENS_FIXTURES`.

```
Packages/ScopeLens/Sources/ScopeLens/
  MirrorCaptureSource        ScreenCaptureKit window discovery, viewport detection, throttled frames
  ScreenStateClassifier      which screen the frame shows (team preview, command, move select, …)
  OCRService                 Vision text recognition with normalized boxes
  PreviewPipeline            the team-preview reader: type-icon classifier + species identifier
                             (pixel icon sheet + HOME renders, rank-fused), confirm taps
  BattleEventParser,         the battle narration → events → running BattleState, with the rules
  BattleReconciler,          that reject illegal readings
  BattleState, BattleVocabulary
  ScoutEngine                the TypeScript engine (engine.js) in JavaScriptCore: type math, meta
                             priors, @smogon/calc rolls, the scout report
  TeamStore, TeamManager     the player's team from a Showdown paste, validated against the vocab
  MetaStore                  the Pikalytics usage snapshot and its on-demand refresh
  AdvisorClient, AdvisorContext, AdvisorTools, PlayLint
                             the opt-in Claude advisor: an agentic tool loop over the engine's six
                             tools, prompt caching, and a lint that bounces illegal plays
  LiveTrackerView, ScoutReportView, BattleLogView, OpponentDossierView, BattleArchiveView,
  OverlayHUD, *SettingsView  the windows
  Resources/                 engine.js, meta-regmbs3.json, vocab.json, dex-info.json,
                             tool-schemas.json, the icon sheet, templates, species index, features
Tools/ScopeLensEngine/       engine.ts and its data bakers, the Pikalytics fetcher, the MCP server
Tools/ScopeLensDiagnostics/  the CLI harnesses (classifier, preview pipeline, engine parity, battle
                             replay, PlayLint, advisor eval), verify-all.sh, and the findings log
Docs/ScopeLens/              the spec, the session briefs and the backlog
```

- **It keeps its own compile settings.** The package is Swift 5 language mode with main-actor
  default isolation and the approachable-concurrency features, exactly as the standalone app was
  built, so the sources stay byte-for-byte shareable with that project and its diagnostics CLIs.
  The only edits on the way in: `Bundle.main` became `Bundle.module` for the seven resource loads,
  the eight windows and the overlay controller became `public`, and the standalone `@main` entry
  point was left behind (a library must not define `main`).
- **The Mac app wraps, never reaches in.** `Mac/ScopeLensScenes.swift` is the only file that
  imports the package: `ScopeLensContent` is the sidebar's Scope Lens tab (the live tracker),
  `ScopeLensWindows` declares the Live Tracker, Scout Report, Battle Log, Scouting Dex and Battle
  Archive windows with the ids and ⇧⌘L/R/B/K/A shortcuts the tracker's buttons already use, and three
  wrappers put the Champions Team, Advisor and Meta panes into the Settings window. `AppTab.scopeLens` exists only in
  `features` on macOS, so Home's cards and the Go menu pick it up there and iOS never sees it. The
  entitlements gain user-selected read-only files for the OCR inspector's open panel.
- **The two halves talk.** `NeodexBridge` (in the package) is a pair of optional hooks Neodex fills
  in on the Mac. `openEntry` turns every species, move, ability and item name in the dossier, the
  scout report, the battle log and the tracker into a link that opens Neodex's entry in its own
  window (`ScopeLensEntryResolver` maps the engine's spellings to Showdown-style ids, with a name
  search as the fallback); `askDexbot` puts a question in front of Dexbot on the Dexbot tab. In the
  standalone app both are nil and the names render as plain text. Dexbot gets a Mac-only `liveBattle`
  tool that returns `LiveTrackerModel.liveBattleSummary()`: the board, the opponent's observed facts,
  the usage-based likely sets, the live matchup and the recent log, in plain text sized for the
  on-device model, so it can suggest the play without an API key. Teams flow the other way: "Use in
  Scope Lens" on a Neodex team, or the Champions Team settings pane, exports the team in Showdown's
  format and runs it through Scope Lens's own validation (`ScopeLensTeamBridge`), which also
  remembers which Neodex team is linked.
- **Where its data lives.** Team, meta cache and the battle archive are JSON in Neodex's
  Application Support (the sandbox container); the Anthropic key is in the Keychain, or
  `ANTHROPIC_API_KEY` in the environment for development runs. The standalone app's container is
  separate, so nothing migrates automatically.
- **Package tests** (`cd Packages/ScopeLens && swift test`) prove the engine, vocabulary, species
  index and tool schemas load from the package bundle and that a scout report comes back. The
  heavier gate is `Tools/ScopeLensDiagnostics/verify-all.sh`: it compiles the package sources straight
  into CLIs (hence `Bundle.scopeLens`, which is the package bundle in the app and the main bundle in
  a CLI), replays recorded battles and stills from the private fixtures, checks PlayLint, builds the
  Mac app and checks the MCP server against the engine.

## Testing

```bash
cd Packages/NeodexKit && swift test     # logic, codec, parsers, database (fast, macOS)
cd Tools/NeodexData && swift test       # pipeline: CSV, JS evaluation, name mapping, join rules, fixture
cd Packages/ScopeLens && swift test     # Scope Lens: engine, vocabulary, templates load from the package bundle
# The widget extension builds with the app; the simulator ignores the App Group entitlement, so widgets
# can be added to the simulator Home Screen and read the group container like on a device.
xcodebuild -scheme Neodex -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # + bundled-data and fixture smoke tests
# The recogniser tests that run the Core ML model only execute on a device: Vision's scene-print
# feature extractor can't create its inference context in the simulator.
```

## Known limitations

- PokeAPI's Pokédex entries and encounter data lag the newest games; locations are shown for the most
  recent game that has data (often Sword/Shield).
- Global Stats and Home's "Popular on Showdown" need a network connection; everything else works
  offline.
- Animated sprites and cries are not bundled; they stream from Showdown and are cached after first
  use. A few of the newest forms have no animation yet and fall back to the still sprite.
- The damage calculator models the modifiers that decide almost every real calc, but not entry
  hazards, multi-turn moves, ally abilities or Dynamax.
- The Mac app has no widgets or visual intelligence yet, and its camera scanner and voice mode have
  not been tried on a Mac; Home, the entry windows and the calculator have.
- Dexbot on the watch needs the iPhone nearby: the watch has no Apple Intelligence of its own, so the
  question travels over WatchConnectivity and comes back as a one-shot spoken-style answer. The paired
  simulators deliver iPhone-to-watch payloads (teams arrive) but not watch-to-iPhone ones: the iPhone's
  WatchConnectivity daemon receives the question, holds the app for ten seconds and drops it, on both
  the interactive and the queued channel, so the relay's answer path still needs its first run on real
  hardware; the teams channel and the watch's timeout and recovery were verified in the simulator.
- Scope Lens needs a mirrored Pokémon Champions window (QuickTime iPhone mirror or a capture card)
  and Screen Recording permission, and its advisor is off until an Anthropic API key is saved in
  Settings. Leaving the Scope Lens tab or closing the Live Tracker window stops tracking, as it did in the
  standalone app.
