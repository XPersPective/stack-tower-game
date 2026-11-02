/// Stack Tower Game — 3B takımada haritası ekranı (map.js portu).
/// Sürükle→yörünge, dikey sürükle→dünya geçişi, dokun→bölüm/günlük.
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
import '../map/map3d.dart';
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
  late MapScene _scene;
  late MapCamera _camera;
  late MapRepaint _repaint;
  late Ticker _ticker;
  Duration _last = Duration.zero;
  bool _snap = true;
  double _yawVel = 0;
  _Drag? _drag;

  @override
  void initState() {
    super.initState();
    _scene = MapScene(context.read<GameSession>());
    // PB-021: 3. bölümden sonra pazar keşfi bir kez duyurulur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<GameSession>();
      if (s.pendingMarketDiscovery && !s.state.marketSeen) {
        s.pendingMarketDiscovery = false;
        s.state.marketSeen = true;
        s.persist();
        ToastHost.show(context, 'PAZAR YERİ AÇILDI — adadaki tezgaha dokun');
      }
    });
    // PB-029: haritaya dönüşte en son inşa edilen parça 1.2s yükselir
    final next = nextBuildIdx(context.read<GameSession>().state, _scene.focusStage);
    if (next != null && next > 0) _scene.startRise(next - 1);
    _camera = MapCamera();
    _repaint = MapRepaint();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _last = elapsed;
    if (_drag == null) {
      _camera.yaw += _yawVel * dt;
      _yawVel *= 0.9;
      if (_yawVel.abs() < 0.001) _yawVel = 0;
    }
    _scene.updateRise(dt);
    _camera.update(_scene, dt, snap: _snap);
    _snap = false;
    _repaint.notify();
  }

  void _openDaily() {
    final def = dailyDef(prog.dayOf(DateTime.now()));
    Navigator.pushNamed(context, Routes.preview, arguments: def);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    final isl = _scene.islands[_scene.focusStage];
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final hit = hitTest(_scene, d.localPosition);
                if (hit != null && hit.startsWith('node:')) {
                  final i = int.parse(hit.substring(5));
                  final nd = _scene.nodes[i];
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
                } else {
                  _openDaily();
                }
              },
              onPanStart: (d) {
                _drag = _Drag(start: d.localPosition, yaw: _camera.yaw);
                _yawVel = 0;
              },
              onPanUpdate: (d) {
                final drag = _drag;
                if (drag == null) return;
                final dx = d.localPosition.dx - drag.start.dx;
                final dy = d.localPosition.dy - drag.start.dy;
                drag.moved = math.max(drag.moved, (d.localPosition - drag.start).distance);
                drag.dy = dy;
                _camera.yaw = drag.yaw - dx * 0.006;
              },
              onPanEnd: (d) {
                final drag = _drag;
                if (drag == null) return;
                if (drag.moved >= 12 &&
                    drag.dy.abs() > 64 &&
                    drag.dy.abs() > (d.localPosition.dx - drag.start.dx).abs() * 0.75) {
                  _scene.setFocus(_scene.focusStage + (drag.dy < 0 ? 1 : -1));
                  _snap = true;
                }
                _drag = null;
              },
              child: CustomPaint(
                painter: MapScenePainter(_scene, _camera, _last.inMicroseconds / 1e6,
                    repaint: _repaint),
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
                  glowColor: hslColor(isl.theme.glow, 90, 62),
                  borderColor:
                      hslColor(isl.theme.glow, 90, 62).withValues(alpha: .45),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('DÜNYA ${isl.stage + 1}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                  color: hslColor(isl.theme.glow, 90, 70),
                                  letterSpacing: 2)),
                      Text(isl.open ? isl.theme.name : '🔒 ???',
                          style: Theme.of(context).textTheme.displayMedium),
                      Text(
                        isl.open
                            ? '${isl.done}/$kLevelsPerStage · ★ ${isl.stars}'
                            : '🔒 ${session.totalStars}/${isl.need} yıldız',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      // PB-019: kilitli dünyada kademeli ipucu
                      if (!isl.open)
                        Text(lockedWorldHint(isl.stage),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: NeonPalette.textDim)),
                      // PB-029: blueprint ipucu METİNLE de okunur (accessibility)
                      _buildHint(context, session, isl.stage),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: GradientButton(
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
            ),
          ],
        );
      }),
    );
  }

  /// PB-029: "burada ne yükselecek?" — haritadaki silüetin metin karşılığı.
  Widget _buildHint(BuildContext context, GameSession session, int stage) {
    final save = session.state;
    final next = nextBuildIdx(save, stage);
    final String visible;
    final String spoken;
    if (next == null) {
      visible = '🏛 ANIT TAMAM · DİYAR YOLU AÇIK';
      spoken = 'Bu dünyada tüm yapılar tamamlandı; anıt hazır.';
    } else {
      final spec = structureAt(next);
      final built = piecesBuilt(save, stage, slotOf(next).structure);
      final total = spec.pieces.length;
      final pct = (built * 100 / total).round();
      // PB-034 C3: yapı yüzdesi + blueprint siluet bilgisi (merak kancası)
      visible = 'SIRADA: ${spec.name} · $built/$total · %$pct';
      spoken = 'Burada ne yükselecek? ${spec.name}, $built/$total parça tamam, yüzde $pct. '
          'Sıradaki parça: ${pieceName(next)}.';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        label: spoken,
        child: Text(
          visible,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hslColor(_glowFor(stage), 90, 78),
                letterSpacing: 1.2,
              ),
        ),
      ),
    );
  }

  int _glowFor(int stage) => kThemes[stage].glow;
}

class _Drag {
  Offset start;
  double yaw;
  double moved = 0;
  double dy = 0;
  _Drag({required this.start, required this.yaw});
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
          child: Icon(icon, color: NeonPalette.text, size: 24),
        ),
      ),
    );
  }
}
