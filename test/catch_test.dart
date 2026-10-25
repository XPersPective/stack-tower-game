import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/catcher_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';

class _Host implements MiniGameHost {
  final List<String> sounds = [];
  final List<String> events = [];
  final List<Map<String, dynamic>?> payloads = [];
  int haptics = 0;

  @override
  void playSound(String name, {int combo = 1}) => sounds.add(name);
  @override
  void haptic(int ms) => haptics++;
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) {
    events.add(name);
    payloads.add(data);
  }
}

void main() {
  CatcherGame gameWith(LevelDef def, _Host host, {int shields = 1}) {
    final g = CatcherGame();
    g.resize(460, 780);
    g.start(def, host: host, shields: shields);
    return g;
  }

  /// Sepetin tam üstüne bir öğe yerleştirir (deterministik yakalama/çarpma).
  void placeAboveBasket(CatcherGame g, {required bool bomb, bool gold = false}) {
    g.items.clear();
    final basketTop = 780 - 92 * g.scale;
    g.items.add(FallingItem(g.basketX, basketTop - 2, 60, 14, bomb: bomb, gold: gold));
  }

  group('CATCH temel kurallar', () {
    test('yıldız yakalanınca skor/kombo artar, merkezde mükemmel', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host);
      placeAboveBasket(g, bomb: false);
      g.tick(1 / 60);
      expect(g.score, 1);
      expect(g.combo, 1);
      expect(g.result().perfects, 1, reason: 'merkezde yakalama mükemmel');
      expect(host.sounds, contains('perfect'));
    });

    test('kaçan yıldız komboyu sıfırlar, can götürmez', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host);
      placeAboveBasket(g, bomb: false);
      g.tick(1 / 60);
      expect(g.combo, 1);
      g.items.clear();
      g.items.add(FallingItem(4, -10, 4000, 14));
      for (var i = 0; i < 60 && g.items.isNotEmpty; i++) {
        g.tick(1 / 60);
      }
      expect(g.combo, 0);
      expect(g.isOver, isFalse);
    });

    test('bomba: kalkan affeder, shield olayı yayar, oyun sürer', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host);
      placeAboveBasket(g, bomb: true);
      g.tick(1 / 60);
      expect(g.shieldsLeft, 0);
      expect(g.isOver, isFalse);
      expect(host.events, contains('shield'));
      expect(host.payloads.last, {'left': 0});
      expect(host.sounds, contains('shield'));
    });

    test('bomba: kalkan yokken kaybettirir', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host, shields: 0);
      placeAboveBasket(g, bomb: true);
      g.tick(1 / 60);
      expect(g.isOver, isTrue);
      expect(g.result().reached, isFalse);
      expect(host.events, contains('lose'));
    });

    test('hedefe ulaşınca kazanır', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host);
      for (var i = 0; i < 8 && !g.isOver; i++) {
        placeAboveBasket(g, bomb: false);
        g.tick(1 / 60);
      }
      expect(g.score, 8);
      expect(g.isOver, isTrue);
      expect(g.result().reached, isTrue);
      expect(host.events, contains('win'));
      expect(host.sounds, contains('win'));
    });

    test('altın yıldız goldBlocks sayar', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host);
      placeAboveBasket(g, bomb: false, gold: true);
      g.tick(1 / 60);
      expect(g.result().goldBlocks, 1);
      expect(host.sounds, contains('coin'));
    });

    test('dokunma yönü ters çevirir (tek girdi)', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host);
      final x0 = g.basketX;
      g.onTap(const Offset(10, 10));
      for (var i = 0; i < 10; i++) {
        g.tick(1 / 60);
      }
      final x1 = g.basketX;
      g.onTap(const Offset(10, 10));
      for (var i = 0; i < 10; i++) {
        g.tick(1 / 60);
      }
      final x2 = g.basketX;
      expect((x1 - x0).sign, isNot((x2 - x1).sign),
          reason: 'iki dokunuş yönü tersine çevirmeli');
    });

    test('sepet ekran sınırları içinde kalır', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host);
      for (var i = 0; i < 900; i++) {
        g.tick(1 / 60);
      }
      expect(g.basketX, greaterThanOrEqualTo(g.basketW / 2 - 1e-6));
      expect(g.basketX, lessThanOrEqualTo(460 - g.basketW / 2 + 1e-6));
    });

    test('spawn sürüyor: 5 saniyede birden çok öğe düşer, kendiliğinden bitmez', () {
      final host = _Host();
      final g = gameWith(levelDef(0), host);
      var spawned = 0;
      for (var i = 0; i < 300; i++) {
        final before = g.items.length;
        g.tick(1 / 60);
        if (g.items.length > before) spawned++;
      }
      expect(spawned, greaterThan(3));
    });
  });
}
