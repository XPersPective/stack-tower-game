# -*- coding: utf-8 -*-
"""PB-039: social_screen kalıcılık + meydan okuma perdesi yaması."""
import io

p = 'lib/screens/social_screen.dart'
s = io.open(p, encoding='utf-8').read()

s = s.replace("""import 'package:flutter/material.dart';

import '../game/rank.dart';
import '../game/social.dart';""",
"""import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_session.dart';
import '../game/rank.dart';
import '../game/social.dart';""")

s = s.replace("""class _SocialScreenState extends State<SocialScreen> {
  ChatThread? _thread; // null = liste, dolu = sohbet

  @override
  Widget build(BuildContext context) {""",
"""class _SocialScreenState extends State<SocialScreen> {
  ChatThread? _thread; // null = liste, dolu = sohbet

  @override
  void initState() {
    super.initState();
    // PB-039: sohbete girildi — okunmamış balonu söndür
    context.read<GameSession>().markSocialRead();
  }

  @override
  Widget build(BuildContext context) {""")

s = s.replace(
    "              onTap: () => setState(() => _thread = ChatThread(bot.name)),",
    "              onTap: () => setState(() => _thread =\n"
    "                  context.read<GameSession>().loadThread(bot.name)),")

s = s.replace(
    "                    onPressed: () => setState(() => thread.addMine(p.text)),",
    "                    onPressed: () {\n"
    "                      setState(() => thread.addMine(p.text));\n"
    "                      context.read<GameSession>().persistThread(thread);\n"
    "                    },")

s = s.replace("""          onTap: () {
              setState(() {
                thread.addMine('Meydan okuyorum!', isChallenge: true);
              });
            },""",
"""          onTap: () => _openChallenge(context, thread),""")

curtain = '''
  /// PB-039: meydan okuma perdesi — aynı tohumlu GÜNLÜK bölümde botun
  /// skorunu geç. Sonuç sohbete yazılır.
  void _openChallenge(BuildContext context, ChatThread thread) {
    final session = context.read<GameSession>();
    final day = dayOfNow();
    final week = day ~/ 7;
    final botScore = challengeBotScore(thread.botName, week);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _ChallengeCurtain(
        botName: thread.botName,
        botScore: botScore,
        onStart: () async {
          Navigator.pop(sheetCtx);
          final audio = context.read<AudioController>();
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PlayScreen(
                session: session,
                audio: audio,
                def: dailyDef(day),
                onExit: () {},
                onFlowDone: () {
                  final myBest = session.state.dailyHistory[day] ?? 0;
                  final won = myBest > botScore;
                  setState(() {
                    thread.addMine(
                      won
                          ? 'Günlük bölümde $myBest yaptım — '
                              'senin $botScore skoru geçildi!'
                          : 'Bu sefer $myBest oldu; $botScore '
                              'skoruna yetişemedim, tekrar deneyeceğim!',
                      isChallenge: true,
                    );
                    if (won) {
                      thread.messages.add(SocialMessage(
                          thread.botName,
                          'Vay be! Hakettin — tebrikler! '
                          'Tekrar meydan okurum...',
                          mine: false));
                    }
                  });
                  session.persistThread(thread);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// PB-039: meydan okuma perdesi — bot + skor + aynı tohum bölümü.
class _ChallengeCurtain extends StatelessWidget {
  const _ChallengeCurtain({
    required this.botName,
    required this.botScore,
    required this.onStart,
  });

  final String botName;
  final int botScore;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF140B22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: NeonPalette.magenta.withValues(alpha: .5)),
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MEYDAN OKUMA',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: NeonPalette.magenta)),
            const SizedBox(height: AppSpace.sm),
            Text(botName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Günlük bölümde $botScore blok dizdi — AYNI tohumu oyna, geç!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.md),
            GlassPanel(
              glow: false,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [
                    Text('$botScore',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: NeonPalette.magenta)),
                    const Text('BOT SKORU',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            color: NeonPalette.textDim)),
                  ]),
                  Container(
                      width: 1,
                      height: 34,
                      color: Colors.white.withValues(alpha: .15)),
                  const Column(children: [
                    Text('GÜNLÜK',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: NeonPalette.cyan)),
                    Text('AYNI BÖLÜM',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            color: NeonPalette.textDim)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            GradientButton(
              label: 'AYNI BÖLÜMÜ OYNA',
              icon: Icons.sports_esports_rounded,
              expand: true,
              height: 50,
              onTap: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

/// Oyuncu kartı — rütbe madalyonu + ŞEFFAF BOT etiketi.'''

s = s.replace("/// Oyuncu kartı — rütbe madalyonu + ŞEFFAF BOT etiketi.", curtain, 1)

s = s.replace("""import '../game/game_session.dart';
import '../game/rank.dart';""",
"""import '../game/game_session.dart';
import '../game/levels.dart' show dailyDef;
import '../game/rank.dart';""")
s = s.replace("""import '../game/social.dart';
import '../game/scene_painter.dart' show hslColor;
import '../theme/tokens.dart';
import '../ui/aurora_background.dart';
import '../ui/premium_kit.dart';""",
"""import '../game/social.dart';
import '../game/scene_painter.dart' show hslColor;
import '../router.dart' show dayOfNow;
import '../theme/tokens.dart';
import '../ui/aurora_background.dart';
import '../ui/premium_kit.dart';
import 'play_screen.dart';""")

io.open(p, 'w', encoding='utf-8').write(s)
print('social_screen ok')
