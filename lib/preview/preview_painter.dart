/// preview.js draw() birebir portu — sinematik bölüm önizleme sahnesi.
/// Gökyüzü → yıldızlar → dev ay → aurora → ufuk parıltısı → 3 katman siluet +
/// sis → gizem geçidi → kule → hava → vinyet sırası JS ile aynı (preview.js:131).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// JS rnd(): seed = seed*1664525+1013904223 mod 2^32 (preview.js:107).
class _Lcg {
  int seed;
  _Lcg(this.seed);
  double next() {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  }
}

class _Particle {
  final double x, y, s, v, ph, a, rot;
  const _Particle(this.x, this.y, this.s, this.v, this.ph, this.a, this.rot);
}

class _Star {
  final double x, y, s, ph;
  const _Star(this.x, this.y, this.s, this.ph);
}

/// Sahne modeli: open() karşılığı — seed'den parçacıklı bir kez kurulur
/// (preview.js:76-83 buildParticles, seed = |i|*977 + (stage+1)*131 + daily?7).
class PreviewScene {
  PreviewScene({
    required this.theme,
    required this.levelI,
    required this.stage,
    this.daily = false,
  }) {
    final rnd = _Lcg(levelI.abs() * 977 + (stage + 1) * 131 + (daily ? 7 : 0));
    final n = theme.weather == 'stars' ? 46 : 54;
    _particles = List.generate(n, (_) {
      final x = rnd.next(), y = rnd.next();
      final s = 0.6 + rnd.next() * 2.2;
      final v = 0.008 + rnd.next() * 0.03;
      final ph = rnd.next() * math.pi * 2;
      final a = 0.25 + rnd.next() * 0.6;
      final rot = rnd.next() * math.pi;
      return _Particle(x, y, s, v, ph, a, rot);
    });
    _stars = List.generate(80, (_) {
      final x = rnd.next();
      final y = rnd.next() * 0.68;
      final s = 0.5 + rnd.next() * 1.4;
      final ph = rnd.next() * 6.28;
      return _Star(x, y, s, ph);
    });
  }

  final WorldTheme theme;
  final int levelI;
  final int stage;
  final bool daily;

  late final List<_Particle> _particles;
  late final List<_Star> _stars;

  /// Test görünümü: JS buildParticles sayıları (stars havası 46, diğerleri 54).
  int get particleCount => _particles.length;
  int get starCount => _stars.length;
}

Color _rgba(Color c, double a) => c.withValues(alpha: a);

Color _hsl(num h, num s, num l, [double a = 1]) =>
    HSLColor.fromAHSL(a, h.toDouble(), s.toDouble() / 100, l.toDouble() / 100)
        .toColor();

class PreviewPainter extends CustomPainter {
  PreviewPainter({required this.scene, required this.t});

  final PreviewScene scene;
  final double t; // saniye

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final theme = scene.theme;
    final c0 = theme.bg1, c1 = theme.bg2;
    final deep = const Color.fromARGB(255, 3, 3, 12);
    final glow = _hsl(theme.glow, 92, 62);

