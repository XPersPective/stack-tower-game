/// Stack Tower Game — sinematik bölüm önizlemesi (preview.js karşılığı).
/// Dünya silueti + hava + fısıltı + gizem cümlesi + bölüm kartı. Tap → hızlandır.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/progress.dart' as prog;
import '../game/scene_painter.dart';
import '../game/levels.dart';
import '../preview/preview_painter.dart';
import '../theme/tokens.dart';
import '../ui/premium_kit.dart';
import 'router.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.def});
  final LevelDef def;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  // sahne solunumu (hava/silüet sürüklenmesi) — sinematik süreden bağımsız akar
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  )..repeat();

  // sahne açılış başına bir kez kurulur — preview.js open() → buildParticles
  // (preview.js:76-83); ambient tick'lerinde yalnız zaman ilerler.
  late final PreviewScene _scene = PreviewScene(
    theme: widget.def.theme,
    levelI: widget.def.i,
    stage: widget.def.stage,
    daily: widget.def.daily,
  );

  void _skip() => _c.forward(from: _c.value < .99 ? .99 : 1);

  @override
  void initState() {
    super.initState();
    // PB-035 D8: dünyanın jingle'ı — önizleme açılışında bir kez (kısa arpej)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AudioController>().playWorldJingle(widget.def.stage);
    });
  }

  @override
  void dispose() {
    _ambient.dispose();
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
    final surprise = (def.endless || def.daily)
        ? null
        : surpriseFor(def.i, prog.dayOf(DateTime.now()));
    // ui.js openIntro: teaser slotu günlükte günlük cümlesini taşır; gizem
    // cümlesi her zaman mysteryFor(d.i) — günlük tanımda i=-2'den seçilir.
    var mystery = mysteryFor(def.i);
    if (surprise != null) {
      mystery = 'Altın bir fısıltı… şans bu bölümde senden yana olabilir.';
    }
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
                // siluet + hava sahnesi — preview.js birebir portu
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _ambient,
                    builder: (context, _) => CustomPaint(
                      painter: PreviewPainter(
                        scene: _scene,
                        t: _ambient.value * 90,
                      ),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 660;
                    final content = Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Geri',
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: NeonPalette.text,
                                size: 26,
                              ),
                            ),
                            const Spacer(),
                            ResourceChip(coins: session.state.coins),
                            const SizedBox(width: AppSpace.md),
                          ],
                        ),
                        if (compact)
                          const SizedBox(height: 20)
                        else
                          const Spacer(),
                        // sinematik metinler — fazlı fade-in
                        FadeTransition(
                          opacity: _fade(0.0, 0.45),
                          child: Text(
                            daily
                                ? 'BUGÜN HERKES İÇİN AYNI'
                                : 'DÜNYA ${def.stage + 1} · ${theme.name}',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: hslColor(theme.glow, 90, 70),
                                  letterSpacing: 2,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeTransition(
                          opacity: _fade(0.15, 0.6),
                          child: Text(
                            daily
                                ? 'Bugünün bölümü herkes için aynı. Tahtada yerini al.'
                                : kWorldTeaser[def.stage],
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeTransition(
                          opacity: _fade(0.35, 0.8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg,
                            ),
                            child: GlassPanel(
                              padding: EdgeInsets.all(
                                compact ? AppSpace.lg : AppSpace.xl,
                              ),
                              radius: AppRadius.xl,
                              blur: 12,
                              glowColor: hslColor(theme.glow, 90, 62),
                              borderColor: surprise != null
                                  ? NeonPalette.gold.withValues(alpha: .6)
                                  : Colors.white.withValues(alpha: .16),
                              child: Column(
                                children: [
                                  GradientTitle(
                                    text: daily
                                        ? 'GÜNLÜK MEYDAN OKUMA'
                                        : 'BÖLÜM ${def.num}',
                                    colors: daily
                                        ? const [
                                            NeonPalette.amber,
                                            NeonPalette.magenta,
                                          ]
                                        : const [
                                            NeonPalette.cyan,
                                            NeonPalette.magenta,
                                          ],
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  // ui.js openIntro(181): günlükte ilerleme slotu 'GÜNLÜK'
                                  Text(
                                    daily
                                        ? 'GÜNLÜK'
                                        : '$worldDoneCount/$kLevelsPerStage',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (var s = 1; s <= 3; s++)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          child: Icon(
                                            Icons.star_rounded,
                                            size: 26,
                                            color: s <= prevStars
                                                ? NeonPalette.star
                                                : Colors.white12,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${mod.icon} ${mod.name}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: hslColor(
                                                theme.glow,
                                                95,
                                                70,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    mod.hint,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                  // PB-030: TÜR KARTI — bu bölüm hangi oyun?
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.md,
                                      vertical: AppSpace.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hslColor(
                                        def.kindSpec.accentHue,
                                        90,
                                        60,
                                      ).withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                      border: Border.all(
                                        color: hslColor(
                                          def.kindSpec.accentHue,
                                          90,
                                          65,
                                        ).withValues(alpha: .45),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          def.kindSpec.icon,
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: hslColor(
                                              def.kindSpec.accentHue,
                                              95,
                                              78,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpace.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      'BU BÖLÜM: ${def.kindSpec.name}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            color: hslColor(
                                                              def
                                                                  .kindSpec
                                                                  .accentHue,
                                                              95,
                                                              78,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  // PB-035 B2: patron rozeti
                                                  if (def.modifier ==
                                                      'patron') ...[
                                                    const SizedBox(
                                                      width: AppSpace.sm,
                                                    ),
                                                    const _PatronBadge(),
                                                  ],
                                                ],
                                              ),
                                              Text(
                                                def.kindSpec.hint,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // "sırada ne var" merak kartı (gizem — PB-019/021 ile derinleşir)
                                  if (!daily && !def.endless) ...[
                                    const SizedBox(height: AppSpace.sm),
                                    Text(
                                      'SIRADA: ${kKindSpecs[kindFor(def.i + 1)]!.name} · '
                                      '${kKindSpecs[kindFor(def.i + 1)]!.icon}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: NeonPalette.textDim,
                                            letterSpacing: 1.2,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpace.sm),
                                  Text(
                                    '${def.target} blok · ${def.coins} 🪙${def.box ? ' + 🎁' : ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge,
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                  Text(
                                    mystery,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontStyle: FontStyle.italic,
                                          color: surprise != null
                                              ? NeonPalette.gold
                                              : NeonPalette.textDim,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpace.md),
                                  FadeTransition(
                                    key: const ValueKey('preview-start-fade'),
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
                    );
                    if (!compact) return content;
                    // kısa ekranlarda kart kaydırılabilir olur (C-016: taşma yok)
                    return SingleChildScrollView(child: content);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Animation<double> _fade(double start, double end) => CurvedAnimation(
    parent: _c,
    curve: Interval(start, end, curve: Curves.easeOut),
  );
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.def});
  final LevelDef def;

  @override
  Widget build(BuildContext context) {
    final session = context.read<GameSession>();
    final locked = !def.daily && !def.endless && !isUnlockedNow(session, def);
    if (!locked) {
      return GradientButton(
        label: 'BAŞLA ▶',
        icon: Icons.play_arrow_rounded,
        expand: true,
        height: 56,
        colors: const [Color(0xFF2E1E86), Color(0xFF12407E), Color(0xFF451C7A)],
        onTap: () => Navigator.pushReplacementNamed(
          context,
          Routes.play,
          arguments: def,
        ),
      );
    }
    // ui.js openIntro(212-218) introLock: kilit nedeni kartta gösterilir
    final need = requiredStars(def.stage);
    final reason = (def.stage > 0 && session.totalStars < need)
        ? 'BU DÜNYA İÇİN $need YILDIZ GEREKİYOR'
        : "ÖNCE BÖLÜM ${def.num - 1}'İ BİTİR";
    return Column(
      children: [
        Text(
          reason,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: NeonPalette.textDim),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpace.sm),
        GradientButton(
          label: '🔒 KİLİTLİ',
          expand: true,
          height: 54,
          enabled: false,
          onTap: () {},
        ),
      ],
    );
  }

  static bool isUnlockedNow(GameSession session, LevelDef def) {
    // PB-037: geliştirici modu — önizleme kilidi de bayrağa saygılı
    // (harita düğümü açılıyor ama önizleme KİLİTLİ gösteriyordu —
    //  kullanıcı raporu: 'çelişkili gösteriyor')
    if (session.state.devUnlockAll) return true;
    if (def.i <= 0) return true;
    if (session.state.completed[def.i - 1] == null) return false;
    return session.totalStars >= requiredStars(def.stage) ||
        def.stage == stageOf(def.i - 1);
  }
}

/// PB-035 B2: patron (boss) bölüm rozeti — tür kartı başlığının yanında küçük
/// dolgulu çip; amber→magenta gradyan kenar + alev ikonu (yalnız sunum).
class _PatronBadge extends StatelessWidget {
  const _PatronBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PATRON bölümü rozeti',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [NeonPalette.amber, NeonPalette.magenta],
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs + 2,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: NeonPalette.glass,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 12,
                color: NeonPalette.amber,
              ),
              SizedBox(width: 3),
              Text(
                'PATRON',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: NeonPalette.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
