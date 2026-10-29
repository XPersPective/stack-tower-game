import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/launch_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';
import 'dart:math' as math;

class _Host implements MiniGameHost {
  final List<String> sounds = [];
  final List<String> events = [];
  int haptics = 0;

  @override
  void playSound(String name, {int combo = 1}) => sounds.add(name);
  @override
  void haptic(int ms) => haptics++;
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) => events.add(name);
}

void main() {
  LaunchGame gameWith(_Host host, {int shields = 1, LevelDef? def}) {
    final g = LaunchGame();
    g.resize(460, 780);
    g.start(def ?? levelDef(3), host: host, shields: shields);
    return g;
  }

  /// Nişanı yukarı sabitler ve tam üste tek hedef koyar (deterministik isabet).
  void aimStraightUpAtTarget(LaunchGame g) {
    g.targetsForTest
      ..clear()
      ..add(Target(g.wForTest / 2, 200, 22));
    g.setAimForTest(-math.pi / 2, 1.0);
  }

  group('LAUNCH temel kurallar', () {
    test('ateş: nişan açısı ve güçle mermi oluşturur, bütçeyi düşürür', () {
      final host = _Host();
      final g = gameWith(host);
      final before = g.shotsLeftForTest;
      g.setAimForTest(-math.pi / 2, 1.0);
      g.fireForTest();
      expect(g.shotsLeftForTest, before - 1);
      expect(g.shotsForTest.length, 1);
      final p = g.shotsForTest.first;
      expect(p.vy, lessThan(0), reason: 'yukarı nişan → negatif vy');
      expect(p.vx.abs(), lessThan(1e-6), reason: 'tam yukarı → vx ~ 0');
      expect(host.sounds, contains('place'));
    });

    test('fizik: yerçekimi mermiyi aşağı çeker', () {
      final host = _Host();
      final g = gameWith(host);
      g.setAimForTest(-math.pi / 2, 0.2);
      g.fireForTest();
      final p = g.shotsForTest.first;
      final vy0 = p.vy;
      g.tick(1 / 60);
      expect(p.vy, greaterThan(vy0), reason: 'vy artmalı (yerçekimi)');
    });

    test('hedef vurma: skor/kombo artar, mükemmel merkez isabeti', () {
      final host = _Host();
      final g = gameWith(host);
      aimStraightUpAtTarget(g);
      g.fireForTest();
      for (var i = 0; i < 240 && g.score == 0; i++) {
        g.tick(1 / 60);
      }
      expect(g.score, 1);
      expect(g.combo, 1);
      expect(g.result().perfects, 1, reason: 'merkez isabeti mükemmel');
      expect(host.sounds, contains('perfect'));
    });

    test('kombo 3 → kritik olayı ve ağır çekim', () {
      final host = _Host();
      final g = gameWith(host);
      for (var k = 0; k < 3; k++) {
        aimStraightUpAtTarget(g);
        g.fireForTest();
        for (var i = 0; i < 240 && g.score <= k; i++) {
          g.tick(1 / 60);
        }
      }
      expect(g.score, 3);
      expect(host.events, contains('crit'));
    });

    test('hedefe ulaşınca kazanır', () {
      final host = _Host();
      final g = gameWith(host, def: levelDef(3)); // hedef 8
      final need = g.target;
      var guard = 0;
      while (!g.isOver && guard++ < 400) {
        aimStraightUpAtTarget(g);
        g.fireForTest();
        for (var i = 0; i < 240 && g.shotsForTest.isNotEmpty; i++) {
          g.tick(1 / 60);
        }
        g.tick(1 / 60);
        if (g.score < need && g.shotsLeftForTest <= 0) break;
      }
      expect(g.score, greaterThanOrEqualTo(need));
      expect(g.result().reached, isTrue);
      expect(host.events, contains('win'));
    });

    test('atış bütçesi: kalkan 3 atış verir, kalkan yoksa kaybettirir', () {
      final host = _Host();
      final g = gameWith(host);
      // tüm atışları boşa harca (hedef yok)
      g.targetsForTest.clear();
      while (!g.isOver && g.shotsLeftForTest > 0) {
        g.fireForTest();
        for (var i = 0; i < 400 && g.shotsForTest.isNotEmpty; i++) {
          g.tick(1 / 60);
        }
        g.tick(1 / 60);
      }
      // kalkan kullanıldı → 3 atış daha verildi ve oyun sürüyor ya da bitti
      expect(host.events.any((e) => e == 'shield' || e == 'lose'), isTrue);
    });

    test('kalkansız bütçe tükenince kayıp', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      g.targetsForTest.clear();
      var guard = 0;
      while (!g.isOver && guard++ < 60) {
        if (g.shotsLeftForTest > 0) g.fireForTest();
        for (var i = 0; i < 400 && g.shotsForTest.isNotEmpty; i++) {
          g.tick(1 / 60);
        }
        g.tick(1 / 60);
      }
      expect(g.isOver, isTrue);
      expect(g.result().reached, isFalse);
      expect(host.events, contains('lose'));
    });

    test('oyun bitince ateş edilmez', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      g.targetsForTest.clear();
      var guard = 0;
      while (!g.isOver && guard++ < 60) {
        if (g.shotsLeftForTest > 0) g.fireForTest();
        for (var i = 0; i < 400 && g.shotsForTest.isNotEmpty; i++) {
          g.tick(1 / 60);
        }
        g.tick(1 / 60);
      }
      final shots = g.shotsForTest.length;
      g.onTap(const Offset(0, 0));
      expect(g.shotsForTest.length, shots);
    });

    test('REGRESYON (softlock): son atış isabet edince oyun kilitlenmez — kayıp', () {
      final host = _Host();
      final g = gameWith(host, shields: 0);
      aimStraightUpAtTarget(g);
      g.setShotsForTest(1); // tek atış kaldı, hedef 8 → isabet kazandırmaz
      g.fireForTest();
      for (var i = 0; i < 300 && !g.isOver; i++) {
        g.tick(1 / 60);
      }
      expect(g.score, 1, reason: 'isabet sayıldı');
      expect(g.isOver, isTrue, reason: 'bütçe bitti → oyun bitmeli (softlock yok)');
      expect(g.result().reached, isFalse);
      expect(host.events, contains('lose'));
    });

    test('REGRESYON (softlock): kalkan varsa son isabet 3 atış daha verir', () {
      final host = _Host();
      final g = gameWith(host, shields: 1);
      aimStraightUpAtTarget(g);
      g.setShotsForTest(1);
      g.fireForTest();
      for (var i = 0; i < 300 && g.shotsLeftForTest == 0; i++) {
        g.tick(1 / 60);
      }
      expect(g.isOver, isFalse);
      expect(g.shotsLeftForTest, 3, reason: 'kalkan 3 atış verdi');
      expect(g.shieldsForTest, 0);
      expect(host.events, contains('shield'));
    });

    test('nişan ve güç otomatik salınır (zamanla değişir)', () {
      final host = _Host();
      final g = gameWith(host);
      final a0 = g.aim;
      final p0 = g.power;
      for (var i = 0; i < 30; i++) {
        g.tick(1 / 60);
      }
      expect(g.aim, isNot(closeTo(a0, 1e-9)));
      expect(g.power, isNot(closeTo(p0, 1e-9)));
      expect(g.power, inInclusiveRange(0.0, 1.0));
    });
  });

  group('LAUNCH PB-025 düzeltmeleri', () {
    test('yerleşimden ÖNCE start: hedefler (0,0) yerine ilk tick\'te doğar', () {
      final host = _Host();
      final g = LaunchGame();
      // üretim akışı: start() ilk yerleşimden önce çağrılır (post-frame resize)
      g.start(levelDef(3), host: host);
      expect(g.targetsForTest, isEmpty, reason: 'w=0 iken hedef üretilmez');
      g.resize(460, 780);
      g.tick(1 / 60);
      expect(g.targetsForTest, isNotEmpty, reason: 'ilk tick hedefleri kurar');
      for (final t in g.targetsForTest) {
        expect(t.x, greaterThan(0));
        expect(t.y, greaterThan(0));
        expect(t.x, lessThan(g.wForTest));
      }
    });

    test('basılı tut = şarj, bırak = fırlat; iptal atış yapmaz', () {
      final host = _Host();
      final g = gameWith(host);
      aimStraightUpAtTarget(g);
      final shots0 = g.shotsForTest.length;
      g.onHoldStart(const Offset(200, 600));
      for (var i = 0; i < 18; i++) {
        g.tick(1 / 60); // 0.3s → charge ≈ 0.48
      }
      expect(g.power, closeTo(0.48, 0.02));
      expect(g.shotsForTest.length, shots0, reason: 'bırakana kadar atış yok');
      g.onRelease(const Offset(200, 600));
      expect(g.shotsForTest.length, shots0 + 1);

      // iptal: şarj sıfırlanır, atış olmaz
      final shots1 = g.shotsForTest.length;
      g.onHoldStart(const Offset(200, 600));
      g.tick(1 / 60);
      g.onHoldCancel();
      expect(g.shotsForTest.length, shots1);
      expect(g.charging, isFalse);
    });

    test('duvar sekmesi: mermi yan duvardan döner, ekranı terk etmez', () {
      final host = _Host();
      final g = gameWith(host);
      g.setAimForTest(0, 1.0); // tam sağa
      g.fireForTest();
      final p = g.shotsForTest.single;
      var bounced = false;
      for (var i = 0; i < 60 && g.shotsForTest.isNotEmpty; i++) {
        final vx0 = p.vx;
        g.tick(1 / 60);
        if (p.vx.sign != vx0.sign) bounced = true;
        expect(p.x, greaterThanOrEqualTo(-1));
        expect(p.x, lessThanOrEqualTo(g.wForTest + 1));
      }
      expect(bounced, isTrue, reason: 'sağ duvardan sekme olmalı');
    });
  });
}
