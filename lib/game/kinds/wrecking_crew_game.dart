/// YIKIM EKİBİ — Kule Yıkma (PB-044, DESIGN-20GAMES #16: Smash).
///
/// Angry Birds yıkım DNA'sı + nişan-zamanlaması: dönme nişanı hedefe gelince
/// DOKUN — gülle balistik uçar, kuleye çarpar; üstteki bloklar TAKLA ATARAK
/// dökülür (basitleştirilmiş bağlantı fiziği). Sınırlı gülle (3). Skor =
/// dökülen blok. Hedef: def.target blok. Gülleler biterse kayıp.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Kule bloğu — sağlamlık, takla durumu.
class TowerBlock {
  double x, y, w, h;
  final int hue;
  bool toppled = false;
  double vx = 0, vy = 0, rot = 0, vr = 0, life = 0;
  TowerBlock(this.x, this.y, this.w, this.h, this.hue);
}

/// Uçan gülle.
class WreckBall {
  double x, y, vx, vy;
  bool alive = true;
  WreckBall(this.x, this.y, this.vx, this.vy);
}

/// Toz bulutu.
class WreckDust {
  double x, y, life, r;
  WreckDust(this.x, this.y, this.r) : life = 0;
}

class WreckingCrewGame implements MiniGame {
  @override
  GameKind get kind => GameKind.wreckingCrew;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  final List<TowerBlock> blocks = [];
  WreckBall? ball;
  final List<WreckDust> dusts = [];

  double aimAngle = 0; // döner nişan (radyan)
  double aimDir = 1;
  int shots = 3;
  int toppled = 0;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0;
  final math.Random _rnd = math.Random();

