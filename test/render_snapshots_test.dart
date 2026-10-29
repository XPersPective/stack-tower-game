/// Antoloji türlerinin görsel anlık görüntülerini üretir (evidence + görsel regresyon).
/// Çıktı: .project-brain/evidence/PB-022/`<kind>`.png (İlk 5 tür)
///        .project-brain/evidence/PB-028/`<kind>`.png (BALANCE/DEFEND/RHYTHM)
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/balance_game.dart';
import 'package:stack_tower_game/game/kinds/catcher_game.dart';
import 'package:stack_tower_game/game/kinds/defend_game.dart';
import 'package:stack_tower_game/game/kinds/merge_game.dart';
import 'package:stack_tower_game/game/kinds/rhythm_game.dart';
import 'package:stack_tower_game/game/kinds/ring_game.dart';
import 'package:stack_tower_game/game/kinds/stack_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';
import 'package:stack_tower_game/game/kinds/launch_game.dart' show LaunchGame, Target;

class _Host implements MiniGameHost {
  @override
  void playSound(String name, {int combo = 1}) {}
  @override
  void haptic(int ms) {}
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) {}
}

/// Kanıt PNG'leri normal test koşusunda evidence'a DOKUNMAZ (inceleme bulgusu:
/// her koşuda yeniden yazıp PB-022/028 kanıt dosyalarını kirletme); `.cache/runs`
/// altına yazar. `PB_EVIDENCE=1` ile koşulunca evidence dizinine yazar.
String _resolveOut(String dir) =>
    Platform.environment['PB_EVIDENCE'] == '1' ? dir : '.cache/runs/snapshots';
File _pngPath(String dir, String name) => File('${_resolveOut(dir)}/$name.png');

