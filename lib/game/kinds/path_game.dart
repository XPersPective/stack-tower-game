/// PATH — Tek Çizgi (DESIGN-V2 §3.1 tür 6, draw-line fiili).
/// Tek girdi: sırayla düğümlere dokun. Amaç tüm ÇİZGİLERİ tam bir kez geçmek
/// (Euler yolu). Yanlış düğüm → kalkan gider; kalkan yoksa kayıp.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class PathNode {
  final int id;

  /// Izgara koordinatı (0..2) — ekran koordinatına layout'ta çevrilir.
  final double gc, gr;
  double x = 0, y = 0;
  PathNode(this.id, this.gc, this.gr);
}

class PathEdge {
  final int a, b;
  bool traced;
  PathEdge(this.a, this.b) : traced = false;
}

class PathGame implements MiniGame {
  @override
  GameKind get kind => GameKind.path;

  /// [rng] yalnızca testlerde tohumlamak için; oyunda varsayılan rastgele.
  PathGame([math.Random? rng]) : _rng = rng ?? math.Random();

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  final List<PathNode> nodes = [];
  final List<PathEdge> edges = [];
  int? current; // son dokunulan düğüm
  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false, _reached = false;
  double time = 0, shake = 0, flash = 0;
  final List<int> trace = [];
  final math.Random _rng;
  final List<int> _solution = [];

  @override
  int get score => _score;
  @override
  int get target => edges.isEmpty ? 0 : _totalEdges;
  @override
  int get combo => _combo;
  @override
  int get shieldsLeft => _shields;
  @override
  bool get isOver => _over;

  late int _totalEdges;

  /* ---- test kancaları ---- */
  @visibleForTesting
  List<PathNode> get nodesForTest => nodes;
  @visibleForTesting
  List<PathEdge> get edgesForTest => edges;
  @visibleForTesting
  int? get currentForTest => current;
  @visibleForTesting
  int get tracedCount => edges.where((e) => e.traced).length;
  @visibleForTesting
  List<int> get solutionForTest => List.unmodifiable(_solution);
  @visibleForTesting
  void tapNodeForTest(int id) => _tapNode(id);

