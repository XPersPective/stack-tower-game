/// LAUNCH — Fırlat (DESIGN-V2 §3.1 tür 4: aim-rotate + charge fiili).
/// Tek dokunuş: nişan döner, güç çubuğu salınır; dokunduğun andaki açı+güçle
/// mermi fırlatılır. Hedef küreleri vur; atış biterse kaybedersin.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class Projectile {
  double x, y, vx, vy;
  double life;


  Projectile(this.x, this.y, this.vx, this.vy) : life = 0;
}

class Target {
  double x, y, r;
  bool hit;
  double pulse;
  Target(this.x, this.y, this.r)
      : hit = false,
        pulse = 0;
}

class BoomFx {
  double x, y, life;
  BoomFx(this.x, this.y) : life = 0;
}

class LaunchGame implements MiniGame, HoldGame {
  @override
  GameKind get kind => GameKind.launch;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  /// Nişan açısı (rad) ve güç (0..1) — ikisi de otomatik salınır.
  double aim = -math.pi / 2;
  double power = 0.5;
  double time = 0;
  int shotsLeft = 0;

  /// PB-025: basılı tut = şarj (0→1, ~0.62s), bırak = fırlat; nişan dönmeye
  /// devam eder ama şarj sırasında yavaşlar (kontrol edilebilir kalsın).
  bool charging = false;
  double charge = 0;

  final List<Projectile> shots = [];
  final List<Target> targets = [];
  final List<BoomFx> booms = [];

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false, _reached = false;
  double shake = 0, flash = 0, slowMo = 0;
  final math.Random _rnd = math.Random();

  @override
  int get score => _score;
  @override
  int get target => _def.target;
  @override
  int get combo => _combo;
  @override
  int get shieldsLeft => _shields;

  /// Hedefler ancak ilk yerleşimden (w>0) sonra doğar — üretim akışında
  /// `start()` yerleşimden önce çağrılıyor (play_screen post-frame resize).
  bool _targetsReady = false;
  @override
  bool get isOver => _over;

  /// Test kancaları.
  @visibleForTesting
  int get shotsLeftForTest => shotsLeft;
  @visibleForTesting
  List<Target> get targetsForTest => targets;
  @visibleForTesting
  List<Projectile> get shotsForTest => shots;
  @visibleForTesting
  void fireForTest() => _fire();
  @visibleForTesting
  double get wForTest => w;
  @visibleForTesting
  void setShotsForTest(int n) => shotsLeft = n;
  @visibleForTesting
  int get shieldsForTest => _shields;
  @visibleForTesting
  void setAimForTest(double angle, double p) {
    aim = angle;
    power = p;
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
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    time = 0;
    shake = 0;
    flash = 0;
    slowMo = 0;
    shots.clear();
    booms.clear();
    targets.clear();
    // atış bütçesi: hedef + 5 (cömert ama sonsuz değil)
    shotsLeft = def.target + 5;
    _targetsReady = false;
    targets.clear();
    _ensureTargets(); // w>0 ise hemen, değilse ilk tick'te
    host.playSound('start');
  }

  void _ensureTargets() {
    if (_targetsReady || w <= 0 || h <= 0) return;
    _targetsReady = true;
    _spawnTargets();
  }

  void _spawnTargets() {
    // hedef sayısı = bölüm hedefi; ekranın üst yarısına dağıtılır
    final n = math.max(3, _def.target);
    for (var i = 0; i < n; i++) {
      final tx = w * (0.14 + 0.72 * ((i + 0.5) / n)) + (_rnd.nextDouble() - 0.5) * w * 0.06;
      final ty = h * (0.16 + 0.34 * ((i % 3) / 2.0)) + (_rnd.nextDouble() - 0.5) * h * 0.05;
      targets.add(Target(tx, ty, 20 * scale));
    }
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    _fire();
  }

  @override
  void onHoldStart(Offset local) {
    if (_over) return;
    charging = true;
    charge = 0;
  }

  @override
  void onRelease(Offset local) {
    if (_over || !charging) return;
    charging = false;
    _fire();
    charge = 0;
  }

  @override
  void onHoldCancel() {
    charging = false;
    charge = 0;
  }

