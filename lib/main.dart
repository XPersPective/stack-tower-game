import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/audio.dart';
import 'game/game_session.dart';
import 'services/leaderboard_service.dart';
import 'services/session.dart';
import 'services/storage.dart';
import 'screens/router.dart';
import 'theme/tokens.dart';
import 'ui/ambient.dart';

/// Üretim skor tahtası backend'i (Cloudflare Workers + D1, SPEC §7).
/// Derleme zamanında --dart-define=LB_API_BASE=... ile geçersiz kılınabilir.
/// Değer yoksa/kapatılırsa tüm ağ çağrıları güvenle başarısız olur ve
/// oyun yalnız yerel tahtayla devam eder (C-005).
const String kLeaderboardApiBase = String.fromEnvironment(
  'LB_API_BASE',
  defaultValue: 'https://stacktower-leaderboard.example.dev',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dikey mod kilidi (SPEC §3) + immersive edge-to-edge.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // iOS: açık renk status bar içeriği (koyu zeminde okunur)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark, // iOS: koyu zemin → açık ikonlar
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: NeonPalette.ink,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();
  final storage = SharedPreferencesStorage(prefs);

  // PB-031: native güvenli depo (keychain/keystore) + oturum servisi.
  final secure = FlutterSecureStore();
  final authSession = SessionService(
    store: secure,
    transport: IoHttpTransport(kLeaderboardApiBase),
  );
  await authSession.init(); // kalıcı oturumu belleğe yükle

  // PB-011: skor kuyruğu + bulut tahtası (kuyruk asla kaybolmaz, C-005).
  final leaderboard = LeaderboardService(
    storage: storage,
    transport: IoHttpTransport(kLeaderboardApiBase),
    sessionToken: authSession.token,
  );

  final audio = AudioController(storage: storage);
  audio.preload(); // ateşle-unut: yükleme arka planda tamamlanır
  audio.ensureMusic(); // PB-033/034: arka plan müzik döngüsü (sessiz ayarına saygılı)

  // Ortam animasyonları (aurora gökyüzü, nefes alan logo) üretimde açıktır;
  // testlerde kapalı kalır (deterministik `pumpAndSettle`).
  AmbientMotion.enable();

  final gameSession = GameSession(storage);
  gameSession.leaderboard = leaderboard;

  // Uygulama öne gelince kuyruğu boşalt (oturum varsa).
  WidgetsBinding.instance.addObserver(_FlushOnResume(leaderboard));

  runApp(StackTowerApp(
    session: gameSession,
    audio: audio,
    authSession: authSession,
    leaderboard: leaderboard,
  ));
}

/// Uygulama öne dönünce tek eşzamanlı flush (PB-031 adım 7).
class _FlushOnResume with WidgetsBindingObserver {
  _FlushOnResume(this.lb);
  final LeaderboardService lb;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && lb.sessionToken != null) {
      unawaited(lb.flush());
    }
  }
}

class StackTowerApp extends StatelessWidget {
  const StackTowerApp({
    super.key,
    required this.session,
    required this.audio,
    this.authSession,
    this.leaderboard,
  });

  final GameSession session;
  final AudioController audio;
  final SessionService? authSession;
  final LeaderboardService? leaderboard;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: audio),
        // Oturum/tahta servisleri üretimde main() tarafından sağlanır; widget
        // testleri bunları vermeden app'i pump edebilir → koşullu sağla.
        if (authSession != null)
          Provider<SessionService>.value(value: authSession!),
        if (leaderboard != null)
          Provider<LeaderboardService>.value(value: leaderboard!),
      ],
      child: MaterialApp(
        title: 'Stack Tower Game',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        initialRoute: Routes.menu,
        onGenerateRoute: buildRoute,
      ),
    );
  }
}
