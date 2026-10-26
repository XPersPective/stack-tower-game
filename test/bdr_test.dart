import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/kinds/balance_game.dart';
import 'package:stack_tower_game/game/kinds/defend_game.dart';
import 'package:stack_tower_game/game/kinds/rhythm_game.dart';
import 'package:stack_tower_game/game/kinds/stack_game.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/mini_game.dart';
import 'package:stack_tower_game/screens/play_screen.dart';

class _Host implements MiniGameHost {
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

/// Küçük hedefli özel bölüm — kazanma yollarını deterministik kılar.
LevelDef _defWithTarget(int target) {
  final base = levelDef(6);
  return LevelDef(
    i: base.i, stage: base.stage, idx: base.idx, num: base.num,
    theme: base.theme, target: target, speed: base.speed, tol: base.tol,
    modifier: base.modifier, coins: base.coins, box: base.box, name: base.name,
  );
}

double _distSq(DefendGame g, int i) {
  final wav = g.waves[i];
  final dx = wav.x - g.coreX, dy = wav.y - g.coreY;
  return dx * dx + dy * dy;
}

void main() {
  group('BALANCE kuralları', () {
    BalanceGame game(_Host host, {int shields = 1}) => BalanceGame()
      ..resize(460, 780)
      ..start(levelDef(6), host: host, shields: shields);

    test('§3.1: dokunuş YAPILAN tarafa ağırlık verir — sol sola, sağ sağa', () {
      final host = _Host();
      final g = game(host);
      g.setTiltForTest(0.3);
      g.onTap(const Offset(100, 400)); // sol yarı → sola ağırlık → merkeze yaklaşır
      expect(g.tiltForTest, closeTo(0.16, 1e-9), reason: '0.3 - 0.14');
      expect(g.nudgesForTest, 1);
      final g2 = game(host);
      g2.setTiltForTest(0.3);
      g2.onTap(const Offset(360, 400)); // sağ yarı → sağa ağırlık → devrilmeye yaklaşır
      expect(g2.tiltForTest, closeTo(0.44, 1e-9),
          reason: 'beceri = taraf seçimi: sabit merkezleme itkisi yok');
      expect(host.sounds, contains('place'));
    });

    test('anti-spam: 0.22 s bekleme içinde ikinci dokunuş yok sayılır', () {
      final host = _Host();
      final g = game(host);
      g.setTiltForTest(0.3);
      g.onTap(const Offset(100, 400));
      g.onTap(const Offset(100, 400)); // cd içinde → etki etmez
      expect(g.nudgesForTest, 1);
      expect(g.tiltForTest, closeTo(0.16, 1e-9));
      g.tick(0.1); // cd: 0.22 → 0.12
      g.onTap(const Offset(100, 400)); // hâlâ cd içinde
      expect(g.nudgesForTest, 1);
      g.tick(0.2); // cd tükendi
      g.onTap(const Offset(100, 400));
      expect(g.nudgesForTest, 2);
    });

    test('perfect = merkez bandında süre; dokunuş başına ödül yok (spam farm edilemez)', () {
      final host = _Host();
      final g = game(host);
      for (var i = 0; i < 5; i++) {
        g.setTiltForTest(0); // her kare bant içinde başlar: deterministik
        g.tick(0.1);
      }
      expect(g.result().perfects, 1, reason: '0.5 s bant → 1 perfect');
      expect(g.combo, 1);
      expect(host.sounds, contains('perfect'));
      g.onTap(const Offset(100, 400)); // dokunuş perfect üretmez
      expect(g.result().perfects, 1);
    });

    test('bant dışına çıkınca kombo sıfırlanır', () {
      final host = _Host();
      final g = game(host);
      for (var i = 0; i < 5; i++) {
        g.setTiltForTest(0);
        g.tick(0.1);
      }
      expect(g.combo, 1);
      g.setTiltForTest(0.2, d: 0);
      g.tick(0.016);
      expect(g.combo, 0);
    });

    test('eğim sınırı aşılırsa kalkan yoksa kayıp', () {
      final host = _Host();
      final g = game(host, shields: 0);
      g.setTiltForTest(0.55); // 0.5 eşiğini rastgele sürükleme marjıyla aşar
      g.tick(0.016);
      expect(g.isOver, isTrue);
      expect(host.events, contains('lose'));
      expect(g.result().reached, isFalse);
    });

    test('kalkan çökmeyi keser: eğim yarıya iner, oyun sürer', () {
      final host = _Host();
      final g = game(host, shields: 1);
      g.setTiltForTest(0.55); // 0.5 eşiğini rastgele sürükleme marjıyla aşar
      g.tick(0.016);
      expect(g.isOver, isFalse);
      expect(host.events, contains('shield'));
      expect(g.shieldsLeft, 0);
      expect(g.tiltForTest, lessThan(0.26), reason: '0.5 * 0.45 = 0.225');
    });

    test('hedef süreye dayanınca kazanır', () {
      final host = _Host();
      final g = game(host, shields: 3);
      var steps = 0;
      while (!g.isOver && steps < 2000) {
        g.tick(0.1);
        g.setTiltForTest(0); // sürüklemeyi sıfırla: süre yolu deterministik
        steps++;
      }
      expect(g.isOver, isTrue);
      expect(host.events, contains('win'));
      expect(g.result().reached, isTrue);
      expect(g.score, greaterThanOrEqualTo(g.target));
    });

    test('geç bölüm hedefi kırpılmaz: needed = def.target (>30 üst sınır yok)', () {
      final host = _Host();
      final def = levelDef(104); // snapshot: target 31+ — eski 30 s kelepçesi burada kazandırırdı
      expect(def.target, greaterThan(30));
      final g = BalanceGame()
        ..resize(460, 780)
        ..start(def, host: host);
      expect(g.needed, def.target.toDouble());
    });
  });

  group('DEFEND kuralları', () {
    // resize(460,780) sonrası: coreX=230, coreY=592.8, coreR=34, cutR=96
    (DefendGame, _Host) game({int shields = 1, int target = 99}) {
      final host = _Host();
      final g = DefendGame()
        ..resize(460, 780)
        ..start(_defWithTarget(target), host: host, shields: shields);
      return (g, host);
    }

    test('dalga çekirdeğe doğru ilerler', () {
      final (g, _) = game();
      g.spawnForTest(x: 230, y: 100);
      final d0 = _distSq(g, 0);
      g.tick(0.1);
      final d1 = _distSq(g, 0);
      expect(d1, lessThan(d0), reason: 'dalga çekirdeğe yaklaşır');
    });

    test('anti-spam: bekleme penceresinde ikinci dokunuş yok sayılır', () {
      final (g, host) = game();
      g.onTap(const Offset(230, 400));
      g.onTap(const Offset(230, 400));
      expect(host.haptics, 1,
          reason: 'etkin dokunuş haptic verir; cd içindeki tekrar etki etmez');
    });

    test('kalkan penceresi + dalga kesme yarıçapı içinde = blok', () {
      final (g, host) = game();
      g.spawnForTest(x: 230, y: 582.8); // d=10 < cutR=96
      g.onTap(const Offset(230, 400));
      g.tick(0.016);
      expect(g.blockedForTest, 1);
      expect(g.combo, 1);
      expect(g.score, 1);
      expect(g.waves, isEmpty);
      expect(host.sounds, anyOf(contains('perfect'), contains('place')));
    });

    test('N dalgayı kesince kazanır', () {
      final (g, host) = game(shields: 3, target: 3);
      var cut = 0;
      while (!g.isOver && cut < 40) {
        g.onTap(const Offset(230, 400)); // taze kalkan (cd 0)
        for (var j = 0; j < 8 && !g.isOver; j++) {
          g.spawnForTest(x: 230, y: 582.8);
          g.tick(0.016); // shieldT=0.18 penceresi içinde kes
          cut++;
        }
        for (var j = 0; j < 12 && !g.isOver; j++) {
          g.tick(0.016); // anti-spam cd'sini (0.34) tüket
        }
      }
      expect(g.isOver, isTrue);
      expect(host.events, contains('win'));
      expect(g.result().reached, isTrue);
      expect(g.blockedForTest, greaterThanOrEqualTo(3));
    });

    test('dalga çekirdeğe değerse: kalkan yoksa kayıp, varsa kalkan harcanır', () {
      final (g0, host0) = game(shields: 0);
      g0.spawnForTest(x: 230, y: 587.8); // d=5 ≤ coreR+8=42
      g0.tick(0.016);
      expect(g0.isOver, isTrue);
      expect(host0.events, contains('lose'));

      final (g1, host1) = game(shields: 1);
      g1.spawnForTest(x: 230, y: 587.8);
      g1.tick(0.016);
      expect(g1.isOver, isFalse);
      expect(host1.events, contains('shield'));
      expect(g1.shieldsLeft, 0);
      expect(g1.blockedForTest, 0);
    });
  });

  group('RHYTHM kuralları', () {
    RhythmGame game(_Host host, {int shields = 1}) => RhythmGame()
      ..resize(460, 780)
      ..start(levelDef(6), host: host, shields: shields);

    test('vuruş çizgisindeki nota dokunuşla AYNI KAREDE isabet (gecikme 0 kare)', () {
      final host = _Host();
      final g = game(host);
      g.addNoteForTest(); // nota tam vuruş çizgisinde
      g.onTap(const Offset(230, 561)); // tick YOK: dokunuş anında işlenmeli
      expect(g.score, 1, reason: 'onTap senkron: bekleyen tick olmadan isabet');
      expect(g.combo, 1);
    });

    test('tam merkez = mükemmel pencere', () {
      final host = _Host();
      final g = game(host);
      g.addNoteForTest();
      g.onTap(const Offset(230, 561));
      expect(g.result().perfects, 1);
      expect(host.sounds, contains('perfect'));
    });

    test('boş dokunuş = ıskalama: kombo sıfırlanır, miss sayılır', () {
      final host = _Host();
      final g = game(host);
      g.onTap(const Offset(230, 561)); // notalar spawn olmadı (beatT henüz 0.5)
      expect(g.missesForTest, 1);
      expect(g.combo, 0);
    });

    test('geçen nota ıskalama sayılır', () {
      final host = _Host();
      final g = game(host);
      g.addNoteForTest();
      g.tick(0.5); // nota pencereyi çoktan geçti
      expect(g.missesForTest, greaterThanOrEqualTo(1));
    });

    test('3 ıskada kalkan: harcanır ve sayaç sıfırlanır; kalkansızsa kayıp', () {
      final host1 = _Host();
      final g1 = game(host1, shields: 1);
      for (var i = 0; i < 3; i++) {
        g1.onTap(const Offset(230, 561));
      }
      expect(host1.events, contains('shield'));
      expect(g1.missesForTest, 0);
      expect(g1.shieldsLeft, 0);
      expect(g1.isOver, isFalse);

      final host0 = _Host();
      final g0 = game(host0, shields: 0);
      for (var i = 0; i < 3; i++) {
        g0.onTap(const Offset(230, 561));
      }
      expect(g0.isOver, isTrue);
      expect(host0.events, contains('lose'));
    });

    test('N isabet = kazanma', () {
      final host = _Host();
      final g = game(host, shields: 3);
      final need = g.target;
      for (var i = 0; i < need && !g.isOver; i++) {
        g.addNoteForTest();
        g.onTap(const Offset(230, 561));
      }
      expect(g.isOver, isTrue);
      expect(host.events, contains('win'));
      expect(g.result().reached, isTrue);
    });
  });

  group('Antoloji dispatch', () {
    test('10/10 tür kendi uygulamasına düşer; BALANCE/DEFEND/RHYTHM fallback değil', () {
      expect(createMiniGame(GameKind.balance), isA<BalanceGame>());
      expect(createMiniGame(GameKind.defend), isA<DefendGame>());
      expect(createMiniGame(GameKind.rhythm), isA<RhythmGame>());
      for (final k in GameKind.values) {
        final g = createMiniGame(k);
        expect(g.kind, k, reason: 'her tür kendi oyununu üretir');
        if (k != GameKind.stack) {
          expect(g is StackGame, isFalse, reason: '$k StackGame fallbackine düşmemeli');
        }
      }
    });
  });
}
