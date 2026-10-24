#!/usr/bin/env node
// Builds Engine/data/dex-info.json — plain-English effect text + per-move
// mechanical facts for the Opponent Dossier (m12-C): the "what does Armor
// Tail do again?" lookup, answered from bundled data instead of a browser.
//
//   node build-dex-info.js
//
// Source: @pkmn/dex (pinned devDependency — the same package build-vocab.js
// and build-learnset-fallback.js already bake from). Scoped to the closed
// vocab (data/vocab.json): exactly the names OCR snapping / meta profiles can
// ever surface, so every lookup either hits or is a genuinely unknown name.
//
// Shape (keys are engine.ts slugs — lookups must match slugify exactly):
//   moves     {slug: {name, type, category, basePower, accuracy, priority, shortDesc}}
//   abilities {slug: {name, shortDesc}}
//   items     {slug: {name, shortDesc}}
//
// Gotcha: @pkmn/dex uses accuracy === true for never-miss moves (Aura
// Sphere) — emitted as null so consumers render "—" instead of "true%".

const fs = require('fs');
const path = require('path');
const {Dex} = require('@pkmn/dex');

// EXACTLY engine.ts's slugify — these keys are looked up by that function.
const slugify = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-');

const vocab = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'data', 'vocab.json'), 'utf8'));

// Sorted-key object for a stable, diffable committed file.
const sorted = (entries) => Object.fromEntries(
  [...entries].sort((a, b) => a[0].localeCompare(b[0])));

function bake(names, lookup, shape) {
  const out = new Map();
  let missing = 0;
  for (const name of names) {
    const hit = lookup(name);
    if (!hit || !hit.exists) { missing++; continue; }  // champions-overrides entries
    const slug = slugify(name);
    const entry = shape(hit);
    const prior = out.get(slug);
    if (prior && JSON.stringify(prior) !== JSON.stringify(entry)) {
      console.warn(`  ⚠️ slug collision: ${slug} (${prior.name} vs ${entry.name})`);
    }
    out.set(slug, entry);
  }
  return {table: sorted(out.entries()), missing};
}

const short = (x) => x.shortDesc || x.desc || '';

const moves = bake(vocab.moves, (n) => Dex.moves.get(n), (m) => ({
  name: m.name,
  type: m.type,
  category: m.category,
  basePower: m.basePower,
  accuracy: m.accuracy === true ? null : m.accuracy,
  priority: m.priority,
  shortDesc: short(m),
}));
const abilities = bake(vocab.abilities, (n) => Dex.abilities.get(n), (a) => ({
  name: a.name,
  shortDesc: short(a),
}));
const items = bake(vocab.items, (n) => Dex.items.get(n), (i) => ({
  name: i.name,
  shortDesc: short(i),
}));

const dexInfo = {
  _source: `@pkmn/dex ${require('@pkmn/dex/package.json').version}, scoped to vocab.json`,
  moves: moves.table,
  abilities: abilities.table,
  items: items.table,
};

const out = path.join(__dirname, 'data', 'dex-info.json');
fs.writeFileSync(out, JSON.stringify(dexInfo, null, 1));
console.log(`wrote ${out}`);
console.log(`  moves ${Object.keys(moves.table).length} (${moves.missing} not in dex)` +
  ` · abilities ${Object.keys(abilities.table).length} (${abilities.missing})` +
  ` · items ${Object.keys(items.table).length} (${items.missing})`);
for (const [kind, table, probe] of [
  ['move', moves.table, 'fake-out'],
  ['ability', abilities.table, 'armor-tail'],
  ['item', items.table, 'life-orb'],
  ['never-miss accuracy', moves.table, 'aura-sphere'],
]) {
  const e = table[probe];
  console.log(`  probe ${kind}: ${probe} → ${e ? JSON.stringify(e).slice(0, 110) : 'MISSING'}`);
}
