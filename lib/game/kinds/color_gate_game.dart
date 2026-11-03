/// RENK KAPI — Renk Geçidi (PB-041, DESIGN-20GAMES #4: Color Gate).
///
/// Color Switch DNA'sının tek-dokunuş uyarlaması: top sabit x'te düşer,
/// dokun → zıpla (C-022). Kapılar yatay salınır — yalnız TOPLA AYNI renkteki
/// pencereden geçilir; kapılar arası RENK PERDESİ topun rengini değiştirir.
/// Beceri = zamanlama (pencere süzülürken tam orada ol). Çözülebilirlik
/// inşada garanti: her kapının pencere rengi, topun o kapıya varış hue'sudur.
/// Kayıp: yanlış renge dokunmak (kalkan varsa sekme). Hedef: def.target kapı.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels.dart';
import '../mini_game.dart';

/// Canlı 6'lı palet — her kapıda en az 3 ayrı renk okunur.
const List<int> kGatePalette = [0, 40, 130, 200, 280, 330];

/// Yatay salınan kapı — duvar | pencere | duvar üç dilimi.
class Gate {
  final double y; // dünya-y (yukarı = azalır)
  double baseX; // pencere taban x (salınım merkezi)
  double winW; // pencere genişliği
  double amp; // salınım genliği
  double omega; // salınım açısal hızı
  double phase;
  final int winHue; // GEÇİLEBİLİR renk (topun varış hue'su)
  final int leftHue, rightHue;
  bool passed = false;
  double passedAt = -10;
  Gate(this.y, this.baseX, this.winW, this.amp, this.omega, this.phase,
      this.winHue, this.leftHue, this.rightHue);

  /// Anlık yatay öteleme — render ve çarpışma AYNI fonksiyonu kullanır.
  double offset(double t) => amp * math.sin(omega * t + phase);
}

/// Renk perdesi — tam genişlik bant; geçen top bu renge boyanır.
class HueBand {
  final double y;
  final int newHue;
  bool used = false;
  HueBand(this.y, this.newHue);
}

/// Zıplama/olay parıltısı.
class GateBurst {
  double x, y, life;
  GateBurst(this.x, this.y) : life = 0;
}

class ColorGateGame implements MiniGame {
  @override
  GameKind get kind => GameKind.colorGate;

  late LevelDef _def;
  MiniGameHost? _host;
  double w = 0, h = 0, scale = 1;

  // top — x sabit (Color Switch DNA'sı; beceri = zamanlama)
  double ballY = 0, vy = 0;
  int ballHue = 200;
  double ballR = 11;
  static const double _gravity = 1500;
  static const double _jumpV = -520;

  double scroll = 0; // kamera: yukarı çıkıldıkça azalır
  double time = 0, flash = 0, shake = 0;
  final List<Gate> gates = [];
  final List<HueBand> bands = [];
  final List<GateBurst> bursts = [];

