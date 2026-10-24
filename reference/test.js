/* NEON KULE testleri — çalıştır: node test.js */
'use strict';
var assert = require('assert');
var g = require('./www/game.js');
var levels = require('./www/levels.js');
var prog = require('./www/progress.js');

/* ================= 1) Oyun çekirdeği: bırakma matematiği ================= */

var r = g.resolveDrop({ x: 100, w: 200 }, { x: 100, w: 200 }, 6);
assert.strictEqual(r.ok, true, 'mükemmel bırakış başarılı olmalı');
assert.strictEqual(r.perfect, true);
assert.deepStrictEqual(r.placed, { x: 100, w: 200 });
assert.strictEqual(r.cuts.length, 0, 'mükemmel bırakışta kırpım olmamalı');

r = g.resolveDrop({ x: 130, w: 200 }, { x: 100, w: 200 }, 6);
assert.strictEqual(r.ok, true);
assert.strictEqual(r.perfect, false, '30px kayma mükemmel sayılmamalı');
assert.strictEqual(r.placed.x, 130);
assert.strictEqual(r.placed.w, 170, 'kalan genişlik 170 olmalı');
assert.strictEqual(r.cuts.length, 1);
assert.strictEqual(r.cuts[0].x, 300, 'sağdaki parça 300\'den başlamalı');
assert.strictEqual(r.cuts[0].w, 30, 'kesilen parça 30px olmalı');

r = g.resolveDrop({ x: 70, w: 200 }, { x: 100, w: 200 }, 6);
assert.strictEqual(r.ok, true);
assert.strictEqual(r.placed.x, 100);
assert.strictEqual(r.placed.w, 170);
assert.strictEqual(r.cuts[0].x, 70);
assert.strictEqual(r.cuts[0].w, 30);

r = g.resolveDrop({ x: 105, w: 200 }, { x: 100, w: 200 }, 6);
assert.strictEqual(r.perfect, true, '5px kayma mükemmel sayılmalı');

r = g.resolveDrop({ x: 300, w: 200 }, { x: 100, w: 200 }, 6);
assert.strictEqual(r.ok, false, 'kenar kenarayken kaçırma sayılmalı');
r = g.resolveDrop({ x: 305, w: 200 }, { x: 100, w: 200 }, 6);
assert.strictEqual(r.ok, false, 'tamamen dışarıdayken kaçırma sayılmalı');

var top = { x: 100, w: 200 };
var b = g.movingBounds(top);
var mv = { x: b.minX, w: 200, dir: 1 };
for (var i = 0; i < 5000; i++) g.stepMoving(mv, top, 10, 1 / 60);
assert.ok(mv.x >= b.minX - 1e-6 && mv.x <= b.maxX + 1e-6, 'x sınırlar içinde kalmalı');
assert.ok(mv.dir === 1 || mv.dir === -1);

mv = { x: b.maxX - 0.001, w: 200, dir: 1 };
g.stepMoving(mv, top, 0, 1 / 60);
assert.strictEqual(mv.dir, -1, 'sağ uçta yön dönmeli');

assert.ok(g.speedMultiplier(0) < g.speedMultiplier(50), 'hız artmalı');
assert.strictEqual(g.speedMultiplier(1000), 3, 'hız tavanı 3');

assert.strictEqual(g.growthWidth(100, 200, 4), 104, '4. mükemmelle %4 büyüme');
assert.strictEqual(g.growthWidth(200, 200, 4), 200, 'taban genişliği aşılmaz');
assert.strictEqual(g.growthWidth(100, 200, 1), 100, 'seri kırılınca büyüme yok');

/* ================= 2) Bölüm tanımları ================= */

assert.strictEqual(levels.levelCount(), 150, '10 dünya × 15 bölüm = 150 (çok uzun oyun)');
assert.strictEqual(levels.STAGE_COUNT * levels.LEVELS_PER_STAGE, 150);
assert.strictEqual(levels.THEMES.length, 10, '10 tema');
assert.strictEqual(levels.WORLD_LORE.length, 10, '10 dünyanın hikâyesi var');

var d0 = levels.levelDef(0);
assert.strictEqual(d0.target, 8, 'ilk bölüm hedefi 8 blok');
assert.strictEqual(d0.modifier, 'normal');
assert.strictEqual(d0.stage, 0);
assert.strictEqual(d0.num, 1);
assert.ok(d0.coins >= 10);

