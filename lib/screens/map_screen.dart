/// Stack Tower Game — DİKEY YOL HARİTASI ekranı (PB-035 tur 5).
///
/// Premium saga-map (Royal Match modeli): kıvrımlı yol + bölüm düğümleri +
/// dünya kapıları; dikey kaydırma (sürükle + atalet), dokun→bölüm/pazar.
/// 3B takımada denemesi kullanıcı talebiyle kaldırıldı.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../game/game_session.dart';
import '../game/levels.dart';
import '../game/progress.dart' as prog;
import '../game/scene_painter.dart' show hslColor;
import '../map/construction.dart';
import '../map/journey_map.dart';
import '../theme/tokens.dart';
import '../ui/premium_kit.dart';
import 'flow_overlays.dart';
import 'router.dart';

/// PB-019: kilitli dünya ipucu — teaser'ın ilk yarısı + '…' (merak).
String lockedWorldHint(int stage) {
  final t = kWorldTeaser[stage % kWorldTeaser.length];
  final cut = (t.length * 0.55).round();
  return '${t.substring(0, cut).trimRight()}…';
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  List<JourneyNode>? _nodes;
  late final _Signal _repaint = _Signal();
  late Ticker _ticker;
  Duration _last = Duration.zero;
  double _scroll = 0;
  double _vel = 0;
  double _viewH = 800;
  int _layoutStamp = -1; // ilerleme değişince yerleşimi tazele

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    // PB-021: 3. bölümden sonra pazar keşfi bir kez duyurulur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<GameSession>();
      if (s.pendingMarketDiscovery && !s.state.marketSeen) {
        s.pendingMarketDiscovery = false;
        s.state.marketSeen = true;
        s.persist();
        ToastHost.show(context, 'PAZAR YERİ AÇILDI — yoldaki tezgaha dokun');
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _last = elapsed;
    // atalet: sürükleme bitince yavaşlayarak dur
    if (_vel.abs() > 1) {
      _scroll = (_scroll + _vel * dt).clamp(0.0, journeyHeight() - _viewH);
      _vel *= math.pow(0.0035, dt).toDouble();
      if (_vel.abs() < 20) _vel = 0;
    }
    _repaint.notify();
  }

  void _snapToCurrent() {
    final nodes = _nodes;
    if (nodes == null) return;
    // YÖN (tur 6): yolculuk YUKARI — güncel düğüm ekranın alt-orta bandında,
    // kilitli aşamalar yukarıda/ufukta; ilerledikçe harita aşağı akar.
    for (final n in nodes) {
      if (n.unlocked && !n.done) {
        _scroll = (n.pos.dy - _viewH * 0.68).clamp(0.0, journeyHeight() - _viewH);
        return;
      }
    }
    _scroll = (nodes.last.pos.dy - _viewH * 0.68)
        .clamp(0.0, journeyHeight() - _viewH);
  }

  void _openDaily() {
    final def = dailyDef(prog.dayOf(DateTime.now()));
    Navigator.pushNamed(context, Routes.preview, arguments: def);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        _viewH = constraints.maxHeight;
        // ilerleme damgası: tamamlanan bölümlerin sağlaması (ucuz)
        final stamp = session.state.levelsDone * 1000 + session.totalStars;
        var nodes = _nodes;
        if (nodes == null || stamp != _layoutStamp) {
          nodes = journeyLayout(session, constraints.maxWidth);
          _nodes = nodes;
          _layoutStamp = stamp;
          // İLK açılış VE bölüm sonrası dönüş: güncel düğüme otur —
          // "haritaya git dediğimde gitmiyor" hatasının düzeltmesi
          _snapToCurrent();
        }
        final list = nodes; // kapama içlerinde güvenli yerel kopya
        final marketOpen = _marketOpen(session);
        final focusStage = _focusStage(list);
        final world = _worldInfo(focusStage);

        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final mapPos = d.localPosition + Offset(0, _scroll);
                final hit = journeyHitTest(list, mapPos, marketOpen: marketOpen);
                if (hit != null && hit.startsWith('node:')) {
                  final i = int.parse(hit.substring(5));
                  final nd = list.firstWhere((e) => e.i == i);
                  if (nd.unlocked) {
                    Navigator.pushNamed(context, Routes.preview,
                        arguments: levelDef(nd.i));
                  } else {
                    final need = requiredStars(nd.def.stage);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        nd.def.stage > 0 && session.totalStars < need
                            ? 'BU DÜNYA İÇİN $need YILDIZ GEREKİYOR'
                            : "ÖNCE BÖLÜM ${nd.def.num - 1}'İ BİTİR",
                      ),
                    ));
                  }
                } else if (hit == 'market') {
                  Navigator.pushNamed(context, Routes.market); // PB-018
                }
              },
              onVerticalDragStart: (_) => _vel = 0,
              onVerticalDragUpdate: (d) {
                // tur 6: yolculuk yukarı — yukarı sürükle ileri götürür
                _scroll =
                    (_scroll + d.delta.dy).clamp(0.0, journeyHeight() - _viewH);
                _repaint.notify();
              },
              onVerticalDragEnd: (d) {
                _vel = d.velocity.pixelsPerSecond.dy * 0.55;
              },
              child: CustomPaint(
                painter: JourneyPainter(
                  session: session,
                  nodes: list,
                  scroll: _scroll,
                  time: _last.inMicroseconds / 1e6,
                  marketOpen: marketOpen,
                  repaint: _repaint,
                ),
                size: Size.infinite,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md, vertical: AppSpace.sm),
                child: Row(
                  children: [
                    _MapIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    ResourceChip(
                      coins: session.state.coins,
                      stars: session.totalStars,
                    ),
                    const SizedBox(width: AppSpace.sm),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: Center(
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xl, vertical: AppSpace.lg),
                  radius: AppRadius.xl,
                  blur: 10,
                  glowColor: hslColor(world.glow, 90, 62),
                  borderColor:
                      hslColor(world.glow, 90, 62).withValues(alpha: .45),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('DÜNYA ${world.stage + 1}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                  color: hslColor(world.glow, 90, 70),
                                  letterSpacing: 2)),
                      Text(world.open ? world.name : '🔒 ???',
                          style: Theme.of(context).textTheme.displayMedium),
                      Text(
                        world.open
                            ? '${world.done}/$kLevelsPerStage · ★ ${world.stars}'
                            : '🔒 ${session.totalStars}/${world.need} yıldız',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      // PB-019: kilitli dünyada kademeli ipucu
                      if (!world.open)
                        Text(lockedWorldHint(world.stage),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: NeonPalette.textDim)),
                      // PB-029: blueprint ipucu METİNLE de okunur (accessibility)
                      _buildHint(context, session, world),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PB-035 B3: KABUS KULESİ kapısı — haftalık 3 hak, kayıp cezasız
                  _NightmareGate(session: session),
                  const SizedBox(height: AppSpace.sm),
                  GradientButton(
                    label: 'GÜNLÜK MEYDAN OKUMA',
                    icon: Icons.public_rounded,
                    expand: true,
                    height: 54,
                    colors: const [
                      Color(0xFF2E1E86),
                      Color(0xFF12407E),
                      Color(0xFF451C7A),
                    ],
                    onTap: _openDaily,
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  bool _marketOpen(GameSession session) {
    var done = 0;
    for (var i = 0; i < 3; i++) {
      if (session.state.completed[i] != null) done++;
    }
    return done >= 3; // eski map3d hasMarket kuralı: 3 bölüm bitince pazar
  }

  int _focusStage(List<JourneyNode> nodes) {
    final midY = _scroll + _viewH * 0.45;
    JourneyNode? best;
    var bestD = double.infinity;
    for (final n in nodes) {
      final d = (n.pos.dy - midY).abs();
      if (d < bestD) {
        bestD = d;
        best = n;
      }
    }
    return best?.def.stage ?? 0;
  }

  ({int stage, bool open, String name, int done, int stars, int need, int glow})
      _worldInfo(int stage) {
    final session = context.read<GameSession>();
    var done = 0, stars = 0;
    for (var k = 0; k < kLevelsPerStage; k++) {
      final cm = session.state.completed[stage * kLevelsPerStage + k];
      if (cm != null) {
        done++;
        stars += cm['stars'] ?? 0;
      }
    }
    final need = requiredStars(stage);
    return (
      stage: stage,
      open: stage == 0 || session.totalStars >= need,
      name: kThemes[stage].name,
      done: done,
      stars: stars,
      need: need,
      glow: kThemes[stage].glow,
    );
  }

  /// PB-029: "burada ne yükselecek?" — inşaat ilerlemesinin metin karşılığı.
  Widget _buildHint(
      BuildContext context,
      GameSession session,
      ({int stage, bool open, String name, int done, int stars, int need, int glow})
          world) {
    final save = session.state;
    final next = nextBuildIdx(save, world.stage);
    final String visible;
    final String spoken;
    if (next == null) {
      visible = '🏛 ANIT TAMAM · DİYAR YOLU AÇIK';
      spoken = 'Bu dünyada tüm yapılar tamamlandı; anıt hazır.';
    } else {
      final spec = structureAt(next);
      final built = piecesBuilt(save, world.stage, slotOf(next).structure);
      final total = spec.pieces.length;
      final pct = (built * 100 / total).round();
      // PB-034 C3: yapı yüzdesi (merak kancası)
      visible = 'SIRADA: ${spec.name} · $built/$total · %$pct';
      spoken =
          'Burada ne yükselecek? ${spec.name}, $built/$total parça tamam, yüzde $pct. '
          'Sıradaki parça: ${pieceName(next)}.';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        label: spoken,
        child: Text(
          visible,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hslColor(world.glow, 90, 78),
                letterSpacing: 1.2,
              ),
        ),
      ),
    );
  }
}

