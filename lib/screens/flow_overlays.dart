/// Stack Tower Game — akış overlay'leri: kutu → dünya töreni → tahta → sonuç.
/// ui.js'teki ovBox/ovWorld/ovBoard/ovResult zincirinin Flutter karşılığı.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/levels.dart';
import '../game/progress.dart' as prog;
import '../map/construction.dart';
import '../ui/ambient.dart';
import '../ui/premium_kit.dart';
import '../widgets/construction_art.dart';
import '../widgets/gift_box.dart';
import '../widgets/monument_ceremony.dart';
import '../theme/tokens.dart';

class FlowOverlays extends StatefulWidget {
  const FlowOverlays({
    super.key,
    required this.session,
    required this.audio,
    required this.onFlowDone,
    required this.onRetry,
    required this.onNext,
  });

  final GameSession session;
  final AudioController audio;
  final VoidCallback onFlowDone; // zincir bitti → harita
  final VoidCallback onRetry; // TEKRAR
  final ValueChanged<LevelDef> onNext; // SONRAKİ BÖLÜM

  @override
  State<FlowOverlays> createState() => _FlowOverlaysState();
}

class _FlowOverlaysState extends State<FlowOverlays> {
  FlowStep? _step;
  String? boxTitle, boxPrize;
  bool boxOpenable = false;