var dBoss = levels.levelDef(14);
assert.strictEqual(dBoss.modifier, 'patron', '15. bölüm patron');
assert.ok(dBoss.target > d0.target, 'patron hedefi daha yüksek');

assert.strictEqual(levels.levelDef(4).modifier, 'altin', '5. bölüm altın');
assert.strictEqual(levels.levelDef(9).modifier, 'altin', '10. bölüm altın');
assert.strictEqual(levels.levelDef(18).modifier, 'ruzgar', '2. dünya rüzgar bölümü');
assert.strictEqual(levels.levelDef(35).modifier, 'hizli', '3. dünya hızlı bölümü');
assert.strictEqual(levels.levelDef(51).modifier, 'karanlik', '4. dünya karanlık bölümü');
assert.strictEqual(levels.levelDef(62).modifier, 'yavas', '5. dünya huzur bölümü');
assert.strictEqual(levels.levelDef(101).modifier, 'deprem', '7. dünya deprem bölümü');
assert.strictEqual(levels.levelDef(121).modifier, 'akan', '9. dünya akan bölüm');
assert.ok(levels.levelDef(62).speed < levels.levelDef(101).speed, 'huzur bölümü yavaş olmalı');
assert.ok(levels.levelDef(62).tol > levels.levelDef(0).tol, 'huzur bölümünde tolerans geniş');

for (var li = 0; li < levels.levelCount(); li++) {
  var d = levels.levelDef(li);
  assert.ok(d.speed > 0.5 && d.speed <= 3.4, 'hız sınırı: ' + d.speed);
  assert.ok(d.target >= 8 && d.target <= 40, 'hedef mantıklı: ' + d.target);
  assert.ok(levels.MODIFIERS[d.modifier], 'geçerli modifiye');
}

assert.strictEqual(levels.requiredStars(0), 0, 'ilk dünya kapısız');
assert.strictEqual(levels.requiredStars(2), 20, '3. dünya 20 yıldız ister');
assert.strictEqual(levels.requiredStars(9), 90, 'son dünya 90 yıldız ister (450 üzerinden ulaşılabilir)');

assert.strictEqual(levels.starsFor(0, 10), 1, 'hedefe ulaş = 1 yıldız');
assert.strictEqual(levels.starsFor(3, 10), 2, '%30 mükemmel = 2 yıldız');
assert.strictEqual(levels.starsFor(6, 10), 3, '%60 mükemmel = 3 yıldız');
assert.ok(levels.isBoxLevel(6), '7. bölüm kutu bölümü');
assert.ok(!levels.isBoxLevel(0));

/* ================= 3) İlerleme / ödül sistemi ================= */

function memStorage() {
  var m = {};
  return {
    getItem: function (k) { return m[k] === undefined ? null : m[k]; },
    setItem: function (k, v) { m[k] = String(v); }
  };
}

var store = memStorage();
var s = prog.load(store);
assert.strictEqual(s.coins, 60, 'hoş geldin parası');
assert.deepStrictEqual(s.skins, ['default'], 'varsayılan görünüm sahip');

/* kaydet/yükle */
s.coins = 250;
prog.save(s, store);
var s2 = prog.load(store);
assert.strictEqual(s2.coins, 250, 'kayıt turu');

/* bölün bitirme ödülü */
var def = levels.levelDef(0);
var out = prog.completeLevel(s2, def, { blocks: 8, perfects: 6, reached: true, stars: 3 });
var expected = def.coins + 3 * 5 + 6 * 2;
assert.strictEqual(out.coins, expected, 'ödül formülü: taban + yıldız + mükemmel');
assert.strictEqual(out.firstClear, true, 'ilk bitiriş');
assert.strictEqual(s2.completed[0].stars, 3);
assert.strictEqual(s2.levelsDone, 1);
assert.strictEqual(s2.coins, 250 + expected);

/* aynı bölümü tekrar: yıldız yükselmezse puan eklenmez */
var coinsBefore = s2.coins;
out = prog.completeLevel(s2, def, { blocks: 8, perfects: 1, reached: true, stars: 1 });
assert.strictEqual(s2.completed[0].stars, 3, 'en iyi yıldız korunur');
assert.ok(s2.coins > coinsBefore, 'tekrar oynamak da para verir');

