/* JS tarafından Dart parite snapshot'ı üretir (tek yönlü referans üretimi).
   Kullanım: node tools_js/gen_levels_snapshot.js
   Çıktı: test/fixtures/levels_js_snapshot.json */
const fs = require('fs');
const path = require('path');
const L = require('../reference/www/levels.js');
const P = require('../reference/www/progress.js');

const levels = [];
for (let i = 0; i < L.levelCount(); i++) {
  const d = L.levelDef(i);
  levels.push({
    i: d.i, stage: d.stage, idx: d.idx, num: d.num,
    target: d.target, speed: d.speed, tol: d.tol,
    modifier: d.modifier, coins: d.coins, box: d.box,
    name: d.name, themeId: d.theme.id,
  });
}

const dailies = [];
for (let day = 0; day <= 36; day++) {
  const d = L.dailyDef(day);
  dailies.push({ day, stage: d.stage, target: d.target, speed: d.speed, tol: d.tol, modifier: d.modifier, coins: d.coins, name: d.name, themeId: d.theme.id });
}

const surprises = [];
for (let i = 0; i < 40; i++) {
  for (let day of [0, 1, 3]) {
    const s = L.surpriseFor(i, day);
    surprises.push({ i, day, id: s ? s.id : null, effect: s ? s.effect : null, coins: s ? (s.coins || 0) : 0 });
  }
}

const mysteries = [];
for (let i = 0; i < 20; i++) mysteries.push({ i, text: L.mysteryFor(i) });

const stars = [];
for (let t = 1; t <= 40; t++) {
  for (const p of [0, 1, Math.ceil(t * 0.3), Math.ceil(t * 0.3) - 1, Math.ceil(t * 0.6), Math.ceil(t * 0.6) - 1, t]) {
    stars.push({ target: t, perfects: p, stars: L.starsFor(p, t) });
  }
}

// rivalsFor: birkaç gün × oyuncu skoru için ilk 3 isim/skor (LCG birebirliği kanıtı)
const rivals = [];
for (const day of [0, 1, 2, 7, 100, 20257]) {
  const list = P.rivalsFor(day, 25);
  rivals.push({ day, playerScore: 25, names: list.map((r) => r.name), scores: list.map((r) => r.score) });
}

// openBox: sabit tohumlu rand dizileriyle iki dal
function seqRand(vals) { let k = 0; return () => vals[k++ % vals.length]; }
const boxLow = P.openBox(P.createSave(), { num: 20 }, seqRand([0.10, 0.5]));
const boxHigh = P.openBox(P.createSave(), { num: 20 }, seqRand([0.9, 0.5]));

// completeLevel örnekleri (normal/altın/başarısız/günlük/serbest)
function completeSample(modifier, res, pre) {
  const st = P.createSave();
  if (pre) Object.assign(st, pre);
  const def = Object.assign({}, L.levelDef(modifier === 'altin' ? 4 : 0), { modifier: modifier || 'normal' });
  const out = P.completeLevel(st, def, res);
  return { coins: out.coins, stars: out.stars, firstClear: out.firstClear, boxDropped: out.boxDropped, stateCoins: st.coins, levelsDone: st.levelsDone };
}

const out = {
  levels,
  dailies,
  surprises,
  mysteries,
  stars,
  rivals,
  openBox: {
    low: { type: boxLow.type, skin: boxLow.skin ? boxLow.skin.id : null, amount: boxLow.amount || null },
    high: { type: boxHigh.type, skin: boxHigh.skin ? boxHigh.skin.id : null, amount: boxHigh.amount || null },
  },
  complete: {
    normal: completeSample('normal', { blocks: 10, perfects: 4, reached: true, stars: 2 }),
    altin: completeSample('altin', { blocks: 10, perfects: 4, reached: true, stars: 2 }),
    fail: completeSample('normal', { blocks: 7, perfects: 1, reached: false }),
  },
  missions: (() => {
    const st = P.createSave();
    st.totalPerfect = 5; st.totalBlocks = 30; st.levelsDone = 1;
    P.ensureMissions(st, 86400000 * 19570);
    return st.missions.items.map((m) => ({ stat: m.stat, goal: m.goal, reward: m.reward, base: m.base }));
  })(),
};

const dest = path.join(__dirname, '..', 'test', 'fixtures', 'levels_js_snapshot.json');
fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.writeFileSync(dest, JSON.stringify(out, null, 1));
console.log('written', dest, 'levels:', levels.length);
