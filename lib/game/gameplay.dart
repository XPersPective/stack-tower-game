/// Stack Tower Game — oyun motoru (durum + fizik + efektler).
/// `reference/www/game.js` motor katmanının birebir portu (SPEC §2.1, §3).
/// Flutter'sız saf Dart'tır; çizim `scene_painter.dart`'ta, test `gameplay_test.dart`ta.
library;

import 'dart:math' as math;

import 'drop_core.dart';
import 'levels.dart';

/// Rüzgar/akan/deprem tiklerini ve efekt fiziğini game.js tick() ile birebir yürütür.
enum EngineState { idle, playing, won, lost }

/// Motor olayı (cb(name, payload) karşılığı).
enum EngineEvent { place, shield, win, lose, ready }

class EngineEventData {
  final bool perfect;
  final int combo;
  final int score;
  final bool rescued;
  final int shieldLeft;
  const EngineEventData({
    this.perfect = false,
    this.combo = 0,
    this.score = 0,
    this.rescued = false,
    this.shieldLeft = 0,
  });
}

class LevelResult {
  final int blocks;
  final int perfects;
  final bool reached;
  const LevelResult(this.blocks, this.perfects, this.reached);
}

/* --------------------------- Efekt tipleri --------------------------- */

class Debris {
  double x, y, w, h, vy, rot, vr, hue, life;
  Debris(this.x, this.y, this.w, this.h, this.vy, this.vr, this.hue)
      : rot = 0,
        life = 0;
}

class Particle {
  double x, y, vx, vy, life, max, size;
  int hue;
  bool coin;
  Particle(this.x, this.y, this.vx, this.vy, this.max, this.size, this.hue, {this.coin = false})
      : life = 0;
}

class Ring {
  double x, y, r, life, max;
  int hue;
  Ring(this.x, this.y, this.r, this.max, this.hue) : life = 0;
}

class Popup {
  String text;
  double x, y, life, max;
  int hue;
  Popup(this.text, this.x, this.y, this.hue) : life = 0, max = 0.9;
}

class Confetti {
  double x, y, vx, vy, rot, vr, w, h, hue, life, max;
  Confetti(this.x, this.y, this.vx, this.vy, this.vr, this.w, this.h, this.hue, this.max,
      {double? rot})
      : rot = rot ?? 0,
        life = 0;
}

class WeatherBit {
  String kind;
  double x, y, r, sp, ph, a;
  WeatherBit(this.kind, this.x, this.y, this.r, this.sp, this.ph, this.a);
}

class Cloud {
  double x, y, rx, ry, a, sp;
  Cloud(this.x, this.y, this.rx, this.ry, this.a, this.sp);
}

class FgBit {
  double x, y, r, ph;
  FgBit(this.x, this.y, this.r, this.ph);
}

class StarBit {
  double x, y, r, p, s;
  StarBit(this.x, this.y, this.r, this.p, this.s);
}

class SilPoint {
  String type; // block | tree | hill
  double x, w, h;
  SilPoint(this.type, this.x, this.w, this.h);
}

class SilLayer {
  List<SilPoint> pts;
  double base;
  int layer;
  SilLayer(this.pts, this.base, this.layer);
}

/* ------------------------------ Motor ------------------------------ */

class GamePlay {
  EngineState state = EngineState.idle;
  LevelDef? def;

  // Geometri (resize ile kurulur)
  double w = 0, h = 0, scale = 1, bh = 24, baseW = 230;
  double groundY = 0, topLimit = 0, depthX = 16, depthY = -9;

  List<Block> blocks = [];
  Moving? moving;
  double camShift = 0;
  int score = 0, combo = 0, bestRun = 0;
  int perfects = 0, misses = 0;
  double time = 0, shake = 0;
  double endTimer = 0;
  EngineEvent? endEvent;
  int shieldsLeft = 1;
  double slowTimer = 0;
  int skinHue = 200;
  int progressStars = 0;

  final List<Debris> debris = [];
  final List<Particle> particles = [];
  final List<Ring> rings = [];
  final List<Popup> popups = [];
  final List<Confetti> confetti = [];

  final List<WeatherBit> weather = [];
  final List<Cloud> clouds = [];
  final List<FgBit> fgBits = [];
  List<StarBit> stars = [];
  List<SilLayer> silhouettes = [];

  final math.Random _rnd = math.Random();

  /// Motor olay dinleyicisi (place/shield/win/lose/ready).
  void Function(EngineEvent, EngineEventData)? onEvent;

