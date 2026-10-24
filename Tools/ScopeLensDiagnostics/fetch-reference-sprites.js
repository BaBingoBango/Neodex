// Rebuilds Fixtures/reference/: species-index.json (name, num, types, icon sheet
// coords) and dex-sprites/ (Showdown 120x120 HOME-style renders; gitignored).
// Usage: npm i @pkmn/dex @pkmn/img && node fetch-reference-sprites.js
const {Dex} = require('@pkmn/dex');
const {Sprites, Icons} = require('@pkmn/img');
const fs = require('fs'), https = require('https'), path = require('path');
const refDir = path.join(__dirname, '..', 'Fixtures', 'reference');
const outDir = path.join(refDir, 'dex-sprites');
fs.mkdirSync(outDir, {recursive: true});
const idx = [];
for (const s of Dex.species.all()) {
  if (s.num <= 0 || s.battleOnly) continue;
  if (s.isNonstandard && s.isNonstandard !== 'Past') continue;
  if (/-Gmax$/.test(s.name)) continue;              // gen9 dex marks Gmax as 'Past'
  const icon = Icons.getPokemon(s.name);
  idx.push({name: s.name, num: s.num, types: s.types, left: -icon.left, top: -icon.top});
}
fs.writeFileSync(path.join(refDir, 'species-index.json'), JSON.stringify(idx));
console.log('index:', idx.length, 'species');
const jobs = idx.map(s => ({url: Sprites.getPokemon(s.name, {gen: 'dex'}).url,
                            file: path.join(outDir, s.name.replace(/[^A-Za-z0-9-]/g, '_') + '.png')}));
let i = 0, active = 0, ok = 0, miss = 0;
(function pump() {
  while (active < 12 && i < jobs.length) {
    const job = jobs[i++]; active++;
    if (fs.existsSync(job.file)) { ok++; active--; continue; }
    https.get(job.url, res => {
      if (res.statusCode !== 200) { miss++; res.resume(); active--; return pump(); }
      const f = fs.createWriteStream(job.file);
      res.pipe(f); f.on('finish', () => { ok++; f.close(() => { active--; pump(); }); });
    }).on('error', () => { miss++; active--; pump(); });
  }
  if (i >= jobs.length && active === 0) console.log('done. ok:', ok, 'missing:', miss);
})();
