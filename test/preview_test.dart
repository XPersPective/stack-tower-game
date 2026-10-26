import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/game/game_session.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/scene_painter.dart';
import 'package:stack_tower_game/preview/preview_painter.dart';
import 'package:stack_tower_game/screens/map_screen.dart';
import 'package:stack_tower_game/screens/play_screen.dart';
import 'package:stack_tower_game/screens/preview_screen.dart';
import 'package:stack_tower_game/screens/router.dart';
import 'package:stack_tower_game/services/storage.dart';
import 'package:stack_tower_game/theme/tokens.dart';

Widget host(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: GameSession(MemoryStorage())),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: MaterialApp(home: child),
    );

// adlandırılmış rotalarla host — BAŞLA (→ /play) ve pop akışları için
Widget routedHost(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: GameSession(MemoryStorage())),
        ChangeNotifierProvider.value(value: AudioController()),
      ],
      child: MaterialApp(
        home: home,
        onGenerateRoute: (s) =>
            MaterialPageRoute(builder: (_) => routeFor(s), settings: s),
      ),
    );

void main() {
  // preview.js draw() portu: her silüet/hava türü (10 tema) iki anda çizilmeli.
  test('preview painter: 10 tema × t=0/5.3 hata vermeden çizer', () {
    for (var stage = 0; stage < kThemes.length; stage++) {
      final def = levelDef(stage * kLevelsPerStage);
      for (final t in [0.0, 5.3]) {
        final scene = PreviewScene(
          theme: def.theme,
          levelI: def.i,
          stage: def.stage,
          daily: def.daily == true,
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        PreviewPainter(scene: scene, t: t)
            .paint(canvas, const Size(360, 640));
        recorder.endRecording().dispose();
        // parçacık sayıları JS buildParticles ile aynı (preview.js:109-127)
        final weather = def.theme.weather;
        expect(scene.particleCount, weather == 'stars' ? 46 : 54);
        expect(scene.starCount, 80);
      }
    }
  });

  // günlük varyant — farklı tohum yolunda da çizilebilmeli
  test('preview painter: günlük varyant çizilir', () {
    final scene =
        PreviewScene(theme: kThemes[0], levelI: 42, stage: 0, daily: true);
    final recorder = ui.PictureRecorder();
    PreviewPainter(scene: scene, t: 2.1).paint(Canvas(recorder), const Size(360, 640));
    recorder.endRecording().dispose();
    expect(scene.particleCount, kThemes[0].weather == 'stars' ? 46 : 54);
  });

  testWidgets('bölüm kartı verisi doğru (isim/tür/hedef/ödül/yıldız)', (tester) async {
    final def = levelDef(0);
    final mod = kModifiers[def.modifier]!;
    await tester.pumpWidget(host(PreviewScreen(def: def)));
    await tester.pump();

    expect(find.text('DÜNYA 1 · ${def.theme.name}'), findsOneWidget);
    expect(find.text('BÖLÜM ${def.num}'), findsOneWidget);
    expect(find.text('0/$kLevelsPerStage'), findsOneWidget);
    expect(find.text('${mod.icon} ${mod.name}'), findsOneWidget);
    expect(find.text(mod.hint), findsOneWidget);
    expect(
        find.text('${def.target} blok · ${def.coins} 🪙${def.box ? ' + 🎁' : ''}'),
        findsOneWidget);
    expect(find.text('★'), findsNWidgets(3)); // önceki yıldız yok → hepsi sönük
  });

  testWidgets('günlük bölümde kart günlük metinleri taşır', (tester) async {
    final def = dailyDef(progDayForTest);
    await tester.pumpWidget(host(PreviewScreen(def: def)));
    await tester.pump();

    expect(find.text('GÜNLÜK MEYDAN OKUMA'), findsOneWidget);
    expect(find.text('BUGÜN HERKES İÇİN AYNI'), findsOneWidget);
    // ui.js openIntro(181): günlükte ilerleme slotu 'GÜNLÜK' metnini taşır
    expect(find.text('GÜNLÜK'), findsOneWidget);
    expect(find.text('Bugünün bölümü herkes için aynı. Tahtada yerini al.'),
        findsOneWidget);
    // ui.js openIntro(181,193): teaser slotunda günlük cümlesi, gizem slotunda
    // mysteryFor(-2) gösterilir; dünya teaser'ı günlükte görünmez
    expect(find.text(mysteryFor(def.i)), findsOneWidget);
    expect(find.text(kWorldTeaser[def.stage]), findsNothing);
  });

  // ui.js openIntro(211-218) introLock: kilit nedeni karta yazılır
  testWidgets('kilitli bölümde kilit nedeni gösterilir', (tester) async {
    final def = levelDef(1); // bölüm 1 tamamlanmadı → kilitli, stage 0
    await tester.pumpWidget(host(PreviewScreen(def: def)));
    await tester.pump();

    expect(find.text("ÖNCE BÖLÜM ${def.num - 1}'İ BİTİR"), findsOneWidget);
    expect(find.text('🔒 KİLİTLİ'), findsOneWidget);
    expect(find.text('BAŞLA ▶'), findsNothing);
  });

  testWidgets('tap sinematiği hızlandırır, BAŞLA görünür kalır', (tester) async {
    final def = levelDef(0);
    await tester.pumpWidget(host(PreviewScreen(def: def)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // sinematik ortası
    // BAŞLA fade'i Interval(0.6, 0.9) → t≈0.23'te henüz sıfır opaklıkta
    final startFade =
        tester.widget<FadeTransition>(find.byType(FadeTransition).last);
    expect(startFade.opacity.value, lessThan(0.05));
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // tap denetleyiciyi %99'a atlattı → fade tamamlanmış olmalı
    final afterTap =
        tester.widget<FadeTransition>(find.byType(FadeTransition).last);
    expect(afterTap.opacity.value, greaterThan(0.99));
    expect(find.text('BAŞLA ▶'), findsOneWidget);
  });

  testWidgets('BAŞLA play ekranına götürür (pushReplacement)', (tester) async {
    final def = levelDef(0);
    await tester.pumpWidget(routedHost(PreviewScreen(def: def)));
    await tester.pump();
    await tester.tap(find.text('BAŞLA ▶'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // değiştirilen rotanın çıkış animasyonu + imhası ~600ms sonra tamamlanır
    await tester.pump(const Duration(milliseconds: 350));
    // surprise toast'unun 2.2s kapanma zamanlayıcısını tüket (pending timer invariant'ı)
    await tester.pump(const Duration(milliseconds: 2300));
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(find.byType(PreviewScreen), findsNothing);
  });

  testWidgets('geri düğmesi haritaya döner', (tester) async {
    final def = levelDef(0);
    await tester.pumpWidget(routedHost(const MapScreen()));
    await tester.pump();
    Navigator.of(tester.element(find.byType(MapScreen)))
        .pushNamed(Routes.preview, arguments: def);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(PreviewScreen), findsOneWidget);
    // MapScreen'de de ok ikonu var → yalnız önizlemedekini hedefle
    await tester.tap(find.descendant(
        of: find.byType(PreviewScreen),
        matching: find.byIcon(Icons.arrow_back)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // pop çıkış animasyonu + imhası için ek kare (BAŞLA testiyle aynı neden)
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(PreviewScreen), findsNothing);
  });

  // [accessibility] kart metinleri: kart zemini (0xCC0a0a1e) tema gradyanı
  // üstüne biner — 10 tema × bg1/bg2 üzerinde WCAG kontrast ölçümü.
  test('önizleme kartı metin kontrastı WCAG AA (10 tema)', () {
    const cardBg = Color(0xCC0a0a1e);
    for (final theme in kThemes) {
      for (final base in [theme.bg1, theme.bg2]) {
        final bg = Color.alphaBlend(cardBg, base);
        expect(_contrast(NeonPalette.text, bg), greaterThan(4.5),
            reason: '${theme.id} bg=${base.toARGB32()} text');
        expect(_contrast(NeonPalette.textDim, bg), greaterThan(4.5),
            reason: '${theme.id} bg=${base.toARGB32()} textDim');
        // mod adı vurgusu: titleLarge (18px w700) → büyük metin eşiği 3.0
        expect(_contrast(hslColor(theme.glow, 95, 70), bg), greaterThan(3.0),
            reason: '${theme.id} bg=${base.toARGB32()} mod vurgusu');
      }
    }
  });

  // sinematik dünya başlığı: glow rengi (l=70) doğrudan tema gradyanı üstünde
  test('sinematik başlık kontrastı (10 tema, gradyan üstünde)', () {
    for (final theme in kThemes) {
      for (final base in [theme.bg1, theme.bg2]) {
        expect(_contrast(hslColor(theme.glow, 90, 70), base), greaterThan(3.0),
            reason: '${theme.id} bg=${base.toARGB32()} dünya başlığı');
      }
    }
  });
}

double _channel(double c) {
  final v = c > 1.0 ? c / 255.0 : c; // Color kanalları bu sürümde 0..1
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final l1 = _luminance(a), l2 = _luminance(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

// Günlük tanım günü — deterministik sabit (levels.js dailyDef(day) tohumu).
const int progDayForTest = 19000;
