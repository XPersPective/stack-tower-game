/// Stack Tower Game — KİŞİSEL PUAN & RÜTBE SAYFASI (PB-036 tur 7).
///
/// Kullanıcı isteği: "puanını/sıralamasını her zaman görebilmeli; tıkladığında
/// kendi özel puan sayfası açılsın; ön sıraya geçebilmesi gerekiyor."
/// Rütbe madalyonu (parıltılı, kademeli), bileşik puan, tüm istatistikler,
/// yerel sıralama yüzdesi + "sonraki kademeye X puan" göstergesi.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_session.dart';
import '../game/progress.dart' as prog;
import '../game/rank.dart';
import '../theme/tokens.dart';
import '../ui/aurora_background.dart';
import '../ui/premium_kit.dart';

class RankScreen extends StatelessWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    final s = session.state;
    final rank = rankFor(s);
    final pts = rankPoints(s);
    final toNext = pointsToNext(s);
    final day = prog.dayOf(DateTime.now());
    final pct = localPercentile(s, day);
    var stars = 0;
    for (final e in s.completed.values) {
      stars += e['stars'] ?? 0;
    }

    return Scaffold(
      body: AuroraBackground(
        hue: 268,
        accentHue: 210,
        child: SafeArea(
          child: Column(
            children: [
              PremiumHeader(
                title: 'PUAN & RÜTBE',
                subtitle: 'Ön sıraya tırman — her blok seni yükseltir',
                onBack: () => Navigator.pop(context),
                trailing: ResourceChip(coins: s.coins),
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                  children: [
                    // rütbe madalyonu — büyük, parıltılı, kademeli gradyan
                    Center(
                      child: _RankMedallion(rank: rank, points: pts),
                    ),
                    const SizedBox(height: AppSpace.md),
                    if (toNext != null)
                      _NextTierBar(points: pts, toNext: toNext)
                    else
                      const Center(
                        child: Text('👑 ZİRVEDESİN — EFSANE',
                            style: TextStyle(
                                color: NeonPalette.amber,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2)),
                      ),
                    const SizedBox(height: AppSpace.lg),
                    // istatistik paneli
                    GlassPanel(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      radius: AppRadius.md,
                      glow: false,
                      child: Column(
                        children: [
                          _StatRow(
                              icon: Icons.star_rounded,
                              label: 'Toplam yıldız',
                              value: '$stars'),
                          _StatRow(
                              icon: Icons.grid_view_rounded,
                              label: 'Dizilen blok',
                              value: '${s.totalBlocks}'),
                          _StatRow(
                              icon: Icons.bolt_rounded,
                              label: 'Mükemmel bırakış',
                              value: '${s.totalPerfect}'),
                          _StatRow(
                              icon: Icons.emoji_events_rounded,
                              label: 'Bitirilen bölüm',
                              value: '${s.levelsDone}'),
                          _StatRow(
                              icon: Icons.today_rounded,
                              label: 'Günün rekoru',
                              value: '${s.daily['best'] ?? 0}'),
                          _StatRow(
                              icon: Icons.dark_mode_rounded,
                              label: 'Kabus rekoru',
                              value: '${s.nightmareBest}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    // sıralama yüzdesi — "ön sıraya geçme" kancası
                    GlassPanel(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      radius: AppRadius.md,
                      glow: true,
                      glowColor: NeonPalette.cyan,
                      child: Column(
                        children: [
                          Text('SIRALAMA',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(letterSpacing: 2.4)),
                          const SizedBox(height: AppSpace.sm),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 150,
                                height: 150,
                                child: CircularProgressIndicator(
                                  value: (100 - pct) / 100,
                                  strokeWidth: 10,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: .08),
                                  valueColor: const AlwaysStoppedAnimation(
                                      NeonPalette.cyan),
                                ),
                              ),
                              Column(
                                children: [
                                  Text('İLK %${100 - pct}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: NeonPalette.cyan)),
                                  const Text('oyuncunun içinde',
                                      style: TextStyle(
                                          color: NeonPalette.textDim,
                                          fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            pct == 0
                                ? 'Zirvedesin! Böyle devam 🏆'
                                : 'Zirveye $pct% oyuncuyu geçtin — bir sonraki rekor seni yukarı taşır',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: NeonPalette.textDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    // rütbe merdiveni — tüm kademeler, bulunduğun vurgulu
                    GlassPanel(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      radius: AppRadius.md,
                      glow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RÜTBE MERDİVENİ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(letterSpacing: 2.4)),
                          const SizedBox(height: AppSpace.md),
                          for (final r in kRankTable)
                            _LadderRow(
                              entry: r,
                              reached: pts >= r.points,
                              isCurrent: r == rank,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parıltılı rütbe madalyonu — kademeli gradyan + nabız (matematiksel, paketsiz).
class _RankMedallion extends StatelessWidget {
  const _RankMedallion({required this.rank, required this.points});
  final RankThreshold rank;
  final int points;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        width: 168,
        height: 168,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: rank.colors,
          ),
          boxShadow: [
            BoxShadow(
              color: rank.colors.first.withValues(alpha: .45),
              blurRadius: 26,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: .55), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(rank.icon, size: 52, color: Colors.white.withValues(alpha: .95)),
            const SizedBox(height: 6),
            Text(rank.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    fontSize: 16)),
            Text('$points PUAN',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .8),
                    fontSize: 11,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// Sonraki kademeye ilerleme çubuğu.
class _NextTierBar extends StatelessWidget {
  const _NextTierBar({required this.points, required this.toNext});
  final int points;
  final int toNext;

  @override
  Widget build(BuildContext context) {
    // mevcut kademe eşiği ile sonraki arasındaki ilerleme
    RankThreshold cur = kRankTable.first;
    for (final r in kRankTable) {
      if (points >= r.points) cur = r;
    }
    final nextPts = points + toNext;
    final span = (nextPts - cur.points).clamp(1, 1 << 30);
    final p = ((points - cur.points) / span).clamp(0.0, 1.0);
    return GlassPanel(
      padding: const EdgeInsets.all(AppSpace.md),
      radius: AppRadius.md,
      glow: false,
      child: Column(
        children: [
          Text('SONRAKİ KADEMEYE $toNext PUAN',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(letterSpacing: 1.6, color: NeonPalette.amber)),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: .08),
              valueColor: const AlwaysStoppedAnimation(NeonPalette.amber),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NeonPalette.cyan),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({required this.entry, required this.reached, required this.isCurrent});
  final RankThreshold entry;
  final bool reached;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: reached
                  ? LinearGradient(colors: entry.colors)
                  : null,
              color: reached ? null : Colors.white.withValues(alpha: .06),
              border: Border.all(
                color: isCurrent
                    ? NeonPalette.cyan
                    : Colors.white.withValues(alpha: .12),
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Icon(entry.icon,
                size: 17,
                color: reached
                    ? Colors.white
                    : Colors.white.withValues(alpha: .3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: reached
                        ? NeonPalette.text
                        : NeonPalette.textDim,
                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                  ),
            ),
          ),
          Text('${entry.points}+',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: NeonPalette.textDim)),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            const Icon(Icons.my_location_rounded, size: 14, color: NeonPalette.cyan),
          ],
        ],
      ),
    );
  }
}

