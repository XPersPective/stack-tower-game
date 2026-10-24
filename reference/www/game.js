/* ============================================================
   NEON KULE — Oyun motoru
   Kule mekaniği + bölüm türleri (rüzgar/hızlı/karanlık/altın/patron)
   + dünya temalı arka planlar + kutlama efektleri.
   Saf çekirdek (resolveDrop vb.) testler için korunmuştur.
   ============================================================ */
(function (root) {
  'use strict';

  /* ------------------------- Saf çekirdek ------------------------- */

  var PERFECT_TOLERANCE = 6;
  var MIN_BLOCK_WIDTH = 6;
  var RANGE_FACTOR = 2.1;
  var OVERSHOOT = 1.05;

  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }

  function resolveDrop(moving, top, tolerance) {
    if (tolerance === undefined || tolerance === null) tolerance = PERFECT_TOLERANCE;
    var overlapLeft = Math.max(moving.x, top.x);
    var overlapRight = Math.min(moving.x + moving.w, top.x + top.w);
    var overlap = overlapRight - overlapLeft;
    if (overlap <= 0) {
      return { ok: false, perfect: false, placed: null, cuts: [{ x: moving.x, w: moving.w }] };
    }
    var perfect = Math.abs(moving.x - top.x) <= tolerance &&
                  Math.abs(moving.w - top.w) <= tolerance;
    if (perfect) {
      return { ok: true, perfect: true, placed: { x: top.x, w: top.w }, cuts: [] };
    }
    var cuts = [];
    if (moving.x < top.x - 0.01) cuts.push({ x: moving.x, w: top.x - moving.x });
    var mR = moving.x + moving.w;
    var tR = top.x + top.w;
    if (mR > tR + 0.01) cuts.push({ x: tR, w: mR - tR });
    return { ok: true, perfect: false, placed: { x: overlapLeft, w: overlap }, cuts: cuts };
  }

  function travelRange(w) { return w * RANGE_FACTOR; }

  function movingBounds(top) {
    var minX = top.x - top.w * OVERSHOOT;
    return { minX: minX, maxX: minX + travelRange(top.w) };
  }

  function speedMultiplier(placed) {
    return Math.min(3, 0.9 + placed * 0.055);
  }

  function stepMoving(moving, top, placed, dt, speedScale) {
    var b = movingBounds(top);
    var speed = travelRange(top.w) * 0.5 * speedMultiplier(placed) * (speedScale || 1);
    moving.x += moving.dir * speed * dt;
    if (moving.x >= b.maxX) { moving.x = b.maxX; moving.dir = -1; }
    else if (moving.x <= b.minX) { moving.x = b.minX; moving.dir = 1; }
    return moving;
  }

  function growthWidth(w, baseW, combo) {
    return (combo > 0 && combo % 4 === 0) ? Math.min(baseW, w * 1.04) : w;
  }

  var CORE = {
    PERFECT_TOLERANCE: PERFECT_TOLERANCE,
    MIN_BLOCK_WIDTH: MIN_BLOCK_WIDTH,
    clamp: clamp,
    resolveDrop: resolveDrop,
    travelRange: travelRange,
    movingBounds: movingBounds,
    speedMultiplier: speedMultiplier,
    stepMoving: stepMoving,
    growthWidth: growthWidth
  };

  /* --------------------------- Motor --------------------------- */

  var canvas = null, ctx = null;
  var W = 0, H = 0, dpr = 1, scale = 1, bh = 24, baseW = 230;
  var groundY = 0, topLimit = 0, depthX = 16, depthY = -9;

  var STATE = 'idle';           // idle | playing | won | lost
  var def = null;               // bölüm tanımı
  var skinHue = 200;
  var cb = function () {};

  var blocks = [], moving = null;
  var camShift = 0;
  var score = 0, combo = 0, bestRun = 0;
  var perfects = 0, misses = 0;
  var time = 0, hueDrift = 0, shake = 0;
  var endTimer = 0, endEvent = null;
  var manualMode = false;
  var shieldsLeft = 0, slowTimer = 0, progressStars = 0;

  var debris = [], particles = [], rings = [], popups = [], confetti = [];
  var weather = [], silhouettes = [], clouds = [], fgBits = [];
  var stars = [];

  var muted = false;
  try { muted = (root.localStorage && root.localStorage.getItem('neonkule_muted_v1')) === '1'; } catch (e) {}

  /* ----------------------------- Ses ----------------------------- */

  var actx = null;

  function unlockAudio() {
    if (!actx) {
      var AC = root.AudioContext || root.webkitAudioContext;
      if (AC) { try { actx = new AC(); } catch (e) { actx = null; } }
    }
    if (actx && actx.state === 'suspended') actx.resume();
  }

  function tone(freq, endFreq, dur, type, vol, delay) {
    if (muted || !actx) return;
    var t0 = actx.currentTime + (delay || 0);
    var osc = actx.createOscillator();
    var gain = actx.createGain();
    osc.type = type || 'sine';
    osc.frequency.setValueAtTime(freq, t0);
    if (endFreq && endFreq !== freq) osc.frequency.exponentialRampToValueAtTime(endFreq, t0 + dur);
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(vol || 0.2, t0 + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(gain);
    gain.connect(actx.destination);
    osc.start(t0);
    osc.stop(t0 + dur + 0.06);
  }

  function playPlace() { tone(240, 110, 0.12, 'triangle', 0.22); }
  function playPerfect(c) {
    var b = Math.min(1200, 640 + c * 45);
    tone(b, b, 0.08, 'sine', 0.20);
    tone(b * 1.5, b * 1.5, 0.12, 'sine', 0.17, 0.07);
  }
  function playWin() {
    [523, 659, 784, 1047].forEach(function (f, i) { tone(f, f, 0.16, 'triangle', 0.22, i * 0.11); });
  }
  function playLose() { tone(340, 70, 0.55, 'sawtooth', 0.22); }
  function playCoin() { tone(1180, 1560, 0.09, 'square', 0.10); }
  function playBox() {
    tone(420, 420, 0.1, 'sine', 0.18);
    [660, 880, 1320].forEach(function (f, i) { tone(f, f, 0.14, 'sine', 0.2, 0.12 + i * 0.1); });
  }
  function playShield() { tone(320, 960, 0.22, 'triangle', 0.22); }
  function playStart() { tone(480, 900, 0.16, 'triangle', 0.18); }

  function toggleMute() {
    muted = !muted;
    try { root.localStorage && root.localStorage.setItem('neonkule_muted_v1', muted ? '1' : '0'); } catch (e) {}
    if (!muted) { unlockAudio(); tone(700, 900, 0.1, 'sine', 0.16); }
    return muted;
  }

  /* -------------------------- Native köprü -------------------------- */

  var nativeTries = 0, nativeBound = false;

  function nativePlugin(name) {
    try {
      var cap = root.Capacitor;
      if (cap && cap.Plugins && cap.Plugins[name]) return cap.Plugins[name];
    } catch (e) {}
    return null;
  }

  function haptic(ms) {
    var h = nativePlugin('Haptics');
    if (h && h.vibrate) { try { h.vibrate({ duration: ms }); return; } catch (e) {} }
    try { if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(ms); } catch (e) {}
  }

  function bindNative() {
    if (nativeBound) return;
    nativeTries++;
    var app = nativePlugin('App');
    var sb = nativePlugin('StatusBar');
    var splash = nativePlugin('SplashScreen');
    if (!app && !sb && !splash) {
      if (nativeTries < 3) root.setTimeout(bindNative, 1200);
      return;
    }
    nativeBound = true;
    if (app && app.addListener) {
      try {
        app.addListener('backButton', function () {
          if (STATE === 'idle') { try { app.exitApp(); } catch (e) {} }
          else if (typeof cb === 'function') { try { cb('back'); } catch (e) {} }
        });
      } catch (e) {}
    }
    if (sb && sb.hide) { try { sb.hide(); } catch (e) {} }
    if (splash && splash.hide) { try { splash.hide(); } catch (e) {} }
  }

  /* --------------------------- Geometri --------------------------- */

  function blockHue(i) {
    if (!def) return (skinHue + i * 12) % 360;
    if (def.modifier === 'altin') return (42 + (i % 3) * 8) % 360;
    return (skinHue + i * 12) % 360;
  }

  function resize() {
    var prevBase = baseW;
    dpr = Math.min(root.devicePixelRatio || 1, 2);
    W = Math.max(320, root.innerWidth);
    H = Math.max(400, root.innerHeight);
    if (!canvas) return;
    canvas.width = Math.round(W * dpr);
    canvas.height = Math.round(H * dpr);
    canvas.style.width = W + 'px';
    canvas.style.height = H + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    scale = clamp(Math.min(W / 460, H / 780), 0.6, 1.6);
    bh = Math.round(24 * scale);
    baseW = clamp(230 * scale, 120, 320);
    depthX = 16 * scale;
    depthY = -9 * scale;
    groundY = H * 0.88;
    topLimit = H * 0.30;

    if (prevBase && baseW !== prevBase && blocks.length) {
      var f = baseW / prevBase;
      for (var i = 0; i < blocks.length; i++) { blocks[i].x *= f; blocks[i].w *= f; }
      if (moving) { moving.x *= f; moving.w *= f; }
    }
    makeAmbience();
  }

  function makeAmbience() {
    stars = [];
    var n = Math.round((W * H) / 13000);
    for (var i = 0; i < n; i++) {
      stars.push({ x: Math.random() * W, y: Math.random() * H, r: Math.random() * 1.5 + 0.4, p: Math.random() * 6.28, s: 0.5 + Math.random() * 1.6 });
    }
    makeWeather();
    makeSilhouette();
    makeClouds();
    makeForeground();
  }

  /* Yüzen bulutlar (canlı arka plan) */
  function makeClouds() {
    clouds = [];
    var n = 5;
    for (var i = 0; i < n; i++) {
      clouds.push({
        x: Math.random() * W,
        y: H * (0.05 + Math.random() * 0.3),
        rx: (70 + Math.random() * 120),
        ry: (18 + Math.random() * 22),
        a: 0.05 + Math.random() * 0.07,
        sp: (4 + Math.random() * 10) * (Math.random() < 0.5 ? 1 : -1)
      });
    }
  }

  /* Ön plan bulanık küteleri (derinlik hissi) */
  function makeForeground() {
    fgBits = [];
    for (var i = 0; i < 3; i++) {
      fgBits.push({
        x: (i === 0 ? 0 : i === 1 ? W : W * 0.5) + (Math.random() - 0.5) * 60,
        y: H * (0.88 + Math.random() * 0.1),
        r: 90 + Math.random() * 120,
        ph: Math.random() * 6.28
      });
    }
  }

  /* Tema hava efekti: kar/kum/kıvılcım/yaprak/yıldız */
  function makeWeather() {
    weather = [];
    if (!def) return;
    var kind = def.theme.weather || 'stars';
    var count = kind === 'stars' ? 0 : Math.round(W / 12);
    for (var i = 0; i < count; i++) weather.push(newWeatherBit(kind, true));
  }

  function newWeatherBit(kind, anywhere) {
    var y = anywhere ? Math.random() * H : -20;
    var bit = { kind: kind, x: Math.random() * W, y: y, r: 1 + Math.random() * 2.6, sp: 20 + Math.random() * 70, ph: Math.random() * 6.28, a: 0.25 + Math.random() * 0.5 };
    if (kind === 'embers') { bit.y = anywhere ? Math.random() * H : H + 20; bit.sp = -(30 + Math.random() * 60); }
    return bit;
  }

  /* Tema silüeti (ufuk manzarası) */
  function makeSilhouette() {
    silhouettes = [];
    if (!def) return;
    var kind = def.theme.silhouette || 'city';
    var layer, k;
    for (layer = 0; layer < 2; layer++) {
      var pts = [];
      var base = H * (0.94 - layer * 0.03);
      var x = -40;
      var rnd = mulberry(def.theme.id.charCodeAt(0) * 97 + layer * 13 + def.stage);
      while (x < W + 60) {
        var w = 40 + rnd() * 90;
        var hgt = (kind === 'city' ? 40 + rnd() * 150 :
                   kind === 'trees' ? 50 + rnd() * 120 :
                   kind === 'dunes' ? 10 + rnd() * 40 :
                   kind === 'ice' ? 60 + rnd() * 140 :
                   kind === 'volcano' ? 60 + rnd() * 170 : 20 + rnd() * 80) * (layer ? 0.7 : 1);
        if (kind === 'dunes') {
          pts.push({ type: 'hill', x: x, w: w * 1.6, h: hgt });
          x += w * 1.1;
        } else if (kind === 'trees') {
          pts.push({ type: 'tree', x: x, w: w * 0.5, h: hgt });
          x += w * 0.7;
        } else {
          pts.push({ type: 'block', x: x, w: w, h: hgt });
          x += w + 6;
        }
      }
      silhouettes.push({ pts: pts, base: base, layer: layer });
    }
  }

  function mulberry(a) {
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  /* --------------------------- Oyun akışı --------------------------- */

  function resetWorld() {
    blocks = [{ x: W / 2 - baseW / 2, w: baseW }];
    camShift = 0; score = 0; combo = 0; perfects = 0; misses = 0;
    shake = 0; debris = []; particles = []; rings = []; popups = []; confetti = [];
    endTimer = 0; endEvent = null;
    spawnMoving();
  }

  function spawnMoving() {
    var top = blocks[blocks.length - 1];
    var b = movingBounds(top);
    var fromLeft = blocks.length % 2 === 1;
    moving = { w: top.w, x: fromLeft ? b.minX : b.maxX, dir: fromLeft ? 1 : -1 };
  }

  function startLevel(d, opts, callback) {
    def = d;
    cb = callback || function () {};
    skinHue = (opts && opts.hue !== undefined) ? opts.hue : 200;
    shieldsLeft = (opts && opts.shields !== undefined) ? opts.shields : 1;   // her bölümde 1 ikinci şans
    slowTimer = 0;
    STATE = 'playing';
    resize();
    resetWorld();
    makeWeather();
    makeSilhouette();
    playStart();
    cb('ready', { def: def });
  }

  function stopLevel() {
    STATE = 'idle';
    def = null;
    moving = null;
    cb = function () {};
  }

  function growthAllowed() {
    return def && def.modifier !== 'hizli' && def.modifier !== 'patron';
  }

  function drop() {
    if (STATE !== 'playing' || !moving) return;
    unlockAudio();
    var top = blocks[blocks.length - 1];
    var idx = blocks.length;
    var y = movingY();
    var res = resolveDrop(moving, top, def.tol || PERFECT_TOLERANCE);

    if (!res.ok) {
      /* KALKAN: ilk kaçırmayı kurtar (daralmış blokla devam) */
      if (shieldsLeft > 0) {
        shieldsLeft--;
        var t0 = blocks[blocks.length - 1];
        var rw = Math.max(t0.w * 0.82, MIN_BLOCK_WIDTH * scale * 1.6);
        blocks.push({ x: t0.x + (t0.w - rw) / 2, w: rw });
        score = blocks.length - 1;
        combo = 0;
        rings.push({ x: t0.x + t0.w / 2, y: y + bh / 2, r: rw * 0.6, life: 0, max: 0.7, hue: 190 });
        burst(t0.x + t0.w / 2, y + bh / 2, rw, 190, 26);
        popup('KALKAN KORUDU!', t0.x + t0.w / 2, y - 18 * scale, 190);
        shake = 15;
        slowTimer = 0.55;                 // dramatik ağır çekim
        playShield();
        haptic(45);
        spawnMoving();
        cb('place', { perfect: false, combo: 0, score: score, rescued: true });
        cb('shield', { left: shieldsLeft });
        if (def.target > 0 && score >= def.target) {
          STATE = 'won';
          celebration();
          playWin();
          endEvent = { name: 'win', payload: resultPayload() };
          endTimer = 0.95;
        }
        return;
      }
      debris.push({ x: moving.x, y: y, w: moving.w, h: bh, vx: 0, vy: -90 * scale, rot: 0, vr: (Math.random() < 0.5 ? -1 : 1) * (2 + Math.random() * 3), hue: blockHue(idx), life: 0 });
      moving = null;
      misses++;
      playLose();
      haptic(60);
      shake = 20;
      endEvent = { name: 'lose', payload: resultPayload() };
      endTimer = 0.55;
      STATE = 'lost';
      return;
    }

    if (res.perfect) {
      combo++;
      perfects++;
      var w = growthAllowed() ? growthWidth(res.placed.w, baseW, combo) : res.placed.w;
      var x = res.placed.x - (w - res.placed.w) / 2;
      blocks.push({ x: x, w: w });
      var hue = blockHue(idx);
      burst(x + w / 2, y, w, hue, 22 + Math.min(26, combo * 3));
      rings.push({ x: x + w / 2, y: y + bh / 2, r: w * 0.3, life: 0, max: 0.5, hue: hue });
      popup(combo > 1 ? 'MÜKEMMEL ×' + combo : 'MÜKEMMEL', x + w / 2, y - 12 * scale, hue);
      if (def.modifier === 'altin') {
        coinBurst(x + w / 2, y, 4 + Math.min(8, combo));
        playCoin();
      }
      shake = Math.min(13, 4 + combo * 0.8);
      playPerfect(combo);
      haptic(12);
    } else {
      combo = 0;
      blocks.push(res.placed);
      for (var i = 0; i < res.cuts.length; i++) {
        var c = res.cuts[i];
        debris.push({ x: c.x, y: y, w: c.w, h: bh, vx: 0, vy: -40 * scale, rot: 0, vr: (Math.random() < 0.5 ? -1 : 1) * (2.5 + Math.random() * 3.5), hue: blockHue(idx), life: 0 });
        burst(c.x + c.w / 2, y + bh / 2, c.w, blockHue(idx), 10);
      }
      shake = Math.min(7, 2 + res.cuts.length * 2);
      playPlace();
    }

    score = blocks.length - 1;
    bestRun = Math.max(bestRun, score);
    spawnMoving();
    cb('place', { perfect: res.perfect, combo: combo, score: score });

    if (blocks[blocks.length - 1].w < MIN_BLOCK_WIDTH * scale) {
      playLose();
      haptic(60);
      endEvent = { name: 'lose', payload: resultPayload() };
      endTimer = 0.5;
      STATE = 'lost';
      return;
    }

    if (def.target > 0 && score >= def.target) {
      STATE = 'won';
      celebration();
      playWin();
      haptic(30);
      endEvent = { name: 'win', payload: resultPayload() };
      endTimer = 0.95;
    }
  }

  function resultPayload() {
    return { blocks: score, perfects: perfects, reached: STATE === 'won' };
  }

  /* Kutlama konfetisi */
  function celebration() {
    for (var i = 0; i < 120; i++) {
      confetti.push({
        x: Math.random() * W,
        y: -20 - Math.random() * H * 0.3,
        vx: (Math.random() - 0.5) * 120,
        vy: 120 + Math.random() * 220,
        rot: Math.random() * 6.28,
        vr: (Math.random() - 0.5) * 8,
        w: (5 + Math.random() * 7) * scale,
        h: (8 + Math.random() * 9) * scale,
        hue: (skinHue + Math.random() * 200) % 360,
        life: 0, max: 1.8 + Math.random()
      });
    }
  }

  function coinBurst(cx, cy, n) {
    for (var i = 0; i < n; i++) {
      particles.push({ x: cx + (Math.random() - 0.5) * 40, y: cy, vx: (Math.random() - 0.5) * 200, vy: -(120 + Math.random() * 240), life: 0, max: 0.7, size: 6 * scale, hue: 48, coin: true });
    }
  }

  function burst(cx, cy, w, hue, count) {
    for (var i = 0; i < count; i++) {
      particles.push({ x: cx + (Math.random() - 0.5) * w, y: cy, vx: (Math.random() - 0.5) * 360 * scale, vy: -(70 + Math.random() * 280) * scale, life: 0, max: 0.4 + Math.random() * 0.45, size: (2.5 + Math.random() * 4) * scale, hue: hue });
    }
  }

  function popup(text, x, y, hue) {
    popups.push({ text: text, x: x, y: y, hue: hue, life: 0, max: 0.9 });
  }

  /* --------------------------- Güncelleme --------------------------- */

  function movingY() { return groundY - blocks.length * bh + camShift; }
  function topY() { return groundY - (blocks.length - 1) * bh + camShift; }

  function tick(dt) {
    if (slowTimer > 0) { slowTimer -= dt; dt *= 0.35; }   // ağır çekim anı
    time += dt;
    hueDrift = (hueDrift + dt * 4) % 360;

    var camTarget = Math.max(0, topLimit - groundY + blocks.length * bh);
    camShift += (camTarget - camShift) * Math.min(1, dt * 10);

    if (moving && (STATE === 'playing')) {
      var top = blocks[blocks.length - 1];
      var placed = blocks.length - 1;
      var speedScale = def ? def.speed : 1;
      /* AKAN: hız dalgalanır · DEPREM: periyodik sarsıntı */
      if (def && def.modifier === 'akan') speedScale *= (1 + 0.55 * Math.sin(time * 2.6));
      if (def && def.modifier === 'deprem') {
        var q1 = Math.floor(time / 2.2), q0 = Math.floor((time - dt) / 2.2);
        if (q1 !== q0) shake = Math.max(shake, 11 + Math.random() * 7);
      }
      stepMoving(moving, top, placed, dt, speedScale);
      if (def && def.modifier === 'ruzgar') {
        var b = movingBounds(top);
        moving.x += Math.sin(time * 2.1) * travelRange(top.w) * 0.14 * dt * 6;
        moving.x = clamp(moving.x, b.minX, b.maxX);
      }
    }

    if (endTimer > 0) {
      endTimer -= dt;
      if (endTimer <= 0 && endEvent) {
        var e = endEvent; endEvent = null;
        cb(e.name, e.payload);
      }
    }

    shake = Math.max(0, shake - dt * 55);

    var i;
    for (i = debris.length - 1; i >= 0; i--) {
      var d = debris[i];
      d.vy += 1500 * scale * dt; d.y += d.vy * dt; d.rot += d.vr * dt; d.life += dt;
      if (d.y > H + 300) debris.splice(i, 1);
    }
    for (i = particles.length - 1; i >= 0; i--) {
      var p = particles[i];
      p.vy += 900 * scale * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.life += dt;
      if (p.life >= p.max) particles.splice(i, 1);
    }
    for (i = rings.length - 1; i >= 0; i--) {
      var r = rings[i]; r.life += dt; r.r += 340 * scale * dt;
      if (r.life >= r.max) rings.splice(i, 1);
    }
    for (i = popups.length - 1; i >= 0; i--) {
      var q = popups[i]; q.life += dt; q.y -= 42 * scale * dt;
      if (q.life >= q.max) popups.splice(i, 1);
    }
    for (i = confetti.length - 1; i >= 0; i--) {
      var cf = confetti[i];
      cf.vy += 60 * dt; cf.x += cf.vx * dt; cf.y += cf.vy * dt; cf.rot += cf.vr * dt; cf.life += dt;
      if (cf.life >= cf.max || cf.y > H + 40) confetti.splice(i, 1);
    }
    for (i = 0; i < weather.length; i++) {
      var wb = weather[i];
      wb.y += wb.sp * dt;
      wb.x += Math.sin(time * 0.8 + wb.ph) * 14 * dt;
      if (wb.kind === 'embers') { if (wb.y < -20) weather[i] = newWeatherBit(wb.kind, false); }
      else if (wb.y > H + 20) weather[i] = newWeatherBit(wb.kind, false);
    }
    for (i = 0; i < clouds.length; i++) {
      var cl = clouds[i];
      cl.x += cl.sp * dt;
      if (cl.x > W + cl.rx) cl.x = -cl.rx;
      if (cl.x < -cl.rx) cl.x = W + cl.rx;
    }
  }

  /* ------------------------------ Çizim ------------------------------ */

  function roundRectPath(x, y, w, h, r) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function theme() { return (def && def.theme) || { bg: ['#0c0a20', '#1e1046'], glow: 268, weather: 'stars' }; }

  /* ---------------- renk yardımcıları (zengin gökyüzü için) ---------------- */

  function hexRgb(hex) {
    var h = String(hex).replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  function mixRgb(a, b, k) {
    return [Math.round(a[0] + (b[0] - a[0]) * k),
            Math.round(a[1] + (b[1] - a[1]) * k),
            Math.round(a[2] + (b[2] - a[2]) * k)];
  }

  function rgba(c, a) { return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'; }

  function hslRgb(h, s, l) {
    h = ((h % 360) + 360) % 360; s /= 100; l /= 100;
    var c = (1 - Math.abs(2 * l - 1)) * s;
    var x = c * (1 - Math.abs((h / 60) % 2 - 1));
    var m = l - c / 2;
    var r = 0, g = 0, b = 0;
    if (h < 60) { r = c; g = x; }
    else if (h < 120) { r = x; g = c; }
    else if (h < 180) { g = c; b = x; }
    else if (h < 240) { g = x; b = c; }
    else if (h < 300) { r = x; b = c; }
    else { r = c; b = x; }
    return [Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255)];
  }

  /* ------------------------------ gökyüzü ------------------------------ */

  function drawBackground() {
    var t = theme();
    var c0 = hexRgb(t.bg[0]);
    var c1 = hexRgb(t.bg[1]);
    var gl = hslRgb(t.glow, 92, 60);
    var deep = [4, 4, 15];

    var g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, rgba(mixRgb(deep, c0, 0.45), 1));
    g.addColorStop(0.42, rgba(c0, 1));
    g.addColorStop(0.76, rgba(c1, 1));
    g.addColorStop(1, rgba(mixRgb(c1, gl, 0.3), 1));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    /* aurora */
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    for (var a = 0; a < 2; a++) {
      var ay = H * (0.18 + a * 0.09) + Math.sin(time * 0.3 + a) * 8 - camShift * 0.02;
      var ag = ctx.createLinearGradient(0, ay - 70, 0, ay + 90);
      ag.addColorStop(0, rgba(gl, 0));
      ag.addColorStop(0.5, rgba(gl, 0.055));
      ag.addColorStop(1, rgba(gl, 0));
      ctx.strokeStyle = ag;
      ctx.lineWidth = 70 + a * 40;
      ctx.beginPath();
      ctx.moveTo(-40, ay);
      ctx.bezierCurveTo(W * 0.32, ay - 50, W * 0.68, ay + 65, W + 40, ay - 12);
      ctx.stroke();
    }
    ctx.restore();

    drawMoon(t, gl);
    drawDistantIslands(t, gl);

    ctx.save();
    for (var i = 0; i < stars.length; i++) {
      var s = stars[i];
      ctx.globalAlpha = 0.18 + 0.55 * (0.5 + 0.5 * Math.sin(time * s.s + s.p));
      ctx.fillStyle = s.r > 1.4 ? '#fff3d4' : '#d6e8ff';
      if (s.r > 1.55) {
        ctx.fillRect(s.x - 4, s.y - 0.5, 8, 1);
        ctx.fillRect(s.x - 0.5, s.y - 4, 1, 8);
      }
      ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();

    drawSilhouette();
    drawCloudSea(t, gl);
    drawClouds();
    drawWeather();
    drawConstellation();
  }

  function drawMoon(t, gl) {
    var mx = W * 0.79;
    var my = H * 0.16 - camShift * 0.012;
    var mr = Math.min(W, H) * 0.085;
    ctx.save();
    var halo = ctx.createRadialGradient(mx, my, mr * 0.2, mx, my, mr * 2.7);
    halo.addColorStop(0, rgba(gl, 0.34));
    halo.addColorStop(0.45, rgba(gl, 0.10));
    halo.addColorStop(1, rgba(gl, 0));
    ctx.fillStyle = halo;
    ctx.beginPath(); ctx.arc(mx, my, mr * 2.7, 0, Math.PI * 2); ctx.fill();

    var disc = ctx.createRadialGradient(mx - mr * 0.32, my - mr * 0.35, mr * 0.1, mx, my, mr);
    disc.addColorStop(0, rgba(mixRgb(gl, [255, 255, 255], 0.5), 0.9));
    disc.addColorStop(0.62, rgba(gl, 0.55));
    disc.addColorStop(1, rgba(mixRgb(gl, hexRgb(t.bg[0]), 0.55), 0.18));
    ctx.fillStyle = disc;
    ctx.beginPath(); ctx.arc(mx, my, mr, 0, Math.PI * 2); ctx.fill();

    ctx.globalAlpha = 0.3;
    ctx.strokeStyle = rgba(gl, 0.7);
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.ellipse(mx, my, mr * 1.7, mr * 0.34, -0.4, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function drawDistantIslands(t, gl) {
    var list = [
      { x: W * 0.13, y: H * 0.5, r: W * 0.12, seed: 2 },
      { x: W * 0.93, y: H * 0.58, r: W * 0.16, seed: 5 },
      { x: W * 0.03, y: H * 0.7, r: W * 0.09, seed: 9 }
    ];
    var par = camShift * 0.03;
    for (var i = 0; i < list.length; i++) {
      var d = list[i];
      var y = d.y + par;
      if (y > H + 120) continue;
      var base = hexRgb(t.bg[1]);
      ctx.save();
      ctx.globalAlpha = 0.85;
      ctx.fillStyle = rgba(mixRgb(base, [5, 5, 15], 0.52), 1);
      ctx.beginPath();
      var N = 9;
      for (var k = 0; k < N; k++) {
        var a = k / N * Math.PI * 2;
        var rr = d.r * (0.72 + 0.25 * Math.sin(k * 2.1 + d.seed));
        var px = d.x + Math.cos(a) * rr;
        var py = y + Math.sin(a) * rr * 0.3;
        if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
      }
      ctx.closePath();
      ctx.fill();
      /* üst kenarda ince ışık */
      ctx.strokeStyle = rgba(gl, 0.22);
      ctx.lineWidth = 1.1;
      ctx.stroke();
      /* alt kaya */
      ctx.beginPath();
      ctx.moveTo(d.x - d.r * 0.55, y + 4);
      ctx.lineTo(d.x, y + d.r * 0.62);
      ctx.lineTo(d.x + d.r * 0.55, y + 4);
      ctx.closePath();
      ctx.fill();
      /* yumuşak üst ışık */
      var hg2 = ctx.createRadialGradient(d.x, y, 2, d.x, y, d.r * 0.9);
      hg2.addColorStop(0, rgba(gl, 0.10));
      hg2.addColorStop(1, rgba(gl, 0));
      ctx.fillStyle = hg2;
      ctx.beginPath(); ctx.ellipse(d.x, y, d.r * 0.85, d.r * 0.28, 0, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  }

  function drawCloudSea(t, gl) {
    var y0 = H * 0.79 + camShift * 0.05;
    var base = hexRgb(t.bg[1]);
    ctx.save();
    var g = ctx.createLinearGradient(0, y0 - 40, 0, H);
    g.addColorStop(0, rgba(mixRgb(base, gl, 0.25), 0));
    g.addColorStop(0.45, rgba(mixRgb(base, gl, 0.32), 0.16));
    g.addColorStop(1, rgba(mixRgb(base, [5, 5, 14], 0.35), 0.5));
    ctx.fillStyle = g;
    ctx.fillRect(0, y0 - 40, W, H - y0 + 40);
    for (var i = 0; i < 6; i++) {
      var x = W * (0.1 + i * 0.18) + Math.sin(time * 0.12 + i) * 14;
      var y = y0 + (i % 3) * 24;
      var rx = W * (0.24 + (i % 2) * 0.08);
      var rg = ctx.createRadialGradient(x, y, 0, x, y, rx);
      rg.addColorStop(0, rgba(gl, 0.05));
      rg.addColorStop(0.6, rgba(mixRgb(base, [220, 235, 255], 0.5), 0.05));
      rg.addColorStop(1, rgba(base, 0));
      ctx.fillStyle = rg;
      ctx.beginPath(); ctx.ellipse(x, y, rx, rx * 0.22, 0, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();
  }

  function drawClouds() {
    if (!clouds.length) return;
    ctx.save();
    for (var i = 0; i < clouds.length; i++) {
      var c = clouds[i];
      var rg = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, c.rx);
      rg.addColorStop(0, 'rgba(220,235,255,' + (c.a * 0.9) + ')');
      rg.addColorStop(0.55, 'rgba(205,225,255,' + (c.a * 0.5) + ')');
      rg.addColorStop(1, 'rgba(200,220,255,0)');
      ctx.fillStyle = rg;
      ctx.beginPath();
      ctx.ellipse(c.x, c.y, c.rx, c.ry, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  /* Ön plan: kule önünden geçen bulanık küteler — derinlik katmanı */
  function drawForeground() {
    if (!fgBits.length) return;
    ctx.save();
    ctx.globalAlpha = 0.5;
    ctx.fillStyle = 'rgba(4,4,14,0.75)';
    ctx.filter = 'blur(2px)';
    for (var i = 0; i < fgBits.length; i++) {
      var f = fgBits[i];
      var sway = Math.sin(time * 0.5 + f.ph) * 8;
      ctx.beginPath();
      ctx.ellipse(f.x + sway, f.y, f.r, f.r * 0.45, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.filter = 'none';
    ctx.restore();
  }

  /* Gökyüzü takımyıldızı: topladığın yıldızlar gökte yanar (konseptin ödülü) */
  function drawConstellation() {
    if (progressStars <= 0) return;
    var TOTAL = 450;                       // 10 bölüm × 15 × 3 yıldız
    var lit = Math.min(42, Math.max(1, Math.round(progressStars / TOTAL * 42)));
    var pts = [];
    for (var i = 0; i < 42; i++) {
      var rnd = mulberry(i * 977 + 5);
      pts.push({ x: W * (0.08 + rnd() * 0.84), y: H * (0.03 + rnd() * 0.22) });
    }
    ctx.save();
    ctx.strokeStyle = 'rgba(170,205,255,0.22)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (i = 0; i < lit; i++) {
      if (i === 0) ctx.moveTo(pts[i].x, pts[i].y);
      else ctx.lineTo(pts[i].x, pts[i].y);
    }
    ctx.stroke();
    for (i = 0; i < lit; i++) {
      var p = pts[i];
      var tw = 0.65 + 0.35 * Math.sin(time * 2 + i);
      ctx.globalAlpha = tw;
      ctx.shadowColor = 'rgba(255,240,180,0.9)';
      ctx.shadowBlur = 10;
      ctx.fillStyle = '#fff3c4';
      ctx.beginPath();
      ctx.arc(p.x, p.y, 2.4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawSilhouette() {
    var t = theme();
    for (var L = 0; L < silhouettes.length; L++) {
      var lay = silhouettes[L];
      /* paralaks: kamera yükseldikçe uzak katman geç kayar */
      var par = -camShift * (lay.layer ? 0.05 : 0.1);
      ctx.save();
      ctx.translate(0, par);
      ctx.globalAlpha = lay.layer ? 0.95 : 0.8;
      ctx.fillStyle = 'hsl(' + t.glow + ',46%,' + (lay.layer ? 6 : 9) + '%)';
      for (var i = 0; i < lay.pts.length; i++) {
        var p = lay.pts[i];
        if (p.type === 'tree') {
          ctx.beginPath();
          ctx.moveTo(p.x, lay.base);
          ctx.lineTo(p.x + p.w / 2, lay.base - p.h);
          ctx.lineTo(p.x + p.w, lay.base);
          ctx.closePath(); ctx.fill();
          if (lay.layer) {
            ctx.fillStyle = 'hsla(' + t.glow + ',90%,72%,0.35)';
            ctx.beginPath(); ctx.arc(p.x + p.w / 2, lay.base - p.h + 1, 1.4, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = 'hsl(' + t.glow + ',46%,' + (lay.layer ? 6 : 9) + '%)';
          }
        } else if (p.type === 'hill') {
          ctx.beginPath();
          ctx.moveTo(p.x, lay.base);
          ctx.quadraticCurveTo(p.x + p.w / 2, lay.base - p.h, p.x + p.w, lay.base);
          ctx.closePath(); ctx.fill();
          if (lay.layer) {
            ctx.strokeStyle = 'hsla(' + t.glow + ',90%,70%,0.18)';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(p.x, lay.base);
            ctx.quadraticCurveTo(p.x + p.w / 2, lay.base - p.h, p.x + p.w, lay.base);
            ctx.stroke();
          }
        } else if (p.type === 'block') {
          ctx.fillRect(p.x, lay.base - p.h, p.w, p.h + 60);
          /* çatı kenarı */
          ctx.fillStyle = 'hsla(' + t.glow + ',90%,66%,0.22)';
          ctx.fillRect(p.x, lay.base - p.h, p.w, 1.4);
          /* pencere ışıkları */
          if (lay.layer) {
            var cols = Math.max(1, Math.floor(p.w / 14));
            var rows = Math.min(7, Math.max(1, Math.floor(p.h / 20)));
            for (var c = 0; c < cols; c++) {
              for (var r = 0; r < rows; r++) {
                if ((i * 5 + c * 3 + r) % 4 === 0) continue;
                var wa = 0.12 + (((i + c + r) % 5) * 0.05);
                ctx.fillStyle = 'rgba(255,226,160,' + wa + ')';
                ctx.fillRect(p.x + 5 + c * 14, lay.base - p.h + 7 + r * 16, 3, 4);
              }
            }
            ctx.fillStyle = 'hsla(' + t.glow + ',46%,6%,1)';
          }
        } else {
          ctx.beginPath();
          ctx.moveTo(p.x, lay.base + 20);
          ctx.lineTo(p.x + p.w / 2, lay.base - p.h);
          ctx.lineTo(p.x + p.w, lay.base + 20);
          ctx.closePath(); ctx.fill();
        }
      }
      ctx.restore();
    }
  }

  function drawWeather() {
    if (!weather.length) return;
    var t = theme();
    ctx.save();
    for (var i = 0; i < weather.length; i++) {
      var b = weather[i];
      ctx.globalAlpha = b.a;
      if (b.kind === 'snow') { ctx.fillStyle = '#dff3ff'; ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2); ctx.fill(); }
      else if (b.kind === 'sand') { ctx.fillStyle = 'hsl(' + t.glow + ',80%,70%)'; ctx.fillRect(b.x, b.y, b.r * 1.6, b.r); }
      else if (b.kind === 'embers') { ctx.fillStyle = 'hsl(' + (10 + (i % 3) * 12) + ',100%,60%)'; ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2); ctx.fill(); }
      else if (b.kind === 'leaves') { ctx.fillStyle = 'hsl(' + (110 + (i % 4) * 14) + ',70%,55%)'; ctx.fillRect(b.x, b.y, b.r * 2, b.r); }
      else { ctx.fillStyle = '#cfe4ff'; ctx.beginPath(); ctx.arc(b.x, b.y, b.r * 0.8, 0, Math.PI * 2); ctx.fill(); }
    }
    ctx.restore();
  }

  function drawGround() {
    if (!blocks.length) return;
    var base = blocks[0];
    var bottom = groundY + bh + camShift;
    if (bottom > H + 160) return;
    var cx = base.x + base.w / 2;
    var half = Math.max(base.w * 0.72, 132 * scale);
    var ry = Math.max(16, 28 * scale);
    var t = theme();
    var glow = t.glow;
    var deep = Math.max(60, 78 * scale);

    ctx.save();
    /* platform arkasındaki ışık */
    var halo = ctx.createRadialGradient(cx, bottom + 10, 4, cx, bottom + 10, half * 1.25);
    halo.addColorStop(0, 'hsla(' + glow + ',90%,62%,0.22)');
    halo.addColorStop(1, 'hsla(' + glow + ',90%,62%,0)');
    ctx.fillStyle = halo;
    ctx.beginPath(); ctx.ellipse(cx, bottom + 10, half * 1.25, ry * 1.8, 0, 0, Math.PI * 2); ctx.fill();

    /* alt kaya */
    var ug = ctx.createLinearGradient(0, bottom - 4, 0, bottom + deep);
    ug.addColorStop(0, 'hsl(' + glow + ',42%,16%)');
    ug.addColorStop(1, 'hsl(' + glow + ',38%,4%)');
    ctx.fillStyle = ug;
    ctx.beginPath();
    ctx.moveTo(cx - half, bottom - 4);
    ctx.quadraticCurveTo(cx - half * 0.55, bottom + deep * 0.9, cx, bottom + deep);
    ctx.quadraticCurveTo(cx + half * 0.55, bottom + deep * 0.9, cx + half, bottom - 4);
    ctx.closePath();
    ctx.fill();

    /* üst yüzey */
    var tg = ctx.createRadialGradient(cx, bottom - ry * 0.2, 4, cx, bottom, half);
    tg.addColorStop(0, 'hsl(' + glow + ',52%,24%)');
    tg.addColorStop(0.7, 'hsl(' + glow + ',48%,14%)');
    tg.addColorStop(1, 'hsl(' + glow + ',44%,8%)');
    ctx.fillStyle = tg;
    ctx.beginPath(); ctx.ellipse(cx, bottom - 5, half, ry, 0, 0, Math.PI * 2); ctx.fill();

    ctx.strokeStyle = 'hsla(' + glow + ',95%,68%,0.55)';
    ctx.lineWidth = Math.max(1, 1.8 * scale);
    ctx.shadowColor = 'hsla(' + glow + ',95%,62%,0.7)';
    ctx.shadowBlur = 16 * scale;
    ctx.stroke();
    ctx.shadowBlur = 0;

    /* iç halka */
    ctx.strokeStyle = 'hsla(' + glow + ',80%,60%,0.16)';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.ellipse(cx, bottom - 5, half * 0.6, ry * 0.6, 0, 0, Math.PI * 2); ctx.stroke();

    /* kule gölgesi */
    var sg = ctx.createRadialGradient(cx, bottom - 3, 2, cx, bottom - 3, base.w * 0.6);
    sg.addColorStop(0, 'rgba(0,0,0,0.5)');
    sg.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = sg;
    ctx.beginPath(); ctx.ellipse(cx, bottom - 3, base.w * 0.6, ry * 0.5, 0, 0, Math.PI * 2); ctx.fill();

    /* kenar kristalleri */
    for (var i = 0; i < 2; i++) {
      var sx = cx + (i === 0 ? -half * 0.82 : half * 0.82);
      var sh = 16 * scale + i * 7;
      ctx.fillStyle = 'hsla(' + glow + ',90%,68%,0.5)';
      ctx.beginPath();
      ctx.moveTo(sx, bottom - ry * 0.4 - sh);
      ctx.lineTo(sx + 4 * scale, bottom - ry * 0.4);
      ctx.lineTo(sx - 4 * scale, bottom - ry * 0.4);
      ctx.closePath(); ctx.fill();
    }
    ctx.restore();
  }

  /* kulenin arkasına düşen tema ışığı */
  function drawTowerBeam() {
    if (!blocks.length) return;
    var base = blocks[0];
    var cx = base.x + base.w / 2;
    var y0 = groundY + bh + camShift;
    var y1 = Math.max(-20, y0 - Math.max(320 * scale, blocks.length * bh + 180));
    if (y0 < 0) return;
    var t = theme();
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    var g = ctx.createLinearGradient(0, y0, 0, y1);
    g.addColorStop(0, 'hsla(' + t.glow + ',95%,62%,0.13)');
    g.addColorStop(0.55, 'hsla(' + t.glow + ',95%,62%,0.05)');
    g.addColorStop(1, 'hsla(' + t.glow + ',95%,62%,0)');
    ctx.fillStyle = g;
    ctx.fillRect(cx - base.w * 0.62, y1, base.w * 1.24, y0 - y1);
    ctx.restore();
  }

  function drawBlock(x, y, w, h, hue) {
    if (y > H + h || y + h + depthY < -h) return;
    var r = Math.min(5 * scale, h / 3);

    /* sağ yan */
    var side = ctx.createLinearGradient(x + w, y + depthY, x + w + depthX, y + h);
    side.addColorStop(0, 'hsl(' + hue + ',76%,34%)');
    side.addColorStop(1, 'hsl(' + hue + ',70%,22%)');
    ctx.beginPath();
    ctx.moveTo(x + w, y);
    ctx.lineTo(x + w + depthX, y + depthY);
    ctx.lineTo(x + w + depthX, y + depthY + h);
    ctx.lineTo(x + w, y + h);
    ctx.closePath();
    ctx.fillStyle = side;
    ctx.fill();

    /* ön yüz */
    var grad = ctx.createLinearGradient(x, y, x + w * 0.7, y + h);
    grad.addColorStop(0, 'hsl(' + hue + ',95%,66%)');
    grad.addColorStop(0.45, 'hsl(' + hue + ',90%,54%)');
    grad.addColorStop(1, 'hsl(' + hue + ',84%,40%)');
    ctx.fillStyle = grad;
    roundRectPath(x, y, w, h, r);
    ctx.fill();

    /* cam parlaması */
    var spec = ctx.createLinearGradient(x, y, x, y + h * 0.55);
    spec.addColorStop(0, 'rgba(255,255,255,0.22)');
    spec.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = spec;
    roundRectPath(x + 2 * scale, y + 1.5 * scale, w - 4 * scale, Math.max(3, h * 0.4), r * 0.7);
    ctx.fill();

    /* neon çerçeve */
    ctx.strokeStyle = 'hsla(' + hue + ',100%,82%,0.45)';
    ctx.lineWidth = Math.max(0.8, 1.1 * scale);
    roundRectPath(x + 0.5, y + 0.5, w - 1, h - 1, r);
    ctx.stroke();

    /* üst yüz */
    var topG = ctx.createLinearGradient(x, y + depthY, x + w, y);
    topG.addColorStop(0, 'hsl(' + hue + ',98%,82%)');
    topG.addColorStop(1, 'hsl(' + hue + ',96%,64%)');
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + depthX, y + depthY);
    ctx.lineTo(x + w + depthX, y + depthY);
    ctx.lineTo(x + w, y);
    ctx.closePath();
    ctx.fillStyle = topG;
    ctx.fill();
    ctx.strokeStyle = 'hsla(' + hue + ',100%,96%,0.5)';
    ctx.lineWidth = Math.max(0.6, 0.9 * scale);
    ctx.stroke();

    /* iç ışık çizgisi */
    ctx.strokeStyle = 'hsla(' + hue + ',100%,88%,0.35)';
    ctx.lineWidth = Math.max(0.6, 0.8 * scale);
    ctx.beginPath();
    ctx.moveTo(x + 4 * scale, y + h * 0.22);
    ctx.lineTo(x + 4 * scale, y + h * 0.9);
    ctx.stroke();
  }

  function drawVignette() {
    var g = ctx.createRadialGradient(W / 2, H * 0.45, Math.min(W, H) * 0.3, W / 2, H * 0.5, Math.max(W, H) * 0.82);
    g.addColorStop(0, 'rgba(0,0,0,0)');
    g.addColorStop(0.72, 'rgba(3,3,12,0.16)');
    g.addColorStop(1, 'rgba(3,3,12,0.55)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  }

  function drawAimShade() {
    if (!moving) return;
    var top = blocks[blocks.length - 1];
    var y = topY();
    var gx1 = clamp(moving.x, top.x, top.x + top.w);
    var gx2 = clamp(moving.x + moving.w, top.x, top.x + top.w);
    if (gx2 - gx1 < 1) return;
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(gx1, y);
    ctx.lineTo(gx1 + depthX, y + depthY);
    ctx.lineTo(gx2 + depthX, y + depthY);
    ctx.lineTo(gx2, y);
    ctx.closePath();
    ctx.clip();
    ctx.fillStyle = 'rgba(0,0,0,0.30)';
    ctx.fillRect(gx1 - 2, y + depthY - 2, (gx2 - gx1) + depthX + 4, -depthY + 4);
    ctx.restore();
  }

  function drawMoving() {
    if (!moving) return;
    var y = movingY();
    drawBlock(moving.x, y, moving.w, bh, blockHue(blocks.length));
    ctx.save();
    ctx.strokeStyle = 'rgba(255,255,255,0.45)';
    ctx.lineWidth = 1.2;
    roundRectPath(moving.x, y, moving.w, bh, Math.min(4 * scale, bh / 3));
    ctx.stroke();
    ctx.restore();
  }

  function drawDark() {
    if (!def || def.modifier !== 'karanlik') return;
    var cx = W / 2, cy = Math.min(movingY(), topY()) + bh;
    var r = Math.max(W, H) * 0.55;
    var g = ctx.createRadialGradient(cx, cy, r * 0.25, cx, cy, r);
    g.addColorStop(0, 'rgba(0,0,0,0)');
    g.addColorStop(0.6, 'rgba(0,0,0,0.55)');
    g.addColorStop(1, 'rgba(2,2,8,0.94)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  }

  function render() {
    if (!ctx) return;
    drawBackground();
    ctx.save();
    if (shake > 0.2) ctx.translate((Math.random() - 0.5) * shake, (Math.random() - 0.5) * shake);

    drawGround();
    drawTowerBeam();
    drawAimShade();
    for (var i = 0; i < blocks.length; i++) {
      drawBlock(blocks[i].x, groundY - i * bh + camShift, blocks[i].w, bh, blockHue(i));
    }
    if (STATE === 'playing') drawMoving();

    drawForeground();

    /* enkaz + efektler */
    var j;
    for (j = 0; j < debris.length; j++) {
      var d = debris[j];
      if (d.y > H + 200) continue;
      ctx.save();
      ctx.translate(d.x + d.w / 2, d.y + d.h / 2);
      ctx.rotate(d.rot);
      ctx.globalAlpha = Math.max(0, 1 - d.life * 0.5);
      ctx.fillStyle = 'hsl(' + d.hue + ',86%,52%)';
      roundRectPath(-d.w / 2, -d.h / 2, d.w, d.h, Math.min(4 * scale, d.h / 3));
      ctx.fill();
      ctx.restore();
    }
    for (j = 0; j < particles.length; j++) {
      var p = particles[j];
      var a = Math.max(0, 1 - p.life / p.max);
      ctx.globalAlpha = a;
      if (p.coin) {
        ctx.fillStyle = 'hsl(48,100%,62%)';
        ctx.beginPath(); ctx.arc(p.x, p.y, p.size / 2, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = 'hsl(38,90%,45%)'; ctx.lineWidth = 1.5; ctx.stroke();
      } else {
        ctx.fillStyle = 'hsl(' + p.hue + ',95%,72%)';
        ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
      }
    }
    ctx.globalAlpha = 1;
    for (j = 0; j < rings.length; j++) {
      var r2 = rings[j];
      var ra = Math.max(0, 1 - r2.life / r2.max);
      ctx.globalAlpha = ra * 0.8;
      ctx.strokeStyle = 'hsl(' + r2.hue + ',95%,75%)';
      ctx.lineWidth = 3 * scale * ra;
      ctx.beginPath(); ctx.arc(r2.x, r2.y, r2.r, 0, Math.PI * 2); ctx.stroke();
    }
    ctx.globalAlpha = 1;
    ctx.save();
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = '900 ' + Math.round(20 * scale) + 'px InterKule, system-ui, -apple-system, Segoe UI, Roboto, sans-serif';
    for (j = 0; j < popups.length; j++) {
      var q = popups[j];
      var qt = q.life / q.max;
      ctx.globalAlpha = qt < 0.15 ? qt / 0.15 : Math.max(0, 1 - (qt - 0.15) / 0.85);
      ctx.lineWidth = 5 * scale;
      ctx.strokeStyle = 'rgba(0,0,0,0.55)';
      ctx.strokeText(q.text, q.x, q.y);
      ctx.fillStyle = 'hsl(' + q.hue + ',100%,82%)';
      ctx.fillText(q.text, q.x, q.y);
    }
    ctx.restore();
    for (j = 0; j < confetti.length; j++) {
      var cf = confetti[j];
      ctx.save();
      ctx.translate(cf.x, cf.y);
      ctx.rotate(cf.rot);
      ctx.globalAlpha = Math.max(0, 1 - cf.life / cf.max);
      ctx.fillStyle = 'hsl(' + cf.hue + ',95%,65%)';
      ctx.fillRect(-cf.w / 2, -cf.h / 2, cf.w, cf.h);
      ctx.restore();
    }
    ctx.restore();

    drawVignette();
    drawDark();
  }

  /* ------------------------------ Döngü ------------------------------ */

  var lastT = 0;

  function frame(t) {
    if (!manualMode) root.requestAnimationFrame(frame);
    if (!lastT) lastT = t;
    var dt = Math.min(0.05, (t - lastT) / 1000);
    lastT = t;
    tick(dt);
    render();
  }

  function init(canvasEl, opts) {
    canvas = canvasEl;
    ctx = canvas.getContext('2d');
    manualMode = !!(opts && opts.manual);
    resize();
    makeAmbience();
    bindNative();
    root.addEventListener('resize', resize);
    root.addEventListener('orientationchange', function () { root.setTimeout(resize, 120); });
    if (!manualMode) root.requestAnimationFrame(frame);
    return API;
  }

  /* ------------------------------ API ------------------------------ */

  var API = {
    CORE: CORE,
    init: init,
    startLevel: startLevel,
    stopLevel: stopLevel,
    drop: drop,
    tick: tick,
    render: render,
    resize: resize,
    unlockAudio: unlockAudio,
    toggleMute: toggleMute,
    isMuted: function () { return muted; },
    haptic: haptic,
    getState: function () { return STATE; },
    getMoving: function () { return moving; },
    getTop: function () { return blocks.length ? blocks[blocks.length - 1] : null; },
    getBlocks: function () { return blocks; },
    getProgress: function () { return { placed: score, target: def ? def.target : 0, combo: combo, perfects: perfects }; },
    getShield: function () { return shieldsLeft; },
    setProgressStars: function (n) { progressStars = n || 0; },
    getProgressStars: function () { return progressStars; },
    setManual: function (m) { manualMode = !!m; }
  };

  if (root) root.NeonEngine = API;
  if (typeof module !== 'undefined' && module.exports) module.exports = CORE;
})(typeof globalThis !== 'undefined' ? globalThis : this);