/* altın bölüm 2 kat */
var goldDef = levels.levelDef(4);
out = prog.completeLevel(s2, goldDef, { blocks: 10, perfects: 4, reached: true, stars: 2 });
assert.strictEqual(out.coins, (goldDef.coins + 2 * 5 + 4 * 2) * 2, 'altın bölüm çift ödül');

/* kilit mantığı */
assert.strictEqual(prog.isUnlocked(s2, 1, levels.levelDef(1), levels), true, '0. bitince 1. açılır');
assert.strictEqual(prog.isUnlocked(s2, 2, levels.levelDef(2), levels), false, '1. bitmeden 2. kapalı');
assert.strictEqual(prog.isUnlocked(s2, 15, levels.levelDef(15), levels), false, 'dünya kapısı yıldız ister');

/* teselli ödülü */
coinsBefore = s2.coins;
out = prog.completeLevel(s2, levels.levelDef(1), { blocks: 5, perfects: 2, reached: false });
assert.strictEqual(out.coins, 2, 'başarısız deneme 2 para');
assert.ok(!s2.completed[1]);

/* sürpriz kutusu */
var boxDef = levels.levelDef(6);
prog.completeLevel(s2, boxDef, { blocks: 10, perfects: 5, reached: true, stars: 3 });
assert.strictEqual(s2.boxes[6], true, 'kutu işareti');
var prize = prog.openBox(s2, boxDef, function () { return 0.99; });   // hep para
assert.strictEqual(prize.type, 'coins');
assert.ok(prize.amount > 0);
s2.coins = 500;
var prize2 = prog.openBox(s2, boxDef, function () { return 0.10; });  // görünüm şansı
assert.ok(prize2.type === 'skin' || prize2.type === 'coins');

/* günlük görevler */
var day = prog.dayOf(1760000000000);
var missions = prog.ensureMissions(s2, 1760000000000);
assert.strictEqual(missions.day, day);
assert.strictEqual(missions.items.length, 3);
var m0 = missions.items[0];
var p0 = prog.missionProgress(s2, m0);
assert.strictEqual(p0, s2.totalPerfect - m0.base, 'görev ilerlemesi = toplam - baz');
assert.strictEqual(prog.claimMission(s2, m0), null, 'hedefe ulaşılmadan alınamaz');
s2[m0.stat] = m0.base + m0.goal;
var got = prog.claimMission(s2, m0);
assert.strictEqual(got, m0.reward, 'görev ödülü');
assert.strictEqual(prog.claimMission(s2, m0), null, 'ikinci kez alınamaz');

/* görünümler (kutuda 'altin' çıktıysa 'alev' ile dene) */
s2.coins = 50;
assert.strictEqual(prog.buySkin(s2, 'alev').ok, false, 'para yetmezse alınamaz');
s2.coins = 1000;
assert.strictEqual(prog.buySkin(s2, 'alev').ok, true);
assert.ok(s2.skins.indexOf('alev') >= 0);
assert.strictEqual(s2.activeSkin, 'alev', 'alınca kuşanır');
assert.strictEqual(prog.buySkin(s2, 'alev').ok, false, 'aynı görünüm tekrar alınamaz');
assert.ok(prog.equipSkin(s2, 'default'));
assert.strictEqual(s2.activeSkin, 'default');

/* serbest mod rekoru */
prog.completeLevel(s2, levels.endlessDef(), { blocks: 42, perfects: 10, reached: false });
assert.strictEqual(s2.best, 42, 'serbest mod rekoru');

/* ================= 5) Günlük meydan okuma + skor tahtası ================= */

var dayA = 26000;
var dailyDef = levels.dailyDef(dayA);
var beforeLevelsDone = s2.levelsDone;
var coinsBeforeDaily = s2.coins;
var dOut = prog.completeLevel(s2, dailyDef, { blocks: 15, perfects: 6, reached: true, stars: 3 });
assert.ok(s2.coins > coinsBeforeDaily, 'günlük ödül verir');
assert.strictEqual(s2.levelsDone, beforeLevelsDone, 'günlük bölüm sayacı artırmaz');
assert.strictEqual(s2.completed[-2], undefined, 'günlük bölüm kayda işlenmez');
assert.ok(dOut.coins > 0);

