/// Stack Tower Game — premium ortak bileşenler.
///
/// Cam paneller, gradyan butonlar, giriş animasyonları, sayaç animasyonu ve
/// rozetler. Tüm ekranlar bu kiti kullanır → görsel dil tutarlı olur.
///
/// NOT (test güvenliği): bu kitapta `Future.delayed`/`Timer` KULLANILMAZ —
/// widget testlerinde "pending timer" hatası üretir. Giriş gecikmeleri
/// AnimationController + Interval ile ifade edilir. Sonsuz (repeat) animasyon
/// yalnız `pumpAndSettle` kullanılmayan ekranlarda çalışır.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/audio.dart';
import '../theme/tokens.dart';

/// Arayüz tık sesi — bağlamda [AudioController] varsa çalar, yoksa sessizce
/// geçer (test ortamı, erken kurulum). Premium dokunuş hissi için tek nokta.
void playTapSound(BuildContext context) {
  try {
    context.read<AudioController>().play(GameSound.tap);
  } catch (_) {
    // Provider yok → ses çalınmaz, akış bozulmaz.
  }
}

/// Ödül/kilit açılışı sesi.
void playRewardSound(BuildContext context) {
  try {
    context.read<AudioController>().play(GameSound.reward);
  } catch (_) {}
}

/// Hata/reddedilme sesi.
void playErrorSound(BuildContext context) {
  try {
    context.read<AudioController>().play(GameSound.error);
  } catch (_) {}
}

/// Cam (buzlu) panel — arkasındaki içeriği bulanıklaştırır, üstüne ışık
/// kenarı ve ince bir üst ışık çizgisi ekler.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadius.lg,
    this.tint,
    this.borderColor,
    this.glowColor,
    this.blur = 0,
    this.glow = true,
    this.gradient = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tint;
  final Color? borderColor;
  final Color? glowColor;
  final double blur;
  final bool glow;
  final bool gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? NeonPalette.glassBorder;
    final halo = glowColor ?? NeonPalette.cyan;
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xF21A1738),
                  tint ?? const Color(0xE6101024),
                ],
              )
            : null,
        color: gradient ? null : (tint ?? NeonPalette.glass),
        border: Border.all(color: border, width: 1.1),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: halo.withValues(alpha: 0.18),
              blurRadius: 26,
              spreadRadius: -6,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (blur > 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    if (onTap == null) return content;
    return PressScale(onTap: onTap!, child: content);
  }
}

/// Basınca küçülen, bırakınca geri açılan sarmalayıcı.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.955,
    this.haptic = true,
    this.onSound,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;
  final bool haptic;

  /// Dokunuş sesi (çağrıcı sağlar).
  final VoidCallback? onSound;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        if (widget.haptic) HapticFeedback.lightImpact();
        widget.onSound?.call();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppDurations.fast,
        curve: appCurve,
        child: AnimatedOpacity(
          opacity: _down ? 0.82 : 1.0,
          duration: AppDurations.fast,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Basılabilir kart — premium ölçü + hafif koyulaşma.
class PressableCard extends StatelessWidget {
  const PressableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadius.lg,
    this.borderColor,
    this.tint,
    this.glowColor,
    this.haptic = true,
    this.blur = 0,
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final Color? tint;
  final Color? glowColor;
  final bool haptic;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      haptic: haptic,
      onTap: onTap,
      child: GlassPanel(
        padding: padding,
        radius: radius,
        borderColor: borderColor,
        tint: tint,
        glowColor: glowColor,
        blur: blur,
        child: child,
      ),
    );
  }
}