  /// Dokunsal geri bildirim kancası (ms).
  void Function(int ms)? onHaptic;

  /* --------------------------- Geometri --------------------------- */

  double movingY() => groundY - blocks.length * bh + camShift;
  double topY() => groundY - (blocks.length - 1) * bh + camShift;

  int blockHue(int i) {
    if (def != null && def!.modifier == 'altin') return (42 + (i % 3) * 8) % 360;
    return (skinHue + i * 12) % 360;
  }

  /// Boyut değişimi: ölçek yeniden hesaplanır, kule yeni baseW'ye taşınır.
  void resize(double vw, double vh) {
    final prevBase = baseW;
    w = math.max(320, vw);
    h = math.max(400, vh);
    scale = clamp(math.min(w / 460, h / 780), 0.6, 1.6);
    bh = (24 * scale).roundToDouble();
    baseW = clamp(230 * scale, 120, 320);
    depthX = 16 * scale;
    depthY = -9 * scale;
    groundY = h * 0.88;
    topLimit = h * 0.30;
    if (prevBase != 0 && baseW != prevBase && blocks.isNotEmpty) {
      final f = baseW / prevBase;
      for (final b in blocks) {
        b.x *= f;
        b.w *= f;
      }
      if (moving != null) {
        moving!.x *= f;
        moving!.w *= f;
      }
    }
    makeAmbience();
  }

  void makeAmbience() {
    stars = [];
    final n = ((w * h) / 13000).round();
    for (var i = 0; i < n; i++) {
      stars.add(StarBit(_rnd.nextDouble() * w, _rnd.nextDouble() * h, _rnd.nextDouble() * 1.5 + 0.4,
          _rnd.nextDouble() * 6.28, 0.5 + _rnd.nextDouble() * 1.6));
    }
    makeWeather();
    makeSilhouette();
    makeClouds();
    makeForeground();
  }

  void makeClouds() {
    clouds.clear();
    for (var i = 0; i < 5; i++) {
      clouds.add(Cloud(
        _rnd.nextDouble() * w,
        h * (0.05 + _rnd.nextDouble() * 0.3),
        70 + _rnd.nextDouble() * 120,
        18 + _rnd.nextDouble() * 22,
        0.05 + _rnd.nextDouble() * 0.07,
        (4 + _rnd.nextDouble() * 10) * (_rnd.nextDouble() < 0.5 ? 1 : -1),
      ));
    }
  }

  void makeForeground() {
    fgBits.clear();
    for (var i = 0; i < 3; i++) {
      final xBase = i == 0 ? 0 : (i == 1 ? w : w * 0.5);
      fgBits.add(FgBit(xBase + (_rnd.nextDouble() - 0.5) * 60, h * (0.88 + _rnd.nextDouble() * 0.1),
          90 + _rnd.nextDouble() * 120, _rnd.nextDouble() * 6.28));
    }
  }

  void makeWeather() {
    weather.clear();
    if (def == null) return;
    final kind = def!.theme.weather.isEmpty ? 'stars' : def!.theme.weather;
    final count = kind == 'stars' ? 0 : (w / 12).round();
    for (var i = 0; i < count; i++) {
      weather.add(newWeatherBit(kind, true));
    }
  }

  WeatherBit newWeatherBit(String kind, bool anywhere) {
    final y = anywhere ? _rnd.nextDouble() * h : (kind == 'embers' ? h + 20.0 : -20.0);
    final bit = WeatherBit(kind, _rnd.nextDouble() * w, y, 1 + _rnd.nextDouble() * 2.6,
        20 + _rnd.nextDouble() * 70, _rnd.nextDouble() * 6.28, 0.25 + _rnd.nextDouble() * 0.5);
    if (kind == 'embers') {
      bit.y = anywhere ? _rnd.nextDouble() * h : h + 20;
      bit.sp = -(30 + _rnd.nextDouble() * 60);
    }
    return bit;
  }

