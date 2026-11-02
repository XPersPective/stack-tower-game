/// MERGE — Birleştir (DESIGN-V2 §3.1 tür 5, merge fiili).
/// Tek girdi: dokun-dokun (seç → hedefle). Eşit iki parça birleşir, değeri katlanır.
/// Baskı: eriyen süre — her birleşme süre ekler, süre biterse kaybedersin.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class MergePop {
  int cell;
  double life;
  MergePop(this.cell) : life = 0;
}

class MergeGame implements MiniGame {
  @override
  GameKind get kind => GameKind.merge;

  static const int cols = 4;
  static const int rows = 4;
  static const int cells = cols * rows;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  /// Hücre değerleri: null = boş, n = 2^n seviyesi (1 → "2", 2 → "4", ...).
  final List<int?> grid = List<int?>.filled(cells, null);
  int? selected;

  /// Eriyen süre (sn). Her birleşme süre ekler.
  double fuse = 12;
  double fuseMax = 20;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false, _reached = false;
  double _sinceMerge = 0;

  /// PB-026: tahta dolabilsin diye zamanla yeni parça doğar (yoksa doluluk
  /// hep 4'te sabit kalıyordu ve "ızgara taşması = kayıp" hiç gerçekleşmiyordu).
  static const double spawnEvery = 5.0;
  double _spawnT = 0;
  double time = 0, shake = 0, flash = 0;
  final List<MergePop> pops = [];
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

  /* ---- test kancaları ---- */
  @visibleForTesting
  List<int?> get gridForTest => grid;
  @visibleForTesting
  double get fuseForTest => fuse;
  @visibleForTesting
  int? get selectedForTest => selected;
  @visibleForTesting
  void setCellForTest(int i, int? level) => grid[i] = level;
  @visibleForTesting
  void fuseTopUpForTest() => fuse = fuseMax;