/// Premium gradyan buton — ışık kenarı, tek seferlik parlama süpürmesi ve
/// basma tepkisi. Süpürme BİR KEZ oynar (sonsuz döngü yok → test güvenli).
///
/// [onSound] verilirse dokunuş sesi çalar (premium "tık" hissi).
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.colors,
    this.expand = false,
    this.height = 54,
    this.radius = AppRadius.md,
    this.enabled = true,
    this.compact = false,
    this.glow = true,
    this.shine = true,
    this.onSound,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final List<Color>? colors;
  final bool expand;
  final double height;
  final double radius;
  final bool enabled;
  final bool compact;
  final bool glow;

  /// Girişte bir kez parlama süpürmesi.
  final bool shine;

  /// Dokunuş sesi (çağrıcı sağlar; Premium kit ses servisine bağlı değildir).
  final VoidCallback? onSound;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _down = false;

  @override
  void initState() {
    super.initState();
    if (widget.shine) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        const [Color(0xFF2B1E7A), Color(0xFF123A6E), Color(0xFF3A1B6E)];
    final on = widget.enabled && widget.onTap != null;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon,
              size: widget.compact ? 16 : 19,
              color: NeonPalette.text.withValues(alpha: on ? 1 : 0.5)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: NeonPalette.text.withValues(alpha: on ? 1 : 0.55),
                  fontSize: widget.compact ? 12.5 : 15,
                  letterSpacing: widget.compact ? 0.9 : 1.2,
                ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTapCancel: on ? () => setState(() => _down = false) : null,
        onTap: on
            ? () {
                HapticFeedback.lightImpact();
                widget.onSound?.call();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1.0,
          duration: AppDurations.fast,
          curve: appCurve,
          child: AnimatedOpacity(
            opacity: on ? 1 : 0.5,
            duration: AppDurations.fast,
            child: Container(
              height: widget.height,
              width: widget.expand ? double.infinity : null,
              constraints: const BoxConstraints(minWidth: 120),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 14 : 26,
                vertical: widget.compact ? 8 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: on
                      ? colors
                      : const [Color(0xFF26263F), Color(0xFF1A1A2E)],
                ),
                border: Border.all(
                  color: NeonPalette.cyan.withValues(alpha: on ? 0.55 : 0.2),
                  width: 1.4,
                ),
                boxShadow: widget.glow && on
                    ? [
                        BoxShadow(
                          color: NeonPalette.cyan.withValues(alpha: 0.28),
                          blurRadius: 20,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: NeonPalette.magenta.withValues(alpha: 0.14),
                          blurRadius: 30,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  label,
                  // tek seferlik parlama süpürmesi (premium "canlı" his)
                  if (on && widget.shine)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) {
                            final v = _c.value;
                            if (v >= 1 || v <= 0) return const SizedBox.shrink();
                            final vis = v < 0.4 ? (v / 0.4) : ((1 - v) / 0.6);
                            return ShaderMask(
                              shaderCallback: (b) => LinearGradient(
                                begin: Alignment(-1.6 + v * 3.2, -0.4),
                                end: Alignment(-0.9 + v * 3.2, 0.4),
                                colors: [
                                  const Color(0x00FFFFFF),
                                  Colors.white.withValues(alpha: 0.16 * vis),
                                  const Color(0x00FFFFFF),
                                ],
                              ).createShader(b),
                              blendMode: BlendMode.plus,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(widget.radius),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sayısal değer sayaç animasyonu — hedefe doğru yumuşak artış.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.builder,
    this.duration = AppDurations.slow,
    this.curve = Curves.easeOutCubic,
    this.style,
  });

  final int value;
  final String Function(int) builder;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => Text(
        builder(v.round()),
        style: style ?? Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

/// Bölüm başlıkları için gradient metin.
class GradientTitle extends StatelessWidget {
  const GradientTitle({
    super.key,
    required this.text,
    this.style,
    this.colors,
    this.glow = true,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final List<Color>? colors;
  final bool glow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.displayMedium;
    final palette = colors ?? const [NeonPalette.cyan, NeonPalette.magenta];
    final baseStyle = base ?? const TextStyle();
    return ShaderMask(
      shaderCallback: (b) =>
          LinearGradient(colors: palette).createShader(b),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        textAlign: textAlign,
        style: baseStyle.copyWith(
          shadows: glow
              ? [
                  Shadow(
                    color: palette.first.withValues(alpha: 0.45),
                    blurRadius: 22,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// Giriş animasyonu: yukarı doğru kayarak + belirerek belirir.
/// Gecikme `Future.delayed` DEĞİL, Interval ile ifade edilir (test güvenli).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 26,
    this.duration = AppDurations.slow,
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.delay + widget.duration).inMicroseconds;
    final start = total == 0 ? 0.0 : widget.delay.inMicroseconds / total;
    final anim = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1.0, curve: appCurve),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - anim.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Ekran başlığı rozeti (tür kartı gibi).
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.color = NeonPalette.cyan,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 11 : 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: color.withValues(alpha: filled ? 0.22 : 0.10),
        border: Border.all(color: color.withValues(alpha: filled ? 0.75 : 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
          ),
        ],
      ),
    );
  }
}

/// Parayı temsil eden madeni simge (emoji yerine çizilen özgün ikon).
class CoinGlyph extends StatelessWidget {
  const CoinGlyph({super.key, this.size = 18, this.color = NeonPalette.gold});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinPainter(color)),
    );
  }
}

class _CoinPainter extends CustomPainter {
  _CoinPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: [
            Color.lerp(color, Colors.white, 0.55)!,
            color,
            Color.lerp(color, const Color(0xFF7A4B00), 0.5)!,
          ],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.13
        ..color =
            Color.lerp(color, const Color(0xFF7A4B00), 0.45)!.withValues(alpha: 0.9),
    );
    // paranın ağırlık hissi için iki çizgi
    final p = Paint()
      ..color = Color.lerp(color, Colors.white, 0.65)!
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(c.dx, c.dy - r * 0.3), Offset(c.dx, c.dy + r * 0.28), p);
    canvas.drawLine(
        Offset(c.dx - r * 0.2, c.dy - r * 0.02), Offset(c.dx + r * 0.2, c.dy - r * 0.02),
        p);
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => old.color != color;
}

/// Yıldız rozeti.
class StarGlyph extends StatelessWidget {
  const StarGlyph({super.key, this.size = 18, this.color = NeonPalette.star});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StarPainter(color)),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r * 0.95 : r * 0.42;
      final a = -1.5707963 + i * 0.6283185;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(color, Colors.white, 0.5)!, color],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.06
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}

/// Premium sayfa başlığı — geri düğmesi + başlık + sağ aksiyon.
class PremiumHeader extends StatelessWidget {
  const PremiumHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.accent = NeonPalette.cyan,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, 0),
      child: Row(
        children: [
          if (onBack != null)
            Semantics(
              button: true,
              label: 'Geri',
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .06),
                    border: Border.all(color: Colors.white.withValues(alpha: .14)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: NeonPalette.text, size: 22),
                ),
              ),
            ),
          if (onBack != null) const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GradientTitle(
                  text: title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        letterSpacing: 1.2,
                      ),
                  colors: [accent, NeonPalette.magenta],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Para / yıldız göstergesi (başlık sağ tarafı).
class ResourceChip extends StatelessWidget {
  const ResourceChip({super.key, required this.coins, this.stars});

  final int coins;
  final int? stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stars != null) ...[
          StarGlyph(size: 16),
          const SizedBox(width: 6),
          Text('$stars',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: NeonPalette.star)),
          const SizedBox(width: AppSpace.md),
        ],
        CoinGlyph(size: 16),
        const SizedBox(width: 6),
        Text('$coins',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: NeonPalette.gold)),
      ],
    );
  }
}
