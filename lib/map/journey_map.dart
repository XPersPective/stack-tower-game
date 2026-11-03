/// Stack Tower Game — DİKEY YOL HARİTASI (saga map, PB-035 tur 5+6).
///
/// Premium casual standardı (Royal Match / Candy Crush modeli): kıvrımlı bir
/// yol, üzerinde bölüm düğümleri, dünyalar arasında anıtsal KAPILAR, her
/// dünyada değişen tema renkleri/dekorları.
///
/// YÖN (kullanıcı tur 6): yolculuk YUKARI — oyuncu altta (kendi aşaması önde),
/// kilitli aşamalar İLERİDE/ufukta; ilerledikçe uzaya doğru tırmanış hissi.
/// Düğümlerde ışıltılı isimler (ALTIN HAZİNE, PATRON, SÜRPRİZ SANDIK…),
/// yol kenarında parıltılı hediye/gizem süsleri.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../game/game_session.dart';
import '../game/levels.dart';
import '../game/progress.dart' as prog;
import '../game/scene_painter.dart' show hslColor;
import 'construction.dart';
import '../theme/tokens.dart';

/// Dünya dikey yüksekliği (mantıksal px) — 15 bölüm + kapı bandı.
const double kWorldH = 1560;
const double kNodeSpacing = 86;
const double kNodeR = 27;

/// Dünya [stage] düğümlerinin TABAN y'si (harita-uzayı; büyük y = oyuncuya yakın).
double worldBaseY(int stage) =>
    journeyHeight() - 240 - stage * kWorldH;

/// Toplam harita yüksekliği.
double journeyHeight() => (kStageCount + 5) * kWorldH + 300; // +5 gizem teaser'ı

/// Dünya [stage]'e giriş kapısının y merkezi (giriş, düğümlerin ALTINDAN).
double gateY(int stage) => worldBaseY(stage) + 130;

/// Yol üzerindeki bölüm düğümü (yerleşim saf matematik — test dostu).
class JourneyNode {
  final int i;
  final LevelDef def;
  final Offset pos; // yol-uzayında
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

  /// Düğümün ışıltılı etiketi (kullanıcı tur 6: isimler + görevler).
  String get label {
    if (def.modifier == 'patron') return 'PATRON KAPISI';
    if (def.box) return 'SÜRPRİZ SANDIK';
    if (def.modifier == 'altin') return 'ALTIN HAZİNE · ★';
    if (def.modifier == 'karanlik') return 'GİZEMLİ · ◐';
    return 'BÖLÜM ${def.num}';
  }

  bool get isSpecial =>
      def.modifier == 'patron' ||
      def.box ||
      def.modifier == 'altin' ||
      def.modifier == 'karanlik';
}

