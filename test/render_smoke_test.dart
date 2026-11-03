/// PB-041 render-duman testleri: her yeni oyunun painter'ı NaN/istisna
/// olmadan çizilmeli (offset NaN hatasının kökünü cihazsız bulmak için).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/color_gate_game.dart';
import 'package:stack_tower_game/game/kinds/dark_hole_game.dart';
import 'package:stack_tower_game/game/kinds/neon_clean_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';

class _Host implements MiniGameHost {
  @override
  void playSound(String name, {int combo = 1}) {}
  @override
  void haptic(int ms) {}
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) {}
}

void _renderSmoke(MiniGame g, int frames) {
  for (var f = 0; f < frames; f++) {
    g.tick(1 / 60);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    g.render(canvas, const Size(392, 844));
    recorder.endRecording().dispose();
  }
}

void main() {
  test('RENK KAPI render dumanı — 240 kare NaN yok', () {
    final g = ColorGateGame();
    g.resize(392, 844);
    g.start(levelDef(15), host: _Host());
    _renderSmoke(g, 240);
  });

  test('NEON TEMİZLİK render dumanı — seçimli 120 kare NaN yok', () {
    final g = NeonCleanGame();
    g.resize(392, 844);
    g.start(levelDef(16), host: _Host());
    _renderSmoke(g, 60);
    g.onTap(const Offset(98, 780)); // kart seç
    _renderSmoke(g, 60);
  });

  test('UZUN KARANLIK render dumanı — süzülme 240 kare NaN yok', () {
    final g = DarkHoleGame();
    g.resize(392, 844);
    g.start(levelDef(17), host: _Host());
    g.onTap(const Offset(120, 340));
    _renderSmoke(g, 240);
  });
}