assert.strictEqual(prog.recordDaily(s2, dayA, 15), 15, 'günlük rekor kaydedildi');
assert.strictEqual(prog.recordDaily(s2, dayA, 9), 15, 'düşük skor rekoru ezmez');
assert.strictEqual(prog.recordDaily(s2, dayA + 1, 7), 7, 'yeni gün rekoru sıfırlanır');

var boardA = prog.rivalsFor(dayA, 20);
var boardA2 = prog.rivalsFor(dayA, 20);
assert.strictEqual(boardA.length, 9, '9 rakip');
assert.deepStrictEqual(boardA, boardA2, 'aynı gün aynı tahta (deterministik)');
for (var ri = 0; ri < boardA.length; ri++) {
  assert.ok(boardA[ri].score >= 3, 'rakip skoru geçerli');
  assert.ok(boardA[ri].name, 'rakip adı var');
}

/* ================= 4) Konsept: dünya töreni + sürpriz anları ================= */

/* günlük meydan okuma: deterministik ve çeşitlendirilmiş */
var dd1 = levels.dailyDef(1234);
var dd2 = levels.dailyDef(1234);
assert.deepStrictEqual(dd1, dd2, 'aynı gün aynı bölüm');
assert.notDeepStrictEqual(levels.dailyDef(1235), dd1, 'farklı gün farklı bölüm');
assert.strictEqual(dd1.daily, true);
assert.ok(dd1.target >= 12 && dd1.target <= 20, 'günlük hedef makul');
assert.ok(levels.MODIFIERS[dd1.modifier], 'günlük modifiye geçerli');
assert.ok(dd1.coins >= 60, 'günlük ödül cömert');
assert.strictEqual(levels.surpriseFor(-2, 0), null, 'günlükte sürpriz çipleri yok');

var s1 = levels.surpriseFor(0, 0);
assert.ok(s1, 'sürpriz bölümü sürprizli');
assert.ok(s1.name && s1.desc && s1.effect, 'sürpriz tanımı dolu');
assert.strictEqual(levels.surpriseFor(1, 0), null, 'sürpriz olmayan bölüm null');
assert.notStrictEqual(levels.surpriseFor(4, 0).effect, s1.effect, 'sürprizler çeşitlenir');
assert.strictEqual(levels.surpriseFor(-1, 0), null, 'serbest modda sürpriz yok');

var sc = prog.createSave();
assert.ok(sc.worldsCelebrated, 'kayıta dünya töreni anahtarı eklendi');
assert.strictEqual(prog.isWorldComplete(sc, 0, levels), false, 'boş kayıtta dünya tamam değil');
for (var w = 0; w < levels.LEVELS_PER_STAGE; w++) {
  var wd = levels.levelDef(w);
  prog.completeLevel(sc, wd, { blocks: wd.target, perfects: 0, reached: true, stars: 1 });
}
assert.strictEqual(prog.isWorldComplete(sc, 0, levels), true, '15 bölüm bitince dünya tamam');
var beforeCoins = sc.coins;
assert.strictEqual(prog.applyWorldComplete(sc, 0), 50, 'ilk dünya bonusu 50 para');
assert.ok(sc.relics[0], 'dünya tamamlanınca kalıntı verilir');
assert.strictEqual(sc.coins, beforeCoins + 50, 'bonus hesaba geçti');
assert.strictEqual(prog.applyWorldComplete(sc, 0), null, 'tören yalnızca bir kez');
assert.strictEqual(prog.worldBonus(1), 75, 'ikinci dünya bonusu 75');

beforeCoins = sc.coins;
assert.strictEqual(prog.applySurpriseCoins(sc, levels.levelDef(0), { effect: 'coinStart', coins: 20 }), 20);
assert.strictEqual(sc.coins, beforeCoins + 20, 'sürpriz parası hesaba geçti');
assert.strictEqual(prog.applySurpriseCoins(sc, levels.levelDef(0), { effect: 'doubleCoins' }), 0, 'sadece coinStart para verir');

/* eski kayıt (worldsCelebrated'sız) yüklenirken tamamlanır */
store.setItem('neonkule_save_v2', JSON.stringify({
  v: 2, coins: 5, completed: {}, skins: ['default'], activeSkin: 'default',
  best: 0, totalPerfect: 0, totalBlocks: 0, levelsDone: 0, day: -1, missions: null, boxes: {}
}));
var oldSave = prog.load(store);
assert.ok(oldSave.worldsCelebrated, 'eski kayda worldsCelebrated eklendi');

