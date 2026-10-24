# Scope Lens conventions

Scope Lens (this package, `Tools/ScopeLensEngine` and `Tools/ScopeLensDiagnostics`) is the live
Pokémon Champions battle observer and advisor inside the Neodex Mac app. Its design docs are in
`Docs/ScopeLens`; read `Docs/ScopeLens/Spec.md` once and the findings log
(`Tools/ScopeLensDiagnostics/README.md`, newest milestones last) before changing anything near
parsing, the reconciler or the advisor. These rules were all earned the hard way.

- **Observer, not simulator.** Mirror what the screen shows; infer with the game's rules; never
  simulate the battle. The state contract is defined top-down (the spec), never grown from OCR output.
- **Fixture-first.** Anything parser-adjacent starts from an exact recorded read. The fixtures live in
  the private Scope Lens checkout (they carry other trainers' names and never enter this public repo);
  the scripts find them through `SCOPELENS_FIXTURES`, defaulting to `../Scope Lens/Fixtures`.
- **The gate.** Run `Tools/ScopeLensDiagnostics/verify-all.sh` after every change to a shared file
  and keep it green (7/7). It compiles these sources straight into CLIs, so the shared-file rule holds:
  files the harnesses compile stay Foundation-only, with `nonisolated` on every type, extension and
  nested conformance (the package builds with main-actor default isolation). `Bundle.scopeLens`, not
  `Bundle.module`, for resources.
- **The eval gates the advisor.** Any doctrine, prompt, data or request-shape change re-runs
  `Tools/ScopeLensDiagnostics/eval-advisor.sh` (`--dry-run` is free) and must stay inside the
  latency budget written in the findings log (turn p50 ≤ 10 s, soft 18 s, worst about 30 s). A red
  case is evidence about the change or the baseline; bisect before believing either.
- **Anthropic API changes** consult the `claude-api` skill first. The key comes from the Keychain in
  the app, or `ANTHROPIC_API_KEY` / a gitignored `.env.local` at the repo root for the harnesses;
  never read `.env.local`, never log the key.
- **Engine rebuilds** use the pinned esbuild (`Tools/ScopeLensEngine/README.md`) and copy
  `dist/engine.js` into this package's `Resources/Engine/`; data files change in `Tools/ScopeLensEngine/data`
  and are copied beside the engine too.
- **Pikalytics is fetched politely and only on explicit action**; the committed snapshot is the
  fallback that every harness pins to.
- Findings go into the findings log as you go; deferred work goes into `Docs/ScopeLens/Backlog.md`.
