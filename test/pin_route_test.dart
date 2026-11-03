/// PB-042 — PİN SIRRI motor testleri: pim çekme, kavşak yönlendirme,
/// huni/çukur skorları, karanlık tehlikesi, kalkan, kazanma/kayıp.
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/pin_route_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';

class _FakeHost implements MiniGameHost {
  final List<String> sounds = [];
  final List<String> events = [];
  @override
  void playSound(String name, {int combo = 1}) => sounds.add(name);
  @override
  void haptic(int ms) {}
  @override
  void onEvent(String name, {Map<String, dynamic>? data}) => events.add(name);
}

const double kW = 400, kH = 800;

typedef PinBundle = (PinRouteGame, _FakeHost);

PinBundle makeGame() {
  final host = _FakeHost();
  final g = PinRouteGame();
  g.resize(kW, kH);
  g.start(levelDef(0), host: host); // hedef 8
  return (g, host);
}

/// Kavşağın açık yönünü ayarla (test determinizmi).
void setLeft(PinRouteGame g, int index, bool left) {
  g.j2s[index].openLeft = left;
}

/// İlk altın cebe sahip pimi çek ve topu huniye ulaştır.
void pullAndRouteToFunnel(PinRouteGame g) {
  final pin = g.pins.firstWhere((p) => !p.used && p.queue.contains(false));
  pin.used = true;
  g.pendingForTest.addAll(pin.queue.where((d) => !d).map((_) => false));
  // topu anında huniye ulaştır (yol fiziğini atla)
  final b = Ball(false, pin.pos);
  b.path.addAll([pin.pos, g.j2s[0].pos, g.j2s[0].pos, g.funnel]);
  b.progress = 2.999;
  g.balls.add(b);
  g.tick(1 / 60);
}

void main() {
  test('tür kimliği: pinRoute', () {
    expect(PinRouteGame().kind, GameKind.pinRoute);
  });

  test('kurulum: 4 cep, altın sayısı hedefi karşılar, 2 kavşak J2', () {
    final (g, _) = makeGame();
    expect(g.pins.length, 4);
    expect(g.j2s.length, 2);
    final gold = g.pins.fold<int>(0, (s, p) => s + p.goldCount);
    expect(gold, greaterThanOrEqualTo(g.target),
        reason: 'çözülebilirlik yasası: altın ≥ hedef');
    // her J2'nin huni çıkışı bir tarafta olmalı (ayna düzeni)
    expect(g.j2s[0].openLeft, isNot(g.j2s[1].openLeft),
        reason: 'aynalı J2: iki kavşak da huniye açılabilir olmalı');
  });

  test('kavşak çevirme: dokunuş yön değiştirir', () {
    final (g, host) = makeGame();
    final j = g.j1s.first;
    final before = j.openLeft;
    g.onTap(j.pos + const Offset(2, 2));
    expect(j.openLeft, isNot(before));
    expect(host.sounds, contains('pop'));
  });

  test('pim çekme → kuyruk; bırakma zamanlayıcı top üretir', () {
    final (g, _) = makeGame();
    final pin = g.pins.first;
    final n = pin.queue.length;
    g.onTap(pin.pos + const Offset(2, 2));
    expect(pin.used, isTrue);
    expect(g.pendingForTest.length, n);
    for (var i = 0; i < n; i++) {
      g.tick(0.6); // her 0.55 s'de bir top
    }
    expect(g.balls.isNotEmpty || g.pendingForTest.isEmpty, isTrue);
  });

  test('altın huniye → skor +2, huniGold artar', () {
    final (g, host) = makeGame();
    final gold0 = g.funnelGold;
    pullAndRouteToFunnel(g);
    expect(g.funnelGold, greaterThan(gold0));
    expect(g.score, greaterThan(0));
    expect(host.sounds, contains('coin'));
  });

  test('karanlık çukura → güvenli skor', () {
    final (g, host) = makeGame();
    final b = Ball(true, g.pins.first.pos);
    b.path.addAll([g.pins.first.pos, g.j2s[1].pos, g.j2s[1].pos, g.pit]);
    b.progress = 2.999;
    g.balls.add(b);
    g.tick(1 / 60);
    expect(g.pitDark, 1);
    expect(g.isOver, isFalse);
    expect(host.sounds, contains('pop'));
  });

  test('karanlık huniye → kalkan saptırır; kalkansız kayıp', () {
    final (g, host) = makeGame();
    final b = Ball(true, g.pins.first.pos);
    b.path.addAll([g.pins.first.pos, g.j2s[0].pos, g.j2s[0].pos, g.funnel]);
    b.progress = 2.999;
    g.balls.add(b);
    g.tick(1 / 60);
    expect(g.shieldsLeft, 0, reason: 'kalkan tüketildi');
    expect(g.isOver, isFalse);
    // kalkansız ikinci deneme
    final b2 = Ball(true, g.pins.first.pos);
    b2.path.addAll(b.path);
    b2.progress = 2.999;
    g.balls.add(b2);
    g.tick(1 / 60);
    expect(g.isOver, isTrue);
    expect(host.events, contains('lose'));
  });

  test('altın çukura → israf, kombo kırılır', () {
    final (g, host) = makeGame();
    final b = Ball(false, g.pins.first.pos);
    b.path.addAll([g.pins.first.pos, g.j2s[1].pos, g.j2s[1].pos, g.pit]);
    b.progress = 2.999;
    g.balls.add(b);
    g.tick(1 / 60);
    expect(g.isOver, isFalse);
    expect(host.sounds, contains('lose'), reason: 'israf tonu');
  });

  test('kazanma: huniGold hedefe ulaşınca reached', () {
    final (g, host) = makeGame();
    final target = g.target;
    // mekanik testleri ayrı; kazanma yolu: hedef kadar altın huniye
    for (var i = 0; i < target; i++) {
      final b = Ball(false, g.pins.first.pos);
      b.path.addAll([g.pins.first.pos, g.j2s[0].pos, g.j2s[0].pos, g.funnel]);
      b.progress = 2.999;
      g.balls.add(b);
      g.tick(1 / 60);
      if (g.isOver) break;
    }
    expect(g.funnelGold, target);
    expect(g.result().reached, isTrue);
    expect(host.events, contains('win'));
  });

  test('uçtan uca: pim çek → kavşak ayarla → altın huniye (gerçek yol)', () {
    final (g, host) = makeGame();
    // saf altın cebi bul (karanlık yok) — yolunu huniye ayarla
    final pin = g.pins.firstWhere((p) => !p.hasDark && p.queue.isNotEmpty);
    final i = g.pins.indexOf(pin);
    g.j1s[i].openLeft = i % 2 == 0; // bu pim j2s[0]'a giden yön
    g.j2s[0].openLeft = true; // 200: sol → huni
    g.onTap(pin.pos + const Offset(2, 2));
    expect(pin.used, isTrue);
    // tüm topların yolculuğunu akıt (3 sn top başına)
    for (var t = 0; t < 400 && (g.balls.isNotEmpty || g.pendingForTest.isNotEmpty); t++) {
      g.tick(1 / 60);
    }
    expect(g.funnelGold, greaterThan(0), reason: 'saf altın cepten huniye');
    expect(g.isOver, isFalse, reason: 'karanlık yok — güvenli el');
  });
}
