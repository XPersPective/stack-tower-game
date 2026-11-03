/// Stack Tower Game — SOSYAL EKRAN (PB-038 MVP).
///
/// Oyuncu listesi (rütbe madalyonlu, ŞEFFAF BOT etiketli) → 1:1 sohbet
/// (mesaj balonları + 32 hazırcümle quick-chat şeridi + bot yanıtları) +
/// 'SENİ YENDİM' tohumlu meydan okuma. Serbest metin YOK (Apple 1.2).
library;

import 'package:flutter/material.dart';

import '../game/rank.dart';
import '../game/social.dart';
import '../game/scene_painter.dart' show hslColor;
import '../theme/tokens.dart';
import '../ui/aurora_background.dart';
import '../ui/premium_kit.dart';

/// Oyuncu listesi — menüden MESAJLAR düğmesiyle açılır.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  ChatThread? _thread; // null = liste, dolu = sohbet

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        hue: 210,
        accentHue: 268,
        child: SafeArea(
          child: Column(
            children: [
              PremiumHeader(
                title: 'MESAJLAR',
                subtitle: 'Rakiplerinle tanış, meydan oku',
                onBack: () {
                  if (_thread != null) {
                    setState(() => _thread = null);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: _thread == null
                    ? _buildPlayerList(context)
                    : _buildChat(context, _thread!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerList(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
      children: [
        for (final bot in kBotPlayers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: _PlayerCard(
              player: bot,
              onTap: () => setState(() => _thread = ChatThread(bot.name)),
            ),
          ),
      ],
    );
  }

  Widget _buildChat(BuildContext context, ChatThread thread) {
    return Column(
      children: [
        // sohbet başlığı
        GlassPanel(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.sm),
          radius: AppRadius.md,
          glow: false,
          child: Row(
            children: [
              _Avatar(hue: 268, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(thread.botName,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const Text('BOT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: NeonPalette.textDim)),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        // mesaj balonları
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: thread.messages.length,
            itemBuilder: (context, i) {
              final m = thread.messages[i];
              return Align(
                alignment:
                    m.mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          Radius.circular(m.mine ? 16 : 4),
                      bottomRight:
                          Radius.circular(m.mine ? 4 : 16),
                    ),
                    color: m.mine
                        ? NeonPalette.cyan.withValues(alpha: .18)
                        : hslColor(268, 40, 14),
                    border: Border.all(
                        color: m.mine
                            ? NeonPalette.cyan.withValues(alpha: .4)
                            : Colors.white.withValues(alpha: .12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.text,
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (m.isChallenge)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('⚔ MEYDAN OKUMA',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: NeonPalette.magenta,
                                  letterSpacing: 1.2)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // quick-chat şeridi — yatay kaydırılabilir hazırcümle düğmeleri
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            children: [
              for (final p in kQuickPhrases.take(12))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(p.text,
                        style: const TextStyle(
                            fontSize: 12, color: NeonPalette.text)),
                    backgroundColor: Colors.white.withValues(alpha: .06),
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: .16)),
                    onPressed: () => setState(() => thread.addMine(p.text)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        // meydan okuma düğmesi
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
          child: GradientButton(
            label: 'SENİ YENDİM — MEYDAN OKU',
            icon: Icons.sports_kabaddi_rounded,
            expand: true,
            height: 46,
            colors: const [Color(0xFF6B1236), Color(0xFF8F2437)],
            onTap: () {
              setState(() {
                thread.addMine('Meydan okuyorum!', isChallenge: true);
              });
            },
          ),
        ),
      ],
    );
  }
}

/// Oyuncu kartı — rütbe madalyonu + ŞEFFAF BOT etiketi.
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player, required this.onTap});
  final SocialPlayer player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rank = _rankForPoints(player.rankPoints);
    return GlassPanel(
      padding: const EdgeInsets.all(AppSpace.md),
      radius: AppRadius.md,
      glow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Row(
          children: [
            _Avatar(hue: player.avatarHue, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(player.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      // ŞEFFAF BOT etiketi — kandırma yok (RESEARCH-social)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          color: Colors.white.withValues(alpha: .08),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: .2)),
                        ),
                        child: const Text('BOT',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: NeonPalette.textDim)),
                      ),
                    ],
                  ),
                  Text('${rank.name} · ${player.rankPoints} puan',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: NeonPalette.textDim)),
                ],
              ),
            ),
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 20, color: NeonPalette.cyan),
          ],
        ),
      ),
    );
  }
}

/// Rütbe noktasından kademe — rank.dart tablosuyla aynı.
RankThreshold _rankForPoints(int points) {
  var best = kRankTable.first;
  for (final r in kRankTable) {
    if (points >= r.points) best = r;
  }
  return best;
}

/// Basit avatar daresi — dünya hue'lu gradyan.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.hue, required this.size});
  final int hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hslColor(hue, 85, 62),
            hslColor(hue, 75, 42),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .4)),
      ),
      child: Icon(Icons.person_rounded,
          size: size * 0.6, color: Colors.white.withValues(alpha: .9)),
    );
  }
}
