/// HEXA NEON — Altıgen Birleştir (PB-042, DESIGN-20GAMES #6: Hexa Merge).
///
/// 2048 DNA'sının düşüş hâli: sayılı altıgen sütuna düşer; AYNI SAYI üstüne
/// düşerse katlanır (×2), zincir kurar. Tahta dolarsa (sütun taşması) kayıp.
/// Tek dokunuş: dokunduğun x → o sütuna düşer (C-022). Skor = birleşen sayı.
/// Hedef: def.target puan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

const int kHexCols = 5;
const int kHexRows = 6;

/// Tahtadaki hücre: sayı (0 = boş) ve doğuş animasyonu.
class HexCell {
  int value;
  double popT;
  HexCell(this.value) : popT = 0;
}

/// Düşen parça animasyonu.
class FallingHex {
  int col, value;
  double y; // hedef hücreye göre 0..1
  double speed;
  FallingHex(this.col, this.value, this.y) : speed = 2.6;
}

/// Birleşme parıltısı.
class MergeFx {
  int col, row;
  double life;
  MergeFx(this.col, this.row) : life = 0;
}

class HexaMergeGame implements MiniGame {
  @override
  GameKind get kind => GameKind.hexaMerge;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  final List<List<HexCell?>> grid =
      List.generate(kHexCols, (_) => List.filled(kHexRows, null));
  FallingHex? falling;
  final List<MergeFx> fx = [];

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false;
  bool _reached = false;
  double time = 0, shake = 0, flash = 0;
  final math.Random _rnd = math.Random();

