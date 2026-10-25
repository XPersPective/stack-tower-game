import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/ring_game.dart';
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
  RingGame gameWith(_Host host, {int shields = 1, LevelDef? def}) {
    final g = RingGame();
    g.resize(460, 780);
    g.start(def ?? levelDef(1), host: host, shields: shields);
    return g;
  }

  group('RING temel kurallar', () {
    test('hedef dilimin merkezinde dokunma → skor + mükemmel', () {
      final host = _Host();
      final g = gameWith(host);
      g.angle = g.targetStart + g.targetWidth / 2;
      g.onTap(Offset.zero);
      expect(g.score, 1);
      expect(g.combo, 1);
      expect(g.result().perfects, 1);
      expect(host.sounds, contains('perfect'));
    });

    test('hedef dilimin kenarında dokunma → skor var, mükemmel yok', () {
      final host = _Host();
      final g = gameWith(host);
      // dilimin %90'ında (merkez dışı ama içinde)
      g.angle = g.targetStart + g.targetWidth * 0.90;
      g.onTap(Offset.zero);
      expect(g.score, 1);
      expect(g.result().perfects, 0);
      expect(host.sounds, contains('place'));
    });

    test('hedef dışında dokunma → kalkan düşer, oyun sürer', () {
      final host = _Host();
      final g = gameWith(host);
      g.angle = g.targetStart + g.targetWidth + 1.2; // açıkça dışarıda
      g.onTap(Offset.zero);
      expect(g.score, 0);
      expect(g.shieldsLeft, 0);
      expect(g.isOver, isFalse);
      expect(host.events, contains('shield'));
      expect(host.sounds, contains('shield'));
    });

    test('kalkan yokken ıskalama → kayıp', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      g.angle = g.targetStart + g.targetWidth + 1.2;
      g.onTap(Offset.zero);
      expect(g.isOver, isTrue);
      expect(g.result().reached, isFalse);
      expect(host.events, contains('lose'));
    });

    test('hedefe ulaşınca kazanır', () {
      final host = _Host();
      final g = gameWith(host, def: levelDef(1)); // hedef 8
      for (var i = 0; i < 8 && !g.isOver; i++) {
        g.angle = g.targetStart + g.targetWidth / 2;
        g.onTap(Offset.zero);
      }
      expect(g.score, 8);
      expect(g.isOver, isTrue);
      expect(g.result().reached, isTrue);
      expect(host.events, contains('win'));
    });

    test('her isabetten sonra yön döner ve hız artar', () {
      final host = _Host();
      final g = gameWith(host);
      final spin0 = g.spinForTest;
      final dir0 = g.dirSignForTest;
      g.angle = g.targetStart + g.targetWidth / 2;
      g.onTap(Offset.zero);
      expect(g.dirSignForTest, -dir0);
      expect(g.spinForTest, greaterThan(spin0));
    });

    test('zorluk: skor arttıkça hedef dilim daralır (taban 0.34 rad)', () {
      final host = _Host();
      final g = gameWith(host);
      final w0 = g.targetWidth;
      for (var i = 0; i < 6; i++) {
        g.angle = g.targetStart + g.targetWidth / 2;
        g.onTap(Offset.zero);
      }
      expect(g.targetWidth, lessThan(w0));
      expect(g.targetWidth, greaterThanOrEqualTo(0.34));
    });

    test('açı sarması: 0/2π sınırında isabet doğru hesaplanır', () {
      final host = _Host();
      final g = gameWith(host);
      // hedef dilimi 0 civarına zorla (sarma durumu)
      g.setTargetForTest(-0.2, 0.4); // -0.2 .. 0.2 (0 üzerinden sarar)
      g.angle = 0.0; // tam merkez
      g.onTap(Offset.zero);
      expect(g.score, 1, reason: 'sarma durumunda merkez isabet olmalı');
    });

    test('tick işareti döndürür; oyun bitince tick etkisiz', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      final a0 = g.angleForTest;
      g.tick(0.1);
      expect(g.angleForTest, isNot(a0));
      g.angle = g.targetStart + g.targetWidth + 1.2;
      g.onTap(Offset.zero); // kayıp
      final aEnd = g.angleForTest;
      g.tick(0.5);
      expect(g.angleForTest, aEnd, reason: 'oyun bitti → işaretçi durur');
    });
  });
}
