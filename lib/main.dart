import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Dikey mod kilidi (SPEC §3) + immersive edge-to-edge.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: NeonPalette.ink,
  ));
  runApp(const StackTowerApp());
}

class StackTowerApp extends StatelessWidget {
  const StackTowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stack Tower Game',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const PlaceholderMenuScreen(),
    );
  }
}

/// PB-001 geçici menü — PB-007'de tam menü ekranıyla değiştirilecek.
class PlaceholderMenuScreen extends StatelessWidget {
  const PlaceholderMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0c0a20), Color(0xFF1e1046)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [NeonPalette.cyan, NeonPalette.magenta],
                  ).createShader(b),
                  child: Text(
                    'STACK TOWER',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontVariations: [interVariation(FontWeight.w900)],
                          shadows: [
                            Shadow(color: NeonPalette.cyan.withValues(alpha: .6), blurRadius: 28),
                            Shadow(color: NeonPalette.magenta.withValues(alpha: .4), blurRadius: 36),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'G A M E',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: NeonPalette.textDim,
                        letterSpacing: 12,
                        fontVariations: [interVariation(FontWeight.w700)],
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
