import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/gameplay.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/screens/play_screen.dart';
import 'package:stack_tower_game/services/storage.dart';

void main() {
  Future<GameSession> makeSession() async => GameSession(MemoryStorage());

  Widget host(GameSession session, LevelDef def, {VoidCallback? onExit, VoidCallback? onFlowDone}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: MaterialApp(
        home: PlayScreen(
          session: session,
          audio: AudioController(),
          def: def,
          onExit: onExit ?? () {},
          onFlowDone: onFlowDone ?? () {},
        ),
      ),
    );
  }

  testWidgets('tap → drop tetiklenir; skor HUD güncellenir', (tester) async {
    final session = await makeSession();
    await tester.pumpWidget(host(session, endlessDef()));
    await tester.pump(const Duration(milliseconds: 120)); // layout + ilk frame

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    // HUD skor 0'da
    expect(find.text('0'), findsOneWidget);

    // mükemmel bırakışı zorla (motor durumuna müdahale — test gözlemcisi)
    final e0 = state.engineForTest;
    e0.moving!.x = e0.blocks.last.x;
    await tester.tap(find.byType(PlayScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(e0.score, 1);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('hedefe ulaşınca zincir: sonuç overlay açılır, TEKRAR yeniden başlatır', (tester) async {
    final session = await makeSession();
    await tester.pumpWidget(host(session, levelDef(0))); // hedef 8
    await tester.pump(const Duration(milliseconds: 120));

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    final e = state.engineForTest;
    for (var i = 0; i < 8; i++) {
      e.moving!.x = e.blocks.last.x;
      e.drop();
    }
    expect(e.state, EngineState.won);

    // endTimer 0.95sn akıt → win olayı → overlay zinciri
    // (Ticker sürekli animasyonlu olduğundan pumpAndSettle KULLANILMAZ)
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // sonuç ekranı: BÖLÜM TAMAM! + yıldızlar + TEKRAR + HARİTA
    expect(find.text('BÖLÜM TAMAM!'), findsOneWidget);
    expect(find.text('TEKRAR'), findsOneWidget);
    expect(find.text('HARİTA'), findsOneWidget);
    // ödül uygulandı
    expect(session.state.completed[0], isNotNull);
    // yıldız animasyon zamanlayıcılarının tamamı akıtılsın (pending timer yok)
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('kaybetme: teselli 2 para ve sonuç overlay', (tester) async {
    final session = await makeSession();
    final before = session.state.coins;
    // teselli parası yalnız normal bölümlerde (JS: endless dalı para vermez)
    await tester.pumpWidget(host(session, levelDef(0)));
    await tester.pump(const Duration(milliseconds: 120)); // layout + ilk frame

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    final e = state.engineForTest;
    // kalkanı sıfırla, sonra tam ıska
    e.shieldsLeft = 0;
    e.moving!.x = e.blocks.last.x - e.moving!.w - 60;
    e.drop();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(e.state, EngineState.lost);
    expect(find.text('BİTİYORDU!'), findsOneWidget);
    expect(session.state.coins, before + 2);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('HARİTA tek dokunuşla zinciri kapatır (onFlowDone bir kez, overlay kalkar)', (tester) async {
    final session = await makeSession();
    var flowDone = 0;
    await tester.pumpWidget(
        host(session, levelDef(0), onFlowDone: () => flowDone++));
    await tester.pump(const Duration(milliseconds: 120));

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    final e = state.engineForTest;
    for (var i = 0; i < 8; i++) {
      e.moving!.x = e.blocks.last.x;
      e.drop();
    }
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('BÖLÜM TAMAM!'), findsOneWidget);

    // ui.js paritesi: sonuç butonu doğrudan showMap çağırır — tek dokunuş yeter
    await tester.tap(find.text('HARİTA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(flowDone, 1);
    expect(find.text('BÖLÜM TAMAM!'), findsNothing);

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('SONRAKİ sonrası kayıpta TEKRAR doğru bölümle (i=1) yeniden başlatır', (tester) async {
    final session = await makeSession();
    await tester.pumpWidget(host(session, levelDef(0)));
    await tester.pump(const Duration(milliseconds: 120));

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    var e = state.engineForTest;
    // bölüm 0'ı kazan → SONRAKİ BÖLÜM görünür
    for (var i = 0; i < 8; i++) {
      e.moving!.x = e.blocks.last.x;
      e.drop();
    }
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('SONRAKİ BÖLÜM →'), findsOneWidget);

    // SONRAKİ: aynı ekran, tanım i=1
    await tester.tap(find.text('SONRAKİ BÖLÜM →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    e = state.engineForTest;
    expect(e.def!.i, 1);
    expect(session.currentDef!.i, 1);

    // i=1'de kaybet
    e.shieldsLeft = 0;
    e.moving!.x = e.blocks.last.x - e.moving!.w - 60;
    e.drop();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('BİTİYORDU!'), findsOneWidget);

    // TEKRAR: motor ve oturum hâlâ i=1'de olmalı (widget.def i=0 gerilemesi yok)
    await tester.tap(find.text('TEKRAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    e = state.engineForTest;
    expect(e.def!.i, 1);
    expect(session.currentDef!.i, 1);

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('geri düğmesi çift dokunma onayı: ilk dokunuş çıkmaz, ikincisi çıkarır', (tester) async {
    final session = await makeSession();
    var exits = 0;
    await tester.pumpWidget(host(session, endlessDef(), onExit: () => exits++));
    await tester.pump(const Duration(milliseconds: 120));

    // İlk dokunuş: yalnız silahlanır — yanlışlıkla çıkış yok
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(exits, 0);
    expect(find.text('Çıkmak için tekrar dokun'), findsOneWidget);

    // İkinci dokunuş: onaylanmış çıkış
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(exits, 1);

    // Toast + onay sıfırlama zamanlayıcılarını akıt (pending timer kalmasın)
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