  void _fire() {
    if (_over) return;
    if (shotsLeft <= 0) return;
    shotsLeft--;
    final speed = (520 + 620 * power) * scale;
    final ox = w / 2, oy = h - 110 * scale;
    shots.add(Projectile(ox, oy, math.cos(aim) * speed, math.sin(aim) * speed));
    _host?.playSound('place');
    _host?.haptic(8);
  }

  @override
  void tick(double dt0) {
    if (_over) return;
    var dt = dt0;
    if (slowMo > 0) {
      slowMo -= dt0;
      dt = dt0 * 0.4;
    }
    _ensureTargets();
    time += dt;
    // nişan dönüşü (şarj sırasında %55 hızda) + güç
    final aimSpeed = (0.9 + _def.speed * 0.35) * (charging ? 0.55 : 1.0);
    aim = -math.pi / 2 + math.sin(time * aimSpeed) * 1.05;
    if (charging) {
      charge = math.min(1, charge + dt * 1.6);
      power = charge;
    } else {
      // dokun modu: güç otomatik salınır (tek dokunuş akışı korunur)
      power = 0.5 + 0.5 * math.sin(time * (1.3 + _def.speed * 0.4) + 1.1);
    }

    shake = math.max(0, shake - dt * 55);
    flash = math.max(0, flash - dt * 3);

    final g = 900 * scale;
    for (var i = shots.length - 1; i >= 0; i--) {
      final p = shots[i];
      p.vy += g * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life += dt;
      // duvar sekmesi (spec §2): yan duvarlardan %72 enerjiyle döner
      if (p.x < 0) {
        p.x = -p.x;
        p.vx = -p.vx * 0.72;
      } else if (p.x > w) {
        p.x = 2 * w - p.x;
        p.vx = -p.vx * 0.72;
      }
      if (p.y > h + 60 || p.x < -80 || p.x > w + 80 || p.life > 6) {
        shots.removeAt(i);
        // kaçan atış komboyu kırar
        if (_combo > 0) _combo = 0;
        _maybeOutOfShots();
        continue;
      }
      // çarpışma
      var hitAny = false;
      for (final t in targets) {
        if (t.hit) continue;
        final dx = t.x - p.x, dy = t.y - p.y;
        if (dx * dx + dy * dy <= (t.r + 7 * scale) * (t.r + 7 * scale)) {
          t.hit = true;
          hitAny = true;
          _score++;
          _combo++;
          // mükemmel: nişan doğrultusunun hedef merkezine dik uzaklığı
          // (kare adımından ve temas anından bağımsız, adil isabet ölçüsü)
          if (_lineDistance(p.x, p.y, p.vx, p.vy, t.x, t.y) <= t.r * 0.55) {
            _perfects++;
          }
          booms.add(BoomFx(t.x, t.y));
          shake = math.min(12, 5 + _combo * 0.8);
          final wasPerfect =
              _lineDistance(p.x, p.y, p.vx, p.vy, t.x, t.y) <= t.r * 0.55;
          _host?.playSound(wasPerfect ? 'perfect' : 'place', combo: _combo);
          _host?.haptic(14);
          if (_combo >= 3) {
            slowMo = 0.22;
            flash = 0.25;
            _host?.onEvent('crit', data: {'combo': _combo});
          }
          shots.removeAt(i);
          if (_def.target > 0 && _score >= _def.target) {
            _win();
          } else {
            // MAJOR düzeltmesi: son atış isabet etse de bütçe bittiyse
            // oyun kilitlenmesin — kalkan ver ya da kaybettir.
            _maybeOutOfShots();
          }
          break;
        }
      }
      if (hitAny) continue;
    }

    for (var i = booms.length - 1; i >= 0; i--) {
      booms[i].life += dt;
      if (booms[i].life > 0.5) booms.removeAt(i);
    }
    for (final t in targets) {
      t.pulse += dt;
    }
  }

  /// (x,y) noktasından (vx,vy) yönündeki doğrunun (tx,ty) hedefine dik uzaklığı.
  double _lineDistance(double x, double y, double vx, double vy, double tx, double ty) {
    final len = math.sqrt(vx * vx + vy * vy);
    if (len <= 1e-9) return math.sqrt((tx - x) * (tx - x) + (ty - y) * (ty - y));
    return ((tx - x) * vy - (ty - y) * vx).abs() / len;
  }

