/// IŞIK HUZMESİ — Light Beam (PB-045, DESIGN-20GAMES #15).
///
/// Monument Valley prestiji, tek dokunuş: kaynak ışık huzmesi sağa akar;
/// AYNALARA dokun → yön değiştir (/ ⇄ \); huzmeyi HEDEF KRİSTALINE ulaştır.
/// Düzenler ÇÖZÜLEBİLİR üretilir (çözüm yolu önce oymulur, aynalar tam
/// yerleştirilir, kalanı süs aynası). Dokunma bütçesi bitince kayıp.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class Mirror {
  final int cell; // r*cols+c
  bool slash; // true: /  false: \
  Mirror(this.cell, this.slash);
}

class LightBeamGame implements MiniGame {
  @override
  GameKind get kind => GameKind.lightBeam;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  int rows = 5, cols = 6;
  late List<Mirror> mirrors;
  int sourceCell = 0; // sol kenar hücresi
  int targetCell = 0;
  final List<int> beamCells = []; // canlı huzme yolu (render)

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1, _budget = 0;
  int _stage = 0;
  bool _over = false;
  bool _reached = false;
  double time = 0, flash = 0, shake = 0;

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

  double get boardX => 24 * scale;
  double get boardY => 100 * scale;
  double get cell => math.min((w - 48 * scale) / cols, (h - 260 * scale) / rows);

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
    _newPuzzle();
    host.playSound('start');
  }

  Offset _rcOf(int cell) => Offset((cell % cols).toDouble(), (cell ~/ cols).toDouble());

  /// Çözülebilir üretim: kaynaktan rastgele dönüşlerle hedefe yol oymulur;
  /// dönüş noktalarına DOĞRU aynalar konur; 1-2 süs aynası eklenir.
  void _newPuzzle() {
    rows = _def.speed >= 2.2 ? 6 : 5;
    cols = 6;
    final rnd = math.Random(_def.i * 13 + _stage * 97 + 7);
    for (var attempt = 0; attempt < 60; attempt++) {
      mirrors = [];
      var r = rnd.nextInt(rows);
      var c = 0;
      var dir = const Offset(1, 0); // sağa başlar
      final path = <int>[r * cols + c];
      final turns = <Mirror>[];
      var steps = 0;
      final maxSteps = cols + rows * 2 + rnd.nextInt(3);
      while (steps < maxSteps) {
        // hücreyi işgal et ve ilerle
        if (rnd.nextDouble() < 0.35 && c + 1 < cols && turns.isEmpty ||
            (turns.isNotEmpty && rnd.nextDouble() < 0.3)) {
          // dönüş: dikey bileşene sap
          final d = rnd.nextBool() ? const Offset(0, 1) : const Offset(0, -1);
          final nr = r + d.dy.toInt();
          if (nr < 0 || nr >= rows) continue;
          // ayna: / \ yönlü dönüş (dir → d)
          final slash = _mirrorFor(dir, d);
          turns.add(Mirror(r * cols + c, slash));
          dir = d;
        }
        final nc = c + dir.dx.toInt();
        final nr2 = r + dir.dy.toInt();
        if (nc < 0 || nc >= cols || nr2 < 0 || nr2 >= rows) break;
        c = nc;
        r = nr2;
        path.add(r * cols + c);
        steps++;
        if (c >= cols - 2 && turns.isNotEmpty) break; // sağ bölgeye vardı
      }
      if (turns.isEmpty || path.length < 4) continue;
      targetCell = path.last;
      // hedefin kaynağın hücresiyle çakışmaması
      if (targetCell == path.first) continue;
      sourceCell = path.first;
      mirrors = turns;
      // süs aynaları (çözümü bozmaz — huzme zaten varışta durur)
      for (var d = 0; d < 2; d++) {
        final cell = rnd.nextInt(rows * cols);
        if (cell == sourceCell || cell == targetCell) continue;
        if (mirrors.any((m) => m.cell == cell)) continue;
        mirrors.add(Mirror(cell, rnd.nextBool()));
      }
      _budget = 8 + _stage * 2;
      _trace();
      // doğrula: huzme hedefe ulaşıyor mu (üretim güvenliği)
      if (beamCells.contains(targetCell)) {
        _budget = 8 + _stage * 2;
        return;
      }
    }
    // son çare: düz hattı çöz
    mirrors = [];
    sourceCell = 2 * cols;
    targetCell = 2 * cols + cols - 1;
    _budget = 8;
    _trace();
  }

  /// dir → d dönüşü için ayna eğimi.
  bool _mirrorFor(Offset dir, Offset d) {
    // '/' : sağ→yukarı, sol→aşağı, yukarı→sağ, aşağı→sol
    if (dir.dx == 1 && d.dy == -1) return true;
    if (dir.dx == -1 && d.dy == 1) return true;
    if (dir.dy == -1 && d.dx == 1) return true;
    if (dir.dy == 1 && d.dx == -1) return true;
    return false;
  }

  /// Huzmeyi simüle et: beamCells'i doldur.
  void _trace() {
    beamCells.clear();
    var pos = _rcOf(sourceCell);
    var dir = const Offset(1, 0);
    for (var step = 0; step < 60; step++) {
      pos += dir;
      if (pos.dx < 0 || pos.dx >= cols || pos.dy < 0 || pos.dy >= rows) break;
      final cell = pos.dy.toInt() * cols + pos.dx.toInt();
      beamCells.add(cell);
      final m = mirrors.where((m) => m.cell == cell).toList();
      if (m.isNotEmpty) {
        final slash = m.first.slash;
        // '/' : (1,0)→(0,-1); '\' : (1,0)→(0,1) ...
        dir = slash
            ? Offset(dir.dy, dir.dx)
            : Offset(-dir.dy, -dir.dx);
      }
      if (cell == targetCell) break;
    }
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    final cCol = ((local.dx - boardX) / cell).floor();
    final cRow = ((local.dy - boardY) / cell).floor();
    if (cCol < 0 || cCol >= cols || cRow < 0 || cRow >= rows) return;
    final cellIdx = cRow * cols + cCol;
    final m = mirrors.where((mm) => mm.cell == cellIdx).toList();
    if (m.isEmpty) return;
    m.first.slash = !m.first.slash;
    _budget--;
    _host?.haptic(5);
    _host?.playSound('pop');
    _trace();
    if (beamCells.contains(targetCell)) {
      _solved();
    } else if (_budget <= 0) {
      _over = true;
      _combo = 0;
      _host?.playSound('lose');
      _host?.haptic(50);
      _host?.onEvent('lose', data: {'points': _score});
    }
  }

  void _solved() {
    _score += 10 + _stage * 2;
    _combo++;
    if (_budget >= 5) _perfects++;
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
  List<Mirror> get mirrorsForTest => mirrors;
  List<int> get beamForTest => beamCells;

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
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
    // ızgara
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(boardX + c * cell, boardY + r * cell,
            cell - 2, cell - 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.16)),
          Paint()
            ..color = Colors.white.withValues(alpha: .035)
            ..style = PaintingStyle.fill);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.16)),
          Paint()
            ..color = Colors.white.withValues(alpha: .08)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      }
    }

    // huzme — canlı neon boru (darbelenen)
    if (beamCells.isNotEmpty) {
      final line = Path();
      final start = Offset(boardX - cell * 0.5,
          boardY + (sourceCell ~/ cols) * cell + cell / 2);
      line.moveTo(start.dx, start.dy);
      for (final cellIdx in beamCells) {
        final p = _rcOf(cellIdx);
        line.lineTo(boardX + p.dx * cell + cell / 2,
            boardY + p.dy * cell + cell / 2);
      }
      final pulse = 0.55 + 0.2 * math.sin(time * 6);
      canvas.drawPath(
          line,
          Paint()
            ..color = _hsl(theme.glow.toDouble(), 95, 65).withValues(alpha: .3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.34
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawPath(
          line,
          Paint()
            ..color = Colors.white.withValues(alpha: pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.12
            ..strokeCap = StrokeCap.round);
    }

    // kaynak prizması
    final src = Offset(boardX - cell * 0.28,
        boardY + (sourceCell ~/ cols) * cell + cell / 2);
    canvas.drawCircle(src, 7 * scale,
        Paint()..color = Colors.white);
    canvas.drawCircle(
        src,
        11 * scale,
        Paint()
          ..color = Colors.white.withValues(alpha: .3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // aynalar
    for (final m in mirrors) {
      final p = _rcOf(m.cell);
      final cx = boardX + p.dx * cell + cell / 2;
      final cy = boardY + p.dy * cell + cell / 2;
      final half = cell * 0.34;
      canvas.drawLine(
          m.slash
              ? Offset(cx - half, cy + half)
              : Offset(cx - half, cy - half),
          m.slash
              ? Offset(cx + half, cy - half)
              : Offset(cx + half, cy + half),
          Paint()
            ..color = const Color(0xFFBFE9FF)
            ..strokeWidth = 3.4
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawLine(
          m.slash
              ? Offset(cx - half, cy + half)
              : Offset(cx - half, cy - half),
          m.slash
              ? Offset(cx + half, cy - half)
              : Offset(cx + half, cy + half),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round);
    }

    // hedef kristal — huzme vardığında parlar
    final tp = _rcOf(targetCell);
    final tc = Offset(boardX + tp.dx * cell + cell / 2,
        boardY + tp.dy * cell + cell / 2);
    final lit = beamCells.contains(targetCell);
    canvas.drawCircle(
        tc,
        cell * 0.3,
        Paint()
          ..color = lit
              ? const Color(0xFFB9FFC9).withValues(alpha: .9)
              : Colors.white.withValues(alpha: .18)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, lit ? 12 : 4));
    canvas.drawCircle(
        tc,
        cell * 0.16,
        Paint()..color = lit ? Colors.white : Colors.white.withValues(alpha: .4));

    // dokunma bütçesi
    final maxB = (8 + _stage * 2).toDouble();
    final bw = (cols * cell) * (_budget / maxB).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(boardX, boardY + rows * cell + 12, cols * cell, 5),
          const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: .1),
    );
    if (bw > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(boardX, boardY + rows * cell + 12, bw, 5),
            const Radius.circular(3)),
        Paint()
          ..color = _hsl(theme.glow.toDouble(), 90, 62)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

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
