/// Stack Tower Game — 3B takımada haritası (map.js birebir portu).
/// Orbit kamera (yatay sürükle), dünya geçişi (dikey sürükle), gezegen adalar,
/// sarmal yükseliş yolu, biten bölümle büyüyen köy, günlük adası.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_session.dart';
import '../game/levels.dart';
import '../game/progress.dart' as prog;
import '../game/scene_painter.dart' show hslColor;
import 'construction.dart';
import '../theme/tokens.dart';

/* ------------------------------ sahne modeli ------------------------------ */

const double kMapFov = 52 * math.pi / 180;
const Offset3 kUp = Offset3(0, 1, 0);

class Offset3 {
  final double x, y, z;
  const Offset3(this.x, this.y, this.z);
}

class MapIsland {
  final int stage;
  final double x, y, z, r, thick;
  final WorldTheme theme;
  final int seed;
  int done;
  int stars;
  bool open;
  final int need;
  List<MapNode> nodes = [];
  List<MapItem> items = [];
  Offset? center; // ekran izdüşümü (hit-test)
  Offset? marketScreen; // PB-018: pazar binası ekran izdüşümü (hit-test)
  double marketR = 0;
  bool get hasMarket => done >= 3; // 3 bölüm bitince pazar kurulur

  MapIsland({
    required this.stage,
    required this.x,
    required this.y,
    required this.z,
    required this.r,
    required this.thick,
    required this.theme,
    required this.seed,
    required this.done,
    required this.stars,
    required this.open,
    required this.need,
  });
}

class MapItem {
  final String type; // building | decor
  final double x, y, z, h, w;
  final int hue;
  MapItem(this.type, this.x, this.y, this.z, this.h, this.w, this.hue);
}

class MapNode {
  final int i;
  final LevelDef def;
  final MapIsland isl;
  final double a;
  final double x, y, z;
  final bool done;
  final int stars;
  final bool unlocked;
  final bool box;
  bool current;
  Offset? screen;
  double screenR = 0;

  MapNode({
    required this.i,
    required this.def,
    required this.isl,
    required this.a,
    required this.x,
    required this.y,
    required this.z,
    required this.done,
    required this.stars,
    required this.unlocked,
    required this.box,
    this.current = false,
  });
}

/// Yüzey yüksekliği (map.js surfY birebir).
double surfY(MapIsland isl, double x, double z) {
  final R = isl.r;
  final dx = x - isl.x, dz = z - isl.z;
  final d = math.min(R, math.sqrt(dx * dx + dz * dz));
  return isl.y - R + math.sqrt(math.max(0, R * R - d * d));
}