  void _maybeOutOfShots() {
    if (_over) return;
    if (shotsLeft <= 0 && shots.isEmpty) {
      if (_shields > 0) {
        _shields--;
        shotsLeft += 3; // kalkan: 3 atış daha
        _host?.playSound('shield');
        _host?.haptic(40);
        _host?.onEvent('shield', data: {'left': _shields});
        return;
      }
      _lose();
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
    shake = 18;
    flash = 0.6;
    _host?.playSound('lose');
    _host?.haptic(60);
    _host?.onEvent('lose', data: {'points': _score});
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() => MiniGameResult(
        points: _score,
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

    // hedefler
    for (final t in targets) {
      if (t.hit) continue;
      final pulse = 1 + 0.06 * math.sin(t.pulse * 3);
      canvas.drawCircle(Offset(t.x, t.y), t.r * 2.1 * pulse,
          Paint()
            ..color = const Color(0xFFFF5ED2).withValues(alpha: .14)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawCircle(Offset(t.x, t.y), t.r * pulse,
          Paint()..color = const Color(0x33FF5ED2));
      canvas.drawCircle(Offset(t.x, t.y), t.r * pulse,
          Paint()
            ..color = const Color(0xFFFF9AE6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);
      canvas.drawCircle(Offset(t.x, t.y), t.r * 0.28,
          Paint()..color = const Color(0xFFFFD7F4));
    }

    // mermiler + iz
    for (final p in shots) {
      final tail = Offset(p.x - p.vx * 0.03, p.y - p.vy * 0.03);
      canvas.drawLine(tail, Offset(p.x, p.y),
          Paint()
            ..color = const Color(0x8846E6FF)
            ..strokeWidth = 5 * scale
            ..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(p.x, p.y), 7 * scale,
          Paint()..color = const Color(0xFFDFFBFF));
    }

    // patlamalar: iç flaş + genişleyen halka + 8 kıvılcım (juice, C-023)
    for (final b in booms) {
      final t = (b.life / 0.5).clamp(0.0, 1.0);
      final c = Offset(b.x, b.y);
      canvas.drawCircle(
          c,
          (10 + t * 20) * scale,
          Paint()
            ..color = const Color(0xFFFFD24A).withValues(alpha: (1 - t) * .45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, 10 * scale)));
      canvas.drawCircle(c, (12 + t * 52) * scale,
          Paint()
            ..color = const Color(0xFFFFD24A).withValues(alpha: (1 - t) * .85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - t) + 1);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4 + b.life * 3;
        final r0 = (14 + t * 30) * scale;
        final r1 = r0 + (10 + 16 * (1 - t)) * scale;
        canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * r0,
            c + Offset(math.cos(a), math.sin(a)) * r1,
            Paint()
              ..color = const Color(0xFFFFE9A8).withValues(alpha: (1 - t) * .9)
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round);
      }
    }

    // fırlatıcı + nişan
    final ox = w / 2, oy = h - 110 * scale;
    canvas.drawCircle(Offset(ox, oy), 20 * scale, Paint()..color = const Color(0xFF22305E));
    canvas.drawCircle(Offset(ox, oy), 20 * scale,
        Paint()
          ..color = const Color(0xFF46E6FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4);
    final len = (60 + 70 * power) * scale;
    canvas.drawLine(Offset(ox, oy), Offset(ox + math.cos(aim) * len, oy + math.sin(aim) * len),
        Paint()
          ..color = const Color(0xFFBFF4FF)
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round);
    // güç çubuğu
    final barW = w * 0.42;
    final bx = (w - barW) / 2, by = h - 54 * scale;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, barW, 10 * scale), Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: .12));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, barW * power, 10 * scale), Radius.circular(6)),
        Paint()..color = const Color(0xFFFFC247));
    // atış bütçesi
    final tp = TextPainter(
      text: TextSpan(
          text: 'ATIŞ $shotsLeft',
          style: const TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFFEEF2FF), fontSize: 15, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, by - 26));
    canvas.restore();

    if (flash > 0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: flash * .25));
    }
  }
}
