import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/gameplay.dart';

/// C-002: silüet RNG'si `GamePlay.mulberry32`, `reference/www/game.js`
/// içindeki `mulberry()` ile birebir olmalı. Snapshot'ı üreten:
/// `node tools_js/gen_silhouette_snapshot.js` (fonksiyonu game.js'ten çıkarır).
void main() {
  test('mulberry32: reference snapshot ile birebir (36 benzersiz seed × 12 değer)', () {
    final file = File('test/fixtures/silhouette_snapshot.json');
    expect(file.existsSync(), isTrue,
        reason: 'fixture yok — önce: node tools_js/gen_silhouette_snapshot.js');
    final snap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    // 40 kombinasyon, 36 benzersiz seed: 'buz'/'bulut' ikisi de 'b' ile başlar
    // → charCodeAt(0)*97 tohumları çakışır (JS'te de böyle, parite korunur).
    expect(snap.length, 36);
    snap.forEach((seed, values) {
      final rng = GamePlay.mulberry32(int.parse(seed));
      for (final v in (values as List)) {
        expect(rng(), equals((v as num).toDouble()), reason: 'seed $seed saptı');
      }
    });
  });

  test('mulberry32: ölçülmüş JS değerleri — seed 11155 (sehir/L0/S0)', () {
    const expected = [
      0.2816482132766396, 0.28427818324416876, 0.3395198250655085,
      0.5390985833946615, 0.8163364948704839, 0.6763891361188143,
      0.04657354950904846, 0.9969855630770326, 0.4857951169833541,
      0.34310195059515536,
    ];
    final rng = GamePlay.mulberry32(11155);
    for (final e in expected) {
      expect(rng(), equals(e));
    }
  });
}
