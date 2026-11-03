/// NEON TEMİZLİK — Blokudoku (PB-041, DESIGN-20GAMES #17: Clear).
///
/// Block Blast/Blockudoku DNA'sı: elde 3 parça, tahtaya yerleştir; TAM SATIR
/// VEYA SÜTUN dolunca neon patlamasıyla temizlenir (Block Blast'tan fark:
/// satır+SÜTUN ikisi de). Tahtaya hiçbir parça sığmıyorsa taşma → kayıp
/// (kalkan: alt 2 satırı temizler). Tek dokunuş: parçaya dokun (seç) →
/// hücreye dokun (koy) — C-022. Skor: satır=8, çoklu temizlik +4/ek,
/// tam temizlik +10. Hedef: def.target puan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Parça şekli — hücre ofsetleri (satır, sütun).
class CleanShape {
  final List<(int, int)> cells;
  final String id;
  const CleanShape(this.id, this.cells);
  int get rows => cells.map((c) => c.$1).reduce(math.max) + 1;
  int get cols => cells.map((c) => c.$2).reduce(math.max) + 1;
}

/// Eldeki somut parça (şekil + renk).
class HandPiece {
  CleanShape shape;
  int hue;
  bool used = false;
  HandPiece(this.shape, this.hue);
}

/// Şekil kataloğu — kolay/orta/zor kademeli (def.speed ile seçilir).
const List<CleanShape> kEasyShapes = [
  CleanShape('dot', [(0, 0)]),
  CleanShape('d2h', [(0, 0), (0, 1)]),
  CleanShape('d2v', [(0, 0), (1, 0)]),
  CleanShape('d3h', [(0, 0), (0, 1), (0, 2)]),
  CleanShape('d3v', [(0, 0), (1, 0), (2, 0)]),
  CleanShape('L3a', [(0, 0), (1, 0), (1, 1)]),
  CleanShape('L3b', [(0, 1), (1, 0), (1, 1)]),
];
const List<CleanShape> kMidShapes = [
  CleanShape('sq2', [(0, 0), (0, 1), (1, 0), (1, 1)]),
  CleanShape('d4h', [(0, 0), (0, 1), (0, 2), (0, 3)]),
  CleanShape('d4v', [(0, 0), (1, 0), (2, 0), (3, 0)]),
  CleanShape('L4a', [(0, 0), (1, 0), (2, 0), (2, 1)]),
  CleanShape('L4b', [(0, 0), (0, 1), (1, 1), (2, 1)]),
  CleanShape('t4', [(0, 0), (0, 1), (0, 2), (1, 1)]),
  CleanShape('s4', [(0, 1), (0, 2), (1, 0), (1, 1)]),
];
const List<CleanShape> kHardShapes = [
  CleanShape('sq3', [
    (0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)
  ]),
  CleanShape('rect23', [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)]),
  CleanShape('d5h', [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)]),
  CleanShape('L4c', [(0, 0), (0, 1), (1, 0), (2, 0)]),
  CleanShape('t4b', [(0, 1), (1, 0), (1, 1), (1, 2)]),
];

const int kCleanGrid = 8;

/// Temizlenme animasyonu hücresi.
class CleanFx {
  int row, col;
  double life;
  int hue;
  CleanFx(this.row, this.col, this.hue) : life = 0;
}

/// Uçan puan yazısı.
class ScorePop {
  double x, y, life;
  String text;
  ScorePop(this.x, this.y, this.text) : life = 0;
}

class NeonCleanGame implements MiniGame {
  @override
  GameKind get kind => GameKind.neonClean;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  // tahta geometrisi
  double boardX = 0, boardY = 0, cs = 0;

  // hücreler: null = boş, aksi hue
  final List<int?> grid = List.filled(kCleanGrid * kCleanGrid, null);
  final List<HandPiece> hand = [];
  int? selected;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  int _linesCleared = 0;
  bool _over = false;
  bool _reached = false;
  double time = 0, shake = 0;
  final List<CleanFx> _fx = [];
  final List<ScorePop> _pops = [];
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

