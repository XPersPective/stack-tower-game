/// PİN SIRRI — Yönlendirme (PB-042, DESIGN-20GAMES #5: Pull the Pin).
///
/// Pull the Pin DNA'sının deterministik yönlendirme hâli: her pim bir top
/// tutar (ALTIN / KARANLIK); dokununca top düşer ve kavşaklardan geçer —
/// her kavşakta AÇIK olan yöne gider. Altını HUNİYE, karanlığı ÇUKURA
/// yönlendir. Karanlık huniye girerse kayıp (kalkan bir kez saptırır).
/// Kavşaklara dokunmak yönü çevirir (C-022). Hedef: def.target altın.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart' show NeonPalette;
import '../levels.dart';
import '../mini_game.dart';

/// Kavşak — açık yön sol mu sağ mı.
class Junction {
  final int id;
  bool openLeft;
  final Offset pos;
  Junction(this.id, this.pos, {required this.openLeft});
}

/// Pim — cep: çoklu top sırası (true = karanlık).
class Pin {
  final int id;
  final Offset pos;
  final List<bool> queue; // bırakma sırasıyla
  bool used = false;
  Pin(this.id, this.pos, this.queue);
  bool get hasDark => queue.contains(true);
  int get goldCount => queue.where((d) => !d).length;
}

/// Yoldaki top — kavşak zincirinde süzülür.
class Ball {
  final bool dark;
  double progress; // 0..3: pim→J1→J2→terminal
  final List<Offset> path = [];
  Junction? pendingJ;
  Ball(this.dark, Offset pinPos) : progress = 0 {
    path.add(pinPos);
  }
}

class PinRouteGame implements MiniGame {
  @override
  GameKind get kind => GameKind.pinRoute;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  final List<Pin> pins = [];
  final List<Junction> j1s = [];
  final List<Junction> j2s = [];
  final List<Ball> balls = [];
  final List<bool> _pending = []; // sıradaki bırakmalar (true = karanlık)
  double _releaseT = 0;

  Offset funnel = Offset.zero;
  Offset pit = Offset.zero;
  int funnelGold = 0, pitDark = 0, wasted = 0;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false;
  bool _reached = false;
  double time = 0, shake = 0, flash = 0;
  final math.Random _rnd = math.Random();

  @override
  int get score => _score;
  @override
  int get target => _def.target;
  @override
  int get combo => _combo;
  @override
  int get shieldsLeft => _shields;
  @override
  bool get isOver => _over;

