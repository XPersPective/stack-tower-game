/// Stack Tower Game — oyun ekranı: ANTLOJİ HOST (ADR-008).
/// Tür-agnostik: LevelDef.kind → uygun MiniGame; ortak HUD, ticker, dokunma,
/// kazanma/kaybetme zinciri (kutu → tören → tahta → sonuç → harita).
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/kinds/balance_game.dart';
import '../game/kinds/catcher_game.dart';
import '../game/kinds/defend_game.dart';
import '../game/kinds/launch_game.dart';
import '../game/kinds/merge_game.dart';
import '../game/kinds/path_game.dart';
import '../game/kinds/sort_game.dart';
import '../game/kinds/rhythm_game.dart';
import '../game/kinds/ring_game.dart';
import '../game/kinds/stack_game.dart';
import '../game/levels.dart';
import '../game/mini_game.dart';
import '../game/twists.dart';
import '../theme/tokens.dart';
import 'flow_overlays.dart';

/// MiniGame fabrikası — yeni türler buraya eklenir (DESIGN-V2 §4).
MiniGame createMiniGame(GameKind kind) {
  switch (kind) {
    case GameKind.stack:
      return StackGame();
    case GameKind.catcher:
      return CatcherGame();
    case GameKind.ring:
      return RingGame();
    case GameKind.launch:
      return LaunchGame();
    case GameKind.merge:
      return MergeGame();
    case GameKind.path:
      return PathGame();
    case GameKind.sort:
      return SortGame();
    case GameKind.balance:
      return BalanceGame();
    case GameKind.defend:
      return DefendGame();
    case GameKind.rhythm:
      return RhythmGame();
  }
}

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
  final VoidCallback onExit;
  final VoidCallback onFlowDone;

  @override
  State<PlayScreen> createState() => PlayScreenState();
}

class PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin
    implements MiniGameHost, HapticPatternHost {
  late MiniGame _game;
  late LevelDef _def;
  late Ticker _ticker;
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  int _hudScore = 0, _hudCombo = 0, _hudShields = 1, _hudTarget = 0;
  int _layerCombo = 0; // PB-017: son bildirilen kombo (katman eşikleri)
  bool _fanfarePlayed = false;
  bool _overlayOpen = false;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _def = widget.def;
    _prepare();
    _ticker = createTicker(_onTick)..start();
  }

  void _prepare() {
    final start = widget.session.prepareLevel(_def);
    _game = createMiniGame(_def.kind);
    _won = false;
    if (_size.width > 0) _game.resize(_size.width, _size.height);
    _game.start(_def,
        host: this, shields: start.shields, hue: widget.session.activeSkinHue);
    _hudShields = start.shields;
    _hudScore = 0;
    _hudCombo = 0;
    _layerCombo = 0;
    _fanfarePlayed = false;
    widget.audio.setCombo(0); // yeni bölüm: katmanlar sıfırdan
    _hudTarget = _game.target;
    final got = widget.session.applyCoinStart();
    final surprise = widget.session.currentSurprise;
    if (surprise != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ToastHost.show(
            context,
            got > 0
                ? '✨ Gizem çözüldü: +$got 🪙'
                : '✨ Gizem çözüldü: ${surprise.name}');
      });
    }
    // sürpriz motoru (PB-015): twist bölümü açılışta duyurulur — hint okunur
    final twistType =
        _def.kind == GameKind.stack ? (_game as StackGame).engine.twist : null;
    final twist = twistType == null ? null : kTwists[twistType];
    if (twist != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ToastHost.show(context, '${twist.icon} ${twist.name} — ${twist.hint}');
      });
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _game.tick(dt);
    // PB-017: kombo merdiveni — 3/6/10 eşiklerinde katmanlar açılır
    if (_game.combo != _layerCombo) {
      _layerCombo = _game.combo;
      widget.audio.setCombo(_layerCombo);
      if (_layerCombo == 10 && !_fanfarePlayed) {
        _fanfarePlayed = true;
        widget.audio.play(GameSound.fanfare);
      }
    }
    if (_game.score != _hudScore ||
        _game.combo != _hudCombo ||
        _game.shieldsLeft != _hudShields ||
        _game.target != _hudTarget) {
      if (mounted) {
        setState(() {
          _hudScore = _game.score;
          _hudCombo = _game.combo;
          _hudShields = _game.shieldsLeft;
          _hudTarget = _game.target;
        });
      }
    }
  }

  /* ------------------------- MiniGameHost ------------------------- */

  @override
  void playSound(String name, {int combo = 1}) {
    final s = switch (name) {
      'place' => GameSound.place,
      'perfect' => GameSound.perfect,
      'win' => GameSound.win,
      'lose' => GameSound.lose,
      'coin' => GameSound.coin,
      'box' => GameSound.box,
      'shield' => GameSound.shield,
      'start' => GameSound.start,
      'crit' => GameSound.crit,
      'fanfare' => GameSound.fanfare,
      'mystery' => GameSound.mystery,
      _ => GameSound.place,
    };
    widget.audio.play(s, combo: combo);
  }

  @override
  void haptic(int ms) {
    // C-023 juice: dokunsal geri bildirim (süreye göre şiddet seçilir)
    if (ms >= 50) {
      HapticFeedback.heavyImpact();
    } else if (ms >= 25) {
      HapticFeedback.mediumImpact();
    } else if (ms > 0) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void hapticPattern(List<int> onsetsMs) {
    // C-023 juice (PB-016): liste vuruş BAŞLANGIÇ anlarıdır (ms); her vuruş
    // kısa bir darbe olarak çalınır (platform süresi ms cinsinden yok sayar)
    for (final at in onsetsMs) {
      if (at <= 0) {
        haptic(10);
      } else {
        final d = Duration(milliseconds: at);
        Future.delayed(d, () {
          if (mounted) haptic(10);
        });
      }
    }
  }

  @override
  void onEvent(String name, {Map<String, dynamic>? data}) {
    if (!mounted) return;
    switch (name) {
      case 'win':
        _won = true;
        _finishLevel();
      case 'lose':
        _won = false;
        _finishLevel();
      case 'shield':
        setState(() => _hudShields = (data?['left'] as int?) ?? 0);
      default:
        break;
    }
  }

  void _finishLevel() {
    widget.audio.setCombo(0); // PB-017: bölüm sonu — katmanlar söner
    final r = _game.result();
    if (_won) {
      widget.session.onWin(r.points, r.perfects,
          crits: r.crits, goldBlocks: r.goldBlocks);
    } else {
      widget.session.onLose(r.points, r.perfects);
    }
    setState(() => _overlayOpen = true);
  }

  DateTime? _lastBackTap;

  /// Geri/ÇIK: yanlışlıkla çıkışı önlemek için çift dokunma onayı.
  void _exit() {
    final now = DateTime.now();
    final prev = _lastBackTap;
    _lastBackTap = now;
    if (prev == null || now.difference(prev) > const Duration(seconds: 2)) {
      ToastHost.show(context, 'Çıkmak için tekrar dokun');
      return;
    }
    _ticker.stop();
    _game.stop();
    widget.onExit();
  }

  /// Test kancaları: aktif MiniGame ve (STACK ise) alttaki motor.
  @visibleForTesting
  MiniGame get gameForTest => _game;

  @visibleForTesting
  dynamic get engineForTest =>
      _game is StackGame ? (_game as StackGame).engine : null;

  @override
  void dispose() {
    _ticker.dispose();
    _game.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = _def;
    final spec = def.kindSpec;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        body: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size != _size && size.width > 0) {
            _size = size;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _game.resize(size.width, size.height);
            });
          }
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (_overlayOpen) return;
                  // juice (PB-016): hit-stop penceresinde dokunuş yok sayılır
                  if (_game is InputGate && !(_game as InputGate).acceptsInput) return;
                  // PB-025: basılı tut = şarj (LAUNCH); diğer türler tek dokunuş
                  if (_game is HoldGame) {
                    (_game as HoldGame).onHoldStart(d.localPosition);
                  } else {
                    _game.onTap(d.localPosition);
                  }
                },
                onTapUp: (d) {
                  if (_game is HoldGame) (_game as HoldGame).onRelease(d.localPosition);
                },
                onTapCancel: () {
                  if (_game is HoldGame) (_game as HoldGame).onHoldCancel();
                },
                child: CustomPaint(
                  painter: _MiniGamePainter(_game),
                  size: Size.infinite,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _hudButton(Icons.arrow_back, 'ÇIK', _exit),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withValues(alpha: .08),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .18)),
                            ),
                            child: Text('${spec.icon} ${spec.name}',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                          const Spacer(),
                          Text(
                            _hudTarget > 0 ? '$_hudScore/$_hudTarget' : '$_hudScore',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const Spacer(),
                          _hudButton(
                            widget.audio.muted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            '',
                            () => setState(() => widget.audio.toggleMute()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_hudTarget > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (_hudScore / _hudTarget).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: .12),
                            valueColor:
                                const AlwaysStoppedAnimation(NeonPalette.cyan),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _hudCombo >= 2 ? '×$_hudCombo' : '',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    color: NeonPalette.amber,
                                    shadows: [
                                      Shadow(
                                          color: NeonPalette.amber
                                              .withValues(alpha: .6),
                                          blurRadius: 18)
                                    ]),
                          ),
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
                    setState(() => _overlayOpen = false);
                    _prepare();
                    if (!_ticker.isActive) _ticker.start();
                  },
                  onNext: (nextDef) {
                    setState(() {
                      _def = nextDef;
                      _overlayOpen = false;
                    });
                    _prepare();
                    if (!_ticker.isActive) _ticker.start();
                  },
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _hudButton(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label.isEmpty ? null : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          child: Icon(icon, color: NeonPalette.text, size: 26),
        ),
      ),
    );
  }
}

/// MiniGame.render'ı her karede çağıran painter.
class _MiniGamePainter extends CustomPainter {
  _MiniGamePainter(this.game);
  final MiniGame game;

  @override
  void paint(Canvas canvas, Size size) => game.render(canvas, size);

  @override
  bool shouldRepaint(covariant _MiniGamePainter oldDelegate) => true;
}
