/// PB-044 — KRİSTAL KESİK + YIKIM EKİBİ motor testleri.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/crystal_cut_game.dart';
import 'package:stack_tower_game/game/kinds/wrecking_crew_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';
import 'package:stack_tower_game/theme/tokens.dart';

class _FakeHost implements MiniGameHost {
  final List<String> sounds = [];
  final List<String> events = [];
  @override
  void playSound(String name, {int combo = 1}) => sounds.add(name);
  @override
  void haptic(int ms) {}
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) => events.add(name);
}

const double kW = 400, kH = 800;

LevelDef longDef({int target = 9999}) => LevelDef(
    i: 999, stage: 9, idx: 0, num: 1000, theme: kThemes[0],
    target: target, speed: 1.0, tol: 6, modifier: 'normal',
    coins: 0, box: false, name: 't');

void main() {
  group('KRİSTAL KESİK', () {
    test('tür kimliği: crystalCut', () {
      expect(CrystalCutGame().kind, GameKind.crystalCut);
    });

    test('kurulum: kristal var, hedef dilim aralıkta', () {
      final host = _FakeHost();
      final g = CrystalCutGame();
      g.resize(kW, kH);
      g.start(longDef(), host: host);
      expect(g.crystal, isNotNull);
      expect(g.crystal!.targetAt, inInclusiveRange(0, g.crystal!.sliceCount - 1));
    });

    test('hedef dilimde dokunma → kesim + parçalar + skor', () {
      final host = _FakeHost();
      final g = CrystalCutGame();
      g.resize(kW, kH);
      g.start(longDef(), host: host);
      final c = g.crystal!;
      // kesik ışığını hedef dilime götür
      final sliceW = c.w / c.sliceCount;
      g.cutX = c.x - c.w / 2 + (c.targetAt + 0.5) * sliceW + sliceW * 0.2;
      g.onTap(const Offset(200, 400));
      expect(g.score, 1);
      expect(g.crystal, isNull, reason: 'kristal ikiye ayrıldı');
      expect(host.sounds, contains('merge_pop'), reason: 'kesim tonu (dilim içi)');
    });

    test('merkez kesim = MÜKEMMEL (slow-mo + crit tonu)', () {
      final host = _FakeHost();
      final g = CrystalCutGame();
      g.resize(kW, kH);
      g.start(longDef(), host: host);
      final c = g.crystal!;
      final sliceW = c.w / c.sliceCount;
      g.cutX = c.x - c.w / 2 + (c.targetAt + 0.5) * sliceW; // tam merkez
      g.onTap(const Offset(200, 400));
      expect(g.slowMo, greaterThan(0));
      expect(host.sounds, contains('crit'));
    });

    test('ıskalama 3 kez → kayıp', () {
      final host = _FakeHost();
      final g = CrystalCutGame();
      g.resize(kW, kH);
      g.start(longDef(), host: host);
      for (var i = 0; i < 3; i++) {
        final c = g.crystal!;
        final sliceW = c.w / c.sliceCount;
        // hedef DIŞI dilim
        final wrong = (c.targetAt + 1) % c.sliceCount;
        g.cutX = c.x - c.w / 2 + (wrong + 0.5) * sliceW;
        g.onTap(const Offset(200, 400));
        if (i < 2) {
          for (var t = 0; t < 90 && g.crystal == null; t++) {
            g.tick(1 / 60); // yeni kristal gelsin
          }
        }
      }
      expect(g.missesForTest, 3);
      expect(g.isOver, isTrue);
      expect(host.events, contains('lose'));
    });

    test('kazanma: hedef kesim sayısı', () {
      final host = _FakeHost();
      final g = CrystalCutGame();
      g.resize(kW, kH);
      g.start(longDef(target: 3), host: host);
      var guard = 0;
      while (!g.isOver && guard < 100) {
        guard++;
        final c = g.crystal!;
        final sliceW = c.w / c.sliceCount;
        g.cutX = c.x - c.w / 2 + (c.targetAt + 0.5) * sliceW;
        g.onTap(const Offset(200, 400));
        for (var t = 0; t < 90 && g.crystal == null && !g.isOver; t++) {
          g.tick(1 / 60);
        }
      }
      expect(g.isOver, isTrue);
      expect(g.result().reached, isTrue);
      expect(g.score, 3);
      expect(host.events, contains('win'));
    });
  });

  group('YIKIM EKİBİ', () {
    test('tür kimliği: wreckingCrew', () {
      expect(WreckingCrewGame().kind, GameKind.wreckingCrew);
    });

    test('kurulum: kule 3 gülleyle başlar, nişan salınır', () {
      final host = _FakeHost();
      final g = WreckingCrewGame();
      g.resize(kW, kH);
      g.start(longDef(), host: host);
      expect(g.shotsForTest, 3);
      expect(g.blocksForTest.length, greaterThanOrEqualTo(4));
      expect(g.blocksForTest.every((b) => !b.toppled), isTrue);
      final a0 = g.aimAngle;
      for (var i = 0; i < 30; i++) {
        g.tick(1 / 60);
      }
      expect(g.aimAngle, isNot(a0), reason: 'nişan döner');
    });

    test('atış → gülle uçar, çarpınca bloklar takla atar', () {
      final host = _FakeHost();
      final g = WreckingCrewGame();
      g.resize(kW, kH);
      g.start(longDef(), host: host);
      // nişanı en alttaki bloğa çevir
      final target = g.blocksForTest.first;
      g.aimAngle = 0.6;
      g.onTap(const Offset(100, 600));
      expect(g.shotsForTest, 2);
      // gülleyi hedef bloğa ışınla (balistik kısayolu)
      g.ball!.x = target.x;
      g.ball!.y = target.y;
      g.tick(1 / 60);
      expect(target.toppled, isTrue, reason: 'zincir dökülmesi');
      expect(g.score, greaterThanOrEqualTo(1));
      expect(host.sounds, contains('crit'));
    });

    test('gülleler biter, hedef eksik → kayıp', () {
      final host = _FakeHost();
      final g = WreckingCrewGame();
      g.resize(kW, kH);
      g.start(longDef(target: 9999), host: host);
      for (var s = 0; s < 3; s++) {
        g.onTap(const Offset(100, 600));
        // gülleyi ekran dışına gönder (ıskala)
        g.ball!.x = -100;
        g.tick(1 / 60);
      }
      expect(g.shotsForTest, 0);
      expect(g.isOver, isTrue);
      expect(host.events, contains('lose'));
    });

    test('kazanma: hedef sayıda blok döker', () {
      final host = _FakeHost();
      final g = WreckingCrewGame();
      g.resize(kW, kH);
      g.start(longDef(target: 2), host: host);
      var guard = 0;
      while (!g.isOver && guard < 50) {
        guard++;
        if (g.ball == null && g.shotsForTest > 0) {
          g.onTap(const Offset(100, 600));
          final alive = g.blocksForTest.firstWhere((b) => !b.toppled);
          g.ball!.x = alive.x;
          g.ball!.y = alive.y;
        }
        g.tick(1 / 60);
      }
      expect(g.isOver, isTrue);
      expect(g.result().reached, isTrue);
      expect(host.events, contains('win'));
    });
  });
}
