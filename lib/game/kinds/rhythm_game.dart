/// RHYTHM — Ritim (DESIGN-V2 §3.1 tür 10, timing-on-beat fiili).
/// Notalar vuruş çizgisine düşer; doğru anda (pencere içinde) dokun = isabet.
/// Erken/geç dokunuş = ıskalama (kombo sıfır, 3 ıskada kalkan/kayıp).
/// Hedef: N isabet; kombo doruğunda ses merdiveni host'a combo ile iletilir.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class RhythmNote {
  double x, y, vy;
  RhythmNote(this.x, this.y, this.vy);
}

class RhythmBurst {
  double x, y, life;
  bool perfect;
  RhythmBurst(this.x, this.y, {this.perfect = false}) : life = 0;
}

class RhythmGame implements MiniGame {
  @override
  GameKind get kind => GameKind.rhythm;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  final List<RhythmNote> notes = [];
  final List<RhythmBurst> bursts = [];
  double lineY = 0, tolY = 40, noteR = 15;
  int hits = 0, misses = 0, needed = 12;
  double beat = 0.8, beatT = 0, spawnCount = 0;
  double time = 0, shake = 0, flash = 0;
  int _combo = 0, _perfects = 0, _shields = 1;
  bool _over = false, _reached = false;
  final math.Random _rnd = math.Random();

  @override
  int get score => hits;
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
  int get missesForTest => misses;
  @visibleForTesting
  void addNoteForTest({double? x, double? y, double? vy}) {
    notes.add(RhythmNote(
        x ?? w / 2, y ?? lineY, vy ?? ((lineY + 80) / 1.2))); // duran nota
  }

