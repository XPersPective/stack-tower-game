/* Harita animasyon stres testi — çalıştır: node tools/anim-check.js
   Yüzlerce gerçek kare sürüp parçacık izleri/aura/yeniden doğuş
   yollarında çalışma zamanı hatası olup olmadığını doğrular. */
'use strict';
var path = require('path');

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
    id: id, textContent: '', innerHTML: '', style: {}, offsetWidth: 0, children: [], _l: {},
    classList: { _s: {}, add: function (c) { this._s[c] = true; }, remove: function (c) { delete this._s[c]; }, toggle: function () {}, contains: function (c) { return !!this._s[c]; } },
    addEventListener: function (t, fn) { (this._l[t] = this._l[t] || []).push(fn); },
    appendChild: function (c) { this.children.push(c); return c; },
    setAttribute: function () {}, getAttribute: function () { return null; }, removeAttribute: function () {},
    querySelector: function () { return null; }, closest: function () { return null; },
    setPointerCapture: function () {}, getContext: function () { return anything(); }
  };
}
var canvas = makeEl('game');
global.document = {
  readyState: 'complete',
  getElementById: function (id) { if (!elements[id]) elements[id] = (id === 'game' ? canvas : makeEl(id)); return elements[id]; },
  createElement: function (tag) { return makeEl(tag); },
  addEventListener: function () {}
};
var mem = {};
global.window = global;
global.innerWidth = 900;
global.innerHeight = 700;
global.devicePixelRatio = 2;
global.localStorage = {
  getItem: function (k) { return mem[k] === undefined ? null : mem[k]; },
  setItem: function (k, v) { mem[k] = String(v); }
};
/* rAF kuyruğu: kareleri biz iteriz */
var rafQueue = [];
global.addEventListener = function () {};
global.requestAnimationFrame = function (fn) { rafQueue.push(fn); };

require(path.join(__dirname, '..', 'www', 'levels.js'));
require(path.join(__dirname, '..', 'www', 'progress.js'));
require(path.join(__dirname, '..', 'www', 'game.js'));
require(path.join(__dirname, '..', 'www', 'map.js'));
require(path.join(__dirname, '..', 'www', 'preview.js'));
require(path.join(__dirname, '..', 'www', 'ui.js'));

var NK = global.NeonKule;
var mapMod = global.NeonMap;
if (!NK || !NK.api || !mapMod || !mapMod.init) throw new Error('modüller yüklenmedi');

function fire(id) {
  var e = elements[id];
  (e._l['click'] || []).forEach(function (fn) { fn({ preventDefault: function () {}, button: 0, target: null }); });
}

/* haritayı aç → animasyon döngüsü başlar */
fire('btnPlay');
if (!mapMod.isRunning()) throw new Error('harita döngüsü çalışmıyor');

var now = 0;
function frames(n) {
  for (var i = 0; i < n; i++) {
    var q = rafQueue; rafQueue = [];
    now += 16.7;
    for (var k = 0; k < q.length; k++) q[k](now);
  }
}

/* 600 kare (~10 sn): parçacık ömürleri birden fazla kez yeniden doğar
   (maxLife 0.75–1.25 sn) */
frames(600);

/* dünyalar arası geçiş + odak ada yeniden kurulumu */
mapMod.setFocus(3);
frames(120);
mapMod.setFocus(0);
frames(120);

/* kayıt tazeleme → layout + initParticles yeniden çalışır, döngü devam eder */
NK.api.refreshMap();
frames(240);

/* günlük adayı da çiz (draw içinden çağrılıyor) */
mapMod.draw();
frames(60);

if (rafQueue.length > 2) throw new Error('rAF kuyruğu şişti: ' + rafQueue.length);
console.log('Animasyon stres testi geçti ✓ — ' + now + ' ms (~' + Math.round(now / 16.7) + ' kare) sürüldü, kuyruk: ' + rafQueue.length);
