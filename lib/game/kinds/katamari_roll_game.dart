/// KATAMARİ ROLL — Büyüme (PB-043, DESIGN-20GAMES #11: Katamari).
///
/// Katamari/Agar DNA'sı tek dokunuşla: top yuvarlanır; DOKUNDUĞUN YARIM
/// (sol/sağ) yöne hız kazanır. Kendinden KÜÇÜK blokları yut → BÜYÜR ve
/// skor; BÜYÜK bloğa dokunmak ölümcül (kalkan: sekme + dokunulmazlık).
/// Arena ekrandan geniş — kamera topu takip eder. Hedef: def.target yutma.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Arena bloğu — 1..5 boyut; top boyundan küçükse yutulur.
class RollBlock {
  double x, y;
  final int size;
  final int hue;
  double wob;
  RollBlock(this.x, this.y, this.size, this.hue) : wob = 0;
}

class KatamariRollGame implements MiniGame {
  @override
  GameKind get kind => GameKind.katamariRoll;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  // top
  double x = 0, y = 0, vx = 0;
  double ballR = 14;
  int facing = 1; // 1 sağ, -1 sol (yuvarlanma yönü görseli)
  double rollA = 0;

  // arena
  double arenaW = 0;
  double camX = 0;

  final List<RollBlock> blocks = [];
  final List<RollPop> pops = [];

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1, _eaten = 0;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0, invuln = 0;
  final math.Random _rnd = math.Random();

  int get ballSize => 1 + (_eaten / 4).floor().clamp(0, 4);

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
    arenaW = w * 2.6;
    ballR = (14 + _eaten * 1.1) * scale;
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
    _eaten = 0;
    _over = false;
    _reached = false;
    time = 0;
    flash = 0;
    shake = 0;
    invuln = 0.8;
    x = arenaW / 2;
    y = h * 0.68;
    vx = 0;
    facing = 1;
    camX = 0;
    blocks.clear();
    pops.clear();
    _seedBlocks(math.max(4, def.target + 6));
    resize(w, h);
    host.playSound('start');
  }

  void _seedBlocks(int n) {
    while (blocks.length < n) {
      final sz = 1 + _rnd.nextInt(math.min(5, ballSize + 2));
      blocks.add(RollBlock(
        40 + _rnd.nextDouble() * (arenaW - 80),
        h * 0.35 + _rnd.nextDouble() * h * 0.45,
        sz,
        _def.theme.hues[_rnd.nextInt(_def.theme.hues.length)],
      ));
    }
  }

  /// Dokun: sol yarı → sola yuvarlan, sağ yarı → sağa.
  @override
  void onTap(Offset local) {
    if (_over) return;
    final dir = local.dx < w / 2 ? -1 : 1;
    facing = dir;
    vx += dir * 190 * scale;
    vx = vx.clamp(-420 * scale, 420 * scale);
    _host?.haptic(4);
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);
    invuln = math.max(0, invuln - dt);

    // sürtünme + hareket
    vx *= math.pow(0.16, dt).toDouble();
    x += vx * dt;
    rollA += vx * dt / math.max(6, ballR);
    x = x.clamp(ballR, arenaW - ballR);
    // kamera takibi
    camX = (x - w * 0.42).clamp(0.0, arenaW - w);

    // blok etkileşimi
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      b.wob += dt * 3;
      final br = 8.0 + b.size * 5.5 * scale;
      final d = math.sqrt((b.x - x) * (b.x - x) + (b.y - y) * (b.y - y));
      if (d < br + ballR) {
        if (b.size <= ballSize) {
          // YUT
          blocks.removeAt(i);
          _eaten++;
          _score += b.size <= ballSize - 1 ? 2 : 1; // küçüğü ezme bonusu
          _combo++;
          if (_combo >= 5) _perfects++;
          resize(w, h); // büyüme
          pops.add(RollPop(b.x, b.y, '+${b.size <= ballSize - 1 ? 2 : 1}'));
          _host?.playSound('coin', combo: _combo);
          _host?.haptic(7);
          if (_def.target > 0 && _score >= _def.target) {
            _win();
            return;
          }
        } else if (invuln <= 0) {
          _hit();
          return;
        }
      }
    }
    // nüfus: yenen blokların yerine yenileri doğar (akış sürer)
    _seedBlocks(math.max(4, _def.target + 6));

    for (var i = pops.length - 1; i >= 0; i--) {
      pops[i].life += dt;
      pops[i].y -= 40 * dt;
      if (pops[i].life > 0.8) pops.removeAt(i);
    }
  }

  void _hit() {
    if (_shields > 0) {
      _shields--;
      invuln = 1.3;
      // sekme: bloğun ters yönüne
      vx = -facing * 260 * scale;
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

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  /// Test kancaları.
  void setShieldsForTest(int n) => _shields = n;
  int get eatenForTest => _eaten;

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
    canvas.translate(-camX, 0);

    // arena kenar hatları
    final edge = Paint()
      ..color = _hsl(theme.glow.toDouble(), 90, 60).withValues(alpha: .5)
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(0, h * 0.2), Offset(0, h), edge);
    canvas.drawLine(Offset(arenaW, h * 0.2), Offset(arenaW, h), edge);

    // bloklar — yuvarlana yuvarlana bekleyen küpler
    for (final b in blocks) {
      final br = 8.0 + b.size * 5.5 * scale;
      final wobble = math.sin(b.wob) * 0.06;
      canvas.save();
      canvas.translate(b.x, b.y);
      canvas.rotate(wobble);
      final rect = Rect.fromCenter(center: Offset.zero, width: br * 2, height: br * 2);
      final big = b.size > ballSize;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(br * 0.3)),
        Paint()
          ..color = big
              ? Colors.redAccent.withValues(alpha: .5)
              : _hsl(b.hue.toDouble(), 85, 55).withValues(alpha: .8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(br * 0.3)),
        Paint()
          ..color = big
              ? Colors.white.withValues(alpha: .75)
              : Colors.white.withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = big ? 1.8 : 1,
      );
      canvas.restore();
    }

    // top — büyüme katmanları (yutulanlar gövdeye katılır)
    final bc = Offset(x, y);
    canvas.drawCircle(
        bc,
        ballR * 1.5,
        Paint()
          ..color = _hsl(theme.glow.toDouble(), 90, 60).withValues(alpha: .14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: const [Color(0xFFFFFFFF), Color(0xFF7FD4C8)],
      ).createShader(Rect.fromCircle(center: bc, radius: ballR));
    canvas.drawCircle(bc, ballR, paint);
    // yüzey yapıları: yutulan blok sayısına göre benekler
    for (var i = 0; i < math.min(_eaten, 12); i++) {
      final a = i * 2.399963 + rollA; // altın açı + yuvarlanma
      final rr = ballR * (0.45 + 0.4 * ((i * 37) % 10) / 10);
      canvas.drawCircle(
          bc + Offset(math.cos(a) * rr, math.sin(a) * rr),
          ballR * 0.14,
          Paint()..color = Colors.white.withValues(alpha: .3));
    }
    if (invuln > 0) {
      canvas.drawCircle(
          bc,
          ballR * 1.6,
          Paint()
            ..color = Colors.white.withValues(alpha: .3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // puan pop'ları
    for (final pop in pops) {
      final a = (1 - pop.life / 0.8).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
            text: pop.text,
            style: TextStyle(
                fontSize: 15 * scale,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: a))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pop.x - tp.width / 2, pop.y));
    }

    canvas.restore();
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }
}

class RollPop {
  double x, y, life;
  final String text;
  RollPop(this.x, this.y, this.text) : life = 0;
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
