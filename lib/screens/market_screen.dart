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
import 'flow_overlays.dart' show NeonButton;

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
      appBar: AppBar(
        title: const Text('PAZAR YERİ'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: Text('🪙 ${session.state.coins}',
                    style: Theme.of(context).textTheme.titleLarge)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('BUGÜNÜN TEZGAHI · GÜN ${day % 1000}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('Her üründen tek adet. Gece yarısı tezgah tazelenir.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
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
            const SizedBox(height: 10),
          ],
          if (_lastMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _lastMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _lastOk ? NeonPalette.cyan : NeonPalette.gold,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
          const SizedBox(height: 18),
          Text('PAZAR NASIL ÇALIŞIR?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(letterSpacing: 2)),
          const SizedBox(height: 6),
          Text(
            'Kalkan ve çarpan bir sonraki bölümde kullanılır. Joker, kazanılan '
            'bölüme +1 yıldız ekler. Sandık değişken oranlıdır: para, görünüm '
            'veya kalıntı parçası (3 parça = 1 kalıntı).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _buy(GameSession session, MarketEntry e, int day) {
    final res = buy(session.state, e, rand: widget.rand, stage: _stage(session));
    if (res.ok) {
      session.persist();
      _audio(context).play(e.isChest ? GameSound.mystery : GameSound.coin);
    } else {
      _audio(context).play(GameSound.lose);
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC0a0a1e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: soldOut ? Colors.white12 : accent.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Text(entry.icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: soldOut ? Colors.white38 : accent)),
                const SizedBox(height: 2),
                Text(entry.hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text('${entry.price} 🪙',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: affordable ? NeonPalette.star : Colors.white38)),
              const SizedBox(height: 6),
              SizedBox(
                width: 92,
                child: NeonButton(
                  soldOut ? 'TÜKENDİ' : (owned ? 'SAHİPSİN' : 'AL'),
                  onBuy,
                  enabled: !soldOut && !owned && affordable,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
