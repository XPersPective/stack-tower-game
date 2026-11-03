/// DÜĞÜM ÇÖZ — Düğüm (PB-045, DESIGN-20GAMES #20: Untangle / Planarity).
///
/// Zen-bulmaca: çizgiler kesişmesin diye DÜĞÜMLERİ taşı. Tek dokunuş:
/// düğüme dokun (seç) → boş noktaya dokun (oraya taşınır). Kesişim sayısı
/// canlı gösterilir; 0 kesişim = çözüldü → sonraki örgü. Taşma bütçesi
/// bitince kayıp. Örgüler PLANAR üretilir (çözüm var — sabit nokta теoremi).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class KnotNode {
  final int id;
  double x, y;
  KnotNode(this.id, this.x, this.y);
}

class KnotEdge {
  final int a, b;
  const KnotEdge(this.a, this.b);
}

class UntangleGame implements MiniGame {
  @override
  GameKind get kind => GameKind.untangle;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  final List<KnotNode> nodes = [];
  final List<KnotEdge> edges = [];
  int? selected;
  int crossings = 0;
  int _budget = 0;
  int _stage = 0;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0;
  final math.Random _rnd = math.Random();

  @override
  int get score => _score;
  @override
  int get target => _def.target;
  @override
  int get combo => _combo;
  @override
  int get shieldsLeft => _shields;
  @override
  bool get isOver => _over;

  double get boardX => 20 * scale;
  double get boardY => 90 * scale;
  double get boardW => w - 40 * scale;
  double get boardH => h - 240 * scale;