  @override
  void initState() {
    super.initState();
    // PB-034 (PB-031 incelemesi): popStep → notifyListeners zincirini build
    // fazından çıkar — alt ağaçta bir gün GameSession.watch() olursa
    // markNeedsBuild-during-build riski kapanır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _advance();
    });
  }

  void _advance() {
    final step = widget.session.popStep();
    if (!mounted) return;
    if (step == null || step == FlowStep.showMap) {
      // zincir bitti / haritaya dönüş adımı (ui.js setTimeout(showMap))
      widget.onFlowDone();
      return;
    }
    if (step == FlowStep.board) widget.session.buildBoard(); // build içinde mutasyon yok
    if (step == FlowStep.box) {
      setState(() {
        _step = FlowStep.box;
        boxTitle = 'SÜRPRİZ KUTU KAZANDIN! 🎁';
        boxPrize = '';
        boxOpenable = true;
      });
    } else {
      setState(() => _step = step);
    }
  }

  void _openBox() {
    final prize = widget.session.openBoxNow();
    widget.audio.play(GameSound.box);
    widget.audio.play(GameSound.mystery); // PB-017: sandık gizemi
    // PB-032: kutu açılışı ödül sesi — kutu gerçekten açılıyorsa
    widget.audio.play(GameSound.reward);
    // juice (PB-016): kutu açılışı üçlü vuruş — başlangıç anları 0/60/120ms
    for (final at in const [0, 60, 120]) {
      if (at == 0) {
        HapticFeedback.lightImpact();
      } else {
        final d = Duration(milliseconds: at);
        Future.delayed(d, () {
          if (mounted) HapticFeedback.lightImpact();
        });
      }
    }
    setState(() {
      if (prize == null) {
        boxTitle = 'SÜRPRİZ KUTU';
        boxPrize = '';
      } else if (prize.type == 'skin') {
        boxTitle = 'YENİ GÖRÜNÜM!';
        boxPrize = '✦ ${prize.skin!.name} ✦\nÖdül Odasından kuşanabilirsin.';
      } else {
        boxTitle = 'MADENİ PARA!';
        boxPrize = '+${prize.amount} 🪙';
      }
      boxOpenable = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case FlowStep.construction:
        return _buildConstruction(context);
      case FlowStep.box:
        return _sheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GiftBox(opened: !boxOpenable),
              const SizedBox(height: AppSpace.lg),
              GradientTitle(
                text: boxTitle!,
                colors: const [NeonPalette.gold, NeonPalette.magenta],
              ),
              if ((boxPrize ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                Text(boxPrize ?? '',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: AppSpace.xl),
              if (boxOpenable)
                GradientButton(
                  label: 'AÇ 🎁',
                  icon: Icons.card_giftcard_rounded,
                  expand: true,
                  height: 54,
                  colors: const [
                    Color(0xFF6B3A0E),
                    Color(0xFF9A5A12),
                  ],
                  onTap: _openBox,
                )
              else
                GradientButton(
                  label: 'DEVAM',
                  icon: Icons.arrow_forward_rounded,
                  expand: true,
                  height: 52,
                  onTap: _advance,
                ),
            ],
          ),
        );
      case FlowStep.world:
        final c = widget.session.lastCeremony!;
        final relic = c.relic;
        final owned = widget.session.state.relics[c.stage.toString()] == true;
        return _sheet(
          celebrate: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              MonumentCeremony(stage: c.stage),
              const SizedBox(height: 4),
              GradientTitle(
                text: 'DÜNYA ${c.stage + 1} AYDINLANDI',
                colors: const [NeonPalette.star, NeonPalette.magenta],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(kWorldLore[c.stage], style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CoinGlyph(size: 20),
                  const SizedBox(width: 8),
                  Text('+${c.bonus}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: NeonPalette.gold)),
                ],
              ),
              if (relic != null && owned) ...[
                const SizedBox(height: AppSpace.lg),
                GlassPanel(
                  padding: const EdgeInsets.all(AppSpace.md),
                  radius: AppRadius.md,
                  glowColor: NeonPalette.star,
                  glow: true,
                  child: Row(
                    children: [
                      Text(relic.icon, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(relic.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: NeonPalette.star)),
                            const SizedBox(height: 2),
                            Text(relic.lore,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              GradientButton(
                label: 'DEVAM',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                height: 52,
                onTap: _advance,
              ),
            ],
          ),
        );
      case FlowStep.board:
        return ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) {
            final rows = widget.session.boardRows;
            // Rozet yalnızca gerçekten bulut görünümü uygulanınca gösterilir;
            // fetch başarısızsa satırlar yereldir (C-005) ve rozet görünmez.
            final cloud = widget.session.boardIsCloud;
            return _sheet(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GradientTitle(
                    text: 'GÜNÜN TAHTASI',
                    colors: const [NeonPalette.cyan, NeonPalette.violet],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '${DateTime.fromMillisecondsSinceEpoch(widget.session.boardDay * 86400000).toIso8601String().substring(0, 10)} · herkes aynı bölüm',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpace.md),
                  // PB-020: kişisel rekor yayı + bu hafta geçilen rakip sayısı
                  DailyLiveliness(session: widget.session),
                  const SizedBox(height: AppSpace.md),
                  for (var i = 0; i < rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md, vertical: AppSpace.sm),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          color: rows[i].me
                              ? NeonPalette.cyan.withValues(alpha: .12)
                              : Colors.white.withValues(alpha: .03),
                          border: Border.all(
                            color: rows[i].me
                                ? NeonPalette.cyan.withValues(alpha: .45)
                                : Colors.white.withValues(alpha: .06),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text('${i + 1}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: i == 0
                                            ? NeonPalette.star
                                            : NeonPalette.textDim,
                                        fontWeight: FontWeight.w800,
                                      )),
                            ),
                            Expanded(
                              child: Text(rows[i].name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: rows[i].me
                                            ? NeonPalette.cyan
                                            : NeonPalette.text,
                                        fontWeight: rows[i].me
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                      )),
                            ),
                            Text('${rows[i].score}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: rows[i].me
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    )),
                          ],
                        ),
                      ),
                    ),
                  if (cloud) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_done_rounded, size: 14, color: NeonPalette.cyan),
                        const SizedBox(width: 6),
                        Text('Bulut tahtası', style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  NeonButton('DEVAM', _advance),
                ],
              ),
            );
          },
        );
      case FlowStep.result:
      default:
        return _buildResult(context);
    }
  }

  /// ADR-009: bölüm sonunda adada yükselen parça (görünür amaç).
  Widget _buildConstruction(BuildContext context) {
    final c = widget.session.lastConstruction;
    if (c == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _advance());
      return const SizedBox.shrink();
    }
    final spec = c.structure;
    final total = spec.pieces.length;
    final built = piecesBuilt(widget.session.state, c.stage, slotOf(c.idx).structure);
    final completed = c.structureCompleted;
    return _sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstructionArt(spec: spec, built: built, total: total),
          const SizedBox(height: AppSpace.md),
          GradientTitle(
            text: completed ? '${spec.icon} ${spec.name} TAMAMLANDI!' : '${spec.icon} ${spec.name}',
            colors: completed
                ? const [NeonPalette.star, NeonPalette.amber]
                : const [NeonPalette.cyan, NeonPalette.violet],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            completed
                ? (c.monumentCompleted
                    ? 'Dünya anıtı yükseldi — bu dünya senin eserini taşıyor.'
                    : 'Dört parça da yerinde! Adada kalıcı olarak duruyor.')
                : '${c.pieceLabel.toUpperCase()} yükseldi · $built/$total parça',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: built / total,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: .12),
              valueColor: AlwaysStoppedAnimation(
                  completed ? NeonPalette.star : NeonPalette.cyan),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          GradientButton(
            label: completed ? 'HARİKA! ✦' : 'DEVAM',
            icon: completed ? Icons.auto_awesome_rounded : Icons.arrow_forward_rounded,
            expand: true,
            height: 52,
            colors: completed
                ? const [Color(0xFF6B4A0E), Color(0xFF9A7212)]
                : const [Color(0xFF2E1E86), Color(0xFF12407E)],
            onTap: _advance,
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final s = widget.session;
    final r = s.pendingResult!;
    final rewards = s.pendingRewards!;
    final def = s.currentDef!;
    final endless = def.endless;
    final daily = def.daily;
    final title = endless
        ? 'SERBEST BİTTİ'
        : daily
            ? 'GÜNLÜK BİTTİ!'
            : (r.reached ? 'BÖLÜM TAMAM!' : 'NEREDEYSE!');
    final detail = (endless || daily)
        ? 'Kule boyu: ${r.blocks}${daily ? ' · Günün rekoru: ${s.state.daily['best'] ?? 0}' : ' · Rekor: ${s.state.best}'}'
        : '${r.perfects} mükemmel bırakış';
    // DNA raporu C5: kayıp, duygusal zirve anıdır — rekor farkı gösterilir,
    // "bir tur daha" hissi güçlendirilir (D5: yenilgi → hızlı tekrar).
    final gapLine = (!endless && !daily && !r.reached && s.state.best > r.blocks && r.blocks > 0)
        ? 'Rekoruna ${(s.state.best - r.blocks)} blok kaldı'
        : null;
    final starCount = r.reached && !endless ? starsFor(r.perfects, def.target) : 0;
    final hasNext = r.reached && !endless && !daily && def.i + 1 < kLevelCount;
    // A7 (PB-035) yenilgi yumuşatma: normal bölüm kaybında ('NEREDEYSE!') hızlı
    // yeniden deneme BİRİNCİL eylemdir — TEKRAR, HARİTA'dan büyük/parlak çizilir
    // (D5: yenilgi → hızlı tekrar). Kazanma ekranında SONRAKİ BÖLÜM birincil kalır.
    final lostNormal = !endless && !daily && !r.reached;
    // PB-037 (RESEARCH-endgame X6-X8): kayıp affi paketi — hedefe %N barı +
    // 2. ardışık kayıpta 'BU TUR ×2 PARA' comeback rozeti (sunum; cüzdan
    // uygulaması session'da comebackBoost bayrağıyla bir sonraki denemede)
    final comebackEligible = lostNormal && s.state.lastLossStreak >= 2;
    final targetPct = lostNormal && def.target > 0
        ? ((r.blocks * 100) / def.target).round().clamp(0, 100)
        : null;

    return _sheet(
      celebrate: r.reached,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientTitle(
            text: title,
            colors: r.reached
                ? const [NeonPalette.amber, NeonPalette.magenta]
                : const [NeonPalette.textDim, NeonPalette.textDim],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(detail, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          if (gapLine != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              gapLine,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NeonPalette.amber,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          // X6: hedefe %N — 'NEREDEYSE' hissinin görsel kanıtı
          if (targetPct != null) ...[
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              width: 190,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: targetPct / 100,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: .08),
                  valueColor:
                      const AlwaysStoppedAnimation(NeonPalette.cyan),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('HEDEFE %$targetPct',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NeonPalette.cyan,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4)),
          ],
          // X8: comeback rozeti — 2. ardışık kayıpta bir sonraki deneme ×2 para
          if (comebackEligible) ...[
            const SizedBox(height: AppSpace.sm),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  NeonPalette.amber,
                  Color(0xFFFF7A3D),
                ]),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                      color: NeonPalette.amber.withValues(alpha: .4),
                      blurRadius: 10),
                ],
              ),
              child: Text('🔥 BU TUR ×2 PARA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      shadows: [
                        Shadow(
                            color: Colors.white.withValues(alpha: .4),
                            blurRadius: 6),
                      ])),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          // yıldız animasyonu: sırayla büyüyerek gelir
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 3; i++)
                _AnimatedStar(on: i <= starCount, delayMs: 150 + i * 220),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoinGlyph(size: 22),
              const SizedBox(width: 10),
              CountUpText(
                value: rewards.coins,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: NeonPalette.gold,
                      shadows: [
                        Shadow(
                            color: NeonPalette.gold.withValues(alpha: .5),
                            blurRadius: 18),
                      ],
                    ),
                builder: (v) => '+$v',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            endless
                ? 'Rekor: ${s.state.best}'
                : daily
                    ? 'Her gün yeni tahta, yeni şans!'
                    : 'Toplam yıldız: ${s.totalStars}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.xl),
          if (hasNext) ...[
            GradientButton(
              label: 'DEVAM',
              icon: Icons.arrow_forward_rounded,
              expand: true,
              height: 54,
              colors: const [
                Color(0xFF2E1E86),
                Color(0xFF12407E),
                Color(0xFF451C7A),
              ],
              // PB-037 X9 result-first: DEVAM meta şölen zincirini
              // sürdürür (inşaat→kutu→dünya→tahta→harita) — doruk
              // anından düşmeden törenler yaşanır
              onTap: _advance,
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          if (!endless)
            GradientButton(
              label: 'TEKRAR',
              icon: Icons.refresh_rounded,
              expand: true,
              height: lostNormal ? 54 : 50,
              colors: lostNormal
                  ? const [Color(0xFF2E1E86), Color(0xFF12407E), Color(0xFF451C7A)]
                  : const [Color(0xFF243A78), Color(0xFF182A52)],
              onTap: widget.onRetry,
            ),
          const SizedBox(height: AppSpace.sm),
          GradientButton(
            label: 'HARİTA',
            icon: Icons.map_rounded,
            expand: true,
            height: 50,
            glow: false,
            colors: const [Color(0xFF2A2A44), Color(0xFF1C1C30)],
            // PB-037 result-first: result zincirin BAŞINDADIR — HARİTA akışı
            // doğrudan kapatır (eski _advance inşaatı açıyordu)
            onTap: widget.onFlowDone,
          ),
        ],
      ),
    );
  }

  Widget _sheet({required Widget child, bool celebrate = false}) {
    return Stack(
      children: [
        // arka karartma + hafif renk yıkaması
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: .68)),
        ),
        if (celebrate)
          Positioned.fill(
            child: IgnorePointer(
              child: _CelebrationBackdrop(),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.all(AppSpace.xl),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF71C1840), Color(0xF20D0C1E)],
                ),
                border:
                    Border.all(color: NeonPalette.cyan.withValues(alpha: .38)),
                boxShadow: [
                  BoxShadow(
                      color: NeonPalette.cyan.withValues(alpha: .20),
                      blurRadius: 36),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .5),
                      blurRadius: 24,
                      offset: const Offset(0, 12)),
                ],
              ),
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ],
    );
  }
}

