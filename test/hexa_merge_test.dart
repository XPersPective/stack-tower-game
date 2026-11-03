/// PB-042 — HEXA NEON motor testleri: sütun düşüşü, zincirli birleşme,
/// skor, taşma → kalkan → kayıp, kazanma, sütun seçimi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/hexa_merge_game.dart';
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

typedef HexBundle = (HexaMergeGame, _FakeHost);

HexBundle makeGame() {
  final host = _FakeHost();
  final g = HexaMergeGame();
  g.resize(kW, kH);
  g.start(levelDef(0), host: host); // hedef 8
  return (g, host);
}

/// Parçayı belirli sütuna düşür (hızlandırılmış iniş).
void drop(HexaMergeGame g, int col, {int value = 2}) {
  g.falling!.col = col;
  g.falling!.value = value;
  g.falling!.y = 0.99;
  g.tick(1 / 60);
}

void main() {
  test('tür kimliği: hexaMerge', () {
    expect(HexaMergeGame().kind, GameKind.hexaMerge);
  });

  test('kurulum: 5×6 boş tahta, parça havada', () {
    final (g, _) = makeGame();
    expect(g.grid.every((col) => col.every((c) => c == null)), isTrue);
    expect(g.falling, isNotNull);
    expect(g.cellW, greaterThan(0));
  });

  test('iniş: parça sütun tabanına oturur', () {
    final (g, _) = makeGame();
    drop(g, 2, value: 2);
    expect(g.grid[2][kHexRows - 1]!.value, 2);
    drop(g, 2, value: 4);
    expect(g.grid[2][kHexRows - 2]!.value, 4, reason: 'üstüne yığılır');
  });

  test('birleşme: 2+2 → 4, skor +4', () {
    final (g, host) = makeGame();
    drop(g, 1, value: 2);
    drop(g, 1, value: 2);
    expect(g.grid[1][kHexRows - 1]!.value, 4);
    expect(g.grid[1][kHexRows - 2], isNull, reason: 'üst hücre boşaldı');
    expect(g.score, 4);
    expect(g.combo, 1);
    expect(host.sounds, contains('coin'));
  });

  test('zincir: 2+2+4 → 8 (iki adım), skor 4+8=12', () {
    final (g, _) = makeGame();
    drop(g, 0, value: 4);
    drop(g, 0, value: 2);
    drop(g, 0, value: 2);
    expect(g.grid[0][kHexRows - 1]!.value, 8);
    expect(g.grid[0][kHexRows - 2], isNull);
    expect(g.score, 12);
    expect(g.combo, 2);
  });

  test('dolu sütuna yönlendirme yok sayılır (taşma inişte tetiklenir)', () {
    final (g, _) = makeGame();
    for (var i = 0; i < kHexRows; i++) {
      drop(g, 3, value: i.isEven ? 2 : 4);
    }
    expect(g.isOver, isFalse);
    g.falling!.col = 0; // parça şu an 0. sütunda
    g.onTap(Offset(g.boardX + g.cellW * 3.5, g.boardY + 10)); // dolu sütun
    expect(g.falling!.col, 0, reason: 'dolu sütun yok sayıldı');
  });

  test('taşma: sütun dolunca kalkan alt 2 hücreyi temizler', () {
    final (g, host) = makeGame();
    for (var i = 0; i < kHexRows; i++) {
      drop(g, 3, value: i.isEven ? 2 : 4);
    }
    // bir parça daha aynı sütuna inemez → iniş anında taşma
    drop(g, 3, value: 2);
    expect(g.shieldsLeft, 0);
    expect(g.isOver, isFalse);
    expect(host.sounds, contains('shield'));
    expect(g.grid[3].where((c) => c != null).length, lessThan(kHexRows));
  });

  test('kalkansız taşma → kayıp', () {
    final (g, host) = makeGame();
    g.setShieldsForTest(0);
    for (var i = 0; i <= kHexRows; i++) {
      drop(g, 4, value: i.isEven ? 2 : 4);
    }
    expect(g.isOver, isTrue);
    expect(host.events, contains('lose'));
  });

  test('kazanma: skor hedefe ulaşınca reached', () {
    final (g, host) = makeGame();
    final target = levelDef(0).target; // 8
    // 4+4 birleşmesi = 8
    drop(g, 2, value: 4);
    drop(g, 2, value: 4);
    expect(g.score, greaterThanOrEqualTo(target));
    expect(g.isOver, isTrue);
    expect(g.result().reached, isTrue);
    expect(host.events, contains('win'));
  });
}
