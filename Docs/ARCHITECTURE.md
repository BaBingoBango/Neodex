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
  the 25 natures and their flavors.
- **`ShowdownTeamCodec`** — a native parser/exporter for Showdown's team text format (replacing the
  JavaScriptCore bridge the original app used).
- **Smogon parsers** — rankings tables, directory listings and the "chaos" JSON, turned into
  percentages the UI can show directly.

The package is covered by Swift Testing suites (`swift test`), including a test that validates the
generated dataset when it is present on disk.

## NeodexData (`Tools/NeodexData`)

A dependency-free Swift command-line tool that rebuilds the bundled dataset from two open sources:

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
swift run neodex-data                 # full refresh (≈1 minute on a fresh cache)
swift run neodex-data --skip-images   # data only, a few seconds
swift run neodex-data --help
```

The whole bundle is ≈49 MB (5.5 MB JSON, 44 MB images) versus the 454 MB asset catalog of the
original app.

## App (`App/`)

SwiftUI, iOS 26 and later, Swift 6 language mode with main-actor default isolation.

```
App/
├── NeodexApp.swift        @main; SwiftData container for teams and history
├── App/                   AppModel (load state), RootView, MainTabView, AppTab, AppRoute
├── Features/              One folder per feature: Home, Pokedex, Moves, Abilities, Items, Types,
│                          Natures, Search, Teambuilder, FaceOff, UsageStats, Explore, Settings, About
├── DesignSystem/          Type palette, TypeBadge, PokemonImage, shared components
├── Services/              SmogonStatsClient (actor), SpotlightIndexer, History
├── Persistence/           SwiftData models: SavedTeam, TeamMember, BrowsingRecord
└── Resources/             Assets.xcassets (icon + colours), Data/, Images/  ← generated
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

## Testing

```bash
cd Packages/NeodexKit && swift test                       # logic, codec, parsers, database (fast, macOS)
xcodebuild -scheme Neodex -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # + bundled-data smoke tests
```

## Known limitations

- PokeAPI's Pokédex entries and encounter data lag the newest games; locations are shown for the most
  recent game that has data (often Sword/Shield).
- Global Stats and Explore's "Popular on Showdown" need a network connection; everything else works
  offline.
- Animated sprites from the original app were dropped to keep the bundle small.