  @override
  void resize(double vw, double vh) {
    w = math.max(300, vw);
    h = math.max(480, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
  }

  @override
  void start(LevelDef def,
      {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    time = 0;
    flash = 0;
    shake = 0;
    _stage = 0;
    _budget = 0;
    _newPuzzle();
    host.playSound('start');
  }

  /// Planar örgü üretimi: rastgele DÜZGÜN çokgen (konveks) + köşegenlerin
  /// kesişmeyen rastgele alt kümesi (triangülasyon dilimi) → çözüm var.
  void _newPuzzle() {
    nodes.clear();
    edges.clear();
    selected = null;
    final n = math.min(9, 5 + (_stage / 2).floor() + _def.speed.round());
    final cx = boardX + boardW / 2;
    final cy = boardY + boardH / 2;
    final radius = math.min(boardW, boardH) / 2 - 20 * scale;
    // düzensiz konveks konum (çözüm çemberi) — oyuncu taşıyınca bozulur
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n + _rnd.nextDouble() * 0.3;
      nodes.add(KnotNode(
          i,
          cx + math.cos(a) * radius * (0.75 + _rnd.nextDouble() * 0.25),
          cy + math.sin(a) * radius * (0.75 + _rnd.nextDouble() * 0.25)));
    }
    // konveks kenarları + kesişmeyen köşegenler
    for (var i = 0; i < n; i++) {
      edges.add(KnotEdge(i, (i + 1) % n));
    }
    final diagCount = 2 + _rnd.nextInt(math.max(1, n - 3));
    var guard = 0;
    var added = 0;
    while (added < diagCount && guard++ < 200) {
      final a = _rnd.nextInt(n), b = _rnd.nextInt(n);
      if ((a - b).abs() < 2 || (a - b).abs() > n - 2) continue;
      final e = KnotEdge(math.min(a, b), math.max(a, b));
      if (edges.any((x) => (x.a == e.a && x.b == e.b))) continue;
      if (edges.any((x) => _segmentsCross(x, e))) continue;
      edges.add(e);
      added++;
    }
    // düğümleri KARIŞTIR (bulanık başlangıç) — ama başlangıçta en fazla birkaç
    // kesişim olsun ki zorluk ölçülü kalsın
    var tries = 0;
    do {
      for (final node in nodes) {
        node.x = boardX + 30 * scale +
            _rnd.nextDouble() * (boardW - 60 * scale);
        node.y = boardY + 30 * scale +
            _rnd.nextDouble() * (boardH - 60 * scale);
      }
      _countCrossings();
      tries++;
    } while (crossings > math.max(2, edges.length ~/ 2) && tries < 60);
    _budget = 12 + n * 2;
  }

  bool _segmentsCross(KnotEdge e1, KnotEdge e2) {
    if (_share(e1, e2)) return false;
    final p1 = nodes[e1.a], p2 = nodes[e1.b];
    final p3 = nodes[e2.a], p4 = nodes[e2.b];
    return _ccw(p1, p3, p2) != _ccw(p1, p4, p2) &&
        _ccw(p3, p1, p4) != _ccw(p3, p2, p4);
  }

  bool _share(KnotEdge e1, KnotEdge e2) =>
      e1.a == e2.a || e1.a == e2.b || e1.b == e2.a || e1.b == e2.b;

  bool _ccw(KnotNode a, KnotNode b, KnotNode c) =>
      (b.y - a.y) * (c.x - a.x) > (b.x - a.x) * (c.y - a.y);

  void _countCrossings() {
    var count = 0;
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        if (_segmentsCross(edges[i], edges[j])) count++;
      }
    }
    crossings = count;
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    // düğüm seçimi (yakın olan)
    KnotNode? best;
    var bestD = 34 * scale;
    for (final node in nodes) {
      final d = (Offset(node.x, node.y) - local).distance;
      if (d < bestD) {
        bestD = d;
        best = node;
      }
    }
    if (best != null) {
      if (selected == best.id) {
        selected = null;
        return;
      }
      selected = best.id;
      _host?.haptic(4);
      _host?.playSound('pop');
      return;
    }
    // taşıma
    if (selected != null) {
      final node = nodes[selected!];
      node.x = local.dx.clamp(boardX + 16 * scale, boardX + boardW - 16 * scale);
      node.y = local.dy.clamp(boardY + 16 * scale, boardY + boardH - 16 * scale);
      _budget--;
      selected = null;
      _host?.haptic(5);
      _host?.playSound('place');
      _countCrossings();
      if (crossings == 0) {
        _solved();
      } else if (_budget <= 0) {
        _over = true;
        _combo = 0;
        _host?.playSound('lose');
        _host?.haptic(50);
        _host?.onEvent('lose', data: {'points': _score});
      }
    }
  }

  void _solved() {
    _score += 10 + _stage * 2;
    _combo++;
    if (_budget > 8) _perfects++;
    _stage++;
    flash = 0.25;
    _host?.playSound('perfect', combo: _combo);
    _host?.haptic(15);
    if (_def.target > 0 && _score >= _def.target) {
      _win();
      return;
    }
    _newPuzzle();
  }

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  /// Test kancaları.
  int get budgetForTest => _budget;
  int get stageForTest => _stage;
  void setBudgetForTest(int n) => _budget = n;

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() =>
      MiniGameResult(points: _score, perfects: _perfects, reached: _reached);

  /* ----------------------------- render ----------------------------- */

  @override
  void render(Canvas canvas, Size size) {
    // ilk kare resize'tan önce gelebilir — w/h=0 iken çizim NaN üretir
    if (w <= 0 || h <= 0) return;
    final theme = _def.theme;
    final bgRect = Offset.zero & size;
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bg1, theme.bg2],
        ).createShader(bgRect),
    );

    canvas.save();
    // kablolar — kesişen kırmızıya döner (L1: sorun tek bakışta)
    for (final e in edges) {
      final a = nodes[e.a];
      final b = nodes[e.b];
      var crossing = false;
      for (final other in edges) {
        if (identical(other, e)) continue;
        if (_segmentsCross(e, other)) {
          crossing = true;
          break;
        }
      }
      canvas.drawLine(
          Offset(a.x, a.y),
          Offset(b.x, b.y),
          Paint()
            ..color = crossing
                ? Colors.redAccent.withValues(alpha: .75)
                : _hsl(theme.glow.toDouble(), 80, 62).withValues(alpha: .8)
            ..strokeWidth = crossing ? 2.4 : 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }

    // düğümler
    for (final node in nodes) {
      final isSel = selected == node.id;
      canvas.drawCircle(
          Offset(node.x, node.y),
          13 * scale,
          Paint()
            ..color = isSel
                ? Colors.white
                : _hsl(theme.glow.toDouble(), 90, 55)
            ..maskFilter = MaskFilter.blur(
                BlurStyle.normal, isSel ? 8 : 4));
      canvas.drawCircle(
          Offset(node.x, node.y),
          13 * scale,
          Paint()
            ..color = Colors.white.withValues(alpha: .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
    }

    // kesişim sayacı + bütçe (tahta altı)
    final tp = TextPainter(
      text: TextSpan(
          text: crossings == 0 ? 'ÇÖZÜLDÜ!' : 'KESİŞİM $crossings',
          style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w900,
              color: crossings == 0
                  ? const Color(0xFFB9FFC9)
                  : crossings < 4
                      ? const Color(0xFFFFE082)
                      : const Color(0xFFFF8A80))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, boardY + boardH + 14));

    // bütçe şeridi
    final maxB = 12.0 + (5 + (_stage / 2).floor() + _def.speed.round()) * 2;
    final bw = boardW * (_budget / maxB).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(boardX, boardY + boardH + 40, boardW, 5),
          const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: .1),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(boardX, boardY + boardH + 40, bw, 5),
          const Radius.circular(3)),
      Paint()
        ..color = _hsl(theme.glow.toDouble(), 90, 62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.restore();
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
