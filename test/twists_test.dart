import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/gameplay.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/twists.dart';

void main() {
  group('dağıtım yasası (C-017)', () {
    test('ilk 5 bölüm: hard-coded 5 farklı deneyim şeması', () {
      expect(twistFor(0), isNull); // KLASİK öğretir
      expect(twistFor(1), TwistType.altinyagmuru);
      expect(twistFor(2), TwistType.ruzgargulu);
      expect(twistFor(3), TwistType.zitakis);
      expect(twistFor(4), TwistType.kritik);
    });

    test('150 bölümde: ardışık aynı twist ≤2 ve her 3 bölümden 1\'i twistli', () {
      TwistType? prev, prev2;
      var twistCount = 0;
      for (var i = 5; i < kLevelCount; i++) {
        final t = twistFor(i);
        if (t != null) twistCount++;
        // ardışık tekrar ≤2
        if (t != null && prev == t && prev2 == t) {
          fail('i=$i: 3 ardışık aynı twist ($t)');
        }
        prev2 = prev;
        prev = t;
      }
      // her 3'te 1: (150-5) bölümün ~1/3'ü
      expect(twistCount, inInclusiveRange(40, 52), reason: 'twist sayısı: $twistCount');
    });

    test('günlük/serbest negatif indeks: twist yok', () {
      expect(twistFor(-1), isNull);
      expect(twistFor(-2), isNull);
    });

    test('tüm twist tanımları dolu (isim/ikon/ipucu)', () {
      for (final t in TwistType.values) {
        expect(kTwists[t]!.name, isNotEmpty);
        expect(kTwists[t]!.icon, isNotEmpty);
        expect(kTwists[t]!.hint, isNotEmpty);
      }
    });
  });

  group('motor etkileri', () {
    GamePlay engineFor(TwistType? twist) {
      final e = GamePlay();
      e.resize(460, 780);
      e.startLevel(endlessDef(), twistType: twist);
      return e;
    }

    void dropPerfect(GamePlay e) {
      e.moving!.x = e.blocks.last.x;
      e.moving!.w = e.blocks.last.w;
      e.drop();
    }

    test('KRİTİK: zorlanmış zar → crit sayacı artar', () {
      final e = engineFor(TwistType.kritik);
      e.critRoll = () => 0.1; // <0.20 → kritik
      dropPerfect(e);
      expect(e.crits, 1);
      e.critRoll = () => 0.9; // kritik değil
      dropPerfect(e);
      expect(e.crits, 1);
      e.critRoll = () => 0.05;
      dropPerfect(e);
      expect(e.crits, 2);
    });

    test('ZİT AKIŞ: mükemmelle taraf KORUNUR (normalde değişirdi)', () {
      final normal = engineFor(null);
      final b0n = movingBoundsOf(normal, normal.blocks.last);
      final side0n = normal.moving!.x < b0n.$1 + (b0n.$2 - b0n.$1) / 2;
      dropPerfect(normal);
      final b1n = movingBoundsOf(normal, normal.blocks.last);
      final side1n = normal.moving!.x < b1n.$1 + (b1n.$2 - b1n.$1) / 2;
      expect(side1n, isNot(side0n), reason: 'normal: her blokta taraf değişir');

      final e = engineFor(TwistType.zitakis);
      final b0 = movingBoundsOf(e, e.blocks.last);
      final side0 = e.moving!.x < b0.$1 + (b0.$2 - b0.$1) / 2;
      dropPerfect(e);
      final b1 = movingBoundsOf(e, e.blocks.last);
      final side1 = e.moving!.x < b1.$1 + (b1.$2 - b1.$1) / 2;
      expect(side1, side0, reason: 'zitakis: flip taban pariteyi dengeler');
    });

    test('SIÇRAYAN: blok merkeze doğru en fazla 8px toparlanır', () {
      final e = engineFor(TwistType.sicrayan);
      final top = e.blocks.last;
      e.moving!.x = top.x + 14; // 14px kayma (tol 6 dışı → kırpılır)
      e.moving!.w = top.w;
      e.drop();
      final placed = e.blocks.last;
      final gapBefore = (top.x + top.w / 2) - (top.x + 14 + (top.w - 14) / 2);
      final expectedNudge = gapBefore.clamp(-8.0, 8.0);
      expect(placed.x, closeTo(top.x + 14 + expectedNudge, 0.5),
          reason: 'sicrayan: merkez yönünde 8px affı');
    });

    test('ALTIN YAĞMURU: zorlanmış zar → altın blok sayacı', () {
      final e = GamePlay();
      e.resize(460, 780);
      e.goldRoll = () => 0.9; // spawn1 → altın değil
      e.startLevel(endlessDef(), twistType: TwistType.altinyagmuru);
      dropPerfect(e); // spawn1 değil; spawn2 (0.9) → değil
      expect(e.goldBlocks, 0);
      e.goldRoll = () => 0.1; // spawn3 (drop2 içinde) → altın
      dropPerfect(e);
      expect(e.goldBlocks, 0);
      dropPerfect(e); // spawn3 altın → 1; spawn4 (0.1) → altın
      expect(e.goldBlocks, 1);
      e.goldRoll = () => 0.9;
      dropPerfect(e); // spawn4 altın → 2
      expect(e.goldBlocks, 2);
      dropPerfect(e); // spawn5 (0.9) → değil
      expect(e.goldBlocks, 2);
    });

    test('DAR GEÇİT: spawn konumu daralan aralık içinde', () {
      final e = engineFor(TwistType.dargecit);
      final b = movingBoundsOf(e, e.blocks.last);
      dropPerfect(e);
      dropPerfect(e);
      // inset = min(w*0.3, blocks.length*6*scale) — 2 blokta 12*scale
      final inset = math.min(e.blocks.last.w * 0.3, e.blocks.length * 6.0 * e.scale);
      expect(e.moving!.x, greaterThanOrEqualTo(b.$1 + inset - 1e-6),
          reason: 'sol duvar içine doğdu');
      expect(e.moving!.x, lessThanOrEqualTo(b.$2 - inset + 1e-6),
          reason: 'sağ duvar içine doğdu');
    });

    test('hit-stop: mükemmelle mikro duraklama, büyük dt yutulmaz', () {
      final e = engineFor(TwistType.kritik);
      e.critRoll = () => 0.9;
      dropPerfect(e);
      expect(e.hitStop, greaterThan(0));
      final dt0 = 1.0;
      e.tick(dt0); // tek büyük tik — yutulmamalı
      expect(e.hitStop, lessThanOrEqualTo(0));
      // endTimer 1s içinde yine dolabilmeli
    });

    test('varsayılan (twistsiz) bölüm: kritik/altın yok', () {
      final e = engineFor(null); // endless → twist otomatik null
      dropPerfect(e);
      expect(e.crits, 0);
      expect(e.goldBlocks, 0);
      expect(e.hitStop, greaterThan(0)); // juice herkese
    });
  });
}

(double, double) movingBoundsOf(GamePlay e, dynamic top) {
  final minX = top.x - top.w * 1.05;
  return (minX, minX + top.w * 2.1);
}
