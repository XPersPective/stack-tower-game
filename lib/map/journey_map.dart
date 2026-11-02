/// Stack Tower Game — DİKEY YOL HARİTASI (saga map, PB-035 tur 5).
///
/// Premium casual standardı (Royal Match / Candy Crush modeli): kıvrımlı bir
/// yol, üzerinde bölüm düğümleri, dünyalar arasında anıtsal KAPILAR, her
/// dünyada değişen tema renkleri/dekorları. 3B takımada denemesi kaldırıldı
/// (kullanıcı 2026-11-02: "gezegen mezegen olmamış").
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_session.dart';
import '../game/levels.dart';
import '../game/progress.dart' as prog;
import 'construction.dart';
import '../game/scene_painter.dart' show hslColor;
import '../theme/tokens.dart';

/// Dünya dikey yüksekliği (mantıksal px) — 15 bölüm + kapı bandı.
const double kWorldH = 1560;
const double kNodeSpacing = 86;
const double kNodeR = 27;

/// Yol üzerindeki bölüm düğümü (yerleşim saf matematik — test dostu).
class JourneyNode {
  final int i;
  final LevelDef def;
  final Offset pos; // yol-uzayında (y: 0 = dünya 0 üstü)
  final bool done;
  final bool unlocked;
  final int stars;
  Offset? screen; // painter her karede doldurur (hitTest için)
  JourneyNode({
    required this.i,
    required this.def,
    required this.pos,
    required this.done,
    required this.unlocked,
    required this.stars,
  });
}

/// [width] genişlikte 150 düğümün kıvrımlı yol yerleşimi — deterministik.
List<JourneyNode> journeyLayout(GameSession session, double width) {
  final save = session.state;
  final nodes = <JourneyNode>[];
  final w = width <= 0 ? 400.0 : width;
  for (var i = 0; i < kLevelCount; i++) {
    final def = levelDef(i);
    final stage = def.stage;
    final idx = def.idx;
    final y = stage * kWorldH + 220 + idx * kNodeSpacing;
    // kıvrım: dünya başına fazla kaymış sinüs — düz hat asla olmaz
    final sway = math.sin(stage * 1.7 + idx * 0.62) * w * 0.24 +
        math.sin(stage * 0.6 + idx * 0.21) * w * 0.08;
    nodes.add(JourneyNode(
      i: i,
      def: def,
      pos: Offset(w * 0.5 + sway, y),
      done: save.completed[i] != null,
      unlocked: prog.isUnlocked(save, i, def),
      stars: save.completed[i]?['stars'] ?? 0,
    ));
  }
  return nodes;
}

/// [stage] dünyasının kapı bandının y merkezı.
double gateY(int stage) => stage * kWorldH + 60;

/// Toplam harita yüksekliği.
double journeyHeight() => kStageCount * kWorldH + 260;

/// Yol hit-test: dokunuş yol-uzayı koordinatında düğüm / pazar tezgahı.
/// Dönen: 'node:<i>' | 'market' | null
String? journeyHitTest(List<JourneyNode> nodes, Offset mapPos,
    {required bool marketOpen}) {
  if (marketOpen) {
    // pazar tezgahı: dünya 0'ın 3. düğümünün sağına sabit
    final stall = Offset(nodes[2].pos.dx + 96, nodes[2].pos.dy + 8);
    if ((mapPos - stall).distance <= 40) return 'market';
  }
  JourneyNode? best;
  var bestD = double.infinity;
  for (final n in nodes) {
    final d = (mapPos - n.pos).distance;
    if (d < bestD) {
      bestD = d;
      best = n;
    }
  }
  if (best != null && bestD <= kNodeR + 14) return 'node:${best.i}';
  return null;
}

