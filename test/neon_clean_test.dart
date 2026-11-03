/// PB-041 — NEON TEMİZLİK motor testleri: yerleştirme, satır+sütun temizliği,
/// skor, taşma → kalkan → kayıp, kazanma, el tazeleme.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/neon_clean_game.dart';
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

typedef NeonBundle = (NeonCleanGame, _FakeHost);

NeonBundle makeGame({double speed = 0.9}) {
  final host = _FakeHost();
  final g = NeonCleanGame();
  g.resize(kW, kH);
  final def = levelDef(0);
  g.start(def, host: host);
  return (g, host);
}

/// i. el kartının merkezi (resize(kW,kH) sonrası).
double cardX(NeonCleanGame g, int i) {
  final cardW = (kW - 40 * g.scale) / 3;
  return 20 * g.scale + cardW * (i + 0.5);
}

double handY(NeonCleanGame g) =>
    g.boardY + kCleanGrid * g.cs + 40 * g.scale;

void main() {
  test('tür kimliği: neonClean', () {
    expect(NeonCleanGame().kind, GameKind.neonClean);
  });

  test('kurulum: el 3 parça, tahta boş, geometri ekran içinde', () {
    final (g, _) = makeGame();
    expect(g.hand.length, 3);
    expect(g.grid.every((c) => c == null), isTrue);
    expect(g.boardX, greaterThanOrEqualTo(0));
    expect(g.boardX + kCleanGrid * g.cs, lessThanOrEqualTo(kW));
  });

  test('yerleştirme: seç → boş hücreye koy → hücreler dolu, parça tükenir', () {
    final (g, host) = makeGame();
    // elin ilk parçasını sabitle: nokta şekli
    g.hand[0] = HandPiece(const CleanShape('dot', [(0, 0)]), 200);
    g.onTap(Offset(cardX(g, 0), handY(g))); // 1. kartı seç
    expect(g.selected, 0);
    // tahtada (0,0) hücresine koy: hücre merkezi
    g.onTap(Offset(g.boardX + g.cs * 0.5, g.boardY + g.cs * 0.5));
    expect(g.grid[0], 200);
    expect(g.hand[0].used, isTrue);
    expect(g.selected, isNull);
    expect(host.sounds, contains('place'));
  });

  test('geçersiz yerleştirme reddedilir (tahta değişmez, oyuncu ölmez)', () {
    final (g, _) = makeGame();
    // tahtayı (0,0)'a kilit fitle: dot parça + dolu hedef
    g.hand[0] = HandPiece(const CleanShape('dot', [(0, 0)]), 45);
    g.grid[0] = 12;
    g.onTap(Offset(cardX(g, 0), handY(g)));
    g.onTap(Offset(g.boardX + g.cs * 0.5, g.boardY + g.cs * 0.5));
    expect(g.grid[0], 12, reason: 'dolu hücre değişmedi');
    expect(g.hand[0].used, isFalse);
    expect(g.isOver, isFalse);
  });

  test('tam satır temizlenir: skor +8, hücreler boşalır', () {
    final (g, host) = makeGame();
    // satır 0'ı doldur; son hücreyi parçayla tamamla
    for (var c = 1; c < kCleanGrid; c++) {
      g.grid[c] = 200;
    }
    g.hand[0] = HandPiece(const CleanShape('dot', [(0, 0)]), 45);
    g.onTap(Offset(cardX(g, 0), handY(g)));
    // (0,0) hücresine koy → satır 0 tamamlanır
    g.onTap(Offset(g.boardX + g.cs * 0.5, g.boardY + g.cs * 0.5));
    for (var c = 0; c < kCleanGrid; c++) {
      expect(g.grid[c], isNull, reason: 'satır temizlenmeli');
    }
    expect(g.score, 18, reason: '8 satır + 10 TAM TEMİZLİK bonusu');
    expect(g.combo, 1);
    expect(host.sounds, contains('perfect'));
  });

  test('tam sütun da temizlenir (Block Blast farkı: satır+SÜTUN)', () {
    final (g, _) = makeGame();
    for (var r = 1; r < kCleanGrid; r++) {
      g.grid[r * kCleanGrid] = 130;
    }
    g.hand[0] = HandPiece(const CleanShape('dot', [(0, 0)]), 12);
    g.onTap(Offset(cardX(g, 0), handY(g)));
    g.onTap(Offset(g.boardX + g.cs * 0.5, g.boardY + g.cs * 0.5));
    for (var r = 0; r < kCleanGrid; r++) {
      expect(g.grid[r * kCleanGrid], isNull, reason: 'sütun temizlenmeli');
    }
    expect(g.score, 18, reason: '8 satır + 10 TAM TEMİZLİK bonusu');
  });

  test('çoklu temizlik: 2 satır → +8×2 +4 bonus = 20', () {
    final (g, _) = makeGame();
    for (var c = 1; c < kCleanGrid; c++) {
      g.grid[c] = 200; // satır 0
      g.grid[kCleanGrid + c] = 45; // satır 1
    }
    g.hand[0] = HandPiece(
        const CleanShape('d2v', [(0, 0), (1, 0)]), 12); // dikey domino
    g.onTap(Offset(cardX(g, 0), handY(g)));
    // (0,0)+(1,0)'a → iki satır birlikte tamamlanır
    g.onTap(Offset(
        g.boardX + g.cs * 0.5, g.boardY + g.cs * 1.0)); // merkez (0,1)
    expect(g.score, 30, reason: '16 + 4 çoklu bonus + 10 TAM TEMİZLİK');
  });

  test('el tazelenir: 3 parça kullanılınca yeni 3 parça', () {
    final (g, _) = makeGame();
    final old0 = g.hand[0];
    for (var i = 0; i < 3; i++) {
      g.hand[i] = HandPiece(const CleanShape('dot', [(0, 0)]), i * 40 + 5);
      g.onTap(Offset(cardX(g, i), handY(g)));
      // farklı hücrelere koy
      g.onTap(Offset(g.boardX + g.cs * (i * 2 + 0.5),
          g.boardY + g.cs * (i * 2 + 0.5)));
    }
    expect(g.hand.length, 3);
    expect(g.hand.every((p) => !p.used), isTrue);
    expect(identical(g.hand[0], old0), isFalse, reason: 'yeni el geldi');
  });

  test('taşma: hiçbir parça sığmıyor → kalkan alt 2 satırı temizler', () {
    final (g, host) = makeGame();
    // tahtayı alt 2 satır dışında doldur
    for (var r = 0; r < kCleanGrid - 2; r++) {
      for (var c = 0; c < kCleanGrid; c++) {
        g.grid[r * kCleanGrid + c] = 200;
      }
    }
    // alt 2 satırın her hücresini de doldur ama elde yalnız dot kalsın ve
    // dot hiçbir yere sığmasın: tüm tahta dolu
    for (var r = kCleanGrid - 2; r < kCleanGrid; r++) {
      for (var c = 0; c < kCleanGrid; c++) {
        g.grid[r * kCleanGrid + c] = 130;
      }
    }
    g.hand[0] = HandPiece(const CleanShape('dot', [(0, 0)]), 12);
    g.hand[1] = HandPiece(const CleanShape('dot', [(0, 0)]), 130);
    g.hand[2] = HandPiece(const CleanShape('dot', [(0, 0)]), 200);
    g.onTap(Offset(cardX(g, 0), handY(g))); // seç
    g.onTap(Offset(g.boardX + g.cs * 0.5, g.boardY + g.cs * 0.5)); // koy → taşma
    expect(g.shieldsLeft, 0, reason: 'kalkan tüketildi');
    expect(g.isOver, isFalse);
    // alt 2 satır temizlendi
    for (var r = kCleanGrid - 2; r < kCleanGrid; r++) {
      for (var c = 0; c < kCleanGrid; c++) {
        expect(g.grid[r * kCleanGrid + c], isNull);
      }
    }
    expect(host.sounds, contains('shield'));
  });

  test('kalkansız taşma → kayıp', () {
    final (g, host) = makeGame();
    for (var i = 0; i < kCleanGrid * kCleanGrid; i++) {
      g.grid[i] = 200;
    }
    g.hand[0] = HandPiece(const CleanShape('dot', [(0, 0)]), 12);
    g.hand[1] = HandPiece(const CleanShape('dot', [(0, 0)]), 45);
    g.hand[2] = HandPiece(const CleanShape('dot', [(0, 0)]), 130);
    g.setShieldsForTest(0);
    g.onTap(Offset(cardX(g, 0), handY(g)));
    g.onTap(Offset(g.boardX + g.cs * 0.5, g.boardY + g.cs * 0.5));
    expect(g.isOver, isTrue);
    expect(host.events, contains('lose'));
  });

  test('kazanma: skor hedefe ulaşınca reached', () {
    final (g, host) = makeGame();
    // hedef 8: 1 satır temizliği yeter
    for (var c = 1; c < kCleanGrid; c++) {
      g.grid[c] = 200;
    }
    g.hand[0] = HandPiece(const CleanShape('dot', [(0, 0)]), 45);
    g.onTap(Offset(cardX(g, 0), handY(g)));
    g.onTap(Offset(g.boardX + g.cs * 0.5, g.boardY + g.cs * 0.5));
    expect(g.isOver, isTrue);
    expect(g.result().reached, isTrue);
    expect(g.result().points, 18, reason: '8 + 10 tam temizlik');
    expect(host.events, contains('win'));
  });
}
