/// YANKI — Echo (PB-045, DESIGN-20GAMES #19: Echo klonu).
///
/// Zaman-oyunu tek dokunuş uyarlaması: 6 neon hücre bir DİZİ yankılanır
/// (her tur +1); oyuncu diziyi YANKILAR. Kendi geçmiş dokunuşların soluk
/// hayalet olarak tekrar oynar — "kendinle iş birliği" hissi. Yanlış
/// hücre = kayıp (kalkan: tur tekrarı). Hedef: def.target tur.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Yankı hücresi.
class EchoCell {
  final int hue;
  double lit; // 0..1 parıltı
  EchoCell(this.hue) : lit = 0;
}

/// Oynayan hayalet adım (geçmiş dokunuşların yankısı).
class EchoGhost {
  final int cell;
  double life;
  EchoGhost(this.cell) : life = 0;
}

enum EchoPhase { showing, waiting }

class EchoGame implements MiniGame {
  @override
  GameKind get kind => GameKind.echo;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  final List<EchoCell> cells = [];
  final List<int> sequence = [];
  final List<EchoGhost> ghosts = [];
  EchoPhase phase = EchoPhase.showing;
  int showIdx = 0;
  double showT = 0;
  int inputIdx = 0;
  int round = 0;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0;
  final math.Random _rnd = math.Random();

  // geometri — 3×2 hücre ızgarası
  double get boardX => 30 * scale;
  double get boardY => 130 * scale;
  double get cellW => (w - 60 * scale) / 3;
  double get cellH => (h - 380 * scale) / 2;

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
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    time = 0;
    flash = 0;
    shake = 0;
    round = 0;
    cells.clear();
    for (var i = 0; i < 6; i++) {
      cells.add(EchoCell((i * 57 + 8) % 360));
    }
    sequence.clear();
    ghosts.clear();
    _nextRound();
    host.playSound('start');
  }

  void _nextRound() {
    round++;
    sequence.add(_rnd.nextInt(6));
    phase = EchoPhase.showing;
    showIdx = 0;
    showT = 0;
    inputIdx = 0;
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);
    for (final c in cells) {
      c.lit = math.max(0, c.lit - dt * 3);
    }
    for (var i = ghosts.length - 1; i >= 0; i--) {
      ghosts[i].life += dt;
      if (ghosts[i].life > 0.5) ghosts.removeAt(i);
    }

    if (phase == EchoPhase.showing) {
      showT += dt;
      final speed = math.max(0.32, 0.6 - _def.speed * 0.06);
      if (showT > speed) {
        showT = 0;
        if (showIdx > 0) {
          cells[sequence[showIdx - 1]].lit = 0; // söndür
        }
        if (showIdx < sequence.length) {
          cells[sequence[showIdx]].lit = 1;
          _host?.playSound('sort_flow', combo: showIdx + 1);
          showIdx++;
        } else {
          cells[sequence.last].lit = 0;
          phase = EchoPhase.waiting;
          _host?.playSound('mystery');
        }
      }
    }
  }

  @override
  void onTap(Offset local) {
    if (_over || phase != EchoPhase.waiting) return;
    final c = _cellAt(local);
    if (c == null) return;
    ghosts.add(EchoGhost(c));
    cells[c].lit = 1;
    if (c == sequence[inputIdx]) {
      inputIdx++;
      _host?.playSound('coin', combo: inputIdx);
      _host?.haptic(6);
      if (inputIdx >= sequence.length) {
        // tur tamam
        _score += sequence.length;
        _combo++;
        if (sequence.length >= 4) _perfects++;
        _host?.playSound('perfect', combo: _combo);
        _host?.haptic(14);
        flash = 0.16;
        if (_def.target > 0 && _score >= _def.target) {
          _win();
          return;
        }
        _nextRound();
      }
    } else {
      // yanlış yankı
      if (_shields > 0) {
        _shields--;
        inputIdx = 0;
        phase = EchoPhase.showing;
        showIdx = 0;
        showT = 0;
        shake = 14;
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
  }

  int? _cellAt(Offset local) {
    for (var r = 0; r < 2; r++) {
      for (var cIdx = 0; cIdx < 3; cIdx++) {
        final rect = Rect.fromLTWH(boardX + cIdx * cellW, boardY + r * cellH,
            cellW - 8 * scale, cellH - 8 * scale);
        if (rect.contains(local)) return r * 3 + cIdx;
      }
    }
    return null;
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
  int get roundForTest => round;

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

    // faz yazısı (L1)
    final phaseText = phase == EchoPhase.showing ? 'DİNLE...' : 'YANKILA!';
    final tp = TextPainter(
      text: TextSpan(
          text: phaseText,
          style: TextStyle(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: phase == EchoPhase.showing
                  ? Colors.white.withValues(alpha: .7)
                  : const Color(0xFFB9FFC9))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, boardY - 60 * scale));

    // hayalet yankılar — geçmiş dokunuşların silüeti
    for (final g in ghosts) {
      final a = (1 - g.life / 0.5) * .3;
      final r = g.cell ~/ 3, cIdx = g.cell % 3;
      final rect = Rect.fromLTWH(boardX + cIdx * cellW + 14 * scale,
          boardY + r * cellH + 14 * scale, cellW - 36 * scale,
          cellH - 36 * scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(12 * scale)),
        Paint()
          ..color = Colors.white.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // hücreler
    for (var i = 0; i < 6; i++) {
      final r = i ~/ 3, cIdx = i % 3;
      final rect = Rect.fromLTWH(boardX + cIdx * cellW, boardY + r * cellH,
          cellW - 8 * scale, cellH - 8 * scale);
      final hue = cells[i].hue.toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(14 * scale)),
        Paint()
          ..color = _hsl(hue, 70, 30).withValues(alpha: .75),
      );
      if (cells[i].lit > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(4), Radius.circular(16 * scale)),
          Paint()
            ..color =
                _hsl(hue, 95, 68).withValues(alpha: cells[i].lit * .9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(14 * scale)),
          Paint()
            ..color = _hsl(hue, 95, 72).withValues(alpha: cells[i].lit),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(14 * scale)),
        Paint()
          ..color = Colors.white.withValues(alpha: .25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // tur göstergesi: dizideki taşlar
    for (var i = 0; i < sequence.length; i++) {
      final done = phase == EchoPhase.waiting || i < inputIdx;
      canvas.drawCircle(
          Offset(w / 2 - (sequence.length - 1) * 9 * scale + i * 18 * scale,
              boardY + 2 * cellH + 24 * scale),
          4.4 * scale,
          Paint()
            ..color = done
                ? _hsl(cells[sequence[i]].hue.toDouble(), 95, 65)
                : Colors.white.withValues(alpha: .2));
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