/// Zafer anında arka planda dönen konfeti + ışık halkaları.
class _CelebrationBackdrop extends StatefulWidget {
  @override
  State<_CelebrationBackdrop> createState() => _CelebrationBackdropState();
}

class _CelebrationBackdropState extends State<_CelebrationBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    // Ortam animasyonu kapalıysa (test) tek kare dondurulur.
    if (AmbientMotion.enabled) {
      _c.repeat();
    } else {
      _c.value = 0.25;
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
      builder: (context, _) => CustomPaint(
        painter: _CelebrationPainter(_c.value),
        size: Size.infinite,
      ),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // ışık halkaları
    for (var i = 0; i < 3; i++) {
      final p = ((t + i / 3) % 1.0);
      final r = size.width * (0.15 + p * 0.75);
      canvas.drawCircle(
        size.center(Offset.zero),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - p)
          ..color = NeonPalette.cyan.withValues(alpha: 0.22 * (1 - p)),
      );
    }
    // konfeti
    final rnd = math.Random(4242);
    for (var i = 0; i < 42; i++) {
      final sx = rnd.nextDouble();
      final speed = 0.35 + rnd.nextDouble() * 0.5;
      final phase = rnd.nextDouble();
      final y = ((t * speed + phase) % 1.0) * size.height * 1.1 - size.height * 0.05;
      final x = sx * size.width + math.sin(t * 3 + i) * 18;
      final hue = [NeonPalette.cyan, NeonPalette.magenta, NeonPalette.amber,
        NeonPalette.star][i % 4];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 6 + i);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: 7, height: 11),
        Paint()..color = hue.withValues(alpha: .65),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter old) => old.t != t;
}

