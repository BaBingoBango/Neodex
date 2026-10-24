#!/usr/bin/env node
// Protocol + parity self-test for the ScopeLens MCP server (m10-B).
// Spawns the server, performs the stdio handshake a real MCP client does
// (initialize → initialized → tools/list → tools/call), and asserts the
// numbers match the scout CLI / committed sample — the same pins
// ScoutEngineHarness holds. verify-all stage 6.
'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const engineDir = __dirname;
const repoRoot = path.resolve(engineDir, '..');

const server = spawn('node', [path.join(engineDir, 'mcp-server.js')], {
  stdio: ['pipe', 'pipe', 'inherit'],
});
const lines = readline.createInterface({ input: server.stdout, terminal: false });

const pending = new Map();
let nextId = 1;
lines.on('line', (line) => {
  if (!line.trim()) return;
  const msg = JSON.parse(line); // malformed protocol output should throw loudly
  const waiter = pending.get(msg.id);
  if (waiter) {
    pending.delete(msg.id);
    waiter(msg);
  }
});

function request(method, params) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    pending.set(id, resolve);
    server.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    setTimeout(() => {
      if (pending.delete(id)) reject(new Error(`timeout waiting for ${method}`));
    }, 15000);
  });
}
const notify = (method, params) =>
  server.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');

function callTool(name, args) {
  return request('tools/call', { name, arguments: args }).then((msg) => {
    if (msg.error) throw new Error(`${name}: protocol error ${JSON.stringify(msg.error)}`);
    return msg.result;
  });
}

let failures = 0;
function check(name, ok, detail) {
  console.log(`  ${ok ? '✅' : '❌'} ${name}${detail ? ': ' + detail : ''}`);
  if (!ok) failures += 1;
}

