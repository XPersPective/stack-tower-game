/// ADR-009 — yapı parçalarını neon stilinde çizen animasyonlu sanat.
/// İnşa edilen parçalar dolu + glow; edilmemişler kesikli blueprint silüeti
/// (merak/anticipation — DESIGN-V2 §3.2).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/construction.dart';
import '../theme/tokens.dart';

class ConstructionArt extends StatefulWidget {
  const ConstructionArt({
    super.key,
    required this.spec,
    required this.built,
    required this.total,
    this.size = 190,
  });

  final StructureSpec spec;
  final int built;
  final int total;
  final double size;

  @override
  State<ConstructionArt> createState() => _ConstructionArtState();
}

class _ConstructionArtState extends State<ConstructionArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: ConstructionPainter(
            kind: widget.spec.kind,
            built: widget.built,
            t: Curves.easeOutCubic.transform(_c.value),
          ),
          size: Size.square(widget.size),
        ),
      ),
    );
  }
}

class ConstructionPainter extends CustomPainter {
  ConstructionPainter({required this.kind, required this.built, required this.t});

  final StructureKind kind;
  final int built;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final ground = h * 0.86;

    // zemin ışığı
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, ground), width: w * 0.72, height: 18),
      Paint()
        ..color = NeonPalette.cyan.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawLine(
      Offset(cx - w * 0.36, ground),
      Offset(cx + w * 0.36, ground),
      Paint()
        ..color = NeonPalette.cyan.withValues(alpha: .45)
        ..strokeWidth = 1.6,
    );

    switch (kind) {
      case StructureKind.ev:
        _ev(canvas, cx, ground, w, h);
      case StructureKind.kule:
        _kule(canvas, cx, ground, w, h);
      case StructureKind.bahce:
        _bahce(canvas, cx, ground, w, h);
      case StructureKind.anit:
        _anit(canvas, cx, ground, w, h);
    }
  }

  void _piece(Canvas c, Path p, int idx, Color col) {
    if (idx < built) {
      final isNew = idx == built - 1;
      c.save();
      if (isNew) {
        c.translate(0, (1 - t) * 24);
      }
      c.drawPath(p, Paint()..color = col.withValues(alpha: isNew ? 0.55 + 0.45 * t : 1));
      c.drawPath(
        p,
        Paint()
          ..color = Colors.white.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
      c.restore();
    } else {
      // blueprint: henüz inşa edilmedi — kesikli silüet (merak)
      c.drawPath(
        p,
        Paint()
          ..color = NeonPalette.cyan.withValues(alpha: .32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _ev(Canvas c, double cx, double ground, double w, double h) {
    final bw = w * 0.42, bh = h * 0.24;
    _piece(
        c,
        Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - bw / 2 - 6, ground - 8, bw + 12, 10),
              const Radius.circular(3))),
        0,
        const Color(0xFF2A3B6B));
    _piece(c, Path()..addRect(Rect.fromLTWH(cx - bw / 2, ground - 8 - bh, bw, bh)), 1,
        const Color(0xFF3D5AA8));
    _piece(
        c,
        Path()
          ..moveTo(cx - bw / 2 - 8, ground - 8 - bh)
          ..lineTo(cx, ground - 8 - bh - h * 0.16)
          ..lineTo(cx + bw / 2 + 8, ground - 8 - bh)
          ..close(),
        2,
        const Color(0xFF7A5BD8));
    final wy = ground - 8 - bh * 0.5;
    if (built > 3) {
      final a = 0.35 + 0.65 * t;
      c.drawCircle(Offset(cx, wy), 13,
          Paint()
            ..color = NeonPalette.gold.withValues(alpha: 0.28 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      c.drawCircle(Offset(cx, wy), 6.5, Paint()..color = NeonPalette.gold.withValues(alpha: a));
    } else {
      _piece(c, Path()..addOval(Rect.fromCircle(center: Offset(cx, wy), radius: 8)), 3,
          NeonPalette.gold);
    }
  }

  void _kule(Canvas c, double cx, double ground, double w, double h) {
    final bw = w * 0.20;
    _piece(c, Path()..addRect(Rect.fromLTWH(cx - bw * 0.8, ground - 10, bw * 1.6, 10)), 0,
        const Color(0xFF2A3B6B));
    _piece(
        c,
        Path()..addRect(Rect.fromLTWH(cx - bw / 2, ground - 10 - h * 0.42, bw, h * 0.42)),
        1,
        const Color(0xFF3D5AA8));
    _piece(
        c,
        Path()
          ..addRect(
              Rect.fromLTWH(cx - bw * 0.75, ground - 10 - h * 0.52, bw * 1.5, h * 0.10)),
        2,
        const Color(0xFF7A5BD6));
    final fy = ground - 10 - h * 0.56;
    if (built > 3) {
      final a = 0.35 + 0.65 * t;
      c.drawCircle(Offset(cx, fy), 16,
          Paint()
            ..color = NeonPalette.cyan.withValues(alpha: 0.3 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      c.drawCircle(Offset(cx, fy), 7, Paint()..color = NeonPalette.cyan.withValues(alpha: a));
    } else {
      _piece(c, Path()..addOval(Rect.fromCircle(center: Offset(cx, fy), radius: 9)), 3,
          NeonPalette.cyan);
    }
  }

  void _bahce(Canvas c, double cx, double ground, double w, double h) {
    _piece(
        c,
        Path()
          ..addOval(Rect.fromCenter(
              center: Offset(cx, ground - 4), width: w * 0.62, height: 22)),
        0,
        const Color(0xFF255C3A));
    final fence = Path();
    for (var i = -3; i <= 3; i++) {
      fence.addRect(Rect.fromLTWH(cx + i * (w * 0.09) - 2, ground - 24, 4, 20));
    }
    _piece(c, fence, 1, const Color(0xFF6FAF7E));
    final flowers = Path();
    for (var i = 0; i < 6; i++) {
      final fx = cx + (i - 2.5) * (w * 0.085);
      flowers.addOval(
          Rect.fromCircle(center: Offset(fx, ground - 30 - (i % 2) * 8.0), radius: 4));
    }
    _piece(c, flowers, 2, const Color(0xFFFF8AD8));
    final pool = Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, ground + 6), width: w * 0.34, height: 14));
    if (built > 3) {
      c.drawPath(pool, Paint()..color = NeonPalette.cyan.withValues(alpha: 0.30 + 0.4 * t));
    } else {
      _piece(c, pool, 3, NeonPalette.cyan);
    }
  }

  void _anit(Canvas c, double cx, double ground, double w, double h) {
    final base = Path();
    for (var i = 0; i < 3; i++) {
      base.addRect(Rect.fromLTWH(cx - w * (0.30 - i * 0.06), ground - 8 - i * 8.0,
          w * (0.60 - i * 0.12), 8));
    }
    _piece(c, base, 0, const Color(0xFF3A3A6A));
    _piece(
        c,
        Path()
          ..moveTo(cx - w * 0.09, ground - 32)
          ..lineTo(cx + w * 0.09, ground - 32)
          ..lineTo(cx + w * 0.05, ground - 32 - h * 0.34)
          ..lineTo(cx - w * 0.05, ground - 32 - h * 0.34)
          ..close(),
        1,
        const Color(0xFF6C6CD8));
    final ty = ground - 36 - h * 0.38;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 13.0 : 5.5;
      final ang = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(cx + math.cos(ang) * r, ty + math.sin(ang) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    if (built > 2) {
      final a = 0.4 + 0.6 * t;
      c.drawPath(
          star,
          Paint()
            ..color = NeonPalette.star.withValues(alpha: a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6));
      c.drawPath(star, Paint()..color = NeonPalette.star.withValues(alpha: a));
    } else {
      _piece(c, Path()..addOval(Rect.fromCircle(center: Offset(cx, ty), radius: 12)), 2,
          NeonPalette.star);
    }
  }

  @override
  bool shouldRepaint(covariant ConstructionPainter old) =>
      old.built != built || old.t != t || old.kind != kind;
}
