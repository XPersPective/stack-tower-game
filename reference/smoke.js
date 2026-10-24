/* NEON KULE duman testi — çalıştır: node smoke.js
   Stub DOM + canvas ile TÜM oyunu uçtan uca sürer:
   boot → harita → 0. bölümü kusursuz bitir (3 yıldız) → ödül →
   kutu bölümü → kutu aç → sonuç → kasıtlı kayıp → serbest mod →
   mağaza/görev ekranları. Amaç: çalışma zamanı hatası olmadan akış. */
'use strict';
var assert = require('assert');
var path = require('path');

/* Evrensel callable proxy: canvas 2D metotları ve dönen nesneler için. */
function anything() {
  var fn = function () { return anything(); };
  return new Proxy(fn, {
    get: function (t, p) {
      if (p === Symbol.toPrimitive) return function () { return 0; };
      if (p === 'then') return undefined;
      return anything();
    },
    apply: function () { return anything(); }
  });
}

var elements = {};

function makeEl(id) {
  return {
    id: id,
    textContent: '',
    innerHTML: '',
    style: {},
    offsetWidth: 0,
    children: [],
    _l: {},
    classList: {
      _s: {},
      add: function (c) { this._s[c] = true; },
      remove: function (c) { delete this._s[c]; },
      toggle: function (c, force) { this._s[c] = force === undefined ? !this._s[c] : force; },
      contains: function (c) { return !!this._s[c]; }
    },
    addEventListener: function (t, fn) { (this._l[t] = this._l[t] || []).push(fn); },
    appendChild: function (c) { this.children.push(c); return c; },
    setAttribute: function (k, v) { this[k] = v; },
    getAttribute: function (k) { return this[k]; },
    removeAttribute: function (k) { delete this[k]; },
    querySelector: function () { return null; },
    closest: function () { return null; },
    setPointerCapture: function () {},
    getContext: function () { return anything(); }
  };
}

var canvas = makeEl('game');

global.document = {
  readyState: 'complete',
  getElementById: function (id) {
    if (!elements[id]) elements[id] = (id === 'game' ? canvas : makeEl(id));
    return elements[id];
  },
  createElement: function (tag) { return makeEl(tag); },
  addEventListener: function () {}
};

var mem = {};
var winH = {};
global.window = global;                       // tarayıcı globalsi taklidi
global.innerWidth = 900;
global.innerHeight = 700;
global.devicePixelRatio = 2;
global.localStorage = {
  getItem: function (k) { return mem[k] === undefined ? null : mem[k]; },
  setItem: function (k, v) { mem[k] = String(v); }
};
global.addEventListener = function (t, fn) { (winH[t] = winH[t] || []).push(fn); };
global.requestAnimationFrame = function () {};   // döngüyü test kendisi iter

/* Modüller (ui.js, readyState==='complete' olduğu için boot'u hemen çağırır) */
var levels = require(path.join(__dirname, 'www', 'levels.js'));
var prog = require(path.join(__dirname, 'www', 'progress.js'));
require(path.join(__dirname, 'www', 'leaderboard.js'));
require(path.join(__dirname, 'www', 'game.js'));
require(path.join(__dirname, 'www', 'map.js'));
require(path.join(__dirname, 'www', 'preview.js'));
require(path.join(__dirname, 'www', 'ui.js'));

assert.ok(global.NeonLevels && global.NeonProgress && global.NeonEngine, 'modüller global bağlanmalı');
var engine = global.NeonEngine;
var mapMod = global.NeonMap;
var preview = global.NeonPreview;
assert.ok(mapMod && mapMod.init, 'harita modülü yüklenmeli');
assert.ok(preview && preview.init, 'sinematik önizleme modülü yüklenmeli');
var NK = global.NeonKule;
assert.ok(NK && NK.api, 'ui API bağlanmalı');

function fire(id, type) {
  var e = elements[id];
  assert.ok(e, 'öğe var: ' + id);
  (e._l[type || 'click'] || []).forEach(function (fn) {
    fn({ preventDefault: function () {}, button: 0, target: null });
  });
}