  @override
  void resize(double vw, double vh) {
    w = math.max(300, vw);
    h = math.max(480, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    final boardSize = math.min(w - 28 * scale, h - 230 * scale);
    cs = boardSize / kCleanGrid;
    boardX = (w - boardSize) / 2;
    boardY = 56 * scale;
  }

  @override
  void start(LevelDef def,
      {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    for (var i = 0; i < grid.length; i++) {
      grid[i] = null;
    }
    hand.clear();
    selected = null;
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _linesCleared = 0;
    _over = false;
    _reached = false;
    time = 0;
    shake = 0;
    _fx.clear();
    _pops.clear();
    _refill();
    host.playSound('start');
  }

  /// Zorluk katmanına göre şekil havuzu (def.speed 0.9..3.0).
  CleanShape _rollShape() {
    final speed = _def.speed;
    final pool = <CleanShape>[
      ...kEasyShapes,
      if (speed >= 1.4) ...kMidShapes,
      if (speed >= 2.1) ...kHardShapes,
    ];
    // zor havuzda büyük parçalar çift ağırlıkta temsil edilsin
    if (speed >= 2.1) pool.addAll(kHardShapes);
    return pool[_rnd.nextInt(pool.length)];
  }

  void _refill() {
    hand.clear();
    final hues = [200, 45, 130, 322, 268, 12];
    for (var i = 0; i < 3; i++) {
      hand.add(HandPiece(_rollShape(), hues[_rnd.nextInt(hues.length)]));
    }
  }

  bool _fits(CleanShape s, int r0, int c0) {
    for (final (dr, dc) in s.cells) {
      final r = r0 + dr, c = c0 + dc;
      if (r < 0 || r >= kCleanGrid || c < 0 || c >= kCleanGrid) return false;
      if (grid[r * kCleanGrid + c] != null) return false;
    }
    return true;
  }

  bool _anyFit(HandPiece p) {
    for (var r = 0; r <= kCleanGrid - p.shape.rows; r++) {
      for (var c = 0; c <= kCleanGrid - p.shape.cols; c++) {
        if (_fits(p.shape, r, c)) return true;
      }
    }
    return false;
  }

  /// Dokunma: önce el şeridi (seçim), sonra tahta (yerleştirme).
  @override
  void onTap(Offset local) {
    if (_over) return;
    // el şeridi bölgesi
    final handTop = boardY + kCleanGrid * cs + 14 * scale;
    if (local.dy >= handTop - 8 * scale) {
      final cardW = (w - 40 * scale) / 3;
      final idx = ((local.dx - 20 * scale) ~/ cardW).clamp(0, 2);
      final p = hand[idx];
      if (p.used) return;
      selected = selected == idx ? null : idx;
      _host?.haptic(4);
      return;
    }
    // tahta: seçili parçayı parmağın merkezine koy
    if (selected == null) return;
    final p = hand[selected!];
    if (p.used) return;
    final r0 = (((local.dy - boardY) / cs) - p.shape.rows / 2)
        .round()
        .clamp(0, kCleanGrid - p.shape.rows);
    final c0 = (((local.dx - boardX) / cs) - p.shape.cols / 2)
        .round()
        .clamp(0, kCleanGrid - p.shape.cols);
    if (!_fits(p.shape, r0, c0)) {
      shake = 8;
      _host?.playSound('lose'); // geçersiz: kısa düşük ton
      _host?.haptic(8);
      _checkStuck(); // yerleştirilemedi → taşma durumu da burada sınanır
      return;
    }
    _place(p, selected!, r0, c0);
  }

  /// Taşma yasası: kullanılmayan HİÇBİR parça sığmıyorsa oyun biter
  /// (kalkan: alt 2 satır temizlenir + el taze-lenir).
  void _checkStuck() {
    if (hand.any((p) => !p.used && _anyFit(p))) return;
    if (_shields > 0) {
      _shields--;
      // taşma kalkanı: alt 2 satırı temizle + el tazele
      for (var r = kCleanGrid - 2; r < kCleanGrid; r++) {
        for (var c = 0; c < kCleanGrid; c++) {
          final hue = grid[r * kCleanGrid + c];
          if (hue != null) _fx.add(CleanFx(r, c, hue));
          grid[r * kCleanGrid + c] = null;
        }
      }
      _refill();
      flashShield();
      _host?.playSound('shield');
      _host?.haptic(25);
      return;
    }
    _over = true;
    _host?.playSound('lose');
    _host?.haptic(50);
    _host?.onEvent('lose', data: {'points': _score});
  }

  void _place(HandPiece p, int handIdx, int r0, int c0) {
    for (final (dr, dc) in p.shape.cells) {
      grid[(r0 + dr) * kCleanGrid + (c0 + dc)] = p.hue;
    }
    p.used = true;
    selected = null;
    _host?.playSound('place');
    _host?.haptic(5);

    // satır + sütun tarama
    final fullRows = <int>[];
    final fullCols = <int>[];
    for (var r = 0; r < kCleanGrid; r++) {
      var full = true;
      for (var c = 0; c < kCleanGrid; c++) {
        if (grid[r * kCleanGrid + c] == null) {
          full = false;
          break;
        }
      }
      if (full) fullRows.add(r);
    }
    for (var c = 0; c < kCleanGrid; c++) {
      var full = true;
      for (var r = 0; r < kCleanGrid; r++) {
        if (grid[r * kCleanGrid + c] == null) {
          full = false;
          break;
        }
      }
      if (full) fullCols.add(c);
    }
    final lines = fullRows.length + fullCols.length;
    if (lines > 0) {
      var gained = 8 * lines + (lines > 1 ? 4 * (lines - 1) : 0);
      // tam temizlik bonusu: dolu hücrelerin TAMAMI temizlenen kümede mi?
      // (birleşim kümeleri kesişimi çift sayar: |A∪B| = |A|+|B|-|A∩B|)
      var remaining = 0;
      for (final cell in grid) {
        if (cell != null) remaining++;
      }
      final covered = fullRows.length * kCleanGrid +
          fullCols.length * kCleanGrid -
          fullRows.length * fullCols.length;
      final perfect = remaining == covered;
      if (perfect) {
        gained += 10;
        _perfects++;
      }
      _score += gained;
      _combo++;
      _linesCleared += lines;
      // hücreleri temizle + fx
      for (final r in fullRows) {
        for (var c = 0; c < kCleanGrid; c++) {
          final hue = grid[r * kCleanGrid + c];
          if (hue != null) _fx.add(CleanFx(r, c, hue));
          grid[r * kCleanGrid + c] = null;
        }
      }
      for (final c in fullCols) {
        for (var r = 0; r < kCleanGrid; r++) {
          final hue = grid[r * kCleanGrid + c];
          if (hue != null) _fx.add(CleanFx(r, c, hue));
          grid[r * kCleanGrid + c] = null;
        }
      }
      _pops.add(ScorePop(w / 2, boardY + kCleanGrid * cs * 0.4,
          lines > 1 ? '+$gained ×$lines!' : '+$gained'));
      _host?.playSound('perfect', combo: _combo);
      _host?.haptic(lines > 1 ? 30 : 12);
      if (_def.target > 0 && _score >= _def.target) {
        _win();
        return;
      }
    } else {
      _combo = 0;
    }

    // el tükendi → yeni el
    if (hand.every((p) => p.used)) _refill();

    // taşma kontrolü: hiçbir parça sığmıyorsa
    _checkStuck();
  }

  double flashShieldT = 0;
  void flashShield() => flashShieldT = 0.5;

  /// Toplam temizlenen satır/sütun sayısı (telemetri + test).
  int get linesCleared => _linesCleared;

  /// Test kanca: kalkan sayısını doğrudan ayarla.
  void setShieldsForTest(int n) => _shields = n;

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  @override
  void tick(double dt) {
    time += dt;
    shake = math.max(0, shake - dt * 40);
    flashShieldT = math.max(0, flashShieldT - dt);
    for (var i = _fx.length - 1; i >= 0; i--) {
      _fx[i].life += dt;
      if (_fx[i].life > 0.3) _fx.removeAt(i);
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      _pops[i].life += dt;
      _pops[i].y -= 40 * dt;
      if (_pops[i].life > 0.9) _pops.removeAt(i);
    }
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
      canvas.translate(
          (_rnd.nextDouble() - 0.5) * shake, (_rnd.nextDouble() - 0.5) * shake);
    }

    // tahta paneli
    final boardRect = Rect.fromLTWH(boardX - 8, boardY - 8,
        kCleanGrid * cs + 16, kCleanGrid * cs + 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(14)),
      Paint()
        ..color = Colors.white.withValues(alpha: .04)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(14)),
      Paint()
        ..color = Colors.white.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // kalkan flaşı
    if (flashShieldT > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(boardRect, const Radius.circular(14)),
        Paint()
          ..color = Colors.amber.withValues(alpha: flashShieldT * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // hücreler
    final ghost = _ghostCells();
    for (var r = 0; r < kCleanGrid; r++) {
      for (var c = 0; c < kCleanGrid; c++) {
        final rect = Rect.fromLTWH(boardX + c * cs + 1.5,
            boardY + r * cs + 1.5, cs - 3, cs - 3);
        final hue = grid[r * kCleanGrid + c];
        if (hue != null) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.22)),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_hsl(hue.toDouble(), 90, 58), _hsl(hue.toDouble(), 85, 42)],
              ).createShader(rect),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.22)),
            Paint()
              ..color = Colors.white.withValues(alpha: .25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.22)),
            Paint()..color = Colors.white.withValues(alpha: .045),
          );
        }
      }
    }

    // hayalet önizleme (seçiliyken ilk sığan konum önerisi)
    if (ghost != null) {
      final valid = ghost.$2;
      final hue = ghost.$3;
      for (final (r, c) in ghost.$1) {
        final rect = Rect.fromLTWH(
            boardX + c * cs + 2, boardY + r * cs + 2, cs - 4, cs - 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.22)),
          Paint()
            ..color = (valid ? _hsl(hue.toDouble(), 90, 60) : const Color(0xFFE53935))
                .withValues(alpha: .38),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.22)),
          Paint()
            ..color = (valid ? Colors.white : const Color(0xFFE53935))
                .withValues(alpha: .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    // temizlenme parıltıları
    for (final e in _fx) {
      final t = e.life / 0.3;
      final rect = Rect.fromLTWH(boardX + e.col * cs + 1, boardY + e.row * cs + 1,
          (cs - 2) * (1 - t), (cs - 2) * (1 - t));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.2)),
        Paint()
          ..color = Colors.white.withValues(alpha: (1 - t) * .9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // el şeridi — 3 kart
    final handTop = boardY + kCleanGrid * cs + 14 * scale;
    final cardW = (w - 40 * scale) / 3;
    for (var i = 0; i < 3; i++) {
      final p = hand[i];
      final isSel = selected == i;
      final cardRect = Rect.fromLTWH(
          20 * scale + i * cardW + 4,
          handTop + (isSel ? -6 : 2) * scale,
          cardW - 8,
          78 * scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cardRect, const Radius.circular(12)),
        Paint()
          ..color = Colors.white.withValues(alpha: p.used ? .02 : .06),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cardRect, const Radius.circular(12)),
        Paint()
          ..color = isSel
              ? _hsl(p.hue.toDouble(), 95, 65).withValues(alpha: .9)
              : Colors.white.withValues(alpha: .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2 : 1,
      );
      if (!p.used) {
        _drawShapeMini(canvas, p, cardRect);
      }
    }

    // puan pop'ları
    for (final pop in _pops) {
      final a = (1 - pop.life / 0.9).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
            text: pop.text,
            style: TextStyle(
                fontSize: 22 * scale,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: a))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pop.x - tp.width / 2, pop.y));
    }

    canvas.restore();
  }

  void _drawShapeMini(Canvas canvas, HandPiece p, Rect card) {
    final s = p.shape;
    final mini = math.min(card.width / (s.cols + 0.6),
            (card.height - 10) / (s.rows + 0.6))
        .clamp(6.0, cs * 0.9);
    final ox = card.center.dx - s.cols * mini / 2;
    final oy = card.center.dy - s.rows * mini / 2;
    for (final (r, c) in s.cells) {
      final rect = Rect.fromLTWH(ox + c * mini, oy + r * mini, mini - 2, mini - 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(mini * 0.24)),
        Paint()
          ..shader = LinearGradient(colors: [
            _hsl(p.hue.toDouble(), 92, 60),
            _hsl(p.hue.toDouble(), 85, 44),
          ]).createShader(rect),
      );
    }
  }

  /// (hücreler, geçerli mi, hue) — seçili parça için ilk sığan konum önerisi.
  (List<(int, int)>, bool, int)? _ghostCells() {
    if (selected == null) return null;
    final p = hand[selected!];
    if (p.used) return null;
    // varsayılan önizleme: ilk sığan konum (dokunmadan önce de yol gösterir)
    for (var r = 0; r <= kCleanGrid - p.shape.rows; r++) {
      for (var c = 0; c <= kCleanGrid - p.shape.cols; c++) {
        if (_fits(p.shape, r, c)) {
          return (
            [for (final (dr, dc) in p.shape.cells) (r + dr, c + dc)],
            true,
            p.hue
          );
        }
      }
    }
    return ([...p.shape.cells], false, p.hue);
  }
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
