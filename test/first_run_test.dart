/// PB-021 — ilk-5 deneyim passi: tol affordansı, mini sürpriz kapısı,
/// pazar keşfi (bir kez).
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/gameplay.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/services/storage.dart';

/// Sabit değer döndüren Random (kapı oranı testleri).
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

GamePlay _engine(int levelIdx) {
  final e = GamePlay();
  e.resize(460, 780);
  e.startLevel(levelDef(levelIdx));
  return e;
}

void main() {
  group('tol affordansı (yalnız 1. bölüm, ilk 5 blok)', () {
    test('1. bölümde 8px sapma mükemmel sayılır (tol 12)', () {
      final e = _engine(0);
      final top = e.blocks.last;
      e.moving!.x = top.x + 8;
      e.moving!.w = top.w;
      e.drop();
      expect(e.perfects, 1, reason: 'affedici tolerans');
      expect(e.combo, 1);
    });

    test('2. bölümde aynı sapma mükemmel DEĞİL (JS paritesi tol 6)', () {
      final e = _engine(1);
      final top = e.blocks.last;
      e.moving!.x = top.x + 8;
      e.moving!.w = top.w;
      e.drop();
      expect(e.perfects, 0);
    });

    test('1. bölümde 6. bloktan sonra tolerans normale döner', () {
      final e = _engine(0);
      for (var i = 0; i < 6; i++) {
        final top = e.blocks.last;
        e.moving!.x = top.x;
        e.moving!.w = top.w;
        e.drop();
        e.tick(0.2);
      }
      final top = e.blocks.last;
      e.moving!.x = top.x + 8;
      e.moving!.w = top.w;
      e.drop();
      expect(e.perfects, 6, reason: 'ilk 5 blok affedildi, 6. blok affedilmez');
    });
  });

  group('mini sürpriz kapısı (ilk 5 bölüm)', () {
    test('her ilk-5 bölümünde ödül gelir; tekrar oynatmada gelmez', () {
      final s = GameSession(MemoryStorage());
      for (var i = 0; i < 5; i++) {
        final def = levelDef(i);
        s.prepareLevel(def);
        final before = s.state.coins;
        final rw = s.onWin(def.target, 3);
        expect(s.lastFirstRunGift, isNotNull, reason: 'bölüm $i');
        expect(s.state.coins - before, rw.coins,
            reason: 'rapor ile cüzdan tutarlı (bölüm $i)');
        // aynı bölüm tekrar: firstClear yok → kapı yok
        s.prepareLevel(def);
        s.onWin(def.target, 3);
        expect(s.lastFirstRunGift, isNull, reason: 'bölüm $i tekrar');
      }
    });

    test('para dilimi: 20-60 arası ve cüzdana yazılır', () {
      final s = GameSession(MemoryStorage());
      s.firstRunRand = _FixedRandom(0.10); // para dilimi
      final def = levelDef(0);
      s.prepareLevel(def);
      final before = s.state.coins;
      final rw = s.onWin(def.target, 3);
      expect(s.lastFirstRunGift, contains('🪙'));
      final gain = s.state.coins - before;
      expect(gain, rw.coins);
      expect(gain, greaterThanOrEqualTo(20));
    });

    test('görünüm dilimi: sahip olunmayan deri açılır', () {
      final s = GameSession(MemoryStorage());
      s.firstRunRand = _FixedRandom(0.85);
      final def = levelDef(1);
      s.prepareLevel(def);
      s.onWin(def.target, 3);
      expect(s.lastFirstRunGift, contains('GÖRÜNÜMÜ'));
      expect(s.state.skins.length, greaterThan(1));
    });

    test('kalıntı dilimi: parça sayacı artar', () {
      final s = GameSession(MemoryStorage());
      s.firstRunRand = _FixedRandom(0.99);
      final def = levelDef(2);
      s.prepareLevel(def);
      s.onWin(def.target, 3);
      expect(s.state.relicPieces, 1);
    });

    test('6. bölümde kapı yok', () {
      final s = GameSession(MemoryStorage());
      final def = levelDef(5);
      s.prepareLevel(def);
      s.onWin(def.target, 3);
      expect(s.lastFirstRunGift, isNull);
    });
  });

  group('pazar keşfi', () {
    test('3. bölümden sonra bir kez tetiklenir', () {
      final s = GameSession(MemoryStorage());
      for (var i = 0; i < 3; i++) {
        final def = levelDef(i);
        s.prepareLevel(def);
        s.onWin(def.target, 3);
      }
      expect(s.pendingMarketDiscovery, isTrue);
      // harita keşfi işaretleyince bir daha tetiklenmez
      s.pendingMarketDiscovery = false;
      s.state.marketSeen = true;
      final def = levelDef(3);
      s.prepareLevel(def);
      s.onWin(def.target, 3);
      expect(s.pendingMarketDiscovery, isFalse);
    });

    test('ilk 2 bölümde keşif yok', () {
      final s = GameSession(MemoryStorage());
      for (var i = 0; i < 2; i++) {
        final def = levelDef(i);
        s.prepareLevel(def);
        s.onWin(def.target, 3);
      }
      expect(s.pendingMarketDiscovery, isFalse);
      expect(s.state.levelsDone, 2);
    });

    test('marketSeen kayıtta korunur', () {
      final s = prog.SaveState(marketSeen: true);
      final back = prog.SaveState.fromJson(Map<String, dynamic>.from(s.toJson()));
      expect(back.marketSeen, isTrue);
    });
  });
}
