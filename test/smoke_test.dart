/// PB-013 — duman simülasyonu (reference/smoke.js karşılığı):
/// boot → 400 rastgele bırakış → bölüm sonu → sonuç → yeni bölüm; çökme yok.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/gameplay.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/services/storage.dart';

void main() {
  test('duman: 50 bölüm × ~400 rastgele bırakış — çökme yok, ekonomi tutarlı', () {
    final storage = MemoryStorage();
    final rnd = math.Random(20261029);
    final session = GameSession(storage);
    var wins = 0, losses = 0, unfinished = 0;

    for (var iter = 0; iter < 50; iter++) {
      final def = levelDef((iter * 37) % 150);
      session.prepareLevel(def);
      final e = GamePlay();
      e.resize(460, 780);
      e.startLevel(def);

      var drops = 0;
      while (e.state == EngineState.playing && drops < 400) {
        final moving = e.moving;
        if (moving != null) {
          final top = e.blocks.last;
          // rastgele zamanlama + yatay gürültü (tol*3'e kadar)
          final noise = (rnd.nextDouble() * 2 - 1) * math.max(1, def.tol) * 3;
          moving.x = top.x + noise;
          moving.w = top.w;
          e.drop();
          drops++;
        }
        e.tick(1 / 60);
      }

      final r = e.detailedResult();
      if (e.state == EngineState.won) {
        wins++;
        session.onWin(r.blocks, r.perfects, crits: r.crits, goldBlocks: r.goldBlocks);
      } else if (e.state == EngineState.lost) {
        losses++;
        session.onLose(r.blocks, r.perfects);
      } else {
        unfinished++;
      }

      // ekonomi asla bozulmaz
      expect(session.state.coins, greaterThanOrEqualTo(0), reason: 'iter $iter');
      // her adımda kayıt yazılır
      expect(storage.getString(prog.kSaveKey), isNotNull, reason: 'iter $iter');
      // yıldız sınırı
      for (final cm in session.state.completed.values) {
        expect(cm['stars'], inInclusiveRange(0, 3));
      }
    }

    // en az bir kazanma ve bir kaybetme yolu koşulmuş olmalı
    expect(wins + losses + unfinished, 50);
    expect(wins, greaterThan(0), reason: 'kazanma yolu hiç koşmadı');
    expect(losses, greaterThan(0), reason: 'kaybetme yolu hiç koşmadı');
  });

  test('duman: yeniden yükleme kaydı bozmaz (boot → save → load)', () {
    final storage = MemoryStorage();
    final a = GameSession(storage);
    a.prepareLevel(levelDef(0));
    a.onWin(levelDef(0).target, 3);
    final coins = a.state.coins;
    final done = a.state.levelsDone;

    final b = GameSession(storage);
    expect(b.state.coins, coins);
    expect(b.state.levelsDone, done);
  });

  test('duman: kritik/altın sayaçları ve twist bölümleri ekonomiye zarar vermez', () {
    final storage = MemoryStorage();
    final session = GameSession(storage);
    for (var i = 0; i < 12; i++) {
      final def = levelDef(i);
      session.prepareLevel(def);
      session.onWin(def.target, 3, crits: 2, goldBlocks: 1);
      expect(session.state.coins, greaterThanOrEqualTo(0));
    }
  });
}