async function main() {
  // ---- handshake (what Claude Code sends) ---------------------------------
  const init = await request('initialize', {
    protocolVersion: '2025-06-18',
    capabilities: {},
    clientInfo: { name: 'mcp-server-test', version: '0.0.1' },
  });
  check('initialize', init.result
    && init.result.protocolVersion === '2025-06-18'
    && init.result.capabilities.tools !== undefined
    && init.result.serverInfo.name === 'scopelens-engine',
    init.result && init.result.protocolVersion);
  notify('notifications/initialized');

  const list = await request('tools/list');
  const toolNames = (list.result.tools || []).map((t) => t.name).sort();
  check('tools/list exposes the §4.3 surface',
    JSON.stringify(toolNames) === JSON.stringify(
      ['damage_calc', 'live_matchup', 'meta_profile', 'resolve_species', 'scout_report', 'type_calc']),
    toolNames.join(','));
  check('every tool has a schema',
    list.result.tools.every((t) => t.inputSchema && t.inputSchema.type === 'object'));

  // ---- parity: meta snapshot (the Pikalytics validation number) -----------
  const inc = JSON.parse((await callTool('meta_profile', { species: 'incineroar' }))
    .content[0].text);
  check('meta_profile: Incineroar Fake Out 99.9%',
    inc.hasMeta && Math.abs(inc.profile.moves['Fake Out'] - 99.9) < 0.2,
    String(inc.profile && inc.profile.moves['Fake Out']));

  // ---- resolve + type math -------------------------------------------------
  const res = JSON.parse((await callTool('resolve_species', {
    names: ['rotom wash', 'farfetchd', 'NotAMon'],
  })).content[0].text);
  check('resolve_species snaps punctuation/case',
    res.resolutions[0].species === 'Rotom-Wash'
    && res.resolutions[1].species === 'Farfetch’d'
    && res.resolutions[2].matched === false,
    res.resolutions.map((r) => r.species || 'MISS').join(','));

  const eff = JSON.parse((await callTool('type_calc', {
    moveType: 'Rock', defenderTypes: ['Fire', 'Flying'],
  })).content[0].text);
  check('type_calc: Rock vs Fire/Flying = 4x', eff.multiplier === 4, String(eff.multiplier));

  // ---- damage_calc: EV/nature plumb (the bridge-checked speed/damage pins) --
  const dmg = JSON.parse((await callTool('damage_calc', {
    attacker: { species: 'Charizard', item: 'Charizardite Y', evs: { spa: 252 }, nature: 'Modest' },
    move: 'Heat Wave',
    defender: { species: 'Incineroar', curPct: 20 },
  })).content[0].text);
  // m15-D: the unspecified defender now gets the MODAL ladder spread —
  // bulky Careful 32HP/20SpD Incineroar survives at 20% (was 24.8% max vs
  // the generic 252-HP-only defender of the 0-EV era).
  check('damage_calc: Modest 252 SpA Zard-Y Heat Wave vs MODAL Incineroar = 19.3% max',
    Math.abs(dmg.maxPct - 19.3) < 0.11 && dmg.koNow === false && dmg.guaranteedKo === false,
    `${dmg.minPct}-${dmg.maxPct}% koNow=${dmg.koNow}`);

  // ---- live_matchup: TR-aware order --------------------------------------
  const matchup = JSON.parse((await callTool('live_matchup', {
    mine: [{ species: 'Charizard', item: 'Charizardite Y', moves: ['Heat Wave'] }],
    theirs: [{ species: 'Incineroar', moves: ['Darkest Lariat'] }],
    field: { trickRoom: true },
  })).content[0].text);
  // m15-D: Charizard's speed is now the MODAL ladder point (Modest 252 →
  // 152), not the 0-EV floor (120). Incineroar's modal spread runs zero
  // speed, so TR still orders it first.
  check('live_matchup: Trick Room reverses speed order',
    matchup.trickRoom === true
    && matchup.speeds[0].species === 'Incineroar'
    && matchup.speeds[1].spe === 152,
    matchup.speeds.map((s) => `${s.species} ${s.spe}`).join(' > '));

  // ---- scout_report parity vs the committed sample -------------------------
  // Same inputs as the sample's exact recorded invocation; mine passed
  // explicitly as the default team's sets (the server may not be able to
  // read the app container in CI-like contexts).
  const defaultTeam = [
    { species: 'Charizard', item: 'Charizardite Y', moves: ['Heat Wave', 'Solar Beam', 'Weather Ball', 'Protect'] },
    { species: 'Venusaur', item: 'Focus Sash', moves: ['Sleep Powder', 'Leaf Storm', 'Sludge Bomb', 'Protect'] },
    { species: 'Garchomp', item: 'Choice Scarf' },
    { species: 'Rotom-Wash', item: 'Leftovers', ability: 'Levitate', moves: ['Hydro Pump', 'Thunderbolt', 'Will-O-Wisp', 'Protect'] },
    { species: 'Sneasler', item: 'White Herb' },
    { species: 'Incineroar', item: 'Sitrus Berry' },
  ];
  const scout = (await callTool('scout_report', {
    mine: defaultTeam,
    theirs: ['Whimsicott', 'Farigiraf', 'Charizard', 'Pelipper', 'Archaludon', 'Venusaur'],
  })).content[0].text;
  const sample = fs.readFileSync(
    path.join(repoRoot, 'Fixtures', 'preview', 'Team_Preview_Initial_scout.md'), 'utf8');
  const suggestion = sample.split('\n').find((l) => l.startsWith('**'));
  check('scout_report: bring-4 matches the committed sample',
    scout.includes(suggestion.split('—')[0].trim().replace(/\*/g, '').trim())
    && suggestion.includes('Charizard'),
    suggestion);
  check('scout_report: Farigiraf Trick Room 95.7% (sample pin)',
    scout.includes('Trick Room (95.7%)') && sample.includes('Trick Room (95.7%)'));

  // ---- tool-level error shape ----------------------------------------------
  const bad = await callTool('damage_calc', {
    attacker: { species: 'Charizard' }, move: 'Protect', defender: { species: 'Incineroar' },
  });
  check('status-move damage is a readable isError result',
    bad.isError === true && bad.content[0].text.startsWith('Error:'),
    bad.content[0].text.slice(0, 60));

  const unknown = await request('no/such/method');
  check('unknown method → -32601', unknown.error && unknown.error.code === -32601);

  console.log(failures === 0 ? '\n✅ MCP SERVER PROTOCOL + PARITY GREEN' : `\n❌ ${failures} FAILURES`);
  server.kill();
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error('test error:', err.stack || String(err));
  server.kill();
  process.exit(1);
});