/// PB-035 B3: Kabus Kulesi kapısı — hafta tohumlu, 3 hak, kayıp cezasız.
class _NightmareGate extends StatelessWidget {
  const _NightmareGate({required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final week = weekOf(DateTime.now().millisecondsSinceEpoch ~/ 86400000);
    final left = prog.nightmareTriesLeft(session.state, week);
    final best = session.state.nightmareBest;
    final active = left > 0;
    return Semantics(
      button: true,
      label: 'Kabus Kulesi: $left hak kaldı. Rekor $best blok.',
      child: GradientButton(
        label: active
            ? 'KABUS KULESİ · $left HAK'
            : 'KABUS BU HAFTA BİTTİ · REKOR $best',
        icon: Icons.dark_mode_rounded,
        expand: true,
        height: 46,
        enabled: active,
        colors: active
            ? const [Color(0xFF3B0D54), Color(0xFF54146B), Color(0xFF22104E)]
            : const [Color(0xFF1D1D2E), Color(0xFF161625)],
        onTap: () {
          prog.consumeNightmareTry(session.state, week);
          session.persist();
          Navigator.pushNamed(context, Routes.playNightmare);
        },
      ),
    );
  }
}

/// Harita köşe düğmesi (geri).
class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Geri',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: .28),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
          ),
          child: Icon(icon, size: 22, color: Colors.white.withValues(alpha: .9)),
        ),
      ),
    );
  }
}

/// Yol haritası tik sinyali (ChangeNotifier kısıtı olmadan).
class _Signal implements Listenable {
  final Set<VoidCallback> _ls = {};
  @override
  void addListener(VoidCallback l) => _ls.add(l);
  @override
  void removeListener(VoidCallback l) => _ls.remove(l);
  void notify() {
    for (final l in List.of(_ls)) {
      l();
    }
  }

  void dispose() => _ls.clear();
}
