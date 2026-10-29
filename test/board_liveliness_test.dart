/// PB-020 — tahta canlılığı: rekor yayı, geçilen rakip, sezonluk rozet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/screens/flow_overlays.dart';
import 'package:stack_tower_game/services/storage.dart';

void main() {
  group('rekor yayı', () {
    test('günün en iyisi tutulur, düşük skor kaydı bozmaz', () {
      final s = prog.SaveState();
      prog.recordDaily(s, 10, 20);
      prog.recordDaily(s, 10, 12);
      expect(s.dailyHistory[10], 20);
      prog.recordDaily(s, 10, 33);
      expect(s.dailyHistory[10], 33);
    });

    test('son 7 gün tutulur, eskiler düşer', () {
      final s = prog.SaveState();
      for (var d = 0; d < 10; d++) {
        prog.recordDaily(s, d, 10 + d);
      }
      expect(s.dailyHistory.length, 7);
      expect(s.dailyHistory.containsKey(9), isTrue);
      expect(s.dailyHistory.containsKey(0), isFalse);
    });

    test('JSON gidiş-dönüşü', () {
      final s = prog.SaveState();
      prog.recordDaily(s, 42, 17);
      final back = prog.SaveState.fromJson(Map<String, dynamic>.from(s.toJson()));
      expect(back.dailyHistory[42], 17);
    });
  });

  group('seri ve rozet', () {
    test('ardışık günler seriyi büyütür, boşluk sıfırlar', () {
      final s = prog.SaveState();
      for (var d = 1; d <= 3; d++) {
        s.dailyHistory[d] = 10;
      }
      expect(prog.dailyStreak(s), 3);
      s.dailyHistory[6] = 10; // boşluk
      expect(prog.dailyStreak(s), 1);
    });

    test('7 gün üst üste → rozet', () {
      final s = prog.SaveState();
      for (var d = 0; d < 7; d++) {
        s.dailyHistory[d] = 10;
      }
      expect(prog.dailyStreak(s), 7);
      expect(prog.weeklyBadge(s), isTrue);
      s.dailyHistory.remove(6);
      expect(prog.weeklyBadge(s), isFalse);
    });

    test('boş geçmiş → 0, rozet yok', () {
      final s = prog.SaveState();
      expect(prog.dailyStreak(s), 0);
      expect(prog.weeklyBadge(s), isFalse);
    });
  });

  group('geçilen rakip', () {
    test('0..9 arası ve bugünkü tahtayla tutarlı', () {
      final s = prog.SaveState();
      expect(prog.beatenCount(s), 0, reason: 'gün yok');
      prog.recordDaily(s, 5, 40);
      final n = prog.beatenCount(s);
      expect(n, inInclusiveRange(0, 9));
      final rivals = prog.rivalsFor(5, 40);
      expect(n, rivals.where((r) => r.score < 40).length);
    });
  });

  group('tahta canlılığı bloğu', () {
    testWidgets('rekor yayı + geçilen rakip satırı görünür', (tester) async {
      final session = GameSession(MemoryStorage());
      for (var d = 1; d <= 4; d++) {
        session.state.dailyHistory[d] = 10 + d * 3;
      }
      session.state.daily = {'day': 4, 'best': 22};
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DailyLiveliness(session: session)),
      ));
      await tester.pump();
      expect(find.textContaining('SON 7 GÜN'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('7 gün serisinde rozet satırı çıkar', (tester) async {
      final session = GameSession(MemoryStorage());
      for (var d = 1; d <= 7; d++) {
        session.state.dailyHistory[d] = 20;
      }
      session.state.daily = {'day': 7, 'best': 20};
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DailyLiveliness(session: session)),
      ));
      await tester.pump();
      expect(find.textContaining('7 GÜN SERİSİ'), findsOneWidget);
    });
  });
}