Future<void> _snapshot(MiniGame game, LevelDef def, String name,
    {int ticks = 90,
    Size size = const Size(540, 1200),
    String outDir = '.project-brain/evidence/PB-022',
    void Function(MiniGame game)? interact}) async {
  game.resize(size.width, size.height);
  game.start(def, host: _Host(), shields: 1);
  for (var i = 0; i < ticks; i++) {
    game.tick(1 / 60);
  }
  interact?.call(game);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  game.render(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory(_resolveOut(outDir));
  dir.createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Kanıt PNG'lerinde marka fontu görünsün (test VM'de varsayılan font yok).
Future<void> _loadBrandFont() async {
  final file = File('assets/fonts/Inter.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('Inter')..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadBrandFont);

  test('CATCH sahne anlık görüntüsü üretilir', () async {
    await _snapshot(CatcherGame(), levelDef(0), 'catch');
    expect(_pngPath('.project-brain/evidence/PB-022', 'catch').lengthSync(), greaterThan(2000));
  });

  test('RING sahne anlık görüntüsü üretilir', () async {
    await _snapshot(RingGame(), levelDef(1), 'ring');
    expect(_pngPath('.project-brain/evidence/PB-022', 'ring').lengthSync(), greaterThan(2000));
  });

  test('LAUNCH sahne anlık görüntüsü üretilir', () async {
    await _snapshot(LaunchGame(), levelDef(3), 'launch');
    expect(_pngPath('.project-brain/evidence/PB-022', 'launch').lengthSync(), greaterThan(2000));
  });

  test('MERGE sahne anlık görüntüsü üretilir', () async {
    await _snapshot(MergeGame(), levelDef(4), 'merge');
    expect(_pngPath('.project-brain/evidence/PB-022', 'merge').lengthSync(), greaterThan(2000));
  });

  test('STACK sahne anlık görüntüsü üretilir', () async {
    final g = StackGame();
    g.resize(540, 1200);
    g.start(levelDef(2), host: _Host(), shields: 1);
    // birkaç blok diz
    for (var i = 0; i < 4; i++) {
      final e = g.engine;
      e.moving!.x = e.blocks.last.x;
      e.moving!.w = e.blocks.last.w;
      e.drop();
      g.tick(1 / 60);
    }
    g.tick(1 / 60);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    g.render(canvas, const Size(540, 1200));
    final image = await recorder.endRecording().toImage(540, 1200);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_resolveOut('.project-brain/evidence/PB-022')).createSync(recursive: true);
    _pngPath('.project-brain/evidence/PB-022', 'stack').writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(_pngPath('.project-brain/evidence/PB-022', 'stack').lengthSync(), greaterThan(2000));
  });

  test('BALANCE sahne anlık görüntüsü üretilir (tahterevalli + ağırlık)', () async {
    // 40 tick sürükleme bırak, sonra sola ağırlık ver → eğik tahterevalli
    await _snapshot(BalanceGame(), levelDef(5), 'balance',
        ticks: 40,
        outDir: '.project-brain/evidence/PB-028',
        interact: (g) {
          g.onTap(const Offset(120, 600));
          for (var i = 0; i < 25; i++) {
            g.tick(1 / 60);
          }
        });
    expect(_pngPath('.project-brain/evidence/PB-028', 'balance').lengthSync(), greaterThan(2000));
  });

  test('DEFEND sahne anlık görüntüsü üretilir (dalga + kalkan halkası)', () async {
    // 70 tick dalgaları yaklaştır, sonra dokun → kalkan penceresi + burst görünür
    await _snapshot(DefendGame(), levelDef(6), 'defend',
        ticks: 70,
        outDir: '.project-brain/evidence/PB-028',
        interact: (g) {
          g.onTap(const Offset(270, 600));
          for (var i = 0; i < 4; i++) {
            g.tick(1 / 60);
          }
        });
    expect(_pngPath('.project-brain/evidence/PB-028', 'defend').lengthSync(), greaterThan(2000));
  });

  test('RHYTHM sahne anlık görüntüsü üretilir (vuruş çizgisi + notalar)', () async {
    await _snapshot(RhythmGame(), levelDef(7), 'rhythm',
        ticks: 90, outDir: '.project-brain/evidence/PB-028');
    expect(_pngPath('.project-brain/evidence/PB-028', 'rhythm').lengthSync(), greaterThan(2000));
  });

  test('LAUNCH fırlatma izi kanıtı (PB-025)', () async {
    await _snapshot(LaunchGame(), levelDef(3), 'launch_flight',
        ticks: 4,
        outDir: '.project-brain/evidence/PB-025',
        interact: (g) {
          final l = g as LaunchGame;
          l.targetsForTest
            ..clear()
            ..add(Target(l.wForTest / 2, 300, 24));
          l.setAimForTest(-math.pi / 2, 0.9);
          l.fireForTest();
          for (var i = 0; i < 7; i++) {
            l.tick(1 / 60); // mermi + iz görünür
          }
        });
    expect(_pngPath('.project-brain/evidence/PB-025', 'launch_flight').lengthSync(),
        greaterThan(2000));
  });

  test('LAUNCH patlama kanıtı (PB-025)', () async {
    await _snapshot(LaunchGame(), levelDef(3), 'launch_boom',
        ticks: 4,
        outDir: '.project-brain/evidence/PB-025',
        interact: (g) {
          final l = g as LaunchGame;
          l.targetsForTest
            ..clear()
            ..add(Target(l.wForTest / 2, 300, 24));
          l.setAimForTest(-math.pi / 2, 0.9);
          l.fireForTest();
          for (var i = 0; i < 150 && l.score == 0; i++) {
            l.tick(1 / 60); // isabet anına kadar
          }
          for (var i = 0; i < 9; i++) {
            l.tick(1 / 60); // patlama halkası genişlesin (0.15s)
          }
        });
    expect(_pngPath('.project-brain/evidence/PB-025', 'launch_boom').lengthSync(),
        greaterThan(2000));
  });

  test('MERGE birleşme patlaması kanıtı (PB-026)', () async {
    await _snapshot(MergeGame(), levelDef(4), 'merge_pop',
        ticks: 10,
        outDir: '.project-brain/evidence/PB-026',
        interact: (g) {
          final m = g as MergeGame;
          for (var i = 0; i < MergeGame.cells; i++) {
            m.setCellForTest(i, null);
          }
          m.setCellForTest(0, 2);
          m.setCellForTest(1, 2);
          m.onTap(_cellCenter(0));
          m.onTap(_cellCenter(1));
          m.tick(1 / 60); // pop animasyonu başlar
        });
    expect(_pngPath('.project-brain/evidence/PB-026', 'merge_pop').lengthSync(),
        greaterThan(2000));
  });
}

/// MERGE tahta hücresi merkezi (540×1200 sahne, merge_game._boardRect ile aynı).
Offset _cellCenter(int cell) {
  const w = 540.0, h = 1200.0;
  final size = math.min(w * 0.86, h * 0.52);
  final left = (w - size) / 2;
  final top = h * 0.24;
  final cw = size / MergeGame.cols;
  final ch = size / MergeGame.rows;
  return Offset(left + (cell % MergeGame.cols) * cw + cw / 2,
      top + (cell ~/ MergeGame.cols) * ch + ch / 2);
}
