/// PB-029 + PB-035: yol haritası inşaat göstergesi — parite + çizim kanıtı.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/map/construction.dart';
import 'package:stack_tower_game/map/journey_map.dart';
import 'package:stack_tower_game/services/storage.dart';

class _Noop extends ChangeNotifier {}

Future<void> _renderMap(GameSession session, String name) async {
  final nodes = journeyLayout(session, 540);
  const size = Size(540, 1200);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  JourneyPainter(
    session: session,
    nodes: nodes,
    scroll: ValueNotifier<double>(0),
    time: ValueNotifier<double>(1.2),
    marketOpen: false,
    repaint: _Noop(),
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(540, 1200);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  Directory('.project-brain/evidence/PB-035').createSync(recursive: true);
  File('.project-brain/evidence/PB-035/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Dünyadaki toplam inşa edilmiş parça (painter da aynı toplamı çizer).
int worldPiecesBuilt(prog.SaveState save, int stage) {
  var sum = 0;
  for (var si = 0; si < kWorldStructures.length; si++) {
    sum += piecesBuilt(save, stage, si);
  }
  return sum;
}

void main() {
  test('boş dünya: hiç parça yok, ilk düğüm açık', () async {
    final session = GameSession(MemoryStorage());
    final nodes = journeyLayout(session, 540);
    expect(worldPiecesBuilt(session.state, 0), 0);
    expect(nodes[0].unlocked, isTrue);
    await _renderMap(session, 'journey_empty');
  });

  test('6 bölüm bitmiş dünya: parça toplamı kurala uyumlu', () async {
    final session = GameSession(MemoryStorage());
    for (var i = 0; i < 6; i++) {
      prog.completeLevel(session.state, levelDef(i),
          blocks: 10, perfects: 5, reached: true, stars: 3);
    }
    expect(worldPiecesBuilt(session.state, 0), greaterThan(0));
    await _renderMap(session, 'journey_built6');
  });

  test('tüm dünya bitmiş: 4 yapının tüm parçaları tamamlanır', () async {
    final session = GameSession(MemoryStorage());
    for (var i = 0; i < kLevelsPerStage; i++) {
      prog.completeLevel(session.state, levelDef(i),
          blocks: 10, perfects: 5, reached: true, stars: 3);
    }
    var total = 0;
    for (var si = 0; si < kWorldStructures.length; si++) {
      total += kWorldStructures[si].pieces.length;
    }
    expect(worldPiecesBuilt(session.state, 0), total);
    await _renderMap(session, 'journey_world_done');
  });

  test('canlılık: aynı yerleşimde iki kare farklı (ambient süre)', () async {
    final session = GameSession(MemoryStorage());
    final nodes = journeyLayout(session, 420);
    Future<List<int>> shot(double t) async {
      final rec = ui.PictureRecorder();
      JourneyPainter(
        session: session,
        nodes: nodes,
        scroll: ValueNotifier<double>(0),
        time: ValueNotifier<double>(t),
        marketOpen: false,
        repaint: _Noop(),
      ).paint(Canvas(rec), const Size(420, 900));
      final img = await rec.endRecording().toImage(420, 900);
      final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      return d!.buffer.asUint8List();
    }

    final a = await shot(0);
    final b = await shot(1.9);
    expect(a, isNot(equals(b)));
  });
}
