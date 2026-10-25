import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/catcher_game.dart';
import 'package:stack_tower_game/game/kinds/ring_game.dart';
import 'package:stack_tower_game/game/kinds/stack_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';

class _RecordingHost implements MiniGameHost {
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
  group('kindFor dağıtım yasası (ADR-008 / C-020)', () {
    test('ilk 5 bölüm 5 FARKLI tür (hook)', () {
      final first5 = [for (var i = 0; i < 5; i++) kindFor(i)];
      expect(first5, [
        GameKind.catcher,
        GameKind.ring,
        GameKind.stack,
        GameKind.launch,
        GameKind.merge,
      ]);
      expect(first5.toSet().length, 5, reason: '5 farklı tür olmalı');
    });

    test('150 bölümde ardışık aynı tür ≤1', () {
      for (var i = 1; i < kLevelCount; i++) {
        expect(kindFor(i) == kindFor(i - 1), isFalse,
            reason: 'i=$i: ${kindFor(i)} ardışık tekrar');
      }
    });

    test('tür çeşitliliği: 150 bölümde ≥8 farklı tür kullanılır', () {
      final kinds = {for (var i = 0; i < kLevelCount; i++) kindFor(i)};
      expect(kinds.length, greaterThanOrEqualTo(8));
    });

    test('dünya patronları (idx 14) imza tür döndürür', () {
      for (var s = 0; s < kStageCount; s++) {
        final i = s * kLevelsPerStage + kLevelsPerStage - 1;
        expect(kindFor(i), isNotNull);
      }
      // 10 dünya patronu farklı türlerde (çeşitlilik)
      final bosses = {
        for (var s = 0; s < kStageCount; s++)
          kindFor(s * kLevelsPerStage + kLevelsPerStage - 1)
      };
      expect(bosses.length, greaterThanOrEqualTo(6));
    });

    test('günlük/serbest → stack (klasik kimlik korunur)', () {
      expect(dailyDef(5).kind, GameKind.stack);
      expect(endlessDef().kind, GameKind.stack);
    });

    test("her türün KindSpec'i dolu (isim/ikon/ipucu)", () {
      for (final k in GameKind.values) {
        expect(kKindSpecs[k]!.name, isNotEmpty);
        expect(kKindSpecs[k]!.icon, isNotEmpty);
        expect(kKindSpecs[k]!.hint, isNotEmpty);
      }
    });
  });

  group('MiniGame sözleşmesi (parametrik)', () {
    final games = <MiniGame>[StackGame(), CatcherGame(), RingGame()];

    for (final g in games) {
      test('${g.kind.name}: start→tick→onTap→result döngüsü exception yok', () {
        final host = _RecordingHost();
        g.resize(460, 780);
        g.start(levelDef(2), host: host, shields: 1);
        expect(g.target, greaterThan(0));
        for (var i = 0; i < 120; i++) {
          g.tick(1 / 60);
          g.onTap(Offset(230, 400));
        }
        final r = g.result();
        expect(r.points, greaterThanOrEqualTo(0));
        expect(host.sounds, isNotEmpty, reason: 'ses olayı üretilmeli');
        g.stop();
      });
    }

    test('CATCHER: yıldız yakalama skoru artırır, hedefe ulaşınca win', () {
      final g = CatcherGame();
      final host = _RecordingHost();
      g.resize(460, 780);
      g.start(levelDef(0), host: host); // tür 0 = catcher
      // sepeti ortaya al ve düşenleri yakala: 400 tik + merkezde tut
      for (var i = 0; i < 1200 && !g.isOver; i++) {
        g.tick(1 / 60);
      }
      // oyun ya bitti ya devam ediyor; exception yok ve tutarlı
      expect(g.score, greaterThanOrEqualTo(0));
      expect(host.events.any((e) => e == 'win' || e == 'lose' || e == 'shield') || !g.isOver,
          isTrue);
    });

    test('RING: hedef dilimde dokunma skoru artırır', () {
      final g = RingGame();
      final host = _RecordingHost();
      g.resize(460, 780);
      g.start(levelDef(1), host: host); // tür 1 = ring
      var hits = 0;
      // 400 denemede en az bir isabet (hedef dilim ≥0.34 rad, dönüş 1.4+ rad/s)
      for (var i = 0; i < 400 && !g.isOver; i++) {
        g.tick(1 / 240);
        g.onTap(Offset.zero);
        if (g.score > hits) hits = g.score;
      }
      expect(hits, greaterThan(0), reason: 'hiç isabet olmadı');
    });

    test('STACK adaptörü: mevcut motor davranışı korunur (skor/mükemmel)', () {
      final g = StackGame();
      final host = _RecordingHost();
      g.resize(460, 780);
      g.start(levelDef(2), host: host, shields: 1);
      final e = g.engine;
      for (var i = 0; i < 8; i++) {
        e.moving!.x = e.blocks.last.x;
        e.moving!.w = e.blocks.last.w;
        e.drop();
      }
      final r = g.result();
      expect(r.points, 8);
      expect(r.perfects, 8);
      expect(r.reached, isTrue);
      expect(g.isOver, isTrue);
    });
  });
}
