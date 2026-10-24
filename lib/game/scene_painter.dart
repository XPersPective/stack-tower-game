/// Stack Tower Game — sahne çizici.
/// `reference/www/game.js` render katmanının CustomPainter portu (SPEC §3):
/// paralaks gökyüzü, aurora, ay, uzak adalar, silüetler, bulut denizi, hava,
/// takımyıldız, zemin platformu, 3B bloklar, efektler, vinyet, karanlık.
/// Katman sırası game.js render() ile birebirdir.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'gameplay.dart';

/* ---------------- renk yardımcıları (game.js birebir) ---------------- */

class Rgb {
  final int r, g, b;
  const Rgb(this.r, this.g, this.b);
}

Rgb hexRgb(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
  final n = int.parse(h, radix: 16);
  return Rgb((n >> 16) & 255, (n >> 8) & 255, n & 255);
}

Rgb mixRgb(Rgb a, Rgb b, double k) => Rgb(
      (a.r + (b.r - a.r) * k).round(),
      (a.g + (b.g - a.g) * k).round(),
      (a.b + (b.b - a.b) * k).round(),
    );

Color rgba(Rgb c, double a) => Color.fromRGBO(c.r, c.g, c.b, a.clamp(0, 1));

Rgb hslRgb(double h, double s, double l) {
  h = ((h % 360) + 360) % 360;
  s /= 100;
  l /= 100;
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = l - c / 2;
  var r = 0.0, g = 0.0, b = 0.0;
  if (h < 60) {
    r = c;
    g = x;
  } else if (h < 120) {
    r = x;
    g = c;
  } else if (h < 180) {
    g = c;
    b = x;
  } else if (h < 240) {
    g = x;
    b = c;
  } else if (h < 300) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  return Rgb(((r + m) * 255).round(), ((g + m) * 255).round(), ((b + m) * 255).round());
}

/// theme() karşılığı — def yokken varsayılan.
const _defaultBg1 = '#0c0a20';
const _defaultBg2 = '#1e1046';
const _defaultGlow = 268;

/* ------------------------------ Painter ------------------------------ */

class ScenePainter extends CustomPainter {
  ScenePainter(this.g) : super(repaint: g);

  final GamePlayRepaint g;
  final math.Random _shakeRnd = math.Random();

  @override
  bool shouldRepaint(ScenePainter oldDelegate) => true; // her tik yeniden çiz