  void makeSilhouette() {
    silhouettes = [];
    if (def == null) return;
    final kind = def!.theme.silhouette;
    for (var layer = 0; layer < 2; layer++) {
      final pts = <SilPoint>[];
      final base = h * (0.94 - layer * 0.03);
      var x = -40.0;
      final rnd = mulberry32(def!.theme.id.codeUnitAt(0) * 97 + layer * 13 + def!.stage);
      while (x < w + 60) {
        final bw = 40 + rnd() * 90;
        final hgt = (kind == 'city'
                ? 40 + rnd() * 150
                : kind == 'trees'
                    ? 50 + rnd() * 120
                    : kind == 'dunes'
                        ? 10 + rnd() * 40
                        : kind == 'ice'
                            ? 60 + rnd() * 140
                            : kind == 'volcano'
                                ? 60 + rnd() * 170
                                : 20 + rnd() * 80) *
            (layer == 1 ? 0.7 : 1.0);
        if (kind == 'dunes') {
          pts.add(SilPoint('hill', x, bw * 1.6, hgt));
          x += bw * 1.1;
        } else if (kind == 'trees') {
          pts.add(SilPoint('tree', x, bw * 0.5, hgt));
          x += bw * 0.7;
        } else {
          pts.add(SilPoint('block', x, bw, hgt));
          x += bw + 6;
        }
      }
      silhouettes.add(SilLayer(pts, base, layer));
    }
  }

  /// JS Math.imul: 32-bit işaretli çarpımın düşük 32 biti.
  static int _toInt32(int v) {
    final r = v & 0xFFFFFFFF;
    return r >= 0x80000000 ? r - 0x100000000 : r;
  }

  /// game.js mulberry (satır 324-331) — 32-bit imzalı aritmetik birebir.
  /// `a |= 0` → _toInt32; `>>>` → toUnsigned(32) kaydırma; ^ ve * düşük-32
  /// bit örüntüsü üzerinden JS ile aynı sonucu verir (kanıt: snapshot testi).
  static double Function() mulberry32(int a0) {
    var a = a0;
    return () {
      a = _toInt32(a);
      a = _toInt32(a + 0x6D2B79F5);
      var t = _toInt32(_toInt32(a ^ (a.toUnsigned(32) >> 15)) * (1 | a));
      t = _toInt32(t + _toInt32(_toInt32(t ^ (t.toUnsigned(32) >> 7)) * (61 | t))) ^ t;
      return ((t ^ (t.toUnsigned(32) >> 14)).toUnsigned(32)) / 4294967296;
    };
  }

  /* --------------------------- Oyun akışı --------------------------- */

  void resetWorld() {
    blocks = [Block(w / 2 - baseW / 2, baseW)];
    camShift = 0;
    score = 0;
    combo = 0;
    perfects = 0;
    misses = 0;
    shake = 0;
    debris.clear();
    particles.clear();
    rings.clear();
    popups.clear();
    confetti.clear();
    endTimer = 0;
    endEvent = null;
    spawnMoving();
  }

  void spawnMoving() {
    final top = blocks[blocks.length - 1];
    final b = movingBounds(top);
    final fromLeft = blocks.length % 2 == 1;
    moving = Moving(fromLeft ? b.minX : b.maxX, top.w, fromLeft ? 1 : -1);
  }

  void startLevel(LevelDef d, {int hue = 200, int shields = 1}) {
    def = d;
    skinHue = hue;
    shieldsLeft = shields;
    slowTimer = 0;
    state = EngineState.playing;
    resetWorld();
    makeWeather();
    makeSilhouette();
    onEvent?.call(EngineEvent.ready, const EngineEventData());
  }

  void stopLevel() {
    state = EngineState.idle;
    def = null;
    moving = null;
  }

  bool growthAllowed() => def != null && def!.modifier != 'hizli' && def!.modifier != 'patron';

