/// Stack Tower Game — GÖRÜNÜR İNŞAAT META (ADR-009, DESIGN-V2 §3.2).
/// Kullanıcı gereksinimi: "amaç tamamlandıkça arkada o bölümde tamamlanan bir şey
/// gösterilmeli ve çok güzel olmalı; birkaç aşamadan sonra hep bir şeyler tamamlanmalı."
///
/// Model: her dünyanın 15 bölümü adada GÖRÜNÜR yapılar yükseltir.
///   idx 0..11  → 3 yapı × 4 parça (temel → duvar → çatı → ışık)
///   idx 12..14 → DÜNYA ANITI (3 parça: kaide → gövde → taç)
/// Parça "inşa edildi" iff ilgili bölüm tamamlanmış (save.completed) — ek kayıt
/// alanı gerekmez; yalnız kutlama animasyonu için geçici durum tutulur.
library;

import '../game/levels.dart';
import '../game/progress.dart' as prog;

enum StructureKind { ev, kule, bahce, anit }

class StructureSpec {
  final StructureKind kind;
  final String name;
  final String icon;
  /// Parça adları — sırayla yükselir (temel → ... → ışık/taç).
  final List<String> pieces;
  const StructureSpec(this.kind, this.name, this.icon, this.pieces);
}

/// Bir dünyada idx sırasına göre inşa edilen yapılar.
const List<StructureSpec> kWorldStructures = [
  StructureSpec(StructureKind.ev, 'IŞIK EVİ', '🏠', ['temel', 'duvar', 'çatı', 'ışık']),
  StructureSpec(StructureKind.kule, 'GÖZLEM KULESİ', '🗼', ['temel', 'gövde', 'üst kat', 'fener']),
  StructureSpec(StructureKind.bahce, 'YILDIZ BAHÇESİ', '🌿', ['toprak', 'çit', 'çiçek', 'havuz']),
  StructureSpec(StructureKind.anit, 'DÜNYA ANITI', '🏛', ['kaide', 'gövde', 'taç']),
];

/// Bölüm idx → (yapı sırası, parça sırası). idx 0..14.
({int structure, int piece}) slotOf(int idx) {
  if (idx < 12) {
    return (structure: idx ~/ 4, piece: idx % 4);
  }
  return (structure: 3, piece: idx - 12); // anıt: 3 parça
}

StructureSpec structureAt(int idx) => kWorldStructures[slotOf(idx).structure];

/// Dünya idx'ine göre yapının parça sayısı.
int pieceCount(int idx) => structureAt(idx).pieces.length;

/// Bu bölüm tamamlandığında hangi parça yükselir?
String pieceName(int idx) {
  final slot = slotOf(idx);
  return kWorldStructures[slot.structure].pieces[slot.piece];
}

/* ------------------------- durum sorguları (saf) ------------------------- */

bool _done(prog.SaveState save, int levelIdx) => save.completed[levelIdx] != null;

/// Bir yapı (dünya + yapı sırası) kaç parça inşa etti?
int piecesBuilt(prog.SaveState save, int stage, int structureIdx) {
  final start = stage * kLevelsPerStage + structureIdx * 4;
  final isMonument = structureIdx == 3;
  final count = isMonument ? 3 : 4;
  var built = 0;
  for (var k = 0; k < count; k++) {
    final idx = isMonument ? stage * kLevelsPerStage + 12 + k : start + k;
    if (_done(save, idx)) built++;
  }
  return built;
}

bool structureComplete(prog.SaveState save, int stage, int structureIdx) =>
    piecesBuilt(save, stage, structureIdx) ==
    (structureIdx == 3 ? 3 : 4);

/// Dünyada tamamlanmış yapı sayısı (4 üzerinden).
int structuresComplete(prog.SaveState save, int stage) {
  var n = 0;
  for (var s = 0; s < kWorldStructures.length; s++) {
    if (structureComplete(save, stage, s)) n++;
  }
  return n;
}

/// Dünyanın inşaat ilerlemesi 0..1 (15 bölüm üzerinden).
double worldBuildRatio(prog.SaveState save, int stage) {
  var built = 0;
  for (var k = 0; k < kLevelsPerStage; k++) {
    if (_done(save, stage * kLevelsPerStage + k)) built++;
  }
  return built / kLevelsPerStage;
}

/// Sıradaki inşa edilecek bölüm idx'i (dünya içinde) — blueprint için.
int? nextBuildIdx(prog.SaveState save, int stage) {
  for (var k = 0; k < kLevelsPerStage; k++) {
    if (!_done(save, stage * kLevelsPerStage + k)) return k;
  }
  return null;
}

/// Diyar geneli: 10 dünya × tamamlanmış yapı sayısı (final ışık köprüleri).
int realmStructures(prog.SaveState save) {
  var n = 0;
  for (var s = 0; s < kStageCount; s++) {
    n += structuresComplete(save, s);
  }
  return n;
}

bool realmComplete(prog.SaveState save) =>
    realmStructures(save) == kStageCount * kWorldStructures.length;

/* ------------------------- kutlama durumu (geçici) ------------------------- */

/// Bölüm bitince haritada oynatılacak inşaat kutlaması.
class ConstructionEvent {
  final int stage;
  final int idx; // dünya içi idx
  final StructureSpec structure;
  final int pieceIdx;
  final String pieceLabel;
  /// Yapı bu parçayla TAMAMLANDI mı (büyük kutlama).
  final bool structureCompleted;
  /// Dünya anıtı tamamlandı mı (DÜNYA AYDINLANDI ile birleşir).
  final bool monumentCompleted;
  const ConstructionEvent({
    required this.stage,
    required this.idx,
    required this.structure,
    required this.pieceIdx,
    required this.pieceLabel,
    required this.structureCompleted,
    required this.monumentCompleted,
  });
}

/// Tamamlanan bölümden inşaat olayı üret (null: bölüm inşaata katkı vermiyorsa).
ConstructionEvent? constructionFor(prog.SaveState save, int levelIdx) {
  if (levelIdx < 0 || levelIdx >= kLevelCount) return null;
  final stage = stageOf(levelIdx);
  final idx = indexInStage(levelIdx);
  final slot = slotOf(idx);
  final spec = kWorldStructures[slot.structure];
  final built = piecesBuilt(save, stage, slot.structure);
  return ConstructionEvent(
    stage: stage,
    idx: idx,
    structure: spec,
    pieceIdx: slot.piece,
    pieceLabel: spec.pieces[slot.piece],
    structureCompleted: built == spec.pieces.length,
    monumentCompleted: slot.structure == 3 && built == 3,
  );
}

/// Haritada bir yapının parçalarını dünya koordinatına yerleştirir.
/// map3d.dart bunu adanın yüzeyinde çizmek için kullanır.
class StructurePlacement {
  final double angle; // ada merkezine göre açı
  final double radiusFactor; // 0..1 (ada yarıçapına oran)
  final double heightScale;
  const StructurePlacement(this.angle, this.radiusFactor, this.heightScale);
}

/// Yapı yerleşimleri: 3 yapı yolun kenarına, anıt merkeze.
const List<StructurePlacement> kPlacements = [
  StructurePlacement(0.9, 0.62, 1.0), // ev
  StructurePlacement(2.4, 0.55, 1.25), // kule
  StructurePlacement(4.1, 0.66, 0.85), // bahçe
  StructurePlacement(0.0, 0.0, 1.8), // anıt (merkez)
];

StructurePlacement placementFor(int structureIdx) =>
    kPlacements[structureIdx.clamp(0, kPlacements.length - 1)];
