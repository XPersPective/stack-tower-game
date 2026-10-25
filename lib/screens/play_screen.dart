/// Stack Tower Game — oyun ekranı: Ticker + dokunma + HUD.
/// game.js frame döngüsü + ui.js HUD davranışının Flutter portu (SPEC §2.8).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/gameplay.dart';
import '../game/levels.dart';
import '../game/scene_painter.dart';
import '../theme/tokens.dart';
import 'flow_overlays.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.session,
    required this.audio,
    required this.def,
    required this.onExit,
    required this.onFlowDone,
  });

  final GameSession session;
  final AudioController audio;
  final LevelDef def;
  final VoidCallback onExit; // HUD ‹ÇIK
  /// Zincir bittiğinde (result → showMap) çağrılır.
  final VoidCallback onFlowDone;

  @override
  State<PlayScreen> createState() => PlayScreenState();
}

class PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  late final GamePlay _engine;
  late final GamePlayRepaint _repaint;
  late final Ticker _ticker;
  late LevelDef _def = widget.def;
  Duration _last = Duration.zero;

  // HUD anlık değerleri (her frame setState yok — değer değişince güncellenir)
  int _hudScore = 0, _hudCombo = 0, _hudShields = 1;
  bool _overlayOpen = false;
  // Çıkış onayı: ilk dokunuş silahlanır, 2.5 sn içinde tekrar dokunuş çıkarır.
  bool _exitArmed = false;
  Timer? _exitResetTimer;

  @override
  void initState() {
    super.initState();
    _engine = GamePlay();
    _repaint = GamePlayRepaint(_engine);
    _engine.onEvent = _onEngineEvent;
    _engine.onHaptic = (_) {}; // titreşim: pb-010'da Haptics bağlanır
    final start = widget.session.prepareLevel(_def);
    _pendingStart = start;
    _hudShields = start.shields;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if (size != null && size.width > 0) _engine.resize(size.width, size.height);
      _startEngine();
    });
    _ticker = createTicker(_onTick)..start();
  }

  LevelStart? _pendingStart;

  /// Test gözlemcisi için motor erişimi (üretimde kullanılmaz).
  @visibleForTesting
  GamePlay get engineForTest => _engine;

  void _startEngine() {
    final start = _pendingStart!;
    _engine.startLevel(_def, hue: start.hue, shields: start.shields);
    widget.audio.play(GameSound.start);
    final got = widget.session.applyCoinStart();
    if (widget.session.currentSurprise != null && mounted) {
      final s = widget.session.currentSurprise!;
      ToastHost.show(context, got > 0 ? '✨ Gizem çözüldü: +$got 🪙' : '✨ Gizem çözüldü: ${s.name}');
    }
  }

  void _onEngineEvent(EngineEvent event, EngineEventData data) {
    if (!mounted) return;
    switch (event) {
      case EngineEvent.place:
        setState(() {
          _hudScore = data.score;
          _hudCombo = data.combo;
        });
        widget.audio.play(data.perfect ? GameSound.perfect : GameSound.place, combo: data.combo);
      case EngineEvent.shield:
        setState(() => _hudShields = data.shieldLeft);
        widget.audio.play(GameSound.shield);
      case EngineEvent.win:
        widget.session.onWin(_engine.result().blocks, _engine.perfects);
        widget.audio.play(GameSound.win);
        _openChain();
      case EngineEvent.lose:
        widget.session.onLose(_engine.result().blocks, _engine.perfects);
        widget.audio.play(GameSound.lose);
        _openChain();
      case EngineEvent.ready:
        break;
    }
  }

  void _openChain() {
    setState(() => _overlayOpen = true);
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _engine.tick(dt);
    _repaint.notify();
  }

  void _drop() {
    if (_overlayOpen) return;
    _engine.drop();
  }

  void _exit() {
    if (!_exitArmed) {
      // Yanlışlıkla çıkışı engelle: ilk dokunuş yalnız silahlanır (ui.js onay diyalogu karşılığı).
      _exitArmed = true;
      _exitResetTimer?.cancel();
      _exitResetTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _exitArmed = false);
      });
      setState(() {});
      ToastHost.show(context, 'Çıkmak için tekrar dokun');
      return;
    }
    _exitResetTimer?.cancel();
    _ticker.stop();
    _engine.stopLevel();
    widget.onExit();
  }

  @override
  void dispose() {
    _exitResetTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = _def;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        body: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 0 &&
              (constraints.maxWidth != _engine.w || constraints.maxHeight != _engine.h)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _engine.resize(constraints.maxWidth, constraints.maxHeight);
            });
          }
          return Stack(
            children: [
              // Oyun sahnesi — dokunma = bırakma
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _drop(),
                child: CustomPaint(
                  painter: ScenePainter(_repaint),
                  size: Size.infinite,
                ),
              ),
              // HUD
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _hudButton(Icons.arrow_back, _exitArmed ? 'Çıkışı onayla' : 'ÇIK', _exit,
                              armed: _exitArmed),
                          const Spacer(),
                          Text(
                            def.target > 0 ? '$_hudScore/${def.target}' : '$_hudScore',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const Spacer(),
                          _hudButton(
                            widget.audio.muted ? Icons.volume_off : Icons.volume_up,
                            '',
                            () => setState(() => widget.audio.toggleMute()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // hedef ilerleme çubuğu
                      if (def.target > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (_hudScore / def.target).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: .12),
                            valueColor: const AlwaysStoppedAnimation(NeonPalette.cyan),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // seri çarpanı
                          Text(
                            _hudCombo >= 2 ? '×$_hudCombo' : '',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: NeonPalette.amber,
                                  shadows: [
                                    Shadow(color: NeonPalette.amber.withValues(alpha: .6), blurRadius: 18)
                                  ],
                                ),
                          ),
                          // kalkan rozeti
                          Opacity(
                            opacity: _hudShields > 0 ? 1 : 0.3,
                            child: Text('🛡 ×$_hudShields',
                                style: Theme.of(context).textTheme.titleLarge),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Zincir overlay'leri (kutu → tören → tahta → sonuç)
              if (_overlayOpen)
                FlowOverlays(
                  session: widget.session,
                  audio: widget.audio,
                  onFlowDone: () {
                    setState(() => _overlayOpen = false);
                    _ticker.stop();
                    widget.onFlowDone();
                  },
                  onRetry: () {
                    setState(() {
                      _overlayOpen = false;
                      _hudScore = 0;
                      _hudCombo = 0;
                    });
                    _pendingStart = widget.session.prepareLevel(_def);
                    _hudShields = _pendingStart!.shields;
                    _startEngine();
                    if (!_ticker.isActive) _ticker.start();
                  },
                  onNext: (nextDef) {
                    // SONRAKİ BÖLÜM: aynı ekran, yeni tanım
                    setState(() {
                      _def = nextDef;
                      _overlayOpen = false;
                      _hudScore = 0;
                      _hudCombo = 0;
                    });
                    _pendingStart = widget.session.prepareLevel(nextDef);
                    _hudShields = _pendingStart!.shields;
                    _startEngine();
                    if (!_ticker.isActive) _ticker.start();
                  },
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _hudButton(IconData icon, String label, VoidCallback onTap, {bool armed = false}) {
    return Semantics(
      button: true,
      label: label.isEmpty ? null : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          decoration: armed
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NeonPalette.amber, width: 1.6),
                )
              : null,
          child: Icon(icon,
              color: armed ? NeonPalette.amber : NeonPalette.text, size: 26),
        ),
      ),
    );
  }
}