  void drop() {
    if (state != EngineState.playing || moving == null) return;
    final top = blocks[blocks.length - 1];
    final idx = blocks.length;
    final y = movingY();
    // JS: def.tol || PERFECT_TOLERANCE — 0/falsey değere düşmez.
    final tol = (def?.tol ?? 0) == 0 ? kPerfectTolerance : def!.tol;
    final res = resolveDrop(moving!, top, tol);

    if (!res.ok) {
      // KALKAN: ilk kaçırmayı kurtar (daralmış blokla devam)
      if (shieldsLeft > 0) {
        shieldsLeft--;
        final t0 = blocks[blocks.length - 1];
        final rw = math.max(t0.w * 0.82, kMinBlockWidth * scale * 1.6);
        blocks.add(Block(t0.x + (t0.w - rw) / 2, rw));
        score = blocks.length - 1;
        combo = 0;
        rings.add(Ring(t0.x + t0.w / 2, y + bh / 2, rw * 0.6, 0.7, 190));
        burst(t0.x + t0.w / 2, y + bh / 2, rw, 190, 26);
        popupText('KALKAN KORUDU!', t0.x + t0.w / 2, y - 18 * scale, 190);
        shake = 15;
        slowTimer = 0.55; // dramatik ağır çekim
        onHaptic?.call(45);
        spawnMoving();
        onEvent?.call(EngineEvent.place, EngineEventData(perfect: false, combo: 0, score: score, rescued: true));
        onEvent?.call(EngineEvent.shield, EngineEventData(shieldLeft: shieldsLeft));
        if ((def?.target ?? 0) > 0 && score >= def!.target) {
          state = EngineState.won;
          celebration();
          endEvent = EngineEvent.win;
          endTimer = 0.95;
        }
        return;
      }
      debris.add(Debris(moving!.x, y, moving!.w, bh, -90 * scale,
          (_rnd.nextDouble() < 0.5 ? -1 : 1) * (2 + _rnd.nextDouble() * 3), blockHue(idx).toDouble()));
      moving = null;
      misses++;
      onHaptic?.call(60);
      shake = 20;
      endEvent = EngineEvent.lose;
      endTimer = 0.55;
      state = EngineState.lost;
      return;
    }

    if (res.perfect) {
      combo++;
      perfects++;
      final w2 = growthAllowed() ? growthWidth(res.placed!.w, baseW, combo) : res.placed!.w;
      final x2 = res.placed!.x - (w2 - res.placed!.w) / 2;
      blocks.add(Block(x2, w2));
      final hue = blockHue(idx);
      burst(x2 + w2 / 2, y, w2, hue, 22 + math.min(26, combo * 3));
      rings.add(Ring(x2 + w2 / 2, y + bh / 2, w2 * 0.3, 0.5, hue));
      popupText(combo > 1 ? 'MÜKEMMEL ×$combo' : 'MÜKEMMEL', x2 + w2 / 2, y - 12 * scale, hue);
      if (def?.modifier == 'altin') {
        coinBurst(x2 + w2 / 2, y, 4 + math.min(8, combo));
      }
      shake = math.min(13, 4 + combo * 0.8);
      onHaptic?.call(12);
    } else {
      combo = 0;
      blocks.add(res.placed!);
      for (final c in res.cuts) {
        debris.add(Debris(c.x, y, c.w, bh, -40 * scale,
            (_rnd.nextDouble() < 0.5 ? -1 : 1) * (2.5 + _rnd.nextDouble() * 3.5), blockHue(idx).toDouble()));
        burst(c.x + c.w / 2, y + bh / 2, c.w, blockHue(idx), 10);
      }
      shake = math.min(7, 2 + res.cuts.length * 2);
    }

    score = blocks.length - 1;
    bestRun = math.max(bestRun, score);
    spawnMoving();
    onEvent?.call(EngineEvent.place, EngineEventData(perfect: res.perfect, combo: combo, score: score));

    if (blocks[blocks.length - 1].w < kMinBlockWidth * scale) {
      onHaptic?.call(60);
      endEvent = EngineEvent.lose;
      endTimer = 0.5;
      state = EngineState.lost;
      return;
    }

    if ((def?.target ?? 0) > 0 && score >= def!.target) {
      state = EngineState.won;
      celebration();
      onHaptic?.call(30);
      endEvent = EngineEvent.win;
      endTimer = 0.95;
    }
  }

  LevelResult result() => LevelResult(score, perfects, state == EngineState.won);

  /* --------------------------- Efektler --------------------------- */

  void celebration() {
    for (var i = 0; i < 120; i++) {
      confetti.add(Confetti(
        _rnd.nextDouble() * w,
        -20 - _rnd.nextDouble() * h * 0.3,
        (_rnd.nextDouble() - 0.5) * 120,
        120 + _rnd.nextDouble() * 220,
        (_rnd.nextDouble() - 0.5) * 8,
        (5 + _rnd.nextDouble() * 7) * scale,
        (8 + _rnd.nextDouble() * 9) * scale,
        (skinHue + _rnd.nextDouble() * 200) % 360,
        1.8 + _rnd.nextDouble(),
        rot: _rnd.nextDouble() * 6.28,
      ));
    }
  }

  void coinBurst(double cx, double cy, int n) {
    for (var i = 0; i < n; i++) {
      particles.add(Particle(cx + (_rnd.nextDouble() - 0.5) * 40, cy,
          (_rnd.nextDouble() - 0.5) * 200, -(120 + _rnd.nextDouble() * 240), 0.7, 6 * scale, 48,
          coin: true));
    }
  }

