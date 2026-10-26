/// SORT — Sırala (DESIGN-V2 §3.1 tür 7, sort fiili).
/// Tek girdi: dokun-dokun (sütun seç → hedef sütuna taşı). Renkli topları
/// kendi sütunlarına ayır. Hamle bütçesi biterse kaybedersin.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

class SortGame implements MiniGame {
  @override
  GameKind get kind => GameKind.sort;

  static const int capacity = 4;

  /// [rng] yalnızca testlerde tohumlamak için; oyunda varsayılan rastgele.
  SortGame([math.Random? rng]) : _rnd = rng ?? math.Random();

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  /// Her sütun bir renk yığını (renk indeksi 0..n-1). start() içinde kurulur.
  List<List<int>> stacks = [];
  int? selected;
  int colors = 4;

  /// Sütun sayısı = renk sayısı + 1 (su sıralama standardı: en az bir boş
  /// sütun yoksa hiçbir dağıtım çözülemez). start() içinde yeniden kurulur.
  int columns = 4;
  int movesLeft = 0;

  /// Kurulan tahtanın çözücü-optimal hamle sayısı (bütçe güvencesi için).
  int _dealtOptimal = 0;

  /// Dağıtım denemelerinde çözücünün taramasına izin verilen toplam durum
  /// üst sınırı — uç durumda start() süresi sınırlı kalır (PB-027 MINOR).
  static const int maxDealWork = 120000;

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1;
  bool _over = false, _reached = false;
  double time = 0, shake = 0, flash = 0;
  final math.Random _rnd;

  @override
  int get score => _score;
  @override
  int get target => colors;
  @override
  int get combo => _combo;
  @override
  int get shieldsLeft => _shields;
  @override
  bool get isOver => _over;

