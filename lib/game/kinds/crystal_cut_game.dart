/// KRİSTAL KESİK — Kesme (PB-044, DESIGN-20GAMES #1: Slicing).
///
/// Fruit Ninja DNA'sının hedef-kesim hâli: süzülen kristale karşı süzülen
/// IŞIK KESİĞİ hedef dilime gelince DOKUN — kesim! Tam merkez = MÜKEMMEL
/// (slow-mo + faset ışıltısı), dilim içi = normal kesim, ıskalamak =
/// kristal bütün düşer (3 ıskala = kayıp). Kesim iki parçaya ayırır ve
/// parçalar sahneden süzülür. Hız def.speed ile artar. Hedef: def.target kesim.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Süzülen kristal — yatay bantta sağa/sola gider, içinde hedef dilimi var.
class Crystal {
  double x, y;
  final double w; // genişlik
  final int targetAt; // hedef dilim (0..sliceCount-1)
  final int sliceCount;
  final int hue;
  double vx;
  double wobble;
  Crystal(this.x, this.y, this.w, this.targetAt, this.sliceCount, this.hue,
      this.vx)
      : wobble = 0;
}

/// Kesilen parça — iki yarı sahneden süzülür.
class CutPiece {
  double x, y, vx, vy, rot, vr, life;
  final int hue;
  final bool leftHalf;
  CutPiece(this.x, this.y, this.vx, this.vy, this.hue, this.leftHalf)
      : rot = 0,
        vr = (leftHalf ? -1 : 1) * 3,
        life = 0;
}

/// Kesim ışıltısı.
class CutSpark {
  double x, y, life;
  final bool perfect;
  CutSpark(this.x, this.y, this.perfect) : life = 0;
}

class CrystalCutGame implements MiniGame {
  @override
  GameKind get kind => GameKind.crystalCut;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  Crystal? crystal;
  double cutX = 0; // kesik ışığının x'i
  double cutDir = 1;
  final List<CutPiece> pieces = [];
  final List<CutSpark> sparks = [];
  double slowMo = 0; // mükemmel kesimde

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1, _misses = 0;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0;
  final math.Random _rnd = math.Random();