/* ================= 6) Dünya fısıltısı, gizem ve kalıntılar ================= */

assert.strictEqual(levels.WORLD_TEASER.length, levels.STAGE_COUNT, 'her dünyanın fısıltısı var');
for (var ti = 0; ti < levels.WORLD_TEASER.length; ti++) {
  assert.ok(levels.WORLD_TEASER[ti].length > 15, 'fısıltı dolu: ' + ti);
  assert.strictEqual(levels.mysteryFor(ti), levels.mysteryFor(ti), 'gizem cümlesi deterministik');
  assert.ok(levels.mysteryFor(ti).length > 10, 'gizem cümlesi dolu');
}
assert.notStrictEqual(levels.mysteryFor(0), levels.mysteryFor(1), 'gizem cümleleri çeşitlenir');
/* gizem, sürprizin adını ele vermemeli */
for (var mi = 0; mi < 40; mi++) {
  var sur = levels.surpriseFor(mi, 0);
  if (!sur) continue;
  assert.ok(levels.mysteryFor(mi).indexOf(sur.name) < 0, 'gizem sürprizi açık etmiyor');
}

assert.strictEqual(prog.RELICS.length, levels.STAGE_COUNT, '10 dünya kalıntısı');
var relicStages = {};
prog.RELICS.forEach(function (r) {
  assert.ok(!relicStages[r.stage], 'kalıntı aşamaları tekil');
  relicStages[r.stage] = true;
  assert.ok(r.name && r.icon && r.lore, 'kalıntı tanımı dolu: ' + r.stage);
});
assert.strictEqual(prog.relicFor(0).name, 'NEON KORU');
assert.strictEqual(prog.relicFor(99), null, 'olmayan aşamada kalıntı yok');

var rs = prog.createSave();
assert.deepStrictEqual(rs.relics, {}, 'yeni kayıtta kalıntı bölümü var');
var awarded = prog.awardRelic(rs, 3);
assert.strictEqual(awarded.stage, 3, 'kalıntı verildi');
assert.ok(rs.relics[3], 'kalıntı kayda işlendi');
assert.strictEqual(prog.awardRelic(rs, 3), null, 'aynı kalıntı iki kez verilmez');

/* eski kayıt (relics alanı yok) uyumlu yüklenir */
store.setItem('neonkule_save_v2', JSON.stringify({
  v: 2, coins: 5, completed: {}, skins: ['default'], activeSkin: 'default',
  best: 0, totalPerfect: 0, totalBlocks: 0, levelsDone: 0, day: -1, missions: null, boxes: {}
}));
var oldRelicSave = prog.load(store);
assert.deepStrictEqual(oldRelicSave.relics, {}, 'eski kayda kalıntı alanı eklendi');

/* ================= 11) Çevrimiçi skor tahtası servisi ================= */

var lb = require('./www/leaderboard.js');

/* senkron "thenable": test senkron kalsın (servis .then kullanır) */
function syncOk(value) {
  return { then: function (onOk) { if (onOk) onOk(value); return this; } };
}
function syncErr(message) {
  return { then: function (onOk, onErr) { if (onErr) onErr({ message: message }); return this; } };
}

/* — köprü yokken: kuyruğa yazar, asla kırılmaz — */
var lbStore = memStorage();
var svcOffline = lb.create({ storage: lbStore, native: null, platform: 'web', ids: {} });
assert.strictEqual(svcOffline.isAvailable(), false, 'köprü yokken çevrimdışı mod');
var offRes = null;
svcOffline.submit('daily', 14, function (r) { offRes = r; });
assert.ok(offRes.ok && offRes.queued, 'çevrimdışı skor kuyruğa yazılır');
assert.strictEqual(svcOffline.pendingCount(), 1, 'kuyrukta 1 skor');
svcOffline.submit('daily', 9, function () {});
assert.strictEqual(svcOffline.pendingCount(), 2, 'kuyruk büyür');
svcOffline.submit('daily', 0, function (r) { assert.strictEqual(r.reason, 'zero-score'); });
var authRes = null;
svcOffline.authenticate(function (r) { authRes = r; });
assert.strictEqual(authRes.native, false, 'çevrimdışında kimlik yok');

