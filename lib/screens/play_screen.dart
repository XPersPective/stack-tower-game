/// Stack Tower Game — oyun ekranı: ANTLOJİ HOST (ADR-008).
/// Tür-agnostik: LevelDef.kind → uygun MiniGame; ortak HUD, ticker, dokunma,
/// kazanma/kaybetme zinciri (kutu → tören → tahta → sonuç → harita).
library;

import 'dart:math' as math;

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
  // PB-033: sahne repaint köprüsü — her tik sonrası bildirir; CustomPaint'in
  // `repaint` dinleyicisi bunu RenderObject'e bağlar (kamera inişi/blok süzülmesi
  // ARTIK her karede çizilir; PB-022'de kopan bağın onarımı).
  final _SceneRepaint _sceneRepaint = _SceneRepaint();

  @override
  void initState() {
    super.initState();
    _def = widget.def;
    _prepare();
    _ticker = createTicker(_onTick)..start();
  }

  void _prepare() {
    final start = widget.session.prepareLevel(_def);
    // PB-037 X8 comeback: 2. ardışık kayıptan sonra TEKRAR — bu denemede
    // ödül ×2 (tek seferlik; rozet ekranı zaten vaat etti)
    if (widget.session.pendingComebackBoost) {
      widget.session.pendingComebackBoost = false;
      widget.session.doubleCoinsThisLevel = true;
    }
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
    final surprise = widget.session.currentSurprise;
    if (surprise != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // coinStart para uygulaması ilk kare SONRASINA ertelendi:
        // applyCoinStart → persist → notifyListeners zinciri build fazında
        // tetiklenemez (flow_test "markNeedsBuild during build" kuralı).
        final got = widget.session.applyCoinStart();
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
    final raw = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    // PB-033: sabit alt-adım — büyük dt (takılma/GC) 1/60'lık parçalara bölünür;
    // motor matematiği (C-002) aynı toplam dt ile akar, 50 ms'lik tek sıçrama
    // görünmez olur. Tavan 3 alt-adım (50 ms → 3×16.7 ms).
    final steps = math.min(3, math.max(1, (raw / (1 / 60)).ceil()));
    for (var i = 0; i < steps; i++) {
      _game.tick(raw / steps);
    }
    // PB-033: her tik sahneyi yeniden boyar (repaint köprüsü)
    _sceneRepaint.notify();
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
      'merge_pop' => GameSound.mergePop,
      'sort_flow' => GameSound.sortFlow,
      'pop' => GameSound.pop,
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
    // PB-021: ilk-5 mini sürpriz kapısı sonucu
    final gift = widget.session.lastFirstRunGift;
    if (gift != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ToastHost.show(context, gift);
      });
    }
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
    _sceneRepaint.dispose();
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
                child: RepaintBoundary(
                  // PB-033: oyun sahnesi kendi katmanında — HUD/overlay
                  // yeniden kurulumları sahnenin tam yeniden boyanmasını tetiklemez
                  child: CustomPaint(
                    painter: _MiniGamePainter(_game, repaint: _sceneRepaint),
                    size: Size.infinite,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md, vertical: AppSpace.sm),
                  child: Column(
                    children: [
                      // PB-037 (RESEARCH-hud): 3 bant TEK cam kapsül —
                      // ÇIK | tür rozeti | büyük gradyan skor | kombo/kalkan | ses
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: Colors.black.withValues(alpha: .32),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .16)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .25),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _hudButton(
                                  Icons.arrow_back_rounded, 'ÇIK', _exit),
                              const SizedBox(width: 6),
                              // tür rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                  color: Colors.white.withValues(alpha: .08),
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: .18)),
                                ),
                                child: Text('${spec.icon} ${spec.name}',
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              ),
                              const SizedBox(width: 10),
                              _buildHudScore(),
                              const SizedBox(width: 10),
                              _HudCombo(combo: _hudCombo),
                              const SizedBox(width: 6),
                              _HudShields(count: _hudShields),
                              const SizedBox(width: 6),
                              _hudButton(
                                widget.audio.muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                '',
                                () => setState(
                                    () => widget.audio.toggleMute()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_hudTarget > 0) ...[
                        const SizedBox(height: 6),
                        // hedef ilerlemesi — kapsül altında ince şerit
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60),
                          child: _HudProgress(
                            value:
                                (_hudScore / _hudTarget).clamp(0.0, 1.0),
                          ),
                        ),
                      ],
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: .22),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Icon(icon, color: NeonPalette.text, size: 24),
        ),
      ),
    );
  }

  /// HUD skoru — metin birebir korunur (testler '0'/'1' bekler), üstünde
  /// yalnızca görsel "pop" animasyonu vardır.
  Widget _buildHudScore() {
    // PB-037 (RESEARCH-hud): 31px w900 beyaz→cyan gradyan + çift glow
    final style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 31,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
      shadows: [
        Shadow(color: NeonPalette.cyan.withValues(alpha: .55), blurRadius: 18),
        Shadow(color: NeonPalette.magenta.withValues(alpha: .30), blurRadius: 30),
      ],
    );
    return ShaderMask(
      shaderCallback: (b) => const LinearGradient(colors: [
        Colors.white,
        Color(0xFF9BE8FF),
      ]).createShader(b),
      blendMode: BlendMode.srcIn,
      child: _PopText(
        text: _hudTarget > 0 ? '$_hudScore/$_hudTarget' : '$_hudScore',
        style: style,
      ),
    );
  }
}