  static const int maxMisses = 3;

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
    _misses = 0;
    _over = false;
    _reached = false;
    time = 0;
    flash = 0;
    shake = 0;
    slowMo = 0;
    pieces.clear();
    sparks.clear();
    crystal = null;
    cutX = 0;
    cutDir = 1;
    _spawn();
    host.playSound('start');
  }

  void _spawn() {
    final speed = _def.speed;
    final sliceCount = speed >= 2.2 ? 6 : (speed >= 1.4 ? 5 : 4);
    crystal = Crystal(
      w * 0.5,
      h * 0.42,
      math.min(300 * scale, w - 60),
      _rnd.nextInt(sliceCount),
      sliceCount,
      _def.theme.hues[_rnd.nextInt(_def.theme.hues.length)],
      (_rnd.nextBool() ? 1 : -1) * (26 + speed * 14) * scale,
    );
    cutX = _rnd.nextBool() ? 0 : w;
    cutDir = cutX == 0 ? 1 : -1;
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    final c = crystal;
    if (c == null) return;
    final sliceW = c.w / c.sliceCount;
    final left = c.x - c.w / 2;
    final idx = ((cutX - left) / sliceW).floor();
    if (idx == c.targetAt) {
      // KESİM!
      final center = left + (idx + 0.5) * sliceW;
      final offCenter = ((cutX - center) / (sliceW / 2)).abs().clamp(0.0, 1.0);
      final perfect = offCenter < 0.35;
      if (perfect) {
        _perfects++;
        slowMo = 0.5;
        _combo++;
        if (_combo >= 3) _perfects++;
        _host?.playSound('crit');
      } else {
        _host?.playSound('merge_pop');
      }
      _score++;
      flash = 0.2;
      shake = perfect ? 10 : 6;
      _host?.haptic(perfect ? 20 : 8);
      sparks.add(CutSpark(cutX, c.y, perfect));
      // parçalar
      pieces.add(CutPiece(c.x - c.w * 0.25, c.y, -60 * scale, 30 * scale, c.hue, true));
      pieces.add(CutPiece(c.x + c.w * 0.25, c.y, 60 * scale, 30 * scale, c.hue, false));
      crystal = null;
      if (_def.target > 0 && _score >= _def.target) {
        _win();
        return;
      }
      // sonraki kristal gecikmeli gelir (tick'te)
    } else {
      // ıskalama: kesik ışığı boşa indi
      _misses++;
      _combo = 0;
      shake = 12;
      _host?.playSound('lose');
      _host?.haptic(30);
      if (_misses >= maxMisses) {
        _over = true;
        _host?.onEvent('lose', data: {'points': _score});
        return;
      }
    }
  }

  @override
  void tick(double dt) {
    if (_over) return;
    final d = slowMo > 0 ? dt * 0.25 : dt;
    slowMo = math.max(0, slowMo - dt);
    time += d;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);

    // kesik ışığı taraması (hız sabit — oyuncu zamanlaması)
    cutX += cutDir * (300 + _def.speed * 60) * scale * d;
    if (cutX > w) {
      cutX = w;
      cutDir = -1;
    } else if (cutX < 0) {
      cutX = 0;
      cutDir = 1;
    }

    final c = crystal;
    if (c != null) {
      c.x += c.vx * d;
      if (c.x < c.w / 2 || c.x > w - c.w / 2) {
        c.vx = -c.vx;
        c.x = c.x.clamp(c.w / 2, w - c.w / 2);
      }
      c.wobble += d * 2;
      // kristal ekrandan kaçarsa (üst bant aşırı uzun süre) — ıskalama say
      c.y += math.sin(c.wobble) * 0.2;
    } else {
      // yeni kristal: 0.7 sn sonra
      _respawnT -= dt;
      if (_respawnT <= 0) {
        _respawnT = 0.7;
        _spawn();
      }
    }

    // parçalar
    for (var i = pieces.length - 1; i >= 0; i--) {
      final p = pieces[i];
      p.life += dt;
      p.vy += 900 * scale * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
      if (p.y > h + 60) pieces.removeAt(i);
    }
    for (var i = sparks.length - 1; i >= 0; i--) {
      sparks[i].life += dt;
      if (sparks[i].life > 0.4) sparks.removeAt(i);
    }
  }

  double _respawnT = 0;

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  /// Test kancaları.
  int get missesForTest => _misses;
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

    final c = crystal;
    if (c != null) {
      final sliceW = c.w / c.sliceCount;
      final left = c.x - c.w / 2;
      // kristal gövdesi — faset dilimleri
      for (var i = 0; i < c.sliceCount; i++) {
        final rect = Rect.fromLTWH(left + i * sliceW + 2, c.y - 34 * scale,
            sliceW - 4, 68 * scale);
        final isTarget = i == c.targetAt;
        final pulse = isTarget ? 0.45 + 0.25 * math.sin(time * 7) : 0.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(8 * scale)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hsl(c.hue.toDouble(), 85, 66).withValues(alpha: .85),
                _hsl(c.hue.toDouble(), 80, 44).withValues(alpha: .9),
              ],
            ).createShader(rect),
        );
        // faset iç çizgileri (kristal DNA — RESEARCH-blocks)
        canvas.drawLine(
            Offset(rect.left + 2, rect.top + 4),
            Offset(rect.right - 2, rect.bottom - 4),
            Paint()
              ..color = Colors.white.withValues(alpha: .22)
              ..strokeWidth = 1);
        canvas.drawLine(
            Offset(rect.right - 2, rect.top + 4),
            Offset(rect.left + 2, rect.bottom - 4),
            Paint()
              ..color = Colors.white.withValues(alpha: .16)
              ..strokeWidth = 1);
        if (isTarget) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.inflate(3), Radius.circular(10 * scale)),
            Paint()
              ..color = Colors.white.withValues(alpha: pulse)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2,
          );
        }
      }
      // süpüren glint
      final glintX = left + ((time * 260) % c.w);
      canvas.drawLine(
          Offset(glintX, c.y - 30 * scale),
          Offset(glintX + 14, c.y + 30 * scale),
          Paint()
            ..color = Colors.white.withValues(alpha: .5)
            ..strokeWidth = 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // kesik ışığı — dikey neon hat
    canvas.drawLine(
        Offset(cutX, h * 0.16),
        Offset(cutX, h * 0.72),
        Paint()
          ..color = Colors.white.withValues(alpha: .9)
          ..strokeWidth = 2.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(
        Offset(cutX, h * 0.16),
        4 * scale,
        Paint()..color = Colors.white);
    // iz
    final tailDir = -cutDir;
    canvas.drawLine(
        Offset(cutX, h * 0.16),
        Offset(cutX + tailDir * 46, h * 0.16 + 8),
        Paint()
          ..color = Colors.white.withValues(alpha: .3)
          ..strokeWidth = 1.4);

    // kesilen parçalar — dönerken süzülür
    for (final p in pieces) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      final rect = Rect.fromCenter(
          center: Offset.zero,
          width: 46 * scale,
          height: 60 * scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(7 * scale)),
        Paint()
          ..color = _hsl(p.hue.toDouble(), 80, 50).withValues(alpha: .7),
      );
      canvas.restore();
    }

    // kesim ışıltıları
    for (final s in sparks) {
      final t = s.life / 0.4;
      canvas.drawCircle(
          Offset(s.x, s.y),
          (s.perfect ? 46 : 26) * scale * (0.4 + t),
          Paint()
            ..color = Colors.white.withValues(alpha: (1 - t) * .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - t) + 1);
      if (s.perfect) {
        // faset patlaması: altı ışınlı
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 3 * i + t;
          canvas.drawLine(
              Offset(s.x, s.y),
              Offset(s.x + math.cos(a) * 40 * scale * (1 - t),
                  s.y + math.sin(a) * 40 * scale * (1 - t)),
              Paint()
                ..color = Colors.white.withValues(alpha: (1 - t) * .9)
                ..strokeWidth = 2);
        }
      }
    }

    // ıskala göstergesi (üst sağ): 3 kalp yerine 3 kristal kırığı
    for (var i = 0; i < maxMisses; i++) {
      final cx = w - 26 * scale - i * 26 * scale;
      final alive = i >= _misses;
      canvas.drawCircle(
          Offset(cx, 24 * scale),
          6 * scale,
          Paint()
            ..color = alive
                ? _hsl(theme.glow.toDouble(), 90, 62)
                : Colors.white.withValues(alpha: .12));
    }

    canvas.restore();
    // slow-mo vinyeti
    if (slowMo > 0) {
      canvas.drawRect(
          bgRect,
          Paint()
            ..color = const Color(0xFF9BE8FF).withValues(alpha: slowMo * .12));
    }
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