double hashF(double n) {
  final x = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

/// Sahne kurulumu (map.js layout birebir).
class MapScene {
  final List<MapIsland> islands = [];
  final List<MapNode> nodes = [];
  final GameSession session;
  int focusStage;
  MapIsland? dailyIsland;

  final int? _initialFocus;

  /// PB-029: haritada en son yükselen parça — 1.2s ease-out yükselme animasyonu.
  int? riseIdx;
  double riseT = 1;

  MapScene(this.session, {int? initialFocus}) : _initialFocus = initialFocus, focusStage = initialFocus ?? 0 {
    rebuild();
  }

  /// [levelIdx] parçası haritada yükselsin (bölüm bitiminden sonra çağrılır).
  void startRise(int levelIdx) {
    riseIdx = levelIdx;
    riseT = 0;
  }

  void updateRise(double dt) {
    if (riseT >= 1) return;
    riseT = math.min(1, riseT + dt / 1.2); // spec: 1.2s
  }

  void rebuild() {
    islands.clear();
    nodes.clear();
    final save = session.state;
    final per = kLevelsPerStage;

    for (var s = 0; s < kStageCount; s++) {
      final ang = -1.15 + s * 0.72;
      final rad = 120.0 + (s % 3) * 46.0;
      var doneCount = 0, starSum = 0;
      for (var k = 0; k < per; k++) {
        final cm = save.completed[s * per + k];
        if (cm != null) {
          doneCount++;
          starSum += cm['stars'] ?? 0;
        }
      }
      final isl = MapIsland(
        stage: s,
        x: math.sin(ang) * rad,
        y: s * 1350.0,
        z: math.cos(ang) * rad,
        r: 330,
        thick: 205,
        theme: kThemes[s],
        seed: 13 + s * 37,
        done: doneCount,
        stars: starSum,
        open: s == 0 || session.totalStars >= requiredStars(s),
        need: requiredStars(s),
      );
      _buildItems(isl);
      islands.add(isl);
    }

    for (var i = 0; i < kLevelCount; i++) {
      final d = levelDef(i);
      final host = islands[d.stage];
      final u = d.idx / (per - 1);
      final a = 0.5 + u * math.pi * 2 * 1.7 + d.stage * 0.37;
      final ring = host.r * (0.70 - u * 0.47);
      final nx = host.x + math.cos(a) * ring;
      final nz = host.z + math.sin(a) * ring;
      final nd = MapNode(
        i: i,
        def: d,
        isl: host,
        a: a,
        x: nx,
        y: surfY(host, nx, nz) + 3,
        z: nz,
        done: save.completed[i] != null,
        stars: save.completed[i]?['stars'] ?? 0,
        unlocked: prog.isUnlocked(save, i, d),
        box: d.box && save.boxes[i.toString()] != true,
      );
      nodes.add(nd);
      host.nodes.add(nd);
    }

    var cur = -1;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].unlocked && !nodes[i].done) {
        cur = i;
        break;
      }
    }
    if (cur >= 0) nodes[cur].current = true;

    focusStage = (_initialFocus ?? (cur >= 0 ? nodes[cur].isl.stage : kStageCount - 1))
        .clamp(0, kStageCount - 1);
    _updateDaily();
  }

  void _buildItems(MapIsland isl) {
    final per = kLevelsPerStage;
    final items = <MapItem>[];
    // köy: bitirilen her bölüm yolun kenarında yeni bir bina açar
    for (var b = 0; b < isl.done && b < per; b++) {
      final u = b / (per - 1);
      final a = 0.5 + u * math.pi * 2 * 1.7 + isl.stage * 0.37 + 0.25;
      final rad = isl.r * (0.70 - u * 0.47);
      final bx = isl.x + math.cos(a) * rad;
      final bz = isl.z + math.sin(a) * rad;
      items.add(MapItem(
        'building',
        bx + math.cos(a + 1.4) * 26,
        surfY(isl, bx, bz) + 2,
        bz + math.sin(a + 1.4) * 26,
        26.0 + ((b * 13) % 42),
        12.0 + ((b * 7) % 9),
        (isl.theme.glow + b * 9) % 360,
      ));
    }
    // doğa: ağaçlar / kristaller
    for (var d = 0; d < 20; d++) {
      final da = hashF(d * 7.0 + isl.seed) * math.pi * 2;
      final dr = isl.r * (0.20 + hashF(d * 13.0 + isl.seed) * 0.62);
      final dx = isl.x + math.cos(da) * dr;
      final dz = isl.z + math.sin(da) * dr;
      items.add(MapItem(
        'decor',
        dx,
        surfY(isl, dx, dz) + 1,
        dz,
        9.0 + ((d * 13) % 21),
        0,
        (isl.theme.hues[d % 3] + 8) % 360,
      ));
    }
    isl.items = items;
  }

  void _updateDaily() {
    final isl = islands.isEmpty ? null : islands[focusStage];
    if (isl == null) {
      dailyIsland = null;
      return;
    }
    dailyIsland = isl;
  }

  void setFocus(int stage) {
    focusStage = stage.clamp(0, kStageCount - 1);
    _updateDaily();
  }
}

/* ------------------------------ kamera ------------------------------ */

class MapCamera {
  double yaw = 0.55, pitch = 0.60, dist = 1420;
  Offset3 focus = const Offset3(0, 0, 0);
  double focal = 800;
  double w = 0, h = 0;
  Offset3 _eye = const Offset3(0, 0, 0);
  Offset3 _fwd = const Offset3(0, 0, 1);
  Offset3 _right = const Offset3(1, 0, 0);
  Offset3 _up = const Offset3(0, 1, 0);

