import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/map/map3d.dart';
import 'package:stack_tower_game/services/storage.dart';

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
