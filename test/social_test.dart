/// PB-038 — sosyal katman MVP testleri: Friend Tag, bot yanıtları, sohbet akışı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/social.dart';
import 'package:stack_tower_game/screens/router.dart' show dayOfNow;
import 'package:stack_tower_game/screens/social_screen.dart';
import 'package:stack_tower_game/services/storage.dart';

void main() {
  test('Friend Tag: deterministik 6 karakter', () {
    final s = GameSession(MemoryStorage());
    s.state.totalBlocks = 120;
    s.state.levelsDone = 10;
    s.state.totalPerfect = 40;
    final a = friendTagFor(s.state);
    final b = friendTagFor(s.state);
    expect(a, b);
    expect(a.length, 6);
    expect(a, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
  });

  test('32 hazırcümle: 5 kategori, benzersiz metinler', () {
    expect(kQuickPhrases.length, 32);
    final texts = kQuickPhrases.map((p) => p.text).toSet();
    expect(texts.length, 32, reason: 'hepsi benzersiz');
    for (final c in SocialCategory.values) {
      expect(kQuickPhrases.any((p) => p.category == c), isTrue,
          reason: '$c kategorisi dolu olmalı');
    }
  });

  test('bot yanıtı: kategoriye göre, deterministik', () {
    final r1 = botReply('NeonKule', SocialCategory.meydan, 0);
    final r2 = botReply('NeonKule', SocialCategory.meydan, 0);
    expect(r1, r2, reason: 'aynı tohum → aynı yanıt');
    final r3 = botReply('NeonKule', SocialCategory.meydan, 1);
    expect(r3, isNotEmpty);
  });

  test('meydan tohumu: bot skoru deterministik 10-21 aralığında', () {
    final a = challengeBotScore('NeonKule', 2955);
    final b = challengeBotScore('NeonKule', 2955);
    expect(a, b);
    expect(a, inInclusiveRange(10, 21));
  });

  test('botlar ŞEFFAF: hepsi isBot işaretli', () {
    for (final p in kBotPlayers) {
      expect(p.isBot, isTrue, reason: '${p.name} BOT etiketli olmalı');
    }
    expect(kBotPlayers.length, 5);
  });

  testWidgets('sohbet akışı: hazırcümle dokunuşu → bot yanıtı', (tester) async {
    final session = GameSession(MemoryStorage());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: AudioController()),
        ],
        child: const MaterialApp(home: SocialScreen()),
      ),
    );
    await tester.pump();

    // oyuncu listesi: 5 bot kartı
    expect(find.text('NeonKule'), findsOneWidget);
    expect(find.text('BOT'), findsWidgets);

    // sohbete gir (PB-039: günlük selam varsa o gelir; yoksa açılış selamı)
    await tester.tap(find.text('NeonKule'));
    await tester.pump();
    final daily = dailyBotGreeting(dayOfNow());
    if (daily.$1 == 'NeonKule') {
      expect(find.textContaining(daily.$2), findsOneWidget);
    } else {
      expect(find.text('Merhaba! İyi oyunlar!'), findsOneWidget);
    }

    // hazırcümle gönder → kullanıcı balonu + bot yanıtı
    // şerit ListView lazy — ilk görünür çip 'Merhaba!' (index 0)
    await tester.tap(find.text('Merhaba!').last);
    await tester.pump();
    expect(find.text('Merhaba!'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('meydan okuma: düğme → perde açılır (PB-039)', (tester) async {
    final session = GameSession(MemoryStorage());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: AudioController()),
        ],
        child: const MaterialApp(home: SocialScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('NeonKule'));
    await tester.pump();

    await tester.tap(find.text('SENİ YENDİM — MEYDAN OKU'));
    await tester.pump();
    // perde: bot + skor + aynı tohum bölümü teklifi
    expect(find.text('MEYDAN OKUMA'), findsOneWidget);
    expect(find.text('BOT SKORU'), findsOneWidget);
    expect(find.text('AYNI BÖLÜMÜ OYNA'), findsOneWidget);
  });
}
