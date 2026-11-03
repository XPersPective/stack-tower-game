import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/gameplay.dart';
import 'package:stack_tower_game/game/kinds/stack_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';
import 'package:stack_tower_game/game/twists.dart';

class _SnapHost implements MiniGameHost {
  @override
  void playSound(String name, {int combo = 1}) {}
  @override
  void haptic(int ms) {}
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) {}
}

/// Kanıt PNG'leri normal test koşusunda evidence'a DOKUNMAZ (inceleme
/// bulgusu: her koşuda yeniden yazıp PB-022/028 kanıt dosyalarını kirletme);
/// `.cache/runs` altına yazar. `PB_EVIDENCE=1` ile koşulunca evidence'a yazar.
const _evidenceDir = '.project-brain/evidence/PB-015';
String get _outDir => Platform.environment['PB_EVIDENCE'] == '1'
    ? _evidenceDir
    : '.cache/runs/snapshots/PB-015';

Future<void> _snap(StackGame g, String name, {required int ticks}) async {
  for (var i = 0; i < ticks; i++) {
    g.tick(1 / 60);
  }
  final recorder = ui.PictureRecorder();
  g.render(Canvas(recorder), const Size(540, 1200));
  final image = await recorder.endRecording().toImage(540, 1200);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  Directory(_outDir).createSync(recursive: true);
  File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}


/// kindFor sırasına göre n. stack bölümünün indeksi (n 0 tabanlı).
/// PB-041: antoloji 11 türe büyüdü; stack indeksleri kayar — testler
/// artık sabit i yerine TÜRETİLMİŞ ordinal kullanır (şema anlamı korunur).
int nthStackLevel(int n) {
  var seen = -1;
  for (var i = 0; i < kLevelCount; i++) {
    if (kindFor(i) == GameKind.stack) {
      seen++;
      if (seen == n) return i;
    }
  }
  return -1;
}