class _AnimatedStar extends StatefulWidget {
  const _AnimatedStar({required this.on, required this.delayMs});
  final bool on;
  final int delayMs;

  @override
  State<_AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<_AnimatedStar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);

  @override
  void initState() {
    super.initState();
    // PB-034 C2 (tören v2): yıldız iniş anında pop + kısa haptic nabzı —
    // süpürme hissi (yıldız başına hafif; yoğunluk ∝ önem, C-023).
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted && widget.on) {
        _c.forward();
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // yıldız arkasında ışık halkası
            if (widget.on)
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      NeonPalette.star.withValues(alpha: .38),
                      NeonPalette.star.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            Text('★',
                style: TextStyle(
                  fontSize: 40,
                  color: widget.on ? NeonPalette.star : Colors.white12,
                  shadows: widget.on
                      ? [Shadow(color: NeonPalette.star.withValues(alpha: .7), blurRadius: 22)]
                      : null,
                )),
          ],
        ),
      ),
    );
  }
}

/// Neon düğme (style.css .btn karşılığı).
///
/// Premium görsel: gradient dolgu, ışık kenarı, basma tepkisi ve tek
/// seferlik parlama süpürmesi. Eski imza (`NeonButton(label, onTap,
/// {enabled})`) korunur — çağıran ekranlar değişmez.
class NeonButton extends StatelessWidget {
  const NeonButton(this.label, this.onTap, {super.key, this.enabled = true});

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GradientButton(
      label: label,
      onTap: enabled ? onTap : null,
      enabled: enabled,
      onSound: () => playTapSound(context),
    );
  }
}

