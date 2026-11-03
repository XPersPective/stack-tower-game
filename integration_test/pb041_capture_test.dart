/// PB-041 — cihaz-üstü PNG kanıt üretimi (kullanıcı yasası: ekran görüntüsü
/// doğrulaması). 3 yeni oyun gerçek renderer ile pump edilir, RepaintBoundary
/// PNG'ye çevrilip uygulamanın kendi external files dizinine yazılır; adb pull
/// ile toplanır. Elle etkileşim YOK — emülatör bellek baskısına dayanıklı.
///
/// Çalıştırma: flutter test integration_test/pb041_capture_test.dart -d emulator-5554
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/screens/play_screen.dart';
import 'package:stack_tower_game/services/storage.dart';

Future<void> _capture(WidgetTester tester, String name) async {
  // sahnenin RepaintBoundary'sini bul (play_screen içindeki ilk boundary)
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(
      of: find.byType(PlayScreen),
      matching: find.byType(RepaintBoundary),
    ).first,
  );
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory(
      '/storage/emulated/0/Android/data/com.stacktower.stack_tower_game/files');
  dir.createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('PB041_CAPTURE: $name.png bytes=${bytes.buffer.lengthInBytes}');
}

/// Oyun sahnesinde belirli orandaki noktaya dokun (tek dokunuş yasası C-022).
Future<void> _tapAt(WidgetTester tester, double fx, double fy) async {
  final size = tester.getSize(find.byType(PlayScreen).first);
  final origin = tester.getTopLeft(find.byType(PlayScreen).first);
  await tester.tapAt(Offset(origin.dx + size.width * fx,
      origin.dy + size.height * fy));
}

Widget _host(GameSession session, LevelDef def) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: AudioController()),
    ],
    child: MaterialApp(
      home: PlayScreen(
        session: session,
        audio: AudioController(),
        def: def,
        onExit: () {},
        onFlowDone: () {},
      ),
    ),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('PB-041 üç yeni oyun cihaz PNG kanıtı', (tester) async {
    final session = GameSession(MemoryStorage());
    session.state.devUnlockAll = true;

    // 1) RENK KAPI (i=15 → colorGate)
    expect(kindFor(15), GameKind.colorGate);
    await tester.pumpWidget(_host(session, levelDef(15)));
    await tester.pump(const Duration(milliseconds: 800));
    await _capture(tester, 'pb041_renk_kapi');

    // oynanış: dokunuşlar → top zıplar
    await _tapAt(tester, 0.5, 0.5);
    await tester.pump(const Duration(milliseconds: 300));
    await _tapAt(tester, 0.5, 0.5);
    await tester.pump(const Duration(milliseconds: 500));
    await _capture(tester, 'pb041_renk_kapi_oyun');

    // 2) NEON TEMİZLİK (i=16 → neonClean)
    expect(kindFor(16), GameKind.neonClean);
    await tester.pumpWidget(_host(session, levelDef(16)));
    await tester.pump(const Duration(milliseconds: 800));
    await _capture(tester, 'pb041_neon_temizlik');
    // el kartı seçimi → hayalet önizleme
    await _tapAt(tester, 0.25, 0.9);
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, 'pb041_neon_temizlik_secim');

    // 3) UZUN KARANLIK (i=17 → darkHole)
    expect(kindFor(17), GameKind.darkHole);
    await tester.pumpWidget(_host(session, levelDef(17)));
    await tester.pump(const Duration(milliseconds: 800));
    await _capture(tester, 'pb041_uzun_karanlik');
    // delik süzülmesi: dokun → hedefe gitsin
    await _tapAt(tester, 0.3, 0.4);
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, 'pb041_uzun_karanlik_oyun');
  });
}
