/// PB-031 kanıt: premium katman görsel anlık görüntüleri + ayarlar erişilebilirlik
/// ve etkileşim akışları (giriş görünümü, çıkış, hesap silme başarı/başarısızlık).
/// Çıktı (PB_EVIDENCE=1): .project-brain/evidence/PB-031/{menu_premium,settings}.png
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
import 'package:stack_tower_game/main.dart';
import 'package:stack_tower_game/screens/shop_screens.dart';
import 'package:stack_tower_game/services/leaderboard_service.dart';
import 'package:stack_tower_game/services/session.dart';
import 'package:stack_tower_game/services/storage.dart';

/// Sahte ağ taşıyıcısı — SettingsScreen etkileşimlerini plugin'siz test eder.
class FakeTransport implements HttpTransport {
  HttpReply nextPost =
      const HttpReply(200, '{"sessionToken":"tok","displayName":"Oyuncu"}');
  HttpReply nextGet = const HttpReply(200, '{"rows":[]}');
  HttpReply nextDelete = const HttpReply(200, '{}');

  @override
  Future<HttpReply> post(String path, Map<String, dynamic> body,
          {String? token}) async =>
      nextPost;

  @override
  Future<HttpReply> get(String path, {String? token}) async => nextGet;

  @override
  Future<HttpReply> delete(String path, {String? token}) async => nextDelete;
}

Future<void> _loadInter() async {
  final file = File('assets/fonts/Inter.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader =
      FontLoader('Inter')..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Widget _appHost({SessionService? auth, LeaderboardService? lb}) =>
    StackTowerApp(
      session: GameSession(MemoryStorage()),
      audio: AudioController(),
      authSession: auth,
      leaderboard: lb,
    );

Widget _settingsHost(SessionService auth, LeaderboardService lb) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: GameSession(MemoryStorage())),
        ChangeNotifierProvider.value(value: AudioController()),
        Provider<SessionService>.value(value: auth),
        Provider<LeaderboardService>.value(value: lb),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );

Future<void> _savePng(GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await testerRunAsync(boundary, name);
}

/// toImage gerçek async ister — sahte test saatinde kilitlenmesin.
Future<void> testerRunAsync(RenderRepaintBoundary boundary, String name) async {
  await TestWidgetsFlutterBinding.ensureInitialized()
      .runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['PB_EVIDENCE'] == '1'
        ? '.project-brain/evidence/PB-031'
        : '.cache/runs/snapshots')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

String _outDir() => Platform.environment['PB_EVIDENCE'] == '1'
    ? '.project-brain/evidence/PB-031'
    : '.cache/runs/snapshots';

void main() {
  setUpAll(_loadInter);

  // [visual] premium menü: aurora zemin + nefes alan logo + cam istatistik şeridi.
  testWidgets('PB-031 görsel: menü premium görünümü taşmasız çizilir',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: _appHost()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2400)); // giriş animasyonları

    expect(find.text('STACK TOWER'), findsOneWidget);
    expect(find.text('G A M E'), findsOneWidget);
    expect(tester.takeException(), isNull); // taşma olmaz
    await _savePng(key, 'menu_premium');
    expect(File('${_outDir()}/menu_premium.png').lengthSync(),
        greaterThan(2000));
  });

  // [visual] + [accessibility] ayarlar: giriş butonları + platform kapısı.
  testWidgets(
      'PB-031 ayarlar: Google var, Apple yalnız iOS (C-011), Geri anlam etiketi',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final auth = SessionService(store: MemorySecureStore(), transport: FakeTransport());
    final lb = LeaderboardService(storage: MemoryStorage(), transport: FakeTransport());
    final key = GlobalKey();
    await tester
        .pumpWidget(RepaintBoundary(key: key, child: _settingsHost(auth, lb)));
    await tester.pump();

    expect(find.text('Google ile giriş'), findsOneWidget);
    // Platform kapısı: Windows/Android test ortamında Apple butonu YOK (MAJOR-3).
    expect(find.text('Apple ile giriş'), findsNothing);
    expect(find.bySemanticsLabel('Geri'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _savePng(key, 'settings');
    expect(File('${_outDir()}/settings.png').lengthSync(), greaterThan(2000));
  });

  // [interaction] çıkış: belirteç temizlenir, görünüm girişe döner.
  testWidgets('PB-031 etkileşim: ÇIKIŞ YAP oturumu kapatır', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final auth = SessionService(store: MemorySecureStore(), transport: FakeTransport());
    final lb = LeaderboardService(storage: MemoryStorage(), transport: FakeTransport());
    await auth.signIn('google', 'fake-id-token'); // sahte taşıyıcı → tok
    expect(auth.signedIn, isTrue);

    await tester.pumpWidget(_settingsHost(auth, lb));
    await tester.pump();
    expect(find.text('ÇIKIŞ YAP'), findsOneWidget);

    await tester.tap(find.text('ÇIKIŞ YAP'));
    await tester.pump();
    expect(auth.signedIn, isFalse);
    expect(find.text('Google ile giriş'), findsOneWidget);
  });

  // [interaction] hesap silme BAŞARISIZLIĞI: oturum korunur, hata gösterilir (MAJOR-2).
  testWidgets('PB-031 etkileşim: silme başarısızsa oturum korunur',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final transport = FakeTransport();
    final auth = SessionService(store: MemorySecureStore(), transport: transport);
    final lb = LeaderboardService(storage: MemoryStorage(), transport: transport);
    await auth.signIn('google', 'fake-id-token');
    transport.nextDelete = const HttpReply(500, '{}'); // sunucu hatası

    await tester.pumpWidget(_settingsHost(auth, lb));
    await tester.pump();
    await tester.tap(find.text('HESABI SİL'));
    await tester.pump();
    await tester.tap(find.text('Sil')); // onay diyaloğu
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(auth.signedIn, isTrue, reason: 'sunucu onayı yoksa oturum korunur');
    expect(
        find.textContaining('Hesap silinemedi'), findsOneWidget);
  });

  // [interaction] hesap silme BAŞARISI: sunucu onayı → yerel temizlik.
  testWidgets('PB-031 etkileşim: silme onaylanınca oturum kapanır',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final transport = FakeTransport();
    final auth = SessionService(store: MemorySecureStore(), transport: transport);
    final lb = LeaderboardService(storage: MemoryStorage(), transport: transport);
    await auth.signIn('google', 'fake-id-token');
    lb.enqueue('daily', 10, 42);

    await tester.pumpWidget(_settingsHost(auth, lb));
    await tester.pump();
    await tester.tap(find.text('HESABI SİL'));
    await tester.pump();
    await tester.tap(find.text('Sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(auth.signedIn, isFalse);
    expect(lb.queue, isEmpty, reason: 'hesap silinince kuyruk temizlenir');
    expect(find.text('Google ile giriş'), findsOneWidget);
  });
}
