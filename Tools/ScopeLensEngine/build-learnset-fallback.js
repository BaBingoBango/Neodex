#!/usr/bin/env node
// Builds Engine/data/learnset-fallback.json — plausible STAB movesets for
// species with NO usage data (m4 task C). True off-ladder opponents currently
// contribute zero threats to the scout report; this lets the report degrade
// to "here's what its learnset could plausibly do" instead of going blind.
//
//   node build-learnset-fallback.js
//
// Per species: up to 2 best STAB attacks (one per type where possible) + the
// best remaining coverage attack + Protect (the VGC constant). "Best" =
// basePower × accuracy, skipping recharge / self-KO / charge gimmicks that
// no real set runs blind. Keyed by the engine's slugify(species.name).
//
// Kept deliberately simple — these are labeled GUESSES (setSource:
// "learnset"), not predictions; the moment the mon reveals a real move the
// observed set wins.

const fs = require('fs');
const path = require('path');
const {Dex} = require('@pkmn/dex');

const slugify = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-');
const drop = (x) => x.isNonstandard === 'CAP' || x.isNonstandard === 'Custom';

async function mergedLearnset(species) {
  // Showdown learnset entries are sparse for formes/evolutions; merge the
  // inheritance chain (prevos + base/changesFrom formes) like the validator.
  const moveIds = new Set();
  const seen = new Set();
  let cur = species;
  while (cur && !seen.has(cur.id)) {
    seen.add(cur.id);
    const l = await Dex.learnsets.get(cur.id);
    for (const id of Object.keys(l?.learnset ?? {})) moveIds.add(id);
    const next = cur.prevo || (cur.changesFrom ?? (cur.name !== cur.baseSpecies ? cur.baseSpecies : null));
    cur = next ? Dex.species.get(next) : null;
    if (cur && !cur.exists) cur = null;
  }
  return moveIds;
}

function score(move, stab) {
  if (move.category === 'Status' || !move.basePower) return 0;
  if (move.isZ || move.isMax || drop(move)) return 0;
  const f = move.flags ?? {};
  if (f.recharge || f.charge) return 0;           // Hyper Beam / Solar Beam class
  if (move.selfdestruct || move.mindBlownRecoil) return 0;
  if (typeof move.accuracy === 'number' && move.accuracy < 70) return 0;
  const acc = move.accuracy === true ? 1 : move.accuracy / 100;
  return move.basePower * acc * (stab ? 1.5 : 1);
}

async function main() {
  const fallback = {};
  for (const s of Dex.species.all()) {
    if (drop(s) || s.num <= 0) continue;
    if (s.forme.includes('Mega') || s.forme === 'Gmax') continue; // calc resolves megas from the base set
    const ids = await mergedLearnset(s);
    const scored = [...ids]
      .map((id) => Dex.moves.get(id))
      .filter((m) => m.exists)
      .map((m) => ({m, stab: s.types.includes(m.type), v: 0}))
      .map((e) => ((e.v = score(e.m, e.stab)), e))
      .filter((e) => e.v > 0)
      .sort((a, b) => b.v - a.v);

    const picks = [];
    for (const type of s.types) { // best STAB per type
      const best = scored.find((e) => e.m.type === type && e.stab && !picks.includes(e.m.name));
      if (best) picks.push(best.m.name);
    }
    const coverage = scored.find((e) => !picks.includes(e.m.name));
    if (coverage) picks.push(coverage.m.name);
    if (ids.has('protect') && picks.length) picks.push('Protect');
    if (picks.length) fallback[slugify(s.name)] = picks.slice(0, 4);
  }

  const out = path.join(__dirname, 'data', 'learnset-fallback.json');
  fs.writeFileSync(out, JSON.stringify(fallback, null, 1));
  console.log(`wrote ${out} — ${Object.keys(fallback).length} species`);
  for (const probe of ['zygarde', 'staraptor', 'basculegion', 'farfetch-d']) {
    console.log(`  ${probe}: ${(fallback[probe] ?? ['?']).join(', ')}`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
