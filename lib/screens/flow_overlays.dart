/// Stack Tower Game — akış overlay'leri: kutu → dünya töreni → tahta → sonuç.
/// ui.js'teki ovBox/ovWorld/ovBoard/ovResult zincirinin Flutter karşılığı.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/levels.dart';
import '../map/construction.dart';
import '../widgets/construction_art.dart';
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
    _advance();
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
              Text(boxTitle!, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(boxPrize ?? '', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (boxOpenable)
                NeonButton('AÇ 🎁', _openBox)
              else
                NeonButton('DEVAM', _advance),
            ],
          ),
        );
      case FlowStep.world:
        final c = widget.session.lastCeremony!;
        final relic = c.relic;
        final owned = widget.session.state.relics[c.stage.toString()] == true;
        return _sheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Text('DÜNYA ${c.stage + 1} AYDINLANDI',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(color: NeonPalette.star),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(kWorldLore[c.stage], style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text('+${c.bonus} 🪙',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: NeonPalette.gold)),
              if (relic != null && owned) ...[
                const SizedBox(height: 14),
                Text('${relic.icon}  ${relic.name}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(relic.lore, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              NeonButton('DEVAM', _advance),
            ],
          ),
        );
      case FlowStep.board:
        final rows = widget.session.boardRows;
        return _sheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('GÜNÜN TAHTASI', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 4),
              Text(
                '${DateTime.fromMillisecondsSinceEpoch(widget.session.boardDay * 86400000).toIso8601String().substring(0, 10)} · herkes aynı bölüm',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 30, child: Text('${i + 1}', style: Theme.of(context).textTheme.bodyLarge)),
                      Expanded(
                        child: Text(rows[i].name,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: rows[i].me ? NeonPalette.cyan : NeonPalette.text,
                                  fontWeight: rows[i].me ? FontWeight.w800 : FontWeight.w500,
                                )),
                      ),
                      Text('${rows[i].score}', style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              NeonButton('DEVAM', _advance),
            ],
          ),
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
          const SizedBox(height: 12),
          Text(completed ? '${spec.icon} ${spec.name} TAMAMLANDI!' : '${spec.icon} ${spec.name}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: completed ? NeonPalette.star : NeonPalette.text,
                  ),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            completed
                ? (c.monumentCompleted
                    ? 'Dünya anıtı yükseldi — bu dünya senin eserini taşıyor.'
                    : 'Dört parça da yerinde! Adada kalıcı olarak duruyor.')
                : '${c.pieceLabel.toUpperCase()} yükseldi · $built/$total parça',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: built / total,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .12),
              valueColor: AlwaysStoppedAnimation(
                  completed ? NeonPalette.star : NeonPalette.cyan),
            ),
          ),
          const SizedBox(height: 18),
          NeonButton(completed ? 'HARİKA! ✦' : 'DEVAM', _advance),
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
            : (r.reached ? 'BÖLÜM TAMAM!' : 'BİTİYORDU!');
    final detail = (endless || daily)
        ? 'Kule boyu: ${r.blocks}${daily ? ' · Günün rekoru: ${s.state.daily['best'] ?? 0}' : ' · Rekor: ${s.state.best}'}'
        : '${r.perfects} mükemmel bırakış';
    final starCount = r.reached && !endless ? starsFor(r.perfects, def.target) : 0;
    final hasNext = r.reached && !endless && !daily && def.i + 1 < kLevelCount;

    return _sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(detail, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          // yıldız animasyonu: sırayla büyüyerek gelir
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 3; i++)
                _AnimatedStar(on: i <= starCount, delayMs: 150 + i * 220),
            ],
          ),
          const SizedBox(height: 14),
          Text('+${rewards.coins} 🪙',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: NeonPalette.gold)),
          const SizedBox(height: 6),
          Text(
            endless
                ? 'Rekor: ${s.state.best}'
                : daily
                    ? 'Her gün yeni tahta, yeni şans!'
                    : 'Toplam yıldız: ${s.totalStars}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (hasNext) ...[
            NeonButton('SONRAKİ BÖLÜM →',
                () => widget.onNext(levelDef(def.i + 1))),
            const SizedBox(height: 8),
          ],
          if (!endless) NeonButton('TEKRAR', widget.onRetry),
          const SizedBox(height: 8),
          NeonButton('HARİTA', _advance),
        ],
      ),
    );
  }

  Widget _sheet({required Widget child}) {
    return Container(
      color: Colors.black.withValues(alpha: .62),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xF0101024),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NeonPalette.cyan.withValues(alpha: .35)),
            boxShadow: [BoxShadow(color: NeonPalette.cyan.withValues(alpha: .18), blurRadius: 30)],
          ),
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
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
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted && widget.on) _c.forward();
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
        child: Text('★',
            style: TextStyle(
              fontSize: 40,
              color: widget.on ? NeonPalette.star : Colors.white12,
              shadows: widget.on
                  ? [Shadow(color: NeonPalette.star.withValues(alpha: .7), blurRadius: 22)]
                  : null,
            )),
      ),
    );
  }
}

/// Neon düğme (style.css .btn karşılığı).
class NeonButton extends StatelessWidget {
  const NeonButton(this.label, this.onTap, {super.key, this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 160),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [Color(0xFF173a6b), Color(0xFF2a1856)]),
                border: Border.all(color: NeonPalette.cyan.withValues(alpha: .55), width: 1.4),
                boxShadow: [
                  BoxShadow(color: NeonPalette.cyan.withValues(alpha: .30), blurRadius: 18),
                ],
              ),
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toast (ui.js toast karşılığı) — kısa süreli üst bildirim.
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xEE141430),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NeonPalette.cyan.withValues(alpha: .3)),
            ),
            child: Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
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
