import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/gameplay.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/twists.dart';
import 'package:stack_tower_game/screens/play_screen.dart';
import 'package:stack_tower_game/services/storage.dart';


/// kindFor sırasına göre n. stack bölümünün indeksi (PB-041 dinamik dağıtım).
int nthStackLevel(int n) {
  var seen = -1;
  for (var i = 0; i < kLevelCount; i++) {
    if (kindFor(i) == GameKind.stack) {
      seen++;
      if (seen == n) return i;
    }
  }
  return -1;
}

void main() {
  // Tarih-duyarlı sürpriz döngüsünü sabitle (market_test kalıbı):
  // 20001. gün → levelDef(2) için (2+20001)%4 = 3 ≠ 0 → sürpriz yok.
  Future<GameSession> makeSession() async => GameSession(MemoryStorage(),
      clock: () => DateTime.fromMillisecondsSinceEpoch(86400000 * 20001));

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
    await tester.pumpWidget(host(session, levelDef(2))); // hedef 8
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

    // PB-037 result-first: İLK sonuç (BÖLÜM TAMAM!) → DEVAM → inşaat 'yükseldi'
    expect(find.text('BÖLÜM TAMAM!'), findsOneWidget);
    await tester.tap(find.text('DEVAM'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.textContaining('yükseldi'), findsOneWidget);
    // ödül uygulandı
    expect(session.state.completed[2], isNotNull);
    // inşaat DEVAM → zincir biter (kutu/dünya yok) → showMap kapanır
    await tester.tap(find.text('DEVAM'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('BÖLÜM TAMAM!'), findsNothing);
    // yıldız animasyon zamanlayıcılarının tamamı akıtılsın (pending timer yok)
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('PB-037 X8 comeback: 2 ardışık kayıp → rozet + TEKRAR ×2 para', (tester) async {
    final session = await makeSession();

    // 1. kayıp
    await tester.pumpWidget(host(session, levelDef(2)));
    await tester.pump(const Duration(milliseconds: 120));
    final e1 = tester.state<PlayScreenState>(find.byType(PlayScreen)).engineForTest;
    e1.shieldsLeft = 0;
    e1.moving!.x = e1.blocks.last.x - e1.moving!.w - 60;
    e1.drop();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(session.state.lastLossStreak, 1);
    expect(find.textContaining('BU TUR'), findsNothing); // 1. kayıpta rozet yok
    await tester.tap(find.text('TEKRAR'));
    await tester.pump(const Duration(milliseconds: 120));

    // 2. kayıp → comeback bayrağı
    final e2 = tester.state<PlayScreenState>(find.byType(PlayScreen)).engineForTest;
    e2.shieldsLeft = 0;
    e2.moving!.x = e2.blocks.last.x - e2.moving!.w - 60;
    e2.drop();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(session.state.lastLossStreak, 2);
    expect(find.textContaining('BU TUR ×2 PARA'), findsOneWidget);

    // TEKRAR → boost tüketilir, sonraki kazanım ×2
    await tester.tap(find.text('TEKRAR'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(session.pendingComebackBoost, isFalse);
    expect(session.doubleCoinsThisLevel, isTrue);
    // temiz kapanış: pending timer yok
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('kaybetme: teselli 2 para ve sonuç overlay', (tester) async {
    final session = await makeSession();
    final before = session.state.coins;
    // teselli parası yalnız normal bölümlerde (JS: endless dalı para vermez)
    await tester.pumpWidget(host(session, levelDef(2)));
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
    expect(find.text('NEREDEYSE!'), findsOneWidget); // PB-033 C5: kayıp başlığı
    expect(session.state.coins, before + 2);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('HARİTA tek dokunuşla zinciri kapatır (onFlowDone bir kez, overlay kalkar)', (tester) async {
    final session = await makeSession();
    var flowDone = 0;
    await tester.pumpWidget(
        host(session, levelDef(2), onFlowDone: () => flowDone++));
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
    // PB-037 result-first: İLK sonuç ekranı
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

  testWidgets('SONRAKİ: antoloji — sıradaki bölüm FARKLI türe geçer (i=3 → LAUNCH)', (tester) async {
    final session = await makeSession();
    await tester.pumpWidget(host(session, levelDef(2)));
    await tester.pump(const Duration(milliseconds: 120));

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    final e = state.engineForTest;
    expect(state.gameForTest.kind, GameKind.stack);
    for (var i = 0; i < 8; i++) {
      e.moving!.x = e.blocks.last.x;
      e.drop();
    }
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    // result-first: result → DEVAM → inşaat kartı → DEVAM → harita
    await tester.tap(find.text('DEVAM'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.textContaining('yükseldi'), findsOneWidget);
    await tester.tap(find.text('DEVAM'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    // zincir kapandı (showMap) — sıradaki bölüm türü antoloji yasasıyla FARKLI
    expect(find.text('BÖLÜM TAMAM!'), findsNothing);
    expect(kindFor(3), GameKind.launch); // i=3 → LAUNCH (STACK değil)

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('TEKRAR: kayıptan sonra aynı bölüm ve aynı türle yeniden başlar', (tester) async {
    final session = await makeSession();
    await tester.pumpWidget(host(session, levelDef(2)));
    await tester.pump(const Duration(milliseconds: 120));

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    final e = state.engineForTest;
    // kaybet: kalkan yok + tam ıska
    e.shieldsLeft = 0;
    e.moving!.x = e.blocks.last.x - e.moving!.w - 60;
    e.drop();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('NEREDEYSE!'), findsOneWidget); // PB-033 C5: kayıp başlığı

    await tester.tap(find.text('TEKRAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(session.currentDef!.i, 2);
    expect(state.gameForTest.kind, GameKind.stack);
    expect(state.engineForTest.score, 0, reason: 'motor sıfırlanmış olmalı');

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('geri düğmesi çift dokunma onayı: ilk dokunuş çıkmaz, ikincisi çıkarır', (tester) async {
    final session = await makeSession();
    var exits = 0;
    await tester.pumpWidget(host(session, endlessDef(), onExit: () => exits++));
    await tester.pump(const Duration(milliseconds: 120));

    // İlk dokunuş: yalnız silahlanır — yanlışlıkla çıkış yok
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    expect(exits, 0);
    expect(find.text('Çıkmak için tekrar dokun'), findsOneWidget);

    // İkinci dokunuş: onaylanmış çıkış
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    expect(exits, 1);

    // Toast + onay sıfırlama zamanlayıcılarını akıt (pending timer kalmasın)
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  testWidgets('twist bölümü açılışta duyurulur: ad + hint toast (RÜZGAR GÜLÜ)', (tester) async {
    final session = await makeSession();
    // n=2 → 3. stack bölümü; twist şeması ruzgargulu verir (PB-041 dinamik indeks)
    final i3rd = nthStackLevel(2);
    await tester.pumpWidget(host(session, levelDef(i3rd)));
    await tester.pump(const Duration(milliseconds: 120));
    final t = kTwists[twistFor(i3rd)]!;
    expect(t.type, TwistType.ruzgargulu);
    expect(find.textContaining('RÜZGAR GÜLÜ'), findsOneWidget);
    expect(find.textContaining(t.hint), findsOneWidget);
    // toast süreölçerini akıt (pending timer kalmasın)
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  test('KRİTİK ×5 ve ALTIN blok paraları kazanan bölümde cüzdana yazılır', () async {
    final session = await makeSession();
    final def = levelDef(5); // stack → ALTIN YAĞMURU (ilk-5 şeması)
    session.prepareLevel(def);
    final before = session.state.coins;
    final rw = session.onWin(10, 5, crits: 2, goldBlocks: 3);
    final twistPay = 2 * 8 + 3 * 10; // KRİTİK mükemmel ×5 (taban 2 + 8 = 10), altın blok 10
    expect(rw.coins, greaterThanOrEqualTo(def.coins + 5 * 2 + twistPay),
        reason: 'ödül raporu taban + twist parası içermeli');
    expect(session.state.coins - before, rw.coins,
        reason: 'rapor ile cüzdan tutarlı (inceleme bulgusu kapanışı)');
  });

  test('kayıpta twist parası ödenmez — para birikmez', () async {
    final session = await makeSession();
    session.prepareLevel(levelDef(5));
    final before = session.state.coins;
    final rw = session.onLose(10, 5);
    expect(rw.coins, 2, reason: 'teselli 2 (progress completeLevel)');
    expect(session.state.coins - before, 2);
  });

  testWidgets('juice (PB-016): hit-stop penceresinde dokunuş blok düşürmez', (tester) async {
    final session = await makeSession();
    await tester.pumpWidget(host(session, endlessDef()));
    await tester.pump(const Duration(milliseconds: 120));

    final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
    final e = state.engineForTest;
    e.moving!.x = e.blocks.last.x;
    await tester.tap(find.byType(PlayScreen));
    await tester.pump();
    expect(e.score, 1);
    expect(e.hitStop, greaterThan(0), reason: 'mükemmel → hit-stop penceresi açık');
    final blocks = e.blocks.length;

    // pencere içindeki dokunuş yok sayılır (kenarda donmuş blok = garantili ıskalama)
    await tester.tap(find.byType(PlayScreen));
    await tester.pump();
    expect(e.blocks.length, blocks, reason: 'hit-stop sırasında blok düşmemeli');

    // pencere kapanınca tek dokunuş akışı aynen çalışır
    await tester.pump(const Duration(milliseconds: 120));
    e.moving!.x = e.blocks.last.x;
    await tester.tap(find.byType(PlayScreen));
    await tester.pump();
    expect(e.blocks.length, blocks + 1, reason: 'pencere sonrası dokunuş normal');
  });
}