  void update(MapScene scene, double dt, {required bool snap}) {
    final isl = scene.islands.isEmpty ? null : scene.islands[scene.focusStage];
    if (isl == null) return;
    final target = Offset3(isl.x, isl.y - isl.r * 0.58, isl.z);
    final k = snap ? 1.0 : math.min(1, math.max(0.02, dt * 5));
    focus = Offset3(
      focus.x + (target.x - focus.x) * k,
      focus.y + (target.y - focus.y) * k,
      focus.z + (target.z - focus.z) * k,
    );

    final cp = math.cos(pitch), sp = math.sin(pitch);
    _eye = Offset3(
      focus.x + math.sin(yaw) * cp * dist,
      focus.y + sp * dist,
      focus.z + math.cos(yaw) * cp * dist,
    );

    final fx = focus.x - _eye.x, fy = focus.y - _eye.y, fz = focus.z - _eye.z;
    final fl = math.sqrt(fx * fx + fy * fy + fz * fz).clamp(1.0, double.infinity);
    _fwd = Offset3(fx / fl, fy / fl, fz / fl);
    final rx = -_fwd.z, rz = _fwd.x;
    final rl = math.sqrt(rx * rx + rz * rz).clamp(1.0, double.infinity);
    _right = Offset3(rx / rl, 0, rz / rl);
    _up = Offset3(
      _right.y * _fwd.z - _right.z * _fwd.y,
      _right.z * _fwd.x - _right.x * _fwd.z,
      _right.x * _fwd.y - _right.y * _fwd.x,
    );
    focal = (h * 0.5) / math.tan(kMapFov / 2);
  }

  /// Ekran izdüşümü (map.js project birebir); z<70 → null.
  ({double x, double y, double s, double z})? project(Offset3 p) {
    final dx = p.x - _eye.x, dy = p.y - _eye.y, dz = p.z - _eye.z;
    final z = dx * _fwd.x + dy * _fwd.y + dz * _fwd.z;
    if (z < 70) return null;
    final s = focal / z;
    return (
      x: w * 0.5 + (dx * _right.x + dy * _right.y + dz * _right.z) * s,
      y: h * 0.5 - (dx * _up.x + dy * _up.y + dz * _up.z) * s,
      s: s,
      z: z,
    );
  }

  double depthOf(Offset3 p) {
    final dx = p.x - _eye.x, dy = p.y - _eye.y, dz = p.z - _eye.z;
    return dx * _fwd.x + dy * _fwd.y + dz * _fwd.z;
  }
}

/* ------------------------------ painter ------------------------------ */

/// Ticker'ın painter'ı her karede tetiklemesi için Listenable köprüsü.
class MapRepaint extends ChangeNotifier {
  void notify() => notifyListeners();
}

class MapScenePainter extends CustomPainter {
  MapScenePainter(this.scene, this.camera, this.time, {required Listenable repaint})
      : super(repaint: repaint);
  final MapScene scene;
  final MapCamera camera;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (scene.islands.isEmpty) return;
    camera.w = size.width;
    camera.h = size.height;
    final isl = scene.islands[scene.focusStage];

    _drawSky(canvas, size, isl);
    _drawHorizonClouds(canvas, size, isl);
    _drawFarRocks(canvas, size, isl);
    _drawIslands(canvas, size);
    _drawNodes(canvas, size);
    _drawDaily(canvas, size);
    _drawForeground(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size, MapIsland isl) {
    final theme = isl.theme;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.bg1, theme.bg2, hslColor(theme.glow, 40, 10)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    // yıldızlar (deterministik)
    for (var i = 0; i < 90; i++) {
      final r = hashF(i * 3.7 + 1);
      final r2 = hashF(i * 7.1 + 2);
      final tw = 0.25 + 0.5 * (0.5 + 0.5 * math.sin(time * (0.5 + r) + i));
      canvas.drawCircle(
        Offset(r * size.width, r2 * size.height * 0.7),
        0.6 + r2 * 1.3,
        Paint()..color = Colors.white.withValues(alpha: tw * 0.7),
      );
    }
  }

