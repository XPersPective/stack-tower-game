/* ============================================================
   NEON KULE — BÖLÜM SİNEMATİĞİ
   Bir bölüme dokununca açılan canlı dünya önizlemesi:
   • Dünyanın silueti, göğü, havası — ama tamamı değil (gizem)
   • Önde oynanacak kule, solda fısıldayan bir geçit
   • Panel metinleriyle birlikte sinematik bir "buraya giriyorsun" anı
   ============================================================ */
(function (root) {
  'use strict';

  var canvas = null, ctx = null;
  var W = 0, H = 0, dpr = 1;
  var def = null, running = false, t = 0, last = 0, raf = null;
  var particles = [], seed = 1, stars = [];

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

  function rgba(c, a) { return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'; }
  function hsl(h, s, l, a) {
    return a === undefined ? 'hsl(' + h + ',' + s + '%,' + l + '%)'
      : 'hsla(' + h + ',' + s + '%,' + l + '%,' + a + ')';
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

  function perfNow() {
    return (root.performance && root.performance.now) ? root.performance.now() : Date.now();
  }

  function init(el) {
    canvas = el;
    if (!canvas) return API;
    ctx = canvas.getContext('2d');
    root.addEventListener('resize', function () { if (running) resize(); });
    return API;
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

  function open(d) {
    if (!canvas) return;
    def = d;
    seed = Math.abs(d.i) * 977 + (d.stage + 1) * 131 + (d.daily ? 7 : 0);
    t = 0;
    last = perfNow();
    resize();
    buildParticles();
    running = true;
    if (raf) root.cancelAnimationFrame && root.cancelAnimationFrame(raf);
    raf = root.requestAnimationFrame(loop);
    draw(0);
  }

  function close() {
    running = false;
    if (raf && root.cancelAnimationFrame) root.cancelAnimationFrame(raf);
    raf = null;
  }

  function loop(ts) {
    if (!running) return;
    raf = root.requestAnimationFrame(loop);
    var dt = Math.min(0.05, Math.max(0.001, (ts - last) / 1000) || 0.016);
    last = ts;
    t += dt;
    draw(dt);
  }

  /* --------------------------- parçacıklar --------------------------- */

  function rnd() { seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296; }

  function buildParticles() {
    particles = [];
    var weather = def.theme.weather;
    var n = weather === 'stars' ? 46 : 54;
    for (var i = 0; i < n; i++) {
      particles.push({
        x: rnd(), y: rnd(),
        s: 0.6 + rnd() * 2.2,
        v: 0.008 + rnd() * 0.03,
        ph: rnd() * Math.PI * 2,
        a: 0.25 + rnd() * 0.6,
        rot: rnd() * Math.PI
      });
    }
    stars = [];
    for (i = 0; i < 80; i++) {
      stars.push({ x: rnd(), y: rnd() * 0.68, s: 0.5 + rnd() * 1.4, ph: rnd() * 6.28 });
    }
  }

  /* ------------------------------ çizim ------------------------------ */

  function draw(dt) {
    if (!ctx || !def) return;
    if (!W || !H) resize();
    var theme = def.theme;
    var c0 = hexRgb(theme.bg[0]);
    var c1 = hexRgb(theme.bg[1]);
    var glow = hslRgb(theme.glow, 92, 62);
    var deep = [3, 3, 12];

    /* gökyüzü */
    var sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, rgba(mix(deep, c0, 0.45), 1));
    sky.addColorStop(0.42, rgba(c0, 1));
    sky.addColorStop(0.72, rgba(c1, 1));
    sky.addColorStop(1, rgba(mix(c1, [4, 4, 12], 0.6), 1));
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, W, H);

    var drift = Math.sin(t * 0.09) * W * 0.012;

    /* yıldızlar */
    for (var i = 0; i < stars.length; i++) {
      var s = stars[i];
      var tw = 0.4 + 0.6 * (0.5 + 0.5 * Math.sin(t * 1.7 + s.ph));
      ctx.globalAlpha = tw * 0.8;
      ctx.fillStyle = '#eaf2ff';
      ctx.beginPath();
      ctx.arc(s.x * W + drift * 0.4, s.y * H, s.s, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    /* dev ay / gezegen */
    var mx = W * 0.52 + drift * 2;
    var my = H * 0.27;
    var mr = Math.min(W, H) * (def.daily ? 0.09 : 0.105);
    var halo = ctx.createRadialGradient(mx, my, mr * 0.2, mx, my, mr * 2.6);
    halo.addColorStop(0, rgba(glow, 0.5));
    halo.addColorStop(0.35, rgba(glow, 0.14));
    halo.addColorStop(1, rgba(glow, 0));
    ctx.fillStyle = halo;
    ctx.beginPath();
    ctx.arc(mx, my, mr * 2.6, 0, Math.PI * 2);
    ctx.fill();

    var disc = ctx.createRadialGradient(mx - mr * 0.35, my - mr * 0.4, mr * 0.1, mx, my, mr);
    disc.addColorStop(0, rgba(mix(glow, [255, 255, 255], 0.55), 0.95));
    disc.addColorStop(0.6, rgba(glow, 0.55));
    disc.addColorStop(1, rgba(mix(glow, c0, 0.55), 0.25));
    ctx.fillStyle = disc;
    ctx.beginPath();
    ctx.arc(mx, my, mr, 0, Math.PI * 2);
    ctx.fill();

    /* aurora */
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    for (i = 0; i < 2; i++) {
      var ay = H * (0.24 + i * 0.08) + Math.sin(t * 0.3 + i) * 8;
      var ag = ctx.createLinearGradient(0, ay - 60, 0, ay + 70);
      ag.addColorStop(0, rgba(glow, 0));
      ag.addColorStop(0.5, rgba(glow, 0.09));
      ag.addColorStop(1, rgba(glow, 0));
      ctx.strokeStyle = ag;
      ctx.lineWidth = 60 + i * 30;
      ctx.beginPath();
      ctx.moveTo(-40, ay);
      ctx.bezierCurveTo(W * 0.3, ay - 55, W * 0.72, ay + 60, W + 40, ay - 14);
      ctx.stroke();
    }
    ctx.restore();

    /* ufuk parıltısı */
    var hz = ctx.createRadialGradient(W * 0.5, H * 0.6, 10, W * 0.5, H * 0.6, W * 0.9);
    hz.addColorStop(0, rgba(glow, 0.20));
    hz.addColorStop(0.5, rgba(glow, 0.06));
    hz.addColorStop(1, rgba(glow, 0));
    ctx.fillStyle = hz;
    ctx.fillRect(0, H * 0.36, W, H * 0.38);

    /* dünya siluetleri — üç katman, paralaks */
    var horizon = H * 0.46;
    for (var layer = 0; layer < 3; layer++) {
      var ly = horizon + layer * H * 0.045;
      var fog = [0.45, 0.30, 0.16][layer];
      var col = rgba(mix(c1, [4, 4, 11], 0.76 - layer * 0.1), 1);
      ctx.save();
      ctx.globalAlpha = 1 - layer * 0.05;
      drawSilhouette(theme.silhouette, ly, drift * (layer + 1) * 1.3, col, layer);
      ctx.restore();
      /* sis bandı */
      var fg = ctx.createLinearGradient(0, ly - 30, 0, ly + 22);
      fg.addColorStop(0, rgba(mix(c1, glow, 0.2), 0));
      fg.addColorStop(0.55, rgba(mix(c1, glow, 0.22), fog * 0.22));
      fg.addColorStop(1, rgba(mix(c1, glow, 0.2), 0));
      ctx.fillStyle = fg;
      ctx.fillRect(0, ly - 30, W, 52);
    }

    /* gizem geçidi */
    drawGate(W * 0.17 + drift, H * 0.5, glow);

    /* oynanacak kule (ön plan) */
    drawTower(W * 0.73 + drift * 1.4, H * 0.80, Math.min(W, H) / 420 * 2.1, def.theme.glow);

    /* hava parçacıkları */
    drawWeather(theme.weather, glow);

    /* okunabilirlik + vinyet */
    var veil = ctx.createLinearGradient(0, H * 0.42, 0, H);
    veil.addColorStop(0, 'rgba(4,4,12,0)');
    veil.addColorStop(0.5, 'rgba(4,4,12,0.42)');
    veil.addColorStop(1, 'rgba(4,4,12,0.92)');
    ctx.fillStyle = veil;
    ctx.fillRect(0, H * 0.42, W, H * 0.58);

    var vg = ctx.createRadialGradient(W * 0.5, H * 0.42, Math.min(W, H) * 0.2, W * 0.5, H * 0.5, Math.max(W, H) * 0.8);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(1, 'rgba(0,0,0,0.55)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, W, H);
  }

  function drawSilhouette(kind, baseY, drift, color, layer) {
    ctx.fillStyle = color;
    if (kind === 'city') {
      var x = -60 + drift;
      var k = 0;
      while (x < W + 60) {
        var w = 22 + ((k * 37 + layer * 13) % 52);
        var h = 24 + ((k * 53 + layer * 31) % 120);
        ctx.fillStyle = color;
        ctx.fillRect(x, baseY - h, w, h + 120);
        if (k % 4 === 0) ctx.fillRect(x + w * 0.4, baseY - h - 14, 2.4, 14);
        /* uzak şehir ışıkları */
        if (layer > 0) {
          var cols2 = Math.max(1, Math.floor(w / 11));
          for (var wc = 0; wc < cols2; wc++) {
            ctx.fillStyle = 'rgba(255,225,160,' + (0.10 + ((k * 3 + wc) % 4) * 0.05) + ')';
            ctx.fillRect(x + 5 + wc * 10, baseY - h + 9 + ((k + wc) % 5) * 11, 2.4, 3.4);
          }
          ctx.fillStyle = 'rgba(150,220,255,0.22)';
          ctx.fillRect(x, baseY - h, w, 1.2);
        }
        x += w + 6 + ((k * 7) % 12);
        k++;
      }
    } else if (kind === 'trees') {
      var tx = -40 + drift;
      var n = 0;
      while (tx < W + 40) {
        var th = 32 + ((n * 29 + layer * 11) % 70);
        var tw2 = 16 + ((n * 17) % 18);
        ctx.beginPath();
        ctx.moveTo(tx, baseY - th);
        ctx.lineTo(tx + tw2, baseY + 90);
        ctx.lineTo(tx - tw2, baseY + 90);
        ctx.closePath();
        ctx.fill();
        tx += tw2 + 8;
        n++;
      }
    } else if (kind === 'dunes' || kind === 'clouds') {
      ctx.beginPath();
      ctx.moveTo(-40, baseY + 90);
      var dx = -40;
      var step = W / 5;
      while (dx < W + 40) {
        ctx.quadraticCurveTo(dx + step * 0.5, baseY - 20 - (layer * 10), dx + step, baseY + 10);
        dx += step;
      }
      ctx.lineTo(W + 40, baseY + 110);
      ctx.closePath();
      ctx.fill();
    } else if (kind === 'ice') {
      ctx.beginPath();
      ctx.moveTo(-40, baseY + 90);
      var ix = -40;
      var m = 0;
      while (ix < W + 40) {
        var ih = 40 + ((m * 43 + layer * 17) % 90);
        ctx.lineTo(ix, baseY + 90);
        ctx.lineTo(ix + 26, baseY - ih);
        ctx.lineTo(ix + 44, baseY + 90);
        ix += 44;
        m++;
      }
      ctx.closePath();
      ctx.fill();
    } else if (kind === 'rocks') {
      for (var r = 0; r < 9; r++) {
        var rx = ((r * 137 + layer * 41) % (W + 80)) - 40 + drift * (r % 3);
        var ry = baseY - 20 + ((r * 53) % 40);
        var rr = 14 + ((r * 19) % 40);
        ctx.beginPath();
        for (var q = 0; q < 6; q++) {
          var a = q / 6 * Math.PI * 2;
          var rad = rr * (0.6 + 0.4 * Math.sin(q * 2.3 + r));
          var px = rx + Math.cos(a) * rad;
          var py = ry + Math.sin(a) * rad * 0.7;
          if (q === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        }
        ctx.closePath();
        ctx.fill();
      }
    } else {
      /* volkan */
      ctx.beginPath();
      ctx.moveTo(-60, baseY + 90);
      ctx.lineTo(W * 0.28 + drift, baseY - 190);
      ctx.lineTo(W * 0.46 + drift, baseY + 90);
      ctx.closePath();
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(W * 0.42 + drift, baseY + 90);
      ctx.lineTo(W * 0.66 + drift, baseY - 110);
      ctx.lineTo(W + 60, baseY + 90);
      ctx.closePath();
      ctx.fill();
      /* lav çatlağı */
      ctx.strokeStyle = 'rgba(255,120,60,0.45)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(W * 0.28 + drift, baseY - 180);
      ctx.lineTo(W * 0.24 + drift, baseY - 110);
      ctx.lineTo(W * 0.31 + drift, baseY - 50);
      ctx.stroke();
    }
  }

  function drawGate(x, y, glow) {
    var r = Math.min(W, H) * 0.095;
    var pulse = 0.5 + 0.5 * Math.sin(t * 1.1);
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    var g = ctx.createRadialGradient(x, y - r * 0.3, 0, x, y - r * 0.3, r * 2.2);
    g.addColorStop(0, rgba(glow, 0.22 + pulse * 0.12));
    g.addColorStop(1, rgba(glow, 0));
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(x, y - r * 0.3, r * 2.2, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = rgba(glow, 0.55);
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    ctx.arc(x, y - r * 0.3, r, Math.PI, 0);
    ctx.lineTo(x + r, y + r * 0.8);
    ctx.moveTo(x - r, y - r * 0.3);
    ctx.lineTo(x - r, y + r * 0.8);
    ctx.stroke();

    ctx.fillStyle = rgba([255, 255, 255], 0.16 + pulse * 0.12);
    ctx.font = '900 ' + Math.round(r * 0.9) + 'px InterKule, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('?', x, y - r * 0.2);
    ctx.restore();
  }

  function drawTower(x, baseY, sc, hue) {
    var glow = hslRgb(hue, 92, 64);
    var widths = [104, 90, 78, 66, 56, 44, 32];
    var heights = [28, 25, 23, 21, 19, 17, 15];
    var y = baseY;
    var offset = 0;
    ctx.save();
    for (var i = 0; i < widths.length; i++) {
      var w = widths[i] * sc * 0.9;
      var h = heights[i] * sc;
      var bx = x - w / 2 + offset;
      /* blok gövdesi */
      var bg = ctx.createLinearGradient(bx, y - h, bx + w, y);
      bg.addColorStop(0, 'rgba(9,9,20,0.98)');
      bg.addColorStop(0.75, 'rgba(16,14,32,0.98)');
      bg.addColorStop(1, 'rgba(24,20,46,0.98)');
      ctx.fillStyle = bg;
      ctx.fillRect(bx, y - h, w, h);
      /* neon kenar */
      ctx.strokeStyle = hsl(hue, 94, 68, 0.8 - i * 0.05);
      ctx.lineWidth = 2;
      ctx.strokeRect(bx + 0.5, y - h + 0.5, w - 1, h - 1);
      /* üst kenar parlaması */
      ctx.strokeStyle = hsl(hue, 96, 78, 0.5 - i * 0.03);
      ctx.beginPath();
      ctx.moveTo(bx, y - h + 0.6);
      ctx.lineTo(bx + w, y - h + 0.6);
      ctx.stroke();
      /* pencere ışıkları */
      var cols = Math.max(2, Math.round(w / (13 * sc)));
      for (var c = 0; c < cols; c++) {
        if ((i * 7 + c) % 3 === 0) continue;
        ctx.fillStyle = hsl(46, 90, 68, 0.25 + 0.35 * (0.5 + 0.5 * Math.sin(t * 2 + i + c)));
        ctx.fillRect(bx + (c + 0.5) * w / cols - 1.5, y - h * 0.55, 3, 4);
      }
      y -= h;
      offset += (widths[i] - widths[i + 1] || 0) * sc * 0.05;
    }
    /* tepe kristali */
    var cw = 20 * sc, ch = 34 * sc;
    ctx.shadowColor = hsl(0, 0, 100, 0.55);
    ctx.shadowBlur = 24;
    var cg = ctx.createLinearGradient(x, y - ch, x, y);
    cg.addColorStop(0, 'rgba(255,255,255,0.95)');
    cg.addColorStop(0.5, rgba(glow, 0.95));
    cg.addColorStop(1, rgba(glow, 0.35));
    ctx.fillStyle = cg;
    ctx.beginPath();
    ctx.moveTo(x, y - ch);
    ctx.lineTo(x + cw / 2, y - ch * 0.45);
    ctx.lineTo(x, y);
    ctx.lineTo(x - cw / 2, y - ch * 0.45);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawWeather(kind, glow) {
    ctx.save();
    if (kind === 'embers') ctx.globalCompositeOperation = 'lighter';
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      var x = p.x * W;
      var y = p.y * H;
      if (kind === 'snow') {
        y = ((p.y + t * p.v * 0.5) % 1) * H * 0.8;
        x += Math.sin(t * 0.6 + p.ph) * 14;
        ctx.fillStyle = 'rgba(226,242,255,' + (p.a * 0.55) + ')';
        ctx.beginPath();
        ctx.arc(x, y, p.s * 0.85, 0, Math.PI * 2);
        ctx.fill();
      } else if (kind === 'sand') {
        x = ((p.x + t * p.v * 1.4) % 1) * W;
        y = H * 0.45 + p.y * H * 0.35;
        ctx.strokeStyle = 'rgba(255,220,160,' + (p.a * 0.35) + ')';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + 16 * p.s, y - 1.5);
        ctx.stroke();
      } else if (kind === 'leaves') {
        x = ((p.x + t * p.v * 0.35) % 1) * W;
        y = ((p.y + t * p.v * 0.22) % 1) * H * 0.75;
        ctx.fillStyle = hsl(120 + (i % 3) * 18, 65, 55, p.a * 0.5);
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(t * 0.8 + p.rot);
        ctx.fillRect(-2, -1, 4.5, 2);
        ctx.restore();
      } else if (kind === 'embers') {
        y = H - ((p.y + t * p.v * 0.5) % 1) * H * 0.62;
        x += Math.sin(t * 0.7 + p.ph) * 18;
        ctx.fillStyle = hsl(26, 95, 62, p.a * 0.55);
        ctx.beginPath();
        ctx.arc(x, y, p.s * 0.7, 0, Math.PI * 2);
        ctx.fill();
      } else {
        var tw = 0.4 + 0.6 * (0.5 + 0.5 * Math.sin(t * 1.4 + p.ph));
        ctx.fillStyle = 'rgba(200,232,255,' + (p.a * tw * 0.6) + ')';
        ctx.beginPath();
        ctx.arc(x, y * 0.7, p.s * 0.75, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();
  }

  var API = {
    init: init,
    open: open,
    close: close,
    draw: function (ms) { draw(ms || 0); },
    isRunning: function () { return running; },
    player: function () { return def; }
  };

  if (root) root.NeonPreview = API;
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
})(typeof globalThis !== 'undefined' ? globalThis : this);
