/// Stack Tower Game — sinematik bölüm önizlemesi (preview.js karşılığı).
/// Dünya silueti + hava + fısıltı + gizem cümlesi + bölüm kartı. Tap → hızlandır.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_session.dart';
import '../game/progress.dart' as prog;
import '../game/scene_painter.dart';
import '../game/levels.dart';
import '../theme/tokens.dart';
import 'flow_overlays.dart';
import 'router.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.def});
  final LevelDef def;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..forward();

  void _skip() => _c.forward(from: _c.value < .99 ? .99 : 1);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final session = context.watch<GameSession>();
    final theme = def.theme;
    final mod = kModifiers[def.modifier]!;
    final daily = def.daily;
    final prevStars = (!daily && session.state.completed[def.i] != null)
        ? session.state.completed[def.i]!['stars']!
        : 0;
    final surprise = (def.endless || def.daily) ? null : surpriseFor(def.i, prog.dayOf(DateTime.now()));
    var mystery = daily ? 'Bugünün bölümü herkes için aynı. Tahtada yerini al.' : mysteryFor(def.i);
    if (surprise != null) mystery = 'Altın bir fısıltı… şans bu bölümde senden yana olabilir.';
    final worldDoneCount = daily ? 0 : session.worldDone(def.stage);

    return Scaffold(
      body: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.bg1, theme.bg2],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // siluet + hava sahnesi
                Positioned.fill(
                  child: CustomPaint(painter: _PreviewPainter(theme)),
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: NeonPalette.textDim),
                        ),
                        const Spacer(),
                        Text('🪙 ${session.state.coins}',
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const Spacer(),
                    // sinematik metinler — fazlı fade-in
                    FadeTransition(
                      opacity: _fade(0.0, 0.45),
                      child: Text(
                        daily ? 'BUGÜN HERKES İÇİN AYNI' : 'DÜNYA ${def.stage + 1} · ${theme.name}',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: hslColor(theme.glow, 90, 70), letterSpacing: 2),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _fade(0.15, 0.6),
                      child: Text(kWorldTeaser[def.stage],
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 26),
                    FadeTransition(
                      opacity: _fade(0.35, 0.8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0a0a1e),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: surprise != null
                                    ? NeonPalette.gold.withValues(alpha: .6)
                                    : Colors.white.withValues(alpha: .14)),
                          ),
                          child: Column(
                            children: [
                              Text(daily ? 'GÜNLÜK MEYDAN OKUMA' : 'BÖLÜM ${def.num}',
                                  style: Theme.of(context).textTheme.displayMedium),
                              const SizedBox(height: 6),
                              if (!daily)
                                Text('$worldDoneCount/$kLevelsPerStage',
                                    style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var s = 1; s <= 3; s++)
                                    Text('★',
                                        style: TextStyle(
                                            fontSize: 22,
                                            color: s <= prevStars
                                                ? NeonPalette.star
                                                : Colors.white12)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${mod.icon} ${mod.name}',
                                      style: Theme.of(context).textTheme.titleLarge
                                          ?.copyWith(color: hslColor(theme.glow, 95, 70))),
                                ],
                              ),
                              Text(mod.hint,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              Text('${def.target} blok · ${def.coins} 🪙${def.box ? ' + 🎁' : ''}',
                                  style: Theme.of(context).textTheme.bodyLarge),
                              const SizedBox(height: 10),
                              Text(mystery,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: surprise != null
                                            ? NeonPalette.gold
                                            : NeonPalette.textDim,
                                      ),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 14),
                              FadeTransition(
                                opacity: _fade(0.6, 0.9),
                                child: _StartButton(def: def),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Animation<double> _fade(double start, double end) =>
      CurvedAnimation(parent: _c, curve: Interval(start, end, curve: Curves.easeOut));
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.def});
  final LevelDef def;

  @override
  Widget build(BuildContext context) {
    final session = context.read<GameSession>();
    final locked = !def.daily && !def.endless && !isUnlockedNow(session, def);
    return NeonButton(
      locked ? '🔒 KİLİTLİ' : 'BAŞLA ▶',
      locked
          ? () {}
          : () => Navigator.pushReplacementNamed(context, Routes.play, arguments: def),
      enabled: !locked,
    );
  }

  static bool isUnlockedNow(GameSession session, LevelDef def) {
    if (def.i <= 0) return true;
    if (session.state.completed[def.i - 1] == null) return false;
    return session.totalStars >= requiredStars(def.stage) ||
        def.stage == stageOf(def.i - 1);
  }
}

/// Önizleme sahnesi: tema gradyanı + iki katman silüet + hava parçacıkları.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.theme);
  final dynamic theme;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    var seed = theme.id.codeUnitAt(0) * 97 + 5;
    double rnd() {
      seed |= 0;
      seed = (seed + 0x6D2B79F5) & 0x7FFFFFFF;
      var t = seed ^ (seed >> 15);
      t = (t * (1 | seed)) & 0xFFFFFFFF;
      t = (t + ((t ^ (t >> 7)) * 61 & 0xFFFFFFFF)) & 0xFFFFFFFF;
      return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
    }

    for (var layer = 0; layer < 2; layer++) {
      final base = h * (0.96 - layer * 0.02);
      final fill = Paint()..color = hsla(theme.glow, 46, layer == 1 ? 6 : 9, 1);
      var x = -30.0;
      while (x < w + 40) {
        final bw = 40 + rnd() * 90;
        final hgt = (20 + rnd() * 110) * (layer == 1 ? 0.7 : 1);
        final path = Path()
          ..moveTo(x, base)
          ..lineTo(x + bw / 2, base - hgt)
          ..lineTo(x + bw, base)
          ..close();
        canvas.drawPath(path, fill);
        x += bw * 0.75;
      }
    }
    // hava
    final weatherColor = hsla(theme.glow, 90, 72, .5);
    for (var i = 0; i < 26; i++) {
      canvas.drawCircle(
        Offset(rnd() * w, rnd() * h * 0.8),
        1 + rnd() * 1.8,
        Paint()..color = weatherColor.withValues(alpha: .2 + rnd() * .3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) => oldDelegate.theme != theme;
}
