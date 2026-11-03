/// YERÇEKİMİ KAPISI — Yerçekimi Döndür (PB-043, DESIGN-20GAMES #12).
///
/// Gravity Guy DNA'sı tek dokunuş: top KORİDORda sağa koşar; dokununca
/// yerçekimi TERS DÖNER (tavan/zemin arası geçiş); engellere çarpmadan
/// ilerle. Skor = mesafe; duvar dışına düşüş yok (koridor kapalı) —
/// tehlike yalnız engeller. Hız bölümle artar (def.speed). Hedef: def.target.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Koridor engeli — zemin/tavana dikilmiş neon blok ya da ortada sütun.
class Obstacle {
  final double x; // dünya-x
  final double h; // yükseklik
  final bool fromFloor; // zeminden mi tavana mı; null = ortada sütun
  final bool midColumn;
  Obstacle(this.x, this.h, this.fromFloor, {this.midColumn = false});
}

class GravityFlipGame implements MiniGame {
  @override
  GameKind get kind => GameKind.gravityFlip;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  // top (ekran-y): floorY/ceilY arasında zıplar
  double ballY = 0, vy = 0;
  int grav = 1; // 1 aşağı, -1 yukarı
  double ballR = 10;
  double scroll = 0; // dünya-x ilerlemesi
  double speed = 0;
  double ceil = 60, floorPad = 90; // koridor bantları (ekran-uzay)
  final List<Obstacle> obstacles = [];
  final List<FlipTrail> trail = [];
  double nextObstacleX = 0;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  double _airStreak = 0;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0;
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

  double get floorY => h - floorPad;
  double get ceilY => ceil;

  @override
  void resize(double vw, double vh) {
    w = math.max(300, vw);
    h = math.max(420, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    ballR = 10 * scale;
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
    _airStreak = 0;
    time = 0;
    flash = 0;
    shake = 0;
    scroll = 0;
    grav = 1;
    vy = 0;
    ballY = floorY - ballR;
    speed = (170 + def.speed * 55) * scale;
    obstacles.clear();
    trail.clear();
    nextObstacleX = 520; // ilk engel biraz ileride
    host.playSound('start');
  }

  /// Dokun → yerçekimi ters döner.
  @override
  void onTap(Offset local) {
    if (_over) return;
    grav = -grav;
    vy = 0;
    _host?.haptic(5);
    _host?.playSound('pop');
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);

    // ilerleme
    scroll += speed * dt;
    _score = (scroll / 60).floor();
    if (_def.target > 0 && _score >= _def.target) {
      _win();
      return;
    }

    // yerçekimi + bant kenetlemesi (aşımaya kapalı)
    vy += 1500 * scale * grav * dt;
    ballY += vy * dt;
    var riding = false;
    if (grav > 0 && ballY >= floorY - ballR && vy >= 0) {
      ballY = floorY - ballR;
      vy = 0;
      riding = true;
    } else if (grav < 0 && ballY <= ceilY + ballR && vy <= 0) {
      ballY = ceilY + ballR;
      vy = 0;
      riding = true;
    }
    if (riding) {
      if (grav > 0) _airStreak = 0;
    } else {
      _airStreak += dt;
      if (_airStreak > 1.2) _perfects++; // uzun serbest uçuş = ustalık
    }

    // iz
    trail.add(FlipTrail(ballX(), ballY));
    if (trail.length > 18) trail.removeAt(0);

    // engel üretimi
    while (nextObstacleX < scroll + w + 100) {
      final mid = _rnd.nextDouble() < 0.28;
      final hh = mid
          ? (floorY - ceilY) * (0.3 + _rnd.nextDouble() * 0.25)
          : 40 * scale + _rnd.nextDouble() * 60 * scale;
      obstacles.add(Obstacle(
          nextObstacleX, hh, _rnd.nextBool(), midColumn: mid));
      nextObstacleX += 330 * scale + _rnd.nextDouble() * 220 * scale;
    }
    obstacles.removeWhere((o) => o.x < scroll - 60);

    // çarpışma: engel topun dünya-x'inde mi
    final bx = ballX();
    for (final o in obstacles) {
      if ((o.x - bx).abs() > 16 * scale + ballR) continue;
      // blok aralığı (ekran-y)
      double top, bottom;
      if (o.midColumn) {
        final midY = (floorY + ceilY) / 2;
        top = midY - o.h / 2;
        bottom = midY + o.h / 2;
      } else if (o.fromFloor) {
        bottom = floorY;
        top = floorY - o.h;
      } else {
        top = ceilY;
        bottom = ceilY + o.h;
      }
      if (ballY + ballR > top && ballY - ballR < bottom) {
        _hit();
        return;
      }
    }
  }

