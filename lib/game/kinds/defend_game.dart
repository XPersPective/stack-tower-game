/// DEFEND — Savun (DESIGN-V2 §3.1 tür 9, stop fiili).
/// Dalga çekirdeğe gelir; doğru anda dokun = kalkan halkası dalgayı keser.
/// Erken/geç dokunuş kesiş halkasını boşa yakar (anti-spam bekleme).
/// Hedef: N dalgayı kes; geçen dalga kalkan yakar, kalkan yoksa kayıp.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class DefendWave {
  double x, y, vx, vy;
  DefendWave(this.x, this.y, this.vx, this.vy);
}

class DefendBurst {
  double x, y, life;
  bool perfect;
  DefendBurst(this.x, this.y, {this.perfect = false}) : life = 0;
}

class DefendGame implements MiniGame {
  @override
  GameKind get kind => GameKind.defend;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  final List<DefendWave> waves = [];
  final List<DefendBurst> bursts = [];
  double coreX = 0, coreY = 0, coreR = 34, cutR = 96;
  int blocked = 0, needed = 8;
  double shieldT = 0, cd = 0, spawnT = 0.8, time = 0, spin = 0;
  double shake = 0, flash = 0, shieldFlash = 0;
  double edgeGlow = 0; // imza anı (PB-035 B8): son dalga kenar parıltısı
  int _combo = 0, _perfects = 0, _shields = 1;
  bool _over = false, _reached = false;
  final math.Random _rnd = math.Random();

  @override
  int get score => blocked;
  @override
  int get target => needed;
  @override
  int get combo => _combo;
  @override
  int get shieldsLeft => _shields;
  @override
  bool get isOver => _over;

  /* ---- test kancaları ---- */
  @visibleForTesting
  int get blockedForTest => blocked;
  @visibleForTesting
  void spawnForTest({double? x, double? y, double? speed}) {
    _spawnWave(x: x, y: y, speed: speed);
  }

