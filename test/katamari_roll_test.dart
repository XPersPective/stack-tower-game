/// PB-043 — KATAMARİ ROLL motor testleri: yön kontrolü, yutma/büyüme,
/// ezme bonusu, büyük blok tehlikesi, kalkan, kazanma/kayıp.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/katamari_roll_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';
import 'package:stack_tower_game/theme/tokens.dart';

class FakeRollHost implements MiniGameHost {
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

typedef RollBundle = (KatamariRollGame, FakeRollHost);

KatamariRollGame makeGame(FakeRollHost host, {int target = 9999}) {
  final g = KatamariRollGame();
  g.resize(kW, kH);
  g.start(LevelDef(
      i: 999, stage: 9, idx: 0, num: 1000, theme: kThemes[0],
      target: target, speed: 1.0, tol: 6, modifier: 'normal',
      coins: 0, box: false, name: 't'), host: host);
  return g;
}

void main() {
  test('tür kimliği: katamariRoll', () {
    expect(KatamariRollGame().kind, GameKind.katamariRoll);
  });

  test('dokun yönü: sol yarı sola, sağ yarı sağa ivme', () {
    final host = FakeRollHost();
    final g = makeGame(host);
    g.onTap(const Offset(60, 400)); // sol
    expect(g.vx, lessThan(0));
    expect(g.facing, -1);
    g.onTap(const Offset(340, 400)); // sağ
    expect(g.facing, 1);
  });

  test('yutma: küçük blok → skor + büyüme', () {
    final host = FakeRollHost();
    final g = makeGame(host);
    g.blocks.clear();
    g.blocks.add(RollBlock(g.x, g.y, 1, 200)); // top boyut 1 → yenebilir
    final r0 = g.ballR;
    g.tick(1 / 60);
    expect(g.eatenForTest, 1);
    expect(g.score, 1);
    expect(g.ballR, greaterThan(r0), reason: 'büyüdü');
    expect(host.sounds, contains('coin'));
  });

  test('ezme bonusu: boyundan çok küçük blok +2', () {
    final host = FakeRollHost();
    final g = makeGame(host);
    // topu büyüt: 4 yutum → boyut 2
    for (var i = 0; i < 4; i++) {
      g.blocks.clear();
      g.blocks.add(RollBlock(g.x, g.y, 1, 200));
      g.tick(1 / 60);
    }
    expect(g.ballSize, 2);
    // boyut 1 blok: küçük → ezme +2
    g.blocks.clear();
    g.blocks.add(RollBlock(g.x, g.y, 1, 200));
    final s0 = g.score;
    g.tick(1 / 60);
    expect(g.score - s0, 2);
  });

  test('büyük blok: kalkan sekmesi; kalkansız kayıp', () {
    final host = FakeRollHost();
    final g = makeGame(host);
    g.invuln = 0;
    g.blocks.clear();
    g.blocks.add(RollBlock(g.x, g.y, 5, 200)); // top 1 → ölümcül
    g.tick(1 / 60);
    expect(g.shieldsLeft, 0);
    expect(g.isOver, isFalse);
    // kalkansız
    g.setShieldsForTest(0);
    g.invuln = 0;
    g.blocks.clear();
    g.blocks.add(RollBlock(g.x, g.y, 5, 200));
    g.tick(1 / 60);
    expect(g.isOver, isTrue);
    expect(host.events, contains('lose'));
  });

  test('kazanma: hedef kadar skor', () {
    final host = FakeRollHost();
    final g = makeGame(host, target: 3);
    // 3 blok yut
    for (var i = 0; i < 3 && !g.isOver; i++) {
      g.blocks.clear();
      g.blocks.add(RollBlock(g.x, g.y, 1, 200));
      g.tick(1 / 60);
    }
    expect(g.isOver, isTrue);
    expect(g.result().reached, isTrue);
    expect(g.score, greaterThanOrEqualTo(3));
  });
}