  double ballX() => w * 0.28;

  void _hit() {
    if (_shields > 0) {
      _shields--;
      invuln = 1.0;
      flash = 0.3;
      shake = 16;
      _combo = 0;
      _host?.playSound('shield');
      _host?.haptic(25);
      return;
    }
    _over = true;
    _combo = 0;
    _host?.playSound('lose');
    _host?.haptic(50);
    _host?.onEvent('lose', data: {'points': _score});
  }

  double invuln = 0;

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  /// Test kancaları.
  void setShieldsForTest(int n) => _shields = n;
  List<Obstacle> get obstaclesForTest => obstacles;
  double get invulnForTest => invuln;
  set invulnForTest(double v) => invuln = v;

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
    // çevirmede kamera hissi: grav'e göre üst/alt ton değişir
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: grav > 0
              ? [theme.bg1, theme.bg2]
              : [theme.bg2, theme.bg1],
        ).createShader(bgRect),
    );

    canvas.save();
    if (shake > 0.2) {
      canvas.translate(
          (_rnd.nextDouble() - 0.5) * shake, (_rnd.nextDouble() - 0.5) * shake);
    }

    // koridor bantları — zemin + tavan neon hatları
    final bandPaint = Paint()
      ..color = _hsl(theme.glow.toDouble(), 90, 58).withValues(alpha: .7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(Rect.fromLTWH(0, ceilY - 3, w, 3), bandPaint);
    canvas.drawRect(Rect.fromLTWH(0, floorY, w, 3), bandPaint);
    // bant içi dolgu
    canvas.drawRect(
        Rect.fromLTWH(0, ceilY - 60 * scale, w, 60 * scale - 3),
        Paint()..color = Colors.white.withValues(alpha: .04));
    canvas.drawRect(
        Rect.fromLTWH(0, floorY + 3, w, 60 * scale),
        Paint()..color = Colors.white.withValues(alpha: .04));

    // hız çizgileri
    for (var i = 0; i < 8; i++) {
      final lx = (w - ((scroll * 1.6 + i * 130) % (w + 60)));
      canvas.drawLine(
          Offset(lx, ceilY + 20 + (i % 4) * 40),
          Offset(lx - 26, ceilY + 20 + (i % 4) * 40),
          Paint()
            ..color = Colors.white.withValues(alpha: .08)
            ..strokeWidth = 1.4);
    }

    // engeller
    for (final o in obstacles) {
      final sx = o.x - scroll;
      if (sx < -80 || sx > w + 80) continue;
      double top, bottom;
      if (o.midColumn) {
        final midY = (floorY + ceilY) / 2;
        top = midY - o.h / 2;
        bottom = midY + o.h / 2;
      } else if (o.fromFloor) {
        bottom = floorY;
        top = floorY - o.h;
      } else {
        top = ceilY;
        bottom = ceilY + o.h;
      }
      final rect = Rect.fromLTWH(sx - 11 * scale, top, 22 * scale, bottom - top);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.redAccent.withValues(alpha: .85),
              Colors.deepOrange.withValues(alpha: .65),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
        Paint()
          ..color = Colors.white.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // iz
    for (var i = 0; i < trail.length; i++) {
      final t = trail[i];
      final a = (i / trail.length) * .4;
      canvas.drawCircle(
          Offset(t.x, t.y),
          ballR * (0.3 + 0.5 * i / trail.length),
          Paint()
            ..color = _hsl(theme.glow.toDouble(), 90, 65).withValues(alpha: a));
    }

    // top — grav'e göre ışık yönlü
    final bc = Offset(ballX(), ballY);
    canvas.drawCircle(
        bc,
        ballR * 2,
        Paint()
          ..color = _hsl(theme.glow.toDouble(), 95, 60).withValues(alpha: .16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(
        bc,
        ballR,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(0.3 * grav, -0.3),
            colors: const [Color(0xFFFFFFFF), Color(0xFF8FD8FF)],
          ).createShader(Rect.fromCircle(center: bc, radius: ballR)));
    if (invuln > 0) {
      canvas.drawCircle(
          bc,
          ballR * 1.7,
          Paint()
            ..color = Colors.white.withValues(alpha: .3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // yerçekimi yön göstergesi — köşe oku (L1)
    final arrowY = grav > 0 ? floorY - 26 * scale : ceilY + 26 * scale;
    final ay = arrowY + (grav > 0 ? -1 : 1) * (time * 30 % 12);
    canvas.drawCircle(
        Offset(w * 0.5, ay),
        3.4 * scale,
        Paint()
          ..color = Colors.white.withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    canvas.restore();
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }
}

class FlipTrail {
  double x, y;
  FlipTrail(this.x, this.y);
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
