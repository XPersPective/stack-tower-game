/// BALANCE — Denge (DESIGN-V2 §3.1 tür 8, "bas = tarafa ağırlık ver").
/// Tahterevalli rastgele sürüklenir ve devrildikçe hızlanır; dokunuşun
/// yapıldığı tarafa ağırlık ekler (sol dokunuş sola yatırır, sağ sağa).
/// Düşme yönünün TERSİNE dokunarak denge kurulur. Merkez banda
/// (|eğim| < 0.08) geçirilen her tam 0.5 s bir "mükemmel" sayılır —
/// dokunuş başına ödül yoktur (spam farm edilemez). Hedef: T saniye devrilmeden.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class BalanceGame implements MiniGame {
  @override
  GameKind get kind => GameKind.balance;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  double tilt = 0; // rad; 0 = dengede; <0 sola, >0 sağa
  double drift = 0; // rad/s anlık sürükleme
  double survived = 0;
  double needed = 12;
  double time = 0, shake = 0, flash = 0;
  double _centerAcc = 0; // merkez bandında biriken süre (0.5 s = 1 mükemmel)
  double _cd = 0; // dokunuş bekleme süresi (spam koruması)
  int _weightSide = 0; // son ağırlığın tarafı (görsel)
  double _weightT = 0; // ağırlık bloğu görünürlüğü
  int _perfects = 0; // merkez bandında geçirilen yarım-saniyeler
  int nudges = 0;
  final math.Random _rnd = math.Random();

  int _combo = 0, _shields = 1;
  bool _over = false, _reached = false;

  /// Kombo yalnız merkez bandında büyür; banttan çıkınca sıfırlanır
  /// (ıska cezası yoktur — türler arası kombo sözleşmesi: DEFEND kalkan
  /// yiyince, RHYTHM ıskada, BALANCE bant dışına çıkınca sıfırlar).

  @override
  int get score => survived.floor(); // HUD: saniye
  @override
  int get target => needed.floor();
  @override
  int get combo => _combo;
  @override
  int get shieldsLeft => _shields;
  @override
  bool get isOver => _over;

  /* ---- test kancaları ---- */
  @visibleForTesting
  double get tiltForTest => tilt;
  @visibleForTesting
  double get survivedForTest => survived;
  @visibleForTesting
  int get nudgesForTest => nudges;
  @visibleForTesting
  double get flashForTest => flash;
  @visibleForTesting
  void setTiltForTest(double v, {double d = 0}) {
    tilt = v;
    drift = d;
  }

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
    tilt = 0;
    drift = 0;
    survived = 0;
    nudges = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    time = 0;
    shake = 0;
    flash = 0;
    _centerAcc = 0;
    _cd = 0;
    _weightSide = 0;
    _weightT = 0;
    // hedef süre: blok hedefinden (DEFEND/RHYTHM ile aynı kaynak), kısa bandda
    needed = (def.target > 0 ? def.target.toDouble() : 10 + def.speed * 1.2)
        .clamp(8.0, 30.0);
    host.playSound('start');
  }

  @override
  void onTap(Offset local) {
    if (_over || _cd > 0) return;
    _cd = 0.22; // DEFEND'deki gibi bekleme: buzz-spam koruması
    // §3.1: bas = TARAFa ağırlık ver. Sol dokunuş sola, sağ sağa yatırır;
    // düşme yönünün tersine dokunarak denge kurulur.
    final side = local.dx < w / 2 ? -1 : 1;
    tilt += side * 0.14;
    _weightSide = side;
    _weightT = 0.6;
    nudges++;
    _host?.playSound('place');
    _host?.haptic(8);
  }

  @override
  void tick(double dt) {
    if (_over || dt <= 0) return;
    time += dt;
    _cd = math.max(0, _cd - dt);
    flash = math.max(0, flash - dt * 3);
    _weightT = math.max(0, _weightT - dt);
    // sürükleme: rastgele esneyer, zamanla hızlanır (bölüm hızıyla)
    if (_rnd.nextDouble() < 0.02 + time * 0.0012) {
      drift += (_rnd.nextDouble() - 0.5) * 0.5 * (0.8 + _def.speed * 0.3);
    }
    // devrilme ivmesi: eğildikçe daha hızlı devrilir (ters sarkaç)
    drift += tilt * 0.35 * dt;
    drift = drift.clamp(-0.9, 0.9);
    tilt += drift * dt;
    survived += dt;
    shake = (tilt.abs() * 26 * scale).clamp(0.0, 14);

    // merkez bandı: burada geçirilen her tam 0.5 s bir mükemmel;
    // bant dışına çıkınca kombo sıfırlanır (dokunuş başına ödül yok)
    if (tilt.abs() < 0.08) {
      _centerAcc += dt;
      while (_centerAcc >= 0.5) {
        _centerAcc -= 0.5;
        _perfects++;
        _combo++;
        _host?.playSound('perfect', combo: _combo);
        _host?.haptic(12);
      }
    } else {
      _centerAcc = 0;
      _combo = 0;
    }

    if (tilt.abs() >= 0.5) {
      // kalkan: eğimi yarıya indir, sürdür
      if (_shields > 0) {
        _shields--;
        tilt *= 0.45;
        drift *= 0.3;
        shake = 15;
        flash = 0.5;
        _host?.playSound('shield');
        _host?.haptic(40);
        _host?.onEvent('shield', data: {'left': _shields});
      } else {
        _over = true;
        _reached = false;
        shake = 22;
        flash = 0.7;
        _host?.playSound('lose');
        _host?.haptic(60);
        _host?.onEvent('lose', data: {'points': survived.floor()});
      }
      return;
    }

    if (survived >= needed) {
      _over = true;
      _reached = true;
      _host?.playSound('win');
      _host?.haptic(30);
      _host?.onEvent('win', data: {'points': survived.floor()});
    }
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() => MiniGameResult(
        points: survived.floor(),
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

    final cx = w / 2;
    final beamY = h * 0.55;
    final beamW = w * 0.78;

    // kule (üstte, eğimle döner)
    canvas.save();
    canvas.translate(cx, beamY);
    canvas.rotate(tilt);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-beamW / 2, -26 * scale, beamW, 22 * scale),
            const Radius.circular(8)),
        Paint()
          ..shader = LinearGradient(colors: [
            _hslC(theme.glow, 70, 52),
            _hslC(theme.glow, 70, 36),
          ]).createShader(Rect.fromLTWH(-beamW / 2, -26 * scale, beamW, 22 * scale)));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-beamW / 2, -26 * scale, beamW, 22 * scale),
            const Radius.circular(8)),
        Paint()
          ..color = _hslA(theme.glow, 100, 80, .6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    // tehlike bölgesi çizgileri (yalnız renk değil — simetrik işaret)
    for (final side in [-1.0, 1.0]) {
      final danger = tilt.abs() > 0.3;
      canvas.drawLine(
          Offset(side * beamW * 0.46, -30 * scale),
          Offset(side * beamW * 0.46, -40 * scale),
          Paint()
            ..color = danger
                ? const Color(0xFFFF5A5A).withValues(alpha: .9)
                : Colors.white.withValues(alpha: .25)
            ..strokeWidth = 3);
    }
    // son dokunuşun ağırlık bloğu — hangi tarafa ağırlık verildiğini gösterir
    if (_weightT > 0 && _weightSide != 0) {
      final wx = _weightSide * beamW * 0.32;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(wx - 15 * scale, -54 * scale, 30 * scale, 28 * scale),
              const Radius.circular(6)),
          Paint()
            ..color = _hslA(theme.glow, 95, 70, (_weightT / 0.6).clamp(0.0, 1.0) * 0.85));
    }
    canvas.restore();

    // kaide
    canvas.drawPath(
        Path()
          ..moveTo(cx - 46 * scale, beamY + 8)
          ..lineTo(cx + 46 * scale, beamY + 8)
          ..lineTo(cx, beamY + 62 * scale)
          ..close(),
        Paint()..color = _hslC(theme.glow, 42, 18));

    // eğim göstergesi (merkez orantı çubuğu)
    final barW = w * 0.5;
    final by = h * 0.78;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW / 2, by, barW, 12 * scale), const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: .12));
    final markerX = cx + (tilt / 0.5) * (barW / 2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                (markerX - 10).clamp(cx - barW / 2, cx + barW / 2 - 20),
                by - 2,
                20,
                16 * scale),
            const Radius.circular(4)),
        Paint()..color = tilt.abs() > 0.3 ? const Color(0xFFFF5A5A) : const Color(0xFF46E6FF));

    if (flash > 0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFFFF5A5A).withValues(alpha: flash * .3));
    }
    canvas.restore();
  }
}

Color _hslC(int hue, int s, int l) =>
    HSLColor.fromAHSL(1, hue.toDouble(), s / 100, l / 100).toColor();

Color _hslA(int hue, int s, int l, double a) =>
    HSLColor.fromAHSL(a.clamp(0, 1), hue.toDouble(), s / 100, l / 100).toColor();
