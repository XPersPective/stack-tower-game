#!/usr/bin/env node
/* ============================================================
   NEON KULE — simge ve açılış görseli üretici
   Saf Node (bağımlılık yok). Mevcut PNG'lerin boyutlarını okur
   ve aynı boyutlarda neon kule görselini yeniden üretir.
   Çalıştır: npm run icons   (node tools/make-icons.js)
   ============================================================ */
'use strict';
var fs = require('fs');
var path = require('path');
var zlib = require('zlib');

var root = path.join(__dirname, '..');

/* ------------------------- PNG kodlayıcı ------------------------- */

var CRC_TABLE = (function () {
  var t = new Int32Array(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  var c = 0xFFFFFFFF;
  for (var i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

function chunk(type, data) {
  var len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  var td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  var crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td), 0);
  return Buffer.concat([len, td, crc]);
}

/* noAlpha = true -> App Store için alfa kanalsız RGB (Apple reddeder). */
function encodePNG(img, noAlpha) {
  var bpp = noAlpha ? 3 : 4;
  var ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0);
  ihdr.writeUInt32BE(img.h, 4);
  ihdr[8] = 8;                       // bit derinliği
  ihdr[9] = noAlpha ? 2 : 6;         // 2 = RGB, 6 = RGBA
  var stride = 1 + img.w * bpp;
  var raw = Buffer.alloc(img.h * stride);
  for (var y = 0; y < img.h; y++) {
    var ro = y * stride;
    raw[ro] = 0;                     // filtre: none
    for (var x = 0; x < img.w; x++) {
      var si = (y * img.w + x) * 4;
      var di = ro + 1 + x * bpp;
      raw[di] = img.data[si];
      raw[di + 1] = img.data[si + 1];
      raw[di + 2] = img.data[si + 2];
    }
  }
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0))
  ]);
}

function pngSize(file) {
  var b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

/* ------------------------- Çizim çekirdeği ------------------------- */

function makeImg(w, h) {
  return { w: w, h: h, data: new Uint8Array(w * h * 4) };
}

function hsl(h, s, l) {
  h = ((h % 360) + 360) % 360; s /= 100; l /= 100;
  var c = (1 - Math.abs(2 * l - 1)) * s;
  var x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  var m = l - c / 2, r = 0, g = 0, b = 0;
  if (h < 60) { r = c; g = x; }
  else if (h < 120) { r = x; g = c; }
  else if (h < 180) { g = c; b = x; }
  else if (h < 240) { g = x; b = c; }
  else if (h < 300) { r = x; b = c; }
  else { r = c; b = x; }
  return [(r + m) * 255, (g + m) * 255, (b + m) * 255];
}

function hex(hexStr) {
  var v = parseInt(hexStr.slice(1), 16);
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
}

/* kaynak-over birleştir (x,y tam sayı piksel) */
function blend(img, x, y, r, g, b, a) {
  if (a <= 0 || x < 0 || y < 0 || x >= img.w || y >= img.h) return;
  var i = (y * img.w + x) * 4;
  var d = img.data;
  var ia = 1 - a;
  d[i] = (r * a + d[i] * ia + 0.5) | 0;
  d[i + 1] = (g * a + d[i + 1] * ia + 0.5) | 0;
  d[i + 2] = (b * a + d[i + 2] * ia + 0.5) | 0;
  d[i + 3] = (255 * a + d[i + 3] * ia + 0.5) | 0;
}

/* toplamsal parlama (arka plan parlaması için) */
function addGlow(img, cx, cy, rad, rgb, strength) {
  var x0 = Math.max(0, Math.floor(cx - rad)), x1 = Math.min(img.w - 1, Math.ceil(cx + rad));
  var y0 = Math.max(0, Math.floor(cy - rad)), y1 = Math.min(img.h - 1, Math.ceil(cy + rad));
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      var dx = x + 0.5 - cx, dy = y + 0.5 - cy;
      var d = Math.sqrt(dx * dx + dy * dy);
      if (d >= rad) continue;
      var t = 1 - d / rad;
      var a = strength * t * t;
      var i = (y * img.w + x) * 4;
      var dd = img.data;
      dd[i] = Math.min(255, dd[i] + rgb[0] * a) | 0;
      dd[i + 1] = Math.min(255, dd[i + 1] + rgb[1] * a) | 0;
      dd[i + 2] = Math.min(255, dd[i + 2] + rgb[2] * a) | 0;
      dd[i + 3] = 255;
    }
  }
}

