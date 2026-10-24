// Snapshot Pikalytics Champions Reg M-B S3 profiles into meta JSON.
//
// Enumeration (2026-07-02): the ranked-list page lazy-loads, so the full
// species set is discovered by crawling the TEAMMATE links on each species
// page, breadth-first from the index page's server-rendered seeds — closure
// over "appears in real teams", which is exactly the scouting population.
// Politeness: 2 concurrent fetches, ~200ms spacing, hard cap as a fuse.
//
// Output keys use the engine's slugify (lowercase, non-alphanumeric → '-')
// so ScopeEngine.metaProfile lookups match. Empty profiles (unranked/404)
// are dropped to keep the engine's hasMeta flag honest.
const https = require('https'), fs = require('fs');

const INDEX = "https://www.pikalytics.com/pokedex/battledataregmbs3";
const CAP = 400;                 // fuse against runaway crawls
const CONCURRENCY = 2;
const SPACING_MS = 200;

const seeds = ["garchomp","sinistcha","basculegion","whimsicott","kingambit","staraptor",
  "incineroar","charizard","raichu","pelipper","sneasler","archaludon","grimmsnarl","sylveon",
  "swampert","metagross","farigiraf","floette-eternal","gholdengo","aerodactyl",
  "venusaur","rotom-wash","dialga","politoed","sableye","scizor","falinks",
  "mawile","ceruledge","milotic","dragonite","typhlosion-hisui"];

const engineSlug = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-');

const out = {};
const queued = new Set();       // by fetch path
const queue = [];

function enqueue(pathName) {
  // Canonicalize: strip query strings (?l=en variants), decode, engine-slug.
  const slug = engineSlug(decodeURIComponent(pathName.split('?')[0]).trim());
  if (!slug || queued.has(slug) || queued.size >= CAP) return;
  queued.add(slug);
  queue.push(slug);
}

function get(url) {
  return new Promise((resolve) => {
    https.get(url, {headers: {"User-Agent": "Mozilla/5.0 (ScopeLens meta snapshot)"}}, res => {
      let body = "";
      res.on("data", c => body += c);
      res.on("end", () => resolve(body));
    }).on("error", () => resolve(""));
  });
}

function parseProfile(name, html) {
  const grab = (re) => { const m = re.exec(html); return m ? m[1] : null; };
  const list = (txt) => {
    const o = {};
    if (!txt) return o;
    for (const m of txt.matchAll(/([A-Za-zÀ-ÿ0-9'’.: -]+?) \((\d+(?:\.\d+)?)%\)/g)) o[m[1].trim().replace(/^and /, '')] = +m[2];
    return o;
  };
  const moves = grab(/top moves for [^"]*? are ([^"]*?)\. These/);
  const items = grab(/most popular items for [^"]*? are ([^"]*?)\. The best/);
  const abilities = grab(/most common abilities for [^"]*? are ([^"]*?)\. The choice/);
  const winrate = grab(/has a (\d+(?:\.\d+)?)% winrate/);
  const profile = {winrate: winrate ? +winrate : null, moves: list(moves), items: list(items), abilities: list(abilities)};
  // m15-D: the server-rendered stat sections. Spreads are CHAMPIONS-NATIVE
  // points (0–32 per stat, ~66 total; 1 point = +1 stat at L50 ≈ 8 mainline
  // EVs), keyed "HP/Atk/Def/SpA/SpD/Spe". Natures are a SEPARATE
  // distribution (the page pairs them only client-side). Teammates are
  // RANKED, no % — kept in page order.
  const section = (id, endIds) => {
    const i = html.indexOf(`id="${id}"`);
    if (i < 0) return '';
    let end = html.length;
    for (const e of endIds) {
      const j = html.indexOf(`id="${e}"`, i + 1);
      if (j > i && j < end) end = j;
    }
    return html.slice(i, end);
  };
  const spreads = {};
  for (const m of section('dex_spreads_wrapper', ['dex_natures_wrapper'])
      .matchAll(/<div class="pokedex-move-entry-new">\s*<div class="pokedex-inline-text-offset">\s*<\/div>\s*((?:<div class="pokedex-inline-text">\d+\/?<\/div>\s*)+)<div class="pokedex-inline-right">(\d+(?:\.\d+)?)%/g)) {
    const points = [...m[1].matchAll(/>(\d+)\/?</g)].map((d) => +d[1]);
    if (points.length === 6 && Object.keys(spreads).length < 4) spreads[points.join('/')] = +m[2];
  }
  const natures = {};
  for (const m of section('dex_natures_wrapper', ['teammate_wrapper', 'dex_team_wrapper'])
      .matchAll(/<div class="pokedex-inline-text-offset">([A-Za-z]+)<\/div>\s*<div class="pokedex-inline-right">(\d+(?:\.\d+)?)%/g)) {
    if (Object.keys(natures).length < 4) natures[m[1]] = +m[2];
  }
  const teammates = [];
  for (const m of html.matchAll(/<a class="teammate_entry[^>]*data-name="([^"]+)"/g)) {
    if (teammates.length < 6 && !teammates.includes(m[1])) teammates.push(m[1]);
  }
  if (Object.keys(spreads).length) profile.spreads = spreads;
  if (Object.keys(natures).length) profile.natures = natures;
  if (teammates.length) profile.teammates = teammates;
  if (Object.keys(profile.moves).length) out[engineSlug(name)] = profile;
}

function discoverLinks(html) {
  for (const m of html.matchAll(/href="\/pokedex\/battledataregmbs3\/([^"]+)"/g)) enqueue(m[1]);
  // Teammates/cores/spreads reference species via sprite images and
  // data-candidates attributes (already lowercase slugs), not hrefs.
  for (const m of html.matchAll(/championssprites\/([a-z0-9-]+)\.png/g)) enqueue(m[1]);
  for (const m of html.matchAll(/data-candidates="([a-z0-9-]+)"/g)) enqueue(m[1]);
}

async function main() {
  const index = await get(INDEX);
  discoverLinks(index);
  seeds.forEach(enqueue);
  console.log("seeds:", queue.length);

  let fetched = 0;
  async function worker() {
    while (queue.length) {
      const name = queue.shift();
      const html = await get(`${INDEX}/${encodeURIComponent(name)}`);
      fetched++;
      if (html) { parseProfile(name, html); discoverLinks(html); }
      if (fetched % 25 === 0) console.log(`  … ${fetched} fetched, ${queue.length} queued, ${Object.keys(out).length} profiles`);
      await new Promise(r => setTimeout(r, SPACING_MS));
    }
  }
  await Promise.all(Array.from({length: CONCURRENCY}, worker));

  fs.writeFileSync(`${__dirname}/data/meta-regmbs3.json`, JSON.stringify(out, null, 1));
  console.log("profiles with moves:", Object.keys(out).length, "of", fetched, "pages fetched");
  console.log("charizard check:", JSON.stringify(out.charizamd ?? out.charizard).slice(0, 120));
  console.log("incineroar fake out %:", out.incineroar && out.incineroar.moves["Fake Out"]);
}
main();
