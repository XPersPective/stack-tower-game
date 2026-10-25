/// Stack Tower Game — ses servisi (ADR-003).
/// Orijinal WebAudio ton setinin üretilmiş WAV karşılıkları assets/sounds/ altında.
/// Dosya yoksa sessizce yok sayar (oyun asla kırılmaz).
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/storage.dart';

enum GameSound { place, perfect, win, lose, coin, box, shield, start }

const String kMuteKey = 'stacktower_muted_v1';

class AudioController extends ChangeNotifier {
  AudioController({bool muted = false, this.storage}) {
    // kalıcı sessiz ayarı (game.js neonkule_muted_v1 karşılığı)
    if (storage?.getString(kMuteKey) == '1') _muted = true;
  }

  final KeyValueStorage? storage;
  bool _muted = false;
  bool get muted => _muted;
  bool _ready = false;

  final Map<GameSound, AudioPlayer> _players = {};

  Future<void> preload() async {
    if (_ready) return;
    _ready = true;
    const names = {
      GameSound.place: 'place.wav',
      GameSound.perfect: 'perfect1.wav',
      GameSound.win: 'win.wav',
      GameSound.lose: 'lose.wav',
      GameSound.coin: 'coin.wav',
      GameSound.box: 'box.wav',
      GameSound.shield: 'shield.wav',
      GameSound.start: 'start.wav',
    };
    for (final e in names.entries) {
      final p = AudioPlayer();
      try {
        await p.setSource(AssetSource('sounds/${e.value}'));
        await p.setReleaseMode(ReleaseMode.stop);
        _players[e.key] = p;
      } catch (_) {
        // Varlık yoksa sessiz mod (çevrimdışı/eksik varlık güvenliği)
      }
    }
  }

  /// Mükemmel serisi yükselen perde: combo 1..8 → perfectN.wav (tavana düşer).
  Future<void> play(GameSound sound, {int combo = 1}) async {
    if (_muted || !_ready) return;
    final name = switch (sound) {
      GameSound.perfect => 'perfect${combo.clamp(1, 8)}.wav',
      _ => _fileOf(sound),
    };
    final p = _players[sound];
    if (p == null) return;
    try {
      await p.stop();
      await p.setSource(AssetSource('sounds/$name'));
      await p.resume();
    } catch (_) {}
  }

  String _fileOf(GameSound s) => switch (s) {
        GameSound.place => 'place.wav',
        GameSound.perfect => 'perfect1.wav',
        GameSound.win => 'win.wav',
        GameSound.lose => 'lose.wav',
        GameSound.coin => 'coin.wav',
        GameSound.box => 'box.wav',
        GameSound.shield => 'shield.wav',
        GameSound.start => 'start.wav',
      };

  void setMuted(bool m) {
    _muted = m;
    storage?.setString(kMuteKey, m ? '1' : '0');
    notifyListeners();
  }

  void toggleMute() => setMuted(!muted);

  @override
  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }
}