function fillVGradient(img, top, bottom) {
  var max = Math.max(1, img.h - 1);
  for (var y = 0; y < img.h; y++) {
    var t = y / max;
    var r = (top[0] + (bottom[0] - top[0]) * t + 0.5) | 0;
    var g = (top[1] + (bottom[1] - top[1]) * t + 0.5) | 0;
    var b = (top[2] + (bottom[2] - top[2]) * t + 0.5) | 0;
    for (var x = 0; x < img.w; x++) {
      var i = (y * img.w + x) * 4;
      img.data[i] = r; img.data[i + 1] = g; img.data[i + 2] = b; img.data[i + 3] = 255;
    }
  }
}

/* yuvarlatılmış dikdörtgen mesafe alanı (SDF) */
function sdRR(px, py, cx, cy, hw, hh, r) {
  var qx = Math.abs(px - cx) - hw + r;
  var qy = Math.abs(py - cy) - hh + r;
  var ax = qx > 0 ? qx : 0, ay = qy > 0 ? qy : 0;
  return Math.sqrt(ax * ax + ay * ay) + Math.min(Math.max(qx, qy), 0) - r;
}

/* Neon blok: parlama halesi + gövde + açık renkli üst yüz */
function drawBar(img, x, y, w, h, rgb) {
  var cx = x + w / 2, cy = y + h / 2;
  var hw = w / 2, hh = h / 2;
  var r = Math.max(2, h * 0.26);
  var pad = Math.max(4, h * 0.75);           // hale genişliği
  var light = [Math.min(255, rgb[0] * 0.45 + 255 * 0.55),
               Math.min(255, rgb[1] * 0.45 + 255 * 0.55),
               Math.min(255, rgb[2] * 0.45 + 255 * 0.55)];

  var x0 = Math.max(0, Math.floor(x - pad)), x1 = Math.min(img.w - 1, Math.ceil(x + w + pad));
  var y0 = Math.max(0, Math.floor(y - pad)), y1 = Math.min(img.h - 1, Math.ceil(y + h + pad));

  for (var py = y0; py <= y1; py++) {
    for (var px = x0; px <= x1; px++) {
      var d = sdRR(px + 0.5, py + 0.5, cx, cy, hw, hh, r);
      if (d > pad) continue;
      if (d > 0) {
        var t = 1 - d / pad;
        blend(img, px, py, rgb[0], rgb[1], rgb[2], 0.42 * t * t);
      } else {
        var cov = Math.min(1, Math.max(0, 0.5 - d));
        var vy = (py + 0.5 - y) / h;          // 0 üst, 1 alt
        var col = vy < 0.26 ? light : rgb;
        var shade = vy < 0.26 ? 1 : (1 - 0.20 * vy);
        blend(img, px, py, col[0] * shade, col[1] * shade, col[2] * shade, cov);
      }
    }
  }
}

/* Üç neon bloktan oluşan kule. bottomY: en alt bloğun alt kenarı. */
function drawTower(img, cx, bottomY, towerH) {
  var barH = towerH * 0.255;
  var gap = towerH * 0.055;
  var bottomW = towerH * 1.02;
  var widths = [bottomW, bottomW * 0.74, bottomW * 0.53];
  var colors = [hsl(210, 92, 60), hsl(268, 92, 66), hsl(322, 92, 70)];
  var yTop = bottomY;
  for (var i = 0; i < 3; i++) {
    var w = widths[i];
    yTop -= barH;
    drawBar(img, cx - w / 2, yTop, w, barH, colors[i]);
    yTop -= gap;
  }
}

/* --------------------------- Görsel tarifleri --------------------------- */

