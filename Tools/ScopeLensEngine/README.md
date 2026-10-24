# Scope Lens engine

The deterministic half of Scope Lens: type math, usage priors, `@smogon/calc` damage rolls and the
team-preview scout report, written once in TypeScript so the same code runs inside the Mac app
(through JavaScriptCore) and as an MCP server (`mcp-server.js`). The Mac app loads the bundled
build from `Packages/ScopeLens/Sources/ScopeLens/Resources/Engine/engine.js`; the JSON data files
beside it (`dex-info`, `meta-regmbs3`, `vocab`, `tool-schemas`) are copies of the ones in `data/`
and this folder.

Rebuild with the pinned esbuild (a bare `npx esbuild` resolves to whatever is newest and made
builds unreproducible):

```bash
cd Tools/ScopeLensEngine
npm install
node_modules/.bin/esbuild src/engine.ts --bundle --format=iife --global-name=ScopeEngine \
  --banner:js="var console={log:function(){},warn:function(){},error:function(){}};" \
  --outfile=dist/engine.js
cp dist/engine.js ../../Packages/ScopeLens/Sources/ScopeLens/Resources/Engine/engine.js
```

`dist/engine.js` is what the MCP server and the diagnostics harnesses load; the copy in the
package is what the app ships. Keep them identical (`verify-all.sh` stage 7 checks the server
against the engine).

`fetch-meta.js` refreshes the Pikalytics usage snapshot (politely: two connections, 200 ms
spacing, only on demand), `build-vocab.js`, `build-dex-info.js` and `build-learnset-fallback.js`
bake the closed vocabulary and effect text from `@pkmn/dex`, and `champions-overrides.json` is the
small delta where Pokémon Champions differs from the mainline games. After changing any data file,
copy it next to `engine.js` so the app sees it.

The replay harnesses and the advisor eval are in `Tools/ScopeLensDiagnostics`; the fixtures they
read stay in the private Scope Lens checkout (`SCOPELENS_FIXTURES`).
