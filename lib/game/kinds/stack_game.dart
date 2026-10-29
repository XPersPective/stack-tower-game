/// STACK adaptörü — mevcut GamePlay motorunu MiniGame sözleşmesine sarar
/// (ADR-008: antoloji host'u tür-agnostik çalışır, STACK regresyonsuz kalır).
library;

import 'package:flutter/material.dart';

import '../gameplay.dart';
import '../levels.dart';
import '../mini_game.dart';
import '../scene_painter.dart';

class StackGame implements MiniGame, InputGate {
  @override
  GameKind get kind => GameKind.stack;

  final GamePlay engine = GamePlay();
  late GamePlayRepaint _repaint;
  bool _ready = false;

  @override
  int get score => engine.score;
  @override
  int get target => engine.def?.target ?? 0;
  @override
  int get combo => engine.combo;
  @override
  int get shieldsLeft => engine.shieldsLeft;
  @override
  bool get isOver =>
      engine.state == EngineState.won || engine.state == EngineState.lost;

  /// juice (PB-016): hit-stop penceresinde dokunuş yok sayılır (kenarda donmuş
  /// blokta dokunuş garantili ıskalama olurdu); pencere ≤70ms, akış değişmez.
  @override
  bool get acceptsInput => engine.hitStop <= 0;

  @override
  void resize(double w, double h) => engine.resize(w, h);

  @override
  void start(LevelDef def, {required MiniGameHost host, int shields = 1, int hue = 200}) {
    if (!_ready) {
      _repaint = GamePlayRepaint(engine);
      _ready = true;
    }
    engine.onHaptic = host.haptic;
    // juice (PB-016): kritik çift vuruş deseni — yalnız destekleyen host'ta;
    // önceki oturumun deseni temizlenir (host değişirse bayat kapanış kalmasın)
    engine.onHapticPattern = null;
    if (host is HapticPatternHost) {
      engine.onHapticPattern = (host as HapticPatternHost).hapticPattern;
    }
    // Motor olayları MiniGameHost olay adlarına çevrilir (aynı yük alanları).
    engine.onEvent = (e, d) {
      // ESKİ davranış korunur: motor olayları ses de tetikler (audio regresyonu düzeltmesi)
      switch (e) {
        case EngineEvent.place:
          host.playSound(d.perfect ? 'perfect' : 'place', combo: d.combo);
        case EngineEvent.shield:
          host.playSound('shield');
        case EngineEvent.win:
          host.playSound('win');
        case EngineEvent.lose:
          host.playSound('lose');
        case EngineEvent.ready:
          break;
      }
      host.onEvent(e.name, data: <String, dynamic>{
        'perfect': d.perfect,
        'combo': d.combo,
        'score': d.score,
        'left': d.shieldLeft,
      });
    };
    engine.startLevel(def, hue: hue, shields: shields);
    host.playSound('start');
  }

  @override
  void tick(double dt) {
    engine.tick(dt);
    if (_ready) _repaint.notify();
  }

  @override
  void onTap(Offset local) => engine.drop();

  @override
  void render(Canvas canvas, Size size) {
    if (!_ready) _repaint = GamePlayRepaint(engine);
    ScenePainter(_repaint).paint(canvas, size);
  }

  @override
  void stop() => engine.stopLevel();

  @override
  MiniGameResult result() {
    final d = engine.detailedResult();
    return MiniGameResult(
      points: d.blocks,
      perfects: d.perfects,
      reached: d.reached,
      crits: d.crits,
      goldBlocks: d.goldBlocks,
    );
  }
}