  @override
  void paint(Canvas canvas, Size size) {
    final e = g.engine;
    if (e.w == 0 || e.h == 0) return;
    final t1 = _themeOf(e);
    final c0 = hexRgb(t1.bg1Hex);
    final c1 = hexRgb(t1.bg2Hex);
    final glow = t1.glow;
    final gl = hslRgb(glow.toDouble(), 92, 60);

    _drawBackground(canvas, e, c0, c1, gl);
    canvas.save();
    if (e.shake > 0.2) {
      canvas.translate((_shakeRnd.nextDouble() - 0.5) * e.shake, (_shakeRnd.nextDouble() - 0.5) * e.shake);
    }

    _drawGround(canvas, e, glow);
    _drawTowerBeam(canvas, e, glow);
    _drawAimShade(canvas, e);
    for (var i = 0; i < e.blocks.length; i++) {
      _drawBlock(canvas, e, e.blocks[i].x, e.groundY - i * e.bh + e.camShift, e.blocks[i].w,
          e.bh, e.blockHue(i));
    }
    if (e.state == EngineState.playing) _drawMoving(canvas, e);

    _drawForeground(canvas, e);

    for (final d in e.debris) {
      if (d.y > e.h + 200) continue;
      canvas.save();
      canvas.translate(d.x + d.w / 2, d.y + d.h / 2);
      canvas.rotate(d.rot);
      final a = (1 - d.life * 0.5).clamp(0.0, 1.0);
      final p = Paint()
        ..color = hsla(d.hue, 86, 52, a)
        ..isAntiAlias = true;
      _roundRectPath(canvas, p, -d.w / 2, -d.h / 2, d.w, d.h, math.min(4 * e.scale, d.h / 3), radiusOnly: true);
      canvas.restore();
    }
    for (final p in e.particles) {
      final a = (1 - p.life / p.max).clamp(0.0, 1.0);
      if (p.coin) {
        final cp = Paint()..color = hsla(48, 100, 62, a);
        canvas.drawCircle(Offset(p.x, p.y), p.size / 2, cp);
        final st = Paint()
          ..color = hsla(38, 90, 45, a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(p.x, p.y), p.size / 2, st);
      } else {
        final pp = Paint()..color = hsla(p.hue, 95, 72, a);
        canvas.drawRect(Rect.fromLTWH(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size), pp);
      }
    }
    for (final r in e.rings) {
      final ra = (1 - r.life / r.max).clamp(0.0, 1.0);
      final p = Paint()
        ..color = hsla(r.hue, 95, 75, ra * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * e.scale * ra;
      canvas.drawCircle(Offset(r.x, r.y), r.r, p);
    }
    // popup'lar konfetiden ÖNCE (game.js: rings → popups → konfeti)
    for (final q in e.popups) {
      _drawPopup(canvas, e, q);
    }
    for (final cf in e.confetti) {
      canvas.save();
      canvas.translate(cf.x, cf.y);
      canvas.rotate(cf.rot);
      final a = (1 - cf.life / cf.max).clamp(0.0, 1.0);
      final p = Paint()..color = hsla(cf.hue, 95, 65, a);
      canvas.drawRect(Rect.fromLTWH(-cf.w / 2, -cf.h / 2, cf.w, cf.h), p);
      canvas.restore();
    }
    canvas.restore();

    _drawVignette(canvas, e);
    _drawDark(canvas, e);
  }

  /* ------------------------------ gökyüzü ------------------------------ */

  void _drawBackground(Canvas canvas, GamePlay e, Rgb c0, Rgb c1, Rgb gl) {
    final rect = Rect.fromLTWH(0, 0, e.w, e.h);
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, e.h),
        [
          rgba(mixRgb(const Rgb(4, 4, 15), c0, 0.45), 1),
          rgba(c0, 1),
          rgba(c1, 1),
          rgba(mixRgb(c1, gl, 0.3), 1),
        ],
        const [0, 0.42, 0.76, 1],
      );
    canvas.drawRect(rect, bg);

