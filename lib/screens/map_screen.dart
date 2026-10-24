/// Stack Tower Game — dünya haritası (işlevsel merkez sürümü).
/// PB-008 bu ekranı 3B perspektif takımadaya (map.js) yükseltecek;
/// buradaki gezinme/kilit/dünya kartı davranışı nihaidir (ui.js showMap).
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

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0c0a20), kThemes[_focusStage(session)].bg2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: NeonPalette.text, size: 28),
                  ),
                  const Spacer(),
                  Text('🪙 ${session.state.coins}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 14),
                  Text('★ ${session.totalStars}', style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: NeonPalette.star)),
                  const SizedBox(width: 8),
                ],
              ),
              Expanded(
                child: _WorldPageView(session: session, initialPage: _focusStage(session)),
              ),
              // günlük meydan okuma düğmesi
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: NeonButton('🌍 GÜNLÜK MEYDAN OKUMA', () {
                  final def = dailyDef(prog.dayOf(DateTime.now()));
                  Navigator.pushNamed(context, Routes.preview, arguments: def);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _focusStage(GameSession session) {
  // ilk bitmemiş dünyaya odaklan
  for (var st = 0; st < kStageCount; st++) {
    if (session.worldDone(st) < kLevelsPerStage) return st;
  }
  return kStageCount - 1;
}

class _WorldPageView extends StatefulWidget {
  const _WorldPageView({required this.session, this.initialPage = 0});
  final GameSession session;
  final int initialPage;

  @override
  State<_WorldPageView> createState() => _WorldPageViewState();
}

class _WorldPageViewState extends State<_WorldPageView> {
  late final PageController _controller =
      PageController(initialPage: widget.initialPage);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return PageView.builder(
      controller: _controller,
      itemCount: kStageCount,
      itemBuilder: (context, stage) {
        final theme = kThemes[stage];
        final open = session.worldOpen(stage);
        final done = session.worldDone(stage);
        final worldStars = List.generate(kLevelsPerStage, (k) => session.state.completed[stage * kLevelsPerStage + k]?['stars'] ?? 0);
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.bg1, theme.bg2],
              ),
              border: Border.all(color: hslColor(theme.glow, 90, 62).withValues(alpha: .45), width: 1.4),
              boxShadow: [BoxShadow(color: hslColor(theme.glow, 90, 62).withValues(alpha: .22), blurRadius: 26)],
            ),
            child: Column(
              children: [
                const SizedBox(height: 14),
                Text('DÜNYA ${stage + 1}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: hslColor(theme.glow, 90, 70))),
                Text(open ? theme.name : '🔒 KİLİTLİ', style: Theme.of(context).textTheme.displayMedium),
                Text(
                  open
                      ? '$done/$kLevelsPerStage · ★ ${worldStars.fold<int>(0, (a, b) => a + b)}'
                      : '🔒 ${session.totalStars}/${requiredStars(stage)} yıldız',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: kLevelsPerStage,
                    itemBuilder: (context, k) {
                      final i = stage * kLevelsPerStage + k;
                      final stars = worldStars[k];
                      final unlocked = k == 0 || session.state.completed[i - 1] != null;
                      return _LevelDot(
                        index: k + 1,
                        stars: stars,
                        locked: !open || !unlocked,
                        glow: theme.glow,
                        onTap: () {
                          if (!open) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Bu dünya için ${requiredStars(stage)} yıldız gerekiyor'),
                            ));
                            return;
                          }
                          if (!unlocked) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Önce bölüm $i\'i bitir')));
                            return;
                          }
                          Navigator.pushNamed(context, Routes.preview, arguments: levelDef(i));
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LevelDot extends StatelessWidget {
  const _LevelDot({
    required this.index,
    required this.stars,
    required this.locked,
    required this.glow,
    required this.onTap,
  });

  final int index;
  final int stars;
  final bool locked;
  final int glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = hslColor(glow, 90, 62);
    return Semantics(
      button: true,
      label: locked ? 'Bölüm $index kilitli' : 'Bölüm $index, $stars yıldız',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: locked ? Colors.white.withValues(alpha: .04) : color.withValues(alpha: .14),
            border: Border.all(
                color: locked ? Colors.white24 : color.withValues(alpha: .7), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(locked ? '🔒' : '$index',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: locked ? NeonPalette.textDim : color,
                      )),
              if (!locked)
                Text('★' * stars,
                    style: const TextStyle(fontSize: 10, color: NeonPalette.star)),
            ],
          ),
        ),
      ),
    );
  }
}