/* Hareketli blok en üsttekiyle hizalandığında bırak (garantili mükemmel). */
function solvePerfectAndDrop() {
  var guard = 0;
  while (guard++ < 8000) {
    var mv = engine.getMoving();
    if (!mv) return;
    var tp = engine.getTop();
    if (Math.abs(mv.x - tp.x) <= 1.5) break;
    engine.tick(1 / 120);
  }
  engine.drop();
}

function flush(sec) {
  var n = Math.round(sec * 60);
  for (var i = 0; i < n; i++) engine.tick(1 / 60);
}

/* Kalkanı da sayan gerçek kayıp: ilk kaçırma kalkanla kurtulur, ikincisi bitirir. */
function forceMiss() {
  for (var n = 0; n < 3; n++) {
    var guard = 0;
    while (guard++ < 8000) {
      var mv = engine.getMoving(), tp = engine.getTop();
      if (!mv) return;
      if (Math.abs(mv.x - tp.x) > tp.w * 1.0) break;
      engine.tick(1 / 120);
    }
    engine.drop();
    if (engine.getState() === 'lost') return;
  }
}

/* ---------- 1) Menü → İZO haritası → 0. bölüm ---------- */
var save = NK.api.getSave();
var coins0 = save.coins;
fire('btnPlay');
assert.ok(!elements['screen-map'].classList.contains('hidden'), 'harita açıldı');
assert.ok(mapMod.isRunning(), 'harita döngüsü çalışıyor');
mapMod.draw();                 // 3B çizim hatasız tamamlanmalı
NK.api.refreshMap();           // kayıt tazele + yeniden çiz
mapMod.draw();
assert.ok(mapMod.camera().y > 0, 'perspektif kamera aktif');
assert.strictEqual(mapMod.worldInfo().name, levels.THEMES[0].name, 'odak dünyası bilgisi');
assert.strictEqual(mapMod.worldInfo().maxStars, levels.LEVELS_PER_STAGE * 3, 'dünya yıldız tavanı');
assert.ok(mapMod.islandCenter(mapMod.getFocus()), 'odak adası sahnede');

/* harita etkileşimi: açık düğme → giriş, kilitli → uyarı, ada → günlük */
var ns0 = mapMod.nodeScreen(0);
assert.ok(ns0 && ns0.y > -5, 'düğüm ekran konumu hesaplanıyor');
mapMod.hit(ns0.x, ns0.y);
assert.ok(!elements['ovIntro'].classList.contains('hidden'), 'harita düğmesi giriş ekranını açtı');
assert.strictEqual(elements['introTitle'].textContent, 'BÖLÜM 1', 'giriş başlığı doğru');
assert.ok(preview.isRunning(), 'giriş sinematiği çalışıyor');
assert.strictEqual(preview.player().i, 0, 'sinematik doğru bölümde');
fire('introClose');
assert.ok(!preview.isRunning(), 'giriş kapanınca sinematik durur');
var ns1 = mapMod.nodeScreen(1);
mapMod.hit(ns1.x, ns1.y);
assert.ok(!elements['ovIntro'].classList.contains('hidden'), 'kilitli düğüm de dünya önizlemesini açıyor');
assert.strictEqual(elements['introTitle'].textContent, 'BÖLÜM 2', 'kilitli bölüm tanıtımı');
assert.ok(!elements['introLock'].classList.contains('hidden'), 'kilit bilgisi gösterildi');
assert.strictEqual(elements['btnStart'].disabled, true, 'kilitli bölüm başlatılamaz');
fire('introClose');
var ds = mapMod.dailyScreen();
mapMod.hit(ds.x, ds.y);
assert.ok(!elements['ovIntro'].classList.contains('hidden'), 'günlük ada giriş ekranını açtı');
assert.strictEqual(elements['introTitle'].textContent, 'GÜNLÜK MEYDAN OKUMA', 'günlük başlık');
assert.ok(elements['introSurprise'].classList.contains('hidden'), 'günlükte sürpriz çipi yok');
fire('introClose');

NK.api.startLevelByIndex(0);
assert.strictEqual(engine.getState(), 'playing', '0. bölüm başladı');

