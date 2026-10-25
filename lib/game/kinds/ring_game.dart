/// RING — Halka (DESIGN-V2 §3.1 tür 3, release/timing fiili).
/// Tek dokunuş: dönen işaretçiyi hedef dilimde durdur.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class RingHitFx {
  double life;
  bool good;
  RingHitFx(this.good) : life = 0;
}

class RingGame implements MiniGame {
  @override
  GameKind get kind => GameKind.ring;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;
  double angle = 0; // işaretçi açısı
  double spin = 1.6; // rad/s
  int dirSign = 1;
  double targetStart = 0; // hedef dilim başlangıcı
  double targetWidth = 1.0; // rad
  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false, _reached = false;
  double time = 0, shake = 0, flash = 0, hitStop = 0;
  final List<RingHitFx> fxs = [];
  final math.Random _rnd = math.Random();

  /// Test kancaları (üretimde kullanılmaz).
  @visibleForTesting
  double get spinForTest => spin;
  @visibleForTesting
  int get dirSignForTest => dirSign;
  @visibleForTesting
  double get angleForTest => angle;
  @visibleForTesting
  void setTargetForTest(double start, double width) {
    targetStart = start;
    targetWidth = width;
  }

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
    w = math.max(320, vw);
    h = math.max(400, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
  }

  @override
  void start(LevelDef def, {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    time = 0;
    angle = -math.pi / 2;
    spin = 1.4 + def.speed * 0.7;
    dirSign = 1;
    fxs.clear();
    _newTarget();
    host.playSound('start');
  }

  void _newTarget() {
    // hedef dilim: seviye ilerledikçe daralır (1.05 rad → 0.34 rad)
    final shrink = math.min(0.7, _score * 0.045);
    targetWidth = math.max(0.34, 1.05 - shrink);
    targetStart = _rnd.nextDouble() * math.pi * 2;
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    // işaretçi hedef dilimde mi?
    final a = _norm(angle);
    final ts = _norm(targetStart);
    final inTarget = _angleWithin(a, ts, targetWidth);
    if (inTarget) {
      // merkez yakınlığı → mükemmel
      final center = _norm(ts + targetWidth / 2);
      final dist = _angleDist(a, center);
      final perfect = dist <= targetWidth * 0.28;
      _score++;
      _combo++;
      if (perfect) _perfects++;
      fxs.add(RingHitFx(true));
      hitStop = perfect ? 0.07 : 0.045;
      shake = perfect ? 9 : 5;
      _host?.playSound(perfect ? 'perfect' : 'place', combo: _combo);
      _host?.haptic(perfect ? 16 : 9);
      if (perfect && _combo >= 3) _host?.onEvent('crit', data: {'combo': _combo});
      // sonraki tur: yön değişir, hızlanır, yeni hedef
      dirSign = -dirSign;
      spin = math.min(4.6, spin + 0.09);
      _newTarget();
      if (_def.target > 0 && _score >= _def.target) _win();
    } else {
      _combo = 0;
      if (_shields > 0) {
        _shields--;
        fxs.add(RingHitFx(false));
        shake = 14;
        flash = 0.5;
        _host?.playSound('shield');
        _host?.haptic(38);
        _host?.onEvent('shield', data: {'left': _shields});
        dirSign = -dirSign;
        _newTarget();
      } else {
        _lose();
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

  void _lose() {
    _over = true;
    _reached = false;
    shake = 20;
    flash = 0.8;
    _host?.playSound('lose');
    _host?.haptic(60);
    _host?.onEvent('lose', data: {'points': _score});
  }

  @override
  void tick(double dt) {
    if (_over) return;
    var d = dt;
    if (hitStop > 0) {
      final c = math.min(hitStop, dt);
      hitStop -= c;
      d = dt - c;
    }
    time += dt;
    angle = _norm(angle + dirSign * spin * d);
    shake = math.max(0, shake - dt * 55);
    flash = math.max(0, flash - dt * 3);
    for (var i = fxs.length - 1; i >= 0; i--) {
      fxs[i].life += dt;
      if (fxs[i].life > 0.5) fxs.removeAt(i);
    }
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() =>
      MiniGameResult(points: _score, perfects: _perfects, reached: _reached);

  @override
  void render(Canvas canvas, Size size) {
    final theme = _def.theme;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          colors: [theme.bg2, theme.bg1],
        ).createShader(Offset.zero & size),
    );
    final c = Offset(w / 2, h * 0.44);
    final R = math.min(w, h) * 0.32;

    canvas.save();
    if (shake > 0.2) {
      canvas.translate((_rnd.nextDouble() - 0.5) * shake, (_rnd.nextDouble() - 0.5) * shake);
    }

    // dış halka (decor)
    canvas.drawCircle(c, R * 1.22, Paint()
      ..color = hslA(theme.glow, 80, 60, 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);

    // hedef dilim
    final targetPaint = Paint()
      ..color = hslA(theme.glow, 95, 62, 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = R * 0.20;
    canvas.drawArc(Rect.fromCircle(center: c, radius: R), targetStart, targetWidth, false, targetPaint);
    // hedef kenar parıltısı
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: R),
        targetStart,
        targetWidth,
        false,
        Paint()
          ..color = hslA(theme.glow, 100, 78, 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6));

    // merkez çekirdek
    canvas.drawCircle(c, R * 0.16, Paint()..color = hslA(theme.glow, 90, 70, 0.85));
    canvas.drawCircle(c, R * 0.30, Paint()
      ..color = hslA(theme.glow, 90, 70, 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));

    // işaretçi
    final px = c.dx + math.cos(angle) * R;
    final py = c.dy + math.sin(angle) * R;
    canvas.drawLine(c, Offset(px, py), Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 2.2);
    canvas.drawCircle(Offset(px, py), 11 * scale, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(Offset(px, py), 17 * scale, Paint()
      ..color = const Color(0x6646E6FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // isabet efektleri
    for (final fx in fxs) {
      final t = fx.life / 0.5;
      final col = fx.good ? const Color(0xFF7CFFB2) : const Color(0xFFFF5A5A);
      canvas.drawCircle(c, R * (1 + t * 0.6), Paint()
        ..color = col.withValues(alpha: (1 - t) * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - t) + 1);
    }
    canvas.restore();

    if (flash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF3B3B).withValues(alpha: flash * 0.3));
    }
  }

  double _norm(double a) => a % (math.pi * 2);
  bool _angleWithin(double a, double start, double width) {
    final d = _angleDist(a, _norm(start + width / 2));
    return d <= width / 2;
  }

  double _angleDist(double a, double b) {
    var d = (a - b).abs() % (math.pi * 2);
    if (d > math.pi) d = math.pi * 2 - d;
    return d;
  }
}

Color hslA(int hue, int s, int l, double a) =>
    HSLColor.fromAHSL(a, (hue % 360).toDouble(), s / 100, l / 100).toColor();
