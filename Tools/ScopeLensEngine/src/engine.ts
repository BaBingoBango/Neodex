// ScopeLens deterministic engine — type math, meta priors, damage rolls, and
// the team-preview scout report. Pure functions; bundled into a single IIFE
// (global `ScopeEngine`) and executed inside JavaScriptCore by the app.
import {calculate, Generations, Pokemon, Move, Field} from '@smogon/calc';
import metaJSON from '../data/meta-regmbs3.json';
import learnsetFallbackJSON from '../data/learnset-fallback.json';
import dexInfoJSON from '../data/dex-info.json';

const gen = Generations.get(9);
// Baked snapshot is the fallback; hosts may inject a fresher snapshot at
// runtime via setMeta (the app loads a bundled/updatable data file), so a
// meta refresh is a JSON swap — no engine rebuild.
let metaStore: Record<string, any> = metaJSON as any;

const slugify = (name: string) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-');

export function setMeta(json: Record<string, any> | null | undefined): void {
  if (json && Object.keys(json).length) metaStore = json;
}

export function metaProfile(species: string): any | null {
  return metaStore[slugify(species)] ?? null;
}

// ---- type math ----------------------------------------------------------
export function typeEffect(moveType: string, defenderTypes: string[]): number {
  let mult = 1;
  const t = gen.types.get(moveType.toLowerCase() as any);
  if (!t) return 1;
  for (const d of defenderTypes) {
    const eff = (t.effectiveness as any)[d];
    if (eff !== undefined) mult *= eff;
  }
  return mult;
}

// ---- dex effect info (m12-C) ----------------------------------------------
// Plain-English effect text + per-move mechanical facts for the Opponent
// Dossier: the "what does Armor Tail do again?" lookup answered from bundled
// data (baked by build-dex-info.js, scoped to the closed vocab). Unknown
// names come back {name, known:false} so consumers degrade gracefully.
export function dexInfo(input: {moves?: string[]; abilities?: string[];
                                items?: string[]}): any {
  const d = dexInfoJSON as any;
  const look = (table: Record<string, any>, names?: string[]) =>
    (names ?? []).map(n => {
      const hit = table[slugify(n)];
      return hit ? {...hit, known: true} : {name: n, known: false};
    });
  return {
    moves: look(d.moves, input.moves),
    abilities: look(d.abilities, input.abilities),
    items: look(d.items, input.items),
  };
}

// ---- advisor capsule facts (m11) -----------------------------------------
// Speed BRACKETS instead of point estimates: the honest range an opponent's
// speed can occupy at level 50 — 0-EV neutral floor to 252-EV +nature
// ceiling. The advisor reasons "outspeeds if invested" rather than trusting
// a false-precision single number.
export function speedBrackets(speciesList: string[]): any[] {
  const out: any[] = [];
  for (const species of speciesList) {
    try {
      const floor = new Pokemon(gen, species as any, {level: 50, evs: {}});
      // +Spe nature with max investment (Timid is representative: +Spe).
      const ceil = new Pokemon(gen, species as any,
                               {level: 50, evs: {spe: 252}, nature: 'Timid'});
      const row: any = {species, min: floor.stats.spe, max: ceil.stats.spe};
      // m15-D: the MODAL point — what the ladder actually runs (top spread
      // × top nature), the honest single number between floor and ceiling.
      const modal = modalSpread(species);
      if (modal) {
        try {
          const mon = new Pokemon(gen, species as any, {
            level: 50, evs: {spe: modal.evs.spe ?? 0},
            nature: (modal.nature ?? 'Hardy') as any,
          });
          row.modal = mon.stats.spe;
          row.modalPct = modal.pct;
        } catch { /* nature/species unknown to calc — bracket only */ }
      }
      out.push(row);
    } catch { /* unknown to the dex (Champions forme) — omit; caller degrades */ }
  }
  return out;
}

// Defensive profile of a typing: which attacking types hit it for 4×/2×/½/¼/0.
// One call replaces 18 typeEffect round-trips through the JSC bridge.
const ALL_TYPES = ['Normal', 'Fire', 'Water', 'Electric', 'Grass', 'Ice',
  'Fighting', 'Poison', 'Ground', 'Flying', 'Psychic', 'Bug', 'Rock', 'Ghost',
  'Dragon', 'Dark', 'Steel', 'Fairy'];