    /* gökyüzü — 4 durak (preview.js:141-147) */
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(deep, c0, 0.45)!,
            c0,
            c1,
            Color.lerp(c1, const Color.fromARGB(255, 4, 4, 12), 0.6)!,
          ],
          stops: const [0, 0.42, 0.72, 1],
        ).createShader(Offset.zero & size),
    );

    final drift = math.sin(t * 0.09) * w * 0.012;

    /* yıldızlar — kırpmalı parıltı (preview.js:152-161) */
    final starPaint = Paint()..color = const Color(0xFFeaf2ff);
    for (final s in scene._stars) {
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 1.7 + s.ph));
      starPaint.color = const Color(0xFFeaf2ff).withValues(alpha: tw * 0.8);
      canvas.drawCircle(Offset(s.x * w + drift * 0.4, s.y * h), s.s, starPaint);
    }

    /* dev ay / gezegen (preview.js:164-183) */
    final mx = w * 0.52 + drift * 2;
    final my = h * 0.27;
    final mr = math.min(w, h) * (scene.daily ? 0.09 : 0.105);
    canvas.drawCircle(
      Offset(mx, my),
      mr * 2.6,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          focal: Alignment.center,
          focalRadius: 0.2 / 2.6,
          colors: [
            _rgba(glow, 0.5),
            _rgba(glow, 0.14),
            _rgba(glow, 0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: Offset(mx, my), radius: mr * 2.6)),
    );
    canvas.drawCircle(
      Offset(mx, my),
      mr,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          focal: const Alignment(-0.35, -0.4),
          focalRadius: 0.1,
          colors: [
            _rgba(Color.lerp(glow, Colors.white, 0.55)!, 0.95),
            _rgba(glow, 0.55),
            _rgba(Color.lerp(glow, c0, 0.55)!, 0.25),
          ],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: Offset(mx, my), radius: mr)),
    );

    /* aurora — iki bezier şerit, toplama karışımı (preview.js:186-201) */
    canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.plus);
    for (var i = 0; i < 2; i++) {
      final ay = h * (0.24 + i * 0.08) + math.sin(t * 0.3 + i) * 8;
      final path = Path()
        ..moveTo(-40, ay)
        ..cubicTo(w * 0.3, ay - 55, w * 0.72, ay + 60, w + 40, ay - 14);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 60.0 + i * 30
          ..shader = LinearGradient(
            begin: Alignment(0, (ay - 60) / h * 2 - 1),
            end: Alignment(0, (ay + 70) / h * 2 - 1),
            colors: [
              _rgba(glow, 0),
              _rgba(glow, 0.09),
              _rgba(glow, 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
    }
    canvas.restore();

    /* ufuk parıltısı (preview.js:204-209) */
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.36, w, h * 0.38),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [_rgba(glow, 0.20), _rgba(glow, 0.06), _rgba(glow, 0)],
          stops: const [0, 0.5, 1],
        ).createShader(
            Rect.fromCircle(center: Offset(w * 0.5, h * 0.6), radius: w * 0.9)),
    );

    /* dünya siluetleri — üç katman + sis bandı (preview.js:212-228) */
    final horizon = h * 0.46;
    for (var layer = 0; layer < 3; layer++) {
      final ly = horizon + layer * h * 0.045;
      final col =
          _rgba(Color.lerp(c1, const Color.fromARGB(255, 4, 4, 11), 0.76 - layer * 0.1)!, 1 - layer * 0.05);
      _drawSilhouette(canvas, size, theme.silhouette, ly,
          drift * (layer + 1) * 1.3, col, layer);
      final fog = [0.45, 0.30, 0.16][layer];
      final fA = Color.lerp(c1, glow, 0.22)!;
      final fB = Color.lerp(c1, glow, 0.2)!;
      canvas.drawRect(
        Rect.fromLTWH(0, ly - 30, w, 52),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _rgba(fB, 0),
              _rgba(fA, fog * 0.22),
              _rgba(fB, 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromLTWH(0, ly - 30, w, 52)),
      );
    }

    /* gizem geçidi (preview.js:231) */
    _drawGate(canvas, size, w * 0.17 + drift, h * 0.5, glow);

    /* oynanacak kule (preview.js:234) */
    _drawTower(canvas, w * 0.73 + drift * 1.4, h * 0.80,
        math.min(w, h) / 420 * 2.1, theme.glow);

    /* hava parçacıkları (preview.js:237) */
    _drawWeather(canvas, size, theme.weather);

    /* okunabilirlik perdesi + vinyet (preview.js:240-251) */
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.42, w, h * 0.58),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color.fromARGB(0, 4, 4, 12),
            const Color.fromARGB(107, 4, 4, 12),
            const Color.fromARGB(235, 4, 4, 12),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTWH(0, h * 0.42, w, h * 0.58)),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.125),
          radius: 1.0,
          colors: [
            const Color.fromARGB(0, 0, 0, 0),
            const Color.fromARGB(140, 0, 0, 0),
          ],
          stops: const [0.2, 1],
        ).createShader(Rect.fromCircle(
            center: Offset(w * 0.5, h * 0.5), radius: math.max(w, h) * 0.8)),
    );
  }

  /* preview.js:254-359 — silüet türleri */
  void _drawSilhouette(Canvas canvas, Size size, String kind, double baseY,
      double drift, Color color, int layer) {
    final w = size.width;
    final fill = Paint()..color = color;
    if (kind == 'city') {
      var x = -60 + drift;
      var k = 0;
      while (x < w + 60) {
        final bw = 22 + ((k * 37 + layer * 13) % 52);
        final bh = 24 + ((k * 53 + layer * 31) % 120);
        canvas.drawRect(Rect.fromLTWH(x, baseY - bh, bw.toDouble(), bh + 120.0), fill);
        if (k % 4 == 0) {
          canvas.drawRect(Rect.fromLTWH(x + bw * 0.4, baseY - bh - 14, 2.4, 14), fill);
        }
        if (layer > 0) {
          final cols2 = math.max(1, bw ~/ 11);
          for (var wc = 0; wc < cols2; wc++) {
            canvas.drawRect(
              Rect.fromLTWH(x + 5 + wc * 10, baseY - bh + 9 + ((k + wc) % 5) * 11, 2.4, 3.4),
              Paint()
                ..color = Color.fromARGB(
                    (0.10 + ((k * 3 + wc) % 4) * 0.05) * 255 ~/ 1, 255, 225, 160),
            );
          }
          canvas.drawRect(
            Rect.fromLTWH(x, baseY - bh, bw.toDouble(), 1.2),
            Paint()..color = const Color.fromARGB(56, 150, 220, 255),
          );
        }
        x += bw + 6 + ((k * 7) % 12);
        k++;
      }
    } else if (kind == 'trees') {
      var tx = -40 + drift;
      var n = 0;
      while (tx < w + 40) {
        final th = 32 + ((n * 29 + layer * 11) % 70);
        final tw2 = 16 + ((n * 17) % 18);
        final path = Path()
          ..moveTo(tx, baseY - th)
          ..lineTo(tx + tw2, baseY + 90)
          ..lineTo(tx - tw2, baseY + 90)
          ..close();
        canvas.drawPath(path, fill);
        tx += tw2 + 8;
        n++;
      }
    } else if (kind == 'dunes' || kind == 'clouds') {
      final path = Path()..moveTo(-40, baseY + 90);
      var dx = -40.0;
      final step = w / 5;
      while (dx < w + 40) {
        path.quadraticBezierTo(dx + step * 0.5, baseY - 20 - (layer * 10), dx + step, baseY + 10);
        dx += step;
      }
      path
        ..lineTo(w + 40, baseY + 110)
        ..close();
      canvas.drawPath(path, fill);
    } else if (kind == 'ice') {
      final path = Path()..moveTo(-40, baseY + 90);
      var ix = -40.0;
      var m = 0;
      while (ix < w + 40) {
        final ih = 40 + ((m * 43 + layer * 17) % 90);
        path
          ..lineTo(ix, baseY + 90)
          ..lineTo(ix + 26, baseY - ih)
          ..lineTo(ix + 44, baseY + 90);
        ix += 44;
        m++;
      }
      path.close();
      canvas.drawPath(path, fill);
    } else if (kind == 'rocks') {
      for (var r = 0; r < 9; r++) {
        final rx = ((r * 137 + layer * 41) % (w + 80)) - 40 + drift * (r % 3);
        final ry = baseY - 20 + ((r * 53) % 40);
        final rr = 14 + ((r * 19) % 40);
        final path = Path();
        for (var q = 0; q < 6; q++) {
          final a = q / 6 * math.pi * 2;
          final rad = rr * (0.6 + 0.4 * math.sin(q * 2.3 + r));
          final px = rx + math.cos(a) * rad;
          final py = ry + math.sin(a) * rad * 0.7;
          if (q == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, fill);
      }
    } else {
      /* volkan */
      var p = Path()
        ..moveTo(-60, baseY + 90)
        ..lineTo(w * 0.28 + drift, baseY - 190)
        ..lineTo(w * 0.46 + drift, baseY + 90)
        ..close();
      canvas.drawPath(p, fill);
      p = Path()
        ..moveTo(w * 0.42 + drift, baseY + 90)
        ..lineTo(w * 0.66 + drift, baseY - 110)
        ..lineTo(w + 60, baseY + 90)
        ..close();
      canvas.drawPath(p, fill);
      /* lav çatlağı */
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.28 + drift, baseY - 180)
          ..lineTo(w * 0.24 + drift, baseY - 110)
          ..lineTo(w * 0.31 + drift, baseY - 50),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color.fromARGB(115, 255, 120, 60),
      );
    }
  }

  /* preview.js:361-389 — gizem geçidi: hale + kemer + '?' */
  void _drawGate(Canvas canvas, Size size, double x, double y, Color glow) {
    final r = math.min(size.width, size.height) * 0.095;
    final pulse = 0.5 + 0.5 * math.sin(t * 1.1);
    // JS'te kırpma yok (save/restore + 'lighter'); tabaka hale çemberini
    // tam içermeli — merkez (x, y-0.3r), yarıçap 2.2r (üst sınır y-2.5r'de).
    canvas.saveLayer(
        Rect.fromCircle(center: Offset(x, y - r * 0.3), radius: r * 2.2),
        Paint()..blendMode = BlendMode.plus);
    canvas.drawCircle(
      Offset(x, y - r * 0.3),
      r * 2.2,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            _rgba(glow, 0.22 + pulse * 0.12),
            _rgba(glow, 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y - r * 0.3), radius: r * 2.2)),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = _rgba(glow, 0.55);
    final arch = Path()
      ..addArc(Rect.fromCircle(center: Offset(x, y - r * 0.3), radius: r), math.pi, math.pi)
      ..moveTo(x + r, y - r * 0.3)
      ..lineTo(x + r, y + r * 0.8)
      ..moveTo(x - r, y - r * 0.3)
      ..lineTo(x - r, y + r * 0.8);
    canvas.drawPath(arch, stroke);

    final tp = TextPainter(
      text: TextSpan(
          text: '?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.16 + pulse * 0.12),
            fontSize: r * 0.9,
            fontWeight: FontWeight.w900,
          )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - r * 0.2 - tp.height / 2));
    canvas.restore();
  }

  /* preview.js:391-446 — 7 bloklu kule + tepe kristali */
  void _drawTower(Canvas canvas, double x, double baseY, double sc, num hue) {
    const widths = [104.0, 90.0, 78.0, 66.0, 56.0, 44.0, 32.0];
    const heights = [28.0, 25.0, 23.0, 21.0, 19.0, 17.0, 15.0];
    var y = baseY;
    var offset = 0.0;
    for (var i = 0; i < widths.length; i++) {
      final bw = widths[i] * sc * 0.9;
      final bh = heights[i] * sc;
      final bx = x - bw / 2 + offset;
      canvas.drawRect(
        Rect.fromLTWH(bx, y - bh, bw, bh),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.topRight,
            colors: const [
              Color.fromARGB(250, 9, 9, 20),
              Color.fromARGB(250, 16, 14, 32),
              Color.fromARGB(250, 24, 20, 46),
            ],
            stops: const [0, 0.75, 1],
          ).createShader(Rect.fromLTWH(bx, y - bh, bw, bh)),
      );
      canvas.drawRect(
        Rect.fromLTWH(bx + 0.5, y - bh + 0.5, bw - 1, bh - 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _hsl(hue, 94, 68, 0.8 - i * 0.05),
      );
      canvas.drawLine(
        Offset(bx, y - bh + 0.6),
        Offset(bx + bw, y - bh + 0.6),
        Paint()
          ..strokeWidth = 1
          ..color = _hsl(hue, 96, 78, 0.5 - i * 0.03),
      );
      final cols = math.max(2, (bw / (13 * sc)).round());
      for (var c = 0; c < cols; c++) {
        if ((i * 7 + c) % 3 == 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(bx + (c + 0.5) * bw / cols - 1.5, y - bh * 0.55, 3, 4),
          Paint()
            ..color = _hsl(
                46, 90, 68, 0.25 + 0.35 * (0.5 + 0.5 * math.sin(t * 2 + i + c))),
        );
      }
      y -= bh;
      final next = i + 1 < widths.length ? widths[i + 1] : 0.0;
      offset += (widths[i] - next) * sc * 0.05;
    }
    /* tepe kristali */
    final cw = 20.0 * sc, ch = 34.0 * sc;
    final glow = _hsl(hue, 92, 64);
    final crystal = Path()
      ..moveTo(x, y - ch)
      ..lineTo(x + cw / 2, y - ch * 0.45)
      ..lineTo(x, y)
      ..lineTo(x - cw / 2, y - ch * 0.45)
      ..close();
    final crystalPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.95),
          _rgba(glow, 0.95),
          _rgba(glow, 0.35),
        ],
      ).createShader(Rect.fromLTWH(x - cw, y - ch, cw * 2, ch));
    canvas.drawPath(crystal, crystalPaint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    crystalPaint.maskFilter = null;
    canvas.drawPath(crystal, crystalPaint);
  }

  /* preview.js:448-496 — hava türleri; embers 'lighter' toplama karışımıyla (preview.js:450) */
  void _drawWeather(Canvas canvas, Size size, String kind) {
    final w = size.width, h = size.height;
    final additive = kind == 'embers';
    if (additive) canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.plus);
    for (var i = 0; i < scene._particles.length; i++) {
      final p = scene._particles[i];
      var x = p.x * w;
      var y = p.y * h;
      if (kind == 'snow') {
        y = ((p.y + t * p.v * 0.5) % 1) * h * 0.8;
        x += math.sin(t * 0.6 + p.ph) * 14;
        canvas.drawCircle(
          Offset(x, y),
          p.s * 0.85,
          Paint()..color = const Color(0xFFe2f2ff).withValues(alpha: p.a * 0.55),
        );
      } else if (kind == 'sand') {
        x = ((p.x + t * p.v * 1.4) % 1) * w;
        y = h * 0.45 + p.y * h * 0.35;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 16 * p.s, y - 1.5),
          Paint()
            ..strokeWidth = 1
            ..color = const Color(0xFFFFDCA0).withValues(alpha: p.a * 0.35),
        );
      } else if (kind == 'leaves') {
        x = ((p.x + t * p.v * 0.35) % 1) * w;
        y = ((p.y + t * p.v * 0.22) % 1) * h * 0.75;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(t * 0.8 + p.rot);
        canvas.drawRect(
          Rect.fromLTWH(-2, -1, 4.5, 2),
          Paint()..color = _hsl(120 + (i % 3) * 18, 65, 55, p.a * 0.5),
        );
        canvas.restore();
      } else if (kind == 'embers') {
        y = h - ((p.y + t * p.v * 0.5) % 1) * h * 0.62;
        x += math.sin(t * 0.7 + p.ph) * 18;
        canvas.drawCircle(
          Offset(x, y),
          p.s * 0.7,
          Paint()..color = _hsl(26, 95, 62, p.a * 0.55),
        );
      } else {
        final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 1.4 + p.ph));
        canvas.drawCircle(
          Offset(x, y * 0.7),
          p.s * 0.75,
          Paint()..color = const Color(0xFFC8E8FF).withValues(alpha: p.a * tw * 0.6),
        );
      }
    }
    if (additive) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PreviewPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.scene != scene;
}