/// Döküman kalitesinde yıldız yolu (5 köşeli).
Path starPath(Offset c, double r) {
  final p = Path();
  for (var k = 0; k < 10; k++) {
    final rr = k.isEven ? r : r * 0.44;
    final a = -math.pi / 2 + k * math.pi / 5;
    final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
    k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Dikey yol haritası painter'ı. [scroll] = üstten kaydırma, [time] sn.
class JourneyPainter extends CustomPainter {
  JourneyPainter({
    required this.session,
    required this.nodes,
    required this.scroll,
    required this.time,
    required this.marketOpen,
    this.riseT = 1.0,
    super.repaint,
  });

  final GameSession session;
  final List<JourneyNode> nodes;
  final double scroll;
  final double time;
  final bool marketOpen;
  final double riseT; // PB-029: son parça yükselme (0..1)

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final currentIdx = _currentIdx();

    _paintBackground(canvas, size, scroll);
    _paintSilhouettes(canvas, size, scroll);
    _paintPath(canvas, size, scroll);
    _paintGates(canvas, size, scroll);
    _paintDecor(canvas, size, scroll);
    _paintConstruction(canvas, size, scroll);
    _paintMarket(canvas, size, scroll);
    for (final n in nodes) {
      final p = n.pos - Offset(0, scroll);
      n.screen = p;
      if (p.dy < -80 || p.dy > size.height + 80) continue;
      _paintNode(canvas, n, p, w, n.i == currentIdx);
    }
  }

  int _currentIdx() {
    for (final n in nodes) {
      if (n.unlocked && !n.done) return n.i;
    }
    return kLevelCount - 1;
  }

  /* ------------------------------ katmanlar ------------------------------ */

  void _paintBackground(Canvas canvas, Size size, double sc) {
    // dünya dilimlerinin dikey gradyanları, sınırda çapraz karışım
    for (var s = 0; s < kStageCount; s++) {
      final top = s * kWorldH - sc;
      if (top > size.height || top + kWorldH < 0) continue;
      final th = kThemes[s];
      final band = Rect.fromLTWH(0, top, size.width, kWorldH);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [th.bg1, th.bg2],
          ).createShader(band.inflate(2)),
      );
      // dünya sınırlarında yumuşak geçiş perdesi
      if (s > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, top - 90, size.width, 180),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kThemes[s - 1].bg2.withValues(alpha: 1),
                kThemes[s - 1].bg2.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(0, top - 90, size.width, 90)),
        );
      }
    }
    // paralaks yıldızlar (yavaş katman)
    final rnd = math.Random(77);
    for (var i = 0; i < 70; i++) {
      final sx = rnd.nextDouble() * size.width;
      final sy = (rnd.nextDouble() * journeyHeight() * 0.5 - sc * 0.5) % size.height;
      final yy = sy < 0 ? sy + size.height : sy;
      final tw = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(time * (0.4 + rnd.nextDouble()) + i));
      canvas.drawCircle(
        Offset(sx, yy),
        0.5 + rnd.nextDouble() * 1.4,
        Paint()..color = Colors.white.withValues(alpha: tw * 0.5),
      );
    }
  }

  void _paintSilhouettes(Canvas canvas, Size size, double sc) {
    // her dünyanın üst kenarında uzak silüet şeridi (paralaks 0.85)
    for (var s = 0; s < kStageCount; s++) {
      final top = s * kWorldH - sc * 0.85;
      if (top > size.height + 60 || top + 140 < -60) continue;
      final th = kThemes[s];
      final col = hslColor(th.glow, 30, 12).withValues(alpha: 0.85);
      final path = Path()..moveTo(-20, top + 130);
      if (th.silhouette == 'city') {
        for (var k = 0; k < 14; k++) {
          final bx = k / 13 * (size.width + 40) - 20;
          final bh = 40 + 70 * math.sin(k * 2.7 + s);
          path.lineTo(bx, top + 130 - bh);
          path.lineTo(bx + (size.width / 14) * 0.5, top + 130 - bh);
        }
      } else {
        for (var k = 0; k < 9; k++) {
          final bx = -20 + k / 8 * (size.width + 40);
          final bh = 50 + 80 * math.sin(k * 1.9 + s * 2);
          path.lineTo(bx + (size.width / 9) / 2, top + 130 - bh);
          path.lineTo(bx + (size.width / 9), top + 130);
        }
      }
      path.lineTo(size.width + 20, top + 130);
      path.close();
      canvas.drawPath(path, Paint()..color = col);
    }
  }

  void _paintPath(Canvas canvas, Size size, double sc) {
    if (nodes.isEmpty) return;
    // yumuşak spline: ardışık düğümler arası orta-nokta kuadratikleri
    final pts = [for (final n in nodes) n.pos];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy - sc);
    for (var k = 1; k < pts.length; k++) {
      final a = pts[k - 1], b = pts[k];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy - sc, mid.dx, mid.dy - sc);
    }
    final last = pts.last;
    path.lineTo(last.dx, last.dy - sc);

    // geniş koyu taban + tema glow iç çizgi
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    // akan kesikli ışık (yol canlı — zamanla kayar)
    canvas.drawPath(
      path,
      Paint()
        ..color = hslColor(kThemes[0].glow, 90, 70).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  void _paintGates(Canvas canvas, Size size, double sc) {
    final save = session.state;
    for (var s = 0; s < kStageCount; s++) {
      final gy = gateY(s) - sc;
      if (gy < -140 || gy > size.height + 140) continue;
      final th = kThemes[s];
      final open = s == 0 || prog.totalStars(save) >= requiredStarsFor(s);
      final glow = hslColor(th.glow, 90, 62);
      final cx = size.width / 2;
      // anıtsal kemer
      final arch = Path()
        ..moveTo(cx - 120, gy + 60)
        ..lineTo(cx - 120, gy - 20)
        ..quadraticBezierTo(cx, gy - 120, cx + 120, gy - 20)
        ..lineTo(cx + 120, gy + 60);
      canvas.drawPath(
        arch,
        Paint()
          ..color = (open ? glow : Colors.white24).withValues(alpha: open ? 0.85 : 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
      // dünya adı + kilit durumu
      final tp = TextPainter(
        text: TextSpan(
          text: open ? 'DÜNYA ${s + 1} · ${th.name}' : '🔒 ${requiredStarsFor(s)} ★',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: open ? glow : Colors.white38,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, gy + 4));
      // kemer ayaklarında fenerler
      for (final fx in const [-120.0, 120.0]) {
        canvas.drawCircle(
          Offset(cx + fx, gy + 60),
          5,
          Paint()..color = (open ? glow : Colors.white24).withValues(alpha: 0.9),
        );
      }
    }
  }

  void _paintDecor(Canvas canvas, Size size, double sc) {
    // yol kenarı dekorları: tema hava tipine göre ağaç/kristal/fener
    for (var s = 0; s < kStageCount; s++) {
      final base = s * kWorldH - sc;
      if (base > size.height + 100 || base + kWorldH < -100) continue;
      final th = kThemes[s];
      final col = hslColor(th.hues.isNotEmpty ? th.hues[0] : th.glow, 70, 45);
      final rnd = math.Random(500 + s);
      for (var k = 0; k < 7; k++) {
        final side = k.isEven ? -1 : 1;
        final dx = size.width * 0.5 + side * (size.width * 0.30 + rnd.nextDouble() * size.width * 0.14);
        final dy = base + 240 + rnd.nextDouble() * (kWorldH - 320);
        final h = 18 + rnd.nextDouble() * 22;
        if (th.weather == 'stars' || th.weather == 'snow') {
          // kristal kümesi
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(0.4);
          canvas.drawRect(
            Rect.fromLTWH(-h * 0.18, -h, h * 0.36, h),
            Paint()..color = col.withValues(alpha: 0.65),
          );
          canvas.restore();
        } else {
          // fener/ağaç silüeti
          canvas.drawCircle(Offset(dx, dy - h), h * 0.34,
              Paint()..color = col.withValues(alpha: 0.55));
          canvas.drawLine(
            Offset(dx, dy),
            Offset(dx, dy - h),
            Paint()
              ..color = col.withValues(alpha: 0.7)
              ..strokeWidth = 2.4,
          );
        }
      }
    }
  }

  /// C-021 görünür inşaat (PB-035 taşıma): dünya segmentinin altında mini
  /// yapı kulesi — tamamlanan parçalar dolu + neon kontur; bitince tepe ışığı.
  void _paintConstruction(Canvas canvas, Size size, double sc) {
    final save = session.state;
    for (var s = 0; s < kStageCount; s++) {
      final baseY = (s + 1) * kWorldH - 150 - sc;
      if (baseY < -160 || baseY > size.height + 160) continue;
      final th = kThemes[s];
      final glow = hslColor(th.glow, 90, 62);
      var built = 0, total = 0;
      for (var si = 0; si < kWorldStructures.length; si++) {
        built += piecesBuilt(save, s, si);
        total += kWorldStructures[si].pieces.length;
      }
      final dx = size.width * 0.5;
      final unit = 13.0;
      final hAll = total * unit;
      // iskelet (hedef) + dolu parçalar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(dx - 16, baseY - hAll, 32, hAll), const Radius.circular(3)),
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );
      for (var k = 0; k < built; k++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(dx - 15, baseY - (k + 1) * unit + 1, 30, unit - 2),
              const Radius.circular(2)),
          Paint()..color = hslColor(th.glow, 60, 20 + (k * 9) % 40),
        );
      }
      if (built > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(dx - 16, baseY - built * unit, 32, built * unit),
              const Radius.circular(3)),
          Paint()
            ..color = glow.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      if (built == total) {
        canvas.drawCircle(
          Offset(dx, baseY - hAll - 8),
          5,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  void _paintMarket(Canvas canvas, Size size, double sc) {
    if (!marketOpen || nodes.length < 3) return;
    final p = Offset(nodes[2].pos.dx + 96, nodes[2].pos.dy + 8) - Offset(0, sc);
    final th = kThemes[0];
    // tezgah: çadır + parlak şerit
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 44, height: 30), const Radius.circular(6)),
      Paint()..color = hslColor(35, 85, 45),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 52, height: 12), const Radius.circular(6)),
      Paint()..color = hslColor(35, 95, 62),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'PAZAR',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: hslColor(th.glow, 90, 78),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, 34));
  }

  void _paintNode(Canvas canvas, JourneyNode n, Offset p, double w, bool current) {
    final th = n.def.theme;
    final glow = hslColor(th.glow, 90, 62);

    if (n.done) {
      // tamamlanan: dolu madalyon + yıldız(lar)
      canvas.drawCircle(p, kNodeR, Paint()..color = glow.withValues(alpha: 0.24));
      canvas.drawCircle(p, kNodeR * 0.82, Paint()..color = glow);
      canvas.drawPath(starPath(p, kNodeR * 0.5), Paint()..color = const Color(0xFFFFF3C4));
    } else if (n.unlocked) {
      // açık sıradaki: çift halka + GİZEMLİ tür glifi (tam görünmez)
      if (current) {
        final pulse = 1 + 0.14 * math.sin(time * 3);
        canvas.drawCircle(
          p,
          kNodeR * 1.5 * pulse,
          Paint()
            ..color = NeonPalette.cyan.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawCircle(p, kNodeR, Paint()..color = const Color(0xE60E0E1C));
      canvas.drawCircle(
        p,
        kNodeR,
        Paint()
          ..color = glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _paintKindGlyph(canvas, n.def.kind, p, glow);
    } else {
      // kilitli: loş disk + asma kilit
      canvas.drawCircle(p, kNodeR * 0.9, Paint()..color = const Color(0xCC0B0B16));
      canvas.drawCircle(
        p,
        kNodeR * 0.9,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final lk = Paint()
        ..color = Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: p + const Offset(0, 2), width: 14, height: 11), const Radius.circular(3)),
        lk,
      );
      canvas.drawArc(Rect.fromCircle(center: p + const Offset(0, -4), radius: 5), math.pi, math.pi, false, lk);
    }
    // kutu düğümü rozeti
    if (n.def.box && session.state.boxes[n.i.toString()] != true) {
      canvas.drawCircle(
        p + Offset(kNodeR * 0.8, -kNodeR * 0.8),
        7,
        Paint()..color = NeonPalette.gold,
      );
    }
  }

  /// Gizemli tür glifi — oyunun tam görüntüsü değil, sinirli bir iması.
  void _paintKindGlyph(Canvas canvas, GameKind kind, Offset c, Color col) {
    final a = 0.45 + 0.18 * (0.5 + 0.5 * math.sin(time * 1.2 + c.dy * 0.02));
    final p = Paint()
      ..color = Colors.white.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final u = kNodeR * 0.44;
    switch (kind) {
      case GameKind.stack:
        canvas.drawRect(Rect.fromLTWH(c.dx - u, c.dy + u * 0.2, u * 2, u * 0.4), p);
        canvas.drawRect(Rect.fromLTWH(c.dx - u * 0.66, c.dy - u * 0.34, u * 1.32, u * 0.4), p);
      case GameKind.catcher:
        canvas.drawArc(Rect.fromCircle(center: c, radius: u), 0.2 * math.pi, 0.6 * math.pi, false, p);
      case GameKind.ring:
        canvas.drawCircle(c, u * 0.8, p);
      case GameKind.launch:
        canvas.drawLine(c + Offset(u * 0.7, u * 0.7), c - Offset(u * 0.7, u * 0.7), p);
      case GameKind.merge:
        canvas.drawCircle(c + Offset(-u * 0.4, 0), u * 0.34, p);
        canvas.drawCircle(c + Offset(u * 0.4, 0), u * 0.34, p);
      case GameKind.path:
        canvas.drawArc(Rect.fromCircle(center: c, radius: u), -0.5, math.pi * 1.2, false, p);
      case GameKind.sort:
        canvas.drawLine(c + Offset(-u * 0.6, u * 0.5), c + Offset(0, -u * 0.5), p);
        canvas.drawLine(c + Offset(0, -u * 0.5), c + Offset(u * 0.6, u * 0.5), p);
      case GameKind.balance:
        canvas.drawLine(c + Offset(-u, 0), c + Offset(u, -u * 0.4), p);
        canvas.drawLine(c + Offset(0, u * 0.6), c, p);
      case GameKind.defend:
        canvas.drawArc(Rect.fromCircle(center: c, radius: u), math.pi, math.pi, false, p);
      case GameKind.rhythm:
        canvas.drawCircle(c + Offset(-u * 0.4, u * 0.3), u * 0.24, p);
        canvas.drawCircle(c + Offset(u * 0.42, -u * 0.1), u * 0.24, p);
    }
  }

  @override
  bool shouldRepaint(covariant JourneyPainter old) => true;
}

/// Bir dünyayı açmak için gereken yıldız (levels.dart kilit kuralıyla aynı).
int requiredStarsFor(int stage) => stage * 10;
