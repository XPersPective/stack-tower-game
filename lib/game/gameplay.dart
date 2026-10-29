/// Stack Tower Game — oyun motoru (durum + fizik + efektler).
/// `reference/www/game.js` motor katmanının birebir portu (SPEC §2.1, §3).
/// Flutter'sız saf Dart'tır; çizim `scene_painter.dart`'ta, test `gameplay_test.dart`ta.
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'drop_core.dart';
import 'levels.dart';
import 'twists.dart';

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
  bool star; // PB-016 juice: yıldız izi parıltısı (yerçekimsiz, yıldız biçimli)
  Particle(this.x, this.y, this.vx, this.vy, this.max, this.size, this.hue, {this.coin = false})
      : life = 0,
        star = false;
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

  // --- Sürpriz motoru (ADR-006) ---
  TwistType? twist;
  bool _zitFlip = false; // zitakis: mükemmelle yön ters çevir
  int crits = 0; // KRİTİK mükemmel sayısı (×5 para, session uygular)
  int goldBlocks = 0; // ALTIN YAĞMURU altın blok sayısı
  bool _goldNow = false; // bu hareketli blok altın mı
  double Function()? critRoll; // test enjeksiyonu
  double Function()? goldRoll; // test enjeksiyonu
  double get hitStopMax => 0.07;
  @visibleForTesting
  bool get goldNowForTest => _goldNow;
  double hitStop = 0; // mükemmelde mikro duraklama (PB-016 juice)
  double squashT = 0; // PB-016 juice: yerleştirme squash'ı kalan süre — hit-stop'tan bağımsız akar
  int squashIdx = -1; // squash yapan blok indeksi
  double flashT = 0; // PB-016 juice: tam-ekran flaş kalan süre
  double flashAlpha = 0; // flaş başlangıç alfası (mükemmel 0.18 / kritik 0.35)
  bool flashWhite = false; // kritik: beyaz flaş
  double spawnTilt = 0; // ruzgargulu görsel açı (±15°)
  Moving? ghost; // GÖLGE BLOK: hayalet ikiz — farklı hızda, hiçbir kuralı etkilemez

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
  /// juice (PB-016): sunum amaçlı ayrı akış — oyun zarlarını (kritik/altın)
  /// tüketmez, JS paritesindeki olasılıkları kaydırmaz.
  final math.Random _fxRnd = math.Random(1016);

  /// Motor olay dinleyicisi (place/shield/win/lose/ready).
  void Function(EngineEvent, EngineEventData)? onEvent;

  /// Dokunsal geri bildirim kancası (ms).
  void Function(int ms)? onHaptic;

  /// PB-016 juice: çoklu vuruş deseni kancası (kritik çift 10+40, kutu üçlü).
  void Function(List<int> pulsesMs)? onHapticPattern;

  /* --------------------------- Geometri --------------------------- */

  double movingY() => groundY - blocks.length * bh + camShift;
  double topY() => groundY - (blocks.length - 1) * bh + camShift;

  int blockHue(int i) {
    if (def != null && def!.modifier == 'altin') return (42 + (i % 3) * 8) % 360;
    if (_goldNow && moving != null) {
      return 48; // ALTIN YAĞMURU: hareketli blok altın
    }
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

  /// DAR GEÇİT: daralan duvarların izin verdiği hareket aralığı. Spawn ve uçuş
  /// (sekme) aynı sınırı kullanır — blok çizili duvarların ötesine taşmaz.
  (double, double) dargecitBounds(Block top) {
    final b = movingBounds(top);
    var minX = b.minX, maxX = b.maxX;
    final inset = math.min(top.w * 0.3, blocks.length * 6.0 * scale);
    minX += inset;
    maxX -= inset;
    if (maxX < minX) {
      final mid = (minX + maxX) / 2;
      minX = mid;
      maxX = mid;
    }
    return (minX, maxX);
  }

  void spawnMoving() {
    final top = blocks[blocks.length - 1];
    final b = movingBounds(top);
    var fromLeft = blocks.length % 2 == 1;
    if (twist == TwistType.zitakis && _zitFlip) fromLeft = !fromLeft;
    // dargecit: duvarlar daraldıkça hareket aralığı da daralır
    var minX = b.minX, maxX = b.maxX;
    if (twist == TwistType.dargecit) {
      (minX, maxX) = dargecitBounds(top);
    }
    moving = Moving(fromLeft ? minX : maxX, top.w, fromLeft ? 1 : -1);
    _goldNow = twist == TwistType.altinyagmuru &&
        (goldRoll ?? _rnd.nextDouble)() < 0.25;
    // GÖLGE BLOK: hayalet ikiz ters taraftan doğar, farklı hızda dolaşır
    ghost = twist == TwistType.golgeblok
        ? Moving(fromLeft ? maxX : minX, top.w, fromLeft ? -1 : 1)
        : null;
  }

  void startLevel(LevelDef d, {int hue = 200, int shields = 1, TwistType? twistType}) {
    def = d;
    skinHue = hue;
    shieldsLeft = shields;
    slowTimer = 0;
    twist = twistType ?? ((d.daily || d.endless) ? null : twistFor(d.i));
    _zitFlip = false;
    crits = 0;
    goldBlocks = 0;
    _goldNow = false;
    hitStop = 0;
    squashT = 0; // juice (PB-016): yeniden başlatmada efekt durumu sıfırlanır
    squashIdx = -1;
    flashT = 0;
    flashAlpha = 0;
    flashWhite = false;
    spawnTilt = 0;
    ghost = null;
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

    var wasCrit = false;
    if (res.perfect) {
      combo++;
      perfects++;
      final w2 = growthAllowed() ? growthWidth(res.placed!.w, baseW, combo) : res.placed!.w;
      final x2 = res.placed!.x - (w2 - res.placed!.w) / 2;
      blocks.add(Block(x2, w2));
      _markSquash(); // juice (PB-016): yerleştirme squash&stretch
      final hue = blockHue(idx);
      var burstCount = 22 + math.min(26, combo * 3).toInt();
      // KRİTİK: %20 ihtimalle ×5 para + büyük patlama
      if (twist == TwistType.kritik) {
        final roll = (critRoll ?? _rnd.nextDouble)();
        if (roll < 0.20) {
          wasCrit = true;
          crits++;
          burstCount = 40;
          rings.add(Ring(x2 + w2 / 2, y + bh / 2, w2 * 0.35, 0.6, 48));
          popupText('KRİTİK ×5!', x2 + w2 / 2, y - 34 * scale, 48);
        }
      }
      burst(x2 + w2 / 2, y, w2, hue, burstCount);
      _confettiBurst(x2 + w2 / 2, y, 12, hue); // juice (PB-016): mükemmel konfetisi
      _starTrail(x2 + w2 / 2, y, hue); // juice (PB-016): yıldız izi
      rings.add(Ring(x2 + w2 / 2, y + bh / 2, w2 * 0.3, 0.5, hue));
      popupText(combo > 1 ? 'MÜKEMMEL ×$combo' : 'MÜKEMMEL', x2 + w2 / 2, y - 12 * scale, hue);
      if (def?.modifier == 'altin') {
        coinBurst(x2 + w2 / 2, y, 4 + math.min(8, combo));
      }
      if (wasCrit) coinBurst(x2 + w2 / 2, y, 10);
      shake = math.min(13, 4 + combo * 0.8) + (wasCrit ? 6 : 0);
      // juice (PB-016): hit-stop her mükemmelde — 40ms + kombo başına 4ms (tavan
      // 70ms); yerleştirme matematiğine (C-002) dokunmaz, yalnız his katmanıdır
      hitStop = math.min(hitStopMax, 0.04 + combo * 0.004 + (wasCrit ? 0.03 : 0));
      // juice (PB-016): tam-ekran flaş — mükemmel tema-glow 0.18, kritik beyaz 0.35 (90ms fade)
      flashAlpha = wasCrit ? 0.35 : 0.18;
      flashWhite = wasCrit;
      flashT = 0.09;
      // juice (PB-016): haptic — desen vuruş başlangıç anlarıdır (ms):
      // [0, 60] = hemen bir vuruş + 60ms sonra ikinci vuruş
      if (wasCrit) {
        final pattern = onHapticPattern;
        if (pattern != null) {
          pattern(const [0, 60]);
        } else {
          onHaptic?.call(50); // desen desteklemeyen host: tek uzun vuruş yedeği
        }
      } else {
        onHaptic?.call(10);
      }
      if (twist == TwistType.zitakis) _zitFlip = !_zitFlip;
    } else {
      combo = 0;
      // SIÇRAYAN: bırakılan blok bir kez en yakın hizaya toparlanır (affedici)
      var placed = res.placed!;
      if (twist == TwistType.sicrayan && top.w > 0) {
        final gap = (top.x + top.w / 2) - (placed.x + placed.w / 2);
        final nudge = gap.clamp(-8.0, 8.0);
        placed = Block(placed.x + nudge, placed.w);
      }
      blocks.add(placed);
      _markSquash(); // juice (PB-016): yerleştirme squash&stretch
      for (final c in res.cuts) {
        debris.add(Debris(c.x, y, c.w, bh, -40 * scale,
            (_rnd.nextDouble() < 0.5 ? -1 : 1) * (2.5 + _rnd.nextDouble() * 3.5), blockHue(idx).toDouble()));
        burst(c.x + c.w / 2, y + bh / 2, c.w, blockHue(idx), 10);
      }
      shake = math.min(7, 2 + res.cuts.length * 2);
    }

    score = blocks.length - 1;
    bestRun = math.max(bestRun, score);
    // ALTIN YAĞMURU: altın blok her yerleştirmede para patlaması
    if (_goldNow) {
      goldBlocks++;
      coinBurst(blocks.last.x + blocks.last.w / 2, y, 8);
      popupText('+ALTIN', blocks.last.x + blocks.last.w / 2, y - 24 * scale, 48);
      _goldNow = false;
    }
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
  ({int blocks, int perfects, bool reached, int crits, int goldBlocks}) detailedResult() =>
      (blocks: score, perfects: perfects, reached: state == EngineState.won, crits: crits, goldBlocks: goldBlocks);

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

  /// juice (PB-016): yerleşen son blokta 120ms squash&stretch işaretle.
  void _markSquash() {
    squashIdx = blocks.length - 1;
    squashT = 0.12;
  }

  /// juice (PB-016): mükemmel konfeti patlaması (12 parça).
  void _confettiBurst(double cx, double cy, int n, int hue) {
    for (var i = 0; i < n; i++) {
      confetti.add(Confetti(
        cx + (_fxRnd.nextDouble() - 0.5) * 30,
        cy,
        (_fxRnd.nextDouble() - 0.5) * 260,
        -(140 + _fxRnd.nextDouble() * 200),
        (_fxRnd.nextDouble() - 0.5) * 10,
        (5 + _fxRnd.nextDouble() * 6) * scale,
        (8 + _fxRnd.nextDouble() * 8) * scale,
        ((hue + 40 * (_fxRnd.nextDouble() - 0.5)) % 360 + 360) % 360,
        0.8 + _fxRnd.nextDouble() * 0.4,
        rot: _fxRnd.nextDouble() * 6.28,
      ));
    }
  }

  /// juice (PB-016): mükemmel üzerinde yükselen yıldız izi (yerçekimsiz parıltı).
  void _starTrail(double cx, double cy, int hue) {
    for (var i = 0; i < 6; i++) {
      particles.add(Particle(
        cx + (_fxRnd.nextDouble() - 0.5) * 44,
        cy - _fxRnd.nextDouble() * 12,
        (_fxRnd.nextDouble() - 0.5) * 60,
        -(28 + _fxRnd.nextDouble() * 56),
        0.7 + _fxRnd.nextDouble() * 0.35,
        (3 + _fxRnd.nextDouble() * 3) * scale,
        hue,
      )..star = true);
    }
  }

  void popupText(String text, double x, double y, int hue) {
    popups.add(Popup(text, x, y, hue));
  }

  /* --------------------------- Güncelleme --------------------------- */

  /// GÖLGE BLOK: gerçek bloğun 1.6 katı hızla dolaşan hayalet ikizi.
  /// Yalnızca görsel bir aldatmacadır — yerleştirme/skor hiçbir kuralı etkilemez.
  void _stepGhost(Moving g, Block top, int placed, double dt) {
    final b = movingBounds(top);
    final speed = travelRange(top.w) * 0.5 * speedMultiplier(placed) * 1.6;
    g.x += g.dir * speed * dt;
    if (g.x >= b.maxX) {
      g.x = b.maxX;
      g.dir = -1;
    } else if (g.x <= b.minX) {
      g.x = b.minX;
      g.dir = 1;
    }
  }

  void tick(double dt0) {
    var dt = dt0;
    var fxDt = dt0; // efekt saati: hit-stop'ta durmaz, ağır çekimde yavaşlar
    // juice: hit-stop ÖNCE uygulanır — ağır çekim çarpanını ezmesin
    if (hitStop > 0) {
      final consume = math.min(hitStop, dt0);
      hitStop -= consume;
      dt = dt0 - consume;
    }
    if (slowTimer > 0) {
      slowTimer -= dt;
      dt *= 0.35; // ağır çekim anı
      fxDt *= 0.35;
    }
    // juice (PB-016): squash/flaş zamanlayıcıları hit-stop'tan bağımsız akar
    if (squashT > 0) squashT = math.max(0, squashT - fxDt);
    if (flashT > 0) flashT = math.max(0, flashT - fxDt);
    time += dt;
    // ruzgargulu görsel açı salınımı — spec: ±15° (toparlanma: oturan blok düz çizilir)
    if (twist == TwistType.ruzgargulu) {
      spawnTilt = math.sin(time * 3) * 15 * math.pi / 180;
    } else {
      spawnTilt = 0;
    }

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
      if (ghost != null) _stepGhost(ghost!, top, placed, dt);
      if (def?.modifier == 'ruzgar') {
        final b = movingBounds(top);
        moving!.x += math.sin(time * 2.1) * travelRange(top.w) * 0.14 * dt * 6;
        moving!.x = clamp(moving!.x, b.minX, b.maxX);
      }
      // DAR GEÇİT: uçuşta da daralan duvarlarda seker — stepMoving tam genişlikte
      // sektiği için çizili duvarların ötesine taşan geziyi burada daralt
      if (twist == TwistType.dargecit) {
        final (dMin, dMax) = dargecitBounds(top);
        if (moving!.x <= dMin) {
          moving!.x = dMin;
          moving!.dir = 1;
        } else if (moving!.x >= dMax) {
          moving!.x = dMax;
          moving!.dir = -1;
        }
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

    shake = math.max(0, shake - fxDt * 55);

    for (var i = debris.length - 1; i >= 0; i--) {
      final d = debris[i];
      d.vy += 1500 * scale * fxDt;
      d.y += d.vy * fxDt;
      d.rot += d.vr * fxDt;
      d.life += fxDt;
      if (d.y > h + 300) debris.removeAt(i);
    }
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      if (!p.star) p.vy += 900 * scale * fxDt; // yıldız izi yerçekimsiz süzülür
      p.x += p.vx * fxDt;
      p.y += p.vy * fxDt;
      p.life += fxDt;
      if (p.life >= p.max) particles.removeAt(i);
    }
    for (var i = rings.length - 1; i >= 0; i--) {
      final r = rings[i];
      r.life += fxDt;
      r.r += 340 * scale * fxDt;
      if (r.life >= r.max) rings.removeAt(i);
    }
    for (var i = popups.length - 1; i >= 0; i--) {
      final q = popups[i];
      q.life += fxDt;
      q.y -= 42 * scale * fxDt;
      if (q.life >= q.max) popups.removeAt(i);
    }
    for (var i = confetti.length - 1; i >= 0; i--) {
      final cf = confetti[i];
      cf.vy += 60 * fxDt;
      cf.x += cf.vx * fxDt;
      cf.y += cf.vy * fxDt;
      cf.rot += cf.vr * fxDt;
      cf.life += fxDt;
      if (cf.life >= cf.max || cf.y > h + 40) confetti.removeAt(i);
    }
    for (var i = 0; i < weather.length; i++) {
      final wb = weather[i];
      wb.y += wb.sp * fxDt;
      wb.x += math.sin(time * 0.8 + wb.ph) * 14 * fxDt;
      if (wb.kind == 'embers') {
        if (wb.y < -20) weather[i] = newWeatherBit(wb.kind, false);
      } else if (wb.y > h + 20) {
        weather[i] = newWeatherBit(wb.kind, false);
      }
    }
    for (final cl in clouds) {
      cl.x += cl.sp * fxDt;
      if (cl.x > w + cl.rx) cl.x = -cl.rx;
      if (cl.x < -cl.rx) cl.x = w + cl.rx;
    }
  }
}
