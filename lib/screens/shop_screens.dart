/// Stack Tower Game — mağaza (görünümler + ödül odası/kalıntılar) + görevler + ayarlar.
/// ui.js renderShop/renderRelics/renderMissions + settings karşılıkları.
///
/// Premium katman: canlı arka plan, cam kartlar, gradyan sekmeler, sayaç
/// animasyonlu ödüller ve basma tepkili dokunmatik hedefler.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/progress.dart' as prog;
import '../services/leaderboard_service.dart';
import '../services/session.dart';
import '../theme/tokens.dart';
import '../ui/aurora_background.dart';
import '../ui/premium_kit.dart';

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
      body: AuroraBackground(
        hue: 322,
        accentHue: 268,
        intensity: 0.85,
        showPlanet: false,
        child: SafeArea(
          child: Column(
            children: [
              PremiumHeader(
                title: relicsTab ? 'ÖDÜL ODASI' : 'MAĞAZA',
                subtitle: relicsTab
                    ? 'Dünyaların kalıntıları — her biri bir dünyanın mührü.'
                    : 'Görünümler kuleyi senin stilinle yeniden yazar.',
                onBack: () => Navigator.pop(context),
                trailing: ResourceChip(coins: session.state.coins),
              ),
              const SizedBox(height: AppSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        label: 'GÖRÜNÜMLER',
                        active: !relicsTab,
                        onTap: () => setState(() => relicsTab = false),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: _SegmentButton(
                        label: 'ÖDÜL ODASI',
                        active: relicsTab,
                        onTap: () => setState(() => relicsTab = true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: relicsTab
                    ? _RelicGrid(session: session)
                    : _SkinGrid(session: session),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sekme düğmesi — seçili durumda gradient + ışık.
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: appCurve,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            gradient: active
                ? const LinearGradient(colors: [
                    Color(0xFF2A1E7E),
                    Color(0xFF123A6E),
                  ])
                : null,
            color: active ? null : Colors.white.withValues(alpha: .05),
            border: Border.all(
              color: active
                  ? NeonPalette.cyan.withValues(alpha: .75)
                  : Colors.white.withValues(alpha: .12),
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: NeonPalette.cyan.withValues(alpha: .26),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active ? NeonPalette.text : NeonPalette.textDim,
                ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: .82,
          crossAxisSpacing: AppSpace.md,
          mainAxisSpacing: AppSpace.md),
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
              playRewardSound(context);
              showSnack(context, '✦ Görünüm kuşanıldı: ${skin.name}');
            } else {
              final r = session.buySkin(skin.id);
              if (!r.ok) {
                playErrorSound(context);
                showSnack(context,
                    r.reason == 'coins' ? 'Yeterli paran yok! Bölüm bitir, kutu aç.' : 'Zaten senin!');
                return;
              }
              playRewardSound(context);
              showSnack(context, '✦ Yeni görünüm: ${skin.name}');
            }
          },
        );
      },
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 16, color: NeonPalette.cyan),
        const SizedBox(width: 10),
        Flexible(child: Text(message)),
      ],
    ),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xF0141430),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: NeonPalette.cyan.withValues(alpha: .3)),
    ),
  ));
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
    final hue = skin.hue;
    return Semantics(
      button: true,
      label: '${skin.name} ${equipped ? "kuşanıldı" : owned ? "kuşan" : "${skin.price} para"}',
      child: PressableCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.md),
        radius: AppRadius.lg,
        borderColor: equipped
            ? NeonPalette.cyan
            : owned
                ? NeonPalette.cyan.withValues(alpha: .4)
                : afford
                    ? Colors.white24
                    : Colors.white12,
        glowColor: hsv(hue: hue),
        tint: equipped
            ? const Color(0xF21C2A50)
            : const Color(0xE60F0F22),
        child: Column(
          children: [
            // mini kule önizleme: 3 neon blok (ui.js towerPreview karşılığı)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      hsv(hue: hue).withValues(alpha: .14),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var k = 0; k < 3; k++)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        width: 68,
                        height: 17,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(hsv(hue: (hue + k * 12) % 360),
                                  Colors.white, 0.25)!,
                              hsv(hue: (hue + k * 12) % 360),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: hsv(hue: (hue + k * 12) % 360)
                                    .withValues(alpha: .55),
                                blurRadius: 12),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(skin.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (equipped)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 15, color: NeonPalette.cyan),
                  const SizedBox(width: 5),
                  Text('✓ KUŞANILDI',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: NeonPalette.cyan,
                            fontWeight: FontWeight.w800,
                          )),
                ],
              )
            else if (owned)
              Text('KUŞAN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: NeonPalette.textDim,
                        fontWeight: FontWeight.w700,
                      ))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CoinGlyph(size: 14),
                  const SizedBox(width: 5),
                  Text('${skin.price}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: afford ? NeonPalette.gold : NeonPalette.danger,
                            fontWeight: FontWeight.w800,
                          )),
                ],
              ),
          ],
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
    final ownedCount =
        prog.kRelics.where((r) => session.state.relics[r.stage.toString()] == true).length;
    return Column(
      children: [
        // PB-020: sezonluk rozet — 7 gün üst üste günlük
        if (prog.weeklyBadge(session.state))
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    size: 18, color: NeonPalette.star),
                const SizedBox(width: 8),
                Text('7 GÜN SERİSİ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NeonPalette.star,
                          letterSpacing: 1.4,
                        )),
                const Spacer(),
                Text('SEZON ROZETİ',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.md),
            radius: AppRadius.md,
            glow: false,
            child: Row(
              children: [
                Text('$ownedCount/${prog.kRelics.length}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: AppSpace.md),
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
        ),
        const SizedBox(height: AppSpace.md),
        Expanded(
          // 10 sabit kart: tembel kurulum gerektirmez, tüm liste ağaçta kalır.
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
            children: [
              for (var i = 0; i < prog.kRelics.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: _relicCard(context, session, i),
                ),
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
    return GlassPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      radius: AppRadius.md,
      glow: owned,
      glowColor: NeonPalette.star,
      borderColor: owned
          ? NeonPalette.star.withValues(alpha: .5)
          : Colors.white.withValues(alpha: .10),
      tint: owned ? const Color(0xE61E1A38) : const Color(0xD90C0C1C),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: owned
                  ? NeonPalette.star.withValues(alpha: .12)
                  : Colors.white.withValues(alpha: .04),
              border: Border.all(
                color: owned
                    ? NeonPalette.star.withValues(alpha: .45)
                    : Colors.white.withValues(alpha: .10),
              ),
            ),
            child: Text(owned ? r.icon : '🔒',
                style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owned ? r.name : 'KİLİTLİ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: owned ? NeonPalette.star : NeonPalette.textDim,
                        )),
                const SizedBox(height: 3),
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
      body: AuroraBackground(
        hue: 45,
        accentHue: 28,
        intensity: 0.8,
        showPlanet: false,
        child: SafeArea(
          child: Column(
            children: [
              PremiumHeader(
                title: 'GÖREVLER',
                subtitle: 'Her gün yenilenir · ödüller doğrudan cüzdanına',
                onBack: () => Navigator.pop(context),
                trailing: ResourceChip(coins: session.state.coins),
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: GlassPanel(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        radius: AppRadius.md,
                        glow: done && !claimed,
                        glowColor: NeonPalette.cyan,
                        borderColor: done && !claimed
                            ? NeonPalette.cyan.withValues(alpha: .55)
                            : Colors.white.withValues(alpha: .10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$goal ${m['label']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: AppSpace.sm),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: p / goal,
                                      minHeight: 8,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: .1),
                                      valueColor: AlwaysStoppedAnimation(
                                          done
                                              ? NeonPalette.cyan
                                              : NeonPalette.amber),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text('$p/$goal',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            SizedBox(
                              width: 108,
                              child: GradientButton(
                                label: claimed ? 'ALINDI ✓' : '+$reward 🪙',
                                compact: true,
                                height: 46,
                                enabled: done && !claimed,
                                colors: const [
                                  Color(0xFF2A1E7E),
                                  Color(0xFF12406E),
                                ],
                                onTap: () {
                                  final got = session.claimMissionAt(i);
                                  if (got != null) {
                                    playRewardSound(context);
                                    showSnack(context,
                                        'Görev ödülü alındı: +$got 🪙');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------ AYARLAR ------------------------------ */

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn(BuildContext context, AuthProvider provider, String kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<SessionService>();
    final lb = context.read<LeaderboardService>();
    final ok = await auth.signInWithProvider(provider, kind: kind);
    if (!mounted) return;
    if (ok) {
      lb.sessionToken = auth.token;
      unawaited(lb.flush()); // oturum açılınca kuyruğu gönder (PB-031)
      setState(() {
        _busy = false;
        _error = null; // önceki hata metni başarıda temizlenir
      });
    } else {
      setState(() {
        _busy = false;
        _error = 'Giriş başarısız. İnternet bağlantını veya sağlayıcı iznini kontrol et.';
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<SessionService>();
    final lb = context.read<LeaderboardService>();
    auth.signOutLocal();
    lb.sessionToken = null;
    // C-005: kuyruk asla kaybolmaz — yüklenmemiş skorlar yeniden girişte
    // (_signIn → flush) sunucuya gider; temizleme YALNIZ hesap silmede.
    setState(() {});
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final auth = context.read<SessionService>();
    final lb = context.read<LeaderboardService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Hesabı sil', style: TextStyle(color: NeonPalette.text)),
        content: const Text(
          'Hesabın ve bulut skorların kalıcı olarak silinir. Cihazındaki oyun ilerlemesi etkilenmez.',
          style: TextStyle(color: NeonPalette.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: NeonPalette.cyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: NeonPalette.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_busy) return; // istek sürerken onay diyaloğu tekrar tetiklenmesin
    _busy = true;
    // Sunucu onayı şart: çevrimdışı/sunucu hatasında oturum KORUNUR ve
    // hesap+skorlar sunucuda kalır (diyalogdaki "kalıcı olarak silinir"
    // vaadi ancak onaydan sonra geçerli — C-010).
    final ok = await auth.deleteAccount();
    if (!mounted) return;
    _busy = false;
    if (ok) {
      lb.sessionToken = null;
      lb.clearQueue();
      setState(() {
        _error = null; // önceki hata metni başarıda temizlenir
      });
    } else {
      setState(() {
        _error =
            'Hesap silinemedi. İnternet bağlantını kontrol edip tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SessionService>();
    final signedIn = auth.signedIn;
    return Scaffold(
      body: AuroraBackground(
        hue: 210,
        accentHue: 268,
        intensity: 0.8,
        showPlanet: false,
        child: SafeArea(
          child: Column(
            children: [
              PremiumHeader(
                title: 'AYARLAR',
                subtitle: 'Ses, hesap ve gizlilik',
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                  children: [
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg, vertical: AppSpace.xs),
                      radius: AppRadius.md,
                      glow: false,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ses',
                            style: TextStyle(color: NeonPalette.text)),
                        subtitle: const Text('Olay sesleri ve kombo katmanları'),
                        activeThumbColor: NeonPalette.cyan,
                        value: !context.watch<AudioController>().muted,
                        onChanged: (v) =>
                            context.read<AudioController>().setMuted(!v),
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),

                    /* --- PB-031: Hesap (Google/Apple) --- */
                    _SectionLabel('HESAP'),
                    GlassPanel(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      radius: AppRadius.md,
                      glow: false,
                      child: Column(
                        children: [
                          if (signedIn) ...[
                            Row(
                              children: [
                                const Icon(Icons.account_circle,
                                    color: NeonPalette.star, size: 34),
                                const SizedBox(width: AppSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(auth.displayName ?? 'Oyuncu',
                                          style: const TextStyle(
                                              color: NeonPalette.text,
                                              fontWeight: FontWeight.w700)),
                                      const Text('Bulut tahtasına bağlandın',
                                          style: TextStyle(color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.md),
                            _accountButton(
                              context,
                              label: 'ÇIKIŞ YAP',
                              color: Colors.white24,
                              enabled: !_busy,
                              onTap: () => _signOut(context),
                            ),
                            const SizedBox(height: AppSpace.sm),
                            _accountButton(
                              context,
                              label: 'HESABI SİL',
                              color: NeonPalette.danger.withValues(alpha: .2),
                              textColor: NeonPalette.danger,
                              enabled: !_busy,
                              onTap: () => _deleteAccount(context),
                            ),
                          ] else ...[
                            _accountButton(
                              context,
                              label: 'Google ile giriş',
                              color: NeonPalette.cyan.withValues(alpha: .16),
                              icon: Icons.g_mobiledata_rounded,
                              enabled: !_busy,
                              onTap: () => _signIn(
                                  context,
                                  // google_sign_in v7 Android'de idToken yalnız
                                  // serverClientId setliyken döner — release
                                  // için: --dart-define=GOOGLE_SERVER_CLIENT_ID=...
                                  GoogleAuthProvider(
                                      serverClientId: const String.fromEnvironment(
                                          'GOOGLE_SERVER_CLIENT_ID')),
                                  'google'),
                            ),
                            const SizedBox(height: AppSpace.sm),
                            // C-011: Apple girişi iOS'ta Google ile birlikte;
                            // Android'de plugin yok → buton hiç gösterilmez.
                            if (Platform.isIOS)
                              _accountButton(
                                context,
                                label: 'Apple ile giriş',
                                color: Colors.white.withValues(alpha: .12),
                                icon: Icons.apple,
                                enabled: !_busy,
                                onTap: () => _signIn(
                                    context, const AppleAuthProvider(), 'apple'),
                              ),
                          ],
                          if (_busy)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpace.sm),
                              child: Center(
                                  child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(strokeWidth: 2))),
                            ),
                          if (_error != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: AppSpace.sm),
                              child: Text(_error!,
                                  style: const TextStyle(color: NeonPalette.danger),
                                  textAlign: TextAlign.center),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),

                    _SectionLabel('Hakkında'),
                    GlassPanel(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      radius: AppRadius.md,
                      glow: false,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 18, color: NeonPalette.textDim),
                              const SizedBox(width: AppSpace.md),
                              Text('Sürüm 1.0.0+1',
                                  style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ),
                          const SizedBox(height: AppSpace.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.shield_outlined,
                                  size: 18, color: NeonPalette.mint),
                              const SizedBox(width: AppSpace.md),
                              Expanded(
                                child: Text(
                                  'Reklam ve analitik yoktur; oyun ilerlemeniz yalnızca '
                                  'cihazınızda saklanır. Hesap verileri (e-posta hariç, '
                                  'yalnızca sağlayıcı kimliği) bulut skor tahtası içindir.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
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

  Widget _accountButton(BuildContext context,
      {required String label,
      required Color color,
      Color? textColor,
      IconData? icon,
      required bool enabled,
      required VoidCallback onTap}) {
    return PressScale(
      onTap: enabled ? onTap : () {},
      haptic: false,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: color,
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, color: textColor ?? NeonPalette.text),
            if (icon != null) const SizedBox(width: 10),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: textColor ?? NeonPalette.text)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.xs, bottom: AppSpace.sm),
      child: Text(text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: NeonPalette.cyan,
                letterSpacing: 1.2,
              )),
    );
  }
}