  void burst(double cx, double cy, double w2, int hue, int count) {
    for (var i = 0; i < count; i++) {
      particles.add(Particle(
        cx + (_rnd.nextDouble() - 0.5) * w2,
        cy,
        (_rnd.nextDouble() - 0.5) * 360 * scale,
        -(70 + _rnd.nextDouble() * 280) * scale,
        0.4 + _rnd.nextDouble() * 0.45,
        (2.5 + _rnd.nextDouble() * 4) * scale,
        hue,
      ));
    }
  }

  void popupText(String text, double x, double y, int hue) {
    popups.add(Popup(text, x, y, hue));
  }

  /* --------------------------- Güncelleme --------------------------- */

  void tick(double dt0) {
    var dt = dt0;
    if (slowTimer > 0) {
      slowTimer -= dt;
      dt *= 0.35; // ağır çekim anı
    }
    time += dt;

    final camTarget = math.max(0, topLimit - groundY + blocks.length * bh);
    camShift += (camTarget - camShift) * math.min(1, dt * 10);

    if (moving != null && state == EngineState.playing) {
      final top = blocks[blocks.length - 1];
      final placed = blocks.length - 1;
      var speedScale = def?.speed ?? 1;
      // AKAN: hız dalgalanır · DEPREM: periyodik sarsıntı
      if (def?.modifier == 'akan') speedScale *= (1 + 0.55 * math.sin(time * 2.6));
      if (def?.modifier == 'deprem') {
        final q1 = (time / 2.2).floor();
        final q0 = ((time - dt) / 2.2).floor();
        if (q1 != q0) shake = math.max(shake, 11 + _rnd.nextDouble() * 7);
      }
      stepMoving(moving!, top, placed, dt, speedScale);
      if (def?.modifier == 'ruzgar') {
        final b = movingBounds(top);
        moving!.x += math.sin(time * 2.1) * travelRange(top.w) * 0.14 * dt * 6;
        moving!.x = clamp(moving!.x, b.minX, b.maxX);
      }
    }

    if (endTimer > 0) {
      endTimer -= dt;
      if (endTimer <= 0 && endEvent != null) {
        final e = endEvent!;
        endEvent = null;
        // game.js: cb(e.name, resultPayload()) — üst katman result() ile okur
        onEvent?.call(e, EngineEventData(score: score, combo: combo));
      }
    }

    shake = math.max(0, shake - dt * 55);

    for (var i = debris.length - 1; i >= 0; i--) {
      final d = debris[i];
      d.vy += 1500 * scale * dt;
      d.y += d.vy * dt;
      d.rot += d.vr * dt;
      d.life += dt;
      if (d.y > h + 300) debris.removeAt(i);
    }
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.vy += 900 * scale * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life += dt;
      if (p.life >= p.max) particles.removeAt(i);
    }
    for (var i = rings.length - 1; i >= 0; i--) {
      final r = rings[i];
      r.life += dt;
      r.r += 340 * scale * dt;
      if (r.life >= r.max) rings.removeAt(i);
    }
    for (var i = popups.length - 1; i >= 0; i--) {
      final q = popups[i];
      q.life += dt;
      q.y -= 42 * scale * dt;
      if (q.life >= q.max) popups.removeAt(i);
    }
    for (var i = confetti.length - 1; i >= 0; i--) {
      final cf = confetti[i];
      cf.vy += 60 * dt;
      cf.x += cf.vx * dt;
      cf.y += cf.vy * dt;
      cf.rot += cf.vr * dt;
      cf.life += dt;
      if (cf.life >= cf.max || cf.y > h + 40) confetti.removeAt(i);
    }
    for (var i = 0; i < weather.length; i++) {
      final wb = weather[i];
      wb.y += wb.sp * dt;
      wb.x += math.sin(time * 0.8 + wb.ph) * 14 * dt;
      if (wb.kind == 'embers') {
        if (wb.y < -20) weather[i] = newWeatherBit(wb.kind, false);
      } else if (wb.y > h + 20) {
        weather[i] = newWeatherBit(wb.kind, false);
      }
    }
    for (final cl in clouds) {
      cl.x += cl.sp * dt;
      if (cl.x > w + cl.rx) cl.x = -cl.rx;
      if (cl.x < -cl.rx) cl.x = w + cl.rx;
    }
  }
}
