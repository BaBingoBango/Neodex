# Neodex architecture

Neodex is split into three pieces that share one set of Swift types:

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
5. Write `Data/*.json` and a `manifest.json` with counts, timestamp and source attribution.

```bash
cd Tools/NeodexData
swift run neodex-data                    # full refresh (≈1 minute on a fresh cache)
swift run neodex-data --skip-images      # data only, a few seconds
swift run neodex-data --preview-fixture  # rebuild only the Xcode Previews fixture
swift run neodex-data --help
swift test                               # pipeline tests: CSV, JS evaluation, name mapping, join rules, fixture
```

Every full run also refreshes the preview fixture (below), so the two never drift apart.

The whole bundle is ≈49 MB (5.5 MB JSON, 44 MB images) versus the 454 MB asset catalog of the
original app.

## App (`App/`)

SwiftUI, iOS 26 and later, Swift 6 language mode with main-actor default isolation.

```
App/
├── NeodexApp.swift        @main; SwiftData container for teams and history
├── App/                   AppModel (load state), DatabaseProvider, DeepLinkRouter, RootView,
│                          MainTabView, AppTab, AppRoute
├── Intents/               App Intents: PokemonEntity + query, Open / Random / Type Matchup /
│                          Dex Entry intents, and the App Shortcuts phrases
├── Features/              One folder per feature: Home, Pokedex, Moves, Abilities, Items, Types,
│                          Natures, Search, Teambuilder, DamageCalc, FaceOff, UsageStats, Explore,
│                          Settings, About
├── DesignSystem/          Type palette, TypeBadge, PokemonImage, shared components
├── Services/              SmogonStatsClient (actor, rankings + trends), MediaCache (actor),
│                          AnimatedSprite, CryPlayer, SpotlightIndexer, History
├── Persistence/           SwiftData models: SavedTeam, TeamMember, BrowsingRecord
├── Preview Content/       preview-*.json fixture for Xcode Previews  ← generated, debug builds only
├── PrivacyInfo.xcprivacy  Privacy manifest (UserDefaults access, no tracking, no data collection)
└── Resources/             Assets.xcassets (icon + colours), AppIcon.icon, Data/, Images/  ← generated
```

Key decisions:

- **Reference data is read-only JSON, not a database.** 5.5 MB decodes in well under a second off
  the main actor, the whole dataset fits comfortably in memory, and every lookup is a dictionary hit.
  SwiftData is used only for what the user creates (teams, browsing history).
- **One route type.** `AppRoute` enumerates every pushable screen; every `NavigationStack` registers
  `.appDestinations()`, so any view can link to any entity with `NavigationLink(value:)`. The same
  type doubles as the Spotlight deep-link identifier (`pokemon:bulbasaur`).
- **Images are loose bundle files with unique names.** Xcode's synchronized folders flatten resources
  into the bundle root, so files are named `pikachu-art.heic`, `pikachu-thumb.heic`,
  `pikachu-sprite.png` and loaded through a small cache (`BundledImageStore`).
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
- **The dataset is versioned.** The pipeline writes a calendar version (`2026.10.9`) and "what's
  new" notes into the manifest; About shows them in an App Store-style card.
- **Previews run on real data.** `App/Preview Content` holds a 0.7 MB slice of the generated dataset
  (14 seed species, their whole evolution families and forms, and every move, ability and item they
  reference). `PokedexDatabase.preview` loads it synchronously and `PreviewHost` wraps any screen with
  it plus an in-memory SwiftData store seeded with a sample team. The folder is a development asset,
  so archives never ship it.

## Testing

```bash
cd Packages/NeodexKit && swift test     # logic, codec, parsers, database (fast, macOS)
cd Tools/NeodexData && swift test       # pipeline: CSV, JS evaluation, name mapping, join rules, fixture
xcodebuild -scheme Neodex -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # + bundled-data and fixture smoke tests
```

## Known limitations

- PokeAPI's Pokédex entries and encounter data lag the newest games; locations are shown for the most
  recent game that has data (often Sword/Shield).
- Global Stats and Explore's "Popular on Showdown" need a network connection; everything else works
  offline.
- Animated sprites and cries are not bundled; they stream from Showdown and are cached after first
  use. A few of the newest forms have no animation yet and fall back to the still sprite.
- The damage calculator models the modifiers that decide almost every real calc, but not entry
  hazards, multi-turn moves, ally abilities or Dynamax.