  // geometri
  double boardX = 0, boardY = 0, cellW = 0, cellH = 0;

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
    final boardW = w - 40 * scale;
    cellW = boardW / kHexCols;
    cellH = cellW * 1.05;
    boardX = 20 * scale;
    boardY = 64 * scale;
  }

  @override
  void start(LevelDef def,
      {required MiniGameHost host, int shields = 1, int hue = 200}) {
    _def = def;
    _host = host;
    for (final col in grid) {
      for (var r = 0; r < kHexRows; r++) {
        col[r] = null;
      }
    }
    falling = null;
    fx.clear();
    _score = 0;
    _perfects = 0;
    _combo = 0;
    _shields = shields;
    _over = false;
    _reached = false;
    time = 0;
    shake = 0;
    flash = 0;
    _spawn();
    host.playSound('start');
  }

  /// Zorlukla ağırlaşan sayı zarı.
  int _roll() {
    final r = _rnd.nextDouble();
    final s = _def.speed;
    if (r < 0.60 - s * 0.05) return 2;
    if (r < 0.88 - s * 0.03) return 4;
    return 8;
  }

  void _spawn() {
    falling = FallingHex(_rnd.nextInt(kHexCols), _roll(), 0);
  }

  /// Dokun: x'e göre sütun seç, parça o sütuna düşer (havada yönlendirilebilir).
  @override
  void onTap(Offset local) {
    if (_over || falling == null) return;
    final col =
        (((local.dx - boardX) / cellW).floor()).clamp(0, kHexCols - 1);
    // dolu sütuna yönlendirme yok sayılır (taşma yalnız inişte)
    if (grid[col][0] != null) return;
    falling!.col = col;
    falling!.speed = 3.0;
    _host?.haptic(4);
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    shake = math.max(0, shake - dt * 40);
    flash = math.max(0, flash - dt * 3);
    for (var i = fx.length - 1; i >= 0; i--) {
      fx[i].life += dt;
      if (fx[i].life > 0.35) fx.removeAt(i);
    }
    for (final col in grid) {
      for (final c in col) {
        if (c != null) c.popT = math.min(1, c.popT + dt * 4);
      }
    }

    final f = falling;
    if (f != null) {
      f.y += f.speed * dt;
      if (f.y >= 1) {
        _land(f);
      }
    }
  }

  void _land(FallingHex f) {
    falling = null;
    final col = f.col;
    // alttan ilk boş satır (0 = üst, 5 = taban)
    var r = kHexRows - 1;
    while (r >= 0 && grid[col][r] != null) {
      r--;
    }
    if (r < 0) {
      _overflow();
      return;
    }
    grid[col][r] = HexCell(f.value);
    _host?.playSound('place');
    // zincirli birleşme: ALTINDAKI aynı sayıyla katlanır, aşağı taşar
    var merged = false;
    while (r + 1 < kHexRows &&
        grid[col][r + 1] != null &&
        grid[col][r]!.value == grid[col][r + 1]!.value) {
      final below = grid[col][r + 1]!;
      below.value *= 2;
      below.popT = 0;
      grid[col][r] = null;
      _score += below.value;
      _combo++;
      merged = true;
      fx.add(MergeFx(col, r + 1));
      _host?.playSound('coin', combo: _combo);
      _host?.haptic(8);
      r++; // birleşen hücrenin yeni yeri
    }
    if (merged) {
      if (_combo >= 3) {
        _perfects++;
        _host?.playSound('perfect', combo: _combo);
        flash = 0.2;
      }
      if (_def.target > 0 && _score >= _def.target) {
        _win();
        return;
      }
    } else {
      _combo = 0;
    }
    _spawn();
  }

  void _overflow() {
    if (_shields > 0) {
      _shields--;
      // taşma kalkanı: en dolu sütunun alt 2 hücresini temizle + yeni parça
      var bestCol = 0, bestCount = -1;
      for (var c = 0; c < kHexCols; c++) {
        final n = grid[c].where((e) => e != null).length;
        if (n > bestCount) {
          bestCount = n;
          bestCol = c;
        }
      }
      for (var r = kHexRows - 2; r < kHexRows; r++) {
        grid[bestCol][r] = null;
      }
      _combo = 0;
      flash = 0.3;
      _host?.playSound('shield');
      _host?.haptic(25);
      _spawn();
      return;
    }
    _over = true;
    _combo = 0;
    _host?.playSound('lose');
    _host?.haptic(50);
    _host?.onEvent('lose', data: {'points': _score});
  }

  void _win() {
    _over = true;
    _reached = true;
    _host?.playSound('win');
    _host?.haptic(30);
    _host?.onEvent('win', data: {'points': _score});
  }

  /// Test kanca: kalkan sayısını doğrudan ayarla.
  void setShieldsForTest(int n) => _shields = n;

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

    // hücreler (altıgen stil)
    for (var c = 0; c < kHexCols; c++) {
      for (var r = 0; r < kHexRows; r++) {
        final cell = grid[c][r];
        final cx = boardX + c * cellW + cellW / 2;
        final cy = boardY + r * cellH + cellH / 2;
        if (cell == null) {
          _drawHex(canvas, cx, cy, cellW * 0.42,
              Paint()..color = Colors.white.withValues(alpha: .045), null);
          continue;
        }
        final hue = _hueFor(cell.value).toDouble();
        final grow = 0.6 + 0.4 * cell.popT;
        final rectPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _hsl(hue, 92, 62),
              _hsl(hue, 86, 44),
            ],
          ).createShader(
              Rect.fromCenter(center: Offset(cx, cy), width: cellW, height: cellH));
        _drawHex(canvas, cx, cy, cellW * 0.44 * grow, rectPaint,
            Colors.white.withValues(alpha: .3));
        // sayı
        final tp = TextPainter(
          text: TextSpan(
              text: '${cell.value}',
              style: TextStyle(
                  fontSize: cellW * 0.34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
      }
    }

    // düşen parça — hedef satıra süzülür
    final f = falling;
    if (f != null) {
      var r = kHexRows - 1;
      while (r >= 0 && grid[f.col][r] != null) {
        r--;
      }
      final ty = r < 0 ? boardY : boardY + r * cellH + cellH / 2;
      final cx = boardX + f.col * cellW + cellW / 2;
      final cy = -cellH + (ty + cellH) * f.y;
      final hue = _hueFor(f.value).toDouble();
      _drawHex(
          canvas,
          cx,
          cy,
          cellW * 0.44,
          Paint()
            ..shader = LinearGradient(colors: [
              _hsl(hue, 92, 64),
              _hsl(hue, 86, 46),
            ]).createShader(Rect.fromCenter(
                center: Offset(cx, cy), width: cellW, height: cellH)),
          Colors.white.withValues(alpha: .5));
    }

    // birleşme parıltıları
    for (final e in fx) {
      final t = e.life / 0.35;
      final cx = boardX + e.col * cellW + cellW / 2;
      final cy = boardY + e.row * cellH + cellH / 2;
      canvas.drawCircle(
        Offset(cx, cy),
        cellW * (0.4 + t * 0.9),
        Paint()
          ..color = Colors.white.withValues(alpha: (1 - t) * .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - t) + 1,
      );
    }

    canvas.restore();
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * .4));
    }
  }

  void _drawHex(
      Canvas canvas, double cx, double cy, double r, Paint? fill, Color? border) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final px = cx + r * math.cos(a);
      final py = cy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    if (fill != null) canvas.drawPath(path, fill);
    if (border != null) {
      canvas.drawPath(
          path,
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
  }

  int _hueFor(int v) {
    final t = (math.log(v) / math.ln2).round().clamp(1, 12);
    return (t * 34) % 360;
  }
}

/// HSL yardımcısı.
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