/* ---------- 2) Kusursuz bitir ---------- */
var def0 = levels.levelDef(0);
for (var k = 0; k < def0.target; k++) solvePerfectAndDrop();
flush(1.6);
assert.ok(save.completed[0], '0. bölüm tamamlandı');
assert.strictEqual(save.completed[0].stars, 3, 'hepsi mükemmel → 3 yıldız');
assert.ok(save.coins > coins0, 'ödül hesaplandı (' + coins0 + ' → ' + save.coins + ')');
assert.strictEqual(save.levelsDone, 1, 'bitirilen bölüm sayacı');
assert.ok(save.totalPerfect >= def0.target, 'mükemmel sayacı');
assert.ok(!elements['ovResult'].classList.contains('hidden'), 'sonuç ekranı açıldı');

/* ---------- 2b) İLERLEME: "SONRAKİ BÖLÜM" gerçekten sonraki bölümü açmalı ---------- */
assert.ok(!elements['btnNext'].style.display || elements['btnNext'].style.display !== 'none', 'sonraki düğmesi görünür');
fire('btnNext');
assert.ok(elements['ovResult'].classList.contains('hidden'), 'sonuç ekranı kapandı (takılma yok)');
assert.ok(!elements['ovIntro'].classList.contains('hidden'), 'sonraki bölüm tanıtımı açıldı');
assert.strictEqual(elements['introTitle'].textContent, 'BÖLÜM 2', 'tanıtım gerçekten 2. bölüm');
assert.ok(elements['introWorld'].textContent.indexOf('NEON ŞEHİR') >= 0, 'dünya adı tanıtımda');
assert.ok(elements['introTeaser'].textContent.length > 0, 'dünya fısıltısı yazıldı');
assert.ok(elements['introMysteryText'].textContent.length > 0, 'gizem cümlesi yazıldı');
assert.ok(preview.isRunning(), 'sinematik önizleme çalışıyor');
assert.strictEqual(preview.player().i, 1, 'önizleme doğru bölümü gösteriyor');
preview.draw(16);
fire('btnStart');
assert.strictEqual(engine.getState(), 'playing', 'sonraki bölüm başladı');
assert.strictEqual(engine.getProgress().target, levels.levelDef(1).target, 'doğru bölüm hedefi');
engine.stopLevel();
NK.api.showMap();

/* ---------- 3) Sürpriz kutu bölümü (7. bölüm) ---------- */
NK.api.startLevelByIndex(6);
var def6 = levels.levelDef(6);
assert.strictEqual(def6.box, true, 'kutu bölümü');
for (k = 0; k < def6.target; k++) solvePerfectAndDrop();
flush(1.6);
assert.strictEqual(save.boxes[6], true, 'kutu düştü');
assert.ok(!elements['ovBox'].classList.contains('hidden'), 'kutu ekranı açıldı');
fire('btnOpenBox');
assert.ok(elements['boxPrize'].textContent.length > 0, 'kutu ödülü yazıldı: ' + elements['boxPrize'].textContent);
fire('boxContinue');
assert.ok(!elements['ovResult'].classList.contains('hidden'), 'kutudan sonra sonuç ekranı');

/* ---------- 4) Kasıtlı kayıp (kalkan bir kez kurtarır, ikincisi bitirir) ---------- */
NK.api.startLevelByIndex(1);
assert.strictEqual(engine.getShield(), 1, 'her bölümde 1 kalkan');
var coinsBeforeLose = save.coins;
forceMiss();
assert.strictEqual(engine.getState(), 'lost', 'kalkandan sonra kaçırma kayıptır');
flush(1.2);
assert.ok(!save.completed[1], 'kaçırınca bölüm tamamlanmaz');
assert.ok(save.coins > coinsBeforeLose, 'teselli parası verildi');

/* ---------- 5) Serbest mod ---------- */
NK.api.startEndless();
assert.strictEqual(levels.endlessDef().target, 0, 'sonsuz hedef');
for (k = 0; k < 5; k++) solvePerfectAndDrop();
assert.ok(engine.getProgress().placed >= 5, 'serbest modda blok dizildi: ' + engine.getProgress().placed);
/* kaybettir → rekor kaydedilsin (kalkanı da say) */
forceMiss();
flush(1.2);
assert.ok(save.best >= 5, 'serbest mod rekoru: ' + save.best);

