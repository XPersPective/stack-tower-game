import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/gameplay.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/twists.dart';

double stepAmount(GamePlay e) {
  final b = e.moving!;
  final x0 = b.x;
  e.tick(1 / 60);
  return (b.x - x0).abs();
}

(double, double) movingBoundsOf(GamePlay e, dynamic top) {
  final minX = top.x - top.w * 1.05;
  return (minX, minX + top.w * 2.1);
}

void main() {
  GamePlay engineFor(LevelDef d, {int shields = 1}) {
    final e = GamePlay();
    e.resize(460, 780);
    e.startLevel(d, hue: 200, shields: shields);
    return e;
  }

  /// Ust bloğun tam merkezine mükemmel bırakış.
  void dropPerfect(GamePlay e) {
    final top = e.blocks.last;
    e.moving!.x = top.x;
    e.moving!.w = top.w;
    e.drop();
  }

  test('startLevel: dünya kurulumu + ready olayı', () {
    var ready = false;
    final e = GamePlay()..onEvent = (n, _) => ready = n == EngineEvent.ready;
    e.resize(460, 780);
    e.startLevel(levelDef(0));
    expect(ready, isTrue);
    expect(e.state, EngineState.playing);
    expect(e.blocks.length, 1);
    expect(e.moving, isNotNull);
    expect(e.w, 460);
    expect(e.scale, closeTo(1.0, 1e-9)); // 460/460=1, 780/780=1
    expect(e.baseW, closeTo(230, 1e-9));
    expect(e.groundY, closeTo(780 * 0.88, 1e-9));
  });

  test('mükemmel seri: combo artar, 4. mükemmelette geri büyüme', () {
    final e = engineFor(levelDef(0));
    // önce daralt: 20px kaydır (tol 6'yı aşar → kırpılır, combo sıfır)
    final top0 = e.blocks.last;
    e.moving!.x = top0.x + 20;
    e.moving!.w = top0.w;
    e.drop();
    final w1 = e.blocks.last.w;
    expect(w1, closeTo(top0.w - 20, 1e-9));
    // şimdi 4 mükemmel: 4.'de %4 geri büyüme (baseW tavanı)
    dropPerfect(e);
    dropPerfect(e);
    dropPerfect(e);
    expect(e.combo, 3);
    expect(e.blocks.last.w, w1); // 1-3'te büyüme yok
    dropPerfect(e);
    expect(e.combo, 4);
    expect(e.blocks.last.w, closeTo(math.min(e.baseW, w1 * 1.04), 1e-6));
    expect(e.perfects, 4);
  });

  test('HIZLI/PATRON: growthAllowed false — büyüme yok', () {
    final hizli = levelDef(0).copyWith(modifier: 'hizli');
    final e = engineFor(hizli);
    final w0 = e.blocks.last.w;
    for (var i = 0; i < 4; i++) {
      dropPerfect(e);
    }
    expect(e.growthAllowed(), isFalse);
    expect(e.blocks.last.w, w0);
  });

  test('kalkan: ilk kaçırmayı kurtarır, bir kez çalışır', () {
    final e = engineFor(levelDef(0), shields: 1);
    final top = e.blocks.last;
    // tam ıskalat: bloğu uzağa taşı
    e.moving!.x = top.x - e.moving!.w - 50;
    e.moving!.w = top.w;
    final before = e.blocks.length;
    var shieldEvent = false;
    e.onEvent = (n, d) {
      if (n == EngineEvent.shield) shieldEvent = true;
    };
    e.drop();
    expect(shieldEvent, isTrue);
    expect(e.blocks.length, before + 1); // daralmış blok eklendi
    expect(e.shieldsLeft, 0);
    expect(e.combo, 0);
    expect(e.state, EngineState.playing); // devam
    expect(e.slowTimer, closeTo(0.55, 1e-9)); // ağır çekim
    // ikinci ıska: kalkan yok → kayıp
    final top2 = e.blocks.last;
    e.moving!.x = top2.x - e.moving!.w - 50;
    e.drop();
    expect(e.state, EngineState.lost);
    expect(e.misses, 1);
  });

  test('hedefe ulaşınca kazanma + endTimer gecikmesi', () {
    final e = engineFor(levelDef(0)); // hedef 8
    EngineEvent? last;
    e.onEvent = (n, _) => last = n;
    for (var i = 0; i < 8; i++) {
      dropPerfect(e);
    }
    expect(e.state, EngineState.won);
    expect(e.confetti.length, greaterThan(0)); // kutlama
    expect(last, isNot(EngineEvent.win)); // endTimer henüz dolmadı
    // 0.95sn'i kare tıklarıyla akıt (hit-stop dahil) → win olayı gelir
    for (var i = 0; i < 70; i++) {
      e.tick(1 / 60);
    }
    expect(last, EngineEvent.win);
    expect(e.result().reached, isTrue);
    expect(e.result().blocks, 8);
  });

  test('dar blok çökmesi: w < 6*scale → kayıp', () {
    final e = engineFor(endlessDef()); // hedef yok: kazanma yolu kapalı
    // bloğu kademeli daralt: hep kenarından 5px kırp
    var alive = true;
    for (var i = 0; i < 200 && alive; i++) {
      final top = e.blocks.last;
      if (top.w <= 16) {
        // dar üstte: 1px örtüşme + Δw=10 (tol 6'yı aşar → asla mükemmel sayılmaz)
        e.moving!.x = top.x + top.w - 1;
        e.moving!.w = top.w + 10;
      } else {
        e.moving!.x = top.x + 8; // 8px içeriden kırp (tol 6'yı aşar)
        e.moving!.w = top.w;
      }
      e.drop();
      alive = e.state == EngineState.playing;
    }
    expect(e.state, EngineState.lost);
  });

  test('AKAN tik: hız çarpanı sinüsle dalgalanır (hareket değişir)', () {
    final e = engineFor(levelDef(0).copyWith(modifier: 'akan'));
    final top = e.blocks.last;
    final b = e.moving!;
    b.x = (top.x + top.w / 2) - b.w / 2;
    final x0 = b.x;
    e.tick(1 / 60);
    expect(b.x, isNot(closeTo(x0, 1e-9))); // hareket etti
    // dalga tepe/noktalarında farklı hız: iki farklı t anında adım farkı
    final e2 = engineFor(levelDef(0).copyWith(modifier: 'akan'));
    e2.time = 0.0;
    final step1 = stepAmount(e2);
    e2.time = 0.96; // sin(2.6*0.96) ≈ sin(2.5) — farklı faz
    final step2 = stepAmount(e2);
    expect((step1 - step2).abs(), greaterThan(1e-6));
  });

  test('DEPREM tik: 2.2sn aralıklarla sarsıntı tetiklenir', () {
    final e = engineFor(levelDef(0).copyWith(modifier: 'deprem'));
    // 2.2sn kuantum sınırı: floor(time/2.2) atlanınca shake tetiklenir
    e.shake = 0;
    e.time = 2.0; // 2.0→2.017 aynı kuantum (0) → tetiklenmez
    e.tick(1 / 60);
    expect(e.shake, 0.0);
    e.time = 2.19; // 2.19→2.207 kuantum atlar (0→1) → tetiklenir
    e.tick(1 / 60);
    expect(e.shake, greaterThan(0));
  });

  test('RÜZGAR tik: sinüs sürüklemesi sınırlar içinde kalır', () {
    final e = engineFor(levelDef(0).copyWith(modifier: 'ruzgar'));
    for (var i = 0; i < 600; i++) {
      e.tick(1 / 60);
      final top = e.blocks.last;
      final b = movingBoundsOf(e, top);
      expect(e.moving!.x, greaterThanOrEqualTo(b.$1 - 0.5));
      expect(e.moving!.x, lessThanOrEqualTo(b.$2 + 0.5));
    }
  });

  test('kamera: kule yükselirken camShift hedefe yaklaşır (monoton lerp)', () {
    final e = engineFor(endlessDef()); // hedef yok: 25 blok diz
    for (var i = 0; i < 25; i++) {
      dropPerfect(e);
    }
    final prev = e.camShift;
    for (var i = 0; i < 30; i++) {
      e.tick(1 / 60);
      expect(e.camShift, greaterThanOrEqualTo(prev - 1e-9));
    }
    expect(e.camShift, greaterThan(0));
  });

  test('resize: ölçek değişince kule çarpanla taşınır', () {
    final e = engineFor(levelDef(0));
    dropPerfect(e);
    final x1 = e.blocks.last.x;
    final w1 = e.blocks.last.w;
    e.resize(700, 1100); // scale büyür
    final f = e.baseW / 230; // yeni baseW / eski baseW
    expect(e.blocks.last.w, closeTo(w1 * f, 1e-6));
    expect(e.blocks.last.x, closeTo(x1 * f, 1e-6));
  });

  test('blockHue: ALTIN bölümde altın paleti', () {
    final normal = engineFor(levelDef(0));
    expect(normal.blockHue(3), (200 + 3 * 12) % 360);
    final altin = engineFor(levelDef(4));
    expect(altin.blockHue(3), (42 + (3 % 3) * 8) % 360);
  });

  test('serbest mod: hedef yok — sonsuz oynanır, kayıp tam ıska ile', () {
    final e = engineFor(endlessDef(), shields: 0);
    expect(e.def!.target, 0);
    for (var i = 0; i < 30; i++) {
      dropPerfect(e);
    }
    expect(e.state, EngineState.playing); // hedefsiz → kazanma yok
    final top = e.blocks.last;
    e.moving!.x = top.x - e.moving!.w - 50;
    e.drop();
    expect(e.state, EngineState.lost);
  });

  group('juice (PB-016)', () {
    test('hit-stop: her mükemmelde 40ms + kombo başına 4ms, tavan 70ms', () {
      final e = engineFor(endlessDef());
      dropPerfect(e); // kombo 1
      expect(e.hitStop, closeTo(0.044, 1e-9));
      e.tick(0.2); // hit-stop'i tüket
      dropPerfect(e); // kombo 2
      expect(e.hitStop, closeTo(0.048, 1e-9));
      for (var i = 0; i < 10; i++) {
        e.tick(0.2);
        dropPerfect(e);
        expect(e.hitStop, lessThanOrEqualTo(0.07 + 1e-9),
            reason: 'kombo $i: hit-stop tavanı (70ms) aşılmamalı');
      }
    });

    test('hit-stop: kritik ek darbesi de 70ms tavanını aşmaz', () {
      final e = GamePlay();
      e.resize(460, 780);
      e.startLevel(endlessDef(), twistType: TwistType.kritik);
      e.critRoll = () => 0.1;
      for (var i = 0; i < 12; i++) {
        dropPerfect(e); // kombo büyüdükçe taban artar
        expect(e.hitStop, lessThanOrEqualTo(0.07 + 1e-9),
            reason: 'kritik dahil tavan 70ms (kombo ${e.combo})');
        e.tick(0.2);
      }
    });

    test('squash: yerleşen blokta 120ms, hit-stop sırasında da akar', () {
      final e = engineFor(endlessDef());
      dropPerfect(e);
      expect(e.squashIdx, e.blocks.length - 1);
      expect(e.squashT, closeTo(0.12, 1e-9));
      expect(e.hitStop, greaterThan(0));
      e.tick(0.05); // hit-stop (0.044s) içindeyken bile efekt akar
      expect(e.squashT, closeTo(0.07, 1e-9));
      e.tick(0.2);
      expect(e.squashT, 0);
      dropPerfect(e); // yeni yerleşim → yeni indeks + taze squash süresi
      expect(e.squashIdx, e.blocks.length - 1);
      expect(e.squashT, closeTo(0.12, 1e-9));
    });

    test('flaş: mükemmelde tema-glow 0.18 / kritikte beyaz 0.35, 90ms fade', () {
      final e = engineFor(endlessDef());
      dropPerfect(e);
      expect(e.flashT, closeTo(0.09, 1e-9));
      expect(e.flashAlpha, 0.18);
      expect(e.flashWhite, isFalse);
      e.tick(0.09);
      expect(e.flashT, 0);
    });

    test('flaş + haptic desen: kritikte beyaz 0.35 + çift vuruş + konfeti + yıldız izi', () {
      final e = GamePlay();
      e.resize(460, 780);
      e.startLevel(endlessDef(), twistType: TwistType.kritik);
      e.critRoll = () => 0.1; // <0.20 → kritik
      final pulses = <List<int>>[];
      e.onHapticPattern = pulses.add;
      dropPerfect(e);
      expect(e.flashWhite, isTrue);
      expect(e.flashAlpha, 0.35);
      expect(pulses, [
        [0, 60]
      ]);
      expect(e.confetti.length, 12, reason: 'mükemmel konfetisi 12 parça');
      expect(e.particles.any((p) => p.star), isTrue, reason: 'yıldız izi parçacıkları');
    });

    test('haptic: mükemmelde tek 10ms nabız', () {
      final e = engineFor(endlessDef());
      final ms = <int>[];
      e.onHaptic = ms.add;
      dropPerfect(e);
      expect(ms, [10]);
    });
  });
}

/// Test yardımcısı: LevelDef kopyalama (modifier değiştirmek için).
extension LevelDefCopy on LevelDef {
  LevelDef copyWith({String? modifier, int? target}) => LevelDef(
        i: i,
        stage: stage,
        idx: idx,
        num: this.num,
        theme: theme,
        target: target ?? this.target,
        speed: speed,
        tol: tol,
        modifier: modifier ?? this.modifier,
        coins: coins,
        box: box,
        name: name,
        daily: daily,
        endless: endless,
      );
}
