/// Dünya anıtı töreni görseli — ışık köprüleri (PB-031 sonrası premium polish).
/// Tamamlanan her dünya için merkezde yükselen neon anıt, çevresindeki
/// adalara ışık köprüleriyle bağlanır; yükselen yıldız parçacıklarıyla taçlanır.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

Color _hsl(double h, double s, double l, [double a = 1]) =>
    HSLColor.fromAHSL(a, ((h % 360) + 360) % 360, s.clamp(0, 100), l.clamp(0, 100))
        .toColor();

class MonumentCeremony extends StatefulWidget {
  const MonumentCeremony({super.key, required this.stage, this.size = 240});
  final int stage;
  final double size;

  @override
  State<MonumentCeremony> createState() => _MonumentCeremonyState();
}

class _MonumentCeremonyState extends State<MonumentCeremony>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = kThemes[widget.stage.clamp(0, kThemes.length - 1)];
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _MonumentPainter(
            hue: theme.glow.toDouble(),
            accent: theme.hues.isNotEmpty ? theme.hues[0].toDouble() : theme.glow.toDouble(),
            t: _c.value,
          ),
          size: Size.square(widget.size),
        ),
      ),
    );
  }
}

class _MonumentPainter extends CustomPainter {
  _MonumentPainter({required this.hue, required this.accent, required this.t});
  final double hue;
  final double accent;
  final double t; // 0..1 faz

  Offset _node(int i, int n, double cx, double cy, double rx, double ry) {
    final a = -math.pi / 2 + i * (math.pi * 2 / n);
    return Offset(cx + math.cos(a) * rx, cy + math.sin(a) * ry);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.66;
    final nodes = 5;
    final rx = size.width * 0.40;
    final ry = size.height * 0.26;

    final colorCore = _hsl(hue, 85, 62);
    final colorAccent = _hsl(accent, 80, 60);

    // --- ışık köprüleri (merkez ↔ ada düğümleri) ---
    for (var i = 0; i < nodes; i++) {
      final p = _node(i, nodes, cx, cy, rx, ry);
      final pulse = 0.35 + 0.25 * math.sin(t * math.pi * 2 + i * 1.3);
      final bridge = Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, cy),
          p,
          [
            colorCore.withValues(alpha: pulse),
            colorAccent.withValues(alpha: pulse * 0.25),
          ],
        )
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      // kesik çizgi hissi: çizgiyi birkaç segmente bölerek
      const seg = 14;
      for (var s = 0; s < seg; s++) {
        final a0 = s / seg;
        final a1 = (s + 0.55) / seg;
        final x0 = ui.Offset.lerp(Offset(cx, cy), p, a0)!;
        final x1 = ui.Offset.lerp(Offset(cx, cy), p, a1)!;
        canvas.drawLine(x0, x1, bridge);
      }
      // köprü üzerinde ilerleyen ışık noktası
      final dotT = ((t + i * 0.21) % 1.0);
      final dot = ui.Offset.lerp(Offset(cx, cy), p, dotT)!;
      final glowDot = Paint()
        ..color = colorAccent.withValues(alpha: 0.9 * (1 - dotT * 0.6))
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
      canvas.drawCircle(dot, 3.2, glowDot);

      // ada düğümü (küçük parlayan ada)
      final nodeGlow = Paint()
        ..color = colorAccent.withValues(alpha: 0.5)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
      canvas.drawCircle(p, 9, nodeGlow);
      canvas.drawCircle(p, 4.5, Paint()..color = _hsl(accent, 90, 72));
    }

    // --- merkez anıtı (yükselen tapered obelisk) ---
    final breathe = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final monumentH = size.height * 0.42 * (0.94 + 0.06 * breathe);
    final baseW = size.width * 0.10;
    final topW = baseW * 0.34;
    final top = cy - monumentH;
    final halo = Paint()
      ..color = colorCore.withValues(alpha: 0.22 + 0.12 * breathe)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 26);
    canvas.drawCircle(Offset(cx, cy - monumentH * 0.55), monumentH * 0.5, halo);

    final body = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, top),
        Offset(cx, cy),
        [
          colorCore.withValues(alpha: 0.95),
          _hsl(hue, 70, 40).withValues(alpha: 0.9),
        ],
      );
    final path = ui.Path()
      ..moveTo(cx - baseW / 2, cy)
      ..lineTo(cx - topW / 2, top)
      ..lineTo(cx + topW / 2, top)
      ..lineTo(cx + baseW / 2, cy)
      ..close();
    canvas.drawPath(path, body);
    // kenar vurgusu
    final edge = Paint()
      ..color = _hsl(accent, 95, 80).withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, edge);
    // tepede ışık kristali
    final tipGlow = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    canvas.drawCircle(Offset(cx, top), 5 + 3 * breathe, tipGlow);

    // --- yükselen yıldız parçacıkları ---
    for (var i = 0; i < 16; i++) {
      final seed = i * 12.9898;
      final baseX = (math.sin(seed) * 0.5 + 0.5) * size.width;
      final speed = 0.18 + (i % 5) * 0.05;
      final prog = ((t * speed + i * 0.137) % 1.0);
      final y = cy - prog * monumentH * 1.15;
      final a = (1 - prog) * 0.8;
      final r = 1.2 + (i % 3) * 0.7;
      final sp = Paint()
        ..color = _hsl(accent, 90, 80).withValues(alpha: a)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
      canvas.drawCircle(Offset(baseX, y), r, sp);
    }
  }

  @override
  bool shouldRepaint(covariant _MonumentPainter old) => old.t != t;
}
