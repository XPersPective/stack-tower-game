import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/path_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';

class _Host implements MiniGameHost {
  final List<String> sounds = [];
  final List<String> events = [];
  int haptics = 0;

  @override
  void playSound(String name, {int combo = 1}) => sounds.add(name);
  @override
  void haptic(int ms) => haptics++;
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) => events.add(name);
}

void main() {
  PathGame gameWith(_Host host, {int shields = 1, LevelDef? def}) {
    final g = PathGame();
    g.resize(460, 780);
    g.start(def ?? levelDef(5), host: host, shields: shields);
    return g;
  }

  group('PATH grafik kurulumu', () {
    test('graf daima Euler yolu içerir (tek-dereceli düğüm ≤ 2, bağlı)', () {
      for (final def in [levelDef(5), levelDef(50), levelDef(95), levelDef(140)]) {
        final g = PathGame(math.Random(3))
          ..resize(460, 780)
          ..start(def, host: _Host());
        expect(g.edgesForTest.length, (6 + def.stage).clamp(6, 10),
            reason: 'stage ${def.stage} kenar sayısı');
        final deg = List.filled(9, 0);
        for (final e in g.edgesForTest) {
          deg[e.a]++;
          deg[e.b]++;
        }
        expect(deg.where((d) => d.isOdd).length, lessThanOrEqualTo(2),
            reason: 'Euler yolu için tek-dereceli düğüm 0 veya 2 olmalı');
        // bağlılık: kenarları taşıyan düğümler tek bileşende
        final adj = <int, Set<int>>{};
        for (final e in g.edgesForTest) {
          adj.putIfAbsent(e.a, () => <int>{}).add(e.b);
          adj.putIfAbsent(e.b, () => <int>{}).add(e.a);
        }
        final seen = <int>{g.edgesForTest.first.a};
        var grew = true;
        while (grew) {
          grew = false;
          for (final n in seen.toList()) {
            for (final m in adj[n] ?? const <int>{}) {
              if (seen.add(m)) grew = true;
            }
          }
        }
        expect(seen.length, adj.length, reason: 'kenar taşıyan tüm düğümler bağlı');
      }
    });

    test('tanık çözümü: ardışık düğümler gerçek kenar, her kenar bir kez', () {
      final g = PathGame(math.Random(11))
        ..resize(460, 780)
        ..start(levelDef(50), host: _Host());
      final sol = g.solutionForTest;
      expect(sol.length, g.edgesForTest.length + 1);
      final used = <String>{};
      for (var i = 0; i + 1 < sol.length; i++) {
        final a = sol[i], b = sol[i + 1];
        expect(
          g.edgesForTest
              .any((e) => (e.a == a && e.b == b) || (e.a == b && e.b == a)),
          isTrue,
          reason: '$a-$b arası kenar yok',
        );
        used.add(a < b ? '$a-$b' : '$b-$a');
      }
      expect(used.length, g.edgesForTest.length, reason: 'kenar tekrarsız');
    });

    test('resize iki kez çağrılsa da yerleşim bozulmaz (regresyon)', () {
      final host = _Host();
      final g = gameWith(host);
      final x1 = g.nodesForTest[0].x;
      final y1 = g.nodesForTest[0].y;
      g.resize(460, 780);
      expect(g.nodesForTest[0].x, closeTo(x1, 1e-9));
      expect(g.nodesForTest[0].y, closeTo(y1, 1e-9));
      g.resize(720, 1400);
      expect(g.nodesForTest[0].x, greaterThan(0));
      expect(g.nodesForTest[0].x, lessThan(720));
    });
  });

  group('PATH oynanış', () {
    test('ilk dokunuş başlangıç düğümünü seçer', () {
      final host = _Host();
      final g = gameWith(host);
      g.tapNodeForTest(0);
      expect(g.currentForTest, 0);
      expect(g.score, 0, reason: 'seçim skor vermez');
    });

    test('komşu düğüm: kenar çizilir, skor artar', () {
      final host = _Host();
      final g = gameWith(host);
      final sol = g.solutionForTest;
      g.tapNodeForTest(sol[0]);
      g.tapNodeForTest(sol[1]); // tanığın ilk kenarı
      expect(g.tracedCount, 1);
      expect(g.score, 1);
      expect(g.currentForTest, sol[1]);
      expect(g.isOver, isFalse, reason: 'tanık devam ediyor, çıkmaz yok');
      expect(host.sounds, contains('place'));
    });

    test('komşu olmayan düğüm: hata → kalkan düşer', () {
      final host = _Host();
      final g = gameWith(host);
      g.tapNodeForTest(0);
      g.tapNodeForTest(8); // çapraz uzak, kenar yok
      expect(g.tracedCount, 0);
      expect(g.shieldsLeft, 0);
      expect(host.events, contains('shield'));
      expect(g.isOver, isFalse);
    });

    test('aynı kenarı ikinci kez geçme: hata sayılır', () {
      final host = _Host();
      final g = gameWith(host);
      final sol = g.solutionForTest;
      g.tapNodeForTest(sol[0]);
      g.tapNodeForTest(sol[1]); // kenar çizilir
      g.tapNodeForTest(sol[0]); // aynı kenar geri → hata
      expect(g.tracedCount, 1);
      expect(g.shieldsLeft, 0);
    });

    test('kalkan yokken hata → kayıp', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      g.tapNodeForTest(0);
      g.tapNodeForTest(8);
      expect(g.isOver, isTrue);
      expect(g.result().reached, isFalse);
      expect(host.events, contains('lose'));
    });

    test('tüm kenarlar yasal yürüyüşle çizilince kazanır (mutasyon yok)', () {
      final host = _Host();
      final g = gameWith(host);
      for (final n in g.solutionForTest) {
        g.tapNodeForTest(n);
      }
      expect(g.isOver, isTrue);
      expect(g.result().reached, isTrue);
      expect(g.score, g.edgesForTest.length);
      expect(host.events, contains('win'));
    });

    test('çıkmaz: yaprak düğümün tek kenarını geçince kayıp', () {
      // Tohumları tarayıp yaprak uçlu (tek dereceli düğüm) graf üreten tohum bul;
      // aynı tohum her seferinde aynı grafı üretir.
      var seed = 0, leafA = -1, leafB = -1;
      for (var s = 1; s <= 60; s++) {
        final g = PathGame(math.Random(s))
          ..resize(460, 780)
          ..start(levelDef(20), host: _Host()); // stage 1 → 7 kenar
        final deg = List.filled(9, 0);
        for (final e in g.edgesForTest) {
          deg[e.a]++;
          deg[e.b]++;
        }
        for (final e in g.edgesForTest) {
          final aLeaf = deg[e.a] == 1, bLeaf = deg[e.b] == 1;
          if (aLeaf != bLeaf) {
            seed = s;
            leafA = aLeaf ? e.a : e.b;
            leafB = aLeaf ? e.b : e.a;
            break;
          }
        }
        if (seed != 0) break;
      }
      expect(seed, greaterThan(0), reason: '60 tohum içinde yaprak uçlu graf bulunmalı');
      final host = _Host();
      final g = PathGame(math.Random(seed))
        ..resize(460, 780)
        ..start(levelDef(20), host: host);
      g.tapNodeForTest(leafB); // yaprağın komşusundan başla
      g.tapNodeForTest(leafA); // yaprağın tek kenarını çiz → orada sıkış
      expect(g.tracedCount, 1);
      expect(g.isOver, isTrue);
      expect(g.result().reached, isFalse);
      expect(host.events, contains('lose'));
    });

    test('kombo: 4 doğru geçişte mükemmel sayılır', () {
      final host = _Host();
      final g = gameWith(host);
      final sol = g.solutionForTest;
      expect(sol.length, greaterThanOrEqualTo(5), reason: 'en az 4 kenar');
      for (var i = 0; i < 5; i++) {
        g.tapNodeForTest(sol[i]);
      }
      expect(g.score, 4);
      expect(g.result().perfects, greaterThanOrEqualTo(1));
    });

    test('oyun bitince dokunuşlar etkisiz', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      g.tapNodeForTest(0);
      g.tapNodeForTest(8); // kayıp
      expect(g.isOver, isTrue);
      final s = g.score;
      g.tapNodeForTest(3);
      expect(g.score, s);
    });
  });
}
