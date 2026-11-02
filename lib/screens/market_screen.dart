/// Stack Tower Game — PAZAR YERİ ekranı (PB-018).
/// Günlük rotasyon (3 ürün + gizli sandık), tek stok, anında kayıt.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/market.dart';
import '../game/progress.dart' as prog;
import '../game/scene_painter.dart' show hslColor;
import '../theme/tokens.dart';
import '../ui/aurora_background.dart';
import '../ui/premium_kit.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, this.rand});

  /// Test enjeksiyonu: sandık değişken oranı.
  final math.Random? rand;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String? _lastMessage;
  bool _lastOk = true;

  @override
  void initState() {
    super.initState();
    // gün değiştiyse stok tazelenir — build sırasında notify olmasın diye
    // ilk kareden sonra yazılır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<GameSession>();
      final day = prog.dayOf(DateTime.now());
      if (session.state.marketDay != day) {
        rollDay(session.state, day);
        session.persist();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    final day = prog.dayOf(DateTime.now());
    final stock = dailyStock(day);

    return Scaffold(
      body: AuroraBackground(
        hue: 35,
        accentHue: 20,
        intensity: 0.85,
        showPlanet: false,
        child: SafeArea(
          child: Column(
            children: [
              PremiumHeader(
                title: 'PAZAR YERİ',
                subtitle: 'Her üründen tek adet · tezgah gece yarısı tazelenir',
                onBack: () => Navigator.pop(context),
                trailing: ResourceChip(coins: session.state.coins),
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded,
                            size: 16, color: NeonPalette.amber),
                        const SizedBox(width: 8),
                        Text('BUGÜNÜN TEZGAHI · GÜN ${day % 1000}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(letterSpacing: 1.6)),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    for (final e in stock) ...[
                      _EntryCard(
                        entry: e,
                        soldOut: soldOut(session.state, e),
                        owned: e.kind == MarketKind.skin &&
                            e.skinId != null &&
                            session.state.skins.contains(e.skinId),
                        affordable: session.state.coins >= e.price,
                        onBuy: () => _buy(session, e, day),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                    const SizedBox(height: AppSpace.md),
                    _TomorrowStrip(day: day),
                    if (_lastMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.sm),
                        child: _MarketMessage(message: _lastMessage!, ok: _lastOk),
                      ),
                    const SizedBox(height: AppSpace.lg),
                    GlassPanel(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      radius: AppRadius.md,
                      glow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.help_outline_rounded,
                                  size: 16, color: NeonPalette.textDim),
                              const SizedBox(width: 8),
                              Text('PAZAR NASIL ÇALIŞIR?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(letterSpacing: 1.4)),
                            ],
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            'Kalkan ve çarpan bir sonraki bölümde kullanılır. Joker, '
                            'kazanılan bölüme +1 yıldız ekler. Sandık değişken oranlıdır: '
                            'para, görünüm veya kalıntı parçası (3 parça = 1 kalıntı).',
                            style: Theme.of(context).textTheme.bodySmall,
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

  void _buy(GameSession session, MarketEntry e, int day) {
    final res = buy(session.state, e, rand: widget.rand, stage: _stage(session));
    if (res.ok) {
      session.persist();
      _audio(context).play(e.isChest ? GameSound.mystery : GameSound.coin);
      if (e.isChest) _audio(context).play(GameSound.reward);
    } else {
      _audio(context).play(GameSound.error);
    }
    setState(() {
      _lastOk = res.ok;
      _lastMessage = res.message;
    });
  }

  int _stage(GameSession session) {
    final done = session.state.levelsDone;
    return (done ~/ 15).clamp(0, 9);
  }

  AudioController _audio(BuildContext context) => context.read<AudioController>();
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.soldOut,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });

  final MarketEntry entry;
  final bool soldOut;
  final bool owned;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final accent = hslColor(entry.hue, 92, 68);
    return GlassPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      radius: AppRadius.lg,
      glow: !soldOut,
      glowColor: accent,
      borderColor: soldOut ? Colors.white12 : accent.withValues(alpha: .55),
      tint: soldOut ? const Color(0xD90C0C1C) : const Color(0xE6141430),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: soldOut ? .06 : .14),
              border: Border.all(
                  color: accent.withValues(alpha: soldOut ? .18 : .45)),
            ),
            child: Text(entry.icon, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: soldOut ? Colors.white38 : accent)),
                const SizedBox(height: 2),
                Text(entry.hint,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinGlyph(size: 13),
                  const SizedBox(width: 5),
                  Text('${entry.price}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: affordable ? NeonPalette.star : Colors.white38,
                            fontWeight: FontWeight.w800,
                          )),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 104,
                child: GradientButton(
                  label: soldOut ? 'TÜKENDİ' : (owned ? 'SAHİPSİN' : 'AL'),
                  compact: true,
                  height: 40,
                  enabled: !soldOut && !owned && affordable,
                  colors: [accent.withValues(alpha: .45), accent.withValues(alpha: .18)],
                  onTap: onBuy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satın alma sonrası mesaj şeridi.
class _MarketMessage extends StatelessWidget {
  const _MarketMessage({required this.message, required this.ok});

  final String message;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? NeonPalette.cyan : NeonPalette.gold;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.info_rounded,
              size: 16, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: color, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }
}

/// PB-034 D3: "YARIN: 3 ürün" şeridi — gün tohumu deterministik olduğu için
/// yarınki tezgâh bedava öngörülür; dönüş kancası (Township bekleme hissi).
class _TomorrowStrip extends StatelessWidget {
  const _TomorrowStrip({required this.day});
  final int day;

  @override
  Widget build(BuildContext context) {
    final names = tomorrowStock(day + 1).map((e) => e.name).join(' · ');
    return GlassPanel(
      padding: const EdgeInsets.all(AppSpace.md),
      radius: AppRadius.md,
      glow: false,
      child: Row(
        children: [
          const Icon(Icons.update_rounded, size: 16, color: NeonPalette.mint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'YARIN: $names',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NeonPalette.textDim,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
