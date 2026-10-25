// Silüet RNG snapshot üretici — reference/www/game.js içindeki mulberry()
// fonksiyonunu dosyadan çıkarıp aynen çalıştırır (tek doğruluk kaynağı).
// Kullanım: node tools_js/gen_silhouette_snapshot.js
// Çıktı: test/fixtures/silhouette_snapshot.json (Dart parite testi okur).
const fs = require('fs');
const path = require('path');

const gameJsPath = path.join(__dirname, '..', 'reference', 'www', 'game.js');
const src = fs.readFileSync(gameJsPath, 'utf8');
const m = src.match(/function mulberry\(a\) \{[\s\S]*?\n  \}/);
if (!m) {
  throw new Error('mulberry() bulunamadı — reference/www/game.js değişmiş olabilir');
}
const mulberry = new Function(m[0] + '\nreturn mulberry;')();

// game.js makeSilhouette: mulberry(themeId.charCodeAt(0) * 97 + layer * 13 + stage)
const themeIds = ['sehir', 'orman', 'col', 'buz', 'uzay', 'volkan', 'bulut', 'deniz', 'kristal', 'zirve'];
const out = {};
for (const id of themeIds) {
  for (let stage = 0; stage < 2; stage++) {
    for (let layer = 0; layer < 2; layer++) {
      const seed = id.charCodeAt(0) * 97 + layer * 13 + stage;
      const rnd = mulberry(seed);
      const vals = [];
      for (let i = 0; i < 12; i++) vals.push(rnd());
      out[seed] = vals;
    }
  }
}

const outPath = path.join(__dirname, '..', 'test', 'fixtures', 'silhouette_snapshot.json');
fs.writeFileSync(outPath, JSON.stringify(out, null, 1) + '\n');
console.log('OK', Object.keys(out).length, 'seed ->', outPath);
