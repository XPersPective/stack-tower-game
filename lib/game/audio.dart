/// Stack Tower Game — ses servisi (ADR-003).
/// Orijinal WebAudio ton setinin üretilmiş WAV karşılıkları assets/sounds/ altında.
/// Dosya yoksa sessizce yok sayar (oyun asla kırılmaz).
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/storage.dart';

enum GameSound {
  place,
  perfect,
  win,
  lose,
  coin,
  box,
  shield,
  start,
  crit,
  fanfare,
  mystery,
  // PB-032: arayüz sesleri
  tap,
  whoosh,
  reward,
  unlock,
  error,
  pop,
  // PB-035 A6/D8: tür imza sesleri
  mergePop,
  sortFlow,
}

/// PB-017: kombo eşiklerine göre aktif ritim katmanları (0..2).
/// 3+ → kick, 6+ → kick+hat, 10+ → üçü birden; kombo kırılınca boş (fade-out).
List<int> activeLayersForCombo(int combo) {
  if (combo >= 10) return const [0, 1, 2];
  if (combo >= 6) return const [0, 1];
  if (combo >= 3) return const [0];
  return const [];
}

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
  // PB-017: döngüsel ritim katmanları (0..2)
  final List<AudioPlayer> _layers = [];
  bool _layersReady = false;
  List<int> _activeLayers = const [];
  List<int> get activeLayersForTest => _activeLayers;

  // PB-033/034: arka plan müzik döngüsü (music_loop.wav — dikişsiz 8 bar)
  AudioPlayer? _music;
  bool _musicWanted = false;
  static const double kMusicVolume = 0.38;

  /// Arka plan müziğini başlat (idempotent). Sessiz modda istek hatırlanır,
  /// ses açılınca kaldığı yerden devam eder.
  Future<void> ensureMusic() async {
    _musicWanted = true;
    if (_muted) return;
    final m = _music;
    if (m != null) {
      try {
        await m.resume();
      } catch (_) {}
      return;
    }
    final p = AudioPlayer();
    try {
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setSource(AssetSource('sounds/music_loop.wav'));
      await p.setVolume(0);
      await p.resume();
      await p.setVolume(kMusicVolume);
      _music = p;
    } catch (_) {
      // eksik varlık: sessizce yoksay (oyun asla kırılmaz)
    }
  }

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
      GameSound.crit: 'crit.wav',
      GameSound.fanfare: 'fanfare.wav',
      GameSound.mystery: 'mystery.wav',
      // PB-032: arayüz sesleri
      GameSound.tap: 'tap.wav',
      GameSound.whoosh: 'whoosh.wav',
      GameSound.reward: 'reward.wav',
      GameSound.unlock: 'unlock.wav',
      GameSound.error: 'error.wav',
      GameSound.pop: 'pop.wav',
      GameSound.mergePop: 'merge_pop.wav',
      GameSound.sortFlow: 'sort_flow.wav',
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
    await _preloadLayers();
  }

  /// PB-017: katmanlar döngüde çalar; ses seviyesi kombo ile açılır.
  Future<void> _preloadLayers() async {
    if (_layersReady) return;
    _layersReady = true;
    for (var i = 0; i < 3; i++) {
      final p = AudioPlayer();
      try {
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setSource(AssetSource('sounds/layer${i + 1}.wav'));
        await p.setVolume(0);
      } catch (_) {
        // eksik varlık güvenli: sessiz katman
      }
      _layers.add(p);
    }
  }

  /// Kombo değiştiğinde katmanları açar/kapatır (fade-out 220ms).
  Future<void> setCombo(int combo) async {
    final want = _muted ? const <int>[] : activeLayersForCombo(combo);
    if (_sameLayers(want, _activeLayers)) return;
    _activeLayers = want;
    for (var i = 0; i < _layers.length; i++) {
      final p = _layers[i];
      final on = want.contains(i);
      try {
        if (on) {
          await p.setVolume(0.55);
          await p.resume();
        } else {
          await _fadeOut(p);
        }
      } catch (_) {}
    }
  }

  Future<void> _fadeOut(AudioPlayer p) async {
    for (var step = 9; step >= 0; step--) {
      try {
        await p.setVolume(0.55 * step / 10);
      } catch (_) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 22));
    }
    try {
      await p.pause();
      await p.setVolume(0);
    } catch (_) {}
  }

  bool _sameLayers(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// PB-035 D8: dünya jingle'ı — önizleme ekranında dünyanın 3'lü arpeji.
  /// [stage] 0..9 → jingle1..10.wav. Dosya yoksa sessizce yoksayılır.
  Future<void> playWorldJingle(int stage) async {
    if (_muted || !_ready) return;
    try {
      final p = AudioPlayer();
      await p.setSource(AssetSource('sounds/jingle${(stage + 1).clamp(1, 10)}.wav'));
      await p.setReleaseMode(ReleaseMode.stop);
      await p.resume();
      _jinglePlayers.add(p);
      // 4 sn sonra temizle (kısa arpej; player havuzu sızmasın)
      Future<void>.delayed(const Duration(seconds: 4), () {
        _jinglePlayers.remove(p);
        p.dispose();
      });
    } catch (_) {}
  }

  final List<AudioPlayer> _jinglePlayers = [];

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
        GameSound.crit => 'crit.wav',
        GameSound.fanfare => 'fanfare.wav',
        GameSound.mystery => 'mystery.wav',
        // PB-032: arayüz sesleri
        GameSound.tap => 'tap.wav',
        GameSound.whoosh => 'whoosh.wav',
        GameSound.reward => 'reward.wav',
        GameSound.unlock => 'unlock.wav',
        GameSound.error => 'error.wav',
        GameSound.pop => 'pop.wav',
        GameSound.mergePop => 'merge_pop.wav',
        GameSound.sortFlow => 'sort_flow.wav',
      };

  void setMuted(bool m) {
    _muted = m;
    storage?.setString(kMuteKey, m ? '1' : '0');
    if (m) {
      setCombo(0); // sustur: katmanlar sönsün
      try {
        _music?.pause();
      } catch (_) {}
    } else if (_musicWanted) {
      ensureMusic(); // ses açıldı: müzik kaldığı yerden devam
    }
    notifyListeners();
  }

  void toggleMute() => setMuted(!muted);

  @override
  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    for (final p in _layers) {
      p.dispose();
    }
    try {
      _music?.dispose();
    } catch (_) {}
    for (final p in _jinglePlayers) {
      p.dispose();
    }
    super.dispose();
  }
}
