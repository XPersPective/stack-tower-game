/// Antoloji türlerinin görsel anlık görüntülerini üretir (evidence + görsel regresyon).
/// Çıktı: .project-brain/evidence/PB-022/`<kind>`.png
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/catcher_game.dart';
import 'package:stack_tower_game/game/kinds/launch_game.dart';
import 'package:stack_tower_game/game/kinds/merge_game.dart';
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

Future<void> _snapshot(MiniGame game, LevelDef def, String name,
    {int ticks = 90, Size size = const Size(540, 1200)}) async {
  game.resize(size.width, size.height);
  game.start(def, host: _Host(), shields: 1);
  for (var i = 0; i < ticks; i++) {
    game.tick(1 / 60);
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  game.render(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('.project-brain/evidence/PB-022');
  dir.createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('CATCH sahne anlık görüntüsü üretilir', () async {
    await _snapshot(CatcherGame(), levelDef(0), 'catch');
    expect(File('.project-brain/evidence/PB-022/catch.png').lengthSync(), greaterThan(2000));
  });

  test('RING sahne anlık görüntüsü üretilir', () async {
    await _snapshot(RingGame(), levelDef(1), 'ring');
    expect(File('.project-brain/evidence/PB-022/ring.png').lengthSync(), greaterThan(2000));
  });

  test('LAUNCH sahne anlık görüntüsü üretilir', () async {
    await _snapshot(LaunchGame(), levelDef(3), 'launch');
    expect(File('.project-brain/evidence/PB-022/launch.png').lengthSync(), greaterThan(2000));
  });

  test('MERGE sahne anlık görüntüsü üretilir', () async {
    await _snapshot(MergeGame(), levelDef(4), 'merge');
    expect(File('.project-brain/evidence/PB-022/merge.png').lengthSync(), greaterThan(2000));
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
    Directory('.project-brain/evidence/PB-022').createSync(recursive: true);
    File('.project-brain/evidence/PB-022/stack.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(File('.project-brain/evidence/PB-022/stack.png').lengthSync(), greaterThan(2000));
  });
}
