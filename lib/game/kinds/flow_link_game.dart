/// NEON AKIŞ — Akış Bağlama (PB-042, DESIGN-20GAMES #14: Flow Free).
///
/// Flow Free DNA'sı tek-dokunuşla: renkli uç noktaya dokun (seç) → komşu
/// hücrelere dokunarak yolu uzat → karşı uç noktaya varınca kilitlenir.
/// Kesişme/hata: yol reddedilir (parmak izi neon akar). Hamle bütçesi
/// bitince kayıp; tüm çiftler bağlanınca kazanma. Bölmeler üretimde
/// ÇÖZÜLEBİLİR inşa edilir (gizli rastgele yol ilk önce oymulur).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class FlowPair {
  final int color; // hue
  final int start, end; // hücre indeksleri (r*cols+c)
  bool done = false;
  FlowPair(this.color, this.start, this.end);
}

class FlowLinkGame implements MiniGame {
  @override
  GameKind get kind => GameKind.flowLink;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  int rows = 5, cols = 5;
  late List<int> grid; // 0 boş; 1..N renk işgali
  late List<FlowPair> pairs;
  int? selPair; // seçili çift (yol aktif)
  final List<int> activePath = [];
  final List<List<int>> donePaths = [];

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1, _budget = 0;
  bool _over = false;
  bool _reached = false;
  double time = 0, shake = 0, flash = 0;

  // geometri
  double boardX = 0, boardY = 0, cell = 0;

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

