/// PB-030 görsel kanıt: önizleme TÜR KARTI + "sırada ne var" merak satırı.
/// Çıktı: .project-brain/evidence/PB-030/kind_card.png (PB_EVIDENCE=1 ile)
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/screens/preview_screen.dart';
import 'package:stack_tower_game/services/storage.dart';

Future<void> _loadInter() async {
  final file = File('assets/fonts/Inter.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('Inter')..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Widget _host(GameSession session, LevelDef def) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Inter', useMaterial3: false),
        home: PreviewScreen(def: def),
      ),
    );

void main() {
  setUpAll(_loadInter);

  testWidgets('PB-030: küçük ekranda (360×640) kart taşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pumpWidget(_host(GameSession(MemoryStorage()), levelDef(4)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2800));
    // taşma olsaydı framework exception fırlatırdı
    expect(tester.takeException(), isNull);
    expect(find.textContaining('BU BÖLÜM:'), findsOneWidget);
    expect(find.textContaining('SIRADA:'), findsOneWidget);
  });

  testWidgets('PB-030: tür kartı + sırada satırı görünür', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    final key = GlobalKey();
    final session = GameSession(MemoryStorage());
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: AudioController()),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Inter', useMaterial3: false),
          home: PreviewScreen(def: levelDef(0)),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2800)); // sinematik tamamlandı

    // kart içeriği: tür adı + ipucu + sırada ne var
    expect(find.textContaining('BU BÖLÜM: YILDIZ AVCISI'), findsOneWidget);
    expect(find.textContaining('SIRADA: HALKA'), findsOneWidget);

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    // toImage gerçek async ister — test sahte saatinde kilitlenmesin
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory(Platform.environment['PB_EVIDENCE'] == '1'
          ? '.project-brain/evidence/PB-030'
          : '.cache/runs/snapshots')
        ..createSync(recursive: true);
      File('${dir.path}/kind_card.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    final dir = Platform.environment['PB_EVIDENCE'] == '1'
        ? '.project-brain/evidence/PB-030'
        : '.cache/runs/snapshots';
    expect(File('$dir/kind_card.png').lengthSync(), greaterThan(2000));
  });
}
