/// Stack Tower Game — saf bırakma çekirdeği.
/// `reference/www/game.js` CORE bölümünün birebir portu (SPEC §2.1, §2.3).
/// Hiçbir Flutter bağımlılığı yoktur; birim testlenir.
library;

const int kPerfectTolerance = 6;
const int kMinBlockWidth = 6;
const double kRangeFactor = 2.1;
const double kOvershoot = 1.05;

double clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Basit blok/geometri (x: sol kenar, w: genişlik).
class Block {
  double x;
  double w;
  Block(this.x, this.w);
}

/// Süzülen blok (dir: +1 sağa, -1 sola).
class Moving {
  double x;
  double w;
  int dir;
  Moving(this.x, this.w, this.dir);
}

/// Bırakma sonucu (game.js resolveDrop birebir).
class DropResult {
  final bool ok; // yerleşti mi
  final bool perfect;
  final Block? placed; // kulenin yeni üstü
  final List<Block> cuts; // kopup düşen parçalar
  DropResult({required this.ok, required this.perfect, this.placed, required this.cuts});
}

/// Bırakma matematiği: örtüşme → kırpma; tolerans içinde → mükemmel.
DropResult resolveDrop(Moving moving, Block top, [int? tolerance]) {
  final tol = tolerance ?? kPerfectTolerance;
  final overlapLeft = moving.x > top.x ? moving.x : top.x;
  final overlapRight = (moving.x + moving.w) < (top.x + top.w) ? (moving.x + moving.w) : (top.x + top.w);
  final overlap = overlapRight - overlapLeft;
  if (overlap <= 0) {
    return DropResult(ok: false, perfect: false, placed: null, cuts: [Block(moving.x, moving.w)]);
  }
  final perfect = (moving.x - top.x).abs() <= tol && (moving.w - top.w).abs() <= tol;
  if (perfect) {
    return DropResult(ok: true, perfect: true, placed: Block(top.x, top.w), cuts: []);
  }
  final cuts = <Block>[];
  if (moving.x < top.x - 0.01) cuts.add(Block(moving.x, top.x - moving.x));
  final mR = moving.x + moving.w;
  final tR = top.x + top.w;
  if (mR > tR + 0.01) cuts.add(Block(tR, mR - tR));
  return DropResult(ok: true, perfect: false, placed: Block(overlapLeft, overlap), cuts: cuts);
}

/// Hareket aralığı genişliği.
double travelRange(double w) => w * kRangeFactor;

/// Süzülen bloğun x sınırları.
class MovingBounds {
  final double minX;
  final double maxX;
  const MovingBounds(this.minX, this.maxX);
}

MovingBounds movingBounds(Block top) {
  final minX = top.x - top.w * kOvershoot;
  return MovingBounds(minX, minX + travelRange(top.w));
}

/// Yerleştirilen blok sayısına göre hız çarpanı.
double speedMultiplier(int placed) {
  final v = 0.9 + placed * 0.055;
  return v < 3 ? v : 3;
}

/// Bir karede süzülen bloğun ilerlemesi (sınırlarda sepgör).
Moving stepMoving(Moving moving, Block top, int placed, double dt, [double speedScale = 1]) {
  final b = movingBounds(top);
  // JS: (speedScale || 1) — 0/NaN falsey kabul edilir, 1'e düşer (game.js satır 53).
  final ss = (speedScale == 0 || speedScale.isNaN) ? 1.0 : speedScale;
  final speed = travelRange(top.w) * 0.5 * speedMultiplier(placed) * ss;
  moving.x += moving.dir * speed * dt;
  if (moving.x >= b.maxX) {
    moving.x = b.maxX;
    moving.dir = -1;
  } else if (moving.x <= b.minX) {
    moving.x = b.minX;
    moving.dir = 1;
  }
  return moving;
}

/// 4 mükemmelette kule %4 geri büyür (baseW tavanıyla).
double growthWidth(double w, double baseW, int combo) {
  return (combo > 0 && combo % 4 == 0) ? (w * 1.04 < baseW ? w * 1.04 : baseW) : w;
}