/// [width] genişlikte 150 düğümün kıvrımlı yol yerleşimi — deterministik.
/// YÖN: düğüm 0 ALTTA (oyuncu), 149 UYUKTA (ufuk) — macera yukarı akar.
List<JourneyNode> journeyLayout(GameSession session, double width) {
  final save = session.state;
  final nodes = <JourneyNode>[];
  final w = width <= 0 ? 400.0 : width;
  for (var i = 0; i < kLevelCount; i++) {
    final def = levelDef(i);
    final stage = def.stage;
    final idx = def.idx;
    final y = worldBaseY(stage) - idx * kNodeSpacing;
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

/// Yol hit-test: dokunuş yol-uzayı koordinatında düğüm / pazar tezgahı.
/// Dönen: 'node:<i>' | 'market' | null
String? journeyHitTest(List<JourneyNode> nodes, Offset mapPos,
    {required bool marketOpen}) {
  if (marketOpen) {
    // pazar tezgahı: 3. düğümün sağına sabit (dünya 1 segmenti)
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

/// PB-036 tur 9 KÖK-DÜZELTME: metin önbelleği — kaydırma jankının kök nedeni
/// her karede 150+ TextPainter.layout idi. Etiket bir kez layout edilir,
/// sonraki karelerde yalnız boyanır (60 fps kaydırma bütçesi).
final Map<String, TextPainter> _journeyTextCache = {};

TextPainter _journeyText(String key, TextSpan span) {
  return _journeyTextCache.putIfAbsent(key, () {
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  });
}

/// Dikey yol haritası painter'ı. [scroll] = alttan kaydırma (0 = başlangıç).
class JourneyPainter extends CustomPainter {
  JourneyPainter({
    required this.session,
    required this.nodes,
    required ValueListenable<double> scroll,
    required ValueListenable<double> time,
    required this.marketOpen,
    this.riseT = 1.0,
    super.repaint,
  })  : _scrollN = scroll,
        _timeN = time;

  final GameSession session;
  final List<JourneyNode> nodes;
  // PB-036 kök-düzeltme: painter build anında KOPYALAMIYOR — kaydırma/animasyon
  // zamanı canlı dinleyiciden okunuyor (eskiden notify yeniden boyar ama eski
  // alan değerleriyle boyuyordu → harita taşınmaz/animasyonsuz görünürdü)
  final ValueListenable<double> _scrollN;
  final ValueListenable<double> _timeN;
  final bool marketOpen;
  final double riseT; // PB-029: son parça yükselme (0..1)

  double get scroll => _scrollN.value;
  double get time => _timeN.value;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final currentIdx = _currentIdx();

    _paintBackground(canvas, size, scroll);
    _paintSilhouettes(canvas, size, scroll);
    _paintHorizon(canvas, size);
    _paintPath(canvas, size, scroll);
    _paintGates(canvas, size, scroll);
    _paintDecor(canvas, size, scroll);
    _paintConstruction(canvas, size, scroll);
    _paintMarket(canvas, size, scroll);
    for (final n in nodes) {
      final p = n.pos - Offset(0, scroll);
      n.screen = p;
      if (p.dy < -90 || p.dy > size.height + 90) continue;
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
    // dünya dilimlerinin dikey gradyanları (büyük y = dünya 1, küçük y = dünya 10)
    for (var s = 0; s < kStageCount; s++) {
      final bottom = journeyHeight() - s * kWorldH - sc;
      final top = bottom - kWorldH;
      if (top > size.height || bottom < 0) continue;
      final th = kThemes[s];
      final band = Rect.fromLTWH(0, top, size.width, kWorldH);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter, // uzak (ufuk) — koyu/hazy
            end: Alignment.bottomCenter, // yakın — tema rengi
            colors: [
              Color.lerp(th.bg1, const Color(0xFF04040F), 0.45)!,
              th.bg1,
              th.bg2,
            ],
            stops: const [0, 0.45, 1],
          ).createShader(band.inflate(2)),
      );
      // dünya sınırlarında yumuşak geçiş perdesi
      if (s > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, bottom - 90, size.width, 180),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kThemes[s - 1].bg2.withValues(alpha: 0),
                kThemes[s - 1].bg2.withValues(alpha: 1),
              ],
            ).createShader(Rect.fromLTWH(0, bottom, size.width, 90)),
        );
      }
    }
    // paralaks yıldızlar
    final rnd = math.Random(77);
    for (var i = 0; i < 90; i++) {
      final sx = rnd.nextDouble() * size.width;
      final sy = (rnd.nextDouble() * journeyHeight() * 0.6 - sc * 0.55) % size.height;
      final yy = sy < 0 ? sy + size.height : sy;
      final tw = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(time * (0.4 + rnd.nextDouble()) + i));
      final rr = 0.5 + rnd.nextDouble() * 1.5;
      canvas.drawCircle(
        Offset(sx, yy),
        rr,
        Paint()..color = Colors.white.withValues(alpha: tw * 0.55),
      );
      // PB-037: parlak yıldızlara çapraz ışın (twinkle hissi)
      if (rr > 1.6 && tw > 0.7) {
        final ray = Paint()..color = Colors.white.withValues(alpha: tw * 0.5);
        canvas.drawRect(Rect.fromLTWH(sx - rr * 3, yy - 0.5, rr * 6, 1), ray);
        canvas.drawRect(Rect.fromLTWH(sx - 0.5, yy - rr * 3, 1, rr * 6), ray);
      }
    }
  }

  /// Ufuk: ekranın üst bandında uzay derinliği parıltısı (her zaman görünür —
  /// ilerledikçe "yukarıda bir şey var" hissi; kullanıcı tur 6).
  void _paintHorizon(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.30);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            hslColor(268, 70, 24).withValues(alpha: 0.30),
            hslColor(268, 70, 24).withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    // uzak gökada silüeti (sabit, çok soluk)
    final rnd = math.Random(2029);
    for (var i = 0; i < 14; i++) {
      final sx = rnd.nextDouble() * size.width;
      final sy = size.height * (0.02 + rnd.nextDouble() * 0.16);
      final r = 1.0 + rnd.nextDouble() * 2.2;
      canvas.drawCircle(
        Offset(sx, sy),
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.10 + rnd.nextDouble() * 0.10),
      );
    }
  }

  void _paintSilhouettes(Canvas canvas, Size size, double sc) {
    // her dünya segmentinin ÜST kenarında (ileride) silüet şeridi — ufuk çizgisi
    for (var s = 0; s < kStageCount; s++) {
      final top = journeyHeight() - (s + 1) * kWorldH - sc;
      if (top > size.height + 60 || top + 140 < -60) continue;
      final th = kThemes[s];
      final col = hslColor(th.glow, 30, 13).withValues(alpha: 0.85);
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
    final pts = [for (final n in nodes) Offset(n.pos.dx, n.pos.dy - sc)];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var k = 1; k < pts.length; k++) {
      final a = pts[k - 1], b = pts[k];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
    final last = pts.last;
    path.lineTo(last.dx, last.dy);

    // geniş koyu taban + iç ışık
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
    // akan kesikli ışık — yukarı akar (macera yönü)
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
    // PB-036 tur 7: SONSUZ HARİTA — 10 dünya sonrası prosedürel gizem
    // segmentleri: isim bulutundan kapılar, ağır sis + rune; içerik SIZMAZ
    // (kullanıcı: "aşağı indikçe hepsi gelebilsin, sonu gözükmesin")
    final mystery = [
      '??? · GİZENLİK BULUTLARI',
      '??? · YANKI KULESİ',
      '??? · SONSUZLUK NOKTASI',
      '??? · AYNALAR DÜNYASI',
      '??? · KARANLIK MATRİS',
    ];
    for (var s = kStageCount; s < kStageCount + mystery.length; s++) {
      final gy = gateY(s) - sc;
      if (gy < -140 || gy > size.height + 140) continue;
      // PB-037 (harita raporu): kemer KALDIRILDI — ufuk ışık sütunu:
      // yukarı doğru yükselen, nabızlayan sisli ışık (içerik sızmaz)
      final pulse = 0.5 + 0.5 * math.sin(time * 1.2 + s * 1.9);
      final cx = size.width / 2;
      final beam = Rect.fromLTWH(cx - 90, gy - 190, 180, 250);
      canvas.drawRect(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              hslColor(268, 70, 34).withValues(alpha: 0.20 + 0.10 * pulse),
              hslColor(268, 70, 34).withValues(alpha: 0),
            ],
          ).createShader(beam),
      );
      // segment girişinde yıldız tozları — yol buradan ufka uzanır
      final rnd = math.Random(900 + s);
      for (var d = 0; d < 14; d++) {
        final dx = cx + (rnd.nextDouble() - 0.5) * 260;
        final dy = gy + 60 - rnd.nextDouble() * 200;
        final dd = rnd.nextDouble();
        canvas.drawCircle(
          Offset(dx, dy),
          0.8 + dd * 1.6,
          Paint()
            ..color = Colors.white
                .withValues(alpha: (0.12 + 0.30 * pulse) * (1 - dd * 0.6)),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: mystery[s - kStageCount],
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Colors.white.withValues(alpha: 0.35 + 0.2 * pulse),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, gy + 2));
      // rune halka: kapı üstünde dönen
      canvas.save();
      canvas.translate(cx, gy - 86);
      canvas.rotate(time * 0.6 + s);
      canvas.drawCircle(
        Offset.zero,
        16,
        Paint()
          ..color = hslColor(268, 70, 32).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var tick = 0; tick < 8; tick++) {
        final ta = tick / 8 * math.pi * 2;
        canvas.drawCircle(
          Offset(math.cos(ta) * 16, math.sin(ta) * 16),
          2.4,
          Paint()..color = Colors.white.withValues(alpha: 0.4 + 0.3 * pulse),
        );
      }
      canvas.restore();
    }
    for (var s = 1; s < kStageCount; s++) {
      final gy = gateY(s) - sc;
      if (gy < -140 || gy > size.height + 140) continue;
      final th = kThemes[s];
      final open = prog.totalStars(save) >= requiredStars(s);
      final glow = hslColor(th.glow, 90, 62);
      final cx = size.width / 2;
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
      final tp = TextPainter(
        text: TextSpan(
          text: open ? 'DÜNYA ${s + 1} · ${th.name}' : 'KİLİTLİ · DÜNYA ${s + 1} · ${requiredStars(s)} ★',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: open ? glow : Colors.white38,
            shadows: open
                ? [Shadow(color: glow.withValues(alpha: .6), blurRadius: 12)]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, gy + 4));
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
    // PB-036 tur 7: emoji süsler (hediye/soru kova hissi) KALDIRILDI → geometrik
    // premium süsler: parıltılı küreler, 4 uçlu glintler, rune halkaları
    for (var s = 0; s < kStageCount; s++) {
      final th = kThemes[s];
      final baseBottom = journeyHeight() - s * kWorldH - sc;
      final baseTop = baseBottom - kWorldH;
      if (baseTop > size.height + 100 || baseBottom < -100) continue;
      final hue = th.hues.isNotEmpty ? th.hues[0] : th.glow;
      final rnd = math.Random(500 + s);
      for (var k = 0; k < 9; k++) {
        final side = k.isEven ? -1 : 1;
        final dx = size.width * 0.5 +
            side * (size.width * 0.28 + rnd.nextDouble() * size.width * 0.16);
        final dy = baseTop + 200 + rnd.nextDouble() * (kWorldH - 340);
        final kind = rnd.nextInt(3);
        if (kind == 0) {
          // parıltılı küre — şeffaf, nabızlı
          final pulse = 0.5 + 0.5 * math.sin(time * 1.1 + k * 2.1 + s);
          final r = 5 + rnd.nextDouble() * 7;
          canvas.drawCircle(
            Offset(dx, dy),
            r * 2.6,
            Paint()
              ..color = hslColor(hue, 90, 70).withValues(alpha: 0.10 + 0.08 * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
          canvas.drawCircle(
            Offset(dx, dy),
            r,
            Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.3 * pulse),
          );
        } else if (kind == 1) {
          // 4 uçlu glint — dönen yıldız pırıltısı (deterministik nefes)
          final pulse = 0.55 + 0.45 * math.sin(time * 1.4 + k * 1.7 + s);
          final g = 7 + rnd.nextDouble() * 6;
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(time * 0.4 + k);
          final gp = Paint()
            ..shader = RadialGradient(colors: [
              Colors.white.withValues(alpha: 0.85 * pulse),
              hslColor(hue, 90, 72).withValues(alpha: 0.25 * pulse),
              Colors.white.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: Offset.zero, radius: g));
          canvas.drawCircle(Offset.zero, g, gp);
          canvas.drawLine(Offset(-g, 0), Offset(g, 0),
              Paint()..color = Colors.white.withValues(alpha: 0.5 * pulse)..strokeWidth = 1);
          canvas.drawLine(Offset(0, -g), Offset(0, g),
              Paint()..color = Colors.white.withValues(alpha: 0.5 * pulse)..strokeWidth = 1);
          canvas.restore();
        } else {
          // rune halkası — yavaş dönen, düşük alfa (gizem; emoji yok)
          final rot = time * 0.5 + k + s;
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(rot);
          canvas.drawCircle(
            Offset.zero,
            15,
            Paint()
              ..color = hslColor(268, 70, 30).withValues(alpha: 0.22)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          for (var tick = 0; tick < 6; tick++) {
            final ta = tick / 6 * math.pi * 2;
            canvas.drawCircle(
              Offset(math.cos(ta) * 15, math.sin(ta) * 15),
              2.2,
              Paint()..color = hslColor(hue, 90, 70).withValues(alpha: 0.55),
            );
          }
          canvas.restore();
        }
      }
    }
  }

  /// C-021 görünür inşaat: dünya segmentinin altında mini yapı kulesi.
  void _paintConstruction(Canvas canvas, Size size, double sc) {
    final save = session.state;
    for (var s = 0; s < kStageCount; s++) {
      final baseY = worldBaseY(s) - 15 * kNodeSpacing - 60 - sc;
      if (baseY < -160 || baseY > size.height + 160) continue;
      final th = kThemes[s];
      final glow = hslColor(th.glow, 90, 62);
      var built = 0, total = 0;
      for (var si = 0; si < kWorldStructures.length; si++) {
        built += piecesBuilt(save, s, si);
        total += kWorldStructures[si].pieces.length;
      }
      final dx = size.width * 0.5 + 150;
      const unit = 13.0;
      final hAll = total * unit;
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 44, height: 30),
          const Radius.circular(6)),
      Paint()..color = hslColor(35, 85, 45),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 52, height: 12),
          const Radius.circular(6)),
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
          color: hslColor(35, 90, 78),
          shadows: [Shadow(color: hslColor(35, 95, 60).withValues(alpha: .6), blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, 34));
  }

  void _paintNode(Canvas canvas, JourneyNode n, Offset p, double w, bool current) {
    final th = n.def.theme;
    final glow = hslColor(th.glow, 90, 62);
    // derinlik: ufka (küçük harita-y) doğru düğümler hafif küçülür — yolculuk hissi
    final depth = (n.pos.dy / journeyHeight()).clamp(0.0, 1.0);
    final r = kNodeR * (0.80 + 0.20 * depth);

    // ışıltılı İSİM etiketi — önbellekli, OKUNUR (tur 9: küçük/soluktu)
    final labelColor = n.isSpecial
        ? (n.def.modifier == 'patron'
            ? NeonPalette.magenta
            : n.def.box
                ? NeonPalette.gold
                : NeonPalette.amber)
        : (n.done ? Colors.white : Colors.white.withValues(alpha: 0.85));
    final label = _journeyText(
      'lbl|${n.label}',
      TextSpan(
        text: n.label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: n.isSpecial ? 13.5 : 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: labelColor,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: .9), blurRadius: 6),
            Shadow(
                color: n.isSpecial
                    ? hslColor(45, 95, 60).withValues(alpha: .85)
                    : glow.withValues(alpha: .7),
                blurRadius: 10),
          ],
        ),
      ),
    );
    label.paint(canvas, Offset(p.dx - label.width / 2, p.dy + r + 5));

    // tur 9 PREMIUM DÜĞÜM: katmanlı madalyon (halo gradyan + kıvılcım
    // halkası + çift kontur + çekirdek parıltısı)
    if (n.done) {
      canvas.drawCircle(
        p,
        r * 1.25,
        Paint()
          ..shader = RadialGradient(colors: [
            glow.withValues(alpha: 0.30),
            glow.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: p, radius: r * 1.25)),
      );
      canvas.drawCircle(
        p,
        r * 0.82,
        Paint()
          ..shader = RadialGradient(colors: [
            hslColor(th.glow, 95, 72),
            hslColor(th.glow, 90, 48),
          ]).createShader(Rect.fromCircle(center: p, radius: r * 0.82)),
      );
      canvas.drawCircle(
        p,
        r * 0.82,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.drawPath(starPath(p, r * 0.5), Paint()..color = const Color(0xFFFFF3C4));
    } else if (n.unlocked) {
      if (current) {
        final pulse = 1 + 0.14 * math.sin(time * 3);
        canvas.drawCircle(
          p,
          r * 1.6 * pulse,
          Paint()
            ..shader = RadialGradient(colors: [
              NeonPalette.cyan.withValues(alpha: 0.34),
              NeonPalette.cyan.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: p, radius: r * 1.6 * pulse)),
        );
        // oyuncu işareti: kuyruklu yıldız (sen buradasın)
        final tail = Path()
          ..moveTo(p.dx - r * 1.9, p.dy + r * 1.9)
          ..quadraticBezierTo(p.dx - r * 0.6, p.dy + r * 0.9, p.dx, p.dy);
        canvas.drawPath(
          tail,
          Paint()
            ..color = NeonPalette.cyan.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      // iç gradyan madalyon
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            hslColor(th.glow, 60, 22),
            const Color(0xE60E0E1C),
          ]).createShader(Rect.fromCircle(center: p, radius: r)),
      );
      // dönen kıvılcım halkası (6 nokta — canlılık)
      final spin = time * (current ? 1.6 : 0.5) + n.i * 0.7;
      for (var d = 0; d < 6; d++) {
        final a = spin + d / 6 * math.pi * 2;
        final sa = current ? 0.8 : 0.45;
        canvas.drawCircle(
          Offset(p.dx + math.cos(a) * r * 1.22, p.dy + math.sin(a) * r * 1.22),
          1.6,
          Paint()..color = Colors.white.withValues(alpha: sa),
        );
      }
      // çift kontur: yumuşak dış + keskin iç
      canvas.drawCircle(
        p,
        r * 1.1,
        Paint()
          ..color = glow.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
      // PB-037: kenar ışıltısı — kontur üzerinde dönen 2 parıltı burnu
      for (var gIdx = 0; gIdx < 2; gIdx++) {
        final ga = time * 1.8 + gIdx * math.pi + n.i * 0.5;
        final gp = Offset(
            p.dx + math.cos(ga) * r * 1.1, p.dy + math.sin(ga) * r * 1.1);
        canvas.drawCircle(
          gp,
          3.2,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      _paintKindGlyph(canvas, n.def.kind, p, glow);
    } else {
      canvas.drawCircle(p, r * 0.9, Paint()..color = const Color(0xB80B0B16));
      canvas.drawCircle(
        p,
        r * 0.9,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        p,
        r * 0.55,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final lk = Paint()
        ..color = Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: p + const Offset(0, 2), width: 14, height: 11),
            const Radius.circular(3)),
        lk,
      );
      canvas.drawArc(
          Rect.fromCircle(center: p + const Offset(0, -4), radius: 5),
          math.pi,
          math.pi,
          false,
          lk);
    }
    if (n.def.box && session.state.boxes[n.i.toString()] != true) {
      canvas.drawCircle(
        p + Offset(r * 0.8, -r * 0.8),
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
      case GameKind.colorGate:
        // ◐ yarım dolu daire — renk geçidi glifi
        canvas.drawArc(Rect.fromCircle(center: c, radius: u * 0.75), -math.pi / 2,
            math.pi, true, Paint()..color = p.color);
        canvas.drawCircle(c, u * 0.75, p);
      case GameKind.neonClean:
        // ⧉ 2×2 mini ızgara — temizlik glifi
        for (final d in [const Offset(-1, -1), const Offset(1, -1),
          const Offset(-1, 1), const Offset(1, 1)]) {
          canvas.drawRect(
              Rect.fromCenter(
                  center: c + d.scale(u * 0.42, u * 0.42), width: u * 0.6, height: u * 0.6),
              p);
        }
      case GameKind.darkHole:
        // ⬤ içi boş daire + iç nokta — delik glifi
        canvas.drawCircle(c, u * 0.8, p);
        canvas.drawCircle(c, u * 0.22, p);
      case GameKind.hexaMerge:
        // ⬡ altıgen glifi
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final px = c.dx + u * 0.8 * math.cos(a);
          final py = c.dy + u * 0.8 * math.sin(a);
          i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
        }
        path.close();
        canvas.drawPath(path, p);
      case GameKind.pinRoute:
        // ⌇ inen kanal + iki ayrım noktası
        canvas.drawLine(c - Offset(0, u * 0.9), c + Offset(0, u * 0.9), p);
        canvas.drawCircle(c + Offset(-u * 0.55, u * 0.3), u * 0.22, p);
        canvas.drawCircle(c + Offset(u * 0.55, u * 0.3), u * 0.22, p);
      case GameKind.flowLink:
        // ≋ iki bağlı dalga — akış glifi
        canvas.drawArc(Rect.fromLTWH(c.dx - u, c.dy - u * 0.5, u * 2, u), 0, math.pi, false, p);
        canvas.drawArc(Rect.fromLTWH(c.dx - u, c.dy + u * 0.1, u * 2, u), math.pi, math.pi, false, p);
      case GameKind.timeFreeze:
        // ❄ karaltı: altı ışınlı çizgi
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i);
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * u * 0.8, p);
        }
      case GameKind.gravityFlip:
        // ⇅ çift yönlü ok
        canvas.drawLine(c - Offset(0, u * 0.7), c + Offset(0, u * 0.7), p);
        canvas.drawLine(c - Offset(0, u * 0.7), c + Offset(-u * 0.35, -u * 0.35), p);
        canvas.drawLine(c - Offset(0, u * 0.7), c + Offset(u * 0.35, -u * 0.35), p);
        canvas.drawLine(c + Offset(0, u * 0.7), c + Offset(-u * 0.35, u * 0.35), p);
        canvas.drawLine(c + Offset(0, u * 0.7), c + Offset(u * 0.35, u * 0.35), p);
      case GameKind.katamariRoll:
        // ● yuvarlanan top + benekleri
        canvas.drawCircle(c, u * 0.75, p);
        canvas.drawCircle(c + Offset(-u * 0.2, -u * 0.15), u * 0.12, p);
        canvas.drawCircle(c + Offset(u * 0.25, u * 0.2), u * 0.16, p);
    }
  }

  @override
  bool shouldRepaint(covariant JourneyPainter old) => true;
}

/// Bir dünyayı açmak için gereken yıldız (levels.dart kilit kuralıyla aynı).
int requiredStarsFor(int stage) => stage * 10;
