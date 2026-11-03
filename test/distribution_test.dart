/// PB-030 — dağıtım yasası + tür ödülü testleri (ADR-008, C-019/C-020).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/services/storage.dart';

void main() {
  group('dağıtım yasası (150 bölüm)', () {
    test('ardışık aynı tür yok (≤1 kuralı)', () {
      for (var i = 1; i < 150; i++) {
        expect(kindFor(i), isNot(kindFor(i - 1)), reason: 'i=$i tür tekrarı');
      }
    });

    test('ilk 5 bölüm 5 FARKLI tür (hook)', () {
      final first = [for (var i = 0; i < 5; i++) kindFor(i)];
      expect(first.toSet().length, 5);
      expect(first, kFirstFiveKinds);
    });

    test('10 türün tamamı 150 bölümde oynanır', () {
      final seen = <GameKind>{for (var i = 0; i < 150; i++) kindFor(i)};
      expect(seen.length, GameKind.values.length);
    });

    test('her dünya patronu (idx 14) imza tür — 10 dünyada 10 farklı patron', () {
      final bosses = <GameKind>[];
      for (var stage = 0; stage < kStageCount; stage++) {
        bosses.add(kindFor(stage * kLevelsPerStage + kLevelsPerStage - 1));
      }
      expect(bosses.toSet().length, kStageCount,
          reason: 'her dünyanın imza patron türü farklı olmalı');
    });

    test('günlük/serbest (i<0) stack', () {
      expect(kindFor(-1), GameKind.stack);
      expect(kindFor(-2), GameKind.stack);
    });
  });

  group('tür ödülü (C-019 cömertlik)', () {
    test('stack bonusu 0 (twist paralarıyla ödenir), diğerleri 2/3', () {
      expect(kindBonus(GameKind.stack, perfects: 9), 0);
      for (final k in GameKind.values.where((k) => k != GameKind.stack)) {
        expect(kindBonus(k, perfects: 0), 2, reason: '$k taban');
        expect(kindBonus(k, perfects: 3), 3, reason: '$k mükemmel bonusu');
      }
    });

    test('kazanılan bölümde tür bonusu cüzdana ve rapora yazılır', () async {
      final s = GameSession(MemoryStorage());
      final def = levelDef(0); // CATCH — stack dışı tür
      expect(def.kind, isNot(GameKind.stack));
      s.prepareLevel(def);
      final before = s.state.coins;
      final rw = s.onWin(def.target, 3);
      final bonus = kindBonus(def.kind, perfects: 3);
      expect(bonus, 3);
      expect(rw.coins, greaterThanOrEqualTo(def.coins + bonus));
      expect(s.state.coins - before, rw.coins,
          reason: 'rapor ile cüzdan tutarlı (bonus çift sayılmaz)');
      expect(s.state.coins, greaterThanOrEqualTo(0));
    });

    test('kayıpta tür bonusu ödenmez — para ≥0 kalır', () {
      // saat sabit: doubleCoins sürprizi tarihe göre denk gelmesin (PB-033 dersi)
      final s = GameSession(MemoryStorage(),
          clock: () => DateTime.fromMillisecondsSinceEpoch(86400000 * 20001));
      final def = levelDef(4); // MERGE
      s.prepareLevel(def);
      final before = s.state.coins;
      final rw = s.onLose(0, 0);
      expect(rw.coins, 2, reason: 'yalnız teselli (kindBonus yok)');
      expect(s.state.coins - before, 2);
      expect(s.state.coins, greaterThanOrEqualTo(0));
    });
  });
}
