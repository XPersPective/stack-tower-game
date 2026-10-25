/// CATCH — Yıldız Avcısı (DESIGN-V2 §3.1 tür 2, dodge/collect fiili).
/// Tek dokunuş: yön değiştir. Düşen yıldızları yakala, bombalardan kaç.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class FallingItem {
  double x, y, vy, r;
  bool bomb;
  bool gold;
  double spin;
  FallingItem(this.x, this.y, this.vy, this.r, {this.bomb = false, this.gold = false})
      : spin = 0;
}

class CatchBurst {
  double x, y;
  double life;
  bool gold;
  CatchBurst(this.x, this.y, {this.gold = false}) : life = 0;
}

class CatcherGame implements MiniGame {
  @override
  GameKind get kind => GameKind.catcher;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;
  double basketX = 0, basketW = 96, basketH = 26;
  int dir = 1;
  final List<FallingItem> items = [];
  final List<CatchBurst> bursts = [];
  double time = 0, spawnTimer = 0;
  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false;
  bool _reached = false;
  double shake = 0, flash = 0, goldFlash = 0;
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
    w = math.max(320, vw);
    h = math.max(400, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    basketW = 96 * scale;
    basketH = 26 * scale;
    if (basketX == 0) basketX = w / 2;
    basketX = basketX.clamp(basketW / 2, w - basketW / 2);
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
    items.clear();
    bursts.clear();
    time = 0;
    spawnTimer = 0;
    dir = 1;
    basketX = w / 2;
    host.playSound('start');
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    // dokun = yön değiştir (tek girdi); ekranın hangi yarısı olduğuna bakılmaz
    dir = -dir;
    _host?.haptic(6);
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    shake = math.max(0, shake - dt * 55);
    flash = math.max(0, flash - dt * 3);
    goldFlash = math.max(0, goldFlash - dt * 3);

    // sepet hareketi
    final speed = 260 * scale * (0.8 + _def.speed * 0.25);
    basketX += dir * speed * dt;
    if (basketX > w - basketW / 2) {
      basketX = w - basketW / 2;
      dir = -1;
    } else if (basketX < basketW / 2) {
      basketX = basketW / 2;
      dir = 1;
    }

    // spawn: hız def.speed ile; bomba oranı seviyeye göre artar
    spawnTimer -= dt;
    if (spawnTimer <= 0) {
      spawnTimer = math.max(0.28, 0.95 - _def.speed * 0.16) * (0.75 + _rnd.nextDouble() * 0.5);
      final bombChance = math.min(0.34, 0.10 + _def.stage * 0.022);
      final isBomb = _rnd.nextDouble() < bombChance;
      final gold = !isBomb && _rnd.nextDouble() < 0.12;
      items.add(FallingItem(
        20 + _rnd.nextDouble() * (w - 40),
        -30,
        (150 + _rnd.nextDouble() * 90 + _def.speed * 55) * scale,
        (isBomb ? 16 : 14) * scale,
        bomb: isBomb,
        gold: gold,
      ));
    }

    // düşenler
    final basketTop = h - 92 * scale;
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      it.y += it.vy * dt;
      it.spin += dt * (it.bomb ? 2.0 : 3.4);
      // yakalama kontrolü
      if (!it.bomb && it.y + it.r >= basketTop && it.y - it.r <= basketTop + basketH) {
        if ((it.x - basketX).abs() <= basketW / 2 + it.r * 0.4) {
          items.removeAt(i);
          _score++;
          _combo++;
          final centered = (it.x - basketX).abs() <= _def.tol * scale * 1.5;
          if (centered) _perfects++;
          bursts.add(CatchBurst(it.x, basketTop, gold: it.gold));
          _host?.playSound(it.gold ? 'coin' : 'perfect', combo: _combo);
          _host?.haptic(it.gold ? 18 : 10);
          if (it.gold) {
            goldFlash = 0.5;
          }
          shake = math.min(8, 2 + _combo * 0.5);
          if (_def.target > 0 && _score >= _def.target) _win();
          continue;
        }
      }
      if (it.bomb && it.y + it.r >= basketTop && it.y - it.r <= basketTop + basketH) {
        if ((it.x - basketX).abs() <= basketW / 2 + it.r * 0.5) {
          items.removeAt(i);
          _hitBomb(it);
          continue;
        }
      }
      if (it.y - it.r > h + 40) {
        // kaçan yıldız komboyu sıfırlar (ceza yok — affedici)
        if (!it.bomb && _combo > 0) _combo = 0;
        items.removeAt(i);
      }
    }

