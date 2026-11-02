import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart';
import 'package:stack_tower_game/game/rank.dart';
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

  group('PB-034: günlük takvim + streak (v3)', () {
    test('touchStreak: ardışık günler artar, gün içi tekrar dokunmaz', () {
      final s = createSave();
      expect(touchStreak(s, 100), 1);
      expect(touchStreak(s, 100), 1); // aynı gün: değişmez
      expect(touchStreak(s, 101), 2);
      expect(touchStreak(s, 102), 3);
    });

    test('touchStreak: kopma sıfırlar, telafi kalkanı 1 gün affeder', () {
      final s = createSave();
      touchStreak(s, 100);
      touchStreak(s, 101);
      touchStreak(s, 104); // 2 gün kaçtı, kalkan yok → sıfır
      expect(s.streakDays, 1);
      // kalkanlı kopma
      final s2 = createSave();
      touchStreak(s2, 100);
      touchStreak(s2, 101);
      s2.streakShield = true;
      touchStreak(s2, 103); // 1 gün kaçtı + kalkan → affedilir
      expect(s2.streakDays, 3);
      expect(s2.streakShield, isFalse); // kalkan tüketildi
    });

    test('claimCalendar: günde bir talep, döngü 7 slotta döner', () {
      final s = createSave();
      expect(claimCalendar(s, 100), (25, 0));
      expect(claimCalendar(s, 100), isNull); // bugün alındı
      expect(claimCalendar(s, 101), (30, 1));
      // 100 → 106: 7 talep, son slot 6 büyük ödül
      final s2 = createSave();
      (int, int)? last;
      for (var d = 0; d < 7; d++) {
        last = claimCalendar(s2, d);
      }
      expect(last, (100, 6));
      expect(s2.streakShield, isTrue); // 7. gün telafi kalkanı hediye
      expect(s2.calendarIndex, 0); // döngü başa döndü
    });

    test('v2→v3 migrasyon: eski kayıt yeni alanlarla açılır, veri kaybı yok', () {
      final s2 = createSave();
      s2.v = 2;
      s2.coins = 123;
      s2.best = 45;
      s2.completed[3] = {'stars': 2, 'best': 12};
      final restored = SaveState.fromJson(
          jsonDecode(s2.encode()) as Map<String, dynamic>);
      expect(restored.coins, 123);
      expect(restored.best, 45);
      expect(restored.completed[3]!['stars'], 2);
      expect(restored.streakDays, 0); // v3 varsayılanı
      expect(restored.streakLastDay, -1);
      expect(restored.calendarIndex, 0);
      expect(restored.v, 2); // fromJson v2'yi korur; load() kabul eder
    });

    test('PB-035 B3: kabus hakları — hafta sıfırlar, 3 tavan, kayıp cezasız', () {
      final s = createSave();
      final w = 3400;
      expect(nightmareTriesLeft(s, w), 3);
      consumeNightmareTry(s, w);
      expect(nightmareTriesLeft(s, w), 2);
      consumeNightmareTry(s, w);
      consumeNightmareTry(s, w);
      expect(nightmareTriesLeft(s, w), 0);
      // kayıp cezasız: rekor güncellenmez, hak düşmez
      recordNightmare(s, w, 20, false);
      expect(s.nightmareBest, 0);
      expect(nightmareTriesLeft(s, w), 0);
      // kazanç rekoru
      recordNightmare(s, w, 25, true);
      expect(s.nightmareBest, 25);
      // yeni hafta → haklar yenilenir
      expect(nightmareTriesLeft(s, w + 1), 3);
      consumeNightmareTry(s, w + 1);
      expect(s.nightmareWeek, w + 1);
      expect(s.nightmareTries, 1);
      // rekor haftalar arası korunur
      expect(s.nightmareBest, 25);
    });

    test('PB-035 B3: nightmareDef hafta tohumu deterministik + hep stack', () {
      final a = nightmareDef(3400);
      final b = nightmareDef(3400);
      expect(a.target, b.target);
      expect(a.speed, b.speed);
      expect(a.nightmare, isTrue);
      expect(a.kind, GameKind.stack);
      expect(a.target, greaterThanOrEqualTo(14));
      expect(a.tol, 4);
      expect(nightmareDef(3401).target, isNot(a.target));
      expect(weekOf(3400 * 7), 3400);
    });

    test('missingRelicPieces: eksik kalıntı sayısı', () {
      final s = createSave();
      expect(missingRelicPieces(s), kStageCount);
      s.relics['0'] = true;
      expect(missingRelicPieces(s), kStageCount - 1);
    });
  });
}

void pb036RankTests() {
  test('PB-036: rütbe kademeleri — eşikler sıralı ve 8 kademe', () {
    expect(kRankTable.length, 8);
    for (var i = 1; i < kRankTable.length; i++) {
      expect(kRankTable[i].points, greaterThan(kRankTable[i - 1].points));
    }
    expect(kRankTable.first.points, 0);
  });

  test('PB-036: rankFor — bileşik puan kademeyi belirler', () {
    final s = createSave();
    expect(rankFor(s).tier, RankTier.caylak); // 0 puan
    s.completed[0] = {'stars': 3, 'best': 10};
    // 3 yıldız ×10 = 30 → hâlâ çaylak (eşik 60)
    expect(rankFor(s).tier, RankTier.caylak);
    s.completed[1] = {'stars': 3, 'best': 10};
    expect(rankFor(s).tier, RankTier.bronz); // 60 puan
    s.totalBlocks = 100; // +100 → 160+ → gümüş
    expect(rankFor(s).tier, RankTier.gumus);
    expect(pointsToNext(s), isNotNull);
    // efsane eşiği üstü
    s.completed[2] = {'stars': 3, 'best': 10};
    s.totalBlocks = 10000;
    s.levelsDone = 50;
    s.totalPerfect = 500;
    expect(rankFor(s).tier, RankTier.efsane);
    expect(pointsToNext(s), isNull); // zirve
  });

  test('PB-036: localPercentile — rakipler içinde yüzde', () {
    final s = createSave();
    s.daily = {'day': 20001, 'best': 100};
    final pct = localPercentile(s, 20001);
    expect(pct, inInclusiveRange(0, 100));
  });
  pb036RankTests();
}