  @override
  void resize(double vw, double vh) {
    w = math.max(320, vw);
    h = math.max(400, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
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
    _sinceMerge = 0;
    _spawnT = 0;
    time = 0;
    shake = 0;
    flash = 0;
    selected = null;
    pops.clear();
    for (var i = 0; i < cells; i++) {
      grid[i] = null;
    }
    fuse = 12;
    fuseMax = 20;
    // başlangıç: 4 parça
    for (var i = 0; i < 4; i++) {
      _spawn();
    }
    host.playSound('start');
  }

  void _spawn() {
    final empty = <int>[
      for (var i = 0; i < cells; i++)
        if (grid[i] == null) i
    ];
    if (empty.isEmpty) return;
    final idx = empty[_rnd.nextInt(empty.length)];
    grid[idx] = _rnd.nextDouble() < 0.72 ? 1 : 2;
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    final idx = _cellAt(local);
    if (idx == null) {
      selected = null;
      return;
    }
    if (grid[idx] == null) {
      // boş hücre: seçili parça varsa taşı
      if (selected != null) {
        grid[idx] = grid[selected!];
        grid[selected!] = null;
        selected = null;
        _host?.haptic(5);
      }
      return;
    }
    if (selected == null) {
      selected = idx;
      _host?.haptic(5);
      return;
    }
    if (selected == idx) {
      selected = null;
      return;
    }
    final a = grid[selected!]!, b = grid[idx]!;
    if (a == b) {
      _merge(selected!, idx);
    } else {
      selected = idx; // eşit değil → seçim taşınır
      _host?.haptic(5);
    }
  }

  void _merge(int from, int to) {
    final level = grid[to]! + 1;
    grid[to] = level;
    grid[from] = null;
    selected = null;
    _score++;
    // 2.5 sn içinde ardışık birleşme → kombo
    _combo = _sinceMerge <= 2.5 ? _combo + 1 : 1;
    _sinceMerge = 0;
    // büyük birleşme (8+) mükemmel sayılır
    if (level >= 4) _perfects++;
    fuse = math.min(fuseMax, fuse + 1.6 + level * 0.12);
    pops.add(MergePop(to));
    shake = math.min(10, 3 + level * 0.9);
    flash = level >= 4 ? 0.22 : 0.08;
    _host?.playSound(level >= 4 ? 'perfect' : 'place', combo: _combo);
    _host?.haptic(level >= 4 ? 22 : 10);
    _spawn();
    if (_def.target > 0 && _score >= _def.target) {
      _win();
    } else if (!_hasMove()) {
      _lose();
    }
  }

  /// Tahta dolu ve hiç eşit çift yoksa hamle kalmaz.
  bool _hasMove() {
    if (grid.any((c) => c == null)) return true;
    for (var i = 0; i < cells; i++) {
      for (var j = i + 1; j < cells; j++) {
        if (grid[i] == grid[j]) return true;
      }
    }
    return false;
  }

  int? _cellAt(Offset local) {
    final board = _boardRect();
    if (!board.contains(local)) return null;
    final cw = board.width / cols;
    final ch = board.height / rows;
    final cx = ((local.dx - board.left) / cw).floor();
    final cy = ((local.dy - board.top) / ch).floor();
    if (cx < 0 || cx >= cols || cy < 0 || cy >= rows) return null;
    return cy * cols + cx;
  }

  Rect _boardRect() {
    final size = math.min(w * 0.86, h * 0.52);
    return Rect.fromLTWH((w - size) / 2, h * 0.24, size, size);
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    _sinceMerge += dt;
    if (_sinceMerge > 2.5) _combo = 0;
    // PB-026: periyodik doğum — doluluk artabilir, taşma kaybı gerçek olur
    _spawnT += dt;
    if (_spawnT >= spawnEvery) {
      _spawnT = 0;
      _spawn();
      if (!_hasMove()) _lose();
    }
    fuse -= dt * (0.85 + _def.speed * 0.12);
    shake = math.max(0, shake - dt * 55);
    flash = math.max(0, flash - dt * 3);
    for (var i = pops.length - 1; i >= 0; i--) {
      pops[i].life += dt;
      if (pops[i].life > 0.4) pops.removeAt(i);
    }
    if (fuse <= 0) {
      fuse = 0;
      if (_shields > 0) {
        _shields--;
        fuse = 6; // kalkan: 6 saniye daha
        _host?.playSound('shield');
        _host?.haptic(40);
        _host?.onEvent('shield', data: {'left': _shields});
      } else {
        _lose();
      }
    }
  }

  void _win() {
    if (_over) return;
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  void _lose() {
    if (_over) return;
    _over = true;
    _reached = false;
    shake = 18;
    flash = 0.6;
    _host?.playSound('lose');
    _host?.haptic(60);
    _host?.onEvent('lose', data: {'points': _score});
  }

  @override
  void stop() {}

  @override
  MiniGameResult result() => MiniGameResult(
        points: _score,
        perfects: _perfects,
        reached: _reached,
      );

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
      canvas.translate((_rnd.nextDouble() - 0.5) * shake,
          (_rnd.nextDouble() - 0.5) * shake);
    }

    final board = _boardRect();
    // tahta zemini
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(18)),
      Paint()..color = Colors.white.withValues(alpha: .05),
    );
    final cw = board.width / cols, ch = board.height / rows;
    for (var i = 0; i < cells; i++) {
      final cx = board.left + (i % cols) * cw;
      final cy = board.top + (i ~/ cols) * ch;
      final rect = Rect.fromLTWH(cx + 5, cy + 5, cw - 10, ch - 10);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          Paint()..color = Colors.white.withValues(alpha: .04));
      final v = grid[i];
      if (v == null) continue;
      final hue = (theme.glow + v * 26) % 360;
      final pop = pops.any((p) => p.cell == i)
          ? 1 + 0.16 * (1 - pops.firstWhere((p) => p.cell == i).life / 0.4)
          : 1.0;
      final r = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: rect.center, width: rect.width * pop, height: rect.height * pop),
          const Radius.circular(12));
      canvas.drawRRect(
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HSLColor.fromAHSL(1, hue.toDouble(), .92, .62).toColor(),
                HSLColor.fromAHSL(1, hue.toDouble(), .88, .42).toColor(),
              ],
            ).createShader(rect));
      canvas.drawRRect(
          r,
          Paint()
            ..color = HSLColor.fromAHSL(.6, hue.toDouble(), 1, .8).toColor()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
      if (selected == i) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(14)),
            Paint()
              ..color = Colors.white.withValues(alpha: .85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4);
      }
      final label = '${1 << v}';
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: (cw * (label.length > 3 ? 0.26 : 0.34)).clamp(12.0, 34.0),
                fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }

    // birleşme patlaması: hücrede genişleyen halka (C-023 juice)
    for (final p in pops) {
      final t = (p.life / 0.4).clamp(0.0, 1.0);
      final cx = board.left + (p.cell % cols) * cw + cw / 2;
      final cy = board.top + (p.cell ~/ cols) * ch + ch / 2;
      canvas.drawCircle(
          Offset(cx, cy),
          (cw * 0.35 + t * cw * 0.55),
          Paint()
            ..color = HSLColor.fromAHSL((1 - t) * .85,
                    (theme.glow + (grid[p.cell] ?? 1) * 26) % 360, 1, .72)
                .toColor()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2 * (1 - t) + 0.8);
      // imza anı (PB-035 B8): birleşme halkası v2 — gecikmeli ikinci halka
      // + dönen 6 kıvılcım (yalnız sunum; oyun mantığına dokunmaz)
      final t2 = ((p.life - 0.07) / 0.4).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(cx, cy),
          cw * (0.3 + t2 * 1.05),
          Paint()
            ..color = Colors.white.withValues(alpha: (1 - t2) * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * (1 - t2) + 0.6);
      for (var k = 0; k < 6; k++) {
        final ang = k * math.pi / 3 + p.life * 2.2;
        final r0 = cw * (0.32 + t * 0.72);
        final r1 = r0 + 7 * scale * (1 - t) + 3;
        canvas.drawLine(
            Offset(cx + math.cos(ang) * r0, cy + math.sin(ang) * r0),
            Offset(cx + math.cos(ang) * r1, cy + math.sin(ang) * r1),
            Paint()
              ..color = Colors.white.withValues(alpha: (1 - t) * 0.55)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round);
      }
    }

    // eriyen süre çubuğu
    final barW = board.width;
    final by = board.bottom + 22 * scale;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(board.left, by, barW, 12 * scale), const Radius.circular(8)),
        Paint()..color = Colors.white.withValues(alpha: .12));
    final ratio = (fuse / fuseMax).clamp(0.0, 1.0);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(board.left, by, barW * ratio, 12 * scale),
            const Radius.circular(8)),
        Paint()
          ..color = ratio > 0.35
              ? const Color(0xFF46E6FF)
              : const Color(0xFFFF5A5A));
    canvas.restore();

    if (flash > 0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = Colors.white.withValues(alpha: flash * .3));
    }
  }
}
