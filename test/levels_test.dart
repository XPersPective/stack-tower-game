import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/levels.dart';

/// JS (reference/www/levels.js) çıktısıyla birebir parite — SPEC §8.
/// Fixture: `node tools_js/gen_levels_snapshot.js` ile üretilir.
Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/levels_js_snapshot.json').readAsStringSync());

void main() {
  test('150 bölüm: tüm denge alanları JS snapshot ile birebir', () {
    final levels = (_fixture()['levels'] as List).cast<Map<String, dynamic>>();
    expect(levels.length, kLevelCount);
    for (final e in levels) {
      final d = levelDef(e['i'] as int);
      expect(d.i, e['i'], reason: 'i=${e['i']}');
      expect(d.stage, e['stage'], reason: 'i=${e['i']}');
      expect(d.idx, e['idx'], reason: 'i=${e['i']}');
      expect(d.num, e['num'], reason: 'i=${e['i']}');
      expect(d.target, e['target'], reason: 'i=${e['i']}');
      expect(d.speed, closeTo((e['speed'] as num).toDouble(), 1e-9), reason: 'i=${e['i']}');
      expect(d.tol, e['tol'], reason: 'i=${e['i']}');
      expect(d.modifier, e['modifier'], reason: 'i=${e['i']}');
      expect(d.coins, e['coins'], reason: 'i=${e['i']}');
      expect(d.box, e['box'], reason: 'i=${e['i']}');
      expect(d.name, e['name'], reason: 'i=${e['i']}');
      expect(d.theme.id, e['themeId'], reason: 'i=${e['i']}');
    }
  });

  test('Bölüm kalıpları: patron/altın/%7 dağılımı', () {
    for (var i = 0; i < kLevelCount; i++) {
      final d = levelDef(i);
      if (d.idx == 14) expect(d.modifier, 'patron', reason: 'i=$i');
      if (d.idx == 4 || d.idx == 9) expect(d.modifier, 'altin', reason: 'i=$i');
      if (d.box) expect((i + 1) % 7, 0);
      // Yıldız kapısı
      expect(requiredStars(d.stage), d.stage * 10);
    }
    // Somut örnekler (snapshot zaten 150 bölümün tamamını kapsıyor)
    expect(levelDef(14).modifier, 'patron'); // 0. dünya 15. bölüm
    expect(levelDef(4).modifier, 'altin');
    expect(levelDef(9).modifier, 'altin');
    expect(levelDef(18).modifier, 'ruzgar'); // stage 1, idx 3 (3%7==3)
    expect(levelDef(51).modifier, 'karanlik'); // stage 3, idx 6 (6%7==6)
    expect(levelDef(62).modifier, 'yavas'); // stage 4, idx 2
    expect(levelDef(104).modifier, 'patron'); // 104%15==14 → patron (deprem değil)
  });

  test('starsFor: %30/%60 eşikleri ceil ile (JS snapshot + sinir değerleri)', () {
    final stars = (_fixture()['stars'] as List).cast<Map<String, dynamic>>();
    for (final e in stars) {
      expect(
        starsFor(e['perfects'] as int, e['target'] as int),
        e['stars'],
        reason: 't=${e['target']} p=${e['perfects']}',
      );
    }
    expect(starsFor(0, 0), 1); // hedefsiz (serbest) → 1
    expect(starsFor(0, 10), 1);
    expect(starsFor(3, 10), 2); // ceil(3)=3
    expect(starsFor(2, 10), 1);
    expect(starsFor(6, 10), 3); // ceil(6)=6
    expect(starsFor(5, 10), 2);
  });

  test('dailyDef: gün 0-36 JS snapshot ile birebir (tohum determinizmi)', () {
    final dailies = (_fixture()['dailies'] as List).cast<Map<String, dynamic>>();
    for (final e in dailies) {
      final d = dailyDef(e['day'] as int);
      expect(d.stage, e['stage'], reason: 'day=${e['day']}');
      expect(d.target, e['target'], reason: 'day=${e['day']}');
      expect(d.speed, closeTo((e['speed'] as num).toDouble(), 1e-9), reason: 'day=${e['day']}');
      expect(d.tol, e['tol'], reason: 'day=${e['day']}');
      expect(d.modifier, e['modifier'], reason: 'day=${e['day']}');
      expect(d.coins, e['coins'], reason: 'day=${e['day']}');
      expect(d.name, e['name'], reason: 'day=${e['day']}');
      expect(d.theme.id, e['themeId'], reason: 'day=${e['day']}');
      expect(d.daily, isTrue);
    }
  });

  test('surpriseFor: (i+day)%4 kapısı ve havuz seçimi JS ile birebir', () {
    final surprises = (_fixture()['surprises'] as List).cast<Map<String, dynamic>>();
    for (final e in surprises) {
      final s = surpriseFor(e['i'] as int, e['day'] as int);
      expect(s?.id, e['id'], reason: 'i=${e['i']} day=${e['day']}');
      expect(s?.effect, e['effect'], reason: 'i=${e['i']} day=${e['day']}');
      expect(s?.coins ?? 0, e['coins'], reason: 'i=${e['i']} day=${e['day']}');
    }
    expect(surpriseFor(-1), isNull);
    expect(surpriseFor(-2, 5), isNull); // günlük/serbest
  });

  test('mysteryFor determinizmi JS snapshot ile birebir', () {
    final mysteries = (_fixture()['mysteries'] as List).cast<Map<String, dynamic>>();
    for (final e in mysteries) {
      expect(mysteryFor(e['i'] as int), e['text']);
    }
  });

  test('endlessDef varsayılanları', () {
    final d = endlessDef();
    expect(d.endless, isTrue);
    expect(d.target, 0);
    expect(d.speed, 1.05);
    expect(d.tol, 6);
    expect(d.i, -1);
  });

  test('levelSignature deterministik ve aralıkta (PB-033)', () {
    final a = levelSignature(7);
    final b = levelSignature(7);
    expect(a.hueShift, b.hueShift);
    expect(a.skyPhase, b.skyPhase);
    expect(a.silVariant, b.silVariant);
    expect(a.hueShift, inInclusiveRange(-13, 13));
    expect(a.skyPhase, inInclusiveRange(0, 3));
    expect(a.silVariant, inInclusiveRange(0, 2));
  });

  test('ardışık bölümlerin imzaları birebir aynı değil (PB-033)', () {
    for (var i = 0; i < kLevelCount - 1; i++) {
      final a = levelSignature(i);
      final b = levelSignature(i + 1);
      final same = a.hueShift == b.hueShift &&
          a.skyPhase == b.skyPhase &&
          a.silVariant == b.silVariant;
      expect(same, isFalse, reason: 'bölüm $i ile ${i + 1} imzası çakıştı');
    }
  });

  test('finaleFor: ardışık aynı final yok, 4 stil de döner (PB-033 B1)', () {
    for (var i = 0; i < kLevelCount - 1; i++) {
      expect(finaleFor(i + 1), isNot(finaleFor(i)),
          reason: 'bölüm $i ile ${i + 1} finali aynı');
    }
    final seen = {for (var i = 0; i < 4; i++) finaleFor(i)};
    expect(seen.length, 4);
  });
}