  static const int maxShots = 3;
  double get groundY => h * 0.86;

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
    shots = maxShots;
    toppled = 0;
    ball = null;
    dusts.clear();
    aimAngle = -0.9; // sağ-yukarıya bakar
    aimDir = 1;
    _buildTower(math.max(4, def.target + 3));
    host.playSound('start');
  }

  /// Prosedürel kule: taban geniş, yukarı daralır (mimari çeşitlilik).
  void _buildTower(int n) {
    blocks.clear();
    final towerX = w * 0.68;
    final bw = 34 * scale;
    var row = 0;
    var inRow = math.max(2, (n / 3).ceil());
    var placed = 0;
    while (placed < n) {
      for (var i = 0; i < inRow && placed < n; i++) {
        final x = towerX - (inRow * bw) / 2 + i * bw + bw / 2;
        final y = groundY - (row + 1) * bw + bw / 2;
        blocks.add(TowerBlock(x, y, bw - 2, bw - 2,
            _def.theme.hues[(row + i) % _def.theme.hues.length]));
        placed++;
      }
      row++;
      inRow = math.max(1, inRow - 1);
    }
  }

  @override
  void onTap(Offset local) {
    if (_over || ball != null || shots <= 0) return;
    shots--;
    // fırlat: sol-alt köşeden nişan açısıyla
    const speed = 900.0;
    ball = WreckBall(
        w * 0.1, groundY - 20 * scale,
        math.cos(aimAngle) * speed * scale,
        -math.sin(aimAngle).abs() * speed * scale);
    _host?.playSound('place');
    _host?.haptic(6);
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);

    // nişan salınımı (gülle yokken)
    if (ball == null && shots > 0) {
      aimAngle += aimDir * dt * (0.9 + _def.speed * 0.25);
      if (aimAngle > 1.35) {
        aimAngle = 1.35;
        aimDir = -1;
      } else if (aimAngle < 0.15) {
        aimAngle = 0.15;
        aimDir = 1;
      }
    }

    // gülle balistiği + çarpışma
    final b = ball;
    if (b != null) {
      b.vy += 1500 * scale * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      // blok çarpışması
      for (final blk in blocks) {
        if (blk.toppled) continue;
        if (b.x > blk.x - blk.w / 2 &&
            b.x < blk.x + blk.w / 2 &&
            b.y > blk.y - blk.h / 2 &&
            b.y < blk.y + blk.h / 2) {
          _topple(blk);
          break;
        }
      }
      if (b.y > groundY + 40 || b.x > w + 60 || b.x < -60) {
        ball = null;
        _checkShots();
      }
    }

    // takla eden bloklar
    for (final blk in blocks) {
      if (!blk.toppled) continue;
      blk.life += dt;
      blk.vy += 1300 * scale * dt;
      blk.x += blk.vx * dt;
      blk.y += blk.vy * dt;
      blk.rot += blk.vr * dt;
      // yere çarpma: toz + sekme sönümü
      if (blk.y > groundY - blk.h / 2) {
        if (blk.vy > 120) {
          dusts.add(WreckDust(blk.x, groundY, 10 + _rnd.nextDouble() * 14));
          _host?.haptic(4);
        }
        blk.y = groundY - blk.h / 2;
        blk.vy = -blk.vy * 0.3;
        blk.vx *= 0.7;
        blk.vr *= 0.7;
      }
    }

    for (var i = dusts.length - 1; i >= 0; i--) {
      dusts[i].life += dt;
      if (dusts[i].life > 0.7) dusts.removeAt(i);
    }
  }

  /// Blok dökülür + zincir: üstündeki desteklenen bloklar da devrilir.
  void _topple(TowerBlock hit) {
    hit.toppled = true;
    hit.vx = 120 + _rnd.nextDouble() * 160;
    hit.vy = -260 * scale;
    hit.vr = (_rnd.nextBool() ? 1 : -1) * (4 + _rnd.nextDouble() * 5);
    toppled++;
    _score++;
    _combo++;
    if (_combo >= 3) _perfects++;
    shake = 20;
    flash = 0.16;
    _host?.playSound('crit');
    _host?.haptic(16);
    // zincir: dik duran ve hit'in ÜSTÜNDE olan bloklar dengesizleşir
    for (final other in blocks) {
      if (other.toppled || identical(other, hit)) continue;
      final above = other.y < hit.y &&
          (other.x - hit.x).abs() < hit.w * 0.9;
      if (above && _rnd.nextDouble() < 0.75) {
        other.toppled = true;
        other.vx = hit.vx * (0.6 + _rnd.nextDouble() * 0.8);
        other.vy = -200 * scale;
        other.vr = (_rnd.nextBool() ? 1 : -1) * 5;
        toppled++;
        _score++;
        if (_def.target > 0 && _score >= _def.target) {
          _win();
          return;
        }
      }
    }
    ball = null;
    if (_def.target > 0 && _score >= _def.target) {
      _win();
      return;
    }
    _checkShots();
  }

  void _checkShots() {
    if (shots <= 0 && !_over) {
      // son gülle de bitti: hedefe ulaşılmadıysa kayıp
      if (_def.target > 0 && _score < _def.target) {
        _over = true;
        _combo = 0;
        _host?.playSound('lose');
        _host?.haptic(50);
        _host?.onEvent('lose', data: {'points': _score});
      } else if (_def.target <= 0 || _score >= _def.target) {
        if (_def.target > 0) _win();
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

  /// Test kancaları.
  int get shotsForTest => shots;
  List<TowerBlock> get blocksForTest => blocks;
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

    canvas.save();
    if (shake > 0.2) {
      canvas.translate(
          (_rnd.nextDouble() - 0.5) * shake, (_rnd.nextDouble() - 0.5) * shake);
    }

    // zemin
    canvas.drawRect(
        Rect.fromLTWH(0, groundY, w, h - groundY),
        Paint()
          ..color = Colors.white.withValues(alpha: .05));
    canvas.drawLine(
        Offset(0, groundY),
        Offset(w, groundY),
        Paint()
          ..color = _hsl(theme.glow.toDouble(), 85, 55).withValues(alpha: .6)
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // fırlatma rampası + nişan
    final origin = Offset(w * 0.1, groundY - 20 * scale);
    canvas.drawCircle(
        origin,
        16 * scale,
        Paint()
          ..color = Colors.white.withValues(alpha: .14));
    if (ball == null && shots > 0 && !_over) {
      // nişan çizgisi + öngörü
      final dir = Offset(math.cos(aimAngle), -math.sin(aimAngle).abs());
      for (var i = 1; i <= 7; i++) {
        final t = i * 26 * scale;
        final px = origin.dx + dir.dx * t;
        final py = origin.dy + dir.dy * t + 0.5 * 1500 * scale * 0.0004 * t * t;
        canvas.drawCircle(
            Offset(px, py),
            2.4 * scale * (1 - i / 9),
            Paint()..color = Colors.white.withValues(alpha: .5 - i * 0.05));
      }
    }

    // kule blokları
    for (final blk in blocks) {
      canvas.save();
      canvas.translate(blk.x, blk.y);
      canvas.rotate(blk.rot);
      final rect = Rect.fromCenter(
          center: Offset.zero, width: blk.w, height: blk.h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(4 * scale)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              _hsl(blk.hue.toDouble(), 70, 52).withValues(alpha: blk.toppled ? .5 : .95),
              _hsl(blk.hue.toDouble(), 65, 36).withValues(alpha: blk.toppled ? .4 : .95),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(4 * scale)),
        Paint()
          ..color = Colors.white.withValues(alpha: .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.restore();
    }

    // gülle
    final b = ball;
    if (b != null) {
      canvas.drawCircle(
          Offset(b.x, b.y),
          9 * scale,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: const [Color(0xFFFFF3C4), Color(0xFFE0A83A)],
            ).createShader(Rect.fromCircle(
                center: Offset(b.x, b.y), radius: 9 * scale)));
    }

    // tozlar
    for (final d in dusts) {
      final t = d.life / 0.7;
      canvas.drawCircle(
          Offset(d.x, d.y - t * 14),
          d.r * scale * (0.6 + t),
          Paint()
            ..color = Colors.white.withValues(alpha: (1 - t) * .3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    // gülle sayacı (alt sol): kalan atış noktaları
    for (var i = 0; i < maxShots; i++) {
      canvas.drawCircle(
          Offset(24 * scale + i * 24 * scale, h - 22 * scale),
          6 * scale,
          Paint()
            ..color = i < shots
                ? const Color(0xFFFFD54A)
                : Colors.white.withValues(alpha: .12));
    }

    canvas.restore();
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