  int _score = 0, _perfects = 0, _combo = 0, _shields = 1, _airStreak = 0;
  bool _over = false;
  bool _reached = false;
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
    h = math.max(420, vh);
    scale = (math.min(w / 460, h / 780)).clamp(0.6, 1.6);
    ballR = 11 * scale;
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
    _airStreak = 0;
    time = 0;
    flash = 0;
    shake = 0;
    scroll = 0;
    vy = 0;
    ballHue = 200; // palet içi — ilk kapı penceresi bunu garanti eder
    ballY = h * 0.68;
    gates.clear();
    bands.clear();
    bursts.clear();
    _buildCourse(math.max(3, def.target));
    host.playSound('start');
  }

  /// Kapı zinciri: pencere rengi = topun varış hue'su (çözülebilirlik yasası).
  /// Kapı k ile k+1 arasına renk perdesi konur; perde rengi bir SONRAKİ
  /// kapının pencere rengidir — duvarlar alternatif (görsel) tuzaktır.
  void _buildCourse(int gateCount) {
    const firstGateY = -320.0;
    const spacing = 300.0;
    var hue = ballHue;
    var y = firstGateY;
    for (var k = 0; k < gateCount; k++) {
      if (k > 0) {
        // perde: mevcut hue'dan FARKLI yeni renk verir
        final idx = kGatePalette.indexOf(hue);
        final next = kGatePalette[(idx + 1 + _rnd.nextInt(kGatePalette.length - 1)) %
            kGatePalette.length];
        bands.add(HueBand(y + spacing * 0.5, next));
        hue = next;
      }
      final winW = (118 - 3 * k).clamp(72.0, 118.0) * scale;
      final winHue = hue;
      // duvarlar: pencere renginden farklı iki renk
      final others =
          kGatePalette.where((c) => c != winHue).toList()..shuffle(_rnd);
      final baseX = w * 0.18 + _rnd.nextDouble() * (w * 0.64 - winW);
      gates.add(Gate(
        y,
        baseX,
        winW,
        w * 0.22,
        1.1 + 0.13 * k,
        _rnd.nextDouble() * math.pi * 2,
        winHue,
        others[0],
        others[1],
      ));
      y -= spacing;
    }
  }

  /// Pencerenin anlık mutlak aralığı (salınımla kayar).
  (double, double) _windowRange(Gate g) {
    final ox = g.offset(time);
    return (g.baseX + ox, g.baseX + ox + g.winW);
  }

  @override
  void onTap(Offset local) {
    if (_over) return;
    vy = _jumpV * scale;
    _host?.haptic(4);
    bursts.add(GateBurst(w / 2, ballY + ballR));
  }

  @override
  void tick(double dt) {
    if (_over) return;
    time += dt;
    flash = math.max(0, flash - dt * 3);
    shake = math.max(0, shake - dt * 55);

    // fizik: yerçekimi
    vy += _gravity * scale * dt;
    ballY += vy * dt;

    // zemin: canlı sekme (ölüm yok; kombo sıfırlanır — tırmanma baskısı)
    if (ballY > h - ballR) {
      ballY = h - ballR;
      vy = _jumpV * scale * 0.62;
      if (_combo > 0 || _airStreak > 0) {
        _combo = 0;
        _airStreak = 0;
        _host?.onEvent('combo_break');
      }
    }
    // tavan üstü: kamera topu %34 hattında tutar (dünya aşağı akar)
    if (ballY < h * 0.34) {
      scroll -= (h * 0.34 - ballY);
      ballY = h * 0.34;
    }
    final worldY = scroll + ballY;

    // kapılar: çarpışma + geçiş
    for (final g in gates) {
      final screenY = g.y - scroll;
      if (screenY < -80 || screenY > h + 80) continue;
      // geçiş skoru: top merkezi kapı çizgisini yukarı yönledi geçti
      if (!g.passed && worldY < g.y) {
        g.passed = true;
        g.passedAt = time;
        _score++;
        _airStreak++;
        if (_airStreak >= 2) _perfects++;
        _combo++;
        _host?.playSound('perfect', combo: _combo);
        _host?.haptic(8);
        bursts.add(GateBurst(w / 2, screenY));
        if (_score >= _def.target) {
          _win();
          return;
        }
      }
      // yeni geçişte 0.25s bağışıklık (pencere süzülürken geri öldürme yok)
      if (g.passed && time - g.passedAt < 0.25) continue;
      // bant çarpışması: |kapıY - topY| < yarıçap+yarıkalınlık
      if ((screenY - ballY).abs() > ballR + 7) continue;
      final (wx0, wx1) = _windowRange(g);
      // topun kapladığı dilimler: pencere rengiyle kesişiyor mu?
      final onWindow = ballXOverlap(wx0, wx1);
      if (!onWindow) {
        _hit();
        return;
      }
    }

    // renk perdeleri: tam genişlik — geçen top boyanır
    for (final b in bands) {
      final screenY = b.y - scroll;
      if (screenY < -40 || screenY > h + 40) continue;
      if ((screenY - ballY).abs() < ballR + 6) {
        if (ballHue != b.newHue) {
          ballHue = b.newHue;
          flash = 0.16;
          _host?.playSound('coin');
          _host?.haptic(6);
        }
        b.used = true;
      }
    }

    // parçacıklar
    for (var i = bursts.length - 1; i >= 0; i--) {
      bursts[i].life += dt;
      bursts[i].y += 70 * dt;
      if (bursts[i].life > 0.6) bursts.removeAt(i);
    }
  }

  /// Top dairesi [x0,x1] aralığıyla kesişiyor mu (%70 tolerans — adil çarpışma).
  bool ballXOverlap(double x0, double x1) {
    const t = 0.7;
    return w / 2 + ballR * t > x0 && w / 2 - ballR * t < x1;
  }

  void _hit() {
    if (_shields > 0) {
      _shields--;
      vy = 320 * scale; // kalkan: aşağı sektir
      ballY -= 2; // banttan çık
      flash = 0.3;
      shake = 14;
      _combo = 0;
      _airStreak = 0;
      _host?.playSound('shield');
      _host?.haptic(25);
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

  @override
  void stop() {}

  @override
  MiniGameResult result() =>
      MiniGameResult(points: _score, perfects: _perfects, reached: _reached);

  @override
  void render(Canvas canvas, Size size) {
    // ilk kare resize'tan önce gelebilir — w/h=0 iken çizim NaN üretir
    if (w <= 0 || h <= 0) return;
    final theme = _def.theme;
    // arka plan: topun rengine göre canlı nefes (DESIGN #4 imzası)
    final bgHue = (ballHue * 0.35 + theme.glow * 0.65) % 360;
    final bgRect = Offset.zero & size;
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _hsl(bgHue, 45, 12),
            _hsl(theme.glow.toDouble(), 40, 9),
            _hsl(bgHue, 42, 8),
          ],
        ).createShader(bgRect),
    );
    // yıldız parallax — yükseldikçe aşağı süzülür
    for (var i = 0; i < 26; i++) {
      final sx = (i * 97.3) % w;
      final sy = ((i * 53.7 - scroll * 0.4) % h + h) % h;
      canvas.drawCircle(Offset(sx, sy), 1.0,
          Paint()..color = Colors.white.withValues(alpha: .16));
    }

    canvas.save();
    if (shake > 0.2) {
      canvas.translate((_rnd.nextDouble() - 0.5) * shake,
          (_rnd.nextDouble() - 0.5) * shake);
    }

    // kapılar
    for (final g in gates) {
      final screenY = g.y - scroll;
      if (screenY < -60 || screenY > size.height + 60) continue;
      final ox = g.offset(time);
      _drawSegment(canvas, ox, g.baseX + ox, screenY, g.leftHue,
          g.leftHue == ballHue);
      _drawSegment(canvas, g.baseX + ox, g.baseX + ox + g.winW, screenY,
          g.winHue, g.winHue == ballHue, window: true);
      _drawSegment(canvas, g.baseX + ox + g.winW, w + ox, screenY, g.rightHue,
          g.rightHue == ballHue);
    }

    // renk perdeleri — yeni hue'nun tam genişlik neon bandı
    for (final b in bands) {
      final screenY = b.y - scroll;
      if (screenY < -30 || screenY > size.height + 30) continue;
      final c = _hsl(b.newHue.toDouble(), 95, 62);
      final pulse = b.used ? 0.35 : 0.55 + 0.25 * math.sin(time * 5);
      canvas.drawRect(
        Rect.fromLTWH(0, screenY - 2.5, w, 5),
        Paint()
          ..color = c.withValues(alpha: pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, screenY - 1, w, 2),
        Paint()..color = c.withValues(alpha: .9),
      );
      // merkez elmas işareti
      canvas.save();
      canvas.translate(w / 2, screenY);
      canvas.rotate(math.pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 9, height: 9),
        Paint()..color = c,
      );
      canvas.restore();
    }

    // top — radial ışık çekirdeği + hale
    final bc = Offset(w / 2, ballY);
    final ballPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          _hsl(ballHue.toDouble(), 100, 78),
          _hsl(ballHue.toDouble(), 95, 52),
        ],
      ).createShader(Rect.fromCircle(center: bc, radius: ballR));
    canvas.drawCircle(bc, ballR * 1.9,
        Paint()..color = _hsl(ballHue.toDouble(), 95, 60).withValues(alpha: .14));
    canvas.drawCircle(bc, ballR, ballPaint);
    canvas.drawCircle(
      bc,
      ballR,
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // zıplama parıltıları
    for (final b in bursts) {
      final a = (1 - b.life / 0.6).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(b.x, b.y),
        5 * (1 - b.life / 0.6) + 1.5,
        Paint()
          ..color = Colors.white.withValues(alpha: a * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.restore();

    // zemin sekme çizgisi — alt neon hat
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 3, size.width, 3),
      Paint()
        ..color = _hsl(theme.glow.toDouble(), 90, 60).withValues(alpha: .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // flaş
    if (flash > 0) {
      canvas.drawRect(bgRect,
          Paint()..color = Colors.white.withValues(alpha: flash * 0.4));
    }
  }

  /// Kapı dilimi çizimi — [x0,x1] mutlak aralık; topun rengiyle eşleşen
  /// dilim nabız gibi parlar (L1 okunabilirlik: güvenli yol hep görünür).
  void _drawSegment(Canvas canvas, double x0, double x1, double y, int hue,
      bool matchesBall,
      {bool window = false}) {
    final x = math.max(x0, -40.0);
    final xEnd = math.min(x1, w + 40);
    if (xEnd - x <= 0) return;
    final rect = Rect.fromLTWH(x, y - 7, xEnd - x, 14);
    final glow = matchesBall ? 0.45 + 0.25 * math.sin(time * 6) : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()
        ..shader = LinearGradient(
          colors: [_hsl(hue.toDouble(), 95, 62), _hsl(hue.toDouble(), 90, 44)],
        ).createShader(rect),
    );
    if (glow > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect.inflate(2.5), const Radius.circular(9)),
        Paint()
          ..color = _hsl(hue.toDouble(), 100, 70).withValues(alpha: glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()
        ..color = Colors.white.withValues(alpha: window ? .65 : .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = window ? 1.6 : 1.0,
    );
  }
}

/// HSL yardımcısı (kinds katmanı scene_painter'a bağımlı değildir).
Color _hsl(double hue, double sat, double light) =>
    HSLColor.fromAHSL(1, hue % 360, sat / 100, light / 100).toColor();