  @override
  void resize(double vw, double vh) {
    w = math.max(320, vw);
    h = math.max(400, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    coreX = w / 2;
    coreY = h * 0.76;
    coreR = 34 * scale;
    cutR = 96 * scale;
  }

  @override
  void start(LevelDef def, {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    blocked = 0;
    _combo = 0;
    _perfects = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    waves.clear();
    bursts.clear();
    time = 0;
    spin = 0;
    shieldT = 0;
    cd = 0;
    shake = 0;
    flash = 0;
    shieldFlash = 0;
    spawnT = 0.8;
    needed = def.target > 0 ? def.target : 6 + def.stage * 2;
    host.playSound('start');
  }

  void _spawnWave({double? x, double? y, double? speed}) {
    final sx = x ?? coreX + (_rnd.nextDouble() - 0.5) * w * 0.9;
    final sy = y ?? -30.0;
    final dx = coreX - sx, dy = coreY - sy;
    final len = math.max(1, math.sqrt(dx * dx + dy * dy));
    final v = (speed ?? (0.5 + _def.speed * 0.16)) * h; // px/s: ~1.4-2.0 s yolculuk
    waves.add(DefendWave(sx, sy, dx / len * v, dy / len * v));
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    if (cd > 0) return; // anti-spam: bekleme penceresi
    shieldT = 0.18;
    cd = 0.34;
    shieldFlash = 0.35;
    _host?.haptic(6);
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    spin += dt * 0.8;
    shake = math.max(0, shake - dt * 55);
    flash = math.max(0, flash - dt * 3);
    shieldFlash = math.max(0, shieldFlash - dt * 2.4);
    shieldT = math.max(0, shieldT - dt);
    cd = math.max(0, cd - dt);

    // dalga pacing'i: kesilecek sayı hedefe yetecek kadar üretir
    spawnT -= dt;
    // imza anı (PB-035 B8): SON DALGA — kalan ≤ 1 iken yeni dalga doğarsa
    // kenar parıltısı 2 sn açılır (final savunması hissi)
    edgeGlow = math.max(0, edgeGlow - dt);
    if (spawnT <= 0) {
      _spawnWave();
      if (needed - blocked <= 1) edgeGlow = 2.0;
      final base = (0.95 - _def.speed * 0.09).clamp(0.5, 1.1);
      spawnT = base * (0.75 + _rnd.nextDouble() * 0.5);
    }

    for (var i = waves.length - 1; i >= 0; i--) {
      if (_over) break; // bitiş sonrası aynı karede ikinci olay yok
      final wav = waves[i];
      wav.x += wav.vx * dt;
      wav.y += wav.vy * dt;
      final d = math.sqrt(
          (wav.x - coreX) * (wav.x - coreX) + (wav.y - coreY) * (wav.y - coreY));
      if (shieldT > 0 && d <= cutR) {
        // kesildi! — çekirdeğe yakınsa cesur kesiş = mükemmel
        waves.removeAt(i);
        blocked++;
        _combo++;
        final brave = d <= coreR + 30 * scale;
        if (brave) _perfects++;
        bursts.add(DefendBurst(wav.x, wav.y, perfect: brave));
        _host?.playSound(brave ? 'perfect' : 'place', combo: _combo);
        _host?.haptic(brave ? 14 : 9);
        shake = math.min(8, 2 + _combo * 0.5);
        if (blocked >= needed) _win();
        continue;
      }
      if (d <= coreR + 8) {
        waves.removeAt(i);
        _hitCore();
      }
    }

    for (var i = bursts.length - 1; i >= 0; i--) {
      bursts[i].life += dt;
      if (bursts[i].life > 0.5) bursts.removeAt(i);
    }
  }

  void _hitCore() {
    if (_over) return;
    if (_shields > 0) {
      _shields--;
      _combo = 0;
      shake = 16;
      flash = 0.55;
      _host?.playSound('shield');
      _host?.haptic(40);
      _host?.onEvent('shield', data: {'left': _shields});
      return;
    }
    shake = 22;
    flash = 0.8;
    _host?.playSound('lose');
    _host?.haptic(60);
    _over = true;
    _reached = false;
    _host?.onEvent('lose', data: {'points': blocked});
  }

  void _win() {
    if (_over) return;
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': blocked});
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() => MiniGameResult(
        points: blocked,
        perfects: _perfects,
        reached: _reached,
      );

  @override
  void render(Canvas canvas, Size size) {
    final theme = _def.theme;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bg1, theme.bg2],
        ).createShader(Offset.zero & size),
    );
    for (var i = 0; i < 36; i++) {
      final x = ((i * 97.3) % w);
      final y = ((i * 53.7 + time * 18) % h);
      canvas.drawCircle(
          Offset(x, y), 1.1, Paint()..color = Colors.white.withValues(alpha: .2));
    }
    // imza anı: son dalga kenar parıltısı — dört kenardan nabız
    if (edgeGlow > 0) {
      final a = (edgeGlow / 2.0) * (0.55 + 0.45 * math.sin(time * 6)) * 0.4;
      for (final edge in const [0, 1, 2, 3]) {
        final rect = edge == 0
            ? Rect.fromLTWH(0, 0, w, h * 0.16)
            : edge == 1
                ? Rect.fromLTWH(0, h * 0.84, w, h * 0.16)
                : edge == 2
                    ? Rect.fromLTWH(0, 0, w * 0.12, h)
                    : Rect.fromLTWH(w * 0.88, 0, w * 0.12, h);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.center,
              end: edge == 0
                  ? Alignment.topCenter
                  : edge == 1
                      ? Alignment.bottomCenter
                      : edge == 2
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
              colors: [
                const Color(0xFFFF5A6E).withValues(alpha: 0),
                Color(0xFFFF5A6E).withValues(alpha: a.clamp(0.0, 1.0)),
              ],
            ).createShader(rect),
        );
      }
    }

    canvas.save();
    if (shake > 0.2) {
      canvas.translate(
          (_rnd.nextDouble() - 0.5) * shake, (_rnd.nextDouble() - 0.5) * shake);
    }

    // kesiş halkası (kalkan bölgesi göstergesi) — kalkan aktifken parlar
    final ringA = 0.14 + (shieldT > 0 ? 0.5 : 0) + shieldFlash * 0.6;
    canvas.drawCircle(
        Offset(coreX, coreY), cutR,
        Paint()
          ..color = const Color(0xFF46E6FF).withValues(alpha: ringA.clamp(0, .95))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 + (shieldT > 0 ? 2 : 0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));

    // çekirdek kristali (dönen elmas)
    canvas.save();
    canvas.translate(coreX, coreY);
    canvas.rotate(spin);
    final crystal = Path()
      ..moveTo(0, -coreR)
      ..lineTo(coreR * 0.72, 0)
      ..lineTo(0, coreR)
      ..lineTo(-coreR * 0.72, 0)
      ..close();
    canvas.drawPath(
        crystal,
        Paint()
          ..shader = LinearGradient(colors: [
            _hslC(theme.glow, 85, 62),
            _hslC(theme.glow, 85, 38),
          ]).createShader(Rect.fromCircle(center: Offset.zero, radius: coreR)));
    canvas.drawPath(
        crystal,
        Paint()
          ..color = _hslA(theme.glow, 100, 82, .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
    canvas.restore();

    // dalgalar (kuyruklu plazma)
    for (final wav in waves) {
      final dx = -wav.vx, dy = -wav.vy;
      final len = math.max(1, math.sqrt(dx * dx + dy * dy));
      final ux = dx / len, uy = dy / len;
      final r = 11 * scale;
      canvas.drawLine(
          Offset(wav.x + ux * 26 * scale, wav.y + uy * 26 * scale),
          Offset(wav.x, wav.y),
          Paint()
            ..color = const Color(0xFFFF5A5A).withValues(alpha: .5)
            ..strokeWidth = 4 * scale
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(
          Offset(wav.x, wav.y), r * 1.7,
          Paint()
            ..color = const Color(0xFFFF5A5A).withValues(alpha: .22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawCircle(Offset(wav.x, wav.y), r,
          Paint()..color = const Color(0xFFFF8A8A));
    }

    // kesilme patlamaları
    for (final b in bursts) {
      final t = b.life / 0.5;
      canvas.drawCircle(
          Offset(b.x, b.y), 8 + t * 52 * scale,
          Paint()
            ..color = (b.perfect ? const Color(0xFFFFD24A) : const Color(0xFF7CFFB2))
                .withValues(alpha: (1 - t) * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - t) + 1);
    }
    canvas.restore();

    if (flash > 0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFFFF3B3B).withValues(alpha: flash * 0.35));
    }
  }
}

Color _hslC(int hue, int s, int l) =>
    HSLColor.fromAHSL(1, hue.toDouble(), s / 100, l / 100).toColor();

Color _hslA(int hue, int s, int l, double a) =>
    HSLColor.fromAHSL(a.clamp(0, 1), hue.toDouble(), s / 100, l / 100).toColor();
