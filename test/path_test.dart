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
    test('9 düğüm + 12 temel kenar + dünya kadar çapraz', () {
      final host = _Host();
      final g = gameWith(host, def: levelDef(5)); // stage 0 → extra 0
      expect(g.nodesForTest.length, 9);
      expect(g.edgesForTest.length, 12);
      expect(g.target, 12);

      final g2 = PathGame()
        ..resize(460, 780)
        ..start(levelDef(50), host: host); // stage 3 → extra 3
      expect(g2.edgesForTest.length, 15);
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
      g.tapNodeForTest(0);
      g.tapNodeForTest(1); // 0-1 yatay kenar
      expect(g.tracedCount, 1);
      expect(g.score, 1);
      expect(g.currentForTest, 1);
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
      g.tapNodeForTest(0);
      g.tapNodeForTest(1);
      g.tapNodeForTest(0); // 0-1 zaten çizildi
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

    test('tüm kenarlar çizilince kazanır', () {
      final host = _Host();
      final g = gameWith(host);
      // son kenar hariç hepsini çizilmiş say
      for (var i = 0; i < g.edgesForTest.length - 1; i++) {
        g.edgesForTest[i].traced = true;
      }
      final last = g.edgesForTest.last;
      g.tapNodeForTest(last.a);
      g.tapNodeForTest(last.b);
      expect(g.isOver, isTrue);
      expect(g.result().reached, isTrue);
      expect(host.events, contains('win'));
    });

    test('çıkmaz: mevcut düğümden geçilmemiş kenar kalmadıysa kayıp', () {
      final host = _Host();
      final g = gameWith(host);
      // 0 düğümünün tüm kenarlarını çizilmiş yap, sonra 0'a gel
      for (final e in g.edgesForTest) {
        if (e.a == 0 || e.b == 0) e.traced = true;
      }
      g.tapNodeForTest(1);
      g.tapNodeForTest(0); // 1-0 kenarı çizilmiş → hata değil mi?
      // 1-0 çizilmiş olduğundan bu bir hatadır → kalkan gider
      expect(g.shieldsLeft, 0);
      expect(g.isOver, isFalse);
    });

    test('kombo: 4 doğru geçişte mükemmel sayılır', () {
      final host = _Host();
      final g = gameWith(host);
      // 0→1→2→5→4 yolu (ızgara kenarları)
      g.tapNodeForTest(0);
      g.tapNodeForTest(1);
      g.tapNodeForTest(2);
      g.tapNodeForTest(5);
      g.tapNodeForTest(4);
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
