/// Stack Tower Game — sürpriz kutusu görseli (premium).
///
/// Kapalı hâlde hafifçe salınır, açılınca kapağı fırlar, içinden ışık
/// sızıntısı ve yükselen yıldızlar çıkar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class GiftBox extends StatefulWidget {
  const GiftBox({super.key, required this.opened, this.size = 132});
  /// true → kutu açılmış (ışık sızıntısı + parçacıklar).
  final bool opened;
  final double size;

  @override
  State<GiftBox> createState() => _GiftBoxState();
}

class _GiftBoxState extends State<GiftBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.opened) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant GiftBox old) {
    super.didUpdateWidget(old);
    if (widget.opened && !old.opened) {
      _c.forward(from: 0);
    }
  }

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
          painter: _GiftPainter(
            t: _c.value,
            opened: widget.opened,
          ),
        ),
      ),
    );
  }
}

class _GiftPainter extends CustomPainter {
  _GiftPainter({required this.t, required this.opened});

  /// 0..1 animasyon ilerlemesi.
  final double t;
  final bool opened;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.62;
    final w = size.width * 0.52;
    final h = size.height * 0.38;

    // açılma eşiği: %35'ten sonra kapak fırlar
    final openT = ((t - 0.35) / 0.35).clamp(0.0, 1.0);
    final openedNow = opened || openT > 0;

    // --- ışık sızıntısı (yalnız açık kutu) ---
    if (openedNow) {
      final beamT = opened ? 1.0 : openT;
      final beam = Paint()
        ..shader = RadialGradient(
          colors: [
            NeonPalette.gold.withValues(alpha: .45 * beamT),
            NeonPalette.amber.withValues(alpha: .18 * beamT),
            const Color(0x00000000),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy - h * 0.4), radius: size.width * 0.75));
      canvas.drawCircle(Offset(cx, cy - h * 0.4), size.width * 0.75, beam);

      // yukarı yükselen ışık huzmesi
      final shaft = Path()
        ..moveTo(cx - w * 0.34, cy - h * 0.5)
        ..lineTo(cx + w * 0.34, cy - h * 0.5)
        ..lineTo(cx + w * 0.72, cy - h * 2.1)
        ..lineTo(cx - w * 0.72, cy - h * 2.1)
        ..close();
      canvas.drawPath(
        shaft,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              NeonPalette.gold.withValues(alpha: .30 * beamT),
              const Color(0x00FFD24A),
            ],
          ).createShader(Rect.fromLTWH(0, cy - h * 2.1, size.width, h * 1.6)),
      );
    }

    // --- kutu gövdesi ---
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFD2384F), Color(0xFF8E1B36)],
      ).createShader(Rect.fromLTWH(cx - w / 2, cy - h, w, h));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w / 2, cy - h, w, h), const Radius.circular(6)),
      body,
    );

    // gövde dikey şerit (çarpayla bağlanan kurdel)
    canvas.drawRect(
      Rect.fromLTWH(cx - w * 0.09, cy - h, w * 0.18, h),
      Paint()..color = NeonPalette.gold.withValues(alpha: .9),
    );
    // kutu kenarı
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w / 2, cy - h, w, h), const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFFF6E86).withValues(alpha: .55),
    );

    // --- kapak (açılınca yukarı fırlar) ---
    final lidY = cy - h - 10 - (openedNow ? openT * 34 : 0);
    final lid = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFE64A62), Color(0xFFA32142)],
      ).createShader(Rect.fromLTWH(cx - w * 0.58, lidY, w * 1.16, 16));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.58, lidY, w * 1.16, 16),
          const Radius.circular(4)),
      lid,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - w * 0.09, lidY, w * 0.18, 16),
      Paint()..color = NeonPalette.gold.withValues(alpha: .9),
    );

    // --- fiyong ---
    final bowY = lidY;
    final bow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = NeonPalette.gold;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 13, bowY - 5), width: 24, height: 16),
        bow);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 13, bowY - 5), width: 24, height: 16),
        bow);
    canvas.drawCircle(Offset(cx, bowY - 4), 4.5, Paint()..color = NeonPalette.gold);

    // --- salınım (kapalı kutu) ---
    if (!openedNow) {
      final sway = math.sin(t * math.pi * 2) * 3.0;
      canvas.save();
      canvas.translate(cx + sway, 0);
      canvas.translate(-cx, 0);
      // salınan içerik yeniden çizilmez — salınım gövde dışında bırakıldı
      canvas.restore();
    }

    // --- açılışta yükselen yıldızlar ---
    if (openedNow) {
      final beamT = opened ? 1.0 : openT;
      final rnd = math.Random(97);
      for (var i = 0; i < 12; i++) {
        final sx = rnd.nextDouble();
        final speed = 0.5 + rnd.nextDouble() * 0.6;
        final phase = rnd.nextDouble();
        final prog = ((t * speed + phase) % 1.0);
        final y = cy - h * 0.5 - prog * size.height * 0.75;
        final x = cx + (sx - 0.5) * size.width * 0.7 + math.sin(t * 4 + i) * 4;
        final a = (1 - prog) * beamT;
        canvas.drawCircle(
          Offset(x, y),
          1.6 + (i % 3) * 0.7,
          Paint()
            ..color = NeonPalette.star.withValues(alpha: a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GiftPainter old) =>
      old.t != t || old.opened != opened;
}