void main() {
  group('dağıtım yasası (C-017, tür-farkında)', () {
    test('stack olmayan bölüm asla twist almaz (oyuncuya ulaşma garantisi)', () {
      for (var i = 0; i < kLevelCount; i++) {
        if (kindFor(i) == GameKind.stack) continue;
        expect(twistFor(i), isNull,
            reason: 'i=$i (${kindFor(i)}) stack değil → twist olamaz');
      }
    });

    test('ilk 5 stack bölümü: hard-coded şema — 1. stack bölümü twistsiz', () {
      // i=0..4: catcher/ring/stack/launch/merge → yalnız i=2 stack (n=0, twistsiz)
      expect(twistFor(0), isNull); // catcher
      expect(twistFor(1), isNull); // ring
      expect(twistFor(3), isNull); // launch
      expect(twistFor(4), isNull); // merge
      expect(twistFor(2), isNull, reason: '1. stack bölümü çekirdeği öğretir');
      // takip eden 4 stack bölümü: sabit şema (n=1..4 — PB-041 dinamik indeks)
      expect(twistFor(nthStackLevel(1)), TwistType.altinyagmuru);
      expect(twistFor(nthStackLevel(2)), TwistType.ruzgargulu);
      expect(twistFor(nthStackLevel(3)), TwistType.zitakis);
      expect(twistFor(nthStackLevel(4)), TwistType.kritik);
    });

    test('her stack bölümü (n>=1) twistli; 7 türün tamamı atanır; ardışık <=2', () {
      final assigned = <TwistType>[];
      var stackLevels = 0;
      for (var i = 0; i < kLevelCount; i++) {
        if (kindFor(i) != GameKind.stack) continue;
        stackLevels++;
        final t = twistFor(i);
        if (stackOrdinalOf(i) == 0) {
          expect(t, isNull, reason: 'i=$i n=0 öğretici bölüm');
        } else {
          expect(t, isNotNull, reason: 'i=$i stack (n=${stackOrdinalOf(i)}) → twist beklenir');
          assigned.add(t!);
        }
      }
      expect(stackLevels, greaterThan(8),
          reason: '150 bölümde stack sayısı anlamlı olmalı: $stackLevels'
              ' (PB-041+: antoloji 20 türe büyüdü — çift-slotlu stack)');
      expect(assigned.length, stackLevels - 1,
          reason: 'öğretici dışındaki her stack bölümü twistli');
      expect(assigned.toSet().length, TwistType.values.length,
          reason: '7 türün tamamı en az bir kez atanmalı');
      for (var k = 2; k < assigned.length; k++) {
        final runOf3 =
            assigned[k] == assigned[k - 1] && assigned[k] == assigned[k - 2];
        expect(runOf3, isFalse,
            reason: '3 ardışık aynı twist: ${assigned[k]} (atama #$k)');
      }
    });

    test('havuz rotasyonu: n=5,6,7 sırasıyla dargecit/sicrayan/golgeblok', () {
      expect(twistFor(nthStackLevel(5)), TwistType.dargecit);
      expect(twistFor(nthStackLevel(6)), TwistType.sicrayan);
      expect(twistFor(nthStackLevel(7)), TwistType.golgeblok);
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

    test('GÖLGE BLOK: hayalet ikiz doğar, bağımsız dolaşır, kural etkisi yok', () {
      final e = engineFor(TwistType.golgeblok);
      expect(e.ghost, isNotNull, reason: 'golgeblok: hayalet ikiz doğar');
      final gx0 = e.ghost!.x;
      e.tick(1 / 60);
      e.tick(1 / 60);
      expect(e.ghost!.x, isNot(gx0), reason: 'hayalet farklı hızda hareket eder');
      // yerleştirme kuralı değişmez: mükemmel sayılır, sayaçlar temiz
      final b0 = e.blocks.length;
      dropPerfect(e);
      expect(e.blocks.length, b0 + 1);
      expect(e.crits, 0);
      expect(e.goldBlocks, 0);
      // hayalet sınırlar içinde kalır
      final b = movingBoundsOf(e, e.blocks.last);
      expect(e.ghost!.x, greaterThanOrEqualTo(b.$1 - 1));
      expect(e.ghost!.x, lessThanOrEqualTo(b.$2 + 1));
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

    test('DAR GEÇİT: uçuş boyunca daralan duvarların ötesine taşmaz', () {
      final e = engineFor(TwistType.dargecit);
      final b = movingBoundsOf(e, e.blocks.last);
      for (var i = 0; i < 240; i++) {
        e.tick(1 / 60);
        final inset =
            math.min(e.blocks.last.w * 0.3, e.blocks.length * 6.0 * e.scale);
        expect(e.moving!.x, greaterThanOrEqualTo(b.$1 + inset - 1e-6),
            reason: 'kare $i: sol duvarın ötesine taşıyor');
        expect(e.moving!.x, lessThanOrEqualTo(b.$2 - inset + 1e-6),
            reason: 'kare $i: sağ duvarın ötesine taşıyor');
      }
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
      // PB-016: hit-stop artık genel juice — twistsiz bölümde mükemmel
      // duraklaması da var (40ms + kombo başına 4ms); yerleştirme matematiği
      // (C-002) değişmez, yalnız his katmanıdır
      expect(e.hitStop, closeTo(0.044, 1e-9),
          reason: 'PB-016: hit-stop twist-gated değil');
    });
  });

  group('görsel anlık görüntüler (kanıt: $_evidenceDir)', () {
    test('RÜZGAR GÜLÜ (n=2): hareketli blok görünür eğimle süzülür', () async {
      final g = StackGame();
      g.resize(540, 1200);
      g.start(levelDef(nthStackLevel(2)), host: _SnapHost(), shields: 1); // 3. stack bölümü
      expect(g.engine.twist, TwistType.ruzgargulu);
      await _snap(g, 'ruzgargulu', ticks: 31); // sin(3*31/60)≈1 → maks eğim
      // görsel iddianın motor karşılığı: blok sahnede döndürülerek çizilir
      expect(g.engine.spawnTilt.abs(), greaterThan(0.08));
      expect(g.engine.spawnTilt.abs(), lessThan(0.27), reason: '±15° tanımı');
      expect(File('$_outDir/ruzgargulu.png').lengthSync(), greaterThan(2000));
    });

    test('DAR GEÇİT (n=5): sahnede daralan neon duvarlar + motor aralığı', () async {
      final g = StackGame();
      g.resize(540, 1200);
      g.start(levelDef(nthStackLevel(5)), host: _SnapHost(), shields: 1); // 6. stack bölümü
      expect(g.engine.twist, TwistType.dargecit);
      await _snap(g, 'dargecit', ticks: 45);
      // görsel iddianın motor karşılığı: hareketli blok daralan aralıkta
      final e = g.engine;
      final b = movingBoundsOf(e, e.blocks.last);
      final inset = math.min(e.blocks.last.w * 0.3, e.blocks.length * 6.0 * e.scale);
      expect(inset, greaterThan(0), reason: 'duvarlar daralmış olmalı');
      expect(e.moving!.x, greaterThanOrEqualTo(b.$1 + inset - 1e-6));
      expect(e.moving!.x, lessThanOrEqualTo(b.$2 - inset + 1e-6));
      expect(File('$_outDir/dargecit.png').lengthSync(), greaterThan(2000));
    });

    test('ALTIN YAĞMURU (n=1): ilk-5 şeması — hareketli blok altın doğar', () async {
      final g = StackGame();
      g.resize(540, 1200);
      g.start(levelDef(nthStackLevel(1)), host: _SnapHost(), shields: 1); // 2. stack bölümü
      g.engine.goldRoll = () => 0.1; // <0.25 → bu blok altın
      g.onTap(const Offset(270, 600)); // dokunuş → bırak; sonraki spawn altın doğar
      expect(g.engine.goldNowForTest, isTrue);
      await _snap(g, 'altinyagmuru', ticks: 20);
      expect(File('$_outDir/altinyagmuru.png').lengthSync(), greaterThan(2000));
    });

    test('GÖLGE BLOK (n=7): hayalet ikiz sahnede soluk çizilir', () async {
      final g = StackGame();
      g.resize(540, 1200);
      g.start(levelDef(nthStackLevel(7)), host: _SnapHost(), shields: 1); // 8. stack bölümü
      expect(g.engine.twist, TwistType.golgeblok);
      await _snap(g, 'golgeblok', ticks: 40);
      expect(g.engine.ghost, isNotNull);
      expect(File('$_outDir/golgeblok.png').lengthSync(), greaterThan(2000));
    });
  });
}

(double, double) movingBoundsOf(GamePlay e, dynamic top) {
  final minX = top.x - top.w * 1.05;
  return (minX, minX + top.w * 2.1);
}