    for (var i = bursts.length - 1; i >= 0; i--) {
      bursts[i].life += dt;
      if (bursts[i].life > 0.55) bursts.removeAt(i);
    }
  }

  void _hitBomb(FallingItem it) {
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
    _host?.onEvent('lose', data: {'points': _score});
  }

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() => MiniGameResult(
        points: _score,
        perfects: _perfects,
        reached: _reached,
        goldBlocks: bursts.where((b) => b.gold).length,
      );

  @override
  void render(Canvas canvas, Size size) {
    final theme = _def.theme;
    // gökyüzü
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bg1, theme.bg2],
        ).createShader(Offset.zero & size),
    );
    // yıldız tozu arka plan
    for (var i = 0; i < 40; i++) {
      final x = ((i * 97.3) % w);
      final y = ((i * 53.7 + time * 12) % h);
      canvas.drawCircle(Offset(x, y), 1.1, Paint()..color = Colors.white.withValues(alpha: .22));
    }

    canvas.save();
    if (shake > 0.2) {
      canvas.translate((_rnd.nextDouble() - 0.5) * shake, (_rnd.nextDouble() - 0.5) * shake);
    }

    // düşenler
    for (final it in items) {
      if (it.bomb) {
        canvas.save();
        canvas.translate(it.x, it.y);
        canvas.rotate(it.spin);
        canvas.drawCircle(Offset.zero, it.r, Paint()..color = const Color(0xFF1a1020));
        canvas.drawCircle(
            Offset.zero, it.r, Paint()
              ..color = const Color(0xFFFF5A5A).withValues(alpha: .85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4);
        canvas.drawLine(Offset(0, -it.r), Offset(0, -it.r - 8 * scale),
            Paint()..color = const Color(0xFFFFC247)..strokeWidth = 2);
        canvas.restore();
      } else {
        final glow = it.gold ? const Color(0xFFFFD24A) : const Color(0xFF9BE8FF);
        canvas.drawCircle(Offset(it.x, it.y), it.r * 1.9,
            Paint()..color = glow.withValues(alpha: .18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        _drawStar(canvas, Offset(it.x, it.y), it.r, glow, it.spin);
      }
    }

    // sepet (neon tekne)
    final basketTop = h - 92 * scale;
    final bp = Path()
      ..moveTo(basketX - basketW / 2, basketTop)
      ..lineTo(basketX + basketW / 2, basketTop)
      ..lineTo(basketX + basketW * 0.34, basketTop + basketH)
      ..lineTo(basketX - basketW * 0.34, basketTop + basketH)
      ..close();
    canvas.drawPath(bp, Paint()..color = const Color(0x3346E6FF));
    canvas.drawPath(
        bp,
        Paint()
          ..color = const Color(0xFF46E6FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
    canvas.drawPath(bp, Paint()
      ..color = const Color(0xFFBFF4FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);

    // yakalama patlamaları
    for (final b in bursts) {
      final t = b.life / 0.55;
      final r = 10 + t * 46 * scale;
      canvas.drawCircle(
        Offset(b.x, b.y),
        r,
        Paint()
          ..color = (b.gold ? const Color(0xFFFFD24A) : const Color(0xFF9BE8FF))
              .withValues(alpha: (1 - t) * 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - t) + 1,
      );
    }
    canvas.restore();

    // flaşlar
    if (flash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF3B3B).withValues(alpha: flash * 0.35));
    }
    if (goldFlash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFD24A).withValues(alpha: goldFlash * 0.22));
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color color, double rot) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = rot + i * math.pi / 4;
      final p = Offset(c.dx + math.cos(a) * rad, c.dy + math.sin(a) * rad);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }
}
