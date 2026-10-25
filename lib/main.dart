import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/audio.dart';
import 'game/game_session.dart';
import 'screens/router.dart';
import 'services/storage.dart';
import 'theme/tokens.dart';

Future<void> main() async {
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

  final prefs = await SharedPreferences.getInstance();
  final audio = AudioController();
  unawaited(audio.preload());

  runApp(StackTowerApp(
    session: GameSession(SharedPreferencesStorage(prefs)),
    audio: audio,
  ));
}

class StackTowerApp extends StatelessWidget {
  const StackTowerApp({super.key, required this.session, required this.audio});

  final GameSession session;
  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: audio),
      ],
      child: MaterialApp(
        title: 'Stack Tower Game',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        initialRoute: Routes.menu,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => routeFor(settings),
        ),
      ),
    );
  }
}
