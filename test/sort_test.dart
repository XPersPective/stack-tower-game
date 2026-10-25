import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/sort_game.dart';
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
  SortGame gameWith(_Host host, {int shields = 1, LevelDef? def}) {
    final g = SortGame();
    g.resize(460, 780);
    g.start(def ?? levelDef(6), host: host, shields: shields);
    return g;
  }

  /// Tahtayı elle kurar (deterministik test).
  void setBoard(SortGame g, List<List<int>> board) {
    for (var c = 0; c < g.columns; c++) {
      g.stacksForTest[c]
        ..clear()
        ..addAll(c < board.length ? board[c] : <int>[]);
    }
  }

  group('SORT kuralları', () {
    test('dağıtım: her renkten 4 top, en az bir boş sütun', () {
      final host = _Host();
      final g = gameWith(host);
      final total = g.stacksForTest.fold<int>(0, (a, s) => a + s.length);
      expect(total, g.colors * SortGame.capacity);
      expect(g.stacksForTest.any((s) => s.isEmpty), isTrue,
          reason: 'çözülebilirlik için boş sütun şart');
      expect(g.movesLeftForTest, greaterThan(0));
    });

    test('ilk dokunuş sütunu seçer, ikinci dokunuş taşır', () {
      final host = _Host();
      final g = gameWith(host);
      setBoard(g, [
        [0, 1],
        [1, 0],
        [],
        []
      ]);
      g.tapColumnForTest(0);
      expect(g.selectedForTest, 0);
      g.tapColumnForTest(2);
      expect(g.stacksForTest[0], [0]);
      expect(g.stacksForTest[2], [1]);
      expect(g.selectedForTest, isNull);
      expect(g.movesLeftForTest, greaterThan(0));
    });

    test('aynı sütuna dokunma seçimi iptal eder', () {
      final host = _Host();
      final g = gameWith(host);
      setBoard(g, [
        [0],
        [],
        [],
        []
      ]);
      g.tapColumnForTest(0);
      g.tapColumnForTest(0);
      expect(g.selectedForTest, isNull);
      expect(g.stacksForTest[0], [0]);
    });

    test('farklı renk üstüne taşıma reddedilir (top yerinde kalır)', () {
      final host = _Host();
      final g = gameWith(host);
      setBoard(g, [
        [0],
        [1],
        [],
        []
      ]);
      g.tapColumnForTest(0);
      g.tapColumnForTest(1); // 1'in üstü farklı renk
      expect(g.stacksForTest[0], [0], reason: 'top taşınmadı');
      expect(g.stacksForTest[1], [1]);
    });

    test('dolu sütuna taşıma reddedilir', () {
      final host = _Host();
      final g = gameWith(host);
      setBoard(g, [
        [0],
        [1, 1, 1, 1],
        [],
        []
      ]);
      g.tapColumnForTest(0);
      g.tapColumnForTest(1);
      expect(g.stacksForTest[1].length, SortGame.capacity);
      expect(g.stacksForTest[0], [0]);
    });

    test('sütun tamamlanınca skor artar ve column olayı yayılır', () {
      final host = _Host();
      final g = gameWith(host);
      setBoard(g, [
        [0, 0, 0],
        [0],
        [],
        []
      ]);
      g.tapColumnForTest(1);
      g.tapColumnForTest(0);
      expect(g.score, 1);
      expect(host.events, contains('column'));
      expect(host.sounds, contains('coin'));
    });

    test('tüm renkler sıralınınca kazanır (gerçek hamlelerle)', () {
      final host = _Host();
      final g = gameWith(host);
      final n = g.colors;
      expect(n, 3, reason: 'levelDef(6) → stage 0 → 3 renk');
      setBoard(g, [
        [0, 0, 0],
        [1, 1, 1],
        [2, 2, 2],
        [2, 1, 0], // yedekler: sırasıyla 0, 1, 2 taşınır
      ]);
      g.tapColumnForTest(3);
      g.tapColumnForTest(0);
      expect(g.score, 1);
      expect(host.events, contains('column'));
      g.tapColumnForTest(3);
      g.tapColumnForTest(1);
      expect(g.score, 2);
      g.tapColumnForTest(3);
      g.tapColumnForTest(2);
      expect(g.score, n);
      expect(g.isOver, isTrue);
      expect(g.result().reached, isTrue);
      expect(host.events, contains('win'));
    });

    test('dağıtımda hazır gelen sütunlar skora sayılmaz ama çözüm yine kazanır', () {
      final host = _Host();
      final g = gameWith(host);
      setBoard(g, [
        [0, 0, 0, 0], // dağıtımda tamamlanmış (skora sayılmaz)
        [1, 1, 1, 1], // dağıtımda tamamlanmış
        [2, 2, 2],
        [2],
      ]);
      g.tapColumnForTest(3);
      g.tapColumnForTest(2); // son sütun hamleyle tamam → tahta çözüldü
      expect(g.isOver, isTrue);
      expect(g.result().reached, isTrue);
      expect(g.score, 1, reason: 'yalnızca hamleyle tamamlanan sütun sayılır');
      expect(host.events, contains('win'));
    });

    test('hamle bütçesi bitince kayıp (çözülmediyse)', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      setBoard(g, [
        [0, 1],
        [1, 0],
        [],
        []
      ]);
      g.setMovesForTest(1);
      g.tapColumnForTest(0);
      g.tapColumnForTest(2); // son hamle, tahta çözülmedi
      expect(g.isOver, isTrue);
      expect(g.result().reached, isFalse);
      expect(host.events, contains('lose'));
    });

    test('oyun bitince dokunuşlar etkisiz', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      setBoard(g, [
        [0, 1],
        [1, 0],
        [],
        []
      ]);
      g.setMovesForTest(1);
      g.tapColumnForTest(0);
      g.tapColumnForTest(2);
      expect(g.isOver, isTrue);
      final before = g.stacksForTest.map((s) => List.of(s)).toList();
      g.tapColumnForTest(1);
      expect(g.stacksForTest.map((s) => List.of(s)).toList(), before);
    });

    test('mükemmel: aynı renkten 2+ topu doğru sütuna oturtmak', () {
      final host = _Host();
      final g = gameWith(host);
      setBoard(g, [
        [1, 0],
        [0],
        [],
        []
      ]);
      g.tapColumnForTest(0); // üstteki 0'ı seç
      g.tapColumnForTest(1); // 0'ın üstüne → run 2, hepsi aynı renk
      expect(g.result().perfects, 1);
      expect(g.combo, 1);
    });
  });
}