  @override
  void resize(double vw, double vh) {
    w = math.max(320, vw);
    h = math.max(400, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    _layout();
  }

  @override
  void start(LevelDef def, {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    time = 0;
    shake = 0;
    flash = 0;
    current = null;
    trace.clear();
    _buildGraph();
    _layout();
    host.playSound('start');
  }

  /// Graf üretimi — yürüyüş-önce: rastgele bir yürüyüşün (her kenarı en çok
  /// bir kez geçen yol) ilk `target` kenarı kenar kümesi olur. Bir yürüyüşün
  /// kenar kümesinde tek dereceli düğüm yalnızca iki ucunda olabilir, dolayı-
  /// sıyla üretilen graf daima bağlıdır ve Euler yolu içerir (tanık: yürüyüşün
  /// kendisi). Böylece hiçbir aşamada kazanılamaz tahta çıkmaz.
  void _buildGraph() {
    nodes.clear();
    edges.clear();
    _solution.clear();
    // 3x3 ızgara düğümleri (dokunulabilir boyut)
    var id = 0;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        nodes.add(PathNode(id++, c.toDouble(), r.toDouble()));
      }
    }
    // aday kenarlar: yatay + dikey + merkez-köşe çaprazları
    final cand = <PathEdge>[];
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final i = r * 3 + c;
        if (c < 2) cand.add(PathEdge(i, i + 1));
        if (r < 2) cand.add(PathEdge(i, i + 3));
      }
    }
    for (final d in const [
      [0, 4],
      [4, 8],
      [2, 4],
      [4, 6]
    ]) {
      cand.add(PathEdge(d[0], d[1]));
    }
    final target = (6 + _def.stage).clamp(6, 10);
    List<int>? trail;
    for (var attempt = 0; attempt < 120 && trail == null; attempt++) {
      trail = _randomTrail(cand, target);
    }
    trail ??= _fallbackTrail(target);
    for (var i = 0; i + 1 < trail.length; i++) {
      final a = trail[i], b = trail[i + 1];
      for (final e in cand) {
        if ((e.a == a && e.b == b) || (e.a == b && e.b == a)) {
          edges.add(e);
          break;
        }
      }
    }
    _solution.addAll(trail);
    _totalEdges = edges.length;
  }

  /// Rastgele yürüyüş: hedef kenar sayısına ulaşmadan tıkanırsa null.
  List<int>? _randomTrail(List<PathEdge> cand, int target) {
    final used = <int>{};
    final seq = <int>[_rng.nextInt(nodes.length)];
    while (used.length < target) {
      final c = seq.last;
      final options = <int>[
        for (var i = 0; i < cand.length; i++)
          if (!used.contains(i) && (cand[i].a == c || cand[i].b == c)) i
      ];
      if (options.isEmpty) return null;
      final i = options[_rng.nextInt(options.length)];
      used.add(i);
      seq.add(cand[i].a == c ? cand[i].b : cand[i].a);
    }
    return seq;
  }

  /// El yapımı güvenli yürüyüş (rastgele denemeler tükenirse): 10 kenarlık
  /// geçerli bir yol; ihtiyaç kadar öneki kullanılır.
  static const _fallbackWalk = [1, 2, 5, 8, 7, 4, 6, 3, 0, 4, 2];
  List<int> _fallbackTrail(int target) =>
      _fallbackWalk.sublist(0, target + 1);

  void _layout() {
    if (nodes.isEmpty) return;
    final board = math.min(w * 0.8, h * 0.46);
    final left = (w - board) / 2;
    final top = h * 0.26;
    final step = board / 2;
    for (final n in nodes) {
      n.x = left + n.gc * step + step / 2;
      n.y = top + n.gr * step + step / 2;
    }
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    // en yakın düğümü bul (dokunma toleransı)
    int? best;
    var bestD = 46 * scale;
    for (final n in nodes) {
      final d = math.sqrt((n.x - local.dx) * (n.x - local.dx) +
          (n.y - local.dy) * (n.y - local.dy));
      if (d < bestD) {
        bestD = d;
        best = n.id;
      }
    }
    if (best == null) return;
    _tapNode(best);
  }

  void _tapNode(int id) {
    if (_over) return;
    if (current == null) {
      current = id;
      trace.add(id);
      _host?.haptic(6);
      return;
    }
    if (current == id) return;
    final edge = _untracedEdgeBetween(current!, id);
    if (edge == null) {
      _mistake();
      return;
    }
    edge.traced = true;
    current = id;
    trace.add(id);
    _score++;
    _combo++;
    // "mükemmel": hiç hata yapmadan ardışık 4 doğru geçiş
    if (_combo % 4 == 0) _perfects++;
    shake = math.min(8, 2 + _combo * 0.4);
    _host?.playSound(_combo % 4 == 0 ? 'perfect' : 'place', combo: _combo);
    _host?.haptic(9);
    if (tracedCount >= _totalEdges) {
      _win();
    } else if (!_hasNextMove()) {
      // hamle kalmadı ama çizgiler bitmedi → başarısız
      _lose();
    }
  }

  PathEdge? _untracedEdgeBetween(int a, int b) {
    for (final e in edges) {
      if (e.traced) continue;
      if ((e.a == a && e.b == b) || (e.a == b && e.b == a)) return e;
    }
    return null;
  }

  /// Mevcut düğümden geçilmemiş bir kenar kaldı mı?
  bool _hasNextMove() {
    final c = current;
    if (c == null) return true;
    return edges.any((e) => !e.traced && (e.a == c || e.b == c));
  }

  void _mistake() {
    _combo = 0;
    if (_shields > 0) {
      _shields--;
      shake = 14;
      flash = 0.5;
      _host?.playSound('shield');
      _host?.haptic(38);
      _host?.onEvent('shield', data: {'left': _shields});
      return;
    }
    _lose();
  }

  void _win() {
    if (_over) return;
    _over = true;
    _reached = true;
    _host?.playSound('win');
    // imza anı (PB-035 B8): yol tamamlanınca bitiş patlaması — fanfare
    // katmanı + güçlü perde (mevcut 'flash' alanı render'da çizilir)
    _host?.playSound('fanfare');
    flash = 0.55;
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  void _lose() {
    if (_over) return;
    _over = true;
    _reached = false;
    shake = 18;
    flash = 0.7;
    _host?.playSound('lose');
    _host?.haptic(60);
    _host?.onEvent('lose', data: {'points': _score});
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    shake = math.max(0, shake - dt * 55);
    flash = math.max(0, flash - dt * 3);
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() =>
      MiniGameResult(points: _score, perfects: _perfects, reached: _reached);

  @override
  void render(Canvas canvas, Size size) {
    final theme = _def.theme;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bg1, theme.bg2],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    if (shake > 0.2) {
      canvas.translate((_rng.nextDouble() - 0.5) * shake,
          (_rng.nextDouble() - 0.5) * shake);
    }

    // kenarlar: çizilmiş olanlar parlak, kalanlar soluk
    for (final e in edges) {
      final a = nodes[e.a], b = nodes[e.b];
      canvas.drawLine(
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        Paint()
          ..color = e.traced
              ? const Color(0xFF7CFFB2).withValues(alpha: .95)
              : Colors.white.withValues(alpha: .18)
          ..strokeWidth = e.traced ? 6 * scale : 2.4 * scale
          ..strokeCap = StrokeCap.round
          ..maskFilter =
              e.traced ? const MaskFilter.blur(BlurStyle.solid, 4) : null,
      );
    }

    // düğümler
    for (final n in nodes) {
      final isCurrent = current == n.id;
      canvas.drawCircle(Offset(n.x, n.y), (isCurrent ? 17 : 12) * scale,
          Paint()..color = isCurrent ? const Color(0xFF46E6FF) : const Color(0x33FFFFFF));
      canvas.drawCircle(Offset(n.x, n.y), (isCurrent ? 17 : 12) * scale,
          Paint()
            ..color = isCurrent ? Colors.white : Colors.white.withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    canvas.restore();

    if (flash > 0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFFFF3B3B).withValues(alpha: flash * .3));
    }
  }
}
