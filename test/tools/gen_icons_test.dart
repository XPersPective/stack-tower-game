/// PB-014 — mağaza ikon seti üreteci (kaynak: reference/assets/icon-1024.png).
/// Mevcut hedef dosyaların PİKSEL boyutlarını koruyarak yeniden çizer
/// (Android mipmap-* + iOS AppIcon.appiconset). Ayrıca adaptive icon
/// foreground katmanını üretir.
///
/// Kullanım: `PB_ICONS=1 flutter test test/tools/gen_icons_test.dart`
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String kSource = 'reference/assets/icon-1024.png';
const String kAndroidRes = 'android/app/src/main/res';
const String kIosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

Future<ui.Image> _decode(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<ui.Image> _resize(ui.Image src, int w, int h, {double inset = 0}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final dst = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  if (inset > 0) {
    // adaptive icon: içerik %66 güvenli alanda ortalanır, kenar saydam
    final side = w * (1 - inset);
    final r = Rect.fromCenter(
        center: dst.center, width: side, height: h * (1 - inset));
    canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        r,
        Paint()..filterQuality = FilterQuality.high);
  } else {
    canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.high);
  }
  final pic = recorder.endRecording();
  return pic.toImage(w, h);
}

Future<List<int>> _png(ui.Image img) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  final enabled = Platform.environment['PB_ICONS'] == '1';

  test('ikon seti üretilir (PB_ICONS=1)', () async {
    if (!enabled) return;
    final src = await _decode(File(kSource).readAsBytesSync());
    var count = 0;

    // Android mipmap'leri: mevcut dosyanın boyutunu koru
    for (final dir in Directory(kAndroidRes).listSync().whereType<Directory>()) {
      if (!dir.path.contains('mipmap')) continue;
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('ic_launcher.png')) continue;
        final old = await _decode(f.readAsBytesSync());
        final w = old.width, h = old.height;
        old.dispose();
        final img = await _resize(src, w, h);
        f.writeAsBytesSync(await _png(img));
        img.dispose();
        count++;
      }
    }

    // iOS appiconset: mevcut her dosyanın boyutunu koru
    final iosDir = Directory(kIosIcons);
    if (iosDir.existsSync()) {
      for (final f in iosDir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.png')) continue;
        final old = await _decode(f.readAsBytesSync());
        final w = old.width, h = old.height;
        old.dispose();
        final img = await _resize(src, w, h);
        f.writeAsBytesSync(await _png(img));
        img.dispose();
        count++;
      }
    }

    // Adaptive icon foreground katmanları (108dp @ yoğunluklar)
    const fgSizes = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
    for (final e in fgSizes.entries) {
      final dir = Directory('$kAndroidRes/mipmap-${e.key}')..createSync(recursive: true);
      final img = await _resize(src, e.value, e.value, inset: 0.34);
      File('${dir.path}/ic_launcher_foreground.png')
          .writeAsBytesSync(await _png(img));
      img.dispose();
      count++;
    }

    // Adaptive icon tanımı + arka plan rengi
    final anydpi = Directory('$kAndroidRes/mipmap-anydpi-v26')..createSync(recursive: true);
    File('${anydpi.path}/ic_launcher.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''');
    final values = Directory('$kAndroidRes/values')..createSync(recursive: true);
    File('${values.path}/ic_launcher_background.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0A0A1E</color>
  </resources>
''');
    count += 2;

    expect(count, greaterThan(20), reason: 'ikon dosyaları üretilmeli');
    // ignore: avoid_print
    print('PB-014: $count ikon dosyası üretildi');
  });
}
