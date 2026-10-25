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
import '../map/map3d.dart';
import '../theme/tokens.dart';
import 'flow_overlays.dart';
import 'router.dart';

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
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: NeonPalette.text, size: 28),
                  ),
                  const Spacer(),
                  Text('🪙 ${session.state.coins}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 14),
                  Text('★ ${session.totalStars}',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: NeonPalette.star)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0a0a1e),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: hslColor(isl.theme.glow, 90, 62).withValues(alpha: .5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('DÜNYA ${isl.stage + 1}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: hslColor(isl.theme.glow, 90, 70), letterSpacing: 2)),
                      Text(isl.open ? isl.theme.name : '🔒 ${isl.theme.name}',
                          style: Theme.of(context).textTheme.displayMedium),
                      Text(
                        isl.open
                            ? '${isl.done}/$kLevelsPerStage · ★ ${isl.stars}'
                            : '🔒 ${session.totalStars}/${isl.need} yıldız',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: NeonButton('🌍 GÜNLÜK MEYDAN OKUMA', _openDaily),
            ),
          ],
        );
      }),
    );
  }
}

class _Drag {
  Offset start;
  double yaw;
  double moved = 0;
  double dy = 0;
  _Drag({required this.start, required this.yaw});
}
