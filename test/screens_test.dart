import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/screens/preview_screen.dart';
import 'package:stack_tower_game/screens/shop_screens.dart';
import 'package:stack_tower_game/services/storage.dart';

Widget host(WidgetBuilderFn builder) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: sessionForTests!),
      ChangeNotifierProvider.value(value: AudioController()),
    ],
    child: MaterialApp(home: builder()),
  );
}

typedef WidgetBuilderFn = Widget Function();

GameSession? sessionForTests;

void main() {
  tearDown(() => sessionForTests = null);

  testWidgets('mağaza: satın alma → bakiye düşer → KUŞANILDI', (tester) async {
    final storage = MemoryStorage();
    final session = GameSession(storage)..state.coins = 400;
    sessionForTests = session;

    await tester.pumpWidget(host(() => const ShopScreen()));
    await tester.pump();

    // GÖKKUŞAĞI (320) kartına dokun (tembel grid: görünene dek kaydır)
    await tester.scrollUntilVisible(
      find.text('GÖKKUŞAĞI'),
      200,
      scrollable: find.descendant(
        of: find.byType(ShopScreen),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GÖKKUŞAĞI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(session.state.coins, 80);
    expect(session.state.activeSkin, 'gokkusagi');
    expect(find.text('✓ KUŞANILDI'), findsOneWidget);
  });

  testWidgets('mağaza: yetersiz para → toast, bakiye korunur', (tester) async {
    final session = GameSession(MemoryStorage())..state.coins = 10;
    sessionForTests = session;

    await tester.pumpWidget(host(() => const ShopScreen()));
    await tester.pump();

    await tester.tap(find.text('ALTIN KULE'));
    await tester.pump();
    expect(session.state.coins, 10);
    expect(find.text('Yeterli paran yok! Bölüm bitir, kutu aç.'), findsOneWidget);
  });

  testWidgets('ödül odası: kalıntı kartları kilitli görünür', (tester) async {
    final session = GameSession(MemoryStorage());
    sessionForTests = session;

    await tester.pumpWidget(host(() => const ShopScreen()));
    await tester.pump();
    await tester.tap(find.text('ÖDÜL ODASI'));
    await tester.pump();

    expect(find.text('0/${prog.kRelics.length}'), findsOneWidget);
    expect(find.text('NEON KORU'), findsNothing); // kilitli → ad gösterilmez
    expect(find.text('KİLİTLİ'), findsWidgets); // görünür görünürlük penceresindeki kartlar
  });

  testWidgets('görevler: gün formülü + tamamlanan görev claim → ALINDI ✓, ödül düşer', (tester) async {
    final session = GameSession(
      MemoryStorage(),
      clock: () => DateTime.fromMillisecondsSinceEpoch(86400000 * 20000),
    );
    sessionForTests = session;

    // gün 20000 goal formülü: base + ((day+idx)%3)*step
    // idx0 totalPerfect: 10 + (20000%3=2)*5 = 20; idx1 totalBlocks: 60 + (20001%3=0)*20 = 60
    final items = session.missionItemsSafe();
    expect(items[0]['goal'], 20);
    expect(items[1]['stat'], 'totalBlocks');
    expect(items[1]['goal'], 60);

    // base kurulum anında 0 → hedefe ulaş (claim düğmesi yalnız done&&!claimed'te açık)
    session.state.totalBlocks = 60;

    await tester.pumpWidget(host(() => const MissionsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ALINDI ✓'), findsNothing);
    await tester.tap(find.text('+25 🪙')); // yalnız totalBlocks (reward 25) tamamlanmış
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(session.state.coins, 60 + 25);
    expect(find.text('ALINDI ✓'), findsOneWidget);
  });

  testWidgets('önizleme: kilitli bölümde KİLİTLİ pasif, açık bölümde BAŞLA', (tester) async {
    final session = GameSession(MemoryStorage());
    sessionForTests = session;

    // levelDef(1): önceki bölüm tamamlanmamış → kilitli
    // (yeni önizlemede 90s sonsuz tekrar eden ortam animasyonu var → pumpAndSettle olmaz,
    //  sabit süreli pump; preview_test.dart aynı kalıbı kullanıyor)
    await tester.pumpWidget(host(() => PreviewScreen(def: levelDef(1))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🔒 KİLİTLİ'), findsOneWidget);
    expect(find.text('BAŞLA ▶'), findsNothing);
    await tester.tap(find.text('🔒 KİLİTLİ')); // pasif düğme → rotaya geçiş olmamalı
    await tester.pump();
    expect(tester.takeException(), isNull);

    // levelDef(0): ilk bölüm her zaman açık
    await tester.pumpWidget(host(() => PreviewScreen(def: levelDef(0))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('BAŞLA ▶'), findsOneWidget);
    expect(find.text('🔒 KİLİTLİ'), findsNothing);
  });

  testWidgets('kutu akışı: openBoxNow para dalı sahte rand ile', (tester) async {
    final session = GameSession(MemoryStorage());
    session.prepareLevel(levelDef(20)); // num 21
    final before = session.state.coins;
    final prize = session.openBoxNow(rand: () => 0.9);
    expect(prize!.type, 'coins');
    expect(session.state.coins, greaterThan(before));
  });
}