function iconImage(size, opaque) {
  var img = makeImg(size, size);
  var s = size;
  fillVGradient(img, hex('#0c0a20'), hex('#1e1046'));
  addGlow(img, s * 0.5, s * 0.56, s * 0.86, hsl(268, 88, 58), 0.32);
  addGlow(img, s * 0.5, s * 0.80, s * 0.55, hsl(210, 90, 55), 0.18);
  drawTower(img, s * 0.5, s * 0.745, s * 0.46);
  if (opaque) {
    for (var i = 3; i < img.data.length; i += 4) img.data[i] = 255;
  }
  return img;
}

/* Uyarlanabilir simge öne planı: şeffaf zemin, güvenli alan içinde. */
function foregroundImage(size) {
  var img = makeImg(size, size);
  drawTower(img, size * 0.5, size * 0.5 + size * 0.42 / 2, size * 0.42);
  return img;
}

/* Açılış perdesi: şeffaf zemin + ortada kule (arkasına config rengi gelir). */
function splashImage(w, h) {
  var img = makeImg(w, h);
  var s = Math.min(w, h);
  drawTower(img, w / 2, h / 2 + s * 0.15, s * 0.30);
  return img;
}

/* Play Store tanıtım görseli: 1024x500. */
function featureImage() {
  var w = 1024, h = 500;
  var img = makeImg(w, h);
  fillVGradient(img, hex('#0c0a20'), hex('#1e1046'));
  addGlow(img, w * 0.24, h * 0.5, h * 0.95, hsl(268, 88, 58), 0.34);
  drawTower(img, w * 0.22, h * 0.82, h * 0.62);
  return img;
}

/* ------------------------------ Üretim ------------------------------ */

var count = 0;
function regen(rel, renderFn, opaque) {
  var full = path.join(root, rel);
  var dims;
  if (fs.existsSync(full)) {
    dims = pngSize(full);
  } else {
    console.log('  (atlandı, dosya yok)', rel);
    return;
  }
  var img = renderFn(dims.w, dims.h);
  fs.writeFileSync(full, encodePNG(img, !!opaque));
  count++;
  console.log('✓', rel, img.w + 'x' + img.h);
}

console.log('NEON KULE ikonları üretiliyor...');

/* Android başlatıcı simgeleri */
['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'].forEach(function (d) {
  var base = 'android/app/src/main/res/mipmap-' + d + '/';
  regen(base + 'ic_launcher.png', function (w) { return iconImage(w, false); });
  regen(base + 'ic_launcher_round.png', function (w) { return iconImage(w, false); });
  regen(base + 'ic_launcher_foreground.png', function (w) { return foregroundImage(w); });
});

/* Android açılış perdeleri (tüm drawable klasörleri) */
var resDir = path.join(root, 'android/app/src/main/res');
fs.readdirSync(resDir).forEach(function (dir) {
  if (!/^drawable/.test(dir)) return;
  var splash = path.join(resDir, dir, 'splash.png');
  if (fs.existsSync(splash)) regen(path.relative(root, splash), splashImage);
});

/* iOS simge + açılış */
regen('ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png',
  function (w) { return iconImage(w, true); }, true);   // alfa kanalsız
regen('ios/App/App/Assets.xcassets/Splash.imageset/splash-2732x2732.png', splashImage);
regen('ios/App/App/Assets.xcassets/Splash.imageset/splash-2732x2732-1.png', splashImage);
regen('ios/App/App/Assets.xcassets/Splash.imageset/splash-2732x2732-2.png', splashImage);

/* Mağaza görselleri (assets/) */
var outDir = path.join(root, 'assets');
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'icon-512.png'), encodePNG(iconImage(512, true), true));
fs.writeFileSync(path.join(outDir, 'icon-1024.png'), encodePNG(iconImage(1024, true), true));
fs.writeFileSync(path.join(outDir, 'feature-1024x500.png'), encodePNG(featureImage(), true));
count += 3;
console.log('✓ assets/icon-512.png, assets/icon-1024.png, assets/feature-1024x500.png');

console.log('Tamamlandı: ' + count + ' görsel üretildi.');