  @override
  void resize(double vw, double vh) {
    w = math.max(300, vw);
    h = math.max(480, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
  }

  @override
  void start(LevelDef def,
      {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    pins.clear();
    j1s.clear();
    j2s.clear();
    balls.clear();
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    funnelGold = 0;
    pitDark = 0;
    wasted = 0;
    _pending.clear();
    _releaseT = 0;
    time = 0;
    shake = 0;
    flash = 0;
    _build(def);
    host.playSound('start');
  }

  /// Prosedürel düzen: 3-4 cep → J1 → 2 paylaşılan J2 → huni/çukur.
  /// Her J2'nin bir huni bir de çukur çıkışı var → her altın YÖNLENDİRİLEBİLİR
  /// (çözülebilirlik yasası). Top sayısı hedefi GARANTİ kapsar: altın ≥ hedef.
  void _build(LevelDef def) {
    funnel = Offset(w * 0.28, h * 0.86);
    pit = Offset(w * 0.72, h * 0.86);
    final n = 4;
    final target = math.max(3, def.target);
    // toplam top = hedef + tuzak payı; altın sayısı ≥ hedef garanti
    final total = target + 3 + _rnd.nextInt(3);
    final darks = (total * (0.18 + def.speed * 0.05)).round().clamp(1, total - target);
    final kinds = <bool>[
      ...List.filled(darks, true),
      ...List.filled(total - darks, false),
    ]..shuffle(_rnd);
    final j2Seed = _rnd.nextBool();
    final per = (kinds.length / n).ceil();
    for (var i = 0; i < n; i++) {
      final pinX = w * (0.14 + 0.72 * i / (n - 1));
      final slice = kinds.skip(i * per).take(per).toList();
      pins.add(Pin(i, Offset(pinX, h * 0.12), slice));
      j1s.add(Junction(100 + i, Offset(pinX, h * 0.34),
          openLeft: (i + (j2Seed ? 0 : 1)) % 2 == 0));
    }
    j2s.add(Junction(200, Offset(w * 0.3, h * 0.6), openLeft: j2Seed));
    j2s.add(Junction(201, Offset(w * 0.7, h * 0.6), openLeft: !j2Seed));
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    // kavşak çevirme (en yakın, tolerans 30*scale)
    Junction? best;
    var bestD = 34 * scale;
    for (final j in [...j1s, ...j2s]) {
      final d = (j.pos - local).distance;
      if (d < bestD) {
        bestD = d;
        best = j;
      }
    }
    if (best != null) {
      best.openLeft = !best.openLeft;
      _host?.haptic(4);
      _host?.playSound('pop');
      return;
    }
    // pim çekme → cep sırası bırakma kuyruğuna girer
    for (final p in pins) {
      if (p.used) continue;
      if ((p.pos - local).distance < 36 * scale) {
        p.used = true;
        _pending.addAll(p.queue);
        _releaseT = 0;
        _host?.haptic(6);
        _host?.playSound('place');
        return;
      }
    }
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    shake = math.max(0, shake - dt * 40);
    flash = math.max(0, flash - dt * 3);

    // bırakma kuyruğu: 0.55 s aralıkla sıradaki top yola çıkar
    if (_pending.isNotEmpty) {
      _releaseT -= dt;
      if (_releaseT <= 0) {
        _releaseT = 0.55;
        balls.add(Ball(_pending.removeAt(0), pins.firstWhere((p) => p.used).pos));
      }
    }

    for (var i = balls.length - 1; i >= 0; i--) {
      final b = balls[i];
      b.progress += dt * 1.5;
      final step = b.progress.floor();
      // segment düğümlerini zamanında ekle
      while (b.path.length <= step + 1 && b.path.length < 4) {
        final from = b.path.last;
        if (b.path.length == 1) {
          // pim → en yakın J1'i SEÇ (pimin dikey hattı)
          final j = _j1OfClosest(from);
          b.path.add(j.pos);
        } else if (b.path.length == 2) {
          _extend(b, _jAt(b.path.last), left: _jAt(b.path.last).openLeft);
        } else if (b.path.length == 3) {
          _extend(b, _jAt(b.path.last), left: _jAt(b.path.last).openLeft);
        }
      }
      if (b.progress >= 3) {
        _arrive(b);
        balls.removeAt(i);
      }
    }
  }

  Junction _j1OfClosest(Offset from) {
    Junction best = j1s.first;
    var bestD = double.infinity;
    for (final j in j1s) {
      final d = (j.pos - from).distance;
      if (d < bestD) {
        bestD = d;
        best = j;
      }
    }
    return best;
  }

  Junction _jAt(Offset pos) {
    for (final j in [...j1s, ...j2s]) {
      if ((j.pos - pos).distance < 0.5) return j;
    }
    // pim → J1 seçiminde hiç kavşağa varmadıysa (teorik) en yakını
    return _j1OfClosest(pos);
  }

  /// Kavşaktan çıkış: J1 → paylaşılan J2; J2 → huni/çukur (id 201 aynalı).
  void _extend(Ball b, Junction j, {required bool left}) {
    if (j.id >= 200) {
      final toFunnel = j.id == 200 ? left : !left;
      b.path.add(toFunnel ? funnel : pit);
    } else {
      final even = j.id % 2 == 0;
      b.path.add(j2s[even == left ? 0 : 1].pos);
    }
  }

  void _arrive(Ball b) {
    final dest = b.path.last;
    final isFunnel = (dest - funnel).distance < 1;
    if (b.dark) {
      if (isFunnel) {
        // karanlık huniye!
        if (_shields > 0) {
          _shields--;
          pitDark++;
          _score++;
          flash = 0.3;
          shake = 14;
          _host?.playSound('shield');
          _host?.haptic(25);
        } else {
          _over = true;
          _combo = 0;
          _host?.playSound('lose');
          _host?.haptic(50);
          _host?.onEvent('lose', data: {'points': _score});
        }
        return;
      }
      pitDark++;
      _score++;
      _combo++;
      _host?.playSound('pop');
      _host?.haptic(8);
    } else {
      if (isFunnel) {
        funnelGold++;
        _score += 2;
        _combo++;
        if (_combo >= 3) _perfects++;
        _host?.playSound('coin', combo: _combo);
        _host?.haptic(10);
      } else {
        // altın çukura — israf
        wasted++;
        _combo = 0;
        _host?.playSound('lose');
        _host?.haptic(15);
      }
    }
    if (_def.target > 0 && funnelGold >= _def.target) {
      _win();
      return;
    }
    _checkExhausted();
  }

  void _checkExhausted() {
    if (pins.every((p) => p.used) &&
        balls.isEmpty &&
        _pending.isEmpty &&
        !_over) {
      if (funnelGold < _def.target) {
        _over = true;
        _host?.playSound('lose');
        _host?.haptic(40);
        _host?.onEvent('lose', data: {'points': _score});
      }
    }
  }

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  /// Test kanca: kalkan sayısını doğrudan ayarla.
  void setShieldsForTest(int n) => _shields = n;

  /// Test gözlemcisi: bırakma kuyruğu.
  List<bool> get pendingForTest => _pending;

  @override
  void stop() {}

  @override
  MiniGameResult result() =>
      MiniGameResult(points: _score, perfects: _perfects, reached: _reached);

  /* ----------------------------- render ----------------------------- */

  @override
  void render(Canvas canvas, Size size) {
    // ilk kare resize'tan önce gelebilir — w/h=0 iken çizim NaN üretir
    if (w <= 0 || h <= 0) return;
    final theme = _def.theme;
    final bgRect = Offset.zero & size;
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bg1, theme.bg2],
        ).createShader(bgRect),
    );

