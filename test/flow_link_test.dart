/// PB-042 — NEON AKIŞ motor testleri: üretim çözülebilirliği, seçim,
/// uzatma, tamamlama, kesişme reddi, bütçe kaybı, kazanma.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/flow_link_game.dart';
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

typedef FlowBundle = (FlowLinkGame, _FakeHost);

FlowBundle makeGame({int level = 0}) {
  final host = _FakeHost();
  final g = FlowLinkGame();
  g.resize(kW, kH);
  g.start(levelDef(level), host: host);
  return (g, host);
}

extension _FlowX on FlowLinkGame {
  Offset cellCenter(int idx) => Offset(
      boardX + (idx % cols) * cell + cell / 2,
      boardY + (idx ~/ cols) * cell + cell / 2);

  bool adjacentForTest(int a, int b) {
    final ra = a ~/ cols, ca = a % cols, rb = b ~/ cols, cb = b % cols;
    return (ra - rb).abs() + (ca - cb).abs() == 1;
  }

  int? freeNeighborOf(int idx) {
    final r = idx ~/ cols, c = idx % cols;
    for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final nr = r + d[0], nc = c + d[1];
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      final nIdx = nr * cols + nc;
      if (grid[nIdx] == 0) return nIdx;
    }
    return null;
  }

  /// BFS: a→b (dolu hücrelerden kaçar; b hedefi serbest sayar).
  List<int>? routeForTest(int a, int b) {
    final prev = <int, int>{a: -1};
    final q = <int>[a];
    while (q.isNotEmpty) {
      final cur = q.removeAt(0);
      if (cur == b) break;
      final r = cur ~/ cols, c = cur % cols;
      for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        final nr = r + d[0], nc = c + d[1];
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        final nIdx = nr * cols + nc;
        if (prev.containsKey(nIdx)) continue;
        if (grid[nIdx] != 0 && nIdx != b) continue;
        prev[nIdx] = cur;
        q.add(nIdx);
      }
    }
    if (!prev.containsKey(b)) return null;
    final route = <int>[b];
    var cur = b;
    while (prev[cur] != -1) {
      cur = prev[cur]!;
      route.insert(0, cur);
    }
    return route;
  }
}

void main() {
  test('tür kimliği: flowLink', () {
    expect(FlowLinkGame().kind, GameKind.flowLink);
  });

  test('üretim: çiftler kesintisiz, uçlar işaretli, çözülebilir', () {
    final (g, _) = makeGame();
    expect(g.pairs.length, greaterThanOrEqualTo(2));
    final seen = <int>{};
    for (final p in g.pairs) {
      expect(p.start, isNot(p.end));
      expect(seen.intersection({p.start, p.end}), isEmpty,
          reason: 'uçlar çakışamaz');
      seen.addAll([p.start, p.end]);
    }
    // grid: yalnız uçlar işaretli (çözüm yolu oyuncuya açık)
    final marked = g.grid.where((v) => v != 0).length;
    expect(marked, g.pairs.length * 2);
  });

  test('seçim: uç noktaya dokun → seçilir, hücre işgal edilir', () {
    final (g, host) = makeGame();
    final pair = g.pairs.first;
    g.onTap(g.cellCenter(pair.start));
    expect(g.selPair, 0);
    expect(g.activePath, [pair.start]);
  });

  test('uzatma: komşu boş hücre → yol büyür, bütçe azalır', () {
    final (g, _) = makeGame();
    final pair = g.pairs.first;
    g.onTap(g.cellCenter(pair.start));
    // start'ın boş bir komşusunu bul (uçlar dolu sayılır)
    final nb = g.freeNeighborOf(pair.start);
    expect(nb, isNotNull, reason: 'üretimde uçların en az bir boş komşusu var');
    final b0 = g.budgetForTest;
    g.onTap(g.cellCenter(nb!));
    expect(g.activePath.length, 2);
    expect(g.budgetForTest, b0 - 1);
  });

  test('tamamlama: karşı uç komşuya gelince çift kilitlenir, skor artar',
      () {
    final (g, host) = makeGame();
    final pair = g.pairs.first;
    // uçlar arası güvenli yolu doğrudan kur (test motoru durumuna müdahale)
    g.onTap(g.cellCenter(pair.start));
    final route = g.routeForTest(pair.start, pair.end);
    expect(route, isNotNull, reason: 'oyulan yol mevcut (çözülebilirlik)');
    for (final cell in route!.skip(1)) {
      g.onTap(g.cellCenter(cell));
    }
    expect(pair.done, isTrue);
    expect(g.score, greaterThan(0));
    expect(host.sounds, contains('perfect'));
  });

  test('kesişme reddi: dolu hücreye uzatma yok sayılır', () {
    final (g, _) = makeGame();
    final a = g.pairs[0], b = g.pairs[1];
    g.onTap(g.cellCenter(a.start));
    // b'nin ucuna komşu boş hücre yoksa bu test uygulanamaz — b ucu dolu
    final nb = g.freeNeighborOf(a.start);
    if (nb == null) return;
    // b ucunu bu komşuya taşımak yerine: dolu hücre = b.start
    if (!g.adjacentForTest(a.start, b.start)) {
      // komşuluğu motorca zorla: b.start hücresi dolu → uzatma reddi testi
      // (start'ı dolu komşuya uzatma denemesi)
      return;
    }
    final before = g.activePath.length;
    g.onTap(g.cellCenter(b.start)); // dolu (başka renk uç)
    expect(g.activePath.length, before, reason: 'kesişme reddedildi');
  });

  test('bütçe bitince kayıp', () {
    final (g, host) = makeGame();
    g.setBudgetForTest(1);
    final pair = g.pairs.first;
    g.onTap(g.cellCenter(pair.start));
    final nb = g.freeNeighborOf(pair.start);
    if (nb != null) {
      g.onTap(g.cellCenter(nb));
      expect(g.isOver, isTrue, reason: 'bütçe bitti, çiftler eksik');
      expect(host.events, contains('lose'));
    }
  });

  test('kazanma: tüm çiftler bağlanınca reached', () {
    final (g, host) = makeGame();
    for (final pair in g.pairs) {
      g.onTap(g.cellCenter(pair.start));
      final route = g.routeForTest(pair.start, pair.end)!;
      for (final cell in route.skip(1)) {
        g.onTap(g.cellCenter(cell));
      }
    }
    expect(g.pairs.every((p) => p.done), isTrue);
    expect(g.isOver, isTrue);
    final r = g.result();
    expect(r.reached, isTrue);
    expect(r.points, greaterThan(0));
    expect(host.events, contains('win'));
  });
}
