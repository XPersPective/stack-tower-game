/* ============================================================
   NEON KULE — YÜKSELİŞ HARİTASI (gerçek perspektifli 3B dünya)
   • 10 dünya = gökte yüzen dev adalar; yükseldikçe yukarı çıkarsın
   • Perspektif kamera: sürükle → yörünge, dikey sürükle → dünyalar
   • Her adada köy büyür, kristal bölüm düğümleri yanar
   • Derinlik: sis, bulut denizi, yıldızlar, aurora, parıltılar
   • Günlük meydan okuma adası dünyanın üstünde süzülür
   ============================================================ */
(function (root) {
  'use strict';

  var FOV = 52 * Math.PI / 180;
  var UP = { x: 0, y: 1, z: 0 };

  var canvas = null, ctx = null;
  var W = 0, H = 0, dpr = 1;
  var save = null, levels = null, prog = null;
  var onTapNode = null, onTapDaily = null, onFocus = null;

  var islands = [], byStage = [], nodes = [], daily = null;
  var focusStage = 0;
  var cam = { yaw: 0.55, pitch: 0.60, dist: 1420 };
  var focus = { x: 0, y: 0, z: 0 }, focusTo = { x: 0, y: 0, z: 0 };
  var eye = { x: 0, y: 0, z: 0 }, fwd = { x: 0, y: 0, z: 1 };
  var right = { x: 1, y: 0, z: 0 }, up = { x: 0, y: 1, z: 0 };
  var focal = 800, snap = true;
  var t = 0, lastTs = 0, running = false, started = false;
  var drag = null, yawVel = 0;
  var stars = [], puffs = [], ambient = [], farRocks = [];
  var islandParticles = [];

  /* ----------------------------- yardımcılar ----------------------------- */

  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }

  function hexRgb(hex) {
    var h = String(hex).replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  function mix(a, b, k) {
    return [Math.round(a[0] + (b[0] - a[0]) * k),
            Math.round(a[1] + (b[1] - a[1]) * k),
            Math.round(a[2] + (b[2] - a[2]) * k)];
  }

  function rgb(c, a) {
    return a === undefined ? 'rgb(' + c[0] + ',' + c[1] + ',' + c[2] + ')'
      : 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')';
  }

  function hsl(h, s, l, a) {
    return a === undefined ? 'hsl(' + h + ',' + s + '%,' + l + '%)'
      : 'hsla(' + h + ',' + s + '%,' + l + '%,' + a + ')';
  }

  function hash(n) {
    var x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
    return x - Math.floor(x);
  }

  function surfY(isl, x, z) {
    var R = isl.r;
    var dx = x - isl.x, dz = z - isl.z;
    var d = Math.min(R, Math.sqrt(dx * dx + dz * dz));
    return isl.y - R + Math.sqrt(Math.max(0, R * R - d * d));
  }

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

  function rr(x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function perfNow() {
    return (root.performance && root.performance.now) ? root.performance.now() : Date.now();
  }

  /* ------------------------------ kurulum ------------------------------ */

  function init(canvasEl, opts) {
    canvas = canvasEl;
    ctx = canvas.getContext('2d');
    save = opts.save;
    levels = opts.levels;
    prog = opts.prog;
    onTapNode = opts.onTapNode || function () {};
    onTapDaily = opts.onTapDaily || function () {};
    onFocus = opts.onFocus || null;

    buildSky();
    resize();
    layout();

    if (!started) {
      started = true;
      root.addEventListener('resize', function () { resize(); layout(); });
      bindInput();
      running = true;
      loop(perfNow());
    }
    return API;
  }

  function buildSky() {
    var seed = 90210;
    function rnd() { seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296; }
    stars = [];
    for (var i = 0; i < 190; i++) {
      stars.push({
        x: rnd(), y: rnd() * 0.78,
        r: 0.4 + rnd() * 1.5,
        ph: rnd() * Math.PI * 2,
        big: rnd() > 0.94
      });
    }
    puffs = [];
    for (i = 0; i < 26; i++) {
      puffs.push({
        x: rnd(), y: 0.62 + rnd() * 0.38,
        r: 0.05 + rnd() * 0.12,
        sp: 0.004 + rnd() * 0.012,
        a: 0.02 + rnd() * 0.04
      });
    }
    ambient = [];
    for (i = 0; i < 30; i++) {
      ambient.push({
        a: rnd() * Math.PI * 2,
        rad: 90 + rnd() * 300,
        h: rnd() * 300,
        sp: 0.15 + rnd() * 0.6,
        ph: rnd() * Math.PI * 2,
        s: 0.5 + rnd() * 1.2
      });
    }
    farRocks = [];
    for (i = 0; i < 16; i++) {
      var ang = rnd() * Math.PI * 2;
      var rad = 1500 + rnd() * 2300;
      farRocks.push({
        x: Math.sin(ang) * rad,
        y: -500 + rnd() * 7200,
        z: Math.cos(ang) * rad,
        r: 70 + rnd() * 190,
        seed: rnd() * 100
      });
    }
  }

  /* Parçacık izi uzunluğu (kuyruk için son N konum saklanır) */
  var TRAIL_LEN = 10;

  function newIslandParticle(isl, seeded) {
    var ang = Math.random() * Math.PI * 2;
    var rad = isl.r * (0.45 + Math.random() * 0.95);
    return {
      ang: ang,
      rad: rad,
      sp: (Math.random() < 0.5 ? -1 : 1) * (0.12 + Math.random() * 0.3),  // yörünge hızı
      y0: isl.y - isl.r * (0.2 + Math.random() * 1.4),                     // yükseliş başlangıcı
      wob: Math.random() * 6.28,
      size: 0.9 + Math.random() * 2.2,
      hue: Math.random() < 0.25 ? (isl.theme.glow + 42) % 360 : isl.theme.glow,  // %25 altın kıvılcım
      life: seeded ? Math.random() : 0,          // başlangıçta yaş dağılsın
      maxLife: 0.75 + Math.random() * 0.5,
      trail: []                                  // { x, y, z } son konumlar
    };
  }

  function initParticles() {
    islandParticles = [];
    for (var s = 0; s < islands.length; s++) {
      var isl = islands[s];
      var particles = [];
      for (var p = 0; p < 16; p++) particles.push(newIslandParticle(isl, true));
      isl.particles = particles;
      islandParticles.push({ isl: isl, particles: particles });
    }
  }

  function updateParticles(dt) {
    for (var i = 0; i < islandParticles.length; i++) {
      var sys = islandParticles[i];
      var isl = sys.isl;
      for (var p = 0; p < sys.particles.length; p++) {
        var pt = sys.particles[p];
        pt.ang += pt.sp * dt;                                   // yörünge süzülüşü
        pt.life += dt / pt.maxLife;
        if (pt.life >= 1) {
          sys.particles[p] = newIslandParticle(isl, false);     // yeniden doğ
          continue;
        }
        var x = isl.x + Math.cos(pt.ang) * pt.rad;
        var z = isl.z + Math.sin(pt.ang) * pt.rad;
        var y = pt.y0 - pt.life * isl.r * 1.7 + Math.sin(t * 0.0012 + pt.wob) * isl.r * 0.06;
        var tr = pt.trail;
        if (tr.length >= TRAIL_LEN) tr.shift();
        tr.push({ x: x, y: y, z: z });
        pt.x = x; pt.y = y; pt.z = z;
      }
    }
  }

  function renderParticles() {
    for (var i = 0; i < islandParticles.length; i++) {
      var sys = islandParticles[i];
      var isl = sys.isl;
      var lit = isl.open ? 1 : 0.5;                              // kilitli ada sönük
      for (var p = 0; p < sys.particles.length; p++) {
        var pt = sys.particles[p];
        if (!pt.trail.length) continue;
        /* iz: arkadan öne doğru solan segmentler */
        ctx.save();
        ctx.globalCompositeOperation = 'lighter';
        ctx.lineCap = 'round';
        for (var k = 1; k < pt.trail.length; k++) {
          var a = project(pt.trail[k - 1]);
          var b = project(pt.trail[k]);
          if (!a || !b) continue;
          var fade = k / pt.trail.length;                       // kuyruğa doğru söner
          var lifeFade = 1 - Math.abs(pt.life - 0.5) * 1.6;     // doğum/ölüm anında söner
          var alpha = 0.34 * fade * fade * lifeFade * lit;
          if (alpha <= 0.01) continue;
          ctx.strokeStyle = hsl(pt.hue, 96, 68, alpha);
          ctx.lineWidth = Math.max(0.5, pt.size * b.s * 0.55 * fade);
          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(b.x, b.y);
          ctx.stroke();
        }
        /* parlak baş: halo + additive çekirdek */
        var pc = project({ x: pt.x, y: pt.y, z: pt.z });
        if (pc) {
          var r = Math.max(0.7, pt.size * pc.s);
          var lifeFade2 = 1 - Math.abs(pt.life - 0.5) * 1.6;
          var halo = ctx.createRadialGradient(pc.x, pc.y, 0, pc.x, pc.y, r * 5.5);
          halo.addColorStop(0, hsl(pt.hue, 95, 74, 0.5 * lifeFade2 * lit));
          halo.addColorStop(1, hsl(pt.hue, 95, 60, 0));
          ctx.fillStyle = halo;
          ctx.beginPath();
          ctx.arc(pc.x, pc.y, r * 5.5, 0, Math.PI * 2);
          ctx.fill();
          ctx.shadowColor = hsl(pt.hue, 100, 70, 0.9);
          ctx.shadowBlur = 12 * pc.s * 0.35;
          ctx.fillStyle = hsl(pt.hue, 100, 86, 0.95 * lifeFade2 * lit);
          ctx.beginPath();
          ctx.arc(pc.x, pc.y, r, 0, Math.PI * 2);
          ctx.fill();
          ctx.shadowBlur = 0;
        }
        ctx.restore();
      }
    }
  }

  /* Ada altı nabız halo — premium zemin ışıltısı */
  function drawIslandAura(isl) {
    var c = project({ x: isl.x, y: isl.y - isl.r * 0.35, z: isl.z });
    if (!c) return;
    var pulse = 0.6 + 0.4 * Math.sin(t * 0.0011 + isl.seed * 3.1);
    var lit = isl.open ? 1 : 0.4;
    var r = isl.r * c.s * 2.6;
    if (r < 3) return;
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    var g = ctx.createRadialGradient(c.x, c.y, 0, c.x, c.y, r);
    g.addColorStop(0, hsl(isl.theme.glow, 92, 62, 0.16 * pulse * lit));
    g.addColorStop(0.5, hsl(isl.theme.glow, 92, 58, 0.07 * pulse * lit));
    g.addColorStop(1, hsl(isl.theme.glow, 92, 55, 0));
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.ellipse(c.x, c.y, r, r * 0.42, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  function resize() {
    if (!canvas) return;
    dpr = Math.min(root.devicePixelRatio || 1, 2);
    W = Math.max(320, root.innerWidth || 360);
    H = Math.max(420, root.innerHeight || 640);
    canvas.width = Math.round(W * dpr);
    canvas.height = Math.round(H * dpr);
    canvas.style.width = W + 'px';
    canvas.style.height = H + 'px';
    if (ctx.setTransform) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function setSave(s) { save = s; }

  /* ------------------------- dünya yerleşimi ------------------------- */

  function layout() {
    if (!save || !levels) return;
    var per = levels.LEVELS_PER_STAGE;
    islands = [];
    byStage = [];
    nodes = [];

    for (var s = 0; s < levels.STAGE_COUNT; s++) {
      var ang = -1.15 + s * 0.72;
      var rad = 120 + (s % 3) * 46;
      var isl = {
        stage: s,
        x: Math.sin(ang) * rad,
        y: s * 1350,
        z: Math.cos(ang) * rad,
        r: 330,
        thick: 205,
        theme: levels.THEMES[s],
        seed: 13 + s * 37,
        done: 0,
        stars: 0,
        open: false,
        need: levels.requiredStars(s),
        geo: null,
        items: null,
        nodes: []
      };

      var doneCount = 0, starSum = 0;
      for (var k = 0; k < per; k++) {
        var cm = save.completed[s * per + k];
        if (cm) { doneCount++; starSum += cm.stars || 0; }
      }
      isl.done = doneCount;
      isl.stars = starSum;
      isl.open = s === 0 || prog.totalStars(save) >= isl.need;

      buildGeometry(isl);
      buildItems(isl);
      byStage.push(isl);
      islands.push(isl);
    }

    for (var i = 0; i < levels.levelCount(); i++) {
      var d = levels.levelDef(i);
      var host = byStage[d.stage];
      /* yükseliş yolu: dünyanın yüzeyinde yukarı doğru kıvrılan sarmal */
      var u = per <= 1 ? 0 : d.idx / (per - 1);
      var a = 0.5 + u * Math.PI * 2 * 1.7 + d.stage * 0.37;
      var ring = host.r * (0.70 - u * 0.47);
      var nx = host.x + Math.cos(a) * ring;
      var nz = host.z + Math.sin(a) * ring;
      var nd = {
        i: i, d: d, isl: host, a: a,
        x: nx,
        y: surfY(host, nx, nz) + 3,
        z: nz,
        done: !!save.completed[i],
        stars: save.completed[i] ? save.completed[i].stars : 0,
        unlocked: prog.isUnlocked(save, i, d, levels),
        box: d.box && !save.boxes[i],
        current: false,
        screen: null
      };
      nodes.push(nd);
      host.nodes.push(nd);
    }

    var cur = -1;
    for (i = 0; i < nodes.length; i++) {
      if (nodes[i].unlocked && !nodes[i].done) { cur = i; break; }
    }
    if (cur >= 0) nodes[cur].current = true;

    /* odak: mevcut bölümün dünyası */
    var nextStage = cur >= 0 ? nodes[cur].isl.stage : levels.STAGE_COUNT - 1;
    if (!started) focusStage = nextStage;
    else focusStage = clamp(focusStage, 0, levels.STAGE_COUNT - 1);

    updateDaily();
    snap = true;
    var f = byStage[focusStage];
    if (f) {
      focusTo.x = f.x; focusTo.y = f.y - f.r * 0.58; focusTo.z = f.z;
      if (!started) { focus.x = focusTo.x; focus.y = focusTo.y; focus.z = focusTo.z; }
    }
    if (onFocus) onFocus(focusStage);

    /* parçacıklar her zaman güncel ada nesnelerine bağlı olsun
       (layout yeniden kurulduğunda eskiler geçersizleşir) */
    initParticles();
  }

  function buildGeometry(isl) {
    var N = 28, top = [], bot = [];
    var rimY = isl.y - isl.r;               /* ekvator: gezegenin görünen kenarı */
    for (var k = 0; k < N; k++) {
      var a = k / N * Math.PI * 2;
      var rr2 = isl.r * (0.96 + 0.025 * Math.sin(a * 3 + isl.seed * 0.7));
      var depth = isl.thick * (0.7 + 0.35 * Math.sin(a * 2 + isl.seed * 1.3));
      top.push({ x: isl.x + Math.cos(a) * rr2, y: rimY, z: isl.z + Math.sin(a) * rr2 });
      bot.push({ x: isl.x + Math.cos(a) * rr2 * 0.70, y: rimY - depth, z: isl.z + Math.sin(a) * rr2 * 0.70 });
    }
    isl.geo = {
      top: top, bot: bot, N: N,
      tip: { x: isl.x, y: rimY - isl.thick - 190, z: isl.z }
    };
  }

  function buildItems(isl) {
    var items = [];
    var per = levels.LEVELS_PER_STAGE;

    /* köy: bitirilen her bölüm, yolun kenarında yeni bir bina açar */
    for (var b = 0; b < isl.done && b < per; b++) {
      var u = per <= 1 ? 0 : b / (per - 1);
      var a = 0.5 + u * Math.PI * 2 * 1.7 + isl.stage * 0.37 + 0.25;
      var rad = isl.r * (0.70 - u * 0.47);
      var bx = isl.x + Math.cos(a) * rad;
      var bz = isl.z + Math.sin(a) * rad;
      items.push({
        type: 'building',
        x: bx + Math.cos(a + 1.4) * 26,
        y: surfY(isl, bx, bz) + 2,
        z: bz + Math.sin(a + 1.4) * 26,
        h: 26 + ((b * 13) % 42),
        w: 12 + ((b * 7) % 9),
        hue: (isl.theme.glow + b * 9) % 360,
        seed: b
      });
    }

    /* doğa: gezegenin yüzeyine serpilmiş ağaçlar / kristaller */
    for (var d = 0; d < 20; d++) {
      var da = hash(d * 7 + isl.seed) * Math.PI * 2;
      var dr = isl.r * (0.20 + hash(d * 13 + isl.seed) * 0.62);
      var dx = isl.x + Math.cos(da) * dr;
      var dz = isl.z + Math.sin(da) * dr;
      items.push({
        type: 'decor',
        x: dx,
        y: surfY(isl, dx, dz) + 1,
        z: dz,
        h: 9 + ((d * 13) % 21),
        hue: (isl.theme.hues[d % 3] + 8) % 360,
        seed: d + isl.seed
      });
    }
    isl.items = items;
  }

  function updateDaily() {
    var isl = byStage[focusStage];
    if (!isl) { daily = null; return; }
    daily = {
      x: isl.x,
      y: isl.y + isl.r * 0.55,
      z: isl.z,
      r: 60, thick: 28, screen: null
    };
  }

  /* --------------------------- kamera / izdüşüm --------------------------- */

  function updateCamera(dt) {
    var isl = byStage[focusStage];
    if (!isl) return;
    focusTo.x = isl.x; focusTo.y = isl.y - isl.r * 0.58; focusTo.z = isl.z;
    var k = snap ? 1 : Math.min(1, Math.max(0.02, dt * 5));
    focus.x += (focusTo.x - focus.x) * k;
    focus.y += (focusTo.y - focus.y) * k;
    focus.z += (focusTo.z - focus.z) * k;
    snap = false;

    var cp = Math.cos(cam.pitch), sp = Math.sin(cam.pitch);
    eye.x = focus.x + Math.sin(cam.yaw) * cp * cam.dist;
    eye.y = focus.y + sp * cam.dist;
    eye.z = focus.z + Math.cos(cam.yaw) * cp * cam.dist;

    var fx = focus.x - eye.x, fy = focus.y - eye.y, fz = focus.z - eye.z;
    var fl = Math.sqrt(fx * fx + fy * fy + fz * fz) || 1;
    fwd.x = fx / fl; fwd.y = fy / fl; fwd.z = fz / fl;

    /* right = fwd × up */
    var rx = -fwd.z, ry = 0, rz = fwd.x;
    var rl = Math.sqrt(rx * rx + rz * rz) || 1;
    right.x = rx / rl; right.y = 0; right.z = rz / rl;

    /* up = right × fwd */
    up.x = right.y * fwd.z - right.z * fwd.y;
    up.y = right.z * fwd.x - right.x * fwd.z;
    up.z = right.x * fwd.y - right.y * fwd.x;

    focal = (H * 0.5) / Math.tan(FOV / 2);
  }

  function project(p) {
    var dx = p.x - eye.x, dy = p.y - eye.y, dz = p.z - eye.z;
    var z = dx * fwd.x + dy * fwd.y + dz * fwd.z;
    if (z < 70) return null;
    var s = focal / z;
    return {
      x: W * 0.5 + (dx * right.x + dy * right.y + dz * right.z) * s,
      y: H * 0.5 - (dx * up.x + dy * up.y + dz * up.z) * s,
      s: s, z: z
    };
  }

  /* ------------------------------ girdi ------------------------------ */

  function bindInput() {
    if (!canvas || !canvas.addEventListener) return;

    canvas.addEventListener('pointerdown', function (e) {
      drag = { x: e.clientX, y: e.clientY, yaw: cam.yaw, moved: 0, lastX: e.clientX, dy: 0 };
      yawVel = 0;
      try { if (canvas.setPointerCapture) canvas.setPointerCapture(e.pointerId); } catch (err) {}
    });

    canvas.addEventListener('pointermove', function (e) {
      if (!drag) return;
      var dx = e.clientX - drag.x;
      var dy = e.clientY - drag.y;
      drag.moved = Math.max(drag.moved, Math.sqrt(dx * dx + dy * dy));
      drag.dy = dy;
      cam.yaw = drag.yaw - dx * 0.006;
      yawVel = (drag.lastX - e.clientX) * 0.05;
      drag.lastX = e.clientX;
    });

    canvas.addEventListener('pointerup', function (e) {
      if (!drag) return;
      if (drag.moved < 12) {
        hit(e.clientX, e.clientY);
      } else if (Math.abs(drag.dy) > 64 && Math.abs(drag.dy) > Math.abs(e.clientX - drag.x) * 0.75) {
        setFocus(focusStage + (drag.dy < 0 ? 1 : -1));
      }
      drag = null;
    });

    canvas.addEventListener('pointercancel', function () { drag = null; });
    canvas.addEventListener('contextmenu', function (e) { e.preventDefault(); });
    canvas.addEventListener('wheel', function (e) {
      cam.dist = clamp(cam.dist + (e.deltaY || 0) * 0.55, 720, 1520);
      e.preventDefault();
    }, { passive: false });
  }

  function hit(px, py) {
    /* önce düğümler (en yakın) */
    var best = null, bestD = 1e9;
    for (var i = 0; i < nodes.length; i++) {
      var nd = nodes[i];
      if (!nd.screen) continue;
      var d = Math.sqrt((px - nd.screen.x) * (px - nd.screen.x) + (py - nd.screen.y) * (py - nd.screen.y));
      if (d < nd.screen.r && d < bestD) { bestD = d; best = nd; }
    }
    if (best) {
      if (best.isl.stage !== focusStage) setFocus(best.isl.stage);
      onTapNode(best.i, best.unlocked);
      return;
    }
    if (daily && daily.screen) {
      var dd = Math.sqrt((px - daily.screen.x) * (px - daily.screen.x) + (py - daily.screen.y) * (py - daily.screen.y));
      if (dd < daily.screen.r) { onTapDaily(); return; }
    }
    /* boşluğa dokunma: ada seçimi */
    for (var s = 0; s < islands.length; s++) {
      var isl = islands[s];
      if (!isl.center) continue;
      var di = Math.sqrt((px - isl.center.x) * (px - isl.center.x) + (py - isl.center.y) * (py - isl.center.y));
      if (di < isl.center.r) { setFocus(isl.stage); return; }
    }
  }

  function setFocus(stage) {
    var max = (levels ? levels.STAGE_COUNT : 10) - 1;
    var next = clamp(stage, 0, max);
    if (next === focusStage && byStage[next]) return;
    focusStage = next;
    updateDaily();
    if (onFocus) onFocus(focusStage);
  }

  /* ------------------------------ döngü ------------------------------ */

  function loop(ts) {
    if (!running) return;
    root.requestAnimationFrame(loop);
    var dt = Math.min(0.05, Math.max(0.001, (ts - lastTs) / 1000) || 0.016);
    lastTs = ts;
    t = ts;
    if (!drag) {
      cam.yaw += yawVel * dt;
      yawVel *= 0.9;
      if (Math.abs(yawVel) < 0.001) yawVel = 0;
    }
    updateCamera(dt);
    updateParticles(dt);
    render();
  }

  function render() {
    if (!ctx || !byStage.length) return;
    var isl = byStage[focusStage];
    drawSky(isl);
    drawHorizonClouds();
    drawFarRocks(isl);
    drawBridges();
    drawCloudPuffs(isl);
    for (var i = 0; i < islands.length; i++) drawIslandAura(islands[i]);
    drawIslands();
    renderParticles();
    drawDaily();
    drawAmbient(isl);
    drawForeground();
  }

  /* ------------------------------- gökyüzü ------------------------------- */

  function drawSky(isl) {
    var theme = isl.theme;
    var c0 = hexRgb(theme.bg[0]);
    var c1 = hexRgb(theme.bg[1]);
    var glow = hslRgb(theme.glow, 92, 60);
    var deep = [3, 3, 11];

    var g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, rgb(mix(deep, c0, 0.45)));
    g.addColorStop(0.42, rgb(c0));
    g.addColorStop(0.76, rgb(mix(c0, c1, 0.75)));
    g.addColorStop(1, rgb(mix(c1, glow, 0.5)));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    /* yıldızlar (yörüngeye göre kayar) */
    var off = (cam.yaw * 90) % W;
    for (var i = 0; i < stars.length; i++) {
      var s = stars[i];
      var x = ((s.x * W - off) % W + W) % W;
      var y = s.y * H;
      var tw = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * 0.0016 + s.ph));
      ctx.globalAlpha = tw * 0.85;
      ctx.fillStyle = s.big ? '#fff6d8' : '#e6efff';
      if (s.big) {
        ctx.fillRect(x - 4, y - 0.6, 8, 1.2);
        ctx.fillRect(x - 0.6, y - 4, 1.2, 8);
      }
      ctx.beginPath();
      ctx.arc(x, y, s.r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    /* aurora */
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    for (var b = 0; b < 3; b++) {
      var y0 = H * (0.14 + b * 0.075) + Math.sin(t * 0.00022 + b * 1.7) * 14;
      var ag = ctx.createLinearGradient(0, y0 - 90, 0, y0 + 90);
      ag.addColorStop(0, rgb(glow, 0));
      ag.addColorStop(0.5, rgb(glow, 0.038 - b * 0.008));
      ag.addColorStop(1, rgb(glow, 0));
      ctx.strokeStyle = ag;
      ctx.lineWidth = 92 + b * 34;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(-60, y0);
      ctx.bezierCurveTo(W * 0.3, y0 - 80, W * 0.7, y0 + 90, W + 60, y0 - 20);
      ctx.stroke();
    }
    ctx.restore();

    /* uzak gezegen */
    var px = W * 0.79 - cam.yaw * 55;
    var py = H * 0.19;
    var pr = Math.min(W, H) * 0.055;
    var pg = ctx.createRadialGradient(px - pr * 0.3, py - pr * 0.35, pr * 0.1, px, py, pr);
    pg.addColorStop(0, rgb(mix(glow, [255, 255, 255], 0.45), 0.85));
    pg.addColorStop(0.55, rgb(glow, 0.4));
    pg.addColorStop(1, rgb(glow, 0.02));
    ctx.fillStyle = pg;
    ctx.beginPath();
    ctx.arc(px, py, pr, 0, Math.PI * 2);
    ctx.fill();
    ctx.save();
    ctx.globalAlpha = 0.35;
    ctx.strokeStyle = rgb(glow, 0.6);
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.ellipse(px, py, pr * 1.65, pr * 0.34, -0.38, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function drawHorizonClouds() {
    ctx.save();
    for (var i = 0; i < puffs.length; i++) {
      var p = puffs[i];
      var x = ((p.x + t * 0.000012 * p.sp * 60) % 1.2 - 0.1) * W;
      var y = p.y * H;
      var r = p.r * W;
      var g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, 'rgba(214,232,255,' + p.a + ')');
      g.addColorStop(1, 'rgba(214,232,255,0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.ellipse(x, y, r, r * 0.32, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  /* --------------------------- 3B bulut / parıltı --------------------------- */

  function drawCloudPuffs(isl) {
    for (var i = 0; i < 9; i++) {
      var a = isl.seed + i * 1.7;
      var cx = isl.x + Math.cos(a) * isl.r * (1.35 + (i % 3) * 0.16) + Math.sin(t * 0.00009 + i) * 40;
      var cy = isl.y - 300 - ((i * 61) % 260);
      var cz = isl.z + Math.sin(a) * isl.r * (1.2 + (i % 2) * 0.2);
      var p = project({ x: cx, y: cy, z: cz });
      if (!p) continue;
      var r = 105 * Math.max(0.25, p.s);
      var g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
      g.addColorStop(0, 'rgba(210,228,255,0.10)');
      g.addColorStop(0.55, 'rgba(190,212,255,0.045)');
      g.addColorStop(1, 'rgba(190,212,255,0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.ellipse(p.x, p.y, r, r * 0.4, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function drawAmbient(isl) {
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    var glow = hslRgb(isl.theme.glow, 92, 68);
    for (var i = 0; i < ambient.length; i++) {
      var a = ambient[i];
      var ang = a.a + t * 0.00006 * a.sp;
      var hh = (a.h + t * 0.02 * a.sp) % 300;
      var p = project({
        x: isl.x + Math.cos(ang) * a.rad,
        y: isl.y + hh - 60 + Math.sin(t * 0.001 + a.ph) * 10,
        z: isl.z + Math.sin(ang) * a.rad
      });
      if (!p) continue;
      var alpha = 0.25 + 0.5 * (0.5 + 0.5 * Math.sin(t * 0.0022 + a.ph));
      ctx.fillStyle = rgb(glow, alpha * 0.5);
      ctx.beginPath();
      ctx.arc(p.x, p.y, Math.max(0.6, a.s * p.s * 1.5), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  /* ------------------------------- adalar ------------------------------- */

  function drawIslands() {
    /* kameradan uzak olan önce */
    var order = islands.slice().sort(function (a, b) {
      return dist2(a) - dist2(b);
    });
    var tops = [];
    var focusIsl = byStage[focusStage];
    var focusDist = focusIsl ? Math.sqrt(dist2(focusIsl)) : 0;
    for (var i = 0; i < order.length; i++) {
      var isl = order[i];
      var c = project({ x: isl.x, y: isl.y, z: isl.z });
      if (!c) continue;
      if (c.x < -W * 1.1 || c.x > W * 2.1 || c.y < -H * 1.1 || c.y > H * 2.1) continue;
      var d = Math.sqrt(dist2(isl));
      if (isl !== focusIsl && d > focusDist + 1900) continue;
      var fogK = isl === focusIsl ? 0 : clamp((d - focusDist - 150) / 1200, 0.15, 1);
      ctx.save();
      ctx.globalAlpha = 1 - fogK * 0.62;
      drawIsland(isl, c);
      ctx.restore();
      tops.push(isl);
    }
  }

  function dist2(isl) {
    var dx = isl.x - eye.x, dy = isl.y - eye.y, dz = isl.z - eye.z;
    return dx * dx + dy * dy + dz * dz;
  }

  function drawIsland(isl, center) {
    isl.center = { x: center.x, y: center.y, r: isl.r * center.s * 1.15 };
    var g = isl.geo;
    var h = isl.theme.glow;
    var fog = clamp((center.z - (cam.dist - 220)) / 2400, 0, 0.55);
    var sat = 1 - fog * 0.9;
    var lit = isl.open ? 1 : 0.55;

    var tp = [], bp = [];
    var i;
    for (i = 0; i < g.N; i++) {
      tp.push(project(g.top[i]));
      bp.push(project(g.bot[i]));
    }
    var tip = project(g.tip);

    /* yüzler: uçurum + alt koni, derinliğe göre sıralı */
    var faces = [];
    for (i = 0; i < g.N; i++) {
      var j = (i + 1) % g.N;
      if (tp[i] && tp[j] && bp[i] && bp[j]) {
        faces.push({
          kind: 'side', i: i,
          pts: [tp[i], tp[j], bp[j], bp[i]],
          depth: (tp[i].z + tp[j].z + bp[i].z + bp[j].z) / 4,
          top: ((tp[i].y + tp[j].y) / 2),
          bot: ((bp[i].y + bp[j].y) / 2)
        });
      }
      if (tip && bp[i] && bp[j]) {
        faces.push({
          kind: 'tip',
          pts: [bp[i], bp[j], tip],
          depth: (bp[i].z + bp[j].z + tip.z) / 3
        });
      }
    }
    faces.sort(function (a, b) { return b.depth - a.depth; });

    for (i = 0; i < faces.length; i++) {
      var f = faces[i];
      ctx.beginPath();
      ctx.moveTo(f.pts[0].x, f.pts[0].y);
      for (var q = 1; q < f.pts.length; q++) ctx.lineTo(f.pts[q].x, f.pts[q].y);
      ctx.closePath();

      if (f.kind === 'tip') {
        ctx.fillStyle = hsl(h, 42 * sat, (7 + 4 * Math.sin(f.depth * 0.01)) * lit, 1);
        ctx.fill();
      } else {
        var shade = 0.7 + 0.4 * Math.cos(f.i * 1.2 + isl.seed);
        var grad = ctx.createLinearGradient(f.pts[0].x, f.top, f.pts[0].x, f.bot);
        grad.addColorStop(0, hsl(h, 48 * sat, 27 * lit * shade));
        grad.addColorStop(0.28, hsl(h, 44 * sat, 18 * lit * shade));
        grad.addColorStop(1, hsl(h, 40 * sat, 6 * lit));
        ctx.fillStyle = grad;
        ctx.fill();
        /* uçurum üst kenarında ince ay ışığı */
        if (center.s > 0.18) {
          ctx.save();
          ctx.strokeStyle = hsl(h, 78, 58, 0.12 * lit);
          ctx.lineWidth = Math.max(0.6, 1.3 * center.s);
          ctx.beginPath();
          ctx.moveTo(f.pts[0].x, f.top + 1);
          ctx.lineTo(f.pts[1].x, f.top + 1);
          ctx.stroke();
          ctx.restore();
        }
      }
    }

    /* gezegen yüzeyi */
    drawPlanet(isl, center, lit);
    drawSummit(isl, center, lit);

    /* anıt + yol + köy + düğümler */
    drawMonument(isl, center, lit);
    drawPath(isl);
    drawItems(isl);
  }

  /* --------------------------- gezegen yüzeyi --------------------------- */

  var TERRAIN = {
    sehir:  { deep: [235, 46, 7],  land: [255, 44, 16], land2: [212, 62, 24], accent: [188, 95, 62] },
    orman:  { deep: [150, 48, 7],  land: [138, 48, 20], land2: [98, 45, 27],  accent: [95, 80, 58] },
    col:    { deep: [30, 55, 9],   land: [36, 62, 30],  land2: [26, 58, 20],   accent: [46, 88, 60] },
    buz:    { deep: [200, 58, 10], land: [198, 55, 48], land2: [205, 46, 31],  accent: [190, 90, 76] },
    uzay:   { deep: [268, 45, 6],  land: [280, 40, 15], land2: [255, 38, 22],  accent: [300, 82, 62] },
    volkan: { deep: [8, 52, 6],    land: [8, 42, 12],   land2: [20, 46, 18],   accent: [18, 96, 58] },
    bulut:  { deep: [212, 55, 13], land: [208, 42, 40], land2: [200, 34, 28],  accent: [195, 70, 82] },
    deniz:  { deep: [195, 74, 8],  land: [165, 48, 19], land2: [190, 55, 14],  accent: [184, 90, 66] },
    kristal:{ deep: [286, 52, 7],  land: [288, 48, 20], land2: [262, 44, 13],  accent: [316, 92, 70] },
    zirve:  { deep: [344, 38, 6],  land: [344, 28, 13], land2: [300, 26, 18],  accent: [345, 88, 64] }
  };

  function drawPlanet(isl, center, lit) {
    var R = isl.r;
    var pc = project({ x: isl.x, y: isl.y - R, z: isl.z });
    if (!pc) return;
    var rp = Math.max(24, R * pc.s);
    var cx = pc.x, cy = pc.y;
    var h = isl.theme.glow;
    var id = isl.theme.id || 'sehir';
    var pal = TERRAIN[id] || TERRAIN.sehir;
    var seed = isl.seed;

    /* halka: arka yarı */
    drawPlanetRing(isl, cx, cy, rp, lit, true);

    /* atmosfer halesi */
    ctx.save();
    var at = ctx.createRadialGradient(cx, cy, rp * 0.88, cx, cy, rp * 1.42);
    at.addColorStop(0, hsl(h, 96, 64, 0));
    at.addColorStop(0.42, hsl(h, 96, 66, 0.10 * lit));
    at.addColorStop(0.75, hsl(h, 96, 68, 0.17 * lit));
    at.addColorStop(1, hsl(h, 96, 70, 0));
    ctx.fillStyle = at;
    ctx.beginPath();
    ctx.arc(cx, cy, rp * 1.42, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, rp, 0, Math.PI * 2);
    ctx.clip();

    /* kürenin temel ışığı */
    var bg = ctx.createRadialGradient(cx - rp * 0.42, cy - rp * 0.48, rp * 0.04, cx, cy, rp * 1.18);
    bg.addColorStop(0, hsl(pal.land[0], pal.land[1], Math.min(62, pal.land[2] + 24 * lit)));
    bg.addColorStop(0.38, hsl(pal.land[0], pal.land[1], pal.land[2] * lit + 6));
    bg.addColorStop(0.72, hsl(pal.deep[0], pal.deep[1], pal.deep[2] * lit + 3));
    bg.addColorStop(1, hsl(pal.deep[0], pal.deep[1], Math.max(2, pal.deep[2] * lit)));
    ctx.fillStyle = bg;
    ctx.fillRect(cx - rp, cy - rp, rp * 2, rp * 2);

    /* kıtalar / arazi kütleleri */
    var blobs = 8;
    for (var b = 0; b < blobs; b++) {
      var a = hash(b * 9.1 + seed) * Math.PI * 2;
      var rad = rp * (0.06 + hash(b * 4.7 + seed * 1.3) * 0.68);
      var bx = cx + Math.cos(a) * rad;
      var by = cy + Math.sin(a) * rad * 0.96;
      var bw = rp * (0.18 + hash(b * 2.3 + seed) * 0.34);
      var bh = bw * (0.45 + hash(b * 6.1 + seed) * 0.5);
      var col = b % 3 === 0 ? pal.land2 : pal.land;
      var tg = ctx.createRadialGradient(bx - bw * 0.2, by - bh * 0.25, 1, bx, by, bw);
      tg.addColorStop(0, hsl(col[0], col[1], Math.min(68, col[2] + 10 * lit), 0.85 * lit));
      tg.addColorStop(0.62, hsl(col[0], col[1], col[2] * lit + 2, 0.62 * lit));
      tg.addColorStop(1, hsl(col[0], col[1], Math.max(3, col[2] * lit - 3), 0));
      ctx.save();
      ctx.translate(bx, by);
      ctx.rotate(a * 0.7);
      ctx.scale(1, bh / bw);
      ctx.fillStyle = tg;
      ctx.beginPath();
      ctx.arc(0, 0, bw, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    /* dünyaya özel dokular */
    drawTerrainDetail(isl, cx, cy, rp, lit, pal);

    /* sürüklenen bulut katmanı */
    var clouds = id === 'bulut' ? 7 : 4;
    for (var c = 0; c < clouds; c++) {
      var ca = hash(c * 3.3 + seed) * Math.PI * 2;
      var cr = rp * (0.12 + hash(c * 8.8 + seed) * 0.62);
      var drift = Math.sin(t * 0.00011 + c * 1.7) * rp * 0.06;
      var ccx = cx + Math.cos(ca) * cr + drift;
      var ccy = cy + Math.sin(ca) * cr * 0.8;
      var cw = rp * (0.18 + hash(c * 5.2 + seed) * 0.24);
      var cg = ctx.createRadialGradient(ccx, ccy, 0, ccx, ccy, cw);
      cg.addColorStop(0, 'rgba(225,240,255,' + (0.10 + (id === 'bulut' ? 0.16 : 0)) * lit + ')');
      cg.addColorStop(0.55, 'rgba(210,230,255,' + (0.05 + (id === 'bulut' ? 0.09 : 0)) * lit + ')');
      cg.addColorStop(1, 'rgba(210,230,255,0)');
      ctx.fillStyle = cg;
      ctx.beginPath();
      ctx.ellipse(ccx, ccy, cw, cw * 0.32, -0.2, 0, Math.PI * 2);
      ctx.fill();
    }

    /* gece / terminatör gölgesi */
    var term = ctx.createRadialGradient(cx - rp * 0.34, cy - rp * 0.38, rp * 0.18, cx, cy, rp * 1.06);
    term.addColorStop(0, 'rgba(0,0,0,0)');
    term.addColorStop(0.52, 'rgba(0,0,0,0)');
    term.addColorStop(0.78, 'rgba(0,0,0,0.20)');
    term.addColorStop(1, 'rgba(0,0,0,0.62)');
    ctx.fillStyle = term;
    ctx.fillRect(cx - rp, cy - rp, rp * 2, rp * 2);

    /* şehir ışıkları gece tarafında parlasın */
    if (id === 'sehir' || id === 'bulut' || id === 'zirve') {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      for (var L = 0; L < 46; L++) {
        var la = hash(L * 3.1 + seed) * Math.PI * 2;
        var lr = rp * Math.sqrt(hash(L * 7.7 + seed)) * 0.9;
        var lx = cx + Math.cos(la) * lr;
        var ly = cy + Math.sin(la) * lr * 0.95;
        var night = Math.max(0, (lx - cx) / rp) * 0.7 + Math.max(0, (ly - cy) / rp) * 0.5;
        var tw = 0.45 + 0.55 * Math.sin(t * 0.0016 + L * 1.9);
        ctx.fillStyle = hsl(46, 95, 72, (0.16 + night * 0.8) * tw * lit);
        ctx.fillRect(lx - 0.4, ly - 0.4, 1.8 + (L % 3) * 0.8, 1.8);
      }
      ctx.restore();
    }

    ctx.restore();

    /* ince atmosfer kenarı + ay ışığı */
    ctx.save();
    ctx.strokeStyle = hsl(h, 96, 72, 0.42 * lit);
    ctx.lineWidth = Math.max(1, rp * 0.006);
    ctx.shadowColor = hsl(h, 98, 66, 0.75 * lit);
    ctx.shadowBlur = rp * 0.10;
    ctx.beginPath();
    ctx.arc(cx, cy, rp - 0.5, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();

    /* halka: ön yarı */
    drawPlanetRing(isl, cx, cy, rp, lit, false);

    /* kilitli dünya */
    if (!isl.open) {
      drawLockGlyph(cx, cy, Math.max(16, rp * 0.20), lit);
    }

    isl.center = { x: cx, y: cy, r: rp * 1.05 };
    isl.sphere = { x: cx, y: cy, r: rp };
  }

  function drawTerrainDetail(isl, cx, cy, rp, lit, pal) {
    var id = isl.theme.id;
    var seed = isl.seed;
    var h = isl.theme.glow;
    var i, a, r, x, y;

    if (id === 'sehir') {
      /* sokak ışıklarından oluşan devre ızgarası */
      ctx.save();
      ctx.strokeStyle = hsl(190, 90, 62, 0.10 * lit);
      ctx.lineWidth = 0.8;
      for (i = -4; i <= 4; i++) {
        var off = i * rp * 0.17;
        ctx.beginPath();
        ctx.moveTo(cx - rp, cy + off);
        ctx.lineTo(cx + rp, cy + off);
        ctx.moveTo(cx + off, cy - rp);
        ctx.lineTo(cx + off, cy + rp);
        ctx.stroke();
      }
      ctx.restore();
    } else if (id === 'orman') {
      for (i = 0; i < 46; i++) {
        a = hash(i * 5.1 + seed) * Math.PI * 2;
        r = rp * (0.18 + hash(i * 2.9 + seed) * 0.66);
        x = cx + Math.cos(a) * r;
        y = cy + Math.sin(a) * r * 0.92;
        ctx.fillStyle = hsl(105 + (i % 4) * 18, 55, 28 + (i % 5) * 6, 0.55 * lit);
        ctx.beginPath();
        ctx.arc(x, y, 1.4 + (i % 3), 0, Math.PI * 2);
        ctx.fill();
      }
    } else if (id === 'col') {
      ctx.save();
      for (i = 0; i < 7; i++) {
        var yy = cy - rp * 0.5 + i * rp * 0.17;
        ctx.strokeStyle = hsl(42, 82, 66, 0.13 * lit);
        ctx.lineWidth = 1.1;
        ctx.beginPath();
        ctx.moveTo(cx - rp * 0.9, yy);
        ctx.quadraticCurveTo(cx, yy - rp * 0.1, cx + rp * 0.9, yy + rp * 0.04);
        ctx.stroke();
      }
      ctx.restore();
    } else if (id === 'buz') {
      ctx.save();
      ctx.strokeStyle = 'rgba(235,250,255,' + (0.20 * lit) + ')';
      ctx.lineWidth = 0.9;
      for (i = 0; i < 10; i++) {
        a = hash(i * 4.4 + seed) * Math.PI * 2;
        r = rp * hash(i * 8.2 + seed) * 0.8;
        x = cx + Math.cos(a) * r;
        y = cy + Math.sin(a) * r;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + rp * 0.11, y + rp * 0.05);
        ctx.lineTo(x + rp * 0.05, y + rp * 0.12);
        ctx.stroke();
      }
      ctx.restore();
    } else if (id === 'uzay') {
      /* kraterler */
      for (i = 0; i < 9; i++) {
        a = hash(i * 6.3 + seed) * Math.PI * 2;
        r = rp * (0.1 + hash(i * 3.7 + seed) * 0.7);
        x = cx + Math.cos(a) * r;
        y = cy + Math.sin(a) * r * 0.9;
        var cr = rp * (0.04 + hash(i + seed) * 0.07);
        ctx.fillStyle = 'rgba(8,4,20,0.5)';
        ctx.beginPath();
        ctx.arc(x, y, cr, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = 'rgba(200,180,255,0.16)';
        ctx.lineWidth = 0.8;
        ctx.beginPath();
        ctx.arc(x - cr * 0.15, y - cr * 0.15, cr, 0, Math.PI * 2);
        ctx.stroke();
      }
    } else if (id === 'volkan') {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      for (i = 0; i < 6; i++) {
        a = hash(i * 7.7 + seed) * Math.PI * 2;
        r = rp * (0.15 + hash(i * 2.2 + seed) * 0.65);
        x = cx + Math.cos(a) * r * 0.4;
        y = cy + Math.sin(a) * r * 0.4;
        ctx.strokeStyle = hsl(18, 98, 58, 0.55 * lit);
        ctx.lineWidth = 1.6;
        ctx.shadowColor = hsl(20, 100, 55, 0.8);
        ctx.shadowBlur = 9;
        ctx.beginPath();
        ctx.moveTo(x, y);
        for (var k = 1; k <= 5; k++) {
          ctx.lineTo(x + Math.cos(a) * k * rp * 0.08 + Math.sin(k * 2 + i) * 4,
                     y + Math.sin(a) * k * rp * 0.08 + Math.cos(k * 3 + i) * 4);
        }
        ctx.stroke();
      }
      ctx.restore();
    } else if (id === 'deniz') {
      ctx.save();
      ctx.strokeStyle = 'rgba(190,240,255,0.15)';
      ctx.lineWidth = 0.9;
      for (i = 0; i < 8; i++) {
        var wy = cy - rp * 0.55 + i * rp * 0.15;
        ctx.beginPath();
        for (var q = 0; q <= 20; q++) {
          var qx = cx - rp + q / 20 * rp * 2;
          var qy = wy + Math.sin(q * 0.7 + i + t * 0.0006) * 2.2;
          if (q === 0) ctx.moveTo(qx, qy); else ctx.lineTo(qx, qy);
        }
        ctx.stroke();
      }
      ctx.restore();
    } else if (id === 'kristal') {
      for (i = 0; i < 7; i++) {
        a = hash(i * 3.9 + seed) * Math.PI * 2;
        r = rp * (0.15 + hash(i * 8.4 + seed) * 0.62);
        x = cx + Math.cos(a) * r;
        y = cy + Math.sin(a) * r;
        var s = rp * (0.06 + hash(i * 1.7 + seed) * 0.08);
        ctx.fillStyle = hsl((292 + i * 9) % 360, 80, 62, 0.24 * lit);
        ctx.beginPath();
        ctx.moveTo(x, y - s);
        ctx.lineTo(x + s * 0.8, y);
        ctx.lineTo(x, y + s * 0.9);
        ctx.lineTo(x - s * 0.8, y);
        ctx.closePath();
        ctx.fill();
        ctx.strokeStyle = hsl(310, 95, 82, 0.5 * lit);
        ctx.lineWidth = 0.8;
        ctx.stroke();
      }
    } else if (id === 'zirve') {
      ctx.save();
      ctx.fillStyle = 'rgba(235,245,255,0.55)';
      ctx.beginPath();
      ctx.ellipse(cx, cy - rp * 0.45, rp * 0.28, rp * 0.10, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255,190,215,0.16)';
      ctx.lineWidth = 1.1;
      for (i = 0; i < 5; i++) {
        ctx.beginPath();
        ctx.arc(cx, cy, rp * (0.3 + i * 0.14), Math.PI * 0.15, Math.PI * 0.85);
        ctx.stroke();
      }
      ctx.restore();
    } else if (id === 'bulut') {
      for (i = 0; i < 5; i++) {
        a = hash(i * 4.4 + seed) * Math.PI * 2;
        r = rp * (0.2 + hash(i * 9.1 + seed) * 0.55);
        x = cx + Math.cos(a) * r;
        y = cy + Math.sin(a) * r * 0.8;
        var cw = rp * (0.16 + hash(i * 5.5 + seed) * 0.2);
        var cg = ctx.createRadialGradient(x, y, 0, x, y, cw);
        cg.addColorStop(0, 'rgba(230,244,255,' + (0.22 * lit) + ')');
        cg.addColorStop(1, 'rgba(220,238,255,0)');
        ctx.fillStyle = cg;
        ctx.beginPath();
        ctx.ellipse(x, y, cw, cw * 0.4, 0, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  function drawPlanetRing(isl, cx, cy, rp, lit, back) {
    var id = isl.theme.id;
    if (id !== 'uzay' && id !== 'zirve' && id !== 'kristal') return;
    var h = isl.theme.glow;
    ctx.save();
    ctx.strokeStyle = hsl(h, 88, 66, (back ? 0.10 : 0.22) * lit);
    ctx.lineWidth = Math.max(1, rp * 0.035);
    ctx.beginPath();
    ctx.ellipse(cx, cy, rp * 1.46, rp * 0.36, -0.30, back ? Math.PI : 0, back ? Math.PI * 2 : Math.PI);
    ctx.stroke();
    ctx.strokeStyle = hsl(h, 92, 78, (back ? 0.06 : 0.12) * lit);
    ctx.lineWidth = Math.max(0.6, rp * 0.008);
    ctx.beginPath();
    ctx.ellipse(cx, cy, rp * 1.58, rp * 0.41, -0.30, back ? Math.PI : 0, back ? Math.PI * 2 : Math.PI);
    ctx.stroke();
    if (!back && id === 'uzay') {
      ctx.fillStyle = hsl(h, 90, 78, 0.85);
      ctx.beginPath();
      ctx.arc(cx + rp * 1.32, cy - rp * 0.20, Math.max(1.4, rp * 0.028), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawLockGlyph(cx, cy, s, lit) {
    ctx.save();
    ctx.fillStyle = 'rgba(4,4,14,0.55)';
    ctx.beginPath();
    ctx.arc(cx, cy, s * 1.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.22)';
    ctx.lineWidth = Math.max(1, s * 0.12);
    ctx.beginPath();
    ctx.arc(cx, cy, s * 1.5, 0, Math.PI * 2);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(255,255,255,0.72)';
    ctx.lineWidth = Math.max(2, s * 0.2);
    ctx.beginPath();
    ctx.arc(cx, cy - s * 0.28, s * 0.42, Math.PI, 0);
    ctx.stroke();
    ctx.fillStyle = 'rgba(255,255,255,0.72)';
    rr(cx - s * 0.52, cy - s * 0.30, s * 1.04, s * 0.86, s * 0.14);
    ctx.fill();
    ctx.fillStyle = 'rgba(8,8,20,0.75)';
    ctx.beginPath();
    ctx.arc(cx, cy + s * 0.06, s * 0.14, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillRect(cx - s * 0.05, cy + s * 0.06, s * 0.10, s * 0.26);
    ctx.restore();
  }

  function drawSummit(isl, center, lit) {
    var p = project({ x: isl.x, y: isl.y, z: isl.z });
    if (!p) return;
    var h = isl.theme.glow;
    var r = Math.max(10, isl.r * 0.16 * p.s);
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    var g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r * 2.4);
    g.addColorStop(0, hsl(h, 96, 66, 0.22 * lit));
    g.addColorStop(0.5, hsl(h, 96, 66, 0.07 * lit));
    g.addColorStop(1, hsl(h, 96, 66, 0));
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(p.x, p.y, r * 2.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
    ctx.save();
    ctx.strokeStyle = hsl(h, 92, 74, 0.35 * lit);
    ctx.lineWidth = Math.max(0.8, r * 0.07);
    ctx.beginPath();
    ctx.ellipse(p.x, p.y, r * 1.05, r * 0.42, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function drawPlateau(isl, center, lit) {
    var R = 116, Hh = 36, N = 20;
    var h = isl.theme.glow;
    var top = [], bot = [];
    var i;
    for (i = 0; i < N; i++) {
      var a = i / N * Math.PI * 2;
      top.push(project({ x: isl.x + Math.cos(a) * R, y: isl.y + Hh, z: isl.z + Math.sin(a) * R }));
      bot.push(project({ x: isl.x + Math.cos(a) * R * 0.98, y: isl.y, z: isl.z + Math.sin(a) * R * 0.98 }));
    }
    var faces = [];
    for (i = 0; i < N; i++) {
      var j = (i + 1) % N;
      if (!top[i] || !top[j] || !bot[i] || !bot[j]) continue;
      faces.push({
        pts: [top[i], top[j], bot[j], bot[i]],
        depth: (top[i].z + top[j].z) / 2,
        i: i
      });
    }
    faces.sort(function (x, y) { return y.depth - x.depth; });
    for (i = 0; i < faces.length; i++) {
      var f = faces[i];
      ctx.beginPath();
      ctx.moveTo(f.pts[0].x, f.pts[0].y);
      for (var k = 1; k < 4; k++) ctx.lineTo(f.pts[k].x, f.pts[k].y);
      ctx.closePath();
      var sh = 0.7 + 0.4 * Math.cos(f.i * 1.1);
      var g = ctx.createLinearGradient(f.pts[0].x, f.pts[0].y, f.pts[0].x, f.pts[3].y);
      g.addColorStop(0, hsl(h, 42, 26 * lit * sh));
      g.addColorStop(1, hsl(h, 38, 8 * lit));
      ctx.fillStyle = g;
      ctx.fill();
    }
    ctx.beginPath();
    for (i = 0; i < top.length; i++) {
      if (!top[i]) continue;
      if (i === 0) ctx.moveTo(top[i].x, top[i].y); else ctx.lineTo(top[i].x, top[i].y);
    }
    ctx.closePath();
    var pg = ctx.createRadialGradient(center.x, center.y - 12, 4, center.x, center.y - 13, R * center.s * 1.1);
    pg.addColorStop(0, hsl(h, 52, 23 * lit));
    pg.addColorStop(1, hsl(h, 45, 13 * lit));
    ctx.fillStyle = pg;
    ctx.fill();
    ctx.strokeStyle = hsl(h, 88, 62, 0.42 * lit);
    ctx.lineWidth = Math.max(0.8, 1.6 * center.s);
    ctx.stroke();
  }

  function drawWaterfall(isl, tp, center) {
    /* ön kenardaki en alçak köşeden akan ışık */
    var best = null;
    for (var i = 0; i < tp.length; i++) {
      if (!tp[i]) continue;
      if (!best || tp[i].y > best.y) best = tp[i];
    }
    if (!best || center.s < 0.2) return;
    var h = isl.theme.glow;
    var len = 150 * center.s * 1.1;
    var x0 = best.x, y0 = best.y + 2;
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    var g = ctx.createLinearGradient(x0, y0, x0, y0 + len);
    g.addColorStop(0, hsl(h, 90, 70, 0.5));
    g.addColorStop(0.5, hsl(h, 90, 62, 0.16));
    g.addColorStop(1, hsl(h, 90, 60, 0));
    ctx.strokeStyle = g;
    ctx.lineWidth = Math.max(2, 4.5 * center.s * 1.2);
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(x0, y0);
    for (var k = 1; k <= 8; k++) {
      var u = k / 8;
      ctx.lineTo(x0 + Math.sin(u * 7 + t * 0.002 + isl.seed) * 5 * u, y0 + len * u);
    }
    ctx.stroke();
    ctx.restore();
  }

  function drawMonument(isl, center, lit) {
    var h = isl.theme.glow;
    var mh = 72 + isl.done * 3;
    var base = project({ x: isl.x, y: isl.y + 36, z: isl.z - isl.r * 0.16 });
    var top = project({ x: isl.x, y: isl.y + 36 + mh, z: isl.z - isl.r * 0.16 });
    if (!base || !top) return;
    var w = Math.max(2, 9 * base.s * 1.5);
    var midY = (top.y + base.y) / 2;

    ctx.save();
    ctx.shadowColor = hsl(h, 95, 62, 0.8 * lit);
    ctx.shadowBlur = 22 * lit;
    var g = ctx.createLinearGradient(base.x, top.y, base.x, base.y);
    g.addColorStop(0, hsl(h, 92, 80, 0.95 * lit));
    g.addColorStop(0.5, hsl(h, 88, 52, 0.9 * lit));
    g.addColorStop(1, hsl(h, 85, 32, 0.85 * lit));
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(base.x, top.y);
    ctx.lineTo(base.x + w, midY);
    ctx.lineTo(base.x + w * 0.55, base.y);
    ctx.lineTo(base.x - w * 0.55, base.y);
    ctx.lineTo(base.x - w, midY);
    ctx.closePath();
    ctx.fill();
    ctx.restore();

    ctx.strokeStyle = 'rgba(255,255,255,0.55)';
    ctx.lineWidth = Math.max(0.6, 1.1 * base.s * 1.4);
    ctx.beginPath();
    ctx.moveTo(base.x, top.y + 2);
    ctx.lineTo(base.x, base.y - 2);
    ctx.stroke();
  }

  function drawTopRing(isl, k, color) {
    var N = 22, pts = [], r = isl.r * k;
    var i;
    for (i = 0; i < N; i++) {
      var a = i / N * Math.PI * 2;
      pts.push(project({
        x: isl.x + Math.cos(a) * r,
        y: isl.y + 1,
        z: isl.z + Math.sin(a) * r
      }));
    }
    ctx.beginPath();
    var started = false;
    for (i = 0; i < N; i++) {
      if (!pts[i]) continue;
      if (!started) { ctx.moveTo(pts[i].x, pts[i].y); started = true; }
      else ctx.lineTo(pts[i].x, pts[i].y);
    }
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();
  }

  function drawPath(isl) {
    var ns = isl.nodes;
    if (!ns || ns.length < 2) return;
    var h = isl.theme.glow;
    ctx.save();
    ctx.lineCap = 'round';
    for (var i = 0; i < ns.length - 1; i++) {
      var a = ns[i], b = ns[i + 1];
      var pa = project({ x: a.x, y: a.y + 2, z: a.z });
      var pb = project({ x: b.x, y: b.y + 2, z: b.z });
      if (!pa || !pb) continue;
      var done = a.done && b.done;
      var sc = (pa.s + pb.s) / 2;
      if (done) {
        ctx.strokeStyle = hsl(h, 90, 62, 0.5);
        ctx.shadowColor = hsl(h, 95, 60, 0.8);
        ctx.shadowBlur = 12 * sc * 2;
        ctx.lineWidth = Math.max(2, 4.5 * sc * 1.6);
      } else {
        ctx.strokeStyle = 'rgba(255,255,255,0.14)';
        ctx.shadowBlur = 0;
        ctx.lineWidth = Math.max(1, 2 * sc * 1.6);
        ctx.setLineDash([2, 7]);
      }
      ctx.beginPath();
      ctx.moveTo(pa.x, pa.y);
      var mx = (pa.x + pb.x) / 2, my = (pa.y + pb.y) / 2;
      ctx.quadraticCurveTo(mx, my - 12 * sc, pb.x, pb.y);
      ctx.stroke();
      ctx.setLineDash([]);
    }
    ctx.restore();
  }

  function drawItems(isl) {
    var i;
    /* binalar ve dekor: derinliğe göre */
    var list = [];
    if (isl.items) {
      for (i = 0; i < isl.items.length; i++) {
        var it = isl.items[i];
        var p = project({ x: it.x, y: it.y, z: it.z });
        if (!p) continue;
        list.push({ p: p, item: it, z: p.z });
      }
    }
    list.sort(function (a, b) { return b.z - a.z; });
    for (i = 0; i < list.length; i++) {
      if (list[i].item.type === 'building') drawBuilding(isl, list[i].item, list[i].p);
      else drawDecor(isl, list[i].item, list[i].p);
    }

    /* kristal düğümler her zaman üstte (oynanabilirlik) */
    var ns = [];
    for (i = 0; i < isl.nodes.length; i++) {
      var nd = isl.nodes[i];
      var np = project({ x: nd.x, y: nd.y, z: nd.z });
      if (!np) { nd.screen = null; continue; }
      ns.push({ p: np, node: nd, z: np.z });
    }
    ns.sort(function (a, b) { return b.z - a.z; });
    for (i = 0; i < ns.length; i++) drawNode(isl, ns[i].node, ns[i].p);
  }

  function drawBuilding(isl, b, p) {
    var top = project({ x: b.x, y: b.y + b.h, z: b.z });
    if (!top) return;
    var bh = Math.max(4, p.y - top.y);
    var bw = Math.max(5, b.w * p.s * 2.6);
    var x = p.x - bw / 2, y = p.y - bh;

    /* gölge */
    ctx.fillStyle = 'rgba(0,0,0,0.4)';
    ctx.beginPath();
    ctx.ellipse(p.x, p.y + 2, bw * 0.85, bw * 0.28, 0, 0, Math.PI * 2);
    ctx.fill();

    var g = ctx.createLinearGradient(x, 0, x + bw, 0);
    g.addColorStop(0, hsl(b.hue, 58, 30));
    g.addColorStop(0.55, hsl(b.hue, 52, 19));
    g.addColorStop(1, hsl(b.hue, 48, 10));
    ctx.fillStyle = g;
    rr(x, y, bw, bh, Math.min(3, bw * 0.14));
    ctx.fill();

    /* neon kenar */
    ctx.strokeStyle = hsl(b.hue, 95, 66, 0.55);
    ctx.lineWidth = Math.max(0.6, 0.9 * p.s * 2);
    ctx.beginPath();
    ctx.moveTo(x + 0.6, y + bh);
    ctx.lineTo(x + 0.6, y + 2);
    ctx.stroke();

    /* çatı */
    ctx.beginPath();
    ctx.moveTo(x - bw * 0.14, y + 1);
    ctx.lineTo(p.x, y - bh * 0.42);
    ctx.lineTo(x + bw * 1.14, y + 1);
    ctx.closePath();
    ctx.fillStyle = hsl(b.hue, 45, 12);
    ctx.fill();
    ctx.strokeStyle = hsl(b.hue, 95, 68, 0.7);
    ctx.lineWidth = Math.max(0.5, 0.8 * p.s * 2);
    ctx.stroke();

    /* ince anten */
    if (b.h > 62) {
      ctx.strokeStyle = hsl(b.hue, 90, 68, 0.5);
      ctx.beginPath();
      ctx.moveTo(p.x, y - bh * 0.42);
      ctx.lineTo(p.x, y - bh * 0.42 - bh * 0.5);
      ctx.stroke();
      ctx.fillStyle = '#ffe9a8';
      ctx.beginPath();
      ctx.arc(p.x, y - bh * 0.42 - bh * 0.5, Math.max(0.8, 1.4 * p.s * 2), 0, Math.PI * 2);
      ctx.fill();
    }

    /* pencereler */
    var rows = Math.max(1, Math.floor(bh / 8));
    var cols = bw > 15 ? 2 : 1;
    var tw = 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(t * 0.002 + b.seed));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        var wx = x + bw * (c + 0.5) / cols - 1.5;
        var wy = y + bh * (r + 0.55) / rows;
        ctx.fillStyle = 'rgba(255,236,170,' + (0.25 + tw * 0.5) + ')';
        ctx.fillRect(wx, wy, 2.6, 3);
      }
    }
  }

  function drawDecor(isl, d, p) {
    var top = project({ x: d.x, y: d.y + d.h, z: d.z });
    if (!top) return;
    var hh = Math.max(3, p.y - top.y);
    var w = Math.max(2, d.h * p.s * 0.55);
    var crystal = d.seed % 3 !== 0;

    ctx.fillStyle = 'rgba(0,0,0,0.28)';
    ctx.beginPath();
    ctx.ellipse(p.x, p.y + 1, w * 0.9, w * 0.32, 0, 0, Math.PI * 2);
    ctx.fill();

    if (crystal) {
      /* sol parlak yüz */
      var g1 = ctx.createLinearGradient(p.x - w, top.y, p.x, p.y);
      g1.addColorStop(0, hsl(d.hue, 95, 78, 0.95));
      g1.addColorStop(1, hsl(d.hue, 85, 42, 0.55));
      ctx.fillStyle = g1;
      ctx.beginPath();
      ctx.moveTo(p.x, top.y);
      ctx.lineTo(p.x - w * 0.6, p.y - hh * 0.42);
      ctx.lineTo(p.x - w * 0.32, p.y);
      ctx.closePath();
      ctx.fill();
      /* sağ koyu yüz */
      var g2 = ctx.createLinearGradient(p.x, top.y, p.x + w, p.y);
      g2.addColorStop(0, hsl(d.hue, 82, 56, 0.8));
      g2.addColorStop(1, hsl(d.hue, 80, 24, 0.45));
      ctx.fillStyle = g2;
      ctx.beginPath();
      ctx.moveTo(p.x, top.y);
      ctx.lineTo(p.x + w * 0.72, p.y - hh * 0.36);
      ctx.lineTo(p.x + w * 0.36, p.y);
      ctx.closePath();
      ctx.fill();
      /* orta çizgi */
      ctx.strokeStyle = 'rgba(255,255,255,0.35)';
      ctx.lineWidth = Math.max(0.4, 0.8 * p.s);
      ctx.beginPath();
      ctx.moveTo(p.x, top.y + 1);
      ctx.lineTo(p.x, p.y - 1);
      ctx.stroke();
    } else {
      /* ağaç */
      ctx.fillStyle = hsl(d.hue, 60, 20, 0.8);
      ctx.fillRect(p.x - 1.2 * p.s, p.y - hh * 0.28, 2.4 * p.s, hh * 0.28);
      var g3 = ctx.createLinearGradient(p.x, top.y, p.x, p.y);
      g3.addColorStop(0, hsl(d.hue, 85, 58, 0.95));
      g3.addColorStop(1, hsl(d.hue, 70, 26, 0.7));
      ctx.fillStyle = g3;
      ctx.beginPath();
      ctx.moveTo(p.x, top.y);
      ctx.lineTo(p.x + w, p.y - hh * 0.15);
      ctx.lineTo(p.x + w * 0.35, p.y - hh * 0.2);
      ctx.lineTo(p.x + w * 0.62, p.y - hh * 0.04);
      ctx.lineTo(p.x, p.y - hh * 0.1);
      ctx.lineTo(p.x - w * 0.62, p.y - hh * 0.04);
      ctx.lineTo(p.x - w * 0.35, p.y - hh * 0.2);
      ctx.lineTo(p.x - w, p.y - hh * 0.15);
      ctx.closePath();
      ctx.fill();
    }
  }

  function drawNode(isl, nd, base) {
    var top = project({ x: nd.x, y: nd.y + 52, z: nd.z });
    if (!top) { nd.screen = null; return; }
    var mid = project({ x: nd.x, y: nd.y + 28, z: nd.z });
    if (!mid) { nd.screen = null; return; }

    var h = nd.d ? (MOD_HUE[nd.d.modifier] || 210) : 210;
    var sc = Math.max(0.5, base.s * 1.35);
    var cw = 9 * sc, ch = (base.y - top.y) * 0.5;
    var cy = (top.y + base.y) / 2;
    var pulse = 0.5 + 0.5 * Math.sin(t * 0.004 + nd.i);

    nd.screen = { x: base.x, y: cy, r: Math.max(18, 26 * sc) };

    /* gölge */
    ctx.fillStyle = 'rgba(0,0,0,0.32)';
    ctx.beginPath();
    ctx.ellipse(base.x, base.y + 2, cw * 1.5, cw * 0.6, 0, 0, Math.PI * 2);
    ctx.fill();

    if (nd.current) {
      /* ışık sütunu */
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      var bg = ctx.createLinearGradient(base.x, base.y, base.x, base.y - 160 * sc);
      bg.addColorStop(0, 'rgba(255,209,102,0.18)');
      bg.addColorStop(0.55, 'rgba(255,209,102,0.045)');
      bg.addColorStop(1, 'rgba(255,209,102,0)');
      ctx.fillStyle = bg;
      ctx.beginPath();
      ctx.moveTo(base.x - 6 * sc, base.y);
      ctx.lineTo(base.x - 2 * sc, base.y - 160 * sc);
      ctx.lineTo(base.x + 2 * sc, base.y - 160 * sc);
      ctx.lineTo(base.x + 6 * sc, base.y);
      ctx.closePath();
      ctx.fill();
      ctx.restore();

      /* altın halka */
      ctx.save();
      ctx.strokeStyle = 'rgba(255,209,102,' + (0.5 + pulse * 0.5) + ')';
      ctx.lineWidth = Math.max(1.6, 2.4 * sc);
      ctx.beginPath();
      ctx.ellipse(base.x, base.y + 2, cw * (2.1 + pulse * 0.35), cw * (0.9 + pulse * 0.15), 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    } else if (nd.done) {
      ctx.fillStyle = hsl(h, 90, 60, 0.22);
      ctx.beginPath();
      ctx.ellipse(base.x, base.y + 1, cw * 1.8, cw * 0.7, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    /* taş platform + tür rengi halkası */
    ctx.save();
    ctx.fillStyle = 'rgba(5,5,16,0.62)';
    ctx.beginPath();
    ctx.ellipse(base.x, base.y + 2, cw * 1.9, cw * 0.72, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = nd.unlocked ? hsl(h, 92, 66, nd.done ? 0.55 : 0.35) : hsl(h, 45, 55, 0.22);
    ctx.lineWidth = Math.max(0.8, 1.1 * sc);
    ctx.beginPath();
    ctx.ellipse(base.x, base.y + 2, cw * 1.75, cw * 0.62, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();

    /* kristal */
    var fill;
    if (!nd.unlocked) {
      fill = ctx.createLinearGradient(base.x, top.y, base.x, mid.y + ch);
      fill.addColorStop(0, hsl(h, 16, 46));
      fill.addColorStop(0.5, hsl(h, 14, 31));
      fill.addColorStop(1, hsl(h, 18, 17));
    } else if (nd.done) {
      fill = ctx.createLinearGradient(base.x, top.y, base.x, mid.y + ch);
      fill.addColorStop(0, hsl(h, 95, 78));
      fill.addColorStop(1, hsl(h, 88, 46));
    } else {
      fill = ctx.createLinearGradient(base.x, top.y, base.x, mid.y + ch);
      fill.addColorStop(0, hsl(h, 96, 76));
      fill.addColorStop(0.6, hsl(h, 90, 58));
      fill.addColorStop(1, hsl(h, 86, 40));
    }

    ctx.save();
    if (nd.unlocked) {
      ctx.shadowColor = hsl(h, 95, 60, nd.current ? 0.9 : 0.5);
      ctx.shadowBlur = (nd.current ? 18 : 9) * sc * 1.4;
    }
    var hover = Math.sin(t * 0.0022 + nd.i * 0.9) * 2.6 * sc;
    ctx.beginPath();
    ctx.moveTo(base.x, top.y + hover);
    ctx.lineTo(base.x + cw, cy + hover);
    ctx.lineTo(base.x, base.y - 6 * sc + hover);
    ctx.lineTo(base.x - cw, cy + hover);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    ctx.restore();

    /* iç çizgi */
    ctx.strokeStyle = 'rgba(255,255,255,' + (nd.unlocked ? 0.55 : 0.15) + ')';
    ctx.lineWidth = Math.max(0.6, 0.9 * sc);
    ctx.beginPath();
    ctx.moveTo(base.x, top.y + hover + 3);
    ctx.lineTo(base.x, base.y - 8 * sc + hover);
    ctx.stroke();

    /* numara / kilit */
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = '900 ' + Math.max(10, Math.round(12 * sc)) + 'px InterKule, system-ui, sans-serif';
    if (nd.unlocked) {
      ctx.fillStyle = nd.done ? 'rgba(12,10,24,0.9)' : '#fff';
      ctx.fillText(String(nd.d.num), base.x, cy + hover + 1);
    } else {
      ctx.fillStyle = 'rgba(255,255,255,0.38)';
      ctx.fillText(String(nd.d.num), base.x, cy + hover + 4);
      /* küçük çizilmiş asma kilit */
      var lx = base.x + cw * 0.9, ly = cy - cw * 1.35 + hover, lw = Math.max(3, 3.6 * sc);
      ctx.strokeStyle = 'rgba(255,255,255,0.45)';
      ctx.lineWidth = Math.max(0.7, 1.1 * sc);
      ctx.beginPath();
      ctx.arc(lx, ly - lw * 0.35, lw * 0.42, Math.PI, 0);
      ctx.stroke();
      ctx.fillStyle = 'rgba(255,255,255,0.45)';
      ctx.fillRect(lx - lw * 0.55, ly - lw * 0.3, lw * 1.1, lw * 0.95);
    }

    /* yıldızlar */
    if (nd.done) {
      var sy = base.y + 11 * sc;
      ctx.font = Math.max(7, Math.round(7.5 * sc)) + 'px InterKule, system-ui, sans-serif';
      for (var s = 0; s < 3; s++) {
        ctx.fillStyle = s < nd.stars ? '#ffd166' : 'rgba(255,255,255,0.2)';
        ctx.fillText('★', base.x - 7 * sc + s * 7 * sc, sy);
      }
    }

    /* hediye */
    if (nd.box && nd.unlocked) {
      var gx = base.x + cw * 2.4, gy = base.y - 22 * sc + Math.sin(t * 0.004 + nd.i) * 2.5;
      drawGift(gx, gy, Math.max(0.7, sc));
    }

    /* şimdi etiketi */
    if (nd.current) {
      ctx.font = '800 ' + Math.max(8, Math.round(9 * sc)) + 'px InterKule, system-ui, sans-serif';
      ctx.fillStyle = 'rgba(255,209,102,' + (0.65 + pulse * 0.35) + ')';
      ctx.fillText('ŞİMDİ', base.x, top.y - 12 * sc);
    }
  }

  function drawGift(x, y, s) {
    ctx.save();
    ctx.fillStyle = '#ffd166';
    rr(x - 7 * s, y - 5 * s, 14 * s, 11 * s, 2.5 * s);
    ctx.fill();
    ctx.fillStyle = '#ff9f43';
    ctx.fillRect(x - 2 * s, y - 5 * s, 4 * s, 11 * s);
    ctx.fillRect(x - 7 * s, y - 2.5 * s, 14 * s, 3 * s);
    ctx.fillStyle = '#ffb84d';
    ctx.beginPath();
    ctx.moveTo(x - 3 * s, y - 6 * s);
    ctx.lineTo(x, y - 9 * s);
    ctx.lineTo(x + 3 * s, y - 6 * s);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  var MOD_HUE = {
    normal: 206, ruzgar: 165, hizli: 45, karanlik: 262, altin: 48,
    yavas: 198, deprem: 12, akan: 296, patron: 338
  };

  /* --------------------------- günlük ada --------------------------- */

  function drawDaily() {
    if (!daily) return;
    var c = project({ x: daily.x, y: daily.y, z: daily.z });
    if (!c) return;
    var pulse = 0.5 + 0.5 * Math.sin(t * 0.0036);
    var r = daily.r * c.s;
    var top = project({ x: daily.x, y: daily.y + 74, z: daily.z });
    var bot = project({ x: daily.x, y: daily.y - daily.thick, z: daily.z });
    daily.screen = { x: c.x, y: c.y - 26 * c.s, r: Math.max(34, r * 1.15) };

    /* hale */
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    var halo = ctx.createRadialGradient(c.x, c.y, r * 0.2, c.x, c.y, r * 2.4);
    halo.addColorStop(0, 'rgba(255,209,102,' + (0.20 + pulse * 0.12) + ')');
    halo.addColorStop(1, 'rgba(255,209,102,0)');
    ctx.fillStyle = halo;
    ctx.beginPath();
    ctx.arc(c.x, c.y, r * 2.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    /* gövde */
    if (top && bot) {
      ctx.beginPath();
      ctx.moveTo(c.x - r, c.y);
      ctx.lineTo(c.x, c.y + r * 0.42);
      ctx.lineTo(c.x, bot.y);
      ctx.lineTo(c.x - r * 0.8, bot.y - 4);
      ctx.closePath();
      ctx.fillStyle = 'hsl(40,55%,22%)';
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(c.x + r, c.y);
      ctx.lineTo(c.x, c.y + r * 0.42);
      ctx.lineTo(c.x, bot.y);
      ctx.lineTo(c.x + r * 0.8, bot.y - 4);
      ctx.closePath();
      ctx.fillStyle = 'hsl(40,45%,14%)';
      ctx.fill();
    }
    ctx.beginPath();
    ctx.moveTo(c.x, c.y - r * 0.45);
    ctx.lineTo(c.x + r, c.y);
    ctx.lineTo(c.x, c.y + r * 0.45);
    ctx.lineTo(c.x - r, c.y);
    ctx.closePath();
    var g = ctx.createRadialGradient(c.x, c.y - r * 0.1, 0, c.x, c.y, r);
    g.addColorStop(0, 'hsl(48,88%,62%)');
    g.addColorStop(1, 'hsl(38,72%,34%)');
    ctx.fillStyle = g;
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,240,190,0.85)';
    ctx.lineWidth = 1.6;
    ctx.stroke();

    /* yıldız */
    ctx.font = '900 ' + Math.round(clamp(r * 0.9, 14, 34)) + 'px InterKule, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#6b4a00';
    ctx.fillText('★', c.x, c.y + 2);

    /* atan halka */
    ctx.save();
    ctx.strokeStyle = 'rgba(255,235,170,' + (0.35 + pulse * 0.5) + ')';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(c.x, c.y + 3, r * (1.25 + pulse * 0.18), r * (0.5 + pulse * 0.06), 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();

    /* etiket */
    ctx.font = '900 ' + Math.round(clamp(8.4 * (W / 390), 8, 10)) + 'px InterKule, system-ui, sans-serif';
    ctx.lineWidth = 3;
    ctx.strokeStyle = 'rgba(5,4,14,0.9)';
    ctx.globalAlpha = 0.9;
    ctx.strokeText('GÜNLÜK MEYDAN OKUMA', c.x, c.y - r - 14);
    ctx.fillStyle = '#ffe9a8';
    ctx.fillText('GÜNLÜK MEYDAN OKUMA', c.x, c.y - r - 14);
    var st = save && save.daily && save.daily.day === prog.dayOf(Date.now()) ? save.daily.best : 0;
    ctx.font = '700 ' + Math.round(clamp(7.6 * (W / 390), 7, 9)) + 'px InterKule, system-ui, sans-serif';
    ctx.globalAlpha = 0.7;
    ctx.strokeText('Bugünkü rekorun: ' + st, c.x, c.y + r + 16);
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    ctx.fillText('Bugünkü rekorun: ' + st, c.x, c.y + r + 16);
    ctx.globalAlpha = 1;
  }

  /* --------------------------- uzak takımada --------------------------- */

  function drawFarRocks(isl) {
    var glow = hslRgb(isl.theme.glow, 78, 55);
    for (var i = 0; i < farRocks.length; i++) {
      var rock = farRocks[i];
      var p = project({ x: rock.x, y: rock.y, z: rock.z });
      if (!p) continue;
      if (p.z < 1600) continue;
      if (p.x < -W * 0.4 || p.x > W * 1.4 || p.y < -H * 0.3 || p.y > H * 1.3) continue;
      var r = rock.r * p.s;
      if (r < 2 || r > 130) continue;
      var fog = clamp((p.z - 1500) / 2900, 0.3, 0.85);
      ctx.save();
      ctx.globalAlpha = 0.34 * (1 - fog);
      ctx.fillStyle = rgb(mix(glow, [8, 8, 20], 0.72));
      ctx.beginPath();
      for (var k = 0; k < 7; k++) {
        var a = k / 7 * Math.PI * 2;
        var rr2 = r * (0.65 + 0.35 * Math.sin(k * 2.1 + rock.seed));
        var px = p.x + Math.cos(a) * rr2;
        var py = p.y + Math.sin(a) * rr2 * 0.72;
        if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
      }
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }
  }

  /* ------------------------- köprüler (yükseliş) ------------------------- */

  function drawBridges() {
    if (!islands.length) return;
    for (var s = 0; s < islands.length - 1; s++) {
      var a = islands[s], b = islands[s + 1];
      if (!(a.open && a.done >= (levels ? levels.LEVELS_PER_STAGE : 15))) continue;

      var from = project({ x: a.x, y: a.y + 90, z: a.z });
      var to = project({ x: b.x, y: b.y + 80, z: b.z });
      var mid = project({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + 210, z: (a.z + b.z) / 2 });
      if (!from || !to || !mid) continue;

      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      for (var k = 0; k <= 22; k++) {
        var u = k / 22;
        var px = (1 - u) * (1 - u) * from.x + 2 * (1 - u) * u * mid.x + u * u * to.x;
        var py = (1 - u) * (1 - u) * from.y + 2 * (1 - u) * u * mid.y + u * u * to.y;
        var tw = 0.5 + 0.5 * Math.sin(t * 0.002 + k * 0.55 + s);
        ctx.fillStyle = 'rgba(170,255,232,' + (0.10 + tw * 0.30) + ')';
        ctx.beginPath();
        ctx.arc(px, py, 1.4 + tw * 1.6, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }
  }

  /* ------------------------------ ön plan ------------------------------ */

  function drawForeground() {
    /* alt bulut denizi */
    ctx.save();
    for (var i = 0; i < 5; i++) {
      var y = H * (0.86 + i * 0.035);
      var g = ctx.createLinearGradient(0, y - 50, 0, y + 70);
      g.addColorStop(0, 'rgba(200,220,255,0)');
      g.addColorStop(0.5, 'rgba(200,220,255,' + (0.028 + i * 0.008) + ')');
      g.addColorStop(1, 'rgba(200,220,255,0)');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.ellipse(W * 0.5 + Math.sin(t * 0.00008 + i) * W * 0.18, y, W * 0.8, 58, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();

    /* vinyet */
    var vg = ctx.createRadialGradient(W * 0.5, H * 0.48, Math.min(W, H) * 0.22, W * 0.5, H * 0.5, Math.max(W, H) * 0.78);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(0.72, 'rgba(2,2,10,0.18)');
    vg.addColorStop(1, 'rgba(2,2,10,0.62)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, W, H);
  }

  /* ------------------------------ API ------------------------------ */

  var API = {
    init: init,
    setSave: setSave,
    refresh: function () { layout(); },
    draw: function () { updateCamera(0.016); render(); },
    centerCurrent: function () {
      for (var i = 0; i < nodes.length; i++) {
        if (nodes[i].current) {
          setFocus(nodes[i].isl.stage);
          updateCamera(1);
          return;
        }
      }
      if (nodes.length) { setFocus(nodes[nodes.length - 1].isl.stage); updateCamera(1); }
    },
    setFocus: setFocus,
    getFocus: function () { return focusStage; },
    focusWorld: function (s) { setFocus(s); },
    nextWorld: function () { setFocus(focusStage + 1); },
    prevWorld: function () { setFocus(focusStage - 1); },
    worldInfo: function () {
      var isl = byStage[focusStage];
      if (!isl) return null;
      return {
        stage: isl.stage, name: isl.theme.name, done: isl.done, total: levels.LEVELS_PER_STAGE,
        stars: isl.stars, maxStars: levels.LEVELS_PER_STAGE * 3,
        open: isl.open, need: isl.need,
        lore: levels.WORLD_LORE[isl.stage] || ''
      };
    },
    /* test/etkileşim kancaları */
    nodeScreen: function (i) {
      var nd = nodes[i];
      return nd && nd.screen ? { x: nd.screen.x, y: nd.screen.y } : null;
    },
    dailyScreen: function () { return daily && daily.screen ? { x: daily.screen.x, y: daily.screen.y } : null; },
    hit: function (px, py) { hit(px, py); },
    islandCenter: function (s) { var isl = byStage[s]; return isl && isl.center ? isl.center : null; },
    camera: function () { return { x: eye.x, y: eye.y, z: eye.z, yaw: cam.yaw, pitch: cam.pitch }; },
    isRunning: function () { return running; }
  };

  if (root) root.NeonMap = API;
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
})(typeof globalThis !== 'undefined' ? globalThis : this);