export function defensiveProfile(defenderTypes: string[]): any {
  const out: Record<string, string[]> =
    {x4: [], x2: [], x05: [], x025: [], x0: []};
  for (const t of ALL_TYPES) {
    const m = typeEffect(t, defenderTypes);
    if (m >= 4) out.x4.push(t);
    else if (m >= 2) out.x2.push(t);
    else if (m === 0) out.x0.push(t);
    else if (m <= 0.25) out.x025.push(t);
    else if (m <= 0.5) out.x05.push(t);
  }
  return out;
}

// ---- damage --------------------------------------------------------------
export interface MonSpec {
  species: string;
  item?: string;
  ability?: string;
  moves?: string[];       // known moves; otherwise meta top-4 assumed
  assumed?: boolean;      // true when the set came from priors, not observation
  setSource?: 'observed' | 'usage' | 'learnset' | 'none';
  // m15-D: where the spread came from — configured (your team, verbatim),
  // modal (top ladder spread × top nature), or generic (synthetic 252s).
  spreadSource?: 'configured' | 'modal' | 'generic';
  // Real spread (m9 team management) — used verbatim when present; the
  // synthetic 252-offense/252-HP defaults otherwise. teraType is carried for
  // the data model but NOT applied to calcs (no live tera tracking yet).
  evs?: Partial<Record<'hp' | 'atk' | 'def' | 'spa' | 'spd' | 'spe', number>>;
  ivs?: Partial<Record<'hp' | 'atk' | 'def' | 'spa' | 'spd' | 'spe', number>>;
  nature?: string;
  level?: number;
  teraType?: string;
  // Live-battle extras (m7 liveMatchup; ignored by the scout report):
  boosts?: Record<string, number>;   // observed stat stages (-6…+6)
  curPct?: number;                   // current HP % (KO-now detection)
  status?: string;                   // brn | par | psn | slp | frz
}

