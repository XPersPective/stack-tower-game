/// PB-035: dikey yol haritası (saga map) — yerleşim + hitTest + canlılık.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/map/journey_map.dart';
import 'package:stack_tower_game/services/storage.dart';

class _Noop extends ChangeNotifier {}

Future<List<int>> _frame(GameSession session, double scroll, double t) async {
  final nodes = journeyLayout(session, 420);
  final rec = ui.PictureRecorder();
  JourneyPainter(
    session: session,
    nodes: nodes,
    scroll: scroll,
    time: t,
    marketOpen: false,
    repaint: _Noop(),
  ).paint(Canvas(rec), const Size(420, 900));
  final img = await rec.endRecording().toImage(420, 900);
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

void main() {
  test('yerleşim: 150 düğüm, dikey tekdüze artar, yatay kadrajda kalır', () {
    final s = GameSession(MemoryStorage());
    final nodes = journeyLayout(s, 420);
    expect(nodes.length, kLevelCount);
    // YÖN (tur 6): yolculuk YUKARI — düğüm 0 altta (büyük y), 149 ufukta
    for (var i = 1; i < nodes.length; i++) {
      expect(nodes[i].pos.dy, lessThan(nodes[i - 1].pos.dy),
          reason: 'y azalan olmalı — ileri YUKARI (i=$i)');
    }
    expect(nodes[0].pos.dy, greaterThan(nodes[149].pos.dy));
    for (final n in nodes) {
      expect(n.pos.dx, inInclusiveRange(20, 400),
          reason: 'düğüm yol-kenarında: ${n.pos.dx}');
    }
    // dünya başına 15 düğüm
    for (var st = 0; st < 10; st++) {
      expect(nodes.where((n) => n.def.stage == st).length, 15);
    }
  });

  test('yerleşim: ilk bölüm açık, sonrası kilit; bitince done', () async {
    final s = GameSession(MemoryStorage());
    var nodes = journeyLayout(s, 420);
    expect(nodes[0].unlocked, isTrue);
    expect(nodes[1].unlocked, isFalse);
    prog.completeLevel(s.state, levelDef(0),
        blocks: 10, perfects: 5, reached: true, stars: 3);
    nodes = journeyLayout(s, 420);
    expect(nodes[0].done, isTrue);
    expect(nodes[1].unlocked, isTrue);
  });

  test('hitTest: düğüm konumunda node:i, boşlukta null', () {
    final s = GameSession(MemoryStorage());
    final nodes = journeyLayout(s, 420);
    expect(journeyHitTest(nodes, nodes[0].pos, marketOpen: false), 'node:0');
    expect(journeyHitTest(nodes, nodes[5].pos, marketOpen: false), 'node:5');
    expect(journeyHitTest(nodes, nodes[2].pos + const Offset(30, 260),
        marketOpen: false), isNull);
  });

  test('hitTest: 3 bölüm bitince pazar tezgahı', () async {
    final s = GameSession(MemoryStorage());
    for (var i = 0; i < 3; i++) {
      prog.completeLevel(s.state, levelDef(i),
          blocks: 10, perfects: 5, reached: true, stars: 3);
    }
    final nodes = journeyLayout(s, 420);
    final stall = Offset(nodes[2].pos.dx + 96, nodes[2].pos.dy + 8);
    expect(journeyHitTest(nodes, stall, marketOpen: true), 'market');
    expect(journeyHitTest(nodes, stall, marketOpen: false), isNull);
  });

  test('canlılık: zaman ilerleyince kareler farklı (ambient)', () async {
    final s = GameSession(MemoryStorage());
    final a = await _frame(s, 0, 0.0);
    final b = await _frame(s, 0, 1.7);
    expect(a, isNot(equals(b)));
  });

  test('tur 6: düğüm etiketleri — özel isimler parıltılı', () {
    final s = GameSession(MemoryStorage());
    final nodes = journeyLayout(s, 420);
    expect(nodes[4].label, '★ ALTIN HAZİNE'); // idx4 = altin
    expect(nodes[9].label, '★ ALTIN HAZİNE'); // idx9 = altin
    expect(nodes[14].label, '♛ PATRON'); // idx14 = patron
    // kutu kuralı: (i+1)%7==0 → i=6 ilk kutu düğümü
    expect(nodes[6].def.box, isTrue);
    expect(nodes[6].label, '🎁 SÜRPRİZ');
    // normal düğüm: kutu-olmayan ilk bölüm num'lu etiket taşır
    final normal = nodes
        .firstWhere((n) => !n.def.box && n.def.modifier == 'normal');
    expect(normal.label, contains('BÖLÜM'));
    // YÖN (tur 6): özel düğümler isSpecial işaretli (parıltı ölçüsü)
    expect(nodes[4].isSpecial, isTrue);
    expect(normal.isSpecial, isFalse);
  });

  test('kapı: journeyHeight 10 dünyayı kapsar', () {
    final s = GameSession(MemoryStorage());
    final nodes = journeyLayout(s, 420);
    expect(journeyHeight(), greaterThan(nodes.last.pos.dy));
    expect(gateY(3), worldBaseY(3) + 130);
  });
}
