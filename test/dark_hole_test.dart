/// PB-041 — UZUN KARANLIK motor testleri: süzülme, yutma/büyüme, karanlık
/// parça küçültmesi, kalkan, kayıp, kazanma.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/dark_hole_game.dart';
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

typedef HoleBundle = (DarkHoleGame, _FakeHost);

HoleBundle makeGame() {
  final host = _FakeHost();
  final g = DarkHoleGame();
  g.resize(kW, kH);
  g.start(levelDef(0), host: host); // hedef 8
  return (g, host);
}

/// Test parçası — doğrudan sahneye koy (rastgelelik yok).
Chunk chunkAt(DarkHoleGame g, double x, double y,
    {bool dark = false, bool gold = false, double r = 12}) {
  final c = Chunk(x, y, 0, r, gold ? 45 : 200, dark: dark, gold: gold);
  g.chunks.add(c);
  return c;
}

void main() {
  test('tür kimliği: darkHole', () {
    expect(DarkHoleGame().kind, GameKind.darkHole);
  });

  test('kurulum: delik alt-ortada, yarıçap başlangıç değeri', () {
    final (g, _) = makeGame();
    expect(g.hx, closeTo(kW / 2, 0.5));
    expect(g.hy, greaterThan(kH * 0.6));
    expect(g.hr, greaterThan(20));
    expect(g.isOver, isFalse);
  });

  test('süzülme: dokun → delik hedefe yaklaşır', () {
    final (g, _) = makeGame();
    final x0 = g.hx, y0 = g.hy;
    g.onTap(const Offset(60, 200));
    for (var i = 0; i < 150; i++) {
      g.tick(1 / 60); // 2.5 s — yeterli süzülme
    }
    expect(g.hx, lessThan(x0), reason: 'sola süzüldü');
    expect(g.hy, lessThan(y0), reason: 'yukarı süzüldü');
    expect((g.hx - 60).abs() + (g.hy - 200).abs(), lessThan(24),
        reason: 'hedefe vardı');
  });

  test('yutma: doğru parça → skor +1, delik büyür, combo artar', () {
    final (g, host) = makeGame();
    final r0 = g.hr;
    // parçayı delik merkezine koy
    chunkAt(g, g.hx, g.hy);
    g.tick(1 / 60);
    expect(g.score, 1);
    expect(g.combo, 1);
    expect(g.hr, greaterThan(r0));
    expect(host.sounds, contains('coin'));
  });

  test('karanlık parça: deliği küçültür, combo kırılır', () {
    final (g, host) = makeGame();
    final r0 = g.hr;
    chunkAt(g, g.hx, g.hy, dark: true);
    g.tick(1 / 60);
    expect(g.hr, lessThan(r0));
    expect(g.combo, 0);
    expect(g.isOver, isFalse, reason: 'tek küçülme öldürmez');
    expect(host.sounds, contains('shield'));
  });

  test('altın parça: +2 skor', () {
    final (g, _) = makeGame();
    chunkAt(g, g.hx, g.hy, gold: true);
    g.tick(1 / 60);
    expect(g.score, 2);
  });

  test('kalkan: yarıçap minimuma inince kalkan kurtarır', () {
    final (g, host) = makeGame();
    g.hr = 14; // minR(13·scale=11.3) sınırında
    chunkAt(g, g.hx, g.hy, dark: true, r: 12);
    g.tick(1 / 60); // hr -= 1.68 → 12.3 < 13·0.8696=11.3? hayır → üstte kalır
    // garanti küçülme: birkaç karanlık parça daha
    for (var i = 0; i < 6 && !g.isOver && g.shieldsLeft > 0; i++) {
      if (g.isOver) break;
      chunkAt(g, g.hx, g.hy, dark: true, r: 12);
      g.tick(1 / 60);
    }
    expect(g.isOver, isFalse, reason: 'kalkan kurtardı');
    expect(g.shieldsLeft, 0);
    expect(g.hr, greaterThan(11), reason: 'kalkan yarıçapı geri getirdi');
  });

  test('kalkansız küçülme → kayıp', () {
    final (g, host) = makeGame();
    g.setShieldsForTest(0);
    for (var i = 0; i < 12 && !g.isOver; i++) {
      chunkAt(g, g.hx, g.hy, dark: true, r: 12);
      g.tick(1 / 60);
    }
    expect(g.isOver, isTrue);
    expect(g.result().reached, isFalse);
    expect(host.events, contains('lose'));
  });

  test('kazanma: hedef kadar doğru parça → reached + win olayı', () {
    final (g, host) = makeGame();
    final target = levelDef(0).target;
    for (var i = 0; i < target; i++) {
      chunkAt(g, g.hx, g.hy);
      g.tick(1 / 60);
    }
    expect(g.score, target);
    expect(g.isOver, isTrue);
    expect(g.result().reached, isTrue);
    expect(host.events, contains('win'));
  });

  test('düşen akış: tick ile parçalar doğar ve yukarıdan süzülür', () {
    final (g, _) = makeGame();
    final n0 = g.chunks.length;
    for (var i = 0; i < 90; i++) {
      g.tick(1 / 60); // 1.5 s — birkaç doğum
    }
    expect(g.chunks.length, greaterThan(n0));
  });

  test('dağıtım: neonClean ve darkHole döngüde, ardışık tekrar yok', () {
    var clean = false, hole = false;
    for (var i = 5; i < 150; i++) {
      if (kindFor(i) == GameKind.neonClean) clean = true;
      if (kindFor(i) == GameKind.darkHole) hole = true;
      expect(kindFor(i), isNot(kindFor(i - 1)), reason: 'i=$i ardışık tekrar');
    }
    expect(clean, isTrue);
    expect(hole, isTrue);
  });
}
