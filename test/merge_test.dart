import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/merge_game.dart';
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
  /// levelDef(4) → MERGE türü (ilk-5 şeması).
  MergeGame gameWith(_Host host, {int shields = 1}) {
    final g = MergeGame();
    g.resize(460, 780);
    g.start(levelDef(4), host: host, shields: shields);
    return g;
  }

  group('MERGE kuralları', () {
    test('eşit iki parça birleşir: değer katlanır, skor artar', () {
      final host = _Host();
      final g = gameWith(host);
      for (var i = 0; i < MergeGame.cells; i++) {
        g.setCellForTest(i, null);
      }
      g.setCellForTest(0, 1);
      g.setCellForTest(1, 1);
      g.onTap(_center(g, 0));
      expect(g.selectedForTest, 0);
      g.onTap(_center(g, 1));
      expect(g.gridForTest[1], 2, reason: '1+1 → 2 seviyesi');
      // birleşme sonrası yeni taş doğar (rastgele hücre) → toplam 2 dolu hücre
      expect(g.gridForTest.where((c) => c != null).length, 2);
      expect(g.score, 1);
      expect(g.selectedForTest, isNull);
      expect(host.sounds, contains('place'));
    });

    test('eşit olmayan parçalar birleşmez, seçim taşınır', () {
      final host = _Host();
      final g = gameWith(host);
      for (var i = 0; i < MergeGame.cells; i++) {
        g.setCellForTest(i, null);
      }
      g.setCellForTest(0, 1);
      g.setCellForTest(1, 2);
      g.onTap(_center(g, 0));
      g.onTap(_center(g, 1));
      expect(g.gridForTest[0], 1);
      expect(g.gridForTest[1], 2);
      expect(g.score, 0);
      expect(g.selectedForTest, 1, reason: 'seçim yeni parçaya geçti');
    });

    test('boş hücreye dokunma seçili parçayı taşır', () {
      final host = _Host();
      final g = gameWith(host);
      for (var i = 0; i < MergeGame.cells; i++) {
        g.setCellForTest(i, null);
      }
      g.setCellForTest(0, 2);
      g.onTap(_center(g, 0));
      g.onTap(_center(g, 5));
      expect(g.gridForTest[5], 2);
      expect(g.gridForTest[0], isNull);
      expect(g.score, 0, reason: 'taşıma skor vermez');
    });

    test('büyük birleşme (16+) mükemmel sayılır', () {
      final host = _Host();
      final g = gameWith(host);
      for (var i = 0; i < MergeGame.cells; i++) {
        g.setCellForTest(i, null);
      }
      g.setCellForTest(0, 3);
      g.setCellForTest(1, 3);
      g.onTap(_center(g, 0));
      g.onTap(_center(g, 1));
      expect(g.gridForTest[1], 4);
      expect(g.result().perfects, 1);
      expect(host.sounds, contains('perfect'));
    });

    test('birleşme süre ekler; süre erir', () {
      final host = _Host();
      final g = gameWith(host);
      final f0 = g.fuseForTest;
      g.tick(1.0);
      expect(g.fuseForTest, lessThan(f0), reason: 'süre azalmalı');
      for (var i = 0; i < MergeGame.cells; i++) {
        g.setCellForTest(i, null);
      }
      g.setCellForTest(0, 1);
      g.setCellForTest(1, 1);
      final before = g.fuseForTest;
      g.onTap(_center(g, 0));
      g.onTap(_center(g, 1));
      expect(g.fuseForTest, greaterThan(before), reason: 'birleşme süre ekler');
    });

    test('süre bitince kalkan 6 sn verir, kalkan yoksa kaybettirir', () {
      final host = _Host();
      final g = gameWith(host);
      for (var i = 0; i < 900 && !g.isOver; i++) {
        g.tick(1 / 60);
      }
      expect(host.events, contains('shield'));
      expect(g.isOver, isFalse);
      for (var i = 0; i < 900 && !g.isOver; i++) {
        g.tick(1 / 60);
      }
      expect(g.isOver, isTrue);
      expect(g.result().reached, isFalse);
      expect(host.events, contains('lose'));
    });

    test('hedefe ulaşınca kazanır', () {
      final host = _Host();
      final g = gameWith(host);
      final need = g.target;
      var guard = 0;
      while (!g.isOver && guard++ < 200) {
        // iki eşit parça koy ve birleştir
        for (var i = 0; i < MergeGame.cells; i++) {
          g.setCellForTest(i, null);
        }
        g.setCellForTest(0, 1);
        g.setCellForTest(1, 1);
        g.onTap(_center(g, 0));
        g.onTap(_center(g, 1));
        g.fuseTopUpForTest();
      }
      expect(g.score, greaterThanOrEqualTo(need));
      expect(g.result().reached, isTrue);
      expect(host.events, contains('win'));
    });

    test('kombo: 2.5 sn içindeki ardışık birleşmeler çarpanı artırır', () {
      final host = _Host();
      final g = gameWith(host);
      for (var k = 0; k < 3; k++) {
        for (var i = 0; i < MergeGame.cells; i++) {
          g.setCellForTest(i, null);
        }
        g.setCellForTest(0, 1);
        g.setCellForTest(1, 1);
        g.onTap(_center(g, 0));
        g.onTap(_center(g, 1));
        g.tick(0.1);
      }
      expect(g.combo, 3);
    });

    test('tahta dolu + eşit çift yok → taşma kaybı (süre bitmeden)', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      // 16 hücreye birbirinden farklı 16 değer → hamle yok
      for (var i = 0; i < MergeGame.cells; i++) {
        g.setCellForTest(i, i + 1);
      }
      // periyodik doğum anında tahta dolu → kayıp (fuse 12s'den ÖNCE)
      var elapsed = 0.0;
      for (var i = 0; i < 400 && !g.isOver; i++) {
        g.tick(1 / 60);
        elapsed += 1 / 60;
      }
      expect(g.isOver, isTrue);
      expect(host.events, contains('lose'));
      expect(elapsed, lessThan(MergeGame.spawnEvery + 1),
          reason: 'kayıp taşma kontrolünden gelmeli, süre dolmasından değil');
    });

    test('doluluk zamanla artar: her 5 sn yeni parça doğar', () {
      final host = _Host();
      final g = gameWith(host);
      int filled() => g.gridForTest.where((c) => c != null).length;
      expect(filled(), 4, reason: 'başlangıç 4 parça');
      for (var i = 0; i < 310; i++) {
        g.tick(1 / 60); // 5.16s
      }
      expect(filled(), 5, reason: 'tahta dolabilmeli (PB-026)');
    });

    test('tahta dolu ama eşit çift varsa kayıp yok', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      for (var i = 0; i < MergeGame.cells; i++) {
        g.setCellForTest(i, 1 + (i ~/ 2)); // her değerden iki tane
      }
      for (var i = 0; i < 310; i++) {
        g.tick(1 / 60);
      }
      expect(g.isOver, isFalse, reason: 'hamle var → taşma kaybı değil');
    });
  });
}

/// Hücre merkezine dokunma koordinatı (board düzeniyle aynı hesap).
Offset _center(MergeGame g, int cell) {
  final size = (460 * 0.86) < (780 * 0.52) ? 460 * 0.86 : 780 * 0.52;
  final left = (460 - size) / 2;
  final top = 780 * 0.24;
  final cw = size / MergeGame.cols;
  final ch = size / MergeGame.rows;
  return Offset(left + (cell % MergeGame.cols) * cw + cw / 2,
      top + (cell ~/ MergeGame.cols) * ch + ch / 2);
}
