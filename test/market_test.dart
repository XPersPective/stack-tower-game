/// PB-018 — pazar yeri: rotasyon determinizmi, ekonomi, sandık, eski kayıt.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/market.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/map/journey_map.dart';
import 'package:stack_tower_game/screens/market_screen.dart';
import 'package:stack_tower_game/services/storage.dart';

void main() {
  group('günlük rotasyon', () {
    test('aynı gün → aynı tezgah (deterministik)', () {
      final a = dailyStock(42);
      final b = dailyStock(42);
      expect(a.map((e) => e.id).toList(), b.map((e) => e.id).toList());
      expect(a.map((e) => e.price).toList(), b.map((e) => e.price).toList());
    });

    test('PB-034 D3: tomorrowStock = dailyStock(day+1) — YARIN önizlemesi', () {
      final today = dailyStock(500);
      final tomorrow = tomorrowStock(500);
      expect(tomorrow.length, today.length);
      for (var i = 0; i < tomorrow.length; i++) {
        expect(tomorrow[i].name, isNot('')); // isimli ürünler
      }
      // bugün ≠ yarın (tohum farklı — dönüş hissi)
      final tNames = tomorrow.map((e) => e.name).toList();
      final bNames = today.map((e) => e.name).toList();
      expect(tNames, isNot(equals(bNames)));
    });

    test('3 ürün + 1 gizli sandık; fiyatlar 40-150 aralığında', () {
      for (final day in [0, 1, 7, 12345]) {
        final stock = dailyStock(day);
        expect(stock.length, 4, reason: 'gün $day');
        expect(stock.where((e) => e.isChest).length, 1);
        for (final e in stock) {
          expect(e.price, inInclusiveRange(40, 150), reason: '${e.id} fiyat');
          expect(e.id, isNotEmpty);
        }
      }
    });

    test('tezgah güne bağlı: satın alma rotasyonu DEĞİŞTİRMEZ', () {
      final s = prog.SaveState(coins: 500);
      final before = dailyStock(3).map((e) => e.id).toList();
      final skin = dailyStock(3).firstWhere((e) => e.kind == MarketKind.skin);
      buy(s, skin);
      expect(dailyStock(3).map((e) => e.id).toList(), before,
          reason: 'stok kapanır, ürünler yer değiştirmez');
    });

    test('sahip olunan görünüm satın alınamaz', () {
      final s = prog.SaveState(coins: 500);
      final skin = dailyStock(3).firstWhere((e) => e.kind == MarketKind.skin);
      s.skins.add(skin.skinId!);
      final r = buy(s, skin);
      expect(r.ok, isFalse);
      expect(r.message, 'ZATEN SAHİPSİN');
      expect(s.coins, 500);
    });

    test('gün değişince stok tazelenir', () {
      final s = prog.SaveState(coins: 500);
      rollDay(s, 10);
      final e = dailyStock(10).first;
      buy(s, e);
      expect(soldOut(s, e), isTrue);
      rollDay(s, 11);
      expect(soldOut(s, e), isFalse);
    });
  });

  group('satın alma ekonomisi', () {
    test('para düşer, stok kapanır, ikinci alım reddedilir', () {
      final s = prog.SaveState(coins: 500);
      final e = dailyStock(5).firstWhere((e) => !e.isChest);
      final before = s.coins;
      final r1 = buy(s, e);
      expect(r1.ok, isTrue);
      expect(s.coins, before - e.price);
      expect(soldOut(s, e), isTrue);
      final r2 = buy(s, e);
      expect(r2.ok, isFalse);
      expect(r2.message, 'TÜKENDİ');
      expect(s.coins, before - e.price);
    });

    test('yetersiz para → reddedilir, bakiye değişmez, stok açık kalır', () {
      final s = prog.SaveState(coins: 10);
      final e = dailyStock(5).first;
      final r = buy(s, e);
      expect(r.ok, isFalse);
      expect(r.message, 'YETERSİZ PARA');
      expect(s.coins, 10);
      expect(soldOut(s, e), isFalse);
    });

    test('kalkan / çarpan / joker bayrakları yazılır', () {
      final s = prog.SaveState(coins: 500);
      final stock = dailyStock(5);
      final shield = stock.firstWhere((e) => e.kind == MarketKind.shield);
      buy(s, shield);
      expect(s.marketShields, 1);

      final s2 = prog.SaveState(coins: 500);
      final dbl = dailyStock(4).firstWhere((e) => e.kind == MarketKind.double);
      buy(s2, dbl);
      expect(s2.marketDouble, isTrue);

      final s3 = prog.SaveState(coins: 500);
      final joker = dailyStock(5).firstWhere((e) => e.kind == MarketKind.joker);
      buy(s3, joker);
      expect(s3.marketJoker, isTrue);
    });

    test('görünüm satın alımı envantere ekler', () {
      final s = prog.SaveState(coins: 500);
      final skin = dailyStock(9).firstWhere((e) => e.kind == MarketKind.skin);
      buy(s, skin);
      expect(s.skins, contains(skin.skinId));
    });
  });

  group('gizli sandık (değişken oran)', () {
    MarketEntry chestOf(int day) =>
        dailyStock(day).firstWhere((e) => e.isChest);

    test('%45 para: +120', () {
      final s = prog.SaveState(coins: 500);
      final e = chestOf(5);
      final before = s.coins;
      final r = buy(s, e, rand: _FixedRandom(0.1));
      expect(r.ok, isTrue);
      expect(s.coins, before - e.price + 120);
    });

    test('%30 görünüm: sahip olunmayan deri açılır', () {
      final s = prog.SaveState(coins: 500);
      final e = chestOf(5);
      final r = buy(s, e, rand: _FixedRandom(0.5));
      expect(r.ok, isTrue);
      expect(r.skinId, isNotNull);
      expect(s.skins, contains(r.skinId));
    });

    test('%25 kalıntı parçası: 3 parça birleşince kalıntı verilir', () {
      final s = prog.SaveState(coins: 500, relicPieces: 2);
      final e = chestOf(5);
      final r = buy(s, e, rand: _FixedRandom(0.9));
      expect(r.ok, isTrue);
      expect(s.relicPieces, 0, reason: '3 parça tüketildi');
      expect(s.relics['0'], isTrue, reason: 'ilk kalıntı açıldı');
    });

    test('para asla negatife düşmez', () {
      final s = prog.SaveState(coins: 0);
      for (final e in dailyStock(6)) {
        buy(s, e);
        expect(s.coins, greaterThanOrEqualTo(0));
      }
    });
  });

  group('kayıt uyumu ve oturum entegrasyonu', () {
    test('eski kayıt (market alanları yok) sorunsuz yüklenir', () {
      final old = prog.SaveState.fromJson({'v': 2, 'coins': 33, 'best': 7});
      expect(old.coins, 33);
      expect(old.marketDay, -1);
      expect(old.marketBought, isEmpty);
      expect(old.marketShields, 0);
      expect(old.marketDouble, isFalse);
      expect(old.marketJoker, isFalse);
      expect(old.relicPieces, 0);
    });

    test('yeni alanlar JSON gidiş-dönüşünde korunur', () {
      final s = prog.SaveState(coins: 120, marketShields: 2, marketJoker: true);
      s.marketDay = 77;
      s.marketBought['shield'] = true;
      s.relicPieces = 2;
      final back = prog.SaveState.fromJson(
          Map<String, dynamic>.from(s.toJson()));
      expect(back.marketDay, 77);
      expect(back.marketBought['shield'], isTrue);
      expect(back.marketShields, 2);
      expect(back.marketJoker, isTrue);
      expect(back.relicPieces, 2);
    });

    test('kalkan ve çarpan bir sonraki bölümde tüketilir', () {
      // PB-032: saat SABİT — aksi halde test, günün sürpriz döngüsüne bağlı
      // olur ve her 4 günde bir kendiliğinden kırılır (tarihe bağlı test ✗).
      // 20001 günü: (0 + 20001) % 4 != 0 → bölüm 0'a sürpriz düşmez.
      final session = GameSession(MemoryStorage(),
          clock: () => DateTime.fromMillisecondsSinceEpoch(86400000 * 20001));
      session.state.marketShields = 1;
      session.state.marketDouble = true;
      final start = session.prepareLevel(levelDef(0));
      expect(start.shields, 2, reason: '1 taban + 1 pazar kalkanı');
      expect(session.doubleCoinsThisLevel, isTrue);
      expect(session.state.marketShields, 0);
      expect(session.state.marketDouble, isFalse);
    });

    test('joker kazanılan bölümde +1 yıldız verir (tavan 3)', () {
      final session = GameSession(MemoryStorage());
      final def = levelDef(0);
      session.prepareLevel(def);
      session.state.marketJoker = true;
      session.onWin(def.target, 0); // perfects 0 → taban 1 yıldız
      final stars = session.state.completed[def.i]!['stars']!;
      expect(stars, 2, reason: 'joker +1');
      expect(session.state.marketJoker, isFalse, reason: 'tek kullanım');
    });
  });

  group('harita (yol)', () {
    test('3 bölüm bitmiş adada pazar tezgahı hitTest market döner', () {
      final session = GameSession(MemoryStorage());
      final nodes = journeyLayout(session, 420);
      final stall = Offset(nodes[2].pos.dx + 96, nodes[2].pos.dy + 8);
      expect(journeyHitTest(nodes, stall, marketOpen: true), 'market');
      expect(journeyHitTest(nodes, stall, marketOpen: false), isNull);
    });
  });

  group('pazar ekranı', () {
    testWidgets('ürün listelenir, AL → bakiye düşer, TÜKENDİ olur', (tester) async {
      final session = GameSession(MemoryStorage());
      session.state.coins = 500;
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: AudioController()),
        ],
        child: const MaterialApp(home: MarketScreen(rand: null)),
      ));
      await tester.pump();

      expect(find.text('PAZAR YERİ'), findsOneWidget);
      // PB-034 D3: YARIN şeridi — yarınki tezgâh bedava öngörülür
      expect(find.textContaining('YARIN:'), findsOneWidget);
      final before = session.state.coins;
      await tester.tap(find.text('AL').first);
      await tester.pump();
      expect(session.state.coins, lessThan(before));
      expect(find.text('TÜKENDİ'), findsWidgets);
    });
  });
}

/// Harita testi için sahte repaint kaynağı.


/// Sabit değer döndüren Random (sandık oranı testleri).
class _FixedRandom implements math.Random {
  _FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => (value * max).floor().clamp(0, max - 1);
  @override
  bool nextBool() => value >= 0.5;
}
