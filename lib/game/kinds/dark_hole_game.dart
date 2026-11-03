/// UZUN KARANLIK — Delik (PB-041, DESIGN-20GAMES #3: Hole).
///
/// Hole.io DNA'sı + renk-eşleme zekâsı (benzersizlik farkı): parmakla sürükle
/// yerine tek dokunuş — delik dokunulan noktaya SÜZÜLEREK gider (C-022).
/// Düşen neon parçaları yut → delik BÜYÜR; yanlış (karanlık) parça → delik
/// KÜÇÜLÜR. Delik yok olacak kadar küçülürse kayıp (kalkan: minimum yarıçapa
/// döner). Hedef: def.target parça yutmak. Yutulan parça spiral çekilir.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Düşen parça — doğru (tema hue) veya karanlık (yanlış).
class Chunk {
  double x, y, vy, r, spin;
  int hue;
  bool dark;
  bool gold;
  // yutulma animasyonu: deliğe spiral çekilme
  bool eaten = false;
  double eatT = 0;
  double eatAngle = 0;
  Chunk(this.x, this.y, this.vy, this.r, this.hue,
      {this.dark = false, this.gold = false}) : spin = 0;
}

class DarkHoleGame implements MiniGame {
  @override
  GameKind get kind => GameKind.darkHole;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  // delik
  double hx = 0, hy = 0, hr = 26;
  double tx = 0, ty = 0; // süzülme hedefi
  static const double minR = 13;
  static const double maxR = 86;

  final List<Chunk> chunks = [];
  double _spawnT = 0;
  final math.Random _rnd = math.Random();

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0, glowPulse = 0;

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
    h = math.max(420, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    if (hx == 0) {
      hx = w / 2;
      hy = h * 0.72;
      tx = hx;
      ty = hy;
    }
  }

  @override
  void start(LevelDef def,
      {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    time = 0;
    flash = 0;
    shake = 0;
    _spawnT = 0;
    chunks.clear();
    hx = w / 2;
    hy = h * 0.72;
    tx = hx;
    ty = hy;
    hr = 26 * scale;
    host.playSound('start');
  }

  /// Dokun → delik o noktaya süzülür (sabit hız; momentum hissi).
  @override
  void onTap(Offset local) {
    if (_over) return;
    tx = local.dx.clamp(hr, w - hr);
    ty = local.dy.clamp(hr * 1.6, h - hr);
  }

  double _speed() => 340 * scale; // süzülme hızı

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);
    glowPulse += dt;

    // delik süzülmesi
    final dx = tx - hx, dy = ty - hy;
    final d = math.sqrt(dx * dx + dy * dy);
    final step = _speed() * dt;
    if (d > 1) {
      final t = math.min(1, step / d);
      hx += dx * t;
      hy += dy * t;
    }

