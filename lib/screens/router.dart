/// Stack Tower Game — ekran yönlendirme tablosu.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/audio.dart';
import '../game/game_session.dart';
import '../game/levels.dart';
import 'map_screen.dart';
import 'rank_screen.dart';
import 'market_screen.dart';
import 'menu_screen.dart';
import 'play_screen.dart';
import 'preview_screen.dart';
import 'shop_screens.dart';

/// Adlandırılmış rota sabitleri.
int dayOfNow() => DateTime.now().millisecondsSinceEpoch ~/ 86400000;

class Routes {
  static const menu = '/';
  static const map = '/map';
  static const preview = '/preview';
  static const play = '/play';
  static const playEndless = '/play-endless';
  static const playNightmare = '/play-nightmare'; // PB-035 B3
  static const rank = '/rank'; // PB-036: kişisel puan & rütbe sayfası
  static const shop = '/shop';
  static const market = '/market';
  static const missions = '/missions';
  static const settings = '/settings';
}

Widget routeFor(RouteSettings settings) {
  switch (settings.name) {
    case Routes.map:
      return const MapScreen();
    case Routes.shop:
      return const ShopScreen();
    case Routes.market:
      return const MarketScreen();
    case Routes.missions:
      return const MissionsScreen();
    case Routes.settings:
      return const SettingsScreen();
    case Routes.preview:
      return PreviewScreen(def: settings.arguments as LevelDef);
    case Routes.play:
      return PlayRoute(def: settings.arguments as LevelDef);
    case Routes.playEndless:
      return PlayRoute(def: endlessDef());
    case Routes.playNightmare:
      return PlayRoute(
          def: nightmareDef(weekOf(dayOfNow()))); // günün haftası tohumu
    case Routes.rank:
      return const RankScreen();
    case Routes.menu:
    default:
      return const MenuScreen();
  }
}

/// Premium sayfa geçişi — hafif ölçek + fade, yumuşak easing.
///
/// Oyun ekranı (play) hızlı geçiş kullanır (tekrar oynatmada bekletmez);
/// diğer ekranlar sinematik geçiş kullanır.
class _FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  _FadeScalePageRoute({required Widget page, this.duration = const Duration(milliseconds: 320)})
      : super(
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );

  final Duration duration;
}

/// Rotayı üretir: oyun ekranı hızlı, diğerleri sinematik geçiş kullanır.
Route<dynamic> buildRoute(RouteSettings settings) {
  final page = routeFor(settings);
  final fast = settings.name == Routes.play || settings.name == Routes.playEndless;
  return _FadeScalePageRoute(
    page: page,
    duration: fast
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 340),
  );
}

/// play ekranı argümanıyla: haritaya dönüş akışını router'da yönetir.
class PlayRoute extends StatelessWidget {
  const PlayRoute({super.key, required this.def});
  final LevelDef def;

  @override
  Widget build(BuildContext context) {
    return PlayScreen(
      session: context.read<GameSession>(),
      audio: context.read<AudioController>(),
      def: def,
      onExit: () {
        Navigator.of(context).popUntil((r) => r.settings.name == Routes.map || r.isFirst);
      },
      onFlowDone: () {
        // zincir bitti → haritaya dön (ui.js setTimeout(showMap) karşılığı)
        Navigator.of(context).popUntil((r) => r.settings.name == Routes.map || r.isFirst);
      },
    );
  }
}
