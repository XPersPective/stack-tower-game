/// PB-016 juice paketi görsel kanıtı + zamanlama/performans ölçümü.
/// Çıktı: .project-brain/evidence/PB-016/{perfect,crit,lose}.png
/// (PB_EVIDENCE=1 yoksa .cache/runs/snapshots — PB-022/028 kanıtları kirlenmez)
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/gameplay.dart';
import 'package:stack_tower_game/game/kinds/stack_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';
import 'package:stack_tower_game/game/scene_painter.dart';
import 'package:stack_tower_game/game/twists.dart';

String _resolveOut() =>
    Platform.environment['PB_EVIDENCE'] == '1' ? '.project-brain/evidence/PB-016' : '.cache/runs/snapshots';

Future<ui.Image> _renderImage(GamePlay e, Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  ScenePainter(GamePlayRepaint(e)).paint(canvas, size);
  return recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
}

Future<void> _writePng(GamePlay e, String name, {Size size = const Size(540, 1200)}) async {
  final image = await _renderImage(e, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory(_resolveOut())..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Ortalama parlaklık (0-255) — flaş katmanının gerçekten boyandığını doğrular.
Future<double> _meanLuminance(ui.Image img) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final b = data!.buffer.asUint8List();
  var sum = 0.0;
  for (var i = 0; i < b.length; i += 4) {
    sum += 0.2126 * b[i] + 0.7152 * b[i + 1] + 0.0722 * b[i + 2];
  }
  return sum / (b.length / 4);
}

/// Birkaç bloğu tam üstüne bırakır (mükemmel seri → kombo + kamera oturur).
void _stackPerfects(GamePlay e, int n) {
  for (var i = 0; i < n; i++) {
    e.moving!.x = e.blocks.last.x;
    e.moving!.w = e.blocks.last.w;
    e.drop();
    e.tick(0.2); // hit-stop'u tüket, sonraki hareketli blok otursun
  }
}

GamePlay _startPerfect(Size size, {TwistType? twist, int shields = 1}) {
  final e = GamePlay();
  e.resize(size.width, size.height);
  e.startLevel(levelDef(2), twistType: twist, shields: shields);
  _stackPerfects(e, 3);
  return e;
}

void main() {
  const size = Size(540, 1200);

  test('juice: mükemmel yerleşim — squash + tema flaşı + konfeti + yıldız izi', () async {
    final e = _startPerfect(size);
    e.moving!.x = e.blocks.last.x;
    e.moving!.w = e.blocks.last.w;
    e.drop();
    // kare, hit-stop/flaş/squash penceresinin İÇİNDE yakalanır (render anında)
    expect(e.flashT, greaterThan(0));
    expect(e.squashT, greaterThan(0));
    expect(e.confetti, isNotEmpty);
    expect(e.particles.where((p) => p.star), isNotEmpty);
    await _writePng(e, 'perfect');
    expect(File('${_resolveOut()}/perfect.png').lengthSync(), greaterThan(2000));
  });

  test('juice: flaş gerçekten boyanıyor — aynı sahne flaşlı/flaşsız parlaklık farkı', () async {
    final e = _startPerfect(size);
    e.moving!.x = e.blocks.last.x;
    e.moving!.w = e.blocks.last.w;
    e.drop();
    final withFlash = await _meanLuminance(await _renderImage(e, size));
    final alpha = e.flashAlpha;
    e.flashT = 0; // aynı sahne, flaş kapalı
    final withoutFlash = await _meanLuminance(await _renderImage(e, size));
    expect(alpha, 0.18);
    expect(withFlash, greaterThan(withoutFlash + 2),
        reason: 'tema flaşı (α=0.18) kareyi ölçülebilir biçimde aydınlatmalı');
  });

  test('juice: kritik vuruş — beyaz flaş 0.35 + çift halka + 40 parça', () async {
    final e = _startPerfect(size, twist: TwistType.kritik);
    e.critRoll = () => 0.1;
    e.moving!.x = e.blocks.last.x;
    e.moving!.w = e.blocks.last.w;
    e.drop();
    expect(e.flashWhite, isTrue);
    expect(e.flashAlpha, 0.35);
    await _writePng(e, 'crit');
    expect(File('${_resolveOut()}/crit.png').lengthSync(), greaterThan(2000));

    // kritik beyaz flaş (0.35), mükemmel tema flaşından (0.18) daha çok aydınlatır
    // — aynı sahne flaşlı/flaşsız ölçülür, parçacık sayısı karıştırmaz
    final critOn = await _meanLuminance(await _renderImage(e, size));
    e.flashT = 0;
    final critOff = await _meanLuminance(await _renderImage(e, size));
    final perfect = _startPerfect(size);
    perfect.moving!.x = perfect.blocks.last.x;
    perfect.moving!.w = perfect.blocks.last.w;
    perfect.drop();
    final perfectOn = await _meanLuminance(await _renderImage(perfect, size));
    perfect.flashT = 0;
    final perfectOff = await _meanLuminance(await _renderImage(perfect, size));
    expect(critOn - critOff, greaterThan(perfectOn - perfectOff),
        reason: 'beyaz 0.35 flaşı tema 0.18 flaşından daha güçlü aydınlatmalı');
  });

  test('juice: squash geometrisi — 120ms boyunca %12 genişler, alt kenar sabit', () {
    const block = Rect.fromLTWH(100, 500, 200, 40);
    final full = ScenePainter.squashedRect(block, 0.12);
    expect(full.width, closeTo(224, 1e-9)); // +%12
    expect(full.height, closeTo(35.2, 1e-9)); // -%12
    expect(full.center.dx, closeTo(block.center.dx, 1e-9)); // merkez sabit
    expect(full.bottom, closeTo(block.bottom, 1e-9)); // zemine oturur
    final mid = ScenePainter.squashedRect(block, 0.06);
    expect(mid.width, greaterThan(block.width));
    expect(mid.width, lessThan(full.width)); // easeOut: sönerek toparlanır
    expect(ScenePainter.squashedRect(block, 0), block); // süre bitince düz
  });

  test('juice: çökme — enkaz + 60ms haptic (flaş yok)', () async {
    final e = _startPerfect(size, shields: 0);
    final haptics = <int>[];
    e.onHaptic = haptics.add;
    e.moving!.x = e.moving!.x + 400; // tamamen ıskala → blok bütün düşer
    e.drop();
    for (var i = 0; i < 12; i++) {
      e.tick(1 / 60);
    }
    expect(e.state, EngineState.lost);
    expect(haptics, contains(60));
    expect(e.flashT, 0, reason: 'çökmede flaş yok — yalnız enkaz + sarsıntı');
    await _writePng(e, 'lose');
    expect(File('${_resolveOut()}/lose.png').lengthSync(), greaterThan(2000));
  });

  test('juice: hit-stop penceresinde dokunuş yok sayılır (garantili ıskalama önlenir)', () {
    final g = StackGame();
    g.resize(size.width, size.height);
    g.start(levelDef(2), host: _PatternHost([]), shields: 1);
    final e = g.engine;
    e.moving!.x = e.blocks.last.x;
    e.moving!.w = e.blocks.last.w;
    e.drop();
    expect(e.hitStop, greaterThan(0));
    expect(g.acceptsInput, isFalse, reason: 'hit-stop penceresi (≤70ms) kısa kilit');
    // pencere kapanınca giriş açılır — akışta ek adım yok
    for (var i = 0; i < 10; i++) {
      g.tick(1 / 60);
    }
    expect(g.acceptsInput, isTrue);
  });

  test('juice: kritik desen desteklemeyen host tek vuruş yedeği alır', () {
    final e = GamePlay();
    e.resize(size.width, size.height);
    e.startLevel(levelDef(2), twistType: TwistType.kritik);
    e.critRoll = () => 0.1;
    final ms = <int>[];
    e.onHaptic = ms.add;
    e.moving!.x = e.blocks.last.x;
    e.moving!.w = e.blocks.last.w;
    e.drop();
    expect(ms, contains(50), reason: 'desen yoksa kritik tek uzun vuruş');
  });

  test('juice: en yoğun karede (kritik + 40 parça + konfeti) boyama bütçesi', () async {
    final e = _startPerfect(size, twist: TwistType.kritik);
    e.critRoll = () => 0.1;
    e.moving!.x = e.blocks.last.x;
    e.moving!.w = e.blocks.last.w;
    e.drop(); // kritik: 40 parça + 2 halka + 12 konfeti + 6 yıldız + flaş
    final painter = ScenePainter(GamePlayRepaint(e));
    const frames = 120;

    // 1) Dart tarafı komut kaydı (kare bütçesinin ana göstergesi)
    double recordAvg() {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (var i = 0; i < 20; i++) {
        painter.paint(canvas, size); // ısınma
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < frames; i++) {
        painter.paint(canvas, size);
      }
      sw.stop();
      return sw.elapsedMicroseconds / frames / 1000;
    }

    final paintMs = recordAvg();
    // ignore: avoid_print
    print('juice paint avg=${paintMs.toStringAsFixed(3)}ms (kare bütçesi 16.6ms, yoğun kare)');
    expect(paintMs, lessThan(16.6),
        reason: 'yoğun juice karesi boyama bütçesini aşmamalı (${paintMs.toStringAsFixed(2)}ms)');

    // 2) Yazılım taraması (test VM'de CPU Skia — GPU süresi DEĞİL): juice'li kare
    //    aynı sahnenin efektsiz haline göre patolojik pahalı olmamalı (blur/shadow yok)
    Future<double> rasterAvg(GamePlay target) async {
      final p = ScenePainter(GamePlayRepaint(target));
      const n = 10;
      final sw = Stopwatch()..start();
      for (var i = 0; i < n; i++) {
        final rec = ui.PictureRecorder();
        p.paint(Canvas(rec), size);
        final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
        img.dispose();
      }
      sw.stop();
      return sw.elapsedMicroseconds / n / 1000;
    }

    final heavyRaster = await rasterAvg(e);
    e.flashT = 0;
    e.particles.clear();
    e.confetti.clear();
    e.rings.clear();
    e.debris.clear();
    final plainRaster = await rasterAvg(e);
    // ignore: avoid_print
    print('juice raster (CPU Skia): yoğun=${heavyRaster.toStringAsFixed(1)}ms '
        'düz=${plainRaster.toStringAsFixed(1)}ms oran=${(heavyRaster / plainRaster).toStringAsFixed(2)}');
    expect(heavyRaster, lessThan(plainRaster * 2),
        reason: 'juice katmanı tarama maliyetini 2 kattan fazla artırmamalı');
  });

  test('juice: StackGame adaptörü host desenini motora bağlar', () {
    final g = StackGame();
    g.resize(540, 1200);
    final patterns = <List<int>>[];
    g.start(levelDef(2), host: _PatternHost(patterns), shields: 1);
    expect(g.engine.onHapticPattern, isNotNull, reason: 'HapticPatternHost desteklenir');
  });
}

class _PatternHost implements MiniGameHost, HapticPatternHost {
  _PatternHost(this.patterns);
  final List<List<int>> patterns;
  @override
  void playSound(String name, {int combo = 1}) {}
  @override
  void haptic(int ms) {}
  @override
  void hapticPattern(List<int> onsetsMs) => patterns.add(onsetsMs);
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) {}
}