  @override
  void resize(double vw, double vh) {
    w = math.max(300, vw);
    h = math.max(480, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    final size = math.min(w - 40 * scale, h - 220 * scale);
    cell = size / cols;
    boardX = (w - size) / 2;
    boardY = 64 * scale;
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
    shake = 0;
    flash = 0;
    selPair = null;
    activePath.clear();
    donePaths.clear();
    rows = cols = def.speed >= 2.2 ? 6 : 5;
    _budget = rows * cols * 3;
    _generate(def);
    resize(w, h);
    host.playSound('start');
  }

  bool _inb(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  /// Çözülebilir üretim: her çift için rastgele kesintisiz yol OYULUR;
  /// uçlar yolun iki ucu olur → oyulan yol garantisi çözümü taşır.
  void _generate(LevelDef def) {
    final pairCount = (2 + def.speed).round().clamp(2, 4);
    final rnd = math.Random(def.i * 7 + def.stage * 131 + def.idx);
    for (var attempt = 0; attempt < 80; attempt++) {
      grid = List.filled(rows * cols, 0);
      final reserved = List.filled(rows * cols, 0); // çözüm rezervi (gizli)
      final ok = <FlowPair>[];
      var success = true;
      for (var p = 0; p < pairCount && success; p++) {
        final hueBase = (p * 87 + 10) % 360;
        final path = _carvePath(rnd, occupied: reserved);
        if (path == null || path.length < 3) {
          success = false;
          break;
        }
        for (final idx in path) {
          reserved[idx] = p + 1;
        }
        // grid: yalnız UÇLAR işaretli (çözüm yolu oyuncuya açık kalır)
        grid[path.first] = p + 1;
        grid[path.last] = p + 1;
        ok.add(FlowPair(hueBase, path.first, path.last));
      }
      if (success && ok.isNotEmpty) {
        pairs = ok;
        return;
      }
    }
    // son çare: 2 kısa sabit çift (çözülebilir — komşu satırlar)
    grid = List.filled(rows * cols, 0);
    pairs = [
      FlowPair(10, 0, 1),
      FlowPair(190, rows * cols - 2, rows * cols - 1),
    ];
    grid[0] = 1;
    grid[1] = 1;
    grid[rows * cols - 2] = 2;
    grid[rows * cols - 1] = 2;
  }

  /// Serbest hücrelerden rastgele kendi-kendi-kesişmeyen yol.
  List<int>? _carvePath(math.Random rnd, {required List<int> occupied}) {
    for (var tryStart = 0; tryStart < 24; tryStart++) {
      var r = rnd.nextInt(rows), c = rnd.nextInt(cols);
      if (occupied[r * cols + c] != 0) continue;
      final path = <int>[r * cols + c];
      final steps = 3 + rnd.nextInt(4);
      for (var s = 0; s < steps; s++) {
        final dirs = [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ]..shuffle(rnd);
        var moved = false;
        for (final d in dirs) {
          final nr = r + d[0], nc = c + d[1];
          if (!_inb(nr, nc)) continue;
          final idx = nr * cols + nc;
          if (occupied[idx] != 0 || path.contains(idx)) continue;
          path.add(idx);
          r = nr;
          c = nc;
          moved = true;
          break;
        }
        if (!moved) break;
      }
      if (path.length >= 3) return path;
    }
    return null;
  }

  int _cellAt(Offset local) {
    final c = ((local.dx - boardX) / cell).floor();
    final r = ((local.dy - boardY) / cell).floor();
    if (!_inb(r, c)) return -1;
    return r * cols + c;
  }

  bool _isEndpointOf(int pairIdx, int cellIdx) =>
      pairs[pairIdx].start == cellIdx || pairs[pairIdx].end == cellIdx;

  bool _adjacent(int a, int b) {
    final ra = a ~/ cols, ca = a % cols, rb = b ~/ cols, cb = b % cols;
    return (ra - rb).abs() + (ca - cb).abs() == 1;
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    final idx = _cellAt(local);
    if (idx < 0) return;

    // seçiliyken mi dokunuldu?
    if (selPair != null) {
      // geri alma: yolun sondan bir önceki hücresi
      if (activePath.length >= 2 && idx == activePath[activePath.length - 2]) {
        final removed = activePath.removeLast();
        grid[removed] = 0;
        _host?.haptic(3);
        return;
      }
      // tamamlama: karşı uç komşuysa
      final pair = pairs[selPair!];
      if (!pair.done &&
          _adjacent(idx, activePath.last) &&
          _isEndpointOf(selPair!, idx) &&
          idx != activePath.first) {
        activePath.add(idx);
        grid[idx] = pair.color + 1;
        _finishPair();
        return;
      }
      // uzatma: boş komşu hücre
      if (_adjacent(idx, activePath.last) && grid[idx] == 0) {
        activePath.add(idx);
        grid[idx] = pair.color + 1;
        _budget--;
        _host?.haptic(3);
        _host?.playSound('place');
        _checkBudget();
        return;
      }
      // geçersiz: başka hücreye dokundu → seçim değiştirme denensin
    }

    // seçim: tamamlanmamış çiftin ucuna dokunma
    for (var p = 0; p < pairs.length; p++) {
      if (pairs[p].done) continue;
      if (_isEndpointOf(p, idx)) {
        selPair = p;
        // aktif yolu geri al (önceki seçim varsa)
        _abandonActive();
        activePath.add(idx);
        grid[idx] = pairs[p].color + 1;
        _host?.haptic(4);
        return;
      }
    }
  }

  void _abandonActive() {
    // uç (ilk hücre) işgal kalsın; ara + son hücreler boşalsın
    for (var i = 1; i < activePath.length; i++) {
      grid[activePath[i]] = 0;
    }
    activePath.clear();
  }

  void _finishPair() {
    final pair = pairs[selPair!];
    pair.done = true;
    donePaths.add(List.of(activePath));
    _score += activePath.length;
    _combo++;
    if (_combo >= 3) _perfects++;
    _budget--;
    selPair = null;
    activePath.clear();
    _host?.playSound('perfect', combo: _combo);
    _host?.haptic(12);
    flash = 0.16;
    if (pairs.every((p) => p.done)) {
      _win();
      return;
    }
    _checkBudget();
  }

  void _checkBudget() {
    if (_budget <= 0 && !pairs.every((p) => p.done)) {
      _over = true;
      _combo = 0;
      _host?.playSound('lose');
      _host?.haptic(50);
      _host?.onEvent('lose', data: {'points': _score});
    }
  }

  void _win() {
    _over = true;
    _reached = true;
    _score += 10; // tamamlama bonusu
    if (_budget > rows * cols) _perfects++;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  /// Test kancaları.
  void setBudgetForTest(int n) => _budget = n;
  int get budgetForTest => _budget;

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    shake = math.max(0, shake - dt * 40);
    flash = math.max(0, flash - dt * 3);
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
    if (shake > 0.2) {
      canvas.translate(0, 0);
    }

    // ızgara
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(boardX + c * cell + 1.5,
            boardY + r * cell + 1.5, cell - 3, cell - 3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
          Paint()..color = Colors.white.withValues(alpha: .04),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
          Paint()
            ..color = Colors.white.withValues(alpha: .1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    // tamamlanan yollar — kalın neon boru
    for (final path in donePaths) {
      _drawPath(canvas, path, pairs.firstWhere((p) => p.done && _samePath(p, path)).color,
          locked: true);
    }

    // aktif yol — nabız
    if (selPair != null && activePath.isNotEmpty) {
      final pulse = 0.7 + 0.3 * math.sin(time * 6);
      _drawPath(canvas, activePath, pairs[selPair!].color,
          locked: false, alpha: pulse);
    }

    // uç noktalar — parlak çekirdek
    for (final p in pairs) {
      for (final idx in [p.start, p.end]) {
        final c = Offset(
            boardX + (idx % cols) * cell + cell / 2,
            boardY + (idx ~/ cols) * cell + cell / 2);
        canvas.drawCircle(c, cell * 0.2,
            Paint()..color = _hsl(p.color.toDouble(), 95, 65));
        canvas.drawCircle(
            c,
            cell * 0.2,
            Paint()
              ..color = Colors.white.withValues(alpha: .8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4);
      }
    }

    // hamle bütçesi şeridi (tahta altı)
    final budgetMax = rows * cols * 3;
    final bw = (cols * cell) * (_budget / budgetMax).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(boardX, boardY + rows * cell + 10, cols * cell, 5),
          const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: .1),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(boardX, boardY + rows * cell + 10, bw, 5),
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

  bool _samePath(FlowPair p, List<int> path) => p.start == path.first && p.end == path.last;

  void _drawPath(Canvas canvas, List<int> path, int hue,
      {required bool locked, double alpha = 1}) {
    if (path.length < 2) return;
    final paint = Paint()
      ..color = _hsl(hue.toDouble(), 90, 60).withValues(alpha: .5 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = cell * 0.42
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, locked ? 4 : 6);
    final line = Path();
    for (var i = 0; i < path.length; i++) {
      final c = Offset(
          boardX + (path[i] % cols) * cell + cell / 2,
          boardY + (path[i] ~/ cols) * cell + cell / 2);
      i == 0 ? line.moveTo(c.dx, c.dy) : line.lineTo(c.dx, c.dy);
    }
    canvas.drawPath(line, paint);
    // iç çekirdek
    final core = Paint()
      ..color = _hsl(hue.toDouble(), 95, 70).withValues(alpha: .85 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell * 0.2;
    canvas.drawPath(line, core);
  }
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