/* — sahte Android köprüsü: kimlik → kuyruk boşalır, en yüksek skor gider — */
var mockCalls = { auth: 0, submits: [], shows: [] };
var mockBridge = {
  authenticate: function () { mockCalls.auth++; return syncOk({ ok: true, platform: 'android' }); },
  submit: function (arg) { mockCalls.submits.push(arg); return syncOk({ ok: true }); },
  show: function (arg) { mockCalls.shows.push(arg); return syncOk({ ok: true }); }
};
var ids = {
  daily: { android: 'AND-DAILY', ios: 'IOS-DAILY' },
  endless: { android: 'AND-ENDLESS', ios: 'IOS-ENDLESS' }
};
var lbStore2 = memStorage();
var svc = lb.create({ storage: lbStore2, native: mockBridge, platform: 'android', ids: ids });
assert.strictEqual(svc.isAvailable(), true, 'köprü + platform ile çevrimiçi');
assert.strictEqual(svc.boardId('daily'), 'AND-DAILY', 'android tahta kimliği');

/* kimlik doğrulama → bekleyen kuyruk toplu gönderilir */
svc.submit('daily', 9, function () {});      // auth öncesi kuyruğa düşsün
svc.submit('daily', 14, function () {});
assert.strictEqual(svc.pendingCount(), 2, 'auth öncesi kuyrukta 2');
var authRes2 = null;
svc.authenticate(function (r) { authRes2 = r; });
assert.strictEqual(authRes2.ok, true);
assert.strictEqual(authRes2.authed, true, 'sahte köprü kimlik doğruladı');
assert.strictEqual(mockCalls.submits.length, 1, 'toplu gönderim: tek çağrı');
assert.strictEqual(mockCalls.submits[0].boardId, 'AND-DAILY');
assert.strictEqual(mockCalls.submits[0].score, 14, 'aynı tahtada en yüksek skor gider');
assert.strictEqual(svc.pendingCount(), 0, 'kuyruk boşaldı');

/* auth sonrası anında gönderim */
svc.submit('endless', 30, function (r) { assert.ok(!r.queued, 'gönderildi'); });
assert.strictEqual(mockCalls.submits[1].boardId, 'AND-ENDLESS');
assert.strictEqual(mockCalls.submits[1].score, 30);

/* tahta kimliği boşsa skor kaybolmaz, kuyrukta bekler */
svc.configure({ daily: { android: 'AND-DAILY', ios: '' }, endless: { android: '', ios: '' } });
var noIdRes = null;
svc.submit('endless', 20, function (r) { noIdRes = r; });
assert.strictEqual(noIdRes.queued, true, 'kimliksiz tahtaya skor kuyrukta kalır');
assert.strictEqual(svc.pendingCount(), 1, 'kuyrukta bekliyor');

/* gönderim hatası → skorlar korunur */
var failCalls = 0;
var failBridge = {
  authenticate: function () { return syncOk({ ok: true }); },
  submit: function () { failCalls++; return syncErr('ag-offline'); },
  show: function () { return syncOk({ ok: true }); }
};
var lbStore3 = memStorage();
var svcFail = lb.create({ storage: lbStore3, native: failBridge, platform: 'android', ids: ids });
svcFail.authenticate(function () {});   // kimlik doğrula ki gönderim denensin
svcFail.submit('daily', 11, function (r) { assert.strictEqual(r.queued, true, 'hata sonrası kuyrukta'); });
assert.strictEqual(failCalls, 1, 'gönderim denendi');
assert.strictEqual(svcFail.pendingCount(), 1, 'başarısız gönderim skoru silmez');

/* iOS platformu kendi kimliklerini seçer */
var svcIos = lb.create({ storage: memStorage(), native: mockBridge, platform: 'ios', ids: ids });
assert.strictEqual(svcIos.boardId('daily'), 'IOS-DAILY', 'ios tahta kimliği');

/* yerel tahta ekranı */
var openRes = null;
svc.open('daily', function (r) { openRes = r; });
assert.strictEqual(openRes.ok, true, 'yerel tahta ekranı açıldı');
assert.strictEqual(mockCalls.shows[0].boardId, 'AND-DAILY');
var openOff = null;
svcOffline.open('daily', function (r) { openOff = r; });
assert.strictEqual(openOff.ok, false, 'çevrimdışında yerel tahta açılmaz');

console.log('Tüm testler geçti ✓ (çekirdek + bölümler + ödüller + konsept + günlük tahta + kalıntılar + çevrimiçi tahta)');
