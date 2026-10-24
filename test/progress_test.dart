import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart';
import 'package:stack_tower_game/services/storage.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/levels_js_snapshot.json').readAsStringSync());

void main() {
  group('completeLevel — JS snapshot ile ödül paritesi', () {
    final fx = _fixture()['complete'] as Map<String, dynamic>;

    test('normal temizlik: (coins + stars*5 + perfects*2)', () {
      final e = fx['normal'] as Map<String, dynamic>;
      final st = createSave();
      final def = levelDef(0);
      final out = completeLevel(st, def, blocks: 10, perfects: 4, reached: true, stars: 2);
      expect(out.coins, e['coins']);
      expect(out.stars, e['stars']);
      expect(out.firstClear, e['firstClear']);
      expect(st.coins, e['stateCoins']);
      expect(st.levelsDone, e['levelsDone']);
      // formül doğrudan: level0 coins=10 → (10 + 2*5 + 4*2) = 28
      expect(out.coins, (10 + 2 * 5 + 4 * 2));
    });

    test('altın bölüm ×2', () {
      final e = fx['altin'] as Map<String, dynamic>;
      final st = createSave();
      final def = levelDef(4); // modifier=altin, coins=10+2+25=37
      final out = completeLevel(st, def, blocks: 10, perfects: 4, reached: true, stars: 2);
      expect(out.coins, e['coins']);
      expect(out.coins, (37 + 2 * 5 + 4 * 2) * 2);
    });

    test('başarısız deneme: teselli 2 para, levelsDone artmaz', () {
      final e = fx['fail'] as Map<String, dynamic>;
      final st = createSave();
      final out = completeLevel(st, levelDef(0), blocks: 7, perfects: 1, reached: false);
      expect(out.coins, e['coins']);
      expect(out.coins, 2);
      expect(st.levelsDone, 0);
      expect(st.completed.isEmpty, isTrue);
    });

    test('yıldız yükseltmesi: en iyi korunur, ödül yine verilir', () {
      final st = createSave();
      final def = levelDef(0);
      completeLevel(st, def, blocks: 10, perfects: 4, reached: true, stars: 2);
      final before = st.coins;
      final out = completeLevel(st, def, blocks: 12, perfects: 8, reached: true, stars: 3);
      expect(out.firstClear, isFalse);
      expect(st.completed[0]!['stars'], 3);
      expect(st.completed[0]!['best'], 12);
      expect(st.coins, greaterThan(before));
    });

    test('günlük: bölüm ilerlemesine dokunmaz', () {
      final st = createSave();
      final def = dailyDef(100);
      final out = completeLevel(st, def, blocks: 14, perfects: 3, reached: true);
      expect(out.coins, def.coins + 3 * 2);
      expect(st.levelsDone, 0);
      expect(st.completed.isEmpty, isTrue);
      final out2 = completeLevel(st, def, blocks: 5, perfects: 0, reached: false);
      expect(out2.coins, 2);
    });

    test('serbest: yalnızca best güncellenir, para yok', () {
      final st = createSave()..coins = 100;
      final out = completeLevel(st, endlessDef(), blocks: 33, perfects: 5, reached: false);
      expect(st.best, 33);
      expect(out.coins, 0);
      expect(st.coins, 100);
      completeLevel(st, endlessDef(), blocks: 20, perfects: 1, reached: false);
      expect(st.best, 33); // düşmez
    });

    test('kutulu bölüm: boxDropped bir kez', () {
      final st = createSave();
      final def = levelDef(6); // (6+1)%7==0
      expect(def.box, isTrue);
      final o1 = completeLevel(st, def, blocks: 10, perfects: 0, reached: true, stars: 1);
      expect(o1.boxDropped, isTrue);
      final o2 = completeLevel(st, def, blocks: 10, perfects: 0, reached: true, stars: 1);
      expect(o2.boxDropped, isFalse);
    });
  });

  group('openBox — sahte rand ile iki dal', () {
    final fx = (_fixture()['openBox'] as Map<String, dynamic>);

    test('r<0.35 → kilitli görünüm (JS snapshot ile aynı)', () {
      final e = fx['low'] as Map<String, dynamic>;
      var k = 0;
      final st = createSave();
      final out = openBox(st, levelDef(19), () => [0.10, 0.5][k++ % 2]);
      expect(out.type, e['type']);
      expect(out.skin?.id, e['skin']);
      expect(st.skins.contains(out.skin!.id), isTrue);
    });

    test('r≥0.35 → para (JS snapshot ile aynı)', () {
      final e = fx['high'] as Map<String, dynamic>;
      var k = 0;
      final st = createSave();
      final out = openBox(st, levelDef(19), () => [0.9, 0.5][k++ % 2]);
      expect(out.type, e['type']);
      expect(out.amount, e['amount']);
    });

    test('tüm görünümler sahipse para dalı zorunlu', () {
      final st = createSave()..skins = kSkins.map((s) => s.id).toList();
      final out = openBox(st, levelDef(19), () => 0.01);
      expect(out.type, 'coins');
    });
  });

  group('görevler', () {
    test('JS snapshot: goal/reward/base formülü', () {
      final e = (_fixture()['missions'] as List).cast<Map<String, dynamic>>();
      final st = createSave()
        ..totalPerfect = 5
        ..totalBlocks = 30
        ..levelsDone = 1;
      final m = ensureMissions(st, DateTime.fromMillisecondsSinceEpoch(86400000 * 19570));
      final items = (m['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(items[i]['stat'], e[i]['stat']);
        expect(items[i]['goal'], e[i]['goal']);
        expect(items[i]['reward'], e[i]['reward']);
        expect(items[i]['base'], e[i]['base']);
      }
    });

    test('gün değişince yenilenir; claim koşulu ve bir kerelik', () {
      final st = createSave();
      final day1 = DateTime.fromMillisecondsSinceEpoch(86400000 * 100);
      ensureMissions(st, day1);
      st.totalPerfect += 15;
      List<Map<String, dynamic>> items() => (st.missions!['items'] as List).cast<Map<String, dynamic>>();
      final m0 = items()[0]; // totalPerfect, goal = 10+((100+0)%3)*5 → 100%3=1 → +5 = 15
      expect(m0['goal'], 10 + (100 % 3) * 5);
      expect(claimMission(st, m0), 30); // 15 ≥ 15 → ödül 30
      expect(claimMission(st, m0), isNull); // bir kerelik
      final m1 = items()[1];
      final m1Goal = m1['goal'] as int;
      if (missionProgress(st, m1) < m1Goal) {
        expect(claimMission(st, m1), isNull);
      }
      // yeni gün → yeni görevler (base anlık toplama reset)
      final day2 = DateTime.fromMillisecondsSinceEpoch(86400000 * 101);
      ensureMissions(st, day2);
      expect(st.missions!['day'], 101);
      expect((st.missions!['items'] as List).cast<Map<String, dynamic>>()[0]['base'], st.totalPerfect);
    });
  });

  group('dünya töreni + kalıntı', () {
    test('applyWorldComplete bir kez; bonus + kalıntı', () {
      final st = createSave();
      for (var i = 0; i < 15; i++) {
        st.completed[i] = {'stars': 1, 'best': 10};
      }
      expect(isWorldComplete(st, 0), isTrue);
      final before = st.coins;
      final bonus = applyWorldComplete(st, 0);
      expect(bonus, 50); // 50 + 0*25
      expect(st.coins, before + 50);
      expect(st.relics['0'], isTrue);
      expect(relicFor(0)!.name, 'NEON KORU');
      expect(applyWorldComplete(st, 0), isNull); // ikinci kez yok
      expect(applyWorldComplete(st, 1), 75); // 50 + 25 (zorlamalı da bir kez verilir)
    });

    test('isWorldComplete: eksik bölüm → false', () {
      final st = createSave();
      st.completed[15] = {'stars': 3, 'best': 20};
      expect(isWorldComplete(st, 1), isFalse);
    });
  });

  group('rivalsFor — LCG JS ile birebir', () {
    test('snapshot: 6 gün × 9 rakip isim/skor', () {
      final rivals = (_fixture()['rivals'] as List).cast<Map<String, dynamic>>();
      for (final e in rivals) {
        final list = rivalsFor(e['day'] as int, e['playerScore'] as int);
        expect(list.map((r) => r.name).toList(), (e['names'] as List).cast<String>());
        expect(list.map((r) => r.score).toList(), (e['scores'] as List).cast<int>(),
            reason: 'day=${e['day']}');
      }
    });

    test('deterministik: aynı gün aynı liste', () {
      expect(rivalsFor(7, 25).map((r) => r.score).toList(),
          rivalsFor(7, 25).map((r) => r.score).toList());
    });
  });

  group('kayıt şeması + depolama', () {
    test('load/save gidiş-dönüş alanları korur', () async {
      final storage = MemoryStorage();
      final st = createSave()..coins = 123;
      st.completed[3] = {'stars': 2, 'best': 22};
      st.skins.add('alev');
      st.activeSkin = 'alev';
      st.best = 44;
      st.daily = {'day': 9, 'best': 12};
      save(st, storage);

      final loaded = load(storage);
      expect(loaded.coins, 123);
      expect(loaded.completed[3], {'stars': 2, 'best': 22});
      expect(loaded.skins, contains('alev'));
      expect(loaded.activeSkin, 'alev');
      expect(loaded.best, 44);
      expect(loaded.daily, {'day': 9, 'best': 12});
    });

    test('bozuk JSON → temiz kayıt; boş depo → 60 para', () {
      final broken = MemoryStorage()..seed(kSaveKey, '{bu-değil');
      expect(load(broken).coins, 60);
      expect(load(MemoryStorage()).coins, 60);
    });

    test('kayıt anahtarı SPEC §5/ADR-001', () {
      expect(kSaveKey, 'stacktower_save_v2');
    });
  });

  group('ekonomi bütünlüğü', () {
    test('buySkin: yetersiz para reddi; asla negatif bakiye yok', () {
      final st = createSave()..coins = 10;
      final res = buySkin(st, 'altin'); // 120
      expect(res.ok, isFalse);
      expect(res.reason, 'coins');
      expect(st.coins, 10);
      st.coins = 130;
      final ok = buySkin(st, 'altin');
      expect(ok.ok, isTrue);
      expect(st.coins, 10);
      expect(st.activeSkin, 'altin');
      expect(buySkin(st, 'altin').reason, 'owned');
    });

    test('equipSkin: sahipsiz giyilemez', () {
      final st = createSave();
      expect(equipSkin(st, 'buz'), isFalse);
      expect(equipSkin(st, 'default'), isTrue);
    });

    test('recordDaily: gün değişince sıfırlanır, rekor korunur', () {
      final st = createSave();
      expect(recordDaily(st, 5, 12), 12);
      expect(recordDaily(st, 5, 9), 12); // düşmez
      expect(recordDaily(st, 6, 3), 3); // yeni gün
    });

    test('applySurpriseCoins: yalnız coinStart etkili', () {
      final st = createSave();
      expect(applySurpriseCoins(st, surpriseFor(0, 0)), 20);
      expect(st.coins, 80);
      expect(applySurpriseCoins(st, surpriseFor(1, 3)), 0); // null
      expect(applySurpriseCoins(st, surpriseFor(3, 1)), 0); // doubleCoins
    });
  });

  group('isUnlocked — yıldız kapısı', () {
    test('i=0 açık; önceki bitmeden kapalı; yıldız şartı', () {
      final st = createSave();
      expect(isUnlocked(st, 0, levelDef(0)), isTrue);
      expect(isUnlocked(st, 1, levelDef(1)), isFalse);
      st.completed[0] = {'stars': 1, 'best': 8};
      expect(isUnlocked(st, 1, levelDef(1)), isTrue); // aynı dünya → yıldız şartı yok
      // dünya 2 (i=15): stageOf(14)=0 ≠ 1 → yıldız şartı: 1*10=10 yıldız gerek
      st.completed[0] = {'stars': 1, 'best': 8}; // (tekrar, temiz durum için)
      for (var i = 1; i < 15; i++) {
        st.completed.remove(i);
      }
      st.completed[14] = {'stars': 1, 'best': 10};
      expect(totalStars(st), 2); // 0. ve 14. bölüm yıldızları
      expect(isUnlocked(st, 15, levelDef(15)), isFalse); // 2 < 10 yıldız
      for (var i = 0; i < 15; i++) {
        st.completed[i] = {'stars': 1, 'best': 10};
      }
      expect(totalStars(st), 15);
      expect(isUnlocked(st, 15, levelDef(15)), isTrue); // 15 ≥ 10
    });
  });
}
