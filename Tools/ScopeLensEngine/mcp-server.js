#!/usr/bin/env node
// ScopeLens MCP server (m10-B) — spec §4.3's promise delivered: the
// deterministic engine's functions exposed as MCP tools over stdio, so a
// Claude session can be asked "teach me this matchup" against the real
// Reg M-B usage snapshot with @smogon/calc numbers.
//
// Zero dependencies: MCP's stdio transport is newline-delimited JSON-RPC
// 2.0, and a tools-only server needs exactly initialize / initialized /
// tools/list / tools/call / ping. The engine is the same pinned-esbuild
// bundle the app ships (Engine/dist/engine.js) with the same data files —
// numbers match the scout CLI by construction.
//
// Run:            node Engine/mcp-server.js          (from anywhere)
// Self-test:      node Engine/mcp-server-test.js     (protocol + parity)
// Claude Code:    add to .mcp.json —
//   { "mcpServers": { "scopelens": {
//       "command": "node",
//       "args": ["/Users/ethan/Scope Lens/Engine/mcp-server.js"] } } }
//
'use strict';

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const engineDir = __dirname;
const repoRoot = path.resolve(engineDir, '..');

// stdout is PURE protocol; all human output goes to stderr.
const logErr = (...a) => process.stderr.write(a.join(' ') + '\n');

// Indirect eval runs the IIFE bundle in GLOBAL scope (strict-mode direct
// eval would keep its `var ScopeEngine` private). Side effect we keep: the
// bundle's banner replaces the global console with no-ops, so nothing
// inside the engine can ever corrupt the protocol stream on stdout.
(0, eval)(fs.readFileSync(path.join(engineDir, 'dist', 'engine.js'), 'utf8'));
const ScopeEngine = globalThis.ScopeEngine;

// Data files: meta snapshot (authoritative over the baked copy) + vocab.
ScopeEngine.setMeta(JSON.parse(
  fs.readFileSync(path.join(engineDir, 'data', 'meta-regmbs3.json'), 'utf8')));
const vocab = JSON.parse(
  fs.readFileSync(path.join(engineDir, 'data', 'vocab.json'), 'utf8'));

// Case/punctuation/apostrophe-insensitive species lookup (the TeamVocab
// matchKey convention).
const matchKey = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '');
const speciesByKey = new Map(vocab.species.map((s) => [matchKey(s.name), s]));

// The app's persisted team (sandbox container) — the convenient default
// for `mine`. Reads can be blocked by macOS TCC; callers then pass `mine`
// explicitly or set SCOPELENS_TEAM_JSON to a readable copy.
function loadConfiguredTeam() {
  const candidates = [
    process.env.SCOPELENS_TEAM_JSON,
    path.join(process.env.HOME || '', 'Library/Containers/com.ethan-marshall.Scope-Lens/Data/Library/Application Support/team.json'),
  ].filter(Boolean);
  for (const p of candidates) {
    try {
      const team = JSON.parse(fs.readFileSync(p, 'utf8'));
      if (Array.isArray(team.members) && team.members.length) {
        return team.members.map((m) => ({
          species: m.species,
          item: m.item, ability: m.ability,
          moves: m.moves && m.moves.length ? m.moves : undefined,
          evs: m.evs, ivs: m.ivs, nature: m.nature, level: m.level,
        }));
      }
    } catch { /* next candidate */ }
  }
  return null;
}

// ---- tool definitions -----------------------------------------------------
// Single source of truth since m11: Engine/tool-schemas.json — the app's
// agentic advisor sends the SAME six definitions to the Anthropic API
// (mapped inputSchema → input_schema), so MCP clients and the in-app tool
// loop reason over byte-identical tool surfaces.

const TOOLS = JSON.parse(
  fs.readFileSync(path.join(engineDir, 'tool-schemas.json'), 'utf8')).tools;

// ---- tool implementations ---------------------------------------------------

function resolveOne(raw) {
  const hit = speciesByKey.get(matchKey(raw));
  return hit
    ? { input: raw, matched: true, species: hit.name, display: hit.display, types: hit.types }
    : { input: raw, matched: false, input_key: matchKey(raw) };
}