  /* ---- test kancaları ---- */
  @visibleForTesting
  List<List<int>> get stacksForTest => stacks;
  @visibleForTesting
  int? get selectedForTest => selected;
  @visibleForTesting
  int get movesLeftForTest => movesLeft;
  @visibleForTesting
  void setMovesForTest(int n) => movesLeft = n;
  @visibleForTesting
  void tapColumnForTest(int c) => _tapColumn(c);

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
    selected = null;
    time = 0;
    shake = 0;
    flash = 0;
    // renk sayısı dünyayla artar (3 → 4)
    colors = def.stage >= 5 ? 4 : 3;
    columns = colors + 1;
    stacks = List.generate(columns, (_) => <int>[]);
    _deal();
    // Bütçe en az çözücünün optimalinden `capacity` fazlası: formül renk/kapasite
    // büyüdüğünde küçük kalırsa bile tahta sessizce kazanılamaz hâle gelmez.
    movesLeft = math.max(
        colors * capacity + 6 + def.stage, _dealtOptimal + capacity);
    host.playSound('start');
  }

  /// Dağıtım: her renkten `capacity` topu karıp dağıtır; tahta BFS çözücüyle
  /// doğrulanana (ve dağıtımda bitmemiş olana) dek yeniden dener. Çözücünün
  /// toplam taraması `maxDealWork`'ü aşarsa (pratikte ~2 denemede bulunur)
  /// ilk iki sütunun son topları takaslanmış 3 hamlede çözülen tahta kurulur.
  void _deal() {
    var work = 0;
    for (var attempt = 0; attempt < 40; attempt++) {
      stacks = List.generate(columns, (_) => <int>[]);
      final pool = <int>[
        for (var c = 0; c < colors; c++) ...List.filled(capacity, c)
      ];
      pool.shuffle(_rnd);
      var i = 0;
      for (var col = 0; col < columns && i < pool.length; col++) {
        for (var k = 0; k < capacity && i < pool.length; k++) {
          stacks[col].add(pool[i++]);
        }
      }
      if (_isSolved()) continue;
      final (optimal, used) = _solve(stacks);
      work += used;
      if (optimal >= 0) {
        _dealtOptimal = optimal;
        return;
      }
      if (work > maxDealWork) break;
    }
    stacks = List.generate(columns, (_) => <int>[]);
    for (var c = 0; c < colors; c++) {
      stacks[c] = List.filled(capacity, c, growable: true);
    }
    stacks[0][capacity - 1] = 1;
    stacks[1][capacity - 1] = 0;
    _dealtOptimal = 3; // takaslı iki topu boş sütun üzerinden geri takas et
  }

  /// Su-sıralama çözücüsü (BFS; kanonik durum = sütun dizeleri sıralı, böylece
  /// simetrik sütunlar tek durum sayılır). Hedef: her sütun boş ya da tek
  /// renk+dolu. Anlamsız hamleler budanır. Döndürdüğü kayıt:
  /// (optimal hamle sayısı, taramaya alınan durum sayısı); optimal = -1 →
  /// `maxStates` aşıldı ya da çözüm yok (dağıtım yeniden deneneceği için
  /// güvenli taraf).
  static (int, int) _solve(List<List<int>> board) {
    bool solved(List<List<int>> b) => b.every(
        (s) => s.isEmpty || (s.length == capacity && s.every((e) => e == s.first)));
    if (solved(board)) return (0, 1);

    String key(List<List<int>> b) =>
        (b.map((s) => s.join(',')).toList()..sort()).join('|');
    final seen = <String>{key(board)};
    final queue = <List<List<int>>>[
      [for (final s in board) List<int>.of(s)]
    ];
    final depths = <int>[0];
    const maxStates = 60000;
    var head = 0;
    while (head < queue.length) {
      if (seen.length > maxStates) return (-1, seen.length);
      final b = queue[head];
      final depth = depths[head];
      head++;
      for (var f = 0; f < b.length; f++) {
        final from = b[f];
        if (from.isEmpty) continue;
        final mono = from.every((e) => e == from.last);
        if (mono && from.length == capacity) continue; // oturmuş sütun
        var emptyTried = false;
        for (var t = 0; t < b.length; t++) {
          if (t == f) continue;
          final to = b[t];
          if (to.length >= capacity) continue;
          if (to.isEmpty) {
            if (mono || emptyTried) continue; // tek-renk→boş anlamsız; tek boş dene
            emptyTried = true;
          } else if (to.last != from.last) {
            continue;
          }
          final nb = [for (final s in b) List<int>.of(s)];
          nb[t].add(nb[f].removeLast());
          final k = key(nb);
          if (seen.contains(k)) continue;
          if (solved(nb)) return (depth + 1, seen.length);
          seen.add(k);
          queue.add(nb);
          depths.add(depth + 1);
        }
      }
    }
    return (-1, seen.length);
  }

  @visibleForTesting
  static bool isSolvable(List<List<int>> board) => _solve(board).$1 >= 0;

  /// Tahtanın çözücü-optimal hamle sayısı; -1 → çözüm yok ya da tarama sınırı.
  @visibleForTesting
  static int optimalMoves(List<List<int>> board) => _solve(board).$1;

  @override
  void onTap(Offset local) {
    if (_over) return;
    final col = _columnAt(local);
    if (col == null) return;
    _tapColumn(col);
  }

  void _tapColumn(int col) {
    if (_over) return;
    if (selected == null) {
      if (stacks[col].isEmpty) return;
      selected = col;
      _host?.haptic(5);
      return;
    }
    if (selected == col) {
      selected = null;
      return;
    }
    final from = selected!;
    final ball = stacks[from].last;
    final target = stacks[col];
    final canMove = target.length < capacity && (target.isEmpty || target.last == ball);
    if (!canMove) {
      // geçersiz taşıma: seçim yeni sütuna geçer (ceza yok — akış bozulmaz)
      selected = col;
      shake = 4;
      _host?.haptic(8);
      return;
    }
    stacks[from].removeLast();
    target.add(ball);
    selected = null;
    movesLeft--;
    // "mükemmel": aynı renkten 2+ topu tek hamlede doğru sütuna oturtmak
    final run = target.length;
    if (run >= 2 && target.every((e) => e == ball)) {
      _perfects++;
      _combo++;
    } else {
      _combo = 0;
    }
    _host?.playSound(run == capacity && target.every((e) => e == ball) ? 'perfect' : 'place',
        combo: _combo);
    _host?.haptic(10);
    shake = 3;

    // sütun tamamlandı mı? (tek renk + dolu)
    if (target.length == capacity && target.every((e) => e == ball)) {
      _score++;
      flash = 0.25;
      shake = 9;
      _host?.playSound('coin');
      _host?.haptic(22);
      _host?.onEvent('column', data: {'color': ball});
    }
    // Kazanma koşulu tahtanın çözülmüş olmasıdır; skor yalnızca hamleyle
    // tamamlanan sütunları sayar (dağıtımda hazır gelen sütun sayılmaz).
    if (_isSolved()) {
      _win();
      return;
    }
    if (movesLeft <= 0) {
      if (_shields > 0) {
        // kalkan: kaybı bir kez iter — ekstra `capacity` hamle hakkı verir
        _shields--;
        movesLeft += capacity;
        flash = 0.35;
        _host?.playSound('shield');
        _host?.haptic(30);
        _host?.onEvent('shield', data: {'left': _shields});
      } else {
        _lose();
      }
    }
  }

  bool _isSolved() {
    for (final s in stacks) {
      if (s.isEmpty) continue;
      if (s.length != capacity) return false;
      if (!s.every((e) => e == s.first)) return false;
    }
    return true;
  }

  int? _columnAt(Offset local) {
    final rect = _boardRect();
    if (local.dy < rect.top - 30 || local.dy > rect.bottom + 30) return null;
    final cw = rect.width / columns;
    final idx = ((local.dx - rect.left) / cw).floor();
    if (idx < 0 || idx >= columns) return null;
    return idx;
  }

  Rect _boardRect() {
    final bw = w * 0.86;
    return Rect.fromLTWH((w - bw) / 2, h * 0.28, bw, h * 0.42);
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

  /// Renk paleti: tema glow'undan türetilir (türler arası görsel tutarlılık).
  Color _colorOf(int c) {
    const hues = [190, 48, 320, 130];
    return HSLColor.fromAHSL(1, hues[c % hues.length].toDouble(), .92, .60).toColor();
  }

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
    final rect = _boardRect();
    final cw = rect.width / columns;
    final tubeW = cw * 0.56;
    final tubeH = rect.height;

    for (var c = 0; c < columns; c++) {
      final cx = rect.left + c * cw + cw / 2;
      final tube = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - tubeW / 2, rect.top, tubeW, tubeH),
          Radius.circular(tubeW / 2));
      canvas.drawRRect(tube, Paint()..color = Colors.white.withValues(alpha: .06));
      canvas.drawRRect(
          tube,
          Paint()
            ..color = selected == c
                ? Colors.white.withValues(alpha: .85)
                : Colors.white.withValues(alpha: .22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected == c ? 3 : 1.6);

      final ballR = tubeW * 0.38;
      for (var i = 0; i < stacks[c].length; i++) {
        final by = rect.bottom - ballR * 1.15 - i * ballR * 2.1;
        final lift = selected == c && i == stacks[c].length - 1 ? -10 * scale : 0.0;
        canvas.drawCircle(
            Offset(cx, by + lift), ballR * 1.5,
            Paint()
              ..color = _colorOf(stacks[c][i]).withValues(alpha: .18)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        canvas.drawCircle(Offset(cx, by + lift), ballR,
            Paint()..color = _colorOf(stacks[c][i]));
        canvas.drawCircle(Offset(cx - ballR * 0.3, by + lift - ballR * 0.3),
            ballR * 0.28, Paint()..color = Colors.white.withValues(alpha: .45));
      }
    }

    // hamle bütçesi
    final tp = TextPainter(
      text: TextSpan(
          text: 'HAMLE $movesLeft',
          style: const TextStyle(
              color: Color(0xFFEEF2FF), fontSize: 16, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, rect.bottom + 26 * scale));
    canvas.restore();

    if (flash > 0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = Colors.white.withValues(alpha: flash * .3));
    }
  }
}
