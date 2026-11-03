/// PB-043 — YERÇEKİMİ KAPISI motor testleri: yerçekimi ters dönme,
/// bant sürüşü, engel çarpışması, kalkan, mesafe skoru, kazanma.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/gravity_flip_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';
import 'package:stack_tower_game/theme/tokens.dart';

/// Uzun hedefli yapay bölüm — mesafe-kazanması testleri bozmasın.
LevelDef longDef() => LevelDef(
    i: 999,
    stage: 9,
    idx: 0,
    num: 1000,
    theme: kThemes[0],
    target: 9999,
    speed: 1.0,
    tol: 6,
    modifier: 'normal',
    coins: 0,
    box: false,
    name: 'test');

class _FakeHost implements MiniGameHost {
  final List<String> sounds = [];
  final List<String> events = [];
  @override
  void playSound(String name, {int combo = 1}) => sounds.add(name);
  @override
  void haptic(int ms) {}
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) => events.add(name);
}

const double kW = 400, kH = 800;

typedef FlipBundle = (GravityFlipGame, _FakeHost);

FlipBundle makeGame({LevelDef? def}) {
  final host = _FakeHost();
  final g = GravityFlipGame();
  g.resize(kW, kH);
  g.start(def ?? levelDef(0), host: host);
  return (g, host);
}

void main() {
  test('tür kimliği: gravityFlip', () {
    expect(GravityFlipGame().kind, GameKind.gravityFlip);
  });

  test('dokun → yerçekimi ters döner, top karşı banda gider', () {
    final (g, _) = makeGame(def: longDef());
    expect(g.grav, 1);
    expect(g.ballY, closeTo(g.floorY - g.ballR, 2), reason: 'zeminde başlar');
    g.onTap(const Offset(200, 400));
    expect(g.grav, -1);
    for (var i = 0; i < 120; i++) {
      g.tick(1 / 60);
    }
    expect(g.ballY, closeTo(g.ceilY + g.ballR, 2),
        reason: 'tavana yapıştı');
    g.onTap(const Offset(200, 400));
    for (var i = 0; i < 120; i++) {
      g.tick(1 / 60);
    }
    expect(g.ballY, closeTo(g.floorY - g.ballR, 2), reason: 'zemine döndü');
  });

  test('mesafe akar: skor artar', () {
    final (g, _) = makeGame();
    g.obstaclesForTest.clear(); // temiz koridor
    g.nextObstacleX = 1073741824.0; // üretimi sustur
    final s0 = g.score;
    for (var i = 0; i < 120; i++) {
      g.tick(1 / 60);
    }
    expect(g.score, greaterThan(s0));
  });

  test('engel çarpması: kalkan → dokunulmazlık; kalkansız → kayıp', () {
    final (g, host) = makeGame();
    g.invulnForTest = 0.0;
    // zemin bloğunu topun hizasına koy
    g.obstaclesForTest.clear();
    g.obstaclesForTest.add(Obstacle(g.ballX(), 120, true));
    g.tick(1 / 60);
    expect(g.shieldsLeft, 0);
    expect(g.isOver, isFalse);
    expect(g.invulnForTest, greaterThan(0));
    // dokunulmazlık süresi bitince tekrar → kayıp
    g.setShieldsForTest(0);
    g.invulnForTest = 0.0;
    g.obstaclesForTest.clear();
    g.obstaclesForTest.add(Obstacle(g.ballX(), 120, true));
    g.tick(1 / 60);
    expect(g.isOver, isTrue);
    expect(host.events, contains('lose'));
  });

  test('orta sütun: uçuş ortasında çarpar', () {
    final (g, host) = makeGame(def: longDef());
    g.setShieldsForTest(0);
    g.invulnForTest = 0.0;
    g.obstaclesForTest.clear();
    g.obstaclesForTest.add(Obstacle(g.ballX(), 300, true, midColumn: true));
    // topu koridor ortasına koy (yön değiştirirken tam sütun hizasında)
    g.ballY = (g.floorY + g.ceilY) / 2;
    g.vy = 0;
    g.tick(1 / 60);
    expect(g.isOver, isTrue);
  });

  test('kazanma: temiz koridorda hedefe ulaş', () {
    final (g, host) = makeGame();
    g.obstaclesForTest.clear();
    g.nextObstacleX = 1073741824.0;
    var guard = 0;
    while (!g.isOver && guard < 60 * 240) {
      guard++;
      g.tick(1 / 60);
    }
    expect(g.isOver, isTrue);
    expect(g.result().reached, isTrue);
    expect(g.score, greaterThanOrEqualTo(g.target));
    expect(host.events, contains('win'));
  });
}