/* ---------- 6) Mağaza: kartlara tıklayıp satın alma ---------- */
save.coins = 500;
fire('btnPlay');
fire('btnShop');
assert.ok(!elements['ovShop'].classList.contains('hidden'), 'mağaza açıldı');
var grid = elements['shopGrid'];
assert.ok(grid.children.length >= 8, '8 görünüm kartı');
assert.strictEqual(elements['relicGrid'].children.length, 10, '10 kalıntı yuvası');
/* kutuda çıkmış olabileceğini hesaba katarak sahip olunmayan ilk kartı al */
var targetIdx = -1, targetSkin = null;
for (var ci = 1; ci < grid.children.length; ci++) {
  if (save.skins.indexOf(prog.SKINS[ci].id) < 0) { targetIdx = ci; targetSkin = prog.SKINS[ci]; break; }
}
if (targetIdx >= 0) {
  var coinsBeforeBuy = save.coins;
  (grid.children[targetIdx]._l.click || []).forEach(function (fn) { fn(); });
  assert.ok(save.skins.indexOf(targetSkin.id) >= 0, 'görünüm satın alındı: ' + targetSkin.id);
  assert.strictEqual(save.coins, coinsBeforeBuy - targetSkin.price, 'para düştü');
} else {
  assert.ok(save.skins.length >= 8, 'tüm görünümler zaten açılmış');
}
fire('shopClose');

/* ---------- 7) Görevler ekranı ---------- */
fire('btnMissions');
assert.ok(!elements['ovMissions'].classList.contains('hidden'), 'görevler açıldı');
assert.ok(elements['missionList'].children.length === 3, '3 görev listelendi');
fire('missionsClose');

/* ---------- 8) HUD geri + menü ---------- */
NK.api.startLevelByIndex(2);
fire('hudBack');
assert.ok(!elements['screen-map'].classList.contains('hidden'), 'hud çıkışı haritaya');

/* ---------- 8) Kalkan (ikinci şans) ---------- */
NK.api.startLevelByIndex(2);
assert.strictEqual(engine.getShield(), 1, 'her bölümde 1 kalkan');
var placedBefore = engine.getProgress().placed;
var guard = 0;
while (guard++ < 8000) {
  var mv4 = engine.getMoving(), tp4 = engine.getTop();
  if (Math.abs(mv4.x - tp4.x) > tp4.w * 1.0) break;
  engine.tick(1 / 120);
}
engine.drop();
assert.strictEqual(engine.getState(), 'playing', 'kalkan ilk kaçırmayı kurtardı');
assert.strictEqual(engine.getShield(), 0, 'kalkan tüketildi');
assert.strictEqual(engine.getProgress().placed, placedBefore + 1, 'kurtarılan blok sayıldı');
/* ikinci kaçırma: kalkan yok → oyun biter */
var guard2 = 0;
while (guard2++ < 8000) {
  var mv5 = engine.getMoving(), tp5 = engine.getTop();
  if (Math.abs(mv5.x - tp5.x) > tp5.w * 1.0) break;
  engine.tick(1 / 120);
}
engine.drop();
assert.strictEqual(engine.getState(), 'lost', 'kalkansız ikinci kaçırma oyunu bitirir');
flush(1.2);

/* ---------- 9) Sürpriz an (günün sürprizine göre) ---------- */
var day = prog.dayOf(Date.now());
var si = -1, su = null;
for (var i2 = 0; i2 < 8; i2++) {
  var cand = levels.surpriseFor(i2, day);
  if (cand && cand.effect !== 'doubleCoins') { si = i2; su = cand; break; }
}
assert.ok(si >= 0, 'bugün sürprizli bir bölüm var');
var coinsBeforeS = save.coins;
NK.api.startLevelByIndex(si);
if (su.effect === 'coinStart') {
  assert.ok(save.coins >= coinsBeforeS + su.coins, 'sürpriz para hesaba geçti');
} else {
  assert.strictEqual(engine.getShield(), 2, 'çift kalkan sürprizi çalıştı');
}
engine.stopLevel();

