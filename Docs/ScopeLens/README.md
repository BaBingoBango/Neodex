# Scope Lens

Scope Lens is the live observer and advisor for Pokémon Champions battles that ships inside the
Neodex Mac app. It began as its own project (BaBingoBango/Scope-Lens, private) and moved here on
2026-10-24; this folder is its home for design and working notes, and this repository is now where
its code lives.

| What | Where |
| --- | --- |
| The code the Mac app runs | [`Packages/ScopeLens`](../../Packages/ScopeLens) (see its `CLAUDE.md` for the working conventions) |
| The TypeScript engine, data bakers, Pikalytics fetcher and MCP server | [`Tools/ScopeLensEngine`](../../Tools/ScopeLensEngine) |
| The diagnostics harnesses, the verification gate and the advisor eval | [`Tools/ScopeLensDiagnostics`](../../Tools/ScopeLensDiagnostics) ([findings log](../../Tools/ScopeLensDiagnostics/README.md)) |
| How it plugs into the Mac app | [`Docs/ARCHITECTURE.md`](../ARCHITECTURE.md), the Scope Lens section |
| The fixtures (real Champions screenshots and battle recordings) | The private Scope Lens checkout, never this repository: they carry other trainers' names. The scripts read them through `SCOPELENS_FIXTURES`. |

## Documents

- [Spec.md](Spec.md): the product and engineering spec (v0.1), the principles the whole thing is
  built on: observer not simulator, a top-down state contract, identity from pixels, two speeds.
- [Backlog.md](Backlog.md): the deferred-work ledger, each item with its root-cause hypothesis.
- [Briefs/](Briefs): the session kickoff briefs (3 through 11) and the opponent-dossier brief; the
  history of what each milestone set out to do and the guardrails it earned.
- [Agent-instructions-standalone.md](Agent-instructions-standalone.md): the agent instructions the
  standalone repository used, kept for the record. The live conventions are in
  `Packages/ScopeLens/CLAUDE.md`.

The paths inside these documents are the standalone layout's: `Scope Lens/` is now
`Packages/ScopeLens/Sources/ScopeLens/`, `Engine/` is `Tools/ScopeLensEngine/`, and `Diagnostics/`
is `Tools/ScopeLensDiagnostics/`.
