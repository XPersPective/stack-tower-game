/// Antoloji türlerinin görsel anlık görüntülerini üretir (evidence + görsel regresyon).
/// Çıktı: .project-brain/evidence/PB-022/`<kind>`.png (İlk 5 tür)
///        .project-brain/evidence/PB-028/`<kind>`.png (BALANCE/DEFEND/RHYTHM)
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/balance_game.dart';
import 'package:stack_tower_game/game/kinds/catcher_game.dart';
import 'package:stack_tower_game/game/kinds/defend_game.dart';
import 'package:stack_tower_game/game/kinds/launch_game.dart';
import 'package:stack_tower_game/game/kinds/merge_game.dart';
import 'package:stack_tower_game/game/kinds/rhythm_game.dart';
import 'package:stack_tower_game/game/kinds/ring_game.dart';
import 'package:stack_tower_game/game/kinds/stack_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';

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

void main() {
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
}