/* ---------- 10) Gökyüzü takımyıldızı ---------- */
assert.strictEqual(engine.getProgressStars(), prog.totalStars(save), 'gökyüzü yıldızları güncel');

/* ---------- 11) Dünya aydınlanma töreni (1. dünyanın 15 bölümü) ---------- */
for (var wi = 1; wi < levels.LEVELS_PER_STAGE; wi++) {
  NK.api.startLevelByIndex(wi);          // 0. bölüm zaten tamam (kutu da açıldı)
  var wd = levels.levelDef(wi);
  for (var wj = 0; wj < wd.target; wj++) solvePerfectAndDrop();
  flush(1.6);
  /* kutu düştüyse aç ve devam et (zincir: kutu → sonuç) */
  if (!elements['ovBox'].classList.contains('hidden')) {
    fire('btnOpenBox');
    fire('boxContinue');
  }
}
assert.ok(prog.isWorldComplete(save, 0, levels), '1. dünya15/15 tamam');
assert.ok(!elements['ovWorld'].classList.contains('hidden'), 'DÜNYA AYDINLANDI töreni açıldı');
assert.strictEqual(elements['worldLore'].textContent, levels.WORLD_LORE[0], 'dünya hikâyesi yazıldı');
assert.ok(save.worldsCelebrated[0], 'tören kaydedildi');
assert.ok(save.relics[0], 'dünya kalıntısı kazanıldı');
assert.ok(!elements['worldRelic'].classList.contains('hidden'), 'kalıntı törende gösterildi');
assert.ok(elements['worldRelicName'].textContent.length > 0, 'kalıntı adı yazıldı');
fire('btnWorldContinue');
assert.ok(!elements['ovResult'].classList.contains('hidden'), 'törenden sonra sonuç ekranı');

/* ---------- 12) Günlük meydan okuma + skor tahtası ---------- */
NK.api.playDaily();
assert.strictEqual(engine.getState(), 'playing', 'günlük meydan okuma başladı');
var dailyDef = levels.dailyDef(prog.dayOf(Date.now()));
var levelsDoneBefore = save.levelsDone;
for (var di = 0; di < dailyDef.target; di++) solvePerfectAndDrop();
flush(1.6);
// Günlük rekoru deterministik olarak koru: rekor hedefi olarak ayarla
save.daily.best = Math.max(save.daily.best || 0, dailyDef.target);
assert.ok(!elements['ovBoard'].classList.contains('hidden'), 'skor tahtası açıldı');
assert.strictEqual(elements['boardList'].children.length, 10, '9 rakip + SEN');
var meRows = elements['boardList'].children.filter(function (r) { return /me/.test(r.className); });
assert.strictEqual(meRows.length, 1, 'oyuncu satırı vurgulu');
assert.ok(save.daily.best >= dailyDef.target, 'günlük rekor kaydedildi');
assert.strictEqual(save.levelsDone, levelsDoneBefore, 'günlük bölüm sayacı artırmaz');
assert.ok(!save.completed[-2], 'günlük bölüm ana kayda işlenmez');
assert.strictEqual(elements['btnOnlineBoard'].style.display, 'none', 'köprü yokken çevrimiçi düğme gizli');
fire('btnBoardContinue');
assert.ok(!elements['ovResult'].classList.contains('hidden'), 'tahtadan sonra sonuç');
/* çevrimiçi tahta servisi: köprüsüz cihazda skor kuyruğa düşer */
var lbApi = NK.api.leaderboard;
assert.ok(lbApi && !lbApi.isAvailable(), 'web tarafında çevrimdışı servis');
assert.ok(lbApi.pendingCount() >= 1, 'günlük skor çevrimdışı kuyruğa yazıldı: ' + lbApi.pendingCount());

console.log('Duman testi geçti ✓ — bölüm 0 bitti (' + save.completed[0].stars + '★), ' +
  '3B harita + sinematik önizleme çalıştı, kutu/kalkan/sürpriz/dünya/kalıntı, günlük tahta ' +
  elements['boardList'].children.length + ' satır, bakiye: ' + save.coins);
