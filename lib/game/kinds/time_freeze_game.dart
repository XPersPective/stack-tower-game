/// ZAMAN KIRICI — Zaman Donma (PB-043, DESIGN-20GAMES #9: Time Freeze).
///
/// SUPERHOT prensibinin tek dokunuş hâli: gemi yukarı süzülür, mermiler
/// enine uçar. BASILI TUT = zaman kristal buz gibi donar (mermiler %4
/// hızla sürünür) ve gemi parmakla yana süzülür — MATRİS KAÇIŞI. Bırak =
/// zaman akar. Donma enerjisi sınırlı (2.5 sn) ve bırakınca şarj olur.
/// Mermi değince kayıp (kalkan: 1 sn dokunulmazlık). Skor = mesafe.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Enine mermi — süzülen kristal kıymık.
class Shard {
  double x, y, vx, r;
  int hue;
  Shard(this.x, this.y, this.vx, this.r, this.hue);
}

/// Donma sisi parçacığı.
class FrostFlake {
  double x, y, life, r;
  FrostFlake(this.x, this.y, this.r) : life = 0;
}

class TimeFreezeGame implements MiniGame, HoldGame {
  @override
  GameKind get kind => GameKind.timeFreeze;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  // gemi
  double shipX = 0, shipY = 0, targetX = 0;
  double shipR = 12;
  bool holding = false;
  double freezeEnergy = 1; // 0..1
  double invuln = 0; // kalkan dokunulmazlık

  final List<Shard> shards = [];
  final List<FrostFlake> frosts = [];
  double scroll = 0; // mesafe
  double spawnT = 0;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
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

  @override
  void resize(double vw, double vh) {
    w = math.max(300, vw);
    h = math.max(420, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    shipR = 12 * scale;
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
    scroll = 0;
    holding = false;
    freezeEnergy = 1;
    invuln = 1; // açılış dokunulmazlığı
    spawnT = 0;
    shipX = w / 2;
    targetX = shipX;
    shipY = h * 0.7;
    shards.clear();
    frosts.clear();
    host.playSound('start');
  }

  /* ------------------------- HoldGame ------------------------- */

  @override
  void onHoldStart(Offset local) {
    if (_over) return;
    holding = true;
    targetX = local.dx.clamp(shipR, w - shipR);
    _host?.playSound('mystery');
  }

  @override
  void onRelease(Offset local) {
    holding = false;
  }

  @override
  void onHoldCancel() {
    holding = false;
  }

  @override
  void onTap(Offset local) {
    // tek dokunuş = kısa dondurma (HoldGame yoksa host bunu kullanır)
    onHoldStart(local);
    // release host HoldGame arayüzüyle gelir; tek dokunuşta 120ms donma
    _shortFreeze = 0.12;
  }

  double _shortFreeze = 0;

  /* ------------------------- tick ------------------------- */

  static const double _shipRise = 120; // süzülme hızı (px/s)
  double get _timeScale => (holding && freezeEnergy > 0) || _shortFreeze > 0
      ? 0.04
      : 1.0;

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);
    invuln = math.max(0, invuln - dt);
    _shortFreeze = math.max(0, _shortFreeze - dt);

    final frozen = _timeScale < 1;
    // enerji: dondururken tüket, akışta şarj
    if (frozen && holding) {
      freezeEnergy = math.max(0, freezeEnergy - dt / 2.5);
      if (freezeEnergy <= 0) holding = false;
    } else {
      freezeEnergy = math.min(1, freezeEnergy + dt / 3.2);
    }

    // gemi: hedefe süzül (zamandan bağımsız — fantazi çekirdeği)
    final dx = targetX - shipX;
    shipX += dx.clamp(-320 * dt, 320 * dt);
    shipY = h * 0.7;

    // dünya akışı: gemi ilerledikçe mesafe artar (donmada yavaşlar)
    final worldDt = dt * (frozen ? 0.15 : 1.0);
    scroll += _shipRise * worldDt;
    _score = (scroll / 40).floor();
    if (_def.target > 0 && _score >= _def.target) {
      _win();
      return;
    }

    // mermi doğumu
    spawnT -= dt;
    if (spawnT <= 0) {
      spawnT = math.max(0.28, 0.75 - _def.speed * 0.12);
      _spawnShard();
    }