    // doğum: zorlukla hızlanan akış
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnT = math.max(0.34, 0.72 - _def.speed * 0.1) ;
      _spawn();
    }

    // parçalar
    for (var i = chunks.length - 1; i >= 0; i--) {
      final c = chunks[i];
      if (c.eaten) {
        // spiral çekilme: deliğe dönerken küçül
        c.eatT += dt * 3.4;
        c.eatAngle += dt * 9;
        final k = 1 - c.eatT;
        c.x = hx + math.cos(c.eatAngle) * c.r * 2.2 * k;
        c.y = hy + math.sin(c.eatAngle) * c.r * 2.2 * k;
        if (c.eatT >= 1) chunks.removeAt(i);
        continue;
      }
      c.y += c.vy * dt;
      c.spin += dt * 2;

      // yutma: parça merkezi delik içinde
      final ex = c.x - hx, ey = c.y - hy;
      final ed = math.sqrt(ex * ex + ey * ey);
      if (ed < hr - c.r * 0.2) {
        if (c.dark) {
          _shrink(c);
        } else {
          _swallow(c);
        }
        continue;
      }
      // taban: yutulamayan parça kaybolur (ceza yok — seçim oyunu)
      if (c.y > h + c.r) chunks.removeAt(i);
    }
  }

  void _spawn() {
    final darkChance = math.min(0.34, 0.16 + _def.speed * 0.06);
    final isDark = _randBool(darkChance);
    final gold = !isDark && _randBool(0.08);
    final hue = isDark ? 0 : _themeHue();
    final r = (isDark ? 15 : 12 + _rnd.nextDouble() * 9) * scale;
    chunks.add(Chunk(
      _rnd.nextDouble() * (w - 2 * r) + r,
      -r,
      (110 + _rnd.nextDouble() * 90 + _def.speed * 30) * scale,
      r,
      hue,
      dark: isDark,
      gold: gold,
    ));
  }

  bool _randBool(double p) => _rnd.nextDouble() < p;

  int _themeHue() {
    final hues = _def.theme.hues;
    return hues[_rnd.nextInt(hues.length)];
  }

  void _swallow(Chunk c) {
    c.eaten = true;
    c.eatT = 0;
    c.eatAngle = _rnd.nextDouble() * math.pi * 2;
    _score += c.gold ? 2 : 1;
    _combo++;
    if (_combo >= 3) _perfects++;
    hr = math.min(maxR * scale, hr + c.r * 0.055);
    _host?.playSound('coin', combo: _combo);
    _host?.haptic(c.gold ? 12 : 6);
    if (_def.target > 0 && _score >= _def.target) {
      _win();
    }
  }

  void _shrink(Chunk c) {
    c.eaten = true;
    c.eatT = 0;
    c.eatAngle = _rnd.nextDouble() * math.pi * 2;
    hr -= c.r * 0.14;
    _combo = 0;
    flash = 0.22;
    shake = 12;
    if (hr < minR * scale) {
      if (_shields > 0) {
        _shields--;
        hr = minR * scale * 1.6;
        _host?.playSound('shield');
        _host?.haptic(25);
        return;
      }
      _over = true;
      _host?.playSound('lose');
      _host?.haptic(50);
      _host?.onEvent('lose', data: {'points': _score});
    } else {
      _host?.playSound('shield');
      _host?.haptic(15);
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
    // derinlik yıldızları
    for (var i = 0; i < 22; i++) {
      final sx = (i * 89.7) % w;
      final sy = (i * 61.3 + time * 22) % h;
      canvas.drawCircle(Offset(sx, sy), 0.9,
          Paint()..color = Colors.white.withValues(alpha: .12));
    }

    // parçalar (yutulanlar deliğin ALTINDA çizilir — spiral içeri)
    for (final c in chunks) {
      _drawChunk(canvas, c);
    }

    // delik: siyah çekirdek + neon rim (combo'da renk ısıması)
    final rimHue = (_def.theme.glow + _combo * 14) % 360;
    final rim = _hsl(rimHue.toDouble(), 95, 60);
    final pulse = 1 + 0.05 * math.sin(glowPulse * 5);
    // dış hale
    canvas.drawCircle(Offset(hx, hy), hr * 1.35 * pulse,
        Paint()..color = rim.withValues(alpha: .12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    // rim halkası
    canvas.drawCircle(
      Offset(hx, hy),
      hr * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..shader = SweepGradient(
          colors: [
            rim,
            _hsl(((rimHue + 60) % 360).toDouble(), 95, 62),
            rim,
          ],
        ).createShader(Rect.fromCircle(center: Offset(hx, hy), radius: hr)),
    );
    // çekirdek: boşluk
    canvas.drawCircle(
        Offset(hx, hy), hr, Paint()..color = const Color(0xFF020206));
    // iç derinlik spirali
    canvas.drawArc(
      Rect.fromCircle(center: Offset(hx, hy), radius: hr * 0.72),
      glowPulse * 2,
      math.pi * 1.2,
      false,
      Paint()
        ..color = rim.withValues(alpha: .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // hedef süzülme işaretçisi (dokunulan noktaya soluk halka)
    final dd = (tx - hx).abs() + (ty - hy).abs();
    if (dd > 6) {
      canvas.drawCircle(
        Offset(tx, ty),
        10 * scale,
        Paint()
          ..color = Colors.white.withValues(alpha: .25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // flaş
    if (flash > 0) {
      canvas.drawRect(
          bgRect, Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }

  void _drawChunk(Canvas canvas, Chunk c) {
    final alpha = c.eaten ? (1 - c.eatT).clamp(0.0, 1.0) : 1.0;
    final col = c.dark
        ? const Color(0xFF1b1b26)
        : (c.gold ? const Color(0xFFFFD54A) : _hsl(c.hue.toDouble(), 90, 60));
    final rect = Rect.fromCenter(
        center: Offset(c.x, c.y),
        width: c.r * 2 * (c.eaten ? 1 - c.eatT * 0.7 : 1),
        height: c.r * 2 * (c.eaten ? 1 - c.eatT * 0.7 : 1));
    // neon rim
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(c.r * 0.45)),
      Paint()
        ..color = c.dark
            ? Colors.white.withValues(alpha: .18 * alpha)
            : col.withValues(alpha: .9 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = c.dark ? 1 : 2,
    );
    // dolgu
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(c.r * 0.45)),
      Paint()..color = col.withValues(alpha: (c.dark ? .55 : .38) * alpha),
    );
    if (c.gold && !c.eaten) {
      canvas.drawCircle(
          Offset(c.x, c.y), c.r * 0.3,
          Paint()
            ..color = Colors.white.withValues(alpha: .8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
