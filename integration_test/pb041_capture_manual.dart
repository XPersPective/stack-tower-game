/// PB-041 — PNG kanıt üretimi (host tarafı, cihazsız).
///
/// PlayScreen gerçek renderer'la (Skia/Impeller test pipeline) 392×844
/// mantıksal + 2× piksel oranında pump edilir; sahnenin RepaintBoundary'si
/// PNG'ye yazılır → .project-brain/evidence/PB-041/.
/// Çalıştırma: flutter test test/pb041_capture_widget_test.dart
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/screens/play_screen.dart';
import 'package:stack_tower_game/services/storage.dart';

const _outDir = '.project-brain/evidence/PB-041';

final GlobalKey _capKey = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  // KÖK boundary: HUD + sahne birlikte (tam ekran kanıt)
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_capKey));
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory(_outDir);
  dir.createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _host(GameSession session, LevelDef def) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: AudioController()),
    ],
    child: RepaintBoundary(
      key: _capKey,
      child: MaterialApp(
      home: PlayScreen(
        session: session,
        audio: AudioController(),
        def: def,
        onExit: () {},
        onFlowDone: () {},
      ),
      ),
    ),
  );
}

void _cap(String name, int levelIdx, GameKind kind) {
  testWidgets('$name PNG', (tester) async {
    tester.view.physicalSize = const Size(784, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final session = GameSession(MemoryStorage());
    session.state.devUnlockAll = true;
    expect(kindFor(levelIdx), kind);
    await tester.pumpWidget(_host(session, levelDef(levelIdx)));
    await tester.pump(const Duration(milliseconds: 500));
    await _capture(tester, name);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

void main() {
  _cap('renk_kapi_oyun', 15, GameKind.colorGate);
  _cap('neon_temizlik_secim', 16, GameKind.neonClean);
  _cap('uzun_karanlik_oyun', 17, GameKind.darkHole);
  _cap('hexa_neon_oyun', 18, GameKind.hexaMerge);
  _cap('pin_sirri_acilis', 19, GameKind.pinRoute);
  _cap('neon_akis_acilis', 20, GameKind.flowLink);
  _cap('zaman_kirici_oyun', 21, GameKind.timeFreeze);
  _cap('yercekimi_kapisi_oyun', 22, GameKind.gravityFlip);
  _cap('katamari_roll_oyun', 23, GameKind.katamariRoll);
}
