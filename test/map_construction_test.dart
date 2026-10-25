/// PB-029 görsel kanıt: inşaatlı harita anlık görüntüsü üretir.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/map/construction.dart';
import 'package:stack_tower_game/map/map3d.dart';
import 'package:stack_tower_game/services/storage.dart';

class _Noop extends ChangeNotifier {}

Future<void> _renderMap(GameSession session, String name) async {
  final scene = MapScene(session);
  final cam = MapCamera();
  const size = Size(540, 1200);
  cam.w = size.width;
  cam.h = size.height;
  cam.update(scene, 0.016, snap: true);
  cam.update(scene, 0.016, snap: false);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  MapScenePainter(scene, cam, 1.2, repaint: _Noop()).paint(canvas, size);
  final image = await recorder.endRecording().toImage(540, 1200);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  Directory('.project-brain/evidence/PB-029').createSync(recursive: true);
  File('.project-brain/evidence/PB-029/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('boş dünya: blueprint silüetleri çizilir', () async {
    await _renderMap(GameSession(MemoryStorage()), 'map_blueprint');
    expect(File('.project-brain/evidence/PB-029/map_blueprint.png').lengthSync(),
        greaterThan(2000));
  });

  test('6 bölüm bitmiş dünya: ilk yapı tamam, ikincisi 2 parça', () async {
    final session = GameSession(MemoryStorage());
    for (var i = 0; i < 6; i++) {
      prog.completeLevel(session.state, levelDef(i),
          blocks: 10, perfects: 5, reached: true, stars: 3);
    }
    session.persist();
    expect(piecesBuilt(session.state, 0, 0), 4, reason: 'IŞIK EVİ tamamlanmış');
    expect(structureComplete(session.state, 0, 0), isTrue);
    expect(piecesBuilt(session.state, 0, 1), 2, reason: 'kule 2 parça');
    expect(worldBuildRatio(session.state, 0), closeTo(6 / 15, 1e-9));
    await _renderMap(session, 'map_built6');
    expect(File('.project-brain/evidence/PB-029/map_built6.png').lengthSync(),
        greaterThan(2000));
  });

  test('tüm dünya bitmiş: anıt dahil 4 yapı tamamlanır', () {
    final session = GameSession(MemoryStorage());
    for (var i = 0; i < 15; i++) {
      prog.completeLevel(session.state, levelDef(i),
          blocks: 12, perfects: 8, reached: true, stars: 3);
    }
    expect(structuresComplete(session.state, 0), 4);
    expect(realmStructures(session.state), 4);
    expect(worldBuildRatio(session.state, 0), 1.0);
  });
}
