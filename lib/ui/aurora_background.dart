/// Stack Tower Game — premium arka plan katmanı.
///
/// Ekranların arkasında yaşayan "canlı gökyüzü": yavaş sürüklenen aurora
/// şeritleri, paralaks yıldız alanı, uzak gezegen ışığı ve vinyet.
/// Tek bir CustomPainter + Listenable tabanlı yeniden boyama ile çalışır;
/// her karede yeni nesne ayırmaz (60 fps bütçesini korur).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'ambient.dart';

/// Yaşayan arka plan. [child] üzerine yığılan tam ekran dekor.
///
/// [hue] dünyanın vurgu rengidir; arka plan bu renkle uyumlu aurora üretir.
/// [intensity] 0..1 → efekt yoğunluğu (düşük güç modunda düşürülür).
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.hue = 268,
    this.accentHue = 210,
    this.intensity = 1.0,
    this.showStars = true,
    this.showPlanet = true,
  });

  final Widget child;
  final double hue;
  final double accentHue;
  final double intensity;
  final bool showStars;
  final bool showPlanet;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void initState() {
    super.initState();
    // Ortam animasyonu kapalıysa (test / düşük güç) tek kare dondurulur →
    // `pumpAndSettle` sonsuz döngüye takılmaz.
    if (AmbientMotion.enabled) {
      _c.repeat();
    } else {
      _c.value = 0.18;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _AuroraPainter(
              t: _c,
              hue: widget.hue,
              accentHue: widget.accentHue,
              intensity: widget.intensity,
              showStars: widget.showStars,
              showPlanet: widget.showPlanet,
            ),
            isComplex: true,
            willChange: true,
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.hue,
    required this.accentHue,
    required this.intensity,
    required this.showStars,
    required this.showPlanet,
  });

  final Animation<double> t;
  final double hue;
  final double accentHue;
  final double intensity;
  final bool showStars;
  final bool showPlanet;

  // HSLColor.fromAHSL s/l değerlerini 0..1 aralığında bekler; çağıranlar
  // 0..100 yüzde ölçeği kullanır → burada ölçek dönüşümü yapılır.
  Color _hsl(double h, double s, double l, [double a = 1]) =>
      HSLColor.fromAHSL(
        a,
        ((h % 360) + 360) % 360,
        (s.clamp(0, 100)) / 100,
        (l.clamp(0, 100)) / 100,
      ).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final time = t.value * 60.0; // saniye

    // --- temel dikey gradyan (mürekkep → gece) ---
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _hsl(hue, 62, 9),
          _hsl(hue, 56, 13),
          _hsl(accentHue, 50, 8),
          const Color(0xFF03030A),
        ],
        stops: const [0, 0.38, 0.72, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    // --- aurora şeritleri (paralaks katmanları) ---
    // PB-033: geniş stroke + keskin birleşimler "soluk gri poligon" artefaktı
    // veriyordu — yuvarlak birleşim + daha doygun/dar şerit + yumuşak alfa.
    canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.plus);
    for (var layer = 0; layer < 3; layer++) {
      final ph = time * (0.055 + layer * 0.026) + layer * 2.1;
      final hueL = hue + layer * 14 - 10;
      final yBase = h * (0.16 + layer * 0.11) + math.sin(ph) * h * 0.035;
      final amp = h * (0.055 + layer * 0.02);
      final path = Path()..moveTo(-w * 0.1, yBase);
      path.cubicTo(
        w * 0.25,
        yBase - amp * 1.5,
        w * 0.62,
        yBase + amp * 1.7,
        w * 1.1,
        yBase - amp * 0.4,
      );
      final strokeH = h * (0.09 + layer * 0.035);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeH
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _hsl(hueL, 95, 52, 0),
            _hsl(hueL, 95, 54, 0.095 * intensity),
            _hsl(hueL + 26, 92, 60, 0.06 * intensity),
            _hsl(hueL, 95, 52, 0),
          ],
          stops: const [0, 0.4, 0.62, 1],
        ).createShader(Rect.fromLTWH(0, yBase - strokeH, w, strokeH * 2));
      canvas.drawPath(path, p);
    }
    canvas.restore();

    // --- paralaks yıldız alanı ---
    if (showStars) {
      final rnd = math.Random(20261030);
      final count = (w * h / 9000).round().clamp(30, 190);
      for (var i = 0; i < count; i++) {
        final sx = rnd.nextDouble() * w;
        final sy = rnd.nextDouble() * h * 0.72;
        final depth = 0.25 + rnd.nextDouble() * 0.75;
        final r = (0.4 + rnd.nextDouble() * 1.5) * depth;
        final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(time * (0.6 + depth) + i * 1.7));
        final c = Color.fromRGBO(226, 238, 255, tw * 0.75 * depth);
        final starPaint = Paint()..color = c;
        if (r > 1.5 && tw > 0.75) {
          // parlak yıldızlar ışın alır
          canvas.drawRect(
              Rect.fromLTWH(sx - r * 2.4, sy - 0.35, r * 4.8, 0.7), starPaint);
          canvas.drawRect(
              Rect.fromLTWH(sx - 0.35, sy - r * 2.4, 0.7, r * 4.8), starPaint);
        }
        canvas.drawCircle(Offset(sx, sy), r, starPaint);
      }
    }

    // --- uzak gezegen ışığı ---
    if (showPlanet) {
      final px = w * 0.82;
      final py = h * 0.13;
      final pr = math.min(w, h) * 0.075;
      final halo = Paint()
        ..shader = RadialGradient(
          colors: [
            _hsl(accentHue, 90, 68, 0.20 * intensity),
            _hsl(accentHue, 90, 60, 0.06 * intensity),
            _hsl(accentHue, 90, 60, 0),
          ],
          stops: const [0, 0.42, 1],
        ).createShader(Rect.fromCircle(center: Offset(px, py), radius: pr * 3.4));
      canvas.drawCircle(Offset(px, py), pr * 3.4, halo);

      final disc = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [
            _hsl(accentHue, 70, 74, 0.85),
            _hsl(accentHue, 82, 52, 0.9),
            _hsl(hue, 70, 22, 0.95),
          ],
        ).createShader(Rect.fromCircle(center: Offset(px, py), radius: pr));
      canvas.drawCircle(Offset(px, py), pr, disc);

      // gezegen halkası
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(-0.38);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: pr * 3.1, height: pr * 0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = _hsl(accentHue, 92, 76, 0.45),
      );
      canvas.restore();
    }

    // --- vinyet (kenarları koyulaştırır, içeriği öne çıkarır) ---
    final vig = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          const Color(0x00000000),
          const Color(0x33000000),
          const Color(0xB3000000),
        ],
        stops: const [0.45, 0.78, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vig);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.hue != hue ||
      old.accentHue != accentHue ||
      old.intensity != intensity ||
      old.showStars != showStars ||
      old.showPlanet != showPlanet;
}

/// Basit, tek renkli degrade zemin (iç içe kullanımda hızlı alternatif).
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.child,
    this.top = const Color(0xFF0C0A20),
    this.bottom = const Color(0xFF1E1046),
  });

  final Widget child;
  final Color top;
  final Color bottom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
      ),
      child: child,
    );
  }
}

/// Ekran köşesinde yumuşak renk lekesi — cam panelin arkasında ışık verir.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({
    super.key,
    required this.child,
    this.color = NeonPalette.cyan,
    this.radius = 260,
    this.alignment = const Alignment(-0.8, -0.9),
    this.opacity = 0.22,
  });

  final Widget child;
  final Color color;
  final double radius;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: radius / 400,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    );
  }
}
