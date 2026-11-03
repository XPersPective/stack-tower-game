/// PB-039 — sosyal dalga 2 testleri: sohbet kalıcılığı, günlük bot selamı,
/// okunmamış bildirim balonu, meydan okuma perdesi akışı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/social.dart';
import 'package:stack_tower_game/screens/menu_screen.dart';
import 'package:stack_tower_game/screens/social_screen.dart';
import 'package:stack_tower_game/services/storage.dart';

void main() {
  test('Friend Tag + günlük selam: gün tohumlu bot + mesaj', () {
    final (bot1, text1) = dailyBotGreeting(100);
    final (bot2, text2) = dailyBotGreeting(101);
    expect(bot1, isNotEmpty);
    expect(text1, isNotEmpty);
    // komşu günlerde bot değişebilir (deterministik ama gün-bağlı)
    expect(bot1 == bot2 && text1 == text2, isFalse,
        reason: 'gün değişince selam değişmeli');
    // determinizm
    expect(dailyBotGreeting(100), (bot1, text1));
  });

  test('sohbet kalıcılığı: serialize → fromLogs yuvarlama', () {
    final t = ChatThread('NeonKule');
    t.addMine('Meydan okuyorum!', isChallenge: true);
    t.addMine('Harika kule!');
    final logs = t.serialize();
    expect(logs.length, greaterThanOrEqualTo(4)); // selam + bot yanıtları
    final t2 = ChatThread.fromLogs('NeonKule', logs);
    expect(t2.messages.length, t.messages.length);
    expect(t2.messages.any((m) => m.isChallenge && m.mine), isTrue,
        reason: 'meydan okuma işareti korunur');
    expect(t2.messages.last.text, t.messages.last.text);
  });

  test('günlük selam: yeni gün → socialUnread +1', () {
    var day = 20000;
    final session = GameSession(MemoryStorage(),
        clock: () => DateTime.fromMillisecondsSinceEpoch(day * 86400000));
    expect(session.state.socialUnread, 1, reason: 'kurulumda günün selamı');
    expect(session.state.socialSeedDay, 20000);
    // aynı gün tekrar kontrol → artmaz
    session.checkDailySocial();
    expect(session.state.socialUnread, 1);
    // gün ilerlet → yeni selam
    day = 20001;
    session.checkDailySocial();
    expect(session.state.socialUnread, 2);
  });

  testWidgets('menü: okunmamış varsa balon görünür', (tester) async {
    final session = GameSession(MemoryStorage());
    session.state.socialUnread = 2;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: const MaterialApp(home: MenuScreen()),
    ));
    await tester.pump();
    expect(find.text('2'), findsOneWidget, reason: 'bildirim balonu');
  });

  testWidgets('meydan okuma perdesi: düğme → bot skoru gösterilir', (tester) async {
    final session = GameSession(MemoryStorage());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: const MaterialApp(home: SocialScreen()),
    ));
    await tester.pump();
    await tester.tap(find.text('NeonKule'));
    await tester.pump();
    await tester.tap(find.text('SENİ YENDİM — MEYDAN OKU'));
    await tester.pump();
    expect(find.text('MEYDAN OKUMA'), findsOneWidget);
    expect(find.text('BOT SKORU'), findsOneWidget);
    expect(find.text('AYNI BÖLÜMÜ OYNA'), findsOneWidget);
  });

  testWidgets('sohbete girince okunmamış söner', (tester) async {
    final session = GameSession(MemoryStorage());
    session.state.socialUnread = 3;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: const MaterialApp(home: SocialScreen()),
    ));
    await tester.pump();
    expect(session.state.socialUnread, 0, reason: 'ekran açılışı okundu sayılır');
  });
}