/// Toast (ui.js toast karşılığı) — kısa süreli üst bildirim.
/// PB-020: tahta canlılığı — rekor yayı, geçilen rakip, sezon rozeti.
class DailyLiveliness extends StatelessWidget {
  const DailyLiveliness({super.key, required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final st = session.state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          width: double.infinity,
          child: CustomPaint(painter: _SparkPainter(st.dailyHistory, NeonPalette.cyan)),
        ),
        const SizedBox(height: 4),
        Text(
          'SON 7 GÜN · bu hafta ${prog.beatenCount(st)} kişiyi geçtin',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (prog.weeklyBadge(st))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('🏅 7 GÜN SERİSİ',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: NeonPalette.star, letterSpacing: 1.5)),
          ),
      ],
    );
  }
}

/// PB-020: 7 günlük rekor yayı — basit, ucuz çizgi grafik.
class _SparkPainter extends CustomPainter {
  _SparkPainter(this.history, this.color);
  final Map<int, int> history;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) {
      final p = Paint()
        ..color = color.withValues(alpha: .35)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(0, size.height * .6),
          Offset(size.width, size.height * .6), p);
      return;
    }
    final days = history.keys.toList()..sort();
    final values = [for (final d in days) history[d]!];
    final maxV = values.reduce(math.max).clamp(1, 1 << 30);
    final dx = size.width / (values.length - 1);
    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(i * dx, size.height - (values[i] / maxV) * (size.height - 6) - 3),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
    for (final p in pts) {
      canvas.drawCircle(p, 2.2, Paint()..color = color);
    }
    canvas.drawCircle(
        pts.last,
        5,
        Paint()
          ..color = color.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.history.length != history.length || old.color != color;
}

class FlowOverlaysToast extends StatefulWidget {
  const FlowOverlaysToast({super.key, required this.message, required this.child});
  final String message;
  final Widget child;

  @override
  State<FlowOverlaysToast> createState() => _FlowOverlaysToastState();
}

class _FlowOverlaysToastState extends State<FlowOverlaysToast> {
  bool _show = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_show)
          Positioned(
            left: 24,
            right: 24,
            bottom: 90,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _show ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xEE141430),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NeonPalette.cyan.withValues(alpha: .3)),
                  ),
                  child: Text(widget.message, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Statik toast yardımcısı (PlayScreen içinde overlay olarak gösterilir).
/// Eşzamanlı toast'lar dikey olarak üst üste BINMEZ — her yeni toast
/// aktif toast'ların üzerine ayrı bir sıraya yerleşir (inceleme bulgusu).
class ToastHost {
  /// Kök overlay'de o anda dolu toast yuvaları (yerleşim ofseti için).
  /// Yeni toast en düşük boş yuvaya yerleşir; süre sonunda yuva boşalır —
  /// ara gelen toast'un bitişi, hâlâ görünür toast'un yerini çalamaz.
  static final Set<int> _slots = {};

  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    var slot = 0;
    while (_slots.contains(slot)) {
      slot++;
    }
    _slots.add(slot);
    late OverlayEntry real;
    real = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 90.0 + slot * 72.0,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              gradient: const LinearGradient(
                colors: [Color(0xF21C1840), Color(0xF20D0C1E)],
              ),
              border:
                  Border.all(color: NeonPalette.cyan.withValues(alpha: .35)),
              boxShadow: [
                BoxShadow(
                    color: NeonPalette.cyan.withValues(alpha: .20),
                    blurRadius: 22),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: NeonPalette.cyan),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(real);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (real.mounted) real.remove();
      _slots.remove(slot);
    });
  }
}
