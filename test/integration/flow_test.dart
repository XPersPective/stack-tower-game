/// PB-013 — uçtan uca akış testleri (emülatör gerekmez):
/// önizleme → oyun → sonuç → tekrar; günlük; serbest.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/gameplay.dart' show EngineState;
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/screens/play_screen.dart';
import 'package:stack_tower_game/screens/preview_screen.dart';
import 'package:stack_tower_game/screens/router.dart';
import 'package:stack_tower_game/services/storage.dart';

Widget _routedHost(Widget home, GameSession session) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: MaterialApp(
        home: home,
        onGenerateRoute: (s) =>
            MaterialPageRoute(builder: (_) => routeFor(s), settings: s),
      ),
    );

void main() {
  testWidgets('akış: önizleme → BAŞLA → oyun başlar (HUD hazır)', (tester) async {
    // Saat sabit (20001. gün) — tarih-duyarlı sürpriz döngüsü testi bozmasın.
    final session = GameSession(MemoryStorage(),
        clock: () => DateTime.fromMillisecondsSinceEpoch(86400000 * 20001));
    // i=2 → STACK (engineForTest yalnız stack türünde motor döndürür);
    // bölümün kilidi açık olsun diye ilk iki bölüm tamamlanır
    for (var i = 0; i < 2; i++) {
      prog.completeLevel(session.state, levelDef(i),
          blocks: 10, perfects: 5, reached: true, stars: 3);
    }
    final def = levelDef(2);
    await tester.pumpWidget(_routedHost(PreviewScreen(def: def), session));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // sinematik fade-in
    await tester.tap(find.text('BAŞLA ▶'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PlayScreen), findsOneWidget);

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    final e = state.engineForTest;
    expect(e.state, EngineState.playing);
    // ilk bırakış skoru ilerletir
    e.moving!.x = e.blocks.last.x;
    e.moving!.w = e.blocks.last.w;
    e.drop();
    expect(e.score, greaterThan(0));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // oyun ekranı hâlâ ayakta (çökme yok)
    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('akış: günlük meydan okuma önizlemesi', (tester) async {
    final session = GameSession(MemoryStorage());
    final def = dailyDef(7);
    await tester.pumpWidget(_routedHost(PreviewScreen(def: def), session));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.textContaining('GÜNLÜK'), findsWidgets);
    expect(find.text('BAŞLA ▶'), findsOneWidget);
  });

  testWidgets('akış: serbest mod oyunu başlar', (tester) async {
    final session = GameSession(MemoryStorage());
    final def = endlessDef();
    await tester.pumpWidget(_routedHost(
        PlayScreen(
          session: session,
          audio: AudioController(),
          def: def,
          onExit: () {},
          onFlowDone: () {},
        ),
        session));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PlayScreen), findsOneWidget);
    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    expect(state.engineForTest.state, EngineState.playing);
  });
}
