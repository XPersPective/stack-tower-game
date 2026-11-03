/// PB-041 — RENK KAPI motor testleri: çözülebilirlik yasası, zıplama fiziği,
/// kapı geçişi, renk perdesi, yanlış-renk çarpışması, kalkan, kazanma.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/color_gate_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';

/// Test mantık genişliği (resize(400, 800) ile eşli).
const double kW = 400;

/// Ses/olayları kaydeden test sahtesi.
class _FakeHost implements MiniGameHost {
  final List<String> sounds = [];
  final List<String> events = [];
  int haptics = 0;
  @override
  void playSound(String name, {int combo = 1}) => sounds.add(name);
  @override
  void haptic(int ms) => haptics++;
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) => events.add(name);
}

(ColorGateGame, _FakeHost) _game() {
  final host = _FakeHost();
  final g = ColorGateGame();
  g.resize(kW, 800);
  g.start(levelDef(0), host: host); // hedef 8
  // salınımı nötrle: pencere baseX'te sabit (deterministik test)
  for (final gate in g.gates) {
    gate.amp = 0;
  }
  return (g, host);
}

void main() {
  test('tür kimliği: colorGate', () {
    expect(ColorGateGame().kind, GameKind.colorGate);
  });

  test('kurulum: hedef kadar kapı, kapı-1 perde, çözülebilirlik zinciri', () {
    final (g, host) = _game();
    final target = levelDef(0).target;
    expect(g.gates.length, target);
    expect(g.bands.length, target - 1);
    // yasa: kapı 0 penceresi = topun varış hue'su (200)
    expect(g.gates.first.winHue, 200);
    // kapı k (k≥1) pencere rengi = önceki perdenin yeni rengi
    for (var k = 1; k < g.gates.length; k++) {
      expect(g.gates[k].winHue, g.bands[k - 1].newHue,
          reason: 'kapı $k perde ${k - 1} ile çözülebilir olmalı');
      expect(g.bands[k - 1].newHue, isNot(g.gates[k - 1].winHue),
          reason: 'perde rengi DEĞİŞMELİ (aynı hue perde anlamsız)');
    }
    // pencere ekran içinde: baseX ∈ [w*0.18, w*0.82 - winW]
    for (final gate in g.gates) {
      expect(
          gate.baseX, inInclusiveRange(kW * 0.18, kW * 0.82 - gate.winW + .01));
    }
  });

  test('zıplama: dokun → vy negatif; yerçekimi düşürür; zemin sekmesi güvenli',
      () {
    final (g, host) = _game();
    g.onTap(const Offset(200, 400));
    expect(g.vy, lessThan(0));
    final v0 = g.vy;
    for (var i = 0; i < 30; i++) {
      g.tick(1 / 60);
    }
    expect(g.vy, greaterThan(v0));
    // top ekrandan aşağı düşmez (zemin seker)
    expect(g.ballY, lessThanOrEqualTo(800 - 11 + 0.5));
    expect(g.isOver, isFalse, reason: 'zemin ölüm değildir');
  });

  test('kapı geçişi: pencere hizalı → geçiş skoru', () {
    final (g, host) = _game();
    final gate = g.gates.first;
    gate.baseX = kW / 2 - gate.winW / 2; // pencereyi topa hizala
    g.scroll = gate.y - 400; // kapı ekran ortasında
    g.ballY = 460; // kapının altında
    for (var i = 0; i < 120 && !g.gates.first.passed; i++) {
      g.onTap(const Offset(200, 400)); // sürekli zıpla (havlama)
      g.tick(1 / 60);
    }
    expect(g.gates.first.passed, isTrue);
    expect(g.score, 1);
    expect(g.combo, 1);
  });

  test('yanlış renk: pencere dışında bant kesişimi → kalkan → ölüm', () {
    final (g, host) = _game();
    final gate = g.gates.first;
    gate.baseX = 0; // pencere solda; top x = w/2 → duvar üstünde
    g.scroll = gate.y - 400;
    g.ballY = 410; // çizginin ALTında, bantta (tek tikte aşmasın)
    g.vy = -300; // yukarı doğru duvara
    g.tick(1 / 60);
    expect(g.shieldsLeft, 0, reason: 'kalkan tüketildi');
    expect(g.isOver, isFalse, reason: 'kalkan sekmesi ölüm değil');
    expect(g.score, 0, reason: 'çarpışan top geçemedi');
    // kalkansız ikinci vuruş → ölüm
    g.ballY = 410;
    g.vy = -300;
    g.tick(1 / 60);
    expect(g.isOver, isTrue);
    expect(g.result().reached, isFalse);
    expect(host.events, contains('lose'));
  });

  test('pencere içi bant kesişimi güvenli ve geçiş sayılır', () {
    final (g, _) = _game();
    final gate = g.gates.first;
    gate.baseX = kW / 2 - gate.winW / 2;
    g.scroll = gate.y - 400;
    g.ballY = 404; // çizginin altında, pencere hizalı
    g.vy = -300;
    g.tick(1 / 60); // banta girer — güvenli
    expect(g.isOver, isFalse);
    expect(g.shieldsLeft, 1);
    g.tick(1 / 60); // çizgiyi yukarı yönlü geçer
    expect(g.score, 1, reason: 'pencereden geçiş sayıldı');
  });

  test('renk perdesi: banttan geçen top boyanır', () {
    final (g, host) = _game();
    final band = g.bands.first;
    expect(band.newHue, isNot(g.ballHue));
    g.scroll = band.y - 400;
    g.ballY = 400;
    g.vy = -300;
    g.tick(1 / 60);
    expect(g.ballHue, band.newHue);
    expect(band.used, isTrue);
  });

  test('zemin kombo kırar: combo sıfırlanır, oyun sürer', () {
    final (g, host) = _game();
    g.onTap(const Offset(200, 400));
    for (var i = 0; i < 180; i++) {
      g.tick(1 / 60);
    }
    expect(g.combo, 0);
    expect(g.isOver, isFalse);
  });

  test('kazanma: tüm kapılar → isOver + reached + puan', () {
    final (g, host) = _game();
    for (final gate in g.gates) {
      gate.baseX = kW / 2 - gate.winW / 2; // hepsi hizalı
    }
    var guard = 0;
    while (!g.isOver && guard < 20000) {
      guard++;
      g.onTap(const Offset(200, 400));
      g.tick(1 / 60);
    }
    expect(g.isOver, isTrue);
    expect(g.score, g.target);
    final r = g.result();
    expect(r.reached, isTrue);
    expect(r.points, g.target);
    expect(host.events, contains('win'));
  });

  test('dağıtım: kindFor colorGate üretir, ardışık tekrar yok', () {
    var seen = false;
    for (var i = 5; i < 150; i++) {
      if (kindFor(i) == GameKind.colorGate) seen = true;
      expect(kindFor(i), isNot(kindFor(i - 1)), reason: 'i=$i ardışık tekrar');
    }
    expect(seen, isTrue, reason: 'colorGate döngüde yer almalı');
  });
}
