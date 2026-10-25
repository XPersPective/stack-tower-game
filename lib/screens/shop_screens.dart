/// Stack Tower Game — mağaza (görünümler + ödül odası/kalıntılar) + görevler + ayarlar.
/// ui.js renderShop/renderRelics/renderMissions + settings karşılıkları.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/progress.dart' as prog;
import '../theme/tokens.dart';

/* ------------------------------ MAĞAZA ------------------------------ */

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool relicsTab = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    return Scaffold(
      appBar: AppBar(
        title: Text(relicsTab ? 'ÖDÜL ODASI' : 'MAĞAZA'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('🪙 ${session.state.coins}',
                style: Theme.of(context).textTheme.titleLarge)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _tabButton('GÖRÜNÜMLER', !relicsTab,
                    () => setState(() => relicsTab = false))),
                const SizedBox(width: 8),
                Expanded(child: _tabButton('ÖDÜL ODASI', relicsTab,
                    () => setState(() => relicsTab = true))),
              ],
            ),
          ),
          Expanded(
            child: relicsTab ? _RelicGrid(session: session) : _SkinGrid(session: session),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? NeonPalette.cyan.withValues(alpha: .16) : Colors.white.withValues(alpha: .04),
          border: Border.all(
              color: active ? NeonPalette.cyan.withValues(alpha: .6) : Colors.white24),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _SkinGrid extends StatelessWidget {
  const _SkinGrid({required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: .95, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: prog.kSkins.length,
      itemBuilder: (context, i) {
        final skin = prog.kSkins[i];
        final owned = session.state.skins.contains(skin.id);
        final equipped = session.state.activeSkin == skin.id;
        final afford = session.state.coins >= skin.price;
        return _SkinCard(
          skin: skin,
          owned: owned,
          equipped: equipped,
          afford: afford,
          onTap: () {
            if (equipped) return;
            if (owned) {
              session.equip(skin.id);
              showSnack(context, '✦ Görünüm kuşanıldı: ${skin.name}');
            } else {
              final r = session.buySkin(skin.id);
              if (!r.ok) {
                showSnack(context,
                    r.reason == 'coins' ? 'Yeterli paran yok! Bölüm bitir, kutu aç.' : 'Zaten senin!');
                return;
              }
              showSnack(context, '✦ Yeni görünüm: ${skin.name}');
            }
          },
        );
      },
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.owned,
    required this.equipped,
    required this.afford,
    required this.onTap,
  });

  final prog.Skin skin;
  final bool owned;
  final bool equipped;
  final bool afford;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${skin.name} ${equipped ? "kuşanıldı" : owned ? "kuşan" : "${skin.price} para"}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: .05),
            border: Border.all(
              color: equipped
                  ? NeonPalette.cyan
                  : owned
                      ? NeonPalette.cyan.withValues(alpha: .4)
                      : afford
                          ? Colors.white24
                          : Colors.white12,
              width: equipped ? 2 : 1.2,
            ),
          ),
          child: Column(
            children: [
              // mini kule önizleme: 3 neon blok (ui.js towerPreview karşılığı)
              SizedBox(
                height: 66,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var k = 0; k < 3; k++)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        width: 64 - k * 0,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: hsv(hue: (skin.hue + k * 12) % 360),
                          boxShadow: [
                            BoxShadow(
                                color: hsv(hue: (skin.hue + k * 12) % 360).withValues(alpha: .6),
                                blurRadius: 10),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(skin.name, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (equipped)
                const Text('✓ KUŞANILDI',
                    style: TextStyle(color: NeonPalette.cyan, fontWeight: FontWeight.w800))
              else if (owned)
                const Text('KUŞAN',
                    style: TextStyle(color: NeonPalette.textDim, fontWeight: FontWeight.w700))
              else
                Text('${skin.price} 🪙',
                    style: TextStyle(
                        color: afford ? NeonPalette.gold : Colors.redAccent,
                        fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  static Color hsv({required int hue}) =>
      HSVColor.fromAHSV(1, hue.toDouble(), .95, .72).toColor();
}

class _RelicGrid extends StatelessWidget {
  const _RelicGrid({required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final ownedCount = prog.kRelics.where((r) => session.state.relics[r.stage.toString()] == true).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('$ownedCount/${prog.kRelics.length}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ownedCount / prog.kRelics.length,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: .1),
                    valueColor: const AlwaysStoppedAnimation(NeonPalette.star),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          // 10 sabit kart: tembel kurulum gerektirmez, tüm liste ağaçta kalır.
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              for (var i = 0; i < prog.kRelics.length; i++) _relicCard(context, session, i),
            ],
          ),
        ),
      ],
    );
  }

  Widget _relicCard(BuildContext context, GameSession session, int i) {
    final r = prog.kRelics[i];
    final owned = session.state.relics[r.stage.toString()] == true;
    final worldName = kThemes[r.stage].name;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: owned ? Colors.white.withValues(alpha: .06) : Colors.white.withValues(alpha: .02),
        border: Border.all(
            color: owned ? NeonPalette.star.withValues(alpha: .5) : Colors.white12),
      ),
      child: Row(
        children: [
          Text(owned ? r.icon : '🔒', style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owned ? r.name : 'KİLİTLİ',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(owned ? r.lore : '$worldName aydınlanınca kazanılır',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ GÖREVLER ------------------------------ */

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  @override
  void initState() {
    super.initState();
    // Görevler gün değişiminde yenilenir; build fazında notify tetiklememek
    // için ilk frame çizildikten sonra çalıştır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameSession>().refreshMissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    final items = session.missionItemsSafe();
    return Scaffold(
      appBar: AppBar(title: const Text('GÖREVLER')),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final m = items[i];
          final goal = m['goal'] as int;
          final claimed = m['claimed'] == true;
          final reward = m['reward'] as int;
          final progress = session.state;
          final stat = m['stat'] as String;
          final base = m['base'] as int;
          final current = stat == 'totalPerfect'
              ? progress.totalPerfect
              : stat == 'totalBlocks'
                  ? progress.totalBlocks
                  : progress.levelsDone;
          final p = (current - base).clamp(0, goal);
          final done = p >= goal;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: .05),
              border: Border.all(color: done && !claimed ? NeonPalette.cyan.withValues(alpha: .5) : Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$goal ${m['label']}', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p / goal,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: .1),
                          valueColor: AlwaysStoppedAnimation(
                              done ? NeonPalette.cyan : NeonPalette.amber),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$p/$goal', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: done && !claimed
                        ? () {
                            final got = session.claimMissionAt(i);
                            if (got != null) {
                              showSnack(context, 'Görev ödülü alındı: +$got 🪙');
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          done && !claimed ? NeonPalette.cyan : Colors.white12,
                      foregroundColor: Colors.black,
                      disabledForegroundColor: NeonPalette.textDim,
                    ),
                    child: Text(claimed ? 'ALINDI ✓' : '+$reward 🪙'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ------------------------------ AYARLAR ------------------------------ */

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AYARLAR')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          SwitchListTile(
            title: const Text('Ses', style: TextStyle(color: NeonPalette.text)),
            subtitle: const Text('Olay sesleri'),
            value: !context.watch<AudioController>().muted,
            onChanged: (v) => context.read<AudioController>().setMuted(!v),
          ),
          const Divider(color: Colors.white12),
          const ListTile(
            title: Text('Sürüm', style: TextStyle(color: NeonPalette.text)),
            subtitle: Text('1.0.0+1'),
          ),
          const ListTile(
            title: Text('Gizlilik', style: TextStyle(color: NeonPalette.text)),
            subtitle: Text('Reklam ve analitik yoktur; oyun ilerlemeniz yalnızca cihazınızda saklanır.'),
          ),
          // PB-011: hesap bölümü (Google/Apple girişi + skor tahtası) buraya eklenecek
        ],
      ),
    );
  }
}