// Mega stones auto-resolve to the mega forme for calculation.
function calcSpecies(spec: MonSpec): string {
  const it = spec.item ?? '';
  if (/^(\w[\w' .:-]*)ite Y$/.test(it)) return `${spec.species}-Mega-Y`;
  if (/^(\w[\w' .:-]*)ite X$/.test(it)) return `${spec.species}-Mega-X`;
  if (/ite$/.test(it) && !/Eviolite/.test(it)) {
    try { new Pokemon(gen, `${spec.species}-Mega` as any); return `${spec.species}-Mega`; } catch { /* no mega */ }
  }
  return spec.species;
}

function topMetaMoves(species: string, n = 4): string[] {
  const p = metaProfile(species);
  if (!p) return [];
  return Object.entries(p.moves as Record<string, number>)
    .sort((a, b) => b[1] - a[1]).slice(0, n).map(e => e[0]);
}
function topMetaItem(species: string): string | undefined {
  return topMetaItems(species, 1)[0];
}
function topMetaItems(species: string, n: number): string[] {
  const p = metaProfile(species);
  if (!p) return [];
  return Object.entries(p.items as Record<string, number>)
    .sort((a, b) => b[1] - a[1]).slice(0, n).map(e => e[0]);
}
function topMetaAbility(species: string): string | undefined {
  const p = metaProfile(species);
  if (!p) return undefined;
  const ab = Object.entries(p.abilities as Record<string, number>).sort((a, b) => b[1] - a[1]);
  return ab[0]?.[0];
}

// m15-D: the MODAL ladder set — top usage spread + top nature. Spreads are
// CHAMPIONS-NATIVE points ("HP/Atk/Def/SpA/SpD/Spe", 0–32 per stat, ~66
// total; 1 point = +1 stat at L50), converted to mainline EVs as pts×8
// (clamped 252 — a 32-point stat computes 1 lower than the game's true +32;
// accepted, documented). Natures are a separate distribution on the page,
// so top-spread × top-nature approximates the modal set.
const STAT_KEYS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'] as const;
function modalSpread(species: string):
    {evs: Partial<Record<typeof STAT_KEYS[number], number>>;
     nature?: string; pct: number} | null {
  const p = metaProfile(species);
  if (!p || !p.spreads) return null;
  const top = Object.entries(p.spreads as Record<string, number>)
    .sort((a, b) => b[1] - a[1])[0];
  if (!top) return null;
  const points = top[0].split('/').map(Number);
  if (points.length !== 6 || points.some(isNaN)) return null;
  const evs: Partial<Record<typeof STAT_KEYS[number], number>> = {};
  STAT_KEYS.forEach((k, i) => { if (points[i] > 0) evs[k] = Math.min(252, points[i] * 8); });
  const nature = p.natures
    ? Object.entries(p.natures as Record<string, number>)
        .sort((a, b) => b[1] - a[1])[0]?.[0]
    : undefined;
  return {evs, nature, pct: top[1]};
}

// True off-ladder species (no usage entry) get plausible STAB movesets from
// their learnset (m4 task C) so the report degrades gracefully instead of
// contributing zero threats. Labeled guesses: setSource = 'learnset'.
function learnsetFallbackMoves(species: string): string[] {
  return (learnsetFallbackJSON as Record<string, string[]>)[slugify(species)] ?? [];
}

export function resolveSet(spec: MonSpec): MonSpec {
  const observed = !!(spec.moves && spec.moves.length);
  const metaMoves = observed ? [] : topMetaMoves(spec.species);
  const learnset = observed || metaMoves.length ? [] : learnsetFallbackMoves(spec.species);
  // m15-D: unconfigured spreads fill from the MODAL ladder set — the
  // 0-EV/generic-252 era estimated the pilot's Solar Beam killer 20+
  // points slower than the ladder actually runs it. Configured spreads
  // (your team, m9) always win.
  const modal = spec.evs || spec.nature ? null : modalSpread(spec.species);
  return {
    ...spec, // carries ivs/level/teraType + live extras through
    item: spec.item ?? topMetaItem(spec.species),
    ability: spec.ability ?? topMetaAbility(spec.species),
    moves: observed ? spec.moves! : metaMoves.length ? metaMoves : learnset,
    evs: spec.evs ?? modal?.evs,
    nature: spec.nature ?? modal?.nature,
    spreadSource: spec.evs ? 'configured' : modal ? 'modal' : 'generic',
    assumed: !observed,
    setSource: observed ? 'observed' : metaMoves.length ? 'usage'
      : learnset.length ? 'learnset' : 'none',
  };
}

// Assumptions (labeled in the report): level 50, 252 EVs in the used offense,
// defender 252 HP / 0 defenses, neutral natures, Doubles. Sun if a Charizardite Y
// is on the field (Champions' dominant Charizard set).
function makeField(all: MonSpec[]): Field {
  const sun = all.some(m => (m.item ?? '') === 'Charizardite Y');
  return new Field({gameType: 'Doubles', weather: sun ? 'Sun' : undefined});
}

export interface Threat { move: string; minPct: number; maxPct: number; effect: number }

export function bestThreat(attacker: MonSpec, defender: MonSpec, field: Field): Threat | null {
  const a = resolveSet(attacker), d = resolveSet(defender);
  let best: Threat | null = null;
  for (const mv of a.moves ?? []) {
    try {
      const move = new Move(gen, mv);
      if (move.category === 'Status') continue;
      // Real spread verbatim when configured (m9); synthetic 252s otherwise.
      // Defender item/ability now also apply (AV/Levitate-class effects),
      // which is what the assumptions footer always claimed.
      const offensive = move.category === 'Physical' ? 'atk' : 'spa';
      // m15-D: modal attackers floor the used offense at 252 (pessimistic
      // incoming damage, same doctrine as livePokemon).
      const atkEvs = (() => {
        const base = a.evs ?? {[offensive]: 252};
        return a.spreadSource === 'modal'
          ? {...base, [offensive]: Math.max((base as any)[offensive] ?? 0, 252)}
          : base;
      })();
      const atk = new Pokemon(gen, calcSpecies(a) as any, {
        level: a.level ?? 50, item: a.item, ability: a.ability,
        nature: a.nature as any, ivs: a.ivs,
        evs: atkEvs,
      });
      const def = new Pokemon(gen, calcSpecies(d) as any, {
        level: d.level ?? 50, item: d.item, ability: d.ability,
        nature: d.nature as any, ivs: d.ivs,
        evs: d.evs ?? {hp: 252},
      });
      const res = calculate(gen, atk, def, move, field);
      const range = res.range();
      const maxHP = def.maxHP();
      const t: Threat = {
        move: mv,
        minPct: Math.round(1000 * range[0] / maxHP) / 10,
        maxPct: Math.round(1000 * range[1] / maxHP) / 10,
        effect: typeEffect(move.type, def.types as any),
      };
      if (!best || t.maxPct > best.maxPct) best = t;
    } catch { /* unknown move/species for calc — skip */ }
  }
  return best;
}

// ---- scout report ---------------------------------------------------------
export function scoutReport(mineIn: MonSpec[], theirsIn: MonSpec[]): any {
  const field = makeField([...mineIn, ...theirsIn]);
  const mine = mineIn.map(resolveSet);
  const theirs = theirsIn.map(resolveSet);

  // full matrices
  const incoming: (Threat | null)[][] = theirs.map(t => mine.map(m => bestThreat(t, m, field)));
  const outgoing: (Threat | null)[][] = mine.map(m => theirs.map(t => bestThreat(m, t, field)));

  // per-my-mon score: how well it trades across their team
  const scores = mine.map((m, mi) => {
    let s = 0;
    for (let ti = 0; ti < theirs.length; ti++) {
      const out = outgoing[mi][ti], inc = incoming[ti][mi];
      s += (out ? Math.min(out.maxPct, 120) : 0) - (inc ? Math.min(inc.maxPct, 120) : 0);
    }
    return s / theirs.length;
  });
  const order = scores.map((s, i) => [s, i] as [number, number]).sort((a, b) => b[0] - a[0]);
  const safeFour = order.slice(0, 4).map(e => mine[e[1]].species);
  const leads = order.slice(0, 2).map(e => mine[e[1]].species);

  // markdown
  const L: string[] = [];
  L.push(`# ScopeLens Scout Report`);
  L.push(``);
  L.push(`## Opponent`);
  for (const t of theirs) {
    const p = metaProfile(t.species);
    const mv = (t.moves ?? []).map(m => {
      const pct = p?.moves?.[m];
      return pct ? `${m} (${pct}%)` : m;
    }).join(', ');
    const tag = p ? '' : t.setSource === 'learnset'
      ? ' *(no usage data — learnset guess)*' : ' *(no meta data)*';
    L.push(`- **${t.species}**${t.item ? ` @ ${t.item}` : ''}${t.ability ? ` — ${t.ability}` : ''}${tag}`);
    L.push(`  - likely moves: ${mv || 'unknown'}`);
  }
  L.push(``);
  L.push(`## Biggest threats to you`);
  const flat: {t: string, m: string, thr: Threat}[] = [];
  theirs.forEach((t, ti) => mine.forEach((m, mi) => {
    const thr = incoming[ti][mi];
    if (thr) flat.push({t: t.species, m: m.species, thr});
  }));
  flat.sort((a, b) => b.thr.maxPct - a.thr.maxPct);
  for (const f of flat.slice(0, 6)) {
    const ko = f.thr.maxPct >= 100 ? ' — **KO range**' : '';
    L.push(`- ${f.t}'s **${f.thr.move}** vs ${f.m}: ${f.thr.minPct}–${f.thr.maxPct}%${ko}`);
  }
  L.push(``);
  L.push(`## Your best answers`);
  mine.forEach((m, mi) => {
    let bi = -1, bv = -1;
    theirs.forEach((t, ti) => {
      const o = outgoing[mi][ti];
      if (o && o.maxPct > bv) { bv = o.maxPct; bi = ti; }
    });
    if (bi >= 0) {
      const o = outgoing[mi][bi]!;
      L.push(`- ${m.species}: **${o.move}** vs ${theirs[bi].species} for ${o.minPct}–${o.maxPct}%`);
    }
  });
  L.push(``);
  L.push(`## Suggested bring 4 (heuristic)`);
  L.push(`**${safeFour.join(', ')}** — leads: **${leads.join(' + ')}**`);
  L.push(``);
  L.push(`*Assumptions: level 50 doubles; mons with configured spreads use their real EVs/IVs/natures, others use the MODAL ladder spread + nature from usage data (252-offense/252-HP synthetics only off-ladder); sets marked (…%) are meta priors from Reg M-B S3 usage${field.weather === 'Sun' ? '; sun assumed (Charizardite Y on the field)' : ''}. Opponent items/abilities are the most common from usage data, not observations.*`);

  return {safeFour, leads, markdown: L.join('\n')};
}

// ---- live matchup (Phase 3, m7) -------------------------------------------
// The in-battle deterministic advisor: given the CURRENT actives (with
// everything the reconciler observed — revealed moves, items, abilities,
// boosts, status, current HP) and the live field, compute damage both ways
// plus a speed order. Unknown Champions megas (Scrafty-Mega, Staraptor-Mega)
// fall back to their base forme's stats, flagged approx.

interface LiveFieldSpec {
  weather?: string;                   // sun | rain | sand | snow | none
  trickRoom?: boolean;
  tailwindYou?: boolean;
  tailwindOpp?: boolean;
  screensYou?: string[];              // Light Screen / Reflect / Aurora Veil
  screensOpp?: string[];
}

const weatherMap: Record<string, string> = {
  sun: 'Sun', rain: 'Rain', sand: 'Sand', snow: 'Snow',
};

// A Pokemon for the live calc: observed boosts/status applied; Champions-only
// formes retry as their base species.
function livePokemon(spec: MonSpec, offensive: 'atk' | 'spa' | null):
    {mon: Pokemon; approx: boolean} | null {
  const options = (species: string) => ({
    level: spec.level ?? 50,
    item: spec.item,
    ability: spec.ability,
    nature: spec.nature as any,
    ivs: spec.ivs,
    // Real spread when configured (m9); MODAL ladder spread otherwise
    // (m15-D) — except a modal ATTACKER's used offense floors at 252:
    // incoming damage stays PESSIMISTIC (a missed doomed-slot flag loses
    // games; modal bulk/speed stay the calibrated estimates). Synthetic
    // single-stat 252s only for off-ladder species.
    evs: (() => {
      const base = spec.evs ?? (offensive ? {[offensive]: 252} : {hp: 252});
      if (offensive && spec.spreadSource === 'modal') {
        return {...base, [offensive]: Math.max(base[offensive] ?? 0, 252)};
      }
      return base;
    })(),
    boosts: spec.boosts ?? {},
    status: (spec.status ?? '') as any,
  });
  for (const [species, approx] of [[calcSpecies(spec), false],
                                   [spec.species, false],
                                   [spec.species.replace(/-Mega(-[XY])?$/, ''), true]] as const) {
    try { return {mon: new Pokemon(gen, species as any, options(species)), approx}; }
    catch { /* try the next form */ }
  }
  return null;
}

function sideScreens(names: string[] | undefined) {
  const s = names ?? [];
  return {
    isReflect: s.includes('Reflect'),
    isLightScreen: s.includes('Light Screen'),
    isAuroraVeil: s.includes('Aurora Veil'),
  };
}

export function liveMatchup(mineIn: MonSpec[], theirsIn: MonSpec[],
                            fieldSpec: LiveFieldSpec): any {
  const mine = mineIn.map(resolveSet).map((r, i) => ({...mineIn[i], ...r}));
  const theirs = theirsIn.map(resolveSet).map((r, i) => ({...theirsIn[i], ...r}));

  function threats(attackers: MonSpec[], defenders: MonSpec[],
                   dir: 'incoming' | 'outgoing') {
    // Screens protect the DEFENDER's side.
    const defenderScreens = sideScreens(dir === 'incoming' ? fieldSpec.screensYou
                                                           : fieldSpec.screensOpp);
    const field = new Field({
      gameType: 'Doubles',
      weather: weatherMap[fieldSpec.weather ?? ''] as any,
      defenderSide: defenderScreens as any,
    });
    const out: any[] = [];
    for (const a of attackers) {
      for (const d of defenders) {
        let best: any = null;
        let approxPair = false;
        for (const mv of a.moves ?? []) {
          try {
            const move = new Move(gen, mv);
            if (move.category === 'Status') continue;
            const atkBuilt = livePokemon(a, move.category === 'Physical' ? 'atk' : 'spa');
            const defBuilt = livePokemon(d, null);
            if (!atkBuilt || !defBuilt) continue;
            approxPair = atkBuilt.approx || defBuilt.approx;
            const res = calculate(gen, atkBuilt.mon, defBuilt.mon, move, field);
            const range = res.range();
            const maxHP = defBuilt.mon.maxHP();
            const minPct = Math.round(1000 * range[0] / maxHP) / 10;
            const maxPct = Math.round(1000 * range[1] / maxHP) / 10;
            if (!best || maxPct > best.maxPct) {
              best = {move: mv, minPct, maxPct};
            }
          } catch { /* unknown move for calc — skip */ }
        }
        if (best) {
          const defCur = d.curPct ?? 100;
          out.push({
            attacker: a.species, defender: d.species, dir,
            move: best.move, minPct: best.minPct, maxPct: best.maxPct,
            koNow: best.maxPct >= defCur,        // max roll clears CURRENT HP
            guaranteedKo: best.minPct >= defCur, // min roll clears it
            setSource: a.setSource ?? 'none',
            approx: approxPair,
          });
        }
      }
    }
    return out.sort((x, y) => y.maxPct - x.maxPct);
  }

  // Speed order under the live field (Tailwind doubles; Trick Room reverses —
  // reported, and the order array is pre-sorted accordingly).
  const speeds = [...mine.map(m => ({m, side: 'you'})), ...theirs.map(m => ({m, side: 'opp'}))]
    .map(({m, side}) => {
      const built = livePokemon(m, null);
      if (!built) return null;
      let spe = built.mon.stats.spe;
      const stage = m.boosts?.spe ?? 0;
      spe = Math.floor(spe * (stage >= 0 ? (2 + stage) / 2 : 2 / (2 - stage)));
      if (m.status === 'par') spe = Math.floor(spe / 2);
      if (side === 'you' ? fieldSpec.tailwindYou : fieldSpec.tailwindOpp) spe *= 2;
      return {species: m.species, side, spe, approx: built.approx};
    })
    .filter(Boolean) as any[];
  speeds.sort((a, b) => fieldSpec.trickRoom ? a.spe - b.spe : b.spe - a.spe);

  return {
    incoming: threats(theirs, mine, 'incoming'),
    outgoing: threats(mine, theirs, 'outgoing'),
    speeds,
    trickRoom: !!fieldSpec.trickRoom,
    assumptions: 'Level 50; configured EVs/natures where set (your team), else ' +
      'the MODAL ladder spread + nature from usage data — with a modal ' +
      "ATTACKER's used offense floored at 252 (incoming damage stays " +
      'pessimistic), else 252 in the used offense vs 252 HP; ' +
      'observed moves/items/abilities/boosts/status where known, priors otherwise; ' +
      'speeds use configured spreads where set, modal ladder spreads otherwise ' +
      '(0-EV floor only for off-ladder species). ' +
      'KO flags compare against current HP.',
  };
}

// ---- reverse damage inference (m12-B) --------------------------------------
// A landed move's observed damage constrains the attacker's investment and
// item — information nobody extracts under a move timer. Test a hypothesis
// grid ({0/128/252 EVs} × {neutral/+nature} × {none/Life Orb/Choice/top meta
// items}) against the observed HP-point damage and report which combinations
// are CONSISTENT with the roll. Honest ranges, never point estimates.
//
// v1 scope (the brief's honesty rules): single-target moves only (spread
// modifiers are per-target-unknown), non-crit (caller gates), OUR side as
// defender (exact plate HP ⇒ damage in HP POINTS, which sidesteps the
// defender's unknown HP EVs entirely — points depend only on Def/SpD).

const SPREAD_TARGETS = new Set(['allAdjacentFoes', 'allAdjacent']);

export function inferAttack(input: {
  attacker: string;                    // calc species (mega-resolved ok)
  move: string;
  defender: MonSpec;                   // our mon — configured spread + observed extras
  field?: LiveFieldSpec;
  observedDamage: number;              // HP points lost (exact plates)
  tolerance?: number;                  // HP points (default ±1 for read/roll rounding)
  attackerBoosts?: Record<string, number>;  // attacker stages when the hit landed
  mega?: boolean;                      // mega ⇒ item slot is the stone: no item grid
}): any {
  let move: Move;
  try { move = new Move(gen, input.move); } catch {
    return {skipped: `unknown move ${input.move}`};
  }
  if (move.category === 'Status') return {skipped: 'status move'};
  if (SPREAD_TARGETS.has((move as any).target)) {
    return {skipped: 'spread move (per-target modifier unknown)'};
  }
  const defBuilt = livePokemon(input.defender, null);
  if (!defBuilt) return {skipped: `defender ${input.defender.species} unknown to the calc`};

  const physical = move.category === 'Physical';
  const stat = physical ? 'atk' : 'spa';
  const statName = physical ? 'Atk' : 'SpA';
  const plusNature = physical ? 'Adamant' : 'Modest';
  const isMega = input.mega || /-Mega(-[XY])?$/.test(input.attacker);
  const base = input.attacker.replace(/-Mega(-[XY])?$/, '');
  // Mega item slot is the stone; otherwise the classic boosters + whatever
  // the meta actually runs (non-damage items collapse into "no item" via
  // the range dedup below).
  const items: (string | undefined)[] = isMega ? [undefined]
    : [undefined, 'Life Orb', physical ? 'Choice Band' : 'Choice Specs'];
  if (!isMega) {
    for (const it of topMetaItems(base, 2)) if (!items.includes(it)) items.push(it);
  }
  const ability = isMega ? undefined : topMetaAbility(base);
  const fieldSpec = input.field ?? ({} as LiveFieldSpec);
  const field = new Field({
    gameType: 'Doubles',
    weather: weatherMap[fieldSpec.weather ?? ''] as any,
    defenderSide: sideScreens(fieldSpec.screensYou) as any,  // defender = our side (v1)
  });
  const observed = input.observedDamage;
  const tol = input.tolerance ?? 1;
  const boosts = input.attackerBoosts ?? {};

  const hypotheses: any[] = [];
  const seenRange = new Set<string>();
  for (const evs of [0, 128, 252]) {
    for (const nature of ['Hardy', plusNature]) {
      for (const item of items) {
        let range: [number, number] | null = null;
        for (const species of [input.attacker, base]) {
          try {
            const atk = new Pokemon(gen, species as any, {
              level: 50, evs: {[stat]: evs}, nature: nature as any,
              item, ability, boosts,
            });
            range = calculate(gen, atk, defBuilt.mon, move, field).range();
            break;
          } catch { /* unknown forme — try the base */ }
        }
        if (!range) continue;
        const key = `${evs}|${nature}|${range[0]}|${range[1]}`;
        if (seenRange.has(key)) continue;   // item didn't change damage — merge
        seenRange.add(key);
        hypotheses.push({
          evs, nature: nature === plusNature ? 'positive' : 'neutral',
          item: item ?? null, min: range[0], max: range[1],
          consistent: observed >= range[0] - tol && observed <= range[1] + tol,
        });
      }
    }
  }
  if (!hypotheses.length) {
    return {skipped: `attacker ${input.attacker} unknown to the calc`};
  }

  const consistent = hypotheses.filter(h => h.consistent);
  const boostStage = boosts[stat] ?? 0;
  const boostNote = boostStage !== 0
    ? ` (at ${statName}${boostStage > 0 ? '+' : ''}${boostStage})` : '';
  let summary: string;
  if (!consistent.length) {
    summary = `no tested set reproduces ${observed} HP — screens/tera/ability may be unaccounted`;
  } else {
    const byItem = new Map<string, any[]>();
    for (const h of consistent) {
      const k = h.item ?? 'no item';
      if (!byItem.has(k)) byItem.set(k, []);
      byItem.get(k)!.push(h);
    }
    const parts: string[] = [];
    for (const [item, hs] of byItem) {
      const minEvs = Math.min(...hs.map(h => h.evs));
      const plusOnly = !hs.some(h => h.evs === minEvs && h.nature === 'neutral');
      parts.push(`${item} (≥${minEvs}${plusOnly ? '+' : ''} ${statName})`);
    }
    summary = byItem.has('no item')
      ? parts.join(', ')
      : `item boost implied — ${parts.join(', or ')}`;
    if (consistent.length === hypotheses.length) summary = `weak signal: ${summary}`;
    summary += boostNote;
  }

  return {
    attacker: input.attacker, move: input.move,
    defender: input.defender.species,
    observedDamage: observed, tolerance: tol,
    attackerBoosts: boosts,
    // Inconclusive (nothing consistent) usually means the observation was
    // tainted — a partial animation tail, an unmodeled mechanic — so
    // consumers should stay SILENT rather than surface "no set matches"
    // as if it were intel.
    conclusive: consistent.length > 0,
    hypotheses, summary,
    assumptions: 'level 50 doubles; defender from the configured team (synthetic '
      + 'spreads where unset); attacker ability = usage default; non-crit, '
      + 'single-target only',
  };
}

// Structured twin of scoutReport for native UI rendering (Phase 2 m3b).
// Same math, same assumptions — data instead of markdown. scoutReport stays
// untouched for the diagnostic CLI.
export function scoutReportData(mineIn: MonSpec[], theirsIn: MonSpec[]): any {
  const field = makeField([...mineIn, ...theirsIn]);
  const mine = mineIn.map(resolveSet);
  const theirs = theirsIn.map(resolveSet);

  const incoming: (Threat | null)[][] = theirs.map(t => mine.map(m => bestThreat(t, m, field)));
  const outgoing: (Threat | null)[][] = mine.map(m => theirs.map(t => bestThreat(m, t, field)));

  const scores = mine.map((m, mi) => {
    let s = 0;
    for (let ti = 0; ti < theirs.length; ti++) {
      const out = outgoing[mi][ti], inc = incoming[ti][mi];
      s += (out ? Math.min(out.maxPct, 120) : 0) - (inc ? Math.min(inc.maxPct, 120) : 0);
    }
    return s / theirs.length;
  });
  const order = scores.map((s, i) => [s, i] as [number, number]).sort((a, b) => b[0] - a[0]);
  const safeFour = order.slice(0, 4).map(e => mine[e[1]].species);
  const leads = order.slice(0, 2).map(e => mine[e[1]].species);

  const opponents = theirs.map(t => {
    const p = metaProfile(t.species);
    return {
      species: t.species,
      item: t.item ?? null,
      ability: t.ability ?? null,
      assumed: t.assumed ?? false,
      hasMeta: !!p,
      setSource: t.setSource ?? 'none',
      moves: (t.moves ?? []).map(m => ({name: m, pct: p?.moves?.[m] ?? null})),
    };
  });

  const threats: any[] = [];
  theirs.forEach((t, ti) => mine.forEach((m, mi) => {
    const thr = incoming[ti][mi];
    if (thr) threats.push({
      attacker: t.species, defender: m.species, move: thr.move,
      minPct: thr.minPct, maxPct: thr.maxPct, ko: thr.maxPct >= 100,
    });
  }));
  threats.sort((a, b) => b.maxPct - a.maxPct);

  const answers = mine.map((m, mi) => {
    let bi = -1, bv = -1;
    theirs.forEach((t, ti) => {
      const o = outgoing[mi][ti];
      if (o && o.maxPct > bv) { bv = o.maxPct; bi = ti; }
    });
    if (bi < 0) return null;
    const o = outgoing[mi][bi]!;
    return {mine: m.species, move: o.move, target: theirs[bi].species,
            minPct: o.minPct, maxPct: o.maxPct};
  }).filter(Boolean);

  const assumptions = `Level 50 doubles; configured spreads use real EVs/natures, ` +
    `others the modal ladder spread + nature (252 synthetics only off-ladder); ` +
    `moves marked with %% are Reg M-B S3 usage priors${field.weather === 'Sun' ? '; sun assumed (Charizardite Y on the field)' : ''}. ` +
    `Opponent items/abilities are the most common from usage data, not observations.`;

  return {opponents, threats: threats.slice(0, 8), answers, safeFour, leads, assumptions};
}