    // mermiler — zaman ölçeğiyle
    for (var i = shards.length - 1; i >= 0; i--) {
      final s = shards[i];
      s.x += s.vx * dt * _timeScale * 2.2;
      s.y += _shipRise * worldDt; // dünya ile akar
      if (s.x < -40 || s.x > w + 40 || s.y > h + 40) {
        shards.removeAt(i);
        continue;
      }
      // çarpışma
      final d = math.sqrt((s.x - shipX) * (s.x - shipX) +
          (s.y - shipY) * (s.y - shipY));
      if (d < s.r + shipR && invuln <= 0) {
        _hit();
        return;
      }
    }

    // donma sisi
    if (frozen && _rnd.nextDouble() < dt * 22) {
      frosts.add(FrostFlake(
          _rnd.nextDouble() * w, _rnd.nextDouble() * h, 3 + _rnd.nextDouble() * 7));
    }
    for (var i = frosts.length - 1; i >= 0; i--) {
      frosts[i].life += dt;
      if (frosts[i].life > 0.9) frosts.removeAt(i);
    }
  }

  void _spawnShard() {
    final fromLeft = _rnd.nextBool();
    final r = (7 + _rnd.nextDouble() * 8) * scale;
    shards.add(Shard(
      fromLeft ? -30 : w + 30,
      _rnd.nextDouble() * h * 0.75,
      (fromLeft ? 1 : -1) * (110 + _rnd.nextDouble() * 120 + _def.speed * 30) *
          scale,
      r,
      _def.theme.hues[_rnd.nextInt(_def.theme.hues.length)],
    ));
  }

  void _hit() {
    if (_shields > 0) {
      _shields--;
      invuln = 1.2;
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

  /// Test kancası.
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
    final frozen = _timeScale < 1;
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: frozen
              ? const [
                  Color(0xFF0A1E33),
                  Color(0xFF0E3050),
                  Color(0xFF0A1E33)
                ]
              : [theme.bg1, theme.bg2, theme.bg1],
        ).createShader(bgRect),
    );
    // yıldız akışı
    for (var i = 0; i < 24; i++) {
      final sx = (i * 91.7) % w;
      final sy = ((i * 57.3 + scroll * 0.5) % h + h) % h;
      canvas.drawCircle(Offset(sx, sy), 1.0,
          Paint()..color = Colors.white.withValues(alpha: .14));
    }

    // donma buz faset overlay'i (L1: durum tek bakışta)
    if (frozen) {
      final ice = Paint()
        ..color = const Color(0xFF9BE8FF).withValues(alpha: .07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawRect(bgRect, ice);
      // köşe buz kristalleri
      for (final corner in [
        const Offset(0, 0),
        Offset(w, 0),
        Offset(0, h),
        Offset(w, h)
      ]) {
        canvas.drawCircle(corner, 60 * scale, ice);
      }
    }

    // donma enerji şeridi (gemi altı)
    final bw = 70 * scale * freezeEnergy;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(shipX - 35 * scale, shipY + shipR + 8, 70 * scale, 4),
          const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: .12),
    );
    if (bw > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                shipX - 35 * scale, shipY + shipR + 8, bw, 4),
            const Radius.circular(2)),
        Paint()
          ..color = const Color(0xFF9BE8FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // mermiler — kristal kıymık
    for (final s in shards) {
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(time * 2 + s.x * 0.01);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: s.r * 2, height: s.r * 0.9),
            Radius.circular(s.r * 0.3)),
        Paint()
          ..color = _hsl(s.hue.toDouble(), 90, 62).withValues(alpha: .85));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: s.r * 2, height: s.r * 0.9),
            Radius.circular(s.r * 0.3)),
        Paint()
          ..color = Colors.white.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
      canvas.restore();
    }

    // gemi — ışık çekirdeği + dokunulmazlık halkası
    final sc = Offset(shipX, shipY);
    if (invuln > 0) {
      canvas.drawCircle(
          sc,
          shipR * 1.8,
          Paint()
            ..color = Colors.white.withValues(alpha: .25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    canvas.drawCircle(
        sc,
        shipR * 2.2,
        Paint()
          ..color = const Color(0xFF9BE8FF).withValues(alpha: frozen ? .2 : .1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(
        sc,
        shipR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: const [Color(0xFFDFF6FF), Color(0xFF57C8F2)],
          ).createShader(
              Rect.fromCircle(center: sc, radius: shipR)));
    canvas.drawCircle(
        sc,
        shipR,
        Paint()
          ..color = Colors.white.withValues(alpha: .6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);

    // donma sisi parçacıkları
    for (final f in frosts) {
      final a = (1 - f.life / 0.9).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(f.x, f.y),
          f.r,
          Paint()
            ..color = Colors.white.withValues(alpha: a * .12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
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
