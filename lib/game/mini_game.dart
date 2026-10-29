/// Stack Tower Game — Antoloji motoru sözleşmesi (ADR-008, DESIGN-V2 §4).
/// Tüm oyun türleri bu arayüzü uygular; play_screen tür-agnostik host'tur.
library;

import 'package:flutter/material.dart';

import 'levels.dart';

/// Ortak sonuç yükü (GameSession.onWin/onLose ekonomisi değişmez).
class MiniGameResult {
  final int points; // bölüme göre: blok/yıldız/isabet
  final int perfects;
  final bool reached;
  final int crits;
  final int goldBlocks;
  const MiniGameResult({
    required this.points,
    required this.perfects,
    required this.reached,
    this.crits = 0,
    this.goldBlocks = 0,
  });
}

/// Host kancaları: ses + haptic + olay bildirimi.
abstract class MiniGameHost {
  void playSound(String name, {int combo});
  void haptic(int ms);
  void onEvent(String name, {Map<String, dynamic>? data});
}

/// juice (PB-016): opsiyonel çoklu vuruş deseni yeteneği.
/// Liste, vuruşların BAŞLANGIÇ anlarıdır (ms): `[0, 60]` = hemen bir vuruş,
/// 60ms sonra ikinci vuruş. Ayrı arayüz: mevcut host'lar (test sahteleri dahil)
/// kırılmaz; uygulamayan host'a motor tek vuruş yedeği gönderir.
abstract class HapticPatternHost {
  void hapticPattern(List<int> onsetsMs);
}

/// Tüm türlerin uyguladığı sözleşme.
abstract class MiniGame {
  GameKind get kind;

  /// HUD için anlık değerler.
  int get score;
  int get target;
  int get combo;
  int get shieldsLeft;
  bool get isOver;

  /// [hue] yalnızca kullanan türler içindir (STACK skin); diğerleri yok sayar.
  void resize(double w, double h);
  void start(LevelDef def, {required MiniGameHost host, int shields = 1, int hue = 200});
  void tick(double dt);
  void onTap(Offset local);
  void render(Canvas canvas, Size size);
  MiniGameResult result();

  /// Bölüm bittiğinde/çıkışta temizlik (motoru durdur). Varsayılan: işlem yok.
  void stop() {}
}

/// juice (PB-016): opsiyonel giriş kapısı. Uygulayan tür, kısa bir sunum
/// penceresinde (ör. STACK hit-stop ≤70ms) dokunuşu yok sayabilir; bu sırada
/// yeni blok kenarda donmuş görünür ve dokunuş garantili ıskalama olurdu.
/// Ayrı arayüz: mevcut türler ve test sahteleri değişmez.
abstract class InputGate {
  bool get acceptsInput;
}

/// PB-025: basılı tutma girdisi (LAUNCH: basılı tut = şarj, bırak = fırlat).
/// Uygulamayan türler tek dokunuşla oynanır; host yalnız bu arayüzü uygulayan
/// türlerde bas/bırak olaylarını yönlendirir.
abstract class HoldGame {
  void onHoldStart(Offset local);
  void onRelease(Offset local);

  /// Dokunuş iptal edildi (kaydırma/geri tuşu): atış yapılmaz, şarj sıfırlanır.
  void onHoldCancel();
}

/// Basit host uygulaması (test + üretim).
class SimpleMiniGameHost implements MiniGameHost, HapticPatternHost {
  SimpleMiniGameHost({this.onSound, this.onHaptic, this.onHapticPattern, this.onGameEvent});
  final void Function(String, int)? onSound;
  final void Function(int)? onHaptic;
  final void Function(List<int>)? onHapticPattern;
  final void Function(String, Map<String, dynamic>?)? onGameEvent;

  @override
  void playSound(String name, {int combo = 1}) => onSound?.call(name, combo);
  @override
  void haptic(int ms) => onHaptic?.call(ms);
  @override
  void hapticPattern(List<int> onsetsMs) {
    final cb = onHapticPattern;
    if (cb != null) {
      cb(onsetsMs);
    } else {
      onHaptic?.call(50); // desen yoksa kritik tek uzun vuruş yedeği
    }
  }
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) => onGameEvent?.call(name, data);
}