/// HUD skoru — değiştiğinde ölçek "pop" yapar (metin değişmez).
class _PopText extends StatefulWidget {
  const _PopText({required this.text, this.style});
  final String text;
  final TextStyle? style;

  @override
  State<_PopText> createState() => _PopTextState();
}

class _PopTextState extends State<_PopText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  String _last = '';

  @override
  void initState() {
    super.initState();
    _last = widget.text;
  }

  @override
  void didUpdateWidget(covariant _PopText old) {
    super.didUpdateWidget(old);
    if (widget.text != _last) {
      _last = widget.text;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_c.value.clamp(0.0, 1.0));
        return Transform.scale(scale: 1.0 + 0.18 * t, child: child);
      },
      child: Text(widget.text, style: widget.style),
    );
  }
}

/// HUD ilerleme çubuğu — hedefe yaklaşırken parlar.
class _HudProgress extends StatelessWidget {
  const _HudProgress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final near = (value - 0.75).clamp(0.0, 1.0) / 0.25;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Stack(
        children: [
          Container(
            height: 8,
            color: Colors.black.withValues(alpha: .28),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    NeonPalette.cyan,
                    Color.lerp(NeonPalette.cyan, NeonPalette.magenta, near)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: NeonPalette.cyan.withValues(alpha: .35 + near * .3),
                    blurRadius: 10 + near * 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// HUD kombo rozeti — arttığında altın renge döner ve parlar.
class _HudCombo extends StatelessWidget {
  const _HudCombo({required this.combo});
  final int combo;

  @override
  Widget build(BuildContext context) {
    if (combo < 2) return const SizedBox.shrink();
    final hot = combo >= 6;
    final color = hot ? NeonPalette.magenta : NeonPalette.amber;
    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: appCurve,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: color.withValues(alpha: .14),
        border: Border.all(color: color.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .30), blurRadius: 16),
        ],
      ),
      child: Text(
        '×$combo',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              shadows: [Shadow(color: color.withValues(alpha: .7), blurRadius: 14)],
            ),
      ),
    );
  }
}

/// HUD kalkan göstergesi — kalkan yoksa soluk ve çarpı.
class _HudShields extends StatelessWidget {
  const _HudShields({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return AnimatedOpacity(
      duration: AppDurations.normal,
      opacity: active ? 1 : 0.32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded,
              size: 19, color: active ? NeonPalette.mint : NeonPalette.textDim),
          const SizedBox(width: 5),
          Text('×$count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: active ? NeonPalette.mint : NeonPalette.textDim,
                  )),
        ],
      ),
    );
  }
}

/// MiniGame.render'ı her karede çağıran painter.
/// PB-033: `repaint` dinleyicisi RenderCustomPaint'e bağlanır — tik başına
/// yeniden boyama (d76a61c davranışı; PB-022'de yanlışlıkla kopmuştu).
class _MiniGamePainter extends CustomPainter {
  _MiniGamePainter(this.game, {required Listenable repaint}) : super(repaint: repaint);
  final MiniGame game;

  @override
  void paint(Canvas canvas, Size size) => game.render(canvas, size);

  @override
  bool shouldRepaint(covariant _MiniGamePainter oldDelegate) => true;
}

/// PB-033: sahne repaint sinyali — tik başına tek bildirim, kendisi dispose
/// edilebilir (CustomPaint'in `repaint` dinleyicisi olarak bağlanır).
class _SceneRepaint implements Listenable {
  final Set<VoidCallback> _listeners = {};
  bool _disposed = false;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notify() {
    if (_disposed) return;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}
