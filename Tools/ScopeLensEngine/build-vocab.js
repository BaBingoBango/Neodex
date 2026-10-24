#!/usr/bin/env node
// Builds Engine/data/vocab.json — the closed vocabularies the m4 BattleState
// parser snaps OCR'd narration/chip text against (spec §4.4 step 4).
//
//   node build-vocab.js
//
// Sources: @pkmn/dex (pinned devDependency) + data/champions-overrides.json
// (hand-curated Champions deltas, e.g. Staraptite/Mega Staraptor).
//
// Contents:
//   species        [{name, display, types}]  — display = in-narration name
//                  (base forme: Rotom-Wash shows as "Rotom")
//   moves          [string]                  — all snap-legal move names
//   abilities      [string]
//   items          [string]
//   signatureMoves {move: species}           — moves with exactly ONE base-
//                  species learner; lets the reconciler resolve a nicknamed
//                  opponent from a move ("Matcha Gotcha" ⇒ Sinistcha).
//
// Deliberately broad (all gens, megas included): a slightly over-wide closed
// vocab only costs fuzzy-match candidates, while a missing entry silently
// drops a real event. CAP/Custom fakemons and Z/Max moves are excluded.

const fs = require('fs');
const path = require('path');
const {Dex} = require('@pkmn/dex');

const overrides = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'data', 'champions-overrides.json'), 'utf8'));

const drop = (x) => x.isNonstandard === 'CAP' || x.isNonstandard === 'Custom';

async function main() {
  // ---- species ----------------------------------------------------------
  const species = [];
  for (const s of Dex.species.all()) {
    if (drop(s) || s.num <= 0) continue;
    species.push({name: s.name, display: s.baseSpecies, types: s.types});
  }
  for (const o of overrides.species ?? []) {
    if (!species.some((s) => s.name === o.name)) {
      species.push({name: o.name, display: o.display ?? o.name, types: o.types ?? []});
    }
  }

  // ---- moves / abilities / items ----------------------------------------
  const moves = Dex.moves.all()
    .filter((m) => !drop(m) && !m.isZ && !m.isMax)
    .map((m) => m.name);
  moves.push(...(overrides.moves ?? []).map((m) => m.name));

  const abilities = Dex.abilities.all()
    .filter((a) => !drop(a) && a.name !== 'No Ability')
    .map((a) => a.name);
  abilities.push(...(overrides.abilities ?? []).map((a) => a.name));

  const items = Dex.items.all().filter((i) => !drop(i)).map((i) => i.name);
  items.push(...(overrides.items ?? []).map((i) => i.name));

  // ---- signature moves ----------------------------------------------------
  // Invert learnsets: move → set of BASE species that learn it. Exactly one
  // learner ⇒ signature. Formes collapse to their base (a nickname can only
  // hide the display name, and the display name is the base species).
  const learners = new Map(); // moveId -> Set<baseSpecies>
  for (const s of Dex.species.all()) {
    if (drop(s) || s.num <= 0) continue;
    const l = await Dex.learnsets.get(s.id);
    if (!l?.learnset) continue;
    for (const moveId of Object.keys(l.learnset)) {
      if (!learners.has(moveId)) learners.set(moveId, new Set());
      learners.get(moveId).add(s.baseSpecies);
    }
  }
  const signatureMoves = {};
  for (const [moveId, who] of [...learners.entries()].sort()) {
    if (who.size !== 1) continue;
    const move = Dex.moves.get(moveId);
    if (!move.exists || drop(move) || move.isZ || move.isMax) continue;
    signatureMoves[move.name] = [...who][0];
  }

  const vocab = {
    _source: `@pkmn/dex ${require('@pkmn/dex/package.json').version} + champions-overrides.json`,
    species: species.sort((a, b) => a.name.localeCompare(b.name)),
    moves: [...new Set(moves)].sort(),
    abilities: [...new Set(abilities)].sort(),
    items: [...new Set(items)].sort(),
    signatureMoves,
  };

  const out = path.join(__dirname, 'data', 'vocab.json');
  fs.writeFileSync(out, JSON.stringify(vocab, null, 1));
  console.log(`wrote ${out}`);
  console.log(`  species ${vocab.species.length} · moves ${vocab.moves.length}` +
    ` · abilities ${vocab.abilities.length} · items ${vocab.items.length}` +
    ` · signature moves ${Object.keys(signatureMoves).length}`);
  for (const probe of ['Matcha Gotcha', 'Thousand Arrows']) {
    console.log(`  signature probe: ${probe} → ${signatureMoves[probe] ?? 'NOT SIGNATURE'}`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