    // aurora — 'lighter' karşılığı BlendMode.plus
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.plus);
    for (var a = 0; a < 2; a++) {
      final ay = e.h * (0.18 + a * 0.09) + math.sin(e.time * 0.3 + a) * 8 - e.camShift * 0.02;
      final path = Path()
        ..moveTo(-40, ay)
        ..cubicTo(e.w * 0.32, ay - 50, e.w * 0.68, ay + 65, e.w + 40, ay - 12);
      final ag = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 70 + a * 40
        ..shader = ui.Gradient.linear(
          Offset(0, ay - 70),
          Offset(0, ay + 90),
          [rgba(gl, 0), rgba(gl, 0.055), rgba(gl, 0)],
          const [0, 0.5, 1],
        );
      canvas.drawPath(path, ag);
    }
    canvas.restore();

    _drawMoon(canvas, e, gl, c0);
    _drawDistantIslands(canvas, e, c1, gl);

    // yıldızlar (+ parlaklara artı çizgisi)
    for (final s in e.stars) {
      final tw = 0.18 + 0.55 * (0.5 + 0.5 * math.sin(e.time * s.s + s.p));
      final p = Paint()..color = (s.r > 1.4 ? const Color(0xFFFFF3D4) : const Color(0xFFD6E8FF)).withValues(alpha: tw);
      if (s.r > 1.55) {
        canvas.drawRect(Rect.fromLTWH(s.x - 4, s.y - 0.5, 8, 1), p);
        canvas.drawRect(Rect.fromLTWH(s.x - 0.5, s.y - 4, 1, 8), p);
      }
      canvas.drawCircle(Offset(s.x, s.y), s.r, p);
    }

    _drawSilhouette(canvas, e);
    _drawCloudSea(canvas, e, c1, gl);
    _drawClouds(canvas, e);
    _drawWeather(canvas, e);
    _drawConstellation(canvas, e);
  }

  void _drawMoon(Canvas canvas, GamePlay e, Rgb gl, Rgb bg0) {
    final mx = e.w * 0.79;
    final my = e.h * 0.16 - e.camShift * 0.012;
    final mr = math.min(e.w, e.h) * 0.085;
    final halo = Paint()
      ..shader = ui.Gradient.radial(Offset(mx, my), mr * 2.7,
          [rgba(gl, 0.34), rgba(gl, 0.10), rgba(gl, 0)], const [0.14, 0.45, 1]);
    canvas.drawCircle(Offset(mx, my), mr * 2.7, halo);

    final disc = Paint()
      ..shader = ui.Gradient.radial(
        Offset(mx - mr * 0.32, my - mr * 0.35),
        mr,
        [
          rgba(mixRgb(gl, const Rgb(255, 255, 255), 0.5), 0.9),
          rgba(gl, 0.55),
          rgba(mixRgb(gl, bg0, 0.55), 0.18),
        ],
        [mr * 0.1, mr * 0.62, 1].map((v) => (v / mr).clamp(0.0, 1.0)).toList(),
      );
    canvas.drawCircle(Offset(mx, my), mr, disc);

    final ring = Paint()
      ..color = rgba(gl, 0.7 * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.save();
    canvas.translate(mx, my);
    canvas.rotate(-0.4);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: mr * 3.4, height: mr * 0.68), ring);
    canvas.restore();
  }

  void _drawDistantIslands(Canvas canvas, GamePlay e, Rgb base, Rgb gl) {
    final list = [
      (Offset(e.w * 0.13, e.h * 0.5), e.w * 0.12, 2.0),
      (Offset(e.w * 0.93, e.h * 0.58), e.w * 0.16, 5.0),
      (Offset(e.w * 0.03, e.h * 0.7), e.w * 0.09, 9.0),
    ];
    final par = e.camShift * 0.03;
    for (final (pos, r, seed) in list) {
      final y = pos.dy + par;
      if (y > e.h + 120) continue;
      canvas.save();
      final fill = Paint()..color = rgba(mixRgb(base, const Rgb(5, 5, 15), 0.52), 0.85);
      final path = Path();
      const n = 9;
      for (var k = 0; k < n; k++) {
        final a = k / n * math.pi * 2;
        final rr = r * (0.72 + 0.25 * math.sin(k * 2.1 + seed));
        final px = pos.dx + math.cos(a) * rr;
        final py = y + math.sin(a) * rr * 0.3;
        k == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      path.close();
      canvas.drawPath(path, fill);
      final edge = Paint()
        ..color = rgba(gl, 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawPath(path, edge);
      final rock = Path()
        ..moveTo(pos.dx - r * 0.55, y + 4)
        ..lineTo(pos.dx, y + r * 0.62)
        ..lineTo(pos.dx + r * 0.55, y + 4)
        ..close();
      canvas.drawPath(rock, fill);
      final hg = Paint()
        ..shader = ui.Gradient.radial(Offset(pos.dx, y), r * 0.9, [rgba(gl, 0.10), rgba(gl, 0)], const [0.05, 1]);
      canvas.drawOval(Rect.fromCenter(center: Offset(pos.dx, y), width: r * 1.7, height: r * 0.56), hg);
      canvas.restore();
    }
  }

  void _drawCloudSea(Canvas canvas, GamePlay e, Rgb base, Rgb gl) {
    final y0 = e.h * 0.79 + e.camShift * 0.05;
    final rect = Rect.fromLTWH(0, y0 - 40, e.w, e.h - y0 + 40);
    final g = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y0 - 40),
        Offset(0, e.h),
        [
          rgba(mixRgb(base, gl, 0.25), 0),
          rgba(mixRgb(base, gl, 0.32), 0.16),
          rgba(mixRgb(base, const Rgb(5, 5, 14), 0.35), 0.5),
        ],
        const [0, 0.45, 1],
      );
    canvas.drawRect(rect, g);
    for (var i = 0; i < 6; i++) {
      final x = e.w * (0.1 + i * 0.18) + math.sin(e.time * 0.12 + i) * 14;
      final y = y0 + (i % 3) * 24.0;
      final rx = e.w * (0.24 + (i % 2) * 0.08);
      final rg = Paint()
        ..shader = ui.Gradient.radial(
          Offset(x, y),
          rx,
          [
            rgba(gl, 0.05),
            rgba(mixRgb(base, const Rgb(220, 235, 255), 0.5), 0.05),
            rgba(base, 0),
          ],
          const [0, 0.6, 1],
        );
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: rx * 0.44), rg);
    }
  }

  void _drawClouds(Canvas canvas, GamePlay e) {
    for (final c in e.clouds) {
      final rg = Paint()
        ..shader = ui.Gradient.radial(
          Offset(c.x, c.y),
          c.rx,
          [
            const Color(0xFFDCEBFF).withValues(alpha: c.a * 0.9),
            const Color(0xFFCDE1FF).withValues(alpha: c.a * 0.5),
            const Color(0xFFC8DCFF).withValues(alpha: 0),
          ],
          const [0, 0.55, 1],
        );
      canvas.drawOval(Rect.fromCenter(center: Offset(c.x, c.y), width: c.rx * 2, height: c.ry * 2), rg);
    }
  }

  void _drawForeground(Canvas canvas, GamePlay e) {
    final p = Paint()
      ..color = const Color(0x6004040E) // 0.5 × 0.75 = 0.375 (game.js katmanı)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final f in e.fgBits) {
      final sway = math.sin(e.time * 0.5 + f.ph) * 8;
      canvas.drawOval(Rect.fromCenter(center: Offset(f.x + sway, f.y), width: f.r * 2, height: f.r * 0.9), p);
    }
  }

  void _drawConstellation(Canvas canvas, GamePlay e) {
    if (e.progressStars <= 0) return;
    const total = 450; // 10 dünya × 15 bölüm × 3 yıldız
    final lit = math.min(42, math.max(1.0, (e.progressStars / total * 42).round()));
    final pts = <Offset>[];
    for (var i = 0; i < 42; i++) {
      final rnd = GamePlay.mulberry32(i * 977 + 5);
      pts.add(Offset(e.w * (0.08 + rnd() * 0.84), e.h * (0.03 + rnd() * 0.22)));
    }
    final line = Paint()
      ..color = const Color(0x38AACDFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < lit; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < lit; i++) {
      final tw = 0.65 + 0.35 * math.sin(e.time * 2 + i);
      final glowP = Paint()
        ..color = const Color(0xE6FFF0B4).withValues(alpha: tw)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(pts[i], 2.4, glowP);
    }
  }

  void _drawSilhouette(Canvas canvas, GamePlay e) {
    final glow = _themeOf(e).glow;
    for (final lay in e.silhouettes) {
      final par = -e.camShift * (lay.layer == 1 ? 0.05 : 0.1);
      canvas.save();
      canvas.translate(0, par);
      final baseFill = hslRgb(glow.toDouble(), 46, lay.layer == 1 ? 6 : 9);
      final fill = Paint()..color = rgba(baseFill, lay.layer == 1 ? 0.95 : 0.8);
      for (var i = 0; i < lay.pts.length; i++) {
        final p = lay.pts[i];
        if (p.type == 'tree') {
          final path = Path()
            ..moveTo(p.x, lay.base)
            ..lineTo(p.x + p.w / 2, lay.base - p.h)
            ..lineTo(p.x + p.w, lay.base)
            ..close();
          canvas.drawPath(path, fill);
          if (lay.layer == 1) {
            final tip = Paint()..color = hsla(glow, 90, 72, 0.35);
            canvas.drawCircle(Offset(p.x + p.w / 2, lay.base - p.h + 1), 1.4, tip);
          }
        } else if (p.type == 'hill') {
          final path = Path()
            ..moveTo(p.x, lay.base)
            ..quadraticBezierTo(p.x + p.w / 2, lay.base - p.h, p.x + p.w, lay.base)
            ..close();
          canvas.drawPath(path, fill);
          if (lay.layer == 1) {
            final edge = Paint()
              ..color = hsla(glow, 90, 70, 0.18)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1;
            final s = Path()
              ..moveTo(p.x, lay.base)
              ..quadraticBezierTo(p.x + p.w / 2, lay.base - p.h, p.x + p.w, lay.base);
            canvas.drawPath(s, edge);
          }
        } else if (p.type == 'block') {
          canvas.drawRect(Rect.fromLTWH(p.x, lay.base - p.h, p.w, p.h + 60), fill);
          final roof = Paint()..color = hsla(glow, 90, 66, 0.22);
          canvas.drawRect(Rect.fromLTWH(p.x, lay.base - p.h, p.w, 1.4), roof);
          if (lay.layer == 1) {
            final cols = math.max(1.0, (p.w / 14).floor());
            final rows = math.min(7, math.max(1.0, (p.h / 20).floor()));
            for (var c = 0; c < cols; c++) {
              for (var r = 0; r < rows; r++) {
                if ((i * 5 + c * 3 + r) % 4 == 0) continue;
                final wa = 0.12 + (((i + c + r) % 5) * 0.05);
                final win = Paint()..color = Color.fromRGBO(255, 226, 160, wa);
                canvas.drawRect(Rect.fromLTWH(p.x + 5 + c * 14.0, lay.base - p.h + 7 + r * 16.0, 3, 4), win);
              }
            }
          }
        } else {
          final path = Path()
            ..moveTo(p.x, lay.base + 20)
            ..lineTo(p.x + p.w / 2, lay.base - p.h)
            ..lineTo(p.x + p.w, lay.base + 20)
            ..close();
          canvas.drawPath(path, fill);
        }
      }
      canvas.restore();
    }
  }

  void _drawWeather(Canvas canvas, GamePlay e) {
    final glow = _themeOf(e).glow;
    for (var i = 0; i < e.weather.length; i++) {
      final b = e.weather[i];
      final p = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: b.a);
      if (b.kind == 'snow') {
        p.color = const Color(0xFFDFF3FF).withValues(alpha: b.a);
        canvas.drawCircle(Offset(b.x, b.y), b.r, p);
      } else if (b.kind == 'sand') {
        p.color = hsla(glow, 80, 70, b.a);
        canvas.drawRect(Rect.fromLTWH(b.x, b.y, b.r * 1.6, b.r), p);
      } else if (b.kind == 'embers') {
        p.color = hsla((10 + (i % 3) * 12).toDouble(), 100, 60, b.a);
        canvas.drawCircle(Offset(b.x, b.y), b.r, p);
      } else if (b.kind == 'leaves') {
        p.color = hsla((110 + (i % 4) * 14).toDouble(), 70, 55, b.a);
        canvas.drawRect(Rect.fromLTWH(b.x, b.y, b.r * 2, b.r), p);
      } else {
        p.color = const Color(0xFFCFE4FF).withValues(alpha: b.a);
        canvas.drawCircle(Offset(b.x, b.y), b.r * 0.8, p);
      }
    }
  }

  /* ------------------------------ zemin + kule ------------------------------ */

  void _drawGround(Canvas canvas, GamePlay e, int glow) {
    if (e.blocks.isEmpty) return;
    final base = e.blocks[0];
    final bottom = e.groundY + e.bh + e.camShift;
    if (bottom > e.h + 160) return;
    final cx = base.x + base.w / 2;
    final half = math.max(base.w * 0.72, 132 * e.scale);
    final ry = math.max(16.0, 28 * e.scale);
    final deep = math.max(60.0, 78 * e.scale);

    // platform arkasındaki ışık
    final halo = Paint()
      ..shader = ui.Gradient.radial(Offset(cx, bottom + 10), half * 1.25,
          [hsla(glow, 90, 62, 0.22), hsla(glow, 90, 62, 0)], const [0.02, 1]);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, bottom + 10), width: half * 2.5, height: ry * 3.6), halo);

    // alt kaya
    final ug = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, bottom - 4),
        Offset(0, bottom + deep),
        [hslColor(glow, 42, 16), hslColor(glow, 38, 4)],
      );
    final rock = Path()
      ..moveTo(cx - half, bottom - 4)
      ..quadraticBezierTo(cx - half * 0.55, bottom + deep * 0.9, cx, bottom + deep)
      ..quadraticBezierTo(cx + half * 0.55, bottom + deep * 0.9, cx + half, bottom - 4)
      ..close();
    canvas.drawPath(rock, ug);

    // üst yüzey
    final tg = Paint()
      ..shader = ui.Gradient.radial(Offset(cx, bottom), half,
          [hslColor(glow, 52, 24), hslColor(glow, 48, 14), hslColor(glow, 44, 8)], const [0.05, 0.7, 1]);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, bottom - 5), width: half * 2, height: ry * 2), tg);

    // glow kenar
    final glowStroke = Paint()
      ..color = hsla(glow, 95, 68, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.8 * e.scale)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, 16 * e.scale));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, bottom - 5), width: half * 2, height: ry * 2), glowStroke);
    // keskin kenar (blur'suz)
    final crisp = Paint()
      ..color = hsla(glow, 95, 68, 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.8 * e.scale);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, bottom - 5), width: half * 2, height: ry * 2), crisp);

    // iç halka
    final inner = Paint()
      ..color = hsla(glow, 80, 60, 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, bottom - 5), width: half * 1.2, height: ry * 1.2), inner);

    // kule gölgesi
    final sg = Paint()
      ..shader = ui.Gradient.radial(Offset(cx, bottom - 3), base.w * 0.6,
          [const Color(0x80000000), const Color(0x00000000)], const [0.1, 1]);
    canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, bottom - 3), width: base.w * 1.2, height: ry),
          sg);

    // kenar kristalleri
    for (var i = 0; i < 2; i++) {
      final sx = cx + (i == 0 ? -half * 0.82 : half * 0.82);
      final sh = 16 * e.scale + i * 7;
      final p = Paint()..color = hsla(glow, 90, 68, 0.5);
      final path = Path()
        ..moveTo(sx, bottom - ry * 0.4 - sh)
        ..lineTo(sx + 4 * e.scale, bottom - ry * 0.4)
        ..lineTo(sx - 4 * e.scale, bottom - ry * 0.4)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  void _drawTowerBeam(Canvas canvas, GamePlay e, int glow) {
    if (e.blocks.isEmpty) return;
    final base = e.blocks[0];
    final cx = base.x + base.w / 2;
    final y0 = e.groundY + e.bh + e.camShift;
    final y1 = math.max(-20.0, y0 - math.max(320 * e.scale, e.blocks.length * e.bh + 180));
    if (y0 < 0) return;
    final rect = Rect.fromLTRB(cx - base.w * 0.62, y1, cx + base.w * 0.62, y0);
    final g = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.linear(
        Offset(0, y0),
        Offset(0, y1),
        [hsla(glow, 95, 62, 0.13), hsla(glow, 95, 62, 0.05), hsla(glow, 95, 62, 0)],
        const [0, 0.55, 1],
      );
    canvas.drawRect(rect, g);
  }

  void _drawAimShade(Canvas canvas, GamePlay e) {
    final m = e.moving;
    if (m == null || e.blocks.isEmpty) return;
    final top = e.blocks[e.blocks.length - 1];
    final y = e.topY();
    final gx1 = m.x.clamp(top.x, top.x + top.w);
    final gx2 = (m.x + m.w).clamp(top.x, top.x + top.w);
    if (gx2 - gx1 < 1) return;
    final path = Path()
      ..moveTo(gx1, y)
      ..lineTo(gx1 + e.depthX, y + e.depthY)
      ..lineTo(gx2 + e.depthX, y + e.depthY)
      ..lineTo(gx2, y)
      ..close();
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(gx1 - 2, y + e.depthY - 2, (gx2 - gx1) + e.depthX + 4, -e.depthY + 4),
      Paint()..color = const Color(0x4D000000),
    );
    canvas.restore();
  }

  void _drawBlock(Canvas canvas, GamePlay e, double x, double y, double w, double h, int hue) {
    if (y > e.h + h || y + h + e.depthY < -h) return;
    final r = math.min(5 * e.scale, h / 3);

    // sağ yan (paralelkenar)
    final side = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x + w, y + e.depthY),
        Offset(x + w + e.depthX, y + h),
        [hslColor(hue, 76, 34), hslColor(hue, 70, 22)],
      );
    final sidePath = Path()
      ..moveTo(x + w, y)
      ..lineTo(x + w + e.depthX, y + e.depthY)
      ..lineTo(x + w + e.depthX, y + e.depthY + h)
      ..lineTo(x + w, y + h)
      ..close();
    canvas.drawPath(sidePath, side);

    // ön yüz
    final front = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x, y),
        Offset(x + w * 0.7, y + h),
        [hslColor(hue, 95, 66), hslColor(hue, 90, 54), hslColor(hue, 84, 40)],
        const [0, 0.45, 1],
      )
      ..isAntiAlias = true;
    _roundRect(canvas, front, x, y, w, h, r);

    // cam parlaması
    final spec = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x, y),
        Offset(x, y + h * 0.55),
        [const Color(0x38FFFFFF), const Color(0x00FFFFFF)],
      );
    _roundRect(canvas, spec, x + 2 * e.scale, y + 1.5 * e.scale, w - 4 * e.scale,
        math.max(3, h * 0.4), r * 0.7);

    // neon çerçeve
    final border = Paint()
      ..color = hsla(hue, 100, 82, 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, 1.1 * e.scale);
    _roundRectStroke(canvas, border, x + 0.5, y + 0.5, w - 1, h - 1, r);

    // üst yüz
    final topG = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x, y + e.depthY),
        Offset(x + w, y),
        [hslColor(hue, 98, 82), hslColor(hue, 96, 64)],
      );
    final topPath = Path()
      ..moveTo(x, y)
      ..lineTo(x + e.depthX, y + e.depthY)
      ..lineTo(x + w + e.depthX, y + e.depthY)
      ..lineTo(x + w, y)
      ..close();
    canvas.drawPath(topPath, topG);
    final topEdge = Paint()
      ..color = hsla(hue, 100, 96, 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, 0.9 * e.scale);
    canvas.drawPath(topPath, topEdge);

    // iç ışık çizgisi
    final line = Paint()
      ..color = hsla(hue, 100, 88, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, 0.8 * e.scale);
    canvas.drawLine(Offset(x + 4 * e.scale, y + h * 0.22), Offset(x + 4 * e.scale, y + h * 0.9), line);
  }

  void _drawMoving(Canvas canvas, GamePlay e) {
    final m = e.moving;
    if (m == null) return;
    final y = e.movingY();
    _drawBlock(canvas, e, m.x, y, m.w, e.bh, e.blockHue(e.blocks.length));
    final p = Paint()
      ..color = const Color(0x73FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _roundRectStroke(canvas, p, m.x, y, m.w, e.bh, math.min(4 * e.scale, e.bh / 3));
  }

  void _drawPopup(Canvas canvas, GamePlay e, Popup q) {
    final qt = q.life / q.max;
    final a = qt < 0.15 ? qt / 0.15 : math.max(0.0, 1 - (qt - 0.15) / 0.85);
    final style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 20 * e.scale,
      fontWeight: FontWeight.w900,
      color: hslToColor(q.hue, 100, 82, a),
    );
    final tp = TextPainter(
      text: TextSpan(text: q.text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    // gölge konturu
    final stroke = TextPainter(
      text: TextSpan(
        text: q.text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * e.scale
            ..color = const Color(0x8C000000),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    stroke.paint(canvas, Offset(q.x - tp.width / 2, q.y - tp.height / 2));
    tp.paint(canvas, Offset(q.x - tp.width / 2, q.y - tp.height / 2));
  }

  void _drawVignette(Canvas canvas, GamePlay e) {
    final g = Paint()
      ..shader = ui.Gradient.radial(
        Offset(e.w / 2, e.h * 0.5),
        math.max(e.w, e.h) * 0.82,
        [
          const Color(0x00000000),
          const Color(0x2903060C),
          const Color(0x8C03030C),
        ],
        [math.min(e.w, e.h) * 0.3 / (math.max(e.w, e.h) * 0.82), 0.72, 1],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, e.w, e.h), g);
  }

  void _drawDark(Canvas canvas, GamePlay e) {
    if (e.def?.modifier != 'karanlik') return;
    final cx = e.w / 2;
    final cy = math.min(e.movingY(), e.topY()) + e.bh;
    final r = math.max(e.w, e.h) * 0.55;
    // game.js: iç r*0.25 → dış r; duraklar tek-yarıçapa dönüştürüldü: [0.25, 0.7, 1]
    final g = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        r,
        [const Color(0x00000000), const Color(0x8C000000), const Color(0xF0020208)],
        const [0.25, 0.7, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, e.w, e.h), g);
  }

  /* ------------------------------ yardımcılar ------------------------------ */

  ({String bg1Hex, String bg2Hex, int glow}) _themeOf(GamePlay e) {
    final t = e.def?.theme;
    // WorldTheme Color olarak tutar; hex'e geri çevir
    if (t == null) return (bg1Hex: _defaultBg1, bg2Hex: _defaultBg2, glow: _defaultGlow);
    return (
      bg1Hex: _colorToHex(t.bg1),
      bg2Hex: _colorToHex(t.bg2),
      glow: t.glow,
    );
  }

  static String _colorToHex(Color c) =>
      '#${(c.r * 255.999).toInt().toRadixString(16).padLeft(2, '0')}'
      '${(c.g * 255.999).toInt().toRadixString(16).padLeft(2, '0')}'
      '${(c.b * 255.999).toInt().toRadixString(16).padLeft(2, '0')}';

  void _roundRect(Canvas canvas, Paint p, double x, double y, double w, double h, double r) {
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(math.max(0.0, math.min(r, math.min(w / 2, h / 2)))));
    canvas.drawRRect(rr, p);
  }

  void _roundRectStroke(Canvas canvas, Paint p, double x, double y, double w, double h, double r) {
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(math.max(0.0, math.min(r, math.min(w / 2, h / 2)))));
    canvas.drawRRect(rr, p);
  }

  void _roundRectPath(Canvas canvas, Paint p, double x, double y, double w, double h, double r,
      {bool radiusOnly = false}) {
    _roundRect(canvas, p, x, y, w, h, r);
  }
}

/// hsl renk üretici kısayolları.
Color hslColor(int hue, int s, int l) {
  final c = hslRgb(hue.toDouble(), s.toDouble(), l.toDouble());
  return Color.fromRGBO(c.r, c.g, c.b, 1);
}

Color hsla(num hue, int s, int l, double a) {
  final c = hslRgb(hue.toDouble(), s.toDouble(), l.toDouble());
  return Color.fromRGBO(c.r, c.g, c.b, a.clamp(0, 1));
}

Color hslToColor(int hue, int s, int l, double a) => hsla(hue, s, l, a);

/// Ticker'ın painter'ı tetiklemesi için Listenable köprüsü.
class GamePlayRepaint extends ChangeNotifier {
  GamePlayRepaint(this.engine);
  final GamePlay engine;

  void notify() => notifyListeners();
}
