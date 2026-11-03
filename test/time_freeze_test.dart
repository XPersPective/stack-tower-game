/// PB-043 — ZAMAN KIRICI motor testleri: dondurma, enerji, mermi kaçışı,
/// çarpışma/kalkan, mesafe skoru, kazanma.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/time_freeze_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';

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

typedef FreezeBundle = (TimeFreezeGame, _FakeHost);

FreezeBundle makeGame() {
  final host = _FakeHost();
  final g = TimeFreezeGame();
  g.resize(kW, kH);
  g.start(levelDef(0), host: host);
  return (g, host);
}

void main() {
  test('tür kimliği: timeFreeze + HoldGame', () {
    final g = TimeFreezeGame();
    expect(g.kind, GameKind.timeFreeze);
    expect(g, isA<HoldGame>());
  });

  test('basılı tut = zaman donar: mermiler sürünür, mesafe yavaşlar', () {
    final (g, host) = makeGame();
    g.onHoldStart(const Offset(200, 400));
    // mermi koy: sağa hızlı
    g.shards.clear();
    g.shards.add(Shard(50, g.shipY, 300, 8, 200));
    final scroll0 = g.scroll;
    final x0 = g.shards.first.x;
    for (var i = 0; i < 60; i++) {
      g.tick(1 / 60);
    }
    expect(g.shards.first.x - x0, lessThan(30),
        reason: 'donmada mermi %4 hızda sürünür');
    expect(g.scroll - scroll0, greaterThan(0), reason: 'gemi yine de süzülür');
    expect(g.freezeEnergy, lessThan(1), reason: 'enerji tüketildi');
    expect(host.sounds, contains('mystery'));
  });

  test('bırak = zaman akar: mermiler tam hız', () {
    final (g, _) = makeGame();
    g.onRelease(const Offset(200, 400));
    g.shards.clear();
    g.shards.add(Shard(50, g.shipY, 300, 8, 200));
    final x0 = g.shards.first.x;
    for (var i = 0; i < 30; i++) {
      g.tick(1 / 60);
    }
    expect(g.shards.first.x - x0, greaterThan(120), reason: 'tam hız akar');
  });

  test('gemi hedefe süzülür (hold noktası)', () {
    final (g, _) = makeGame();
    g.onHoldStart(const Offset(60, 400));
    for (var i = 0; i < 90; i++) {
      g.tick(1 / 60);
    }
    expect((g.shipX - 60).abs(), lessThan(24), reason: 'hedefe varır');
  });

  test('enerji biterse donma biter (holding false)', () {
    final (g, _) = makeGame();
    g.onHoldStart(const Offset(200, 400));
    var minEnergy = 1.0;
    var holdingAtMin = true;
    for (var i = 0; i < 60 * 3; i++) {
      g.tick(1 / 60); // 3 sn — enerji 2.5 sn'de biter
      if (g.freezeEnergy < minEnergy) {
        minEnergy = g.freezeEnergy;
        holdingAtMin = g.holding;
      }
    }
    expect(minEnergy, lessThan(0.05), reason: 'enerji tükenir');
    expect(holdingAtMin, isFalse, reason: 'enerji boşalınca donma biter');
    expect(g.freezeEnergy, greaterThan(minEnergy),
        reason: 'bırakınca şarj olur');
  });

  test('mesafe skoru: hedefe ulaşınca reached', () {
    final (g, host) = makeGame();
    g.shards.clear(); // temiz koridor
    var guard = 0;
    while (!g.isOver && guard < 60 * 120) {
      guard++;
      g.tick(1 / 60);
    }
    expect(g.isOver, isTrue);
    expect(g.result().reached, isTrue);
    expect(g.score, greaterThanOrEqualTo(g.target));
    expect(host.events, contains('win'));
  });

  test('mermi çarpması: kalkan → dokunulmazlık; kalkansız → kayıp', () {
    final (g, host) = makeGame();
    g.invuln = 0; // açılış dokunulmazlığını kapat
    // mermiyi geminin üstüne koy
    g.shards.add(Shard(g.shipX, g.shipY, 0, 8, 200));
    g.tick(1 / 60);
    expect(g.shieldsLeft, 0);
    expect(g.isOver, isFalse);
    expect(g.invuln, greaterThan(0), reason: 'dokunulmazlık penceresi');
    // dokunulmazlıkta çarpma ölümcül değil
    g.shards.add(Shard(g.shipX, g.shipY, 0, 8, 200));
    g.tick(1 / 60);
    expect(g.isOver, isFalse);
    // dokunulmazlık bitsin, tekrar çarpma → kayıp
    g.setShieldsForTest(0);
    g.invuln = 0;
    g.shards.add(Shard(g.shipX, g.shipY, 0, 8, 200));
    g.tick(1 / 60);
    expect(g.isOver, isTrue);
    expect(host.events, contains('lose'));
  });
}