  void _drawHorizonClouds(Canvas canvas, Size size, MapIsland isl) {
    final glow = hslColor(isl.theme.glow, 60, 60);
    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.55 + (i % 3) * 0.08) +
          math.sin(time * 0.1 + i) * 6;
      final w = size.width * (0.5 + hashF(i * 3.3) * 0.5);
      final x = size.width * hashF(i * 5.1) + math.sin(time * 0.05 + i * 2) * 20;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.16),
        Paint()
          ..color = glow.withValues(alpha: 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }
  }

  void _drawFarRocks(Canvas canvas, Size size, MapIsland isl) {
    final glow = hslColor(isl.theme.glow, 45, 22);
    for (var i = 0; i < 4; i++) {
      final proj = camera.project(Offset3(
        isl.x + math.sin(hashF(i * 9.7) * 6.28) * 900,
        isl.y - 220 + hashF(i * 3.9) * 300,
        isl.z + math.cos(hashF(i * 9.7) * 6.28) * 900,
      ));
      if (proj == null) continue;
      final r = proj.s * (60 + hashF(i * 5.3) * 70);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(proj.x, proj.y), width: r * 2, height: r * 0.8),
        Paint()..color = glow.withValues(alpha: 0.5),
      );
    }
  }

  void _drawIslands(Canvas canvas, Size size) {
    // kameradan uzağa göre sırala (uzak önce)
    final sorted = [...scene.islands]..sort(
        (a, b) => camera.depthOf(Offset3(b.x, b.y, b.z))
            .compareTo(camera.depthOf(Offset3(a.x, a.y, a.z))),
      );
    for (final isl in sorted) {
      _drawIsland(canvas, isl);
    }
  }

  void _drawIsland(Canvas canvas, MapIsland isl) {
    final theme = isl.theme;
    final glow = hslColor(theme.glow, 85, 62);
    const n = 28;
    final rimTop = <Offset?>[];
    final rimBot = <Offset?>[];
    // rimBot yalnız koni path'i için kullanılır
    double? cyTop, cx;
    var minTopY = double.infinity, maxBotY = double.negativeInfinity;
    for (var k = 0; k < n; k++) {
      final a = k / n * math.pi * 2;
      final rr2 = isl.r * (0.96 + 0.025 * math.sin(a * 3 + isl.seed * 0.7));
      final depth = isl.thick * (0.7 + 0.35 * math.sin(a * 2 + isl.seed * 1.3));
      final top = Offset3(isl.x + math.cos(a) * rr2, isl.y - isl.r, isl.z + math.sin(a) * rr2);
      final bot = Offset3(
        isl.x + math.cos(a) * rr2 * 0.70,
        isl.y - isl.r - depth,
        isl.z + math.sin(a) * rr2 * 0.70,
      );
      final pt = camera.project(top);
      final pb = camera.project(bot);
      rimTop.add(pt == null ? null : Offset(pt.x, pt.y));
      rimBot.add(pb == null ? null : Offset(pb.x, pb.y));
      if (pt != null) {
        cyTop ??= pt.y;
        minTopY = math.min(minTopY, pt.y);
        cx ??= pt.x;
      }
      // bot noktaları path'te kullanılıyor
      if (pb != null) maxBotY = math.max(maxBotY, pb.y);
    }
    if (cyTop == null || cx == null) {
      isl.center = null;
      return;
    }
    final topProj = camera.project(Offset3(isl.x, isl.y - isl.r, isl.z));
    if (topProj == null) {
      isl.center = null;
      return;
    }
    final s = topProj.s;
    isl.center = Offset(topProj.x, topProj.y);
    final rScreen = isl.r * s;

    // aura
    canvas.drawCircle(
      Offset(topProj.x, topProj.y),
      rScreen * 1.25,
      Paint()
        ..color = glow.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, rScreen * 0.3)),
    );

    // alt koni (tip)
    final tip = camera.project(Offset3(isl.x, isl.y - isl.r - isl.thick - 190, isl.z));
    final sidePath = Path();
    var started = false;
    for (var k = 0; k <= n; k++) {
      final p = rimBot[k % n];
      if (p == null) continue;
      started ? sidePath.lineTo(p.dx, p.dy) : sidePath.moveTo(p.dx, p.dy);
      started = true;
    }
    if (tip != null && started) sidePath.lineTo(tip.x, tip.y);
    sidePath.close();
    canvas.drawPath(
      sidePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            hslColor(theme.glow, 42, 16),
            hslColor(theme.glow, 40, 7),
          ],
        ).createShader(Rect.fromLTRB(topProj.x - rScreen, maxBotY, topProj.x + rScreen, tip?.y ?? maxBotY)),
    );

    // üst yüzey: rim diski + küre kubbesi (surfY'un balonlaşması) birleşimi
    final topPath = Path();
    started = false;
    for (var k = 0; k <= n; k++) {
      final p = rimTop[k % n];
      if (p == null) continue;
      started ? topPath.lineTo(p.dx, p.dy) : topPath.moveTo(p.dx, p.dy);
      started = true;
    }
    topPath.close();
    canvas.drawPath(
      topPath,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            hslColor(theme.glow, 30, 22),
            hslColor(theme.glow, 32, 14),
          ],
        ).createShader(Rect.fromCircle(center: Offset(topProj.x, topProj.y), radius: rScreen)),
    );
    // kubbe: küre silüet çemberi ∩ ekvator üstü yarısı (surfY balonlaşması)
    final sphereC = Offset3(isl.x, isl.y - isl.r, isl.z);
    final cs = camera.project(sphereC);
    if (cs != null) {
      final distC = camera.depthOf(sphereC).abs();
      final apparentR =
          camera.focal * isl.r / math.sqrt(math.max(1.0, distC * distC - isl.r * isl.r));
      final upP = camera.project(Offset3(sphereC.x, sphereC.y + 100, sphereC.z));
      if (upP != null) {
        var ux = upP.x - cs.x, uy = upP.y - cs.y;
        final ul = math.sqrt(ux * ux + uy * uy).clamp(0.001, double.infinity);
        ux /= ul;
        uy /= ul;
        // üst yarı-düzlem: cs'den dik iki uç + up yönünde iki uç
        final big = 9999.0;
        final region = Path()
          ..moveTo(cs.x - uy * big, cs.y + ux * big)
          ..lineTo(cs.x + uy * big, cs.y - ux * big)
          ..lineTo(cs.x + uy * big + ux * big, cs.y - ux * big + uy * big)
          ..lineTo(cs.x - uy * big + ux * big, cs.y + ux * big + uy * big)
          ..close();
        canvas.save();
        canvas.clipPath(region);
        canvas.drawCircle(
          Offset(cs.x, cs.y),
          apparentR,
          Paint()
            ..shader = RadialGradient(
              colors: [
                hslColor(theme.glow, 34, 22),
                hslColor(theme.glow, 32, 13),
              ],
            ).createShader(Rect.fromCircle(center: Offset(cs.x, cs.y), radius: apparentR)),
        );
        canvas.restore();
      }
    }

    // köy binaları + dekor (öndekiler sonra)
    final itemsSorted = [...isl.items]
      ..sort((a, b) => camera.depthOf(Offset3(b.x, b.y, b.z))
          .compareTo(camera.depthOf(Offset3(a.x, a.y, a.z))));
    for (final it in itemsSorted) {
      final p = camera.project(Offset3(it.x, it.y, it.z));
      if (p == null) continue;
      if (it.type == 'building') {
        final bw = it.w * p.s;
        final bh2 = it.h * p.s;
        canvas.drawRect(
          Rect.fromLTWH(p.x - bw / 2, p.y - bh2, bw, bh2),
          Paint()..color = hslColor(it.hue, 70, 40),
        );
        canvas.drawRect(
          Rect.fromLTWH(p.x - bw / 2, p.y - bh2, bw, math.max(1.0, 2 * p.s)),
          Paint()..color = hslColor(it.hue, 90, 68),
        );
        // pencere ışıkları
        canvas.drawRect(
          Rect.fromLTWH(p.x - bw * 0.15, p.y - bh2 * 0.62, bw * 0.3, bh2 * 0.22),
          Paint()..color = const Color(0x66FFE2A0),
        );
      } else {
        final h2 = it.h * p.s;
        final path = Path()
          ..moveTo(p.x, p.y)
          ..lineTo(p.x + h2 * 0.22, p.y - h2)
          ..lineTo(p.x + h2 * 0.44, p.y)
          ..close();
        canvas.drawPath(path, Paint()..color = hslColor(it.hue, 60, 30));
      }
    }

    // GÖRÜNÜR İNŞAAT (ADR-009): tamamlanan bölümler yapı yükseltir
    _drawStructures(canvas, isl);
    // PB-018: pazar yeri binası (3+ bölüm bitmiş adalarda)
    _drawMarket(canvas, isl);
  }

  /// PB-018: pazar yeri — ışıklı tezgah, dokunulabilir (hitTest 'market').
  void _drawMarket(Canvas canvas, MapIsland isl) {
    if (!isl.hasMarket) {
      isl.marketScreen = null;
      return;
    }
    // ada merkezinin sağ-alt köşesi (yapıların uzağı)
    final wx = isl.x + isl.r * 0.52;
    final wz = isl.z + isl.r * 0.30;
    final wy = surfY(isl, wx, wz);
    final p = camera.project(Offset3(wx, wy, wz));
    if (p == null) {
      isl.marketScreen = null;
      return;
    }
    final s = p.s;
    final w = 54 * s, h = 30 * s;
    final base = Offset(p.x, p.y);
    isl.marketScreen = base;
    isl.marketR = math.max(26.0, 34 * s);

    // gölge
    canvas.drawOval(
        Rect.fromCenter(center: base, width: w * 1.15, height: h * 0.34),
        Paint()..color = Colors.black.withValues(alpha: .35));
    // tezgah gövdesi
    canvas.drawRect(Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h),
        Paint()..color = hslColor(isl.theme.glow, 40, 22));
    // çizgili tente
    const stripes = 4;
    for (var i = 0; i < stripes; i++) {
      final sx = base.dx - w / 2 + (w / stripes) * i;
      canvas.drawRect(
          Rect.fromLTWH(sx, base.dy - h - 9 * s, w / stripes, 9 * s),
          Paint()
            ..color = i.isEven
                ? hslColor(isl.theme.glow, 90, 62)
                : const Color(0xFFEFE7D2));
    }
    // sıcak fener
    canvas.drawCircle(
        Offset(base.dx, base.dy - h - 13 * s),
        7 * s,
        Paint()
          ..color = const Color(0xFFFFD98A).withValues(alpha: .5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, 8 * s)));
    canvas.drawCircle(Offset(base.dx, base.dy - h - 13 * s), 2.6 * s,
        Paint()..color = const Color(0xFFFFE9A8));
    // PB-021: keşif parıltısı — ilk alışverişe kadar tezgah nabız gibi parlar
    if (scene.session.state.marketBought.isEmpty) {
      final pulse = 0.55 + 0.45 * math.sin(time * 3.2);
      canvas.drawCircle(
          Offset(base.dx, base.dy - h * 0.5),
          (26 + 10 * pulse) * s,
          Paint()
            ..color = hslColor(isl.theme.glow, 95, 72)
                .withValues(alpha: .18 + .18 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 * s);
    }
    // "PAZAR" işareti (metin yerine üç nokta — font maliyeti yok)
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset(base.dx - 6 * s + i * 6 * s, base.dy - h * 0.55),
          1.5 * s,
          Paint()..color = hslColor(isl.theme.glow, 95, 78));
    }
  }

  void _drawStructures(Canvas canvas, MapIsland isl) {
    final save = scene.session.state;
    final nextIdx = nextBuildIdx(save, isl.stage);
    for (var si = 0; si < kWorldStructures.length; si++) {
      final built = piecesBuilt(save, isl.stage, si);
      final spec = kWorldStructures[si];
      final pl = placementFor(si);
      final wx = isl.x + math.cos(pl.angle) * isl.r * pl.radiusFactor;
      final wz = isl.z + math.sin(pl.angle) * isl.r * pl.radiusFactor;
      final wy = surfY(isl, wx, wz);
      final p = camera.project(Offset3(wx, wy, wz));
      if (p == null) continue;
      final s = p.s * pl.heightScale;
      final baseW = 46 * s;
      final unitH = 30 * s;

      if (built == 0) {
        // blueprint: sıradaki yapının silüeti (merak)
        final isNext = nextIdx != null && slotOf(nextIdx).structure == si;
        final bp = Paint()
          ..color = (isNext ? hslColor(isl.theme.glow, 90, 70) : Colors.white)
              .withValues(alpha: isNext ? 0.42 : 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, 1.6 * s);
        final h3 = spec.pieces.length * unitH;
        canvas.drawRect(
            Rect.fromLTWH(p.x - baseW / 2, p.y - h3, baseW, h3), bp);
        canvas.drawLine(Offset(p.x - baseW / 2, p.y - h3),
            Offset(p.x + baseW / 2, p.y), bp);
        canvas.drawLine(Offset(p.x + baseW / 2, p.y - h3),
            Offset(p.x - baseW / 2, p.y), bp);
        continue;
      }

      // inşa edilen parçalar (alttan üste)
      final riseSlot = scene.riseIdx == null ? null : slotOf(scene.riseIdx!);
      for (var k = 0; k < built; k++) {
        // PB-029: en son parça haritada 1.2s ease-out ile yükselir
        final rising = riseSlot != null &&
            riseSlot.structure == si &&
            riseSlot.piece == k &&
            scene.riseT < 1;
        final grow = rising ? _easeOutCubic(scene.riseT) : 1.0;
        final pieceH = unitH * 0.92 * grow;
        final yTop = p.y - (k + 1) * unitH + (unitH * 0.92 - pieceH);
        final shrink = 1.0 - k * 0.12;
        final rect = Rect.fromLTWH(
            p.x - baseW * shrink / 2, yTop, baseW * shrink, pieceH);
        canvas.drawRect(rect, Paint()..color = hslColor(isl.theme.glow, 55, 26 + k * 8));
        canvas.drawRect(
            rect,
            Paint()
              ..color = hslColor(isl.theme.glow, 95, 70).withValues(alpha: .75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.8, 1.2 * s));
      }
      // PB-029: yükselme sırasında parıltı (tam 1.2s)
      if (riseSlot != null && riseSlot.structure == si && scene.riseT < 1) {
        final k = riseSlot.piece;
        final topY = p.y - (k + 1) * unitH;
        canvas.drawCircle(
            Offset(p.x, topY + unitH * 0.5),
            18 * s * (1 - scene.riseT * 0.4),
            Paint()
              ..color = hslColor(isl.theme.glow, 100, 85)
                  .withValues(alpha: .45 * (1 - scene.riseT))
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, 8 * s)));
      }
      // yapı tamamlandıysa tepe ışığı
      if (built == spec.pieces.length) {
        final topY = p.y - built * unitH;
        canvas.drawCircle(
            Offset(p.x, topY - 6 * s),
            9 * s,
            Paint()
              ..color = hslColor(isl.theme.glow, 95, 70).withValues(alpha: .22)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, 10 * s)));
        canvas.drawCircle(Offset(p.x, topY - 6 * s), 3.4 * s,
            Paint()..color = hslColor(isl.theme.glow, 100, 82));
      }
    }
  }

  static double _easeOutCubic(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }

  void _drawNodes(Canvas canvas, Size size) {
    final sorted = [...scene.nodes]..sort((a, b) => camera
        .depthOf(Offset3(b.x, b.y, b.z))
        .compareTo(camera.depthOf(Offset3(a.x, a.y, a.z))));
    for (final nd in sorted) {
      final p = camera.project(Offset3(nd.x, nd.y, nd.z));
      if (p == null) {
        nd.screen = null;
        continue;
      }
      final r = math.max(7.0, p.s * 26);
      nd.screen = Offset(p.x, p.y);
      nd.screenR = r;

      final glow = hslColor(nd.isl.theme.glow, 90, 62);
      final color = nd.done
          ? glow
          : nd.unlocked
              ? NeonPalette.cyan
              : Colors.white24;
      // halo (current pulse)
      if (nd.current) {
        final pulse = 1 + 0.18 * math.sin(time * 3);
        canvas.drawCircle(
          Offset(p.x, p.y),
          r * 1.7 * pulse,
          Paint()
            ..color = NeonPalette.cyan.withValues(alpha: 0.28)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, r * 0.8)),
        );
      }
      canvas.drawCircle(Offset(p.x, p.y), r, Paint()..color = color.withValues(alpha: 0.10));
      canvas.drawCircle(
        Offset(p.x, p.y),
        r,
        Paint()
          ..color = nd.unlocked ? color : Colors.white10
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, r * 0.16),
      );
      if (nd.done) {
        // dolu çekirdek + yıldız puantiyeleri
        canvas.drawCircle(Offset(p.x, p.y), r * 0.42, Paint()..color = glow);
      } else if (nd.unlocked) {
        canvas.drawCircle(Offset(p.x, p.y), r * 0.28, Paint()..color = NeonPalette.cyan);
      } else {
        // kilit ikizi (metinle de okunur — accessibility)
        canvas.drawLine(Offset(p.x - r * 0.25, p.y - r * 0.1),
            Offset(p.x - r * 0.25, p.y + r * 0.28), Paint()..color = Colors.white54..strokeWidth = 1.6);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(p.x - r * 0.25, p.y - r * 0.12), radius: r * 0.16),
          math.pi,
          math.pi,
          false,
          Paint()..color = Colors.white54..style = PaintingStyle.stroke..strokeWidth = 1.6,
        );
      }
      if (nd.box) {
        canvas.drawCircle(
          Offset(p.x + r * 0.9, p.y - r * 0.9),
          r * 0.3,
          Paint()..color = NeonPalette.gold,
        );
      }
    }
  }

  void _drawDaily(Canvas canvas, Size size) {
    final isl = scene.islands[scene.focusStage];
    final dy = isl.y + isl.r * 0.55;
    final p = camera.project(Offset3(isl.x, dy, isl.z));
    if (p == null) return;
    final r = p.s * 60;
    canvas.drawCircle(
      Offset(p.x, p.y),
      r,
      Paint()
        ..shader = const RadialGradient(colors: [
          Color(0x8046E6FF),
          Color(0x1FFF5ED2),
        ]).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    );
    canvas.drawCircle(
      Offset(p.x, p.y),
      r,
      Paint()
        ..color = NeonPalette.cyan.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 🌍 yerine nöon çember + "GÜNLÜK" etiketi yok — dokunma alanı günlük düğmesiyle
    canvas.drawCircle(Offset(p.x, p.y), r * 0.45, Paint()..color = NeonPalette.gold.withValues(alpha: 0.9));
  }

  void _drawForeground(Canvas canvas, Size size) {
    // alt bulut denizi
    final g = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0x0006040f), const Color(0xB806040f)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.86, size.width, size.height * 0.14));
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.86, size.width, size.height * 0.14), g);
  }

  @override
  bool shouldRepaint(covariant MapScenePainter oldDelegate) => true;
}

/// Dokunma testi (map.js hit birebir): düğümler → günlük → ada.
String? hitTest(MapScene scene, Offset px) {
  // PB-018: pazar binası düğümlerden önce denenir
  final isl = scene.islands.isEmpty ? null : scene.islands[scene.focusStage];
  final mk = isl?.marketScreen;
  if (isl != null && mk != null && (px - mk).distance <= isl.marketR) {
    return 'market';
  }
  MapNode? best;
  var bestD = double.infinity;
  for (final nd in scene.nodes) {
    final s = nd.screen;
    if (s == null) continue;
    final d = (px - s).distance;
    if (d < nd.screenR && d < bestD) {
      bestD = d;
      best = nd;
    }
  }
  if (best != null) {
    if (best.isl.stage != scene.focusStage) scene.setFocus(best.isl.stage);
    return 'node:${best.i}';
  }
  return 'none';
}
