/// PB-029 görsel kanıt: inşaatlı harita anlık görüntüsü üretir.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/map/construction.dart';
import 'package:stack_tower_game/map/map3d.dart';
import 'package:stack_tower_game/screens/map_screen.dart';
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

  test('PB-029 yükselme: 1.2s ease-out, süre bitince sabit', () {
    final session = GameSession(MemoryStorage());
    prog.completeLevel(session.state, levelDef(0),
        blocks: 10, perfects: 5, reached: true, stars: 3);
    final scene = MapScene(session);
    scene.startRise(0);
    expect(scene.riseT, 0);
    scene.updateRise(0.6);
    expect(scene.riseT, closeTo(0.5, 1e-9));
    scene.updateRise(0.6);
    expect(scene.riseT, 1.0);
    scene.updateRise(0.6); // tavan
    expect(scene.riseT, 1.0);
  });

  test('PB-029 yükselme görünür: animasyon karesi oturmuş kareden farklı', () async {
    final session = GameSession(MemoryStorage());
    for (var i = 0; i < 2; i++) {
      prog.completeLevel(session.state, levelDef(i),
          blocks: 10, perfects: 5, reached: true, stars: 3);
    }
    Future<List<int>> frameAt(double riseT) async {
      final scene = MapScene(session);
      scene.startRise(1);
      scene.updateRise(1.2 * riseT);
      final cam = MapCamera();
      const size = Size(540, 1200);
      cam.w = size.width;
      cam.h = size.height;
      cam.update(scene, 0.016, snap: true);
      cam.update(scene, 0.016, snap: false);
      final rec = ui.PictureRecorder();
      MapScenePainter(scene, cam, 1.2, repaint: _Noop()).paint(Canvas(rec), size);
      final img = await rec.endRecording().toImage(540, 1200);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    }

    final rising = await frameAt(0.15);
    File('.project-brain/evidence/PB-029/map_rise.png')
        .writeAsBytesSync(rising); // kanıt: yükselme anı
    final settled = await frameAt(1.0);
    expect(rising.length, greaterThan(2000));
    expect(rising, isNot(equals(settled)),
        reason: 'yükselen parça oturmuş parçadan farklı çizilmeli');
  });

  testWidgets('PB-029 [accessibility]: blueprint ipucu metinle okunur', (tester) async {
    final session = GameSession(MemoryStorage());
    prog.completeLevel(session.state, levelDef(0),
        blocks: 10, perfects: 5, reached: true, stars: 3);
    session.persist();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: const MaterialApp(home: MapScreen()),
    ));
    await tester.pump();
    expect(find.textContaining('SIRADA: IŞIK EVİ · 1/4'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.ancestor(
        of: find.textContaining('SIRADA:'),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(semantics.properties.label, contains('Burada ne yükselecek?'));
    expect(semantics.properties.label, contains('Sıradaki parça: duvar'));
  });
}
