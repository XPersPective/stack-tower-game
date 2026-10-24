import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/drop_core.dart';

void main() {
  group('resolveDrop', () {
    test('tam üstüne → mükemmel, kırpılmaz', () {
      final r = resolveDrop(Moving(100, 80, 1), Block(100, 80), 6);
      expect(r.ok, isTrue);
      expect(r.perfect, isTrue);
      expect(r.placed!.x, 100);
      expect(r.placed!.w, 80);
      expect(r.cuts, isEmpty);
    });

    test('tolerans siniri: |Δx|=tol mükemmel, +0.01 değil', () {
      final r1 = resolveDrop(Moving(106, 80, 1), Block(100, 80), 6);
      expect(r1.perfect, isTrue);
      final r2 = resolveDrop(Moving(106.01, 80, 1), Block(100, 80), 6);
      expect(r2.perfect, isFalse);
      // genişlik farkı da tolerans içinde olmalı
      final r3 = resolveDrop(Moving(100, 86, 1), Block(100, 80), 6);
      expect(r3.perfect, isTrue);
      final r4 = resolveDrop(Moving(100, 86.01, 1), Block(100, 80), 6);
      expect(r4.perfect, isFalse);
    });

    test('sola kayma → sağ parça kırpılır, placed örtüşme', () {
      final r = resolveDrop(Moving(70, 80, 1), Block(100, 80), 6); // 70..150 üstüne 100..180
      expect(r.ok, isTrue);
      expect(r.perfect, isFalse);
      expect(r.placed!.x, 100);
      expect(r.placed!.w, 50);
      expect(r.cuts.length, 1);
      expect(r.cuts[0].x, closeTo(70, 1e-9));
      expect(r.cuts[0].w, closeTo(30, 1e-9));
    });

    test('sağa taşma → sağ parça kırpılır', () {
      final r = resolveDrop(Moving(130, 80, 1), Block(100, 80), 6); // 130..210
      expect(r.placed!.x, 130);
      expect(r.placed!.w, 50);
      expect(r.cuts.length, 1);
      expect(r.cuts[0].x, closeTo(180, 1e-9));
      expect(r.cuts[0].w, closeTo(30, 1e-9));
    });

    test('iki yandan taşma → iki parça', () {
      final r = resolveDrop(Moving(80, 120, 1), Block(100, 80), 6); // 80..200
      expect(r.placed!.x, 100);
      expect(r.placed!.w, 80);
      expect(r.cuts.length, 2);
    });

    test('sıfır örtüşme → ok:false, blok bütün düşer', () {
      final r = resolveDrop(Moving(10, 50, 1), Block(100, 80), 6);
      expect(r.ok, isFalse);
      expect(r.cuts.length, 1);
      expect(r.cuts[0].w, 50);
    });

    test('varsayılan tolerans 6 (kPerfectTolerance)', () {
      expect(resolveDrop(Moving(105.9, 80, 1), Block(100, 80)).perfect, isTrue);
      expect(resolveDrop(Moving(107, 80, 1), Block(100, 80)).perfect, isFalse);
    });
  });

  group('stepMoving + sınırlar', () {
    test('x [minX,maxX] dışına çıkmaz, sınırlarda yön döner', () {
      final top = Block(100, 80);
      final b = movingBounds(top);
      expect(b.minX, closeTo(100 - 80 * 1.05, 1e-9));
      expect(b.maxX - b.minX, closeTo(80 * 2.1, 1e-9));
      final m = Moving(b.minX, 80, 1);
      // minX'ten küçük adımla sağa çıkar: ilk karede hâlâ sağa yönelir
      stepMoving(m, top, 5, 1 / 120, 1.0);
      expect(m.dir, 1);
      expect(m.x, greaterThan(b.minX));
      for (var i = 0; i < 2000; i++) {
        stepMoving(m, top, 5, 1 / 60, 1.0);
        expect(m.x, greaterThanOrEqualTo(b.minX - 1e-9));
        expect(m.x, lessThanOrEqualTo(b.maxX + 1e-9));
      }
      // maxX'e ulaşınca -1'e dönmeli (sekme): büyük adım + hızlı çarpanla sınır aşımı
      final fast = Moving(b.maxX - 1, 80, 1);
      stepMoving(fast, top, 39, 1, 3.0); // mult=3 → adım = 168*3*3 ≫ kalan mesafe
      expect(fast.dir, -1);
      expect(fast.x, closeTo(b.maxX, 1e-9));
      // minX'te sola itilirse +1'e döner
      final left = Moving(b.minX + 1, 80, -1);
      stepMoving(left, top, 39, 1, 3.0);
      expect(left.dir, 1);
      expect(left.x, closeTo(b.minX, 1e-9));
    });

    test('clamp: aralık dışını kırpar', () {
      expect(clamp(5, 0, 10), 5);
      expect(clamp(-3, 0, 10), 0);
      expect(clamp(12, 0, 10), 10);
      expect(clamp(7, 7, 7), 7);
    });

    test('hız: travelRange*0.5*mult*scale*dt', () {
      final top = Block(0, 100); // sınırlar: [-105, 105]
      final m1 = Moving(-100, 100, 1);
      final m2 = Moving(-100, 100, 1);
      stepMoving(m1, top, 0, 0.5, 1.0); // mult=0.9 → 47.25
      stepMoving(m2, top, 39, 0.5, 1.0); // mult=3 (tavan) → 157.5 (sınıra takılmaz)
      final base = 100 * 2.1 * 0.5;
      expect(m1.x + 100, closeTo(base * 0.9 * 0.5, 1e-9));
      expect(m2.x + 100, closeTo(base * 3.0 * 0.5, 1e-9));
    });

    test('speedMultiplier tavanı 3', () {
      expect(speedMultiplier(0), closeTo(0.9, 1e-9));
      expect(speedMultiplier(38), closeTo(0.9 + 38 * 0.055, 1e-9)); // 2.99
      expect(speedMultiplier(39), 3.0);
      expect(speedMultiplier(100), 3.0);
    });
  });

  group('growthWidth', () {
    test('combo=4 → ×1.04; combo=8 → tekrar; baseW tavanı', () {
      const baseW = 230.0;
      expect(growthWidth(100, baseW, 3), 100); // 3 → aynı
      expect(growthWidth(100, baseW, 4), closeTo(104, 1e-9));
      expect(growthWidth(104, baseW, 8), closeTo(108.16, 1e-9));
      expect(growthWidth(229, baseW, 4), closeTo(230, 1e-9)); // tavan
      expect(growthWidth(230, baseW, 4), 230); // tavan aşmaz
      expect(growthWidth(100, baseW, 0), 100);
      expect(growthWidth(100, baseW, -4), 100); // negatif combo büyütmez
    });
  });
}
