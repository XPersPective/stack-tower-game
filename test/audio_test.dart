import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/services/storage.dart';

void main() {
  test('ses varlıkları üretildi: 21 dosya mevcut ve boş değil', () {
    const expected = [
      'place.wav',
      'perfect1.wav', 'perfect2.wav', 'perfect3.wav', 'perfect4.wav',
      'perfect5.wav', 'perfect6.wav', 'perfect7.wav', 'perfect8.wav',
      'win.wav', 'lose.wav', 'coin.wav', 'box.wav', 'shield.wav', 'start.wav',
      // PB-017
      'crit.wav', 'fanfare.wav', 'mystery.wav',
      'layer1.wav', 'layer2.wav', 'layer3.wav',
    ];
    for (final f in expected) {
      final file = hardCodedAsset(f);
      expect(file, isNotNull, reason: 'assets/sounds/$f eksik');
    }
  });

  test('mute toggle kalıcı: storage a yazılır ve yeniden yüklemede okunur', () {
    final storage = MemoryStorage();
    final a = AudioController(storage: storage);
    expect(a.muted, isFalse);
    a.setMuted(true);
    expect(storage.getString(kMuteKey), '1');

    final b = AudioController(storage: storage);
    expect(b.muted, isTrue); // kalıcılık
    b.setMuted(false);
    expect(storage.getString(kMuteKey), '0');
  });

  test('PB-017 kombo eşikleri: 3 → kick, 6 → +hat, 10 → üç katman', () {
    expect(activeLayersForCombo(0), isEmpty);
    expect(activeLayersForCombo(2), isEmpty);
    expect(activeLayersForCombo(3), [0]);
    expect(activeLayersForCombo(5), [0]);
    expect(activeLayersForCombo(6), [0, 1]);
    expect(activeLayersForCombo(9), [0, 1]);
    expect(activeLayersForCombo(10), [0, 1, 2]);
    expect(activeLayersForCombo(42), [0, 1, 2]);
  });

  test('PB-017 setCombo katmanları uygular; mute hepsini kapatır', () async {
    final a = AudioController(storage: MemoryStorage());
    await a.setCombo(6);
    expect(a.activeLayersForTest, [0, 1]);
    await a.setCombo(2); // kombo kırıldı → boş (fade-out yolu)
    expect(a.activeLayersForTest, isEmpty);
    await a.setCombo(12);
    expect(a.activeLayersForTest, [0, 1, 2]);
    a.setMuted(true);
    expect(a.activeLayersForTest, isEmpty, reason: 'mute katmanları kapatır');
  });

  test('PB-017 katman varlıkları loop uzunluğunda (8s @22.05kHz)', () {
    for (var i = 1; i <= 3; i++) {
      final f = File('assets/sounds/layer$i.wav');
      expect(f.existsSync(), isTrue);
      // 8.0s * 22050 * 2 byte + 44 header
      expect(f.lengthSync(), closeTo(44 + 8 * 22050 * 2, 2),
          reason: 'layer$i.wav 4 bar (120 BPM) loop olmalı');
    }
  });
}

/// Test ortamında asset bundle yok: dosya sisteminden varlığı doğrula.
String? hardCodedAsset(String name) {
  final f = 'assets/sounds/$name';
  final file = File(f);
  return file.existsSync() && file.lengthSync() > 44 ? f : null;
}
