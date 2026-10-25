import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/audio.dart';
import 'package:stack_tower_game/services/storage.dart';

void main() {
  test('ses varlıkları üretildi: 15 dosya mevcut ve boş değil', () {
    const expected = [
      'place.wav',
      'perfect1.wav', 'perfect2.wav', 'perfect3.wav', 'perfect4.wav',
      'perfect5.wav', 'perfect6.wav', 'perfect7.wav', 'perfect8.wav',
      'win.wav', 'lose.wav', 'coin.wav', 'box.wav', 'shield.wav', 'start.wav',
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
}

/// Test ortamında asset bundle yok: dosya sisteminden varlığı doğrula.
String? hardCodedAsset(String name) {
  final f = 'assets/sounds/$name';
  final file = File(f);
  return file.existsSync() && file.lengthSync() > 44 ? f : null;
}
