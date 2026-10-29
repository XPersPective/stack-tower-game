import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/map/map3d.dart';
import 'package:stack_tower_game/screens/map_screen.dart' show lockedWorldHint;
import 'package:stack_tower_game/services/storage.dart';

class _Noop extends ChangeNotifier {}

Future<List<int>> _frame(MapScene scene, double t) async {
  final cam = MapCamera();
  const size = Size(540, 1200);
  cam.w = size.width;
  cam.h = size.height;
  cam.update(scene, 0.016, snap: true);
  cam.update(scene, 0.016, snap: false);
  final rec = ui.PictureRecorder();
  MapScenePainter(scene, cam, t, repaint: _Noop()).paint(Canvas(rec), size);
  final img = await rec.endRecording().toImage(540, 1200);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  test('kamera kurulumu: odak odak adaya kilitlenir ve izdüşüm yakın olur', () {
    final scene = MapScene(GameSession(MemoryStorage()));
    final cam = MapCamera();
    cam.w = 1080;
    cam.h = 2400;
    cam.update(scene, 0.016, snap: true);
    cam.update(scene, 0.016, snap: false);

    final isl = scene.islands[scene.focusStage];
    final top =
        cam.project(Offset3(isl.x, isl.y - isl.r, isl.z));
    expect(top, isNotNull, reason: 'ada üstü izdüşümü null — kamera/izdüşüm hatası');
    final rScreen = isl.r * top!.s;
    expect(rScreen, greaterThan(100), reason: 'ada ekran yarıçapı çok küçük: $rScreen');
    // düğüm noktaları da görünür olmalı
    final visible = scene.nodes.where((n) => cam.project(Offset3(n.x, n.y, n.z)) != null).length;
    expect(visible, greaterThan(0), reason: 'görünür düğüm yok');
  });

  test('PB-019: sis yoğunluğu kilitli adada >0, açık adada 0', () {
    expect(MapScenePainter.fogStrength(open: true, time: 1.7), 0);
    for (final t in [0.0, 0.8, 1.9, 4.2]) {
      final a = MapScenePainter.fogStrength(open: false, time: t);
      expect(a, inInclusiveRange(0.10, 0.145), reason: 't=$t');
    }
  });

  test('PB-019: kilitli ada sisi animasyonlu (kareler farklı)', () async {
    final scene = MapScene(GameSession(MemoryStorage()));
    // ilk ada açık, ikinci ada kilitli
    final locked = scene.islands[1];
    scene.setFocus(1);
    expect(locked.open, isFalse);
    final a = await _frame(scene, 0.0);
    final b = await _frame(scene, 1.3);
    expect(a, isNot(equals(b)), reason: 'sis salınımı kareyi değiştirmeli');
    // görsel kanıt
    final dir = Directory(Platform.environment['PB_EVIDENCE'] == '1'
        ? '.project-brain/evidence/PB-019'
        : '.cache/runs/snapshots')
      ..createSync(recursive: true);
    File('${dir.path}/locked_fog.png').writeAsBytesSync(a);
  });

  test('PB-019: açık adada mikro-animasyon var (kareler farklı)', () async {
    final session = GameSession(MemoryStorage());
    for (var i = 0; i < 4; i++) {
      prog.completeLevel(session.state, levelDef(i),
          blocks: 10, perfects: 5, reached: true, stars: 3);
    }
    final scene = MapScene(session);
    expect(scene.islands[0].open, isTrue);
    final a = await _frame(scene, 0.0);
    final b = await _frame(scene, 2.1);
    expect(a, isNot(equals(b)));
  });

  test('PB-019: kilitli dünya ipucu teaser\'ın yarısı + …', () {
    for (var stage = 1; stage < kStageCount; stage++) {
      final full = kWorldTeaser[stage];
      final hint = lockedWorldHint(stage);
      expect(hint.endsWith('…'), isTrue);
      expect(hint.length, lessThan(full.length));
      expect(full.startsWith(hint.substring(0, hint.length - 1).trimRight()), isTrue,
          reason: 'ipucu teaser\'ın başından gelmeli (stage $stage)');
    }
  });

  test('hitTest: düğüm ekran koordinatında node:i döner', () {
    final scene = MapScene(GameSession(MemoryStorage()));
    final cam = MapCamera();
    cam.w = 1080;
    cam.h = 2400;
    cam.update(scene, 0.016, snap: true);
    cam.update(scene, 0.016, snap: false);
    // düğümleri elle projekte edip screen doldur
    for (final nd in scene.nodes) {
      final p = cam.project(Offset3(nd.x, nd.y, nd.z));
      if (p != null) {
        nd.screen = Offset(p.x, p.y);
        nd.screenR = (nd.isl.r * p.s).clamp(7.0, 60.0);
        break;
      }
    }
    final nd = scene.nodes.firstWhere((n) => n.screen != null);
    final hit = hitTest(scene, Offset(nd.screen!.dx + 3, nd.screen!.dy + 3));
    expect(hit, 'node:${nd.i}');
  });
}