const handlers = {
  resolve_species({ names }) {
    return { resolutions: names.map(resolveOne) };
  },

  meta_profile({ species }) {
    const resolved = resolveOne(species);
    const profile = ScopeEngine.metaProfile(resolved.matched ? resolved.species : species);
    if (!profile) {
      return {
        species: resolved.matched ? resolved.species : species,
        hasMeta: false,
        note: 'No Reg M-B ranked usage data for this species (off-ladder); damage tools fall back to learnset-derived movesets.',
      };
    }
    return { species: resolved.matched ? resolved.species : species, hasMeta: true, profile };
  },

  type_calc({ moveType, defenderTypes }) {
    const multiplier = ScopeEngine.typeEffect(moveType, defenderTypes);
    return { moveType, defenderTypes, multiplier };
  },

  damage_calc({ attacker, move, defender, field }) {
    const result = ScopeEngine.liveMatchup(
      [{ ...attacker, moves: [move] }], [defender], field || {});
    const hit = result.outgoing[0];
    if (!hit) {
      throw new Error(`no damage result — "${move}" may be a status move, unknown to the calc, or the species names may need resolve_species first`);
    }
    return {
      attacker: attacker.species, move, defender: defender.species,
      minPct: hit.minPct, maxPct: hit.maxPct,
      koNow: hit.koNow, guaranteedKo: hit.guaranteedKo,
      defenderCurrentHpPct: defender.curPct ?? 100,
      approxStats: hit.approx,
      assumptions: result.assumptions,
    };
  },

  scout_report({ theirs, mine }) {
    let mineSpecs = mine;
    let mineSource = 'caller-provided';
    if (!mineSpecs || !mineSpecs.length) {
      mineSpecs = loadConfiguredTeam();
      mineSource = 'configured ScopeLens team';
      if (!mineSpecs) {
        throw new Error('no `mine` given and the configured team is unreadable (macOS may require consent to read the app container) — pass `mine` explicitly or set SCOPELENS_TEAM_JSON to a team.json path');
      }
    }
    const report = ScopeEngine.scoutReport(
      mineSpecs, theirs.map((s) => ({ species: s })));
    return { markdown: report.markdown, safeFour: report.safeFour, leads: report.leads, mineSource };
  },

  live_matchup({ mine, theirs, field }) {
    return ScopeEngine.liveMatchup(mine, theirs, field || {});
  },
};

// ---- MCP over newline-delimited JSON-RPC 2.0 -------------------------------

const SUPPORTED_VERSIONS = ['2025-06-18', '2025-03-26', '2024-11-05'];
const send = (msg) => process.stdout.write(JSON.stringify(msg) + '\n');

function handle(req) {
  const { id, method, params } = req;
  const isNotification = id === undefined || id === null;

  switch (method) {
    case 'initialize': {
      const requested = params && params.protocolVersion;
      send({
        jsonrpc: '2.0', id,
        result: {
          protocolVersion: SUPPORTED_VERSIONS.includes(requested)
            ? requested : SUPPORTED_VERSIONS[0],
          capabilities: { tools: {} },
          serverInfo: { name: 'scopelens-engine', version: '0.1.0' },
        },
      });
      return;
    }
    case 'notifications/initialized':
    case 'notifications/cancelled':
      return; // notifications get no response
    case 'ping':
      if (!isNotification) send({ jsonrpc: '2.0', id, result: {} });
      return;
    case 'tools/list':
      send({ jsonrpc: '2.0', id, result: { tools: TOOLS } });
      return;
    case 'tools/call': {
      const name = params && params.name;
      const args = (params && params.arguments) || {};
      const handler = handlers[name];
      if (!handler) {
        send({ jsonrpc: '2.0', id, error: { code: -32602, message: `unknown tool: ${name}` } });
        return;
      }
      try {
        const result = handler(args);
        const text = name === 'scout_report'
          ? result.markdown + `\n\n_(mine: ${result.mineSource}; bring 4: ${result.safeFour.join(', ')})_`
          : JSON.stringify(result, null, 1);
        send({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text }], isError: false } });
      } catch (err) {
        // Tool-level failure: a normal result with isError, so the model can
        // read the message and adapt (JSON-RPC errors are protocol-level).
        send({
          jsonrpc: '2.0', id,
          result: { content: [{ type: 'text', text: `Error: ${err.message}` }], isError: true },
        });
      }
      return;
    }
    default:
      if (!isNotification) {
        send({ jsonrpc: '2.0', id, error: { code: -32601, message: `method not found: ${method}` } });
      }
  }
}

readline.createInterface({ input: process.stdin, terminal: false })
  .on('line', (line) => {
    if (!line.trim()) return;
    let req;
    try {
      req = JSON.parse(line);
    } catch {
      send({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'parse error' } });
      return;
    }
    try {
      handle(req);
    } catch (err) {
      logErr('internal error:', err.stack || String(err));
      if (req.id !== undefined && req.id !== null) {
        send({ jsonrpc: '2.0', id: req.id, error: { code: -32603, message: 'internal error' } });
      }
    }
  });

logErr(`scopelens-engine MCP server ready (repo: ${repoRoot})`);
