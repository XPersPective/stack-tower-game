/// Stack Tower Game — RÜTBE HİYERARŞİSİ (PB-036 tur 7).
///
/// Kullanıcı isteği: "puanlarına göre sembolleri değişsin, değişik türde
/// görünümleri olsun, hiyerarşik yapısı olsun." Puan = yıldız + blok + seviye
/// bileşiği; 8 kademe; her kadenin ikonu/rengi/gradyonu farklı.
/// Saf katman — istemci tarafı (gerçek sıralama PB-037'de sunucuyla).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'progress.dart' as prog;

/// Rütbe kademeleri — eşikler [RankThreshold.points] bileşik puana göre.
enum RankTier {
  caylak,
  bronz,
  gumus,
  altin,
  platin,
  elmas,
  usta,
  efsane,
}

typedef RankThreshold = ({RankTier tier, String name, int points, IconData icon, List<Color> colors});

/// 8 kademe: bileşik puan eşikleri + görsel kimlik. Sıralı artan.
const List<RankThreshold> kRankTable = [
  (
    tier: RankTier.caylak,
    name: 'ÇAYLAK',
    points: 0,
    icon: Icons.pest_control_rodent_outlined,
    colors: [Color(0xFF6B7280), Color(0xFF374151)]
  ),
  (
    tier: RankTier.bronz,
    name: 'BRONZ',
    points: 60,
    icon: Icons.shield_outlined,
    colors: [Color(0xFFD08A4E), Color(0xFF8C5A2B)]
  ),
  (
    tier: RankTier.gumus,
    name: 'GÜMÜŞ',
    points: 160,
    icon: Icons.shield_outlined,
    colors: [Color(0xFFCBD5E1), Color(0xFF7C8BA1)]
  ),
  (
    tier: RankTier.altin,
    name: 'ALTIN',
    points: 320,
    icon: Icons.military_tech_outlined,
    colors: [Color(0xFFFFD54F), Color(0xFFB8860B)]
  ),
  (
    tier: RankTier.platin,
    name: 'PLATİN',
    points: 560,
    icon: Icons.military_tech,
    colors: [Color(0xFF7FE7DD), Color(0xFF2E8B8B)]
  ),
  (
    tier: RankTier.elmas,
    name: 'ELMAS',
    points: 900,
    icon: Icons.diamond_outlined,
    colors: [Color(0xFF8AB6FF), Color(0xFF2C5FD8)]
  ),
  (
    tier: RankTier.usta,
    name: 'USTA',
    points: 1400,
    icon: Icons.workspace_premium_outlined,
    colors: [Color(0xFFC084FC), Color(0xFF6B21A8)]
  ),
  (
    tier: RankTier.efsane,
    name: 'EFSANE',
    points: 2200,
    icon: Icons.local_fire_department_outlined,
    colors: [Color(0xFFFF8A5B), Color(0xFFB3123B)]
  ),
];

/// Bileşik puan: yıldız ×10 + toplam blok + seviye ×5 + mükemmel ×2.
/// (Kullanıcı tur 7: "puanlarına göre" — yıldız ağır, blok hafif katsayı.)
int rankPoints(prog.SaveState s) {
  var stars = 0;
  for (final e in s.completed.values) {
    stars += e['stars'] ?? 0;
  }
  return stars * 10 + s.totalBlocks + s.levelsDone * 5 + s.totalPerfect * 2;
}

/// Puana göre kademe — eşik tablosunda son geçilen basamak.
RankThreshold rankFor(prog.SaveState s) {
  final pts = rankPoints(s);
  var best = kRankTable.first;
  for (final r in kRankTable) {
    if (pts >= r.points) best = r;
  }
  return best;
}

/// Sonraki kademeye kalan puan (tepe kademede null — "zirvedesin").
int? pointsToNext(prog.SaveState s) {
  final pts = rankPoints(s);
  for (final r in kRankTable) {
    if (r.points > pts) return r.points - pts;
  }
  return null;
}

/// Yerel sıralama yüzdesi — LCG rakip simülasyonu (mevcut `rivalsFor` kuralı):
/// günlük skor tahtasında oyuncunun yüzde kaçıncı dilimde olduğu (0 = zirve).
/// Gerçek sıralama PB-037'de sunucudan gelir; bu, her zaman görünen yerel tahmin.
int localPercentile(prog.SaveState s, int day) {
  final blocks = s.daily['day'] == day ? (s.daily['best'] ?? 0) : 0;
  final rivals = prog.rivalsFor(day, blocks);
  var worse = 0;
  for (final r in rivals) {
    if (r.score < blocks) worse++;
  }
  final total = rivals.length;
  if (total == 0) return 100;
  return ((total - worse) * 100 / total).round().clamp(0, 100);
}

/// Rütbe madalyonunda kullanılan hafif parıltı (deterministik nefes).
double rankGlow(double time) => 0.75 + 0.25 * math.sin(time * 1.6);
