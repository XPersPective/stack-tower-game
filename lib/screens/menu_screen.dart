/// Stack Tower Game — menü ekranı (ui.js showMenu karşılığı).
/// Gökyüzü takımyıldızı + rozetler + OYNA/SERBEST/GÖREVLER/MAĞAZA.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_session.dart';
import '../theme/tokens.dart';
import 'flow_overlays.dart';
import 'router.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    final stars = session.totalStars;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0c0a20), Color(0xFF1e1046)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // gökyüzü: topladığın her yıldız gökte bir yıldız (konseptin ödülü)
              _SkyConstellation(stars: stars),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [NeonPalette.cyan, NeonPalette.magenta],
                      ).createShader(b),
                      child: Text(
                        'STACK TOWER',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              shadows: [
                                Shadow(color: NeonPalette.cyan.withValues(alpha: .6), blurRadius: 28),
                                Shadow(color: NeonPalette.magenta.withValues(alpha: .4), blurRadius: 36),
                              ],
                            ),
                      ),
                    ),
                    Text('G A M E',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: NeonPalette.textDim, letterSpacing: 12)),
                    const SizedBox(height: 10),
                    Text('★ $stars', style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: NeonPalette.star)),
                    const SizedBox(height: 34),
                    NeonButton('OYNA', () => Navigator.pushNamed(context, Routes.map)),
                    const SizedBox(height: 12),
                    NeonButton('SERBEST MOD', () => Navigator.pushNamed(context, Routes.playEndless)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: NeonButton('GÖREVLER', () => Navigator.pushNamed(context, Routes.missions))),
                        const SizedBox(width: 12),
                        Flexible(child: NeonButton('MAĞAZA', () => Navigator.pushNamed(context, Routes.shop))),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text('En iyi: ${session.state.best} · 🪙 ${session.state.coins}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              // ses düğmesi + ayarlar
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.settings),
                  icon: const Icon(Icons.settings, color: NeonPalette.textDim, size: 28),
                  tooltip: 'Ayarlar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menü göğü: 42 noktalı takımyıldız — toplam yıldıza göre yanar.
class _SkyConstellation extends StatelessWidget {
  const _SkyConstellation({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SkyPainter(stars),
        size: Size.infinite,
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.starCount);
  final int starCount;

  @override
  void paint(Canvas canvas, Size size) {
    const total = 42;
    final lit = starCount <= 0 ? 0 : (starCount * total / 450).clamp(1, total).round();
    final line = Paint()
      ..color = const Color(0x22AACDFF)
      ..strokeWidth = 1;
    var seed = 183;
    double rnd() {
      seed |= 0;
      seed = (seed + 0x6D2B79F5) & 0x7FFFFFFF;
      var t = seed ^ (seed >> 15);
      t = (t * (1 | seed)) & 0xFFFFFFFF;
      t = (t + ((t ^ (t >> 7)) * 61 & 0xFFFFFFFF)) & 0xFFFFFFFF;
      return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
    }

    final pts = <Offset>[];
    for (var i = 0; i < total; i++) {
      pts.add(Offset(size.width * (0.06 + rnd() * 0.88), size.height * (0.04 + rnd() * 0.30)));
    }
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < lit; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < lit; i++) {
      canvas.drawCircle(pts[i], 2.2, Paint()..color = const Color(0xFFFFF3C4));
    }
    for (var i = 0; i < 60; i++) {
      canvas.drawCircle(
        Offset(rnd() * size.width, rnd() * size.height),
        rnd() * 1.1 + 0.3,
        Paint()..color = Colors.white.withValues(alpha: .25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => oldDelegate.starCount != starCount;
}
