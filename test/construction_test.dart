import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/levels.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/map/construction.dart';

void main() {
  prog.SaveState saveWith(List<int> doneLevels, {int stars = 1}) {
    final s = prog.createSave();
    for (final i in doneLevels) {
      s.completed[i] = {'stars': stars, 'best': 10};
    }
    return s;
  }

  group('slot haritası (DESIGN-V2 §3.2)', () {
    test('idx 0..11 → 3 yapı × 4 parça; idx 12..14 → anıt 3 parça', () {
      expect(slotOf(0), (structure: 0, piece: 0));
      expect(slotOf(3), (structure: 0, piece: 3));
      expect(slotOf(4), (structure: 1, piece: 0));
      expect(slotOf(11), (structure: 2, piece: 3));
      expect(slotOf(12), (structure: 3, piece: 0));
      expect(slotOf(14), (structure: 3, piece: 2));
    });

    test('parça adları sıralı ve yapıya özgü', () {
      expect(pieceName(0), 'temel');
      expect(pieceName(3), 'ışık');
      expect(pieceName(4), 'temel');
      expect(pieceName(7), 'fener');
      expect(pieceName(12), 'kaide');
      expect(pieceName(14), 'taç');
    });

    test('her yapının spec\'i tam (isim/ikon/parçalar)', () {
      for (final s in kWorldStructures) {
        expect(s.name, isNotEmpty);
        expect(s.icon, isNotEmpty);
        expect(s.pieces.length, greaterThanOrEqualTo(3));
      }
      expect(kWorldStructures.length, 4);
    });
  });

  group('ilerleme sorguları', () {
    test('piecesBuilt: tamamlanan bölümlerle artar', () {
      final s = saveWith([0, 1]); // dünya 0, ev yapısı 2 parça
      expect(piecesBuilt(s, 0, 0), 2);
      expect(structureComplete(s, 0, 0), isFalse);
      final s2 = saveWith([0, 1, 2, 3]);
      expect(structureComplete(s2, 0, 0), isTrue);
      expect(structuresComplete(s2, 0), 1);
    });

    test('anıt 3 parçayla tamamlanır (idx 12-14)', () {
      final s = saveWith(List.generate(15, (i) => i)); // tüm dünya 0
      expect(piecesBuilt(s, 0, 3), 3);
      expect(structureComplete(s, 0, 3), isTrue);
      expect(structuresComplete(s, 0), 4);
      expect(worldBuildRatio(s, 0), 1.0);
    });

    test('worldBuildRatio kısmi ilerlemede doğru', () {
      final s = saveWith([0, 1, 2]);
      expect(worldBuildRatio(s, 0), closeTo(3 / 15, 1e-9));
    });

    test('nextBuildIdx: ilk tamamlanmamış bölüm', () {
      expect(nextBuildIdx(saveWith([]), 0), 0);
      expect(nextBuildIdx(saveWith([0, 1]), 0), 2);
      expect(nextBuildIdx(saveWith(List.generate(15, (i) => i)), 0), isNull);
    });

    test('realm: 10 dünya × 4 yapı = 40; tamamlanınca realmComplete', () {
      final s = prog.createSave();
      expect(realmStructures(s), 0);
      for (var st = 0; st < kStageCount; st++) {
        for (var k = 0; k < kLevelsPerStage; k++) {
          s.completed[st * kLevelsPerStage + k] = {'stars': 1, 'best': 10};
        }
      }
      expect(realmStructures(s), 40);
      expect(realmComplete(s), isTrue);
    });
  });

  group('constructionFor kutlama olayı', () {
    test('parça tamamlandığında structureCompleted true', () {
      final s = saveWith([0, 1, 2, 3]); // ev bitti
      final ev = constructionFor(s, 3)!;
      expect(ev.structure.kind, StructureKind.ev);
      expect(ev.pieceLabel, 'ışık');
      expect(ev.structureCompleted, isTrue);
      expect(ev.monumentCompleted, isFalse);
    });

    test('anıtın son parçası monumentCompleted true', () {
      final s = saveWith(List.generate(15, (i) => i));
      final anit = constructionFor(s, 14)!;
      expect(anit.structure.kind, StructureKind.anit);
      expect(anit.pieceLabel, 'taç');
      expect(anit.monumentCompleted, isTrue);
      expect(anit.structureCompleted, isTrue);
    });

    test('ara parçada tamamlanma bayrağı yok', () {
      final s = saveWith([0]);
      final ev = constructionFor(s, 0)!;
      expect(ev.structureCompleted, isFalse);
      expect(ev.pieceIdx, 0);
    });

    test('günlük/serbest (negatif idx) → null', () {
      final s = prog.createSave();
      expect(constructionFor(s, -1), isNull);
      expect(constructionFor(s, -2), isNull);
    });

    test('levelIdx sınırları: 150 üstü null', () {
      expect(constructionFor(prog.createSave(), kLevelCount), isNull);
    });
  });

  group('yerleşim', () {
    test('4 yapı için yerleşim var; anıt merkezde', () {
      expect(kPlacements.length, 4);
      expect(placementFor(3).radiusFactor, 0.0); // anıt merkez
      expect(placementFor(0).radiusFactor, greaterThan(0));
      expect(placementFor(99).radiusFactor, isNotNull); // clamp güvenli
    });
  });
}
