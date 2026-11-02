/// Stack Tower Game — menü ekranı (ui.js showMenu karşılığı).
///
/// Premium katman: canlı aurora gökyüzü, nefes alan neon logo, kademeli
/// giriş animasyonları, cam panel istatistik şeridi ve dokunsal geri bildirim.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_session.dart';
import '../theme/tokens.dart';
import '../ui/ambient.dart';
import '../ui/aurora_background.dart';
import '../ui/premium_kit.dart';
import '../game/rank.dart';
import 'router.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    final stars = session.totalStars;

    return Scaffold(
      body: AuroraBackground(
        hue: 268,
        accentHue: 210,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxHeight < 680;
            return Stack(
              children: [
                // gökyüzü: topladığın her yıldız gökte bir yıldız (konseptin ödülü)
                Positioned.fill(child: _SkyConstellation(stars: stars)),
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: compact ? 6 : 24),
                          const _AnimatedLogo(),
                          SizedBox(height: compact ? 10 : 18),
                          _StatStrip(session: session),
                          SizedBox(height: compact ? 18 : 30),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 120),
                            child: GradientButton(
                              label: 'OYNA',
                              icon: Icons.play_arrow_rounded,
                              expand: true,
                              height: 60,
                              colors: const [
                                Color(0xFF2E1E86),
                                Color(0xFF12407E),
                                Color(0xFF451C7A),
                              ],
                              onTap: () =>
                                  Navigator.pushNamed(context, Routes.map),
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 200),
                            child: GradientButton(
                              label: 'SERBEST MOD',
                              icon: Icons.all_inclusive_rounded,
                              expand: true,
                              height: 52,
                              colors: const [
                                Color(0xFF243A78),
                                Color(0xFF182A52),
                              ],
                              onTap: () =>
                                  Navigator.pushNamed(context, Routes.playEndless),
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 280),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _SmallMenuButton(
                                    label: 'GÖREVLER',
                                    icon: Icons.checklist_rounded,
                                    color: NeonPalette.amber,
                                    onTap: () => Navigator.pushNamed(
                        context, Routes.missions),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.md),
                                Expanded(
                                  child: _SmallMenuButton(
                                    label: 'MAĞAZA',
                                    icon: Icons.storefront_rounded,
                                    color: NeonPalette.magenta,
                                    onTap: () => Navigator.pushNamed(
                        context, Routes.shop),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: compact ? 14 : 26),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 360),
                            child: _FooterNote(),
                          ),
                          SizedBox(height: compact ? 6 : 16),
                        ],
                      ),
                    ),
                  ),
                ),
                // ses düğmesi + ayarlar
                Positioned(
                  top: 4,
                  right: 4,
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 420),
                    child: _RoundIconButton(
                      icon: Icons.settings_rounded,
                      tooltip: 'Ayarlar',
                      onTap: () => Navigator.pushNamed(context, Routes.settings),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Nefes alan neon logo — marka adı + alt satır.
class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void initState() {
    super.initState();
    // Ortam animasyonu kapalıysa (test) logo tek karede durur.
    if (AmbientMotion.enabled) {
      _c.repeat(reverse: true);
    } else {
      _c.value = 0.5;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final glow = 22 + t * 26;
        return Column(
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [NeonPalette.cyan, Color(0xFFB8F3FF), NeonPalette.magenta],
              ).createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text(
                'STACK TOWER',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 40,
                      letterSpacing: 2.5,
                      shadows: [
                        Shadow(
                            color: NeonPalette.cyan
                                .withValues(alpha: 0.30 + t * 0.30),
                            blurRadius: glow),
                        Shadow(
                            color: NeonPalette.magenta
                                .withValues(alpha: 0.18 + t * 0.22),
                            blurRadius: glow + 14),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Opacity(
                opacity: 0.55 + 0.35 * t,
                child: Text('G A M E',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: NeonPalette.textDim,
                          letterSpacing: 12,
                        )),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// İstatistik şeridi — cam panelde yıldız / en iyi / para.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final rank = rankFor(session.state);
    return FadeSlideIn(
      delay: const Duration(milliseconds: 60),
      // PB-036 tur 7: puan/sıralama HER ZAMAN erişilebilir — şeride dokun →
      // kişisel puan & rütbe sayfası
      child: Semantics(
        button: true,
        label: 'Puan ve rütbe: ${rank.name}. Puan sayfasını aç',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => Navigator.pushNamed(context, Routes.rank),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.md),
            radius: AppRadius.pill,
            glow: false,
            child: Row(
              children: [
                // rütbe madalyonu (mini) — hiyerarşi ilk bakışta
                _RankBadge(rank: rank),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(
                        icon: StarGlyph(size: 17),
                        label: '${session.totalStars}',
                        color: NeonPalette.star,
                      ),
                      _Stat(
                        icon: Icon(Icons.emoji_events_rounded,
                            size: 17, color: NeonPalette.amber),
                        label: '${session.state.best}',
                        color: NeonPalette.amber,
                      ),
                      _Stat(
                        icon: CoinGlyph(size: 17),
                        label: '${session.state.coins}',
                        color: NeonPalette.gold,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: NeonPalette.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PB-036: mini rütbe madalyonu — puana göre değişen sembol/görünüm (hiyerarşi).
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final RankThreshold rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: rank.colors,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .5)),
        boxShadow: [
          BoxShadow(
            color: rank.colors.first.withValues(alpha: .4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Icon(rank.icon, size: 18, color: Colors.white),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.color});
  final Widget icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 7),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// İkincil menü düğmesi (ikon + etiket).
class _SmallMenuButton extends StatelessWidget {
  const _SmallMenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GradientButton(
        label: label,
        icon: icon,
        expand: true,
        height: 52,
        compact: true,
        colors: [color.withValues(alpha: .30), color.withValues(alpha: .12)],
        onTap: onTap,
      ),
    );
  }
}

/// Alt bilgi şeridi — günlük meydan okuma ipucu.
class _FooterNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: Colors.white.withValues(alpha: .04),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt_rounded, size: 15, color: NeonPalette.amber),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Her gün aynı bölüm, tüm oyunculara açık.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Köşe düğmesi (ayarlar).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .06),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
          ),
          child: Icon(icon, color: NeonPalette.textDim, size: 24),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
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
      // DÜZELTME: style belirtilmemişti → varsayılan FILL, zikzak çizgiyi dev
      // yarı saydam köşeli düzlemler olarak dolduruyordu ("gri poligon" hatası)
      ..style = PaintingStyle.stroke
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
      pts.add(Offset(size.width * (0.06 + rnd() * 0.88),
          size.height * (0.04 + rnd() * 0.30)));
    }
    // bağlantı çizgileri: her yıldız en yakın 2 komşusuna — klasik takımyıldız
    // ağı (ardışık zikzak yerine; artık yalnız stroke çizilir, FILL dolgusu yok)
    final path = Path();
    for (var i = 0; i < total; i++) {
      final dists = <(double, int)>[
        for (var j = 0; j < total; j++)
          if (j != i)
            ((pts[i] - pts[j]).distanceSquared, j),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      for (var k = 0; k < 2 && k < dists.length; k++) {
        if (dists[k].$1 > 190 * 190) continue; // yalnız yakın komşular
        path.moveTo(pts[i].dx, pts[i].dy);
        path.lineTo(pts[dists[k].$2].dx, pts[dists[k].$2].dy);
      }
    }
    canvas.drawPath(path, line);

    // yıldız topladıkça yanan noktalar
    for (var i = 0; i < lit; i++) {
      canvas.drawCircle(
        pts[i],
        2.2,
        Paint()
          ..color = const Color(0xFFFFF3C4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(pts[i], 1.6, Paint()..color = const Color(0xFFFFFDF0));
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) =>
      oldDelegate.starCount != starCount;
}