    canvas.save();
    if (shake > 0.2) {
      canvas.translate(
          (_rnd.nextDouble() - 0.5) * shake, (_rnd.nextDouble() - 0.5) * shake);
    }

    // kanallar: pim→J1→J2 çizgileri (soluk)
    final linkPaint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final p in pins) {
      final j1 = _j1OfClosest(p.pos);
      canvas.drawLine(p.pos, j1.pos, linkPaint);
      canvas.drawLine(j1.pos, j2s[0].pos, linkPaint);
      canvas.drawLine(j1.pos, j2s[1].pos, linkPaint);
    }
    for (final j2 in j2s) {
      canvas.drawLine(j2.pos, funnel, linkPaint);
      canvas.drawLine(j2.pos, pit, linkPaint);
    }

    // huni + çukur
    _drawWell(canvas, funnel, true);
    _drawWell(canvas, pit, false);

    // kavşaklar — açık yön okuyla elmas
    for (final j in [...j1s, ...j2s]) {
      final col = j.id >= 200 ? NeonPalette.magenta : NeonPalette.cyan;
      canvas.save();
      canvas.translate(j.pos.dx, j.pos.dy);
      canvas.rotate(math.pi / 4);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 14 * scale, height: 14 * scale),
          Paint()
            ..color = col.withValues(alpha: .25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.restore();
      // açık yön göstergesi
      final dx = j.openLeft ? -1.0 : 1.0;
      canvas.drawCircle(j.pos + Offset(dx * 16 * scale, 0), 3.2 * scale,
          Paint()..color = col);
    }

    // pimler + topları
    for (final p in pins) {
      final col = p.hasDark ? const Color(0xFF3A2A55) : const Color(0xFFFFD54A);
      canvas.drawCircle(p.pos, 12 * scale, Paint()..color = col);
      canvas.drawCircle(
          p.pos,
          12 * scale,
          Paint()
            ..color = p.hasDark
                ? Colors.redAccent.withValues(alpha: .7)
                : Colors.white.withValues(alpha: .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
      if (p.used) {
        canvas.drawCircle(p.pos, 12 * scale,
            Paint()..color = Colors.black.withValues(alpha: .5));
      }
      // pim çubuğu
      canvas.drawLine(
          p.pos - Offset(20 * scale, 0),
          p.pos + Offset(20 * scale, 0),
          Paint()
            ..color = p.used ? Colors.white.withValues(alpha: .15) : Colors.white.withValues(alpha: .6)
            ..strokeWidth = 3);
    }

    // yoldaki toplar
    for (final b in balls) {
      final pos = _posAt(b);
      canvas.drawCircle(
          pos,
          10 * scale,
          Paint()
            ..color = b.dark ? const Color(0xFF3A2A55) : const Color(0xFFFFD54A));
      canvas.drawCircle(
          pos,
          10 * scale,
          Paint()
            ..color = b.dark
                ? Colors.redAccent.withValues(alpha: .7)
                : Colors.white.withValues(alpha: .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
    }

    // sayaçlar
    _counter(canvas, funnel + Offset(0, -30 * scale), 'ALTIN $funnelGold',
        const Color(0xFFFFD54A));
    _counter(canvas, pit + Offset(0, -30 * scale), 'ÇUKUR $pitDark',
        NeonPalette.magenta);

    canvas.restore();
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }

  Offset _posAt(Ball b) {
    final seg = b.progress.floor().clamp(0, b.path.length - 2);
    final t = (b.progress - seg).clamp(0.0, 1.0);
    return Offset.lerp(b.path[seg], b.path[seg + 1], t)!;
  }

  void _drawWell(Canvas canvas, Offset c, bool isFunnel) {
    final col = isFunnel ? const Color(0xFFFFD54A) : NeonPalette.magenta;
    final path = Path()
      ..moveTo(c.dx - 34 * scale, c.dy - 46 * scale)
      ..lineTo(c.dx + 34 * scale, c.dy - 46 * scale)
      ..lineTo(c.dx + 16 * scale, c.dy)
      ..lineTo(c.dx - 16 * scale, c.dy)
      ..close();
    canvas.drawPath(
        path, Paint()..color = col.withValues(alpha: .18));
    canvas.drawPath(
        path,
        Paint()
          ..color = col.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawCircle(
        c + Offset(0, 6 * scale),
        7 * scale,
        Paint()
          ..color = col
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  void _counter(Canvas canvas, Offset c, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: 13 * scale,
              fontWeight: FontWeight.w800,
              color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy));
  }
}
