/// AYNA İKİZ — Mirror (PB-045, DESIGN-20GAMES #8: Ayna simetrisi).
///
/// İki ikiz AYNA-simetrik yürür: sol yarıya dokun → ikisi SOLA adım
/// (ikiz tersine); sağ yarıya dokun → ikisi SAĞA (ikiz tersine). Çukurlar
/// asimetrik — adım sayısı ORTAK olduğu için ikisini de güvende tutan
/// plan gerekir. Faz köprüleri her adımda açılıp kapanır. İkizler de
/// karşılıklı uçlara varınca sahne çözülür. Bütçe bitince kayıp.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Çukur — faz köprüsü: (adım + faz) çift ise sağlam.
class Pit {
  final int cell;
  final int phase;
  Pit(this.cell, this.phase);
}

class MirrorTwinsGame implements MiniGame {
  @override
  GameKind get kind => GameKind.mirrorTwins;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  int L = 13;
  int hero = 0; // sol ikiz konumu
  int twin = 0; // sağ ikiz konumu (ayna: L-1-hero başlangıçta)
  int goalHero = 0, goalTwin = 0;
  final List<Pit> pits = [];
  int steps = 0;
  int budget = 0;
  final List<TwinStepFx> trail = [];

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  int _stage = 0;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0;

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

  double get boardX => 24 * scale;
  double get boardY => h * 0.42;
  double get cellW => (w - 48 * scale) / L;

  @override
  void resize(double vw, double vh) {
    w = math.max(320, vw);
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
    _stage = 0;
    trail.clear();
    _newStage();
    host.playSound('start');
  }

  /// Çözülebilir sahne: durum uzayında BFS (hero,twin,faz) ile garanti.
  void _newStage() {
    L = math.min(15, 11 + (_stage / 2).floor());
    budget = L * 3;
    final rnd = math.Random(_def.i * 29 + _stage * 71 + 3);
    for (var attempt = 0; attempt < 80; attempt++) {
      pits.clear();
      final pitCount = 2 + rnd.nextInt(2) + (_stage > 2 ? 1 : 0);
      for (var i = 0; i < pitCount; i++) {
        final cell = 2 + rnd.nextInt(L - 4);
        if (pits.any((p) => p.cell == cell)) continue;
        pits.add(Pit(cell, rnd.nextInt(2)));
      }
      hero = 0;
      twin = L - 1;
      goalHero = L - 1;
      goalTwin = 0;
      steps = 0;
      if (_solvable()) return;
    }
    // son çare: çukursuz sahne
    pits.clear();
    hero = 0;
    twin = L - 1;
    goalHero = L - 1;
    goalTwin = 0;
    steps = 0;
  }

  /// BFS: (hero, twin, parity) → hedef ulaşılabilir mi.
  bool _solvable() {
    final start = (hero, twin, 0);
    final seen = <(int, int, int)>{start};
    final queue = <(int, int, int)>[start];
    while (queue.isNotEmpty) {
      final (h, t, par) = queue.removeAt(0);
      if (h == goalHero && t == goalTwin) return true;
      for (final dir in [-1, 1]) {
        final nh = h + dir;
        final nt = t - dir;
        if (nh < 0 || nh >= L || nt < 0 || nt >= L) continue;
        if (_deadly(nh, par)) continue;
        if (_deadly(nt, par)) continue;
        final state = (nh, nt, (par + 1) % 2);
        if (seen.add(state)) queue.add(state);
      }
    }
    return false;
  }

  bool _deadly(int cell, int parity) {
    for (final p in pits) {
      if (p.cell == cell && (parity + p.phase) % 2 != 0) return true;
    }
    return false;
  }

  /// Dokun: sol yarı = ikisi sola (ikiz sağa), sağ yarı = tersi.
  @override
  void onTap(Offset local) {
    if (_over) return;
    final dir = local.dx < w / 2 ? -1 : 1;
    _step(dir);
  }

  void _step(int dir) {
    final nh = hero + dir;
    final nt = twin - dir;
    final parity = steps % 2;
    // kenar: biri çıkarsa adım yok sayılır
    if (nh < 0 || nh >= L || nt < 0 || nt >= L) {
      _host?.haptic(3);
      return;
    }
    steps++;
    budget--;
    // çukur kontrolü (kalkan: o adımı bağışlar)
    if (_deadly(nh, parity) || _deadly(nt, parity)) {
      if (_shields > 0) {
        _shields--;
        shake = 14;
        flash = 0.25;
        _combo = 0;
        _host?.playSound('shield');
        _host?.haptic(25);
        // adım gerçekleşmez — köprü kapalıydı
        steps--;
        budget++;
        return;
      }
      _over = true;
      _combo = 0;
      _host?.playSound('lose');
      _host?.haptic(50);
      _host?.onEvent('lose', data: {'points': _score});
      return;
    }
    hero = nh;
    twin = nt;
    trail.add(TwinStepFx(hero, twin));
    if (trail.length > 10) trail.removeAt(0);
    _host?.haptic(5);
    _host?.playSound('place');
    if (hero == goalHero && twin == goalTwin) {
      _stageClear();
    } else if (budget <= 0) {
      _over = true;
      _combo = 0;
      _host?.playSound('lose');
      _host?.haptic(40);
      _host?.onEvent('lose', data: {'points': _score});
    }
  }