  @override
  void resize(double vw, double vh) {
    w = math.max(320, vw);
    h = math.max(400, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    lineY = h * 0.72;
    tolY = 16 + 24 * scale; // ~40px: okunur pencere
    noteR = 15 * scale;
  }

  @override
  void start(LevelDef def, {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    hits = 0;
    misses = 0;
    _combo = 0;
    _perfects = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    notes.clear();
    bursts.clear();
    time = 0;
    spawnCount = 0;
    shake = 0;
    flash = 0;
    beatT = 0.5;
    beat = (0.92 - def.speed * 0.07).clamp(0.45, 1.0);
    tolY = (16 + def.tol * 1.4) + 18 * scale;
    needed = def.target > 0 ? def.target : 10 + def.stage * 2;
    host.playSound('start');
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    // en yakın vuruş çizgisindeki notayı bul (tek dokunuş — şerit seçimi yok)
    RhythmNote? best;
    var bestD = 1e9;
    for (final n in notes) {
      final d = (n.y - lineY).abs();
      if (d < bestD) {
        bestD = d;
        best = n;
      }
    }
    if (best != null && bestD <= tolY + noteR) {
      notes.remove(best);
      hits++;
      _combo++;
      final perfect = bestD <= tolY * 0.45;
      if (perfect) _perfects++;
      bursts.add(RhythmBurst(best.x, lineY, perfect: perfect));
      _host?.playSound(perfect ? 'perfect' : 'place', combo: _combo);
      _host?.haptic(perfect ? 14 : 9);
      shake = math.min(7, 2 + _combo * 0.4);
      if (hits >= needed) _win();
      return;
    }
    // boş vuruş: ıskalama (spam'i caydırır; affedici — yalnız kombo gider)
    _miss(emptyTap: true);
  }

  void _miss({bool emptyTap = false}) {
    if (_over) return;
    _combo = 0;
    misses++;
    flash = math.max(flash, emptyTap ? 0.18 : 0.3);
    _host?.haptic(5);
    if (misses >= 3) {
      if (_shields > 0) {
        _shields--;
        misses = 0;
        shake = 16;
        flash = 0.55;
        _host?.playSound('shield');
        _host?.haptic(40);
        _host?.onEvent('shield', data: {'left': _shields});
      } else {
        _lose();
      }
    }
  }

  void _lose() {
    if (_over) return;
    _over = true;
    _reached = false;
    shake = 22;
    flash = 0.8;
    _host?.playSound('lose');
    _host?.haptic(60);
    _host?.onEvent('lose', data: {'points': hits});
  }

  void _win() {
    if (_over) return;
    _over = true;
    _reached = true;
    _host?.playSound('win');
    // imza anı (PB-035 B8): final akoru — fanfare + pop üst katmanları
    _host?.playSound('fanfare');
    _host?.playSound('pop');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': hits});
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    shake = math.max(0, shake - dt * 55);
    flash = math.max(0, flash - dt * 3);

    // vuruş saati: notayı ritim aralığında üret; ara sıra nefes vuruşu
    beatT -= dt;
    if (beatT <= 0) {
      final rest = _rnd.nextDouble() < 0.16;
      if (!rest) {
        final lane = ((spawnCount % 3) - 1) * w * 0.26;
        final travel = (1.5 - _def.speed * 0.15).clamp(0.9, 1.6);
        notes.add(RhythmNote(w / 2 + lane + (_rnd.nextDouble() - 0.5) * 14,
            -30, (lineY + 60) / travel));
        spawnCount++;
      }
      beatT = beat * (rest ? 2 : 1);
    }

    for (var i = notes.length - 1; i >= 0; i--) {
      if (_over) break; // bitiş sonrası aynı karede ikinci olay yok
      final n = notes[i];
      n.y += n.vy * dt;
      if (n.y > lineY + tolY + 26 * scale) {
        notes.removeAt(i);
        _miss(); // geçen nota = ıskalama
      }
    }

    for (var i = bursts.length - 1; i >= 0; i--) {
      bursts[i].life += dt;
      if (bursts[i].life > 0.45) bursts.removeAt(i);
    }
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() => MiniGameResult(
        points: hits,
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

    canvas.save();
    if (shake > 0.2) {
      canvas.translate(
          (_rnd.nextDouble() - 0.5) * shake, (_rnd.nextDouble() - 0.5) * shake);
    }

    // şerit kılavuzları
    for (var l = 0; l < 3; l++) {
      final lx = w / 2 + (l - 1) * w * 0.26;
      canvas.drawLine(
          Offset(lx, h * 0.12), Offset(lx, lineY),
          Paint()..color = Colors.white.withValues(alpha: .07)..strokeWidth = 2);
    }

    // vuruş çizgisi — vuruşta nabız atar (C-023: eyleme anında yanıt)
    final pulse = 1.0 - (beatT / beat).clamp(0.0, 1.0);
    final lineA = 0.55 + pulse * 0.4;
    canvas.drawLine(
        Offset(w * 0.1, lineY), Offset(w * 0.9, lineY),
        Paint()
          ..color = _hslA(theme.glow, 100, 70, lineA)
          ..strokeWidth = 3 + pulse * 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
    // isabet penceresi bandı
    canvas.drawRect(
        Rect.fromPoints(
            Offset(w * 0.12, lineY - tolY - noteR), Offset(w * 0.88, lineY + tolY + noteR)),
        Paint()..color = Colors.white.withValues(alpha: .05));

    // notalar (neon küreler)
    for (final n in notes) {
      final near = (n.y - lineY).abs() <= tolY + noteR;
      canvas.drawCircle(
          Offset(n.x, n.y), noteR * 1.8,
          Paint()
            ..color = _hslA(theme.glow, 95, 65, near ? .34 : .18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(
          Offset(n.x, n.y), noteR,
          Paint()
            ..color = near ? Colors.white : _hslC(theme.glow, 90, 68)
            ..style = near ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 2.2);
    }

    // isabet patlamaları
    for (final b in bursts) {
      final t = b.life / 0.45;
      canvas.drawCircle(
          Offset(b.x, b.y), 6 + t * 44 * scale,
          Paint()
            ..color = (b.perfect ? const Color(0xFFFFD24A) : const Color(0xFF7CFFB2))
                .withValues(alpha: (1 - t) * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - t) + 1);
    }
    canvas.restore();

    if (flash > 0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFFFF3B3B).withValues(alpha: flash * 0.3));
    }
  }
}

Color _hslC(int hue, int s, int l) =>
    HSLColor.fromAHSL(1, hue.toDouble(), s / 100, l / 100).toColor();

Color _hslA(int hue, int s, int l, double a) =>
    HSLColor.fromAHSL(a.clamp(0, 1), hue.toDouble(), s / 100, l / 100).toColor();