  void _stageClear() {
    _score += 10 + _stage * 2;
    _combo++;
    if (budget > L) _perfects++;
    _stage++;
    flash = 0.25;
    _host?.playSound('perfect', combo: _combo);
    _host?.haptic(15);
    if (_def.target > 0 && _score >= _def.target) {
      _win();
      return;
    }
    _newStage();
  }

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  /// Test kancaları.
  int get stageForTest => _stage;
  int get budgetForTest => budget;
  List<Pit> get pitsForTest => pits;
  void setShieldsForTest(int n) => _shields = n;

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    for (var i = trail.length - 1; i >= 0; i--) {
      trail[i].life += dt;
      if (trail[i].life > 0.6) trail.removeAt(i);
    }
  }

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
    // ayna ekseni — ortada dikey ışık hattı (ikizlik hissi)
    canvas.drawLine(
        Offset(w / 2, boardY - 46 * scale),
        Offset(w / 2, boardY + 64 * scale),
        Paint()
          ..color = Colors.white.withValues(alpha: .22)
          ..strokeWidth = 1.6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // koridor hücreleri
    for (var i = 0; i < L; i++) {
      final rect = Rect.fromLTWH(boardX + i * cellW, boardY, cellW - 3, 46 * scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
        Paint()..color = Colors.white.withValues(alpha: .04),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
        Paint()
          ..color = Colors.white.withValues(alpha: .1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    }

    // çukur + faz köprüleri
    for (final p in pits) {
      final rect = Rect.fromLTWH(boardX + p.cell * cellW, boardY, cellW - 3, 46 * scale);
      final solid = (steps + p.phase) % 2 == 0;
      if (solid) {
        // köprü: parlak tahta
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
          Paint()
            ..color = _hsl(theme.glow.toDouble(), 70, 45).withValues(alpha: .8));
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
          Paint()
            ..color = Colors.white.withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
      } else {
        // açık çukur: kesikli kızıl uyarı
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
          Paint()
            ..color = Colors.redAccent.withValues(alpha: .12));
        canvas.drawLine(
            Offset(rect.left + 4, rect.center.dy),
            Offset(rect.right - 4, rect.center.dy),
            Paint()
              ..color = Colors.redAccent.withValues(alpha: .8)
              ..strokeWidth = 2);
      }
    }

    // hedefler — karşıt uçlarda ışık kapıları
    for (final (cell, hue) in [(goalHero, 150.0), (goalTwin, 285.0)]) {
      final rect = Rect.fromLTWH(
          boardX + cell * cellW + 4, boardY - 4, cellW - 11, 54 * scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(8 * scale)),
        Paint()
          ..color = _hsl(hue, 90, 62).withValues(alpha: .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }

    // iz hayaletleri
    for (final t in trail) {
      final a = (1 - t.life / 0.6) * .3;
      for (final cell in [t.hero, t.twin]) {
        canvas.drawCircle(
            Offset(boardX + cell * cellW + cellW / 2 - 1.5, boardY + 23 * scale),
            8 * scale,
            Paint()..color = Colors.white.withValues(alpha: a));
      }
    }

    // ikizler — ayna simetrik ışık çekirdekleri
    for (final (cell, hue) in [(hero, 200.0), (twin, 322.0)]) {
      final c = Offset(boardX + cell * cellW + cellW / 2 - 1.5,
          boardY + 23 * scale);
      canvas.drawCircle(
          c,
          15 * scale,
          Paint()
            ..color = _hsl(hue, 95, 65).withValues(alpha: .2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(
          c,
          9.5 * scale,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [
                _hsl(hue, 100, 80),
                _hsl(hue, 95, 52),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: 9.5 * scale)));
      canvas.drawCircle(
          c,
          9.5 * scale,
          Paint()
            ..color = Colors.white.withValues(alpha: .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }

    // adım bütçesi
    final bw = (L * cellW) * (budget / (L * 3)).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(boardX, boardY + 70 * scale, L * cellW, 5),
          const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: .1),
    );
    if (bw > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(boardX, boardY + 70 * scale, bw, 5),
            const Radius.circular(3)),
        Paint()
          ..color = _hsl(theme.glow.toDouble(), 90, 62)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    canvas.restore();
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }
}

class TwinStepFx {
  final int hero, twin;
  double life;
  TwinStepFx(this.hero, this.twin) : life = 0;
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
