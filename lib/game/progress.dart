/// Stack Tower Game — ilerleme/ödül sistemi (saf katman, test edilebilir).
/// `reference/www/progress.js` birebir portu (SPEC §2.6, §5): para, yıldız,
/// görünümler, kalıntılar, görevler, kutular, günlük rekor. Depolama soyutlanmıştır.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'levels.dart';
import '../services/storage.dart';

const String kSaveKey = 'stacktower_save_v2'; // ADR-001 (anahtar sabit; biçim v3 üst-kümeleri)

/// Kilitlenebilir kule görünümleri (hue: blok paletinin başlangıç rengi).
class Skin {
  final String id;
  final String name;
  final int price;
  final int hue;
  const Skin(this.id, this.name, this.price, this.hue);
}

const List<Skin> kSkins = [
  Skin('default', 'NEON', 0, 200),
  Skin('altin', 'ALTIN KULE', 120, 45),
  Skin('alev', 'ALEV', 150, 10),
  Skin('okyanus', 'OKYANUS', 160, 192),
  Skin('orman', 'YOSUN', 180, 130),
  Skin('buz', 'BUZ', 200, 205),
  Skin('pembe', 'SÜPERNOVA', 240, 322),
  Skin('gokkusagi', 'GÖKKUŞAĞI', 320, 0),
];

Skin skinById(String id) => kSkins.firstWhere((s) => s.id == id, orElse: () => kSkins[0]);

/// Dünya kalıntıları: her dünyayı bitirince kalıcı bir yadigâr kazanılır.
class Relic {
  final int stage;
  final String name;
  final String icon;
  final String lore;
  const Relic(this.stage, this.name, this.icon, this.lore);
}

const List<Relic> kRelics = [
  Relic(0, 'NEON KORU', '💠', 'Şehrin ilk ışığı. Hâlâ içinde bir nabız atıyor.'),
  Relic(1, 'YAŞAM TOHUMU', '🌱', 'Bir ormanı tek başına taşıyabilecek kadar ağır.'),
  Relic(2, 'KUM SAATİ', '⏳', 'İçindeki kum hiç bitmiyor; sabrı ödüllendiriyor.'),
  Relic(3, 'EZELİ KRİSTAL', '❄️', 'Sessizliğin donmuş hâli. Dokununca bir nota çalıyor.'),
  Relic(4, 'YILDIZ ÇEKİRDEĞİ', '🪐', 'Bir yıldızın kalbi; avucunda hafifçe titriyor.'),
  Relic(5, 'MAGMA KALBİ', '🌋', 'Volkanın son atışı. Sıcaklığı hiç geçmiyor.'),
  Relic(6, 'GÖK YELKENİ', '☁️', 'Bulut şehrin rüzgârını içine hapsetmiş bir bez.'),
  Relic(7, 'İNCİ FENERİ', '🐚', 'Derinlerde yanan tek ışık; yolunu o çiziyor.'),
  Relic(8, 'YANKI PRİZMASI', '🔮', 'Sana baktığında seni değil, olmak istediğini gösteriyor.'),
  Relic(9, 'ZİRVE TACI', '👑', 'Yükselişin son kanıtı. Ama gökyüzü hâlâ bitmedi.'),
];

Relic? relicFor(int stage) {
  for (final r in kRelics) {
    if (r.stage == stage) return r;
  }
  return null;
}

/// Bir günlük görev.
class MissionItem {
  String stat; // totalPerfect | totalBlocks | levelsDone
  String label;
  int goal;
  int reward;
  int base;
  bool claimed;

  MissionItem({
    required this.stat,
    required this.label,
    required this.goal,
    required this.reward,
    required this.base,
    this.claimed = false,
  });

  Map<String, dynamic> toJson() => {
        'stat': stat,
        'label': label,
        'goal': goal,
        'reward': reward,
        'base': base,
        'claimed': claimed,
      };

  static MissionItem fromJson(Map<String, dynamic> j) => MissionItem(
        stat: j['stat'] as String,
        label: j['label'] as String,
        goal: j['goal'] as int,
        reward: j['reward'] as int,
        base: j['base'] as int,
        claimed: j['claimed'] as bool? ?? false,
      );
}

/// Kayıt durumu — SPEC §5 şeması (JS JSON anahtar adları korunur).
class SaveState {
  int v;
  int coins;
  Map<int, Map<String, int>> completed; // levelIndex -> {stars,best}
  List<String> skins;
  String activeSkin;
  int best;
  int totalPerfect;
  int totalBlocks;
  int levelsDone;
  int day;
  Map<String, dynamic>? missions; // {day, items[]}
  Map<String, int> daily; // {day,best}
  Map<String, bool> worldsCelebrated;
  Map<String, bool> relics;
  Map<String, bool> boxes;
  // PB-018 pazar yeri (şema genişletme; eski kayıtlar varsayılanla okunur)
  int marketDay;
  Map<String, bool> marketBought;
  int marketShields;
  bool marketDouble;
  bool marketJoker;
  int relicPieces;
  /// PB-021: pazar keşfi bir kez duyurulur.
  bool marketSeen;
  /// PB-020: son 7 günün en iyi skoru (gün → blok).
  Map<int, int> dailyHistory;
  // PB-034 (v3): günlük takvim + streak (eski kayıtlar varsayılanla okunur)
  int streakLastDay;
  int streakDays;
  bool streakShield; // telafi kalkanı: 1 gün kaçırma affedilir (7. gün kazanılır)
  int calendarClaimDay; // son talep günü
  int calendarIndex; // 7 günlük döngüde sıradaki slot (0..6)
  // PB-035 B3: Kabus Kulesi (haftalık 3 hak, kayıp cezasız)
  int nightmareWeek; // son oynanan hafta
  int nightmareTries; // bu hafta tüketilen haklar (0..3)
  int nightmareBest; // tüm zamanlar rekoru (blok)
  bool devUnlockAll; // PB-036: geliştirici modu — tüm bölümler açık (yalnız debug UI)

  SaveState({
    this.v = 3,
    this.coins = 60,
    Map<int, Map<String, int>>? completed,
    List<String>? skins,
    this.activeSkin = 'default',
    this.best = 0,
    this.totalPerfect = 0,
    this.totalBlocks = 0,
    this.levelsDone = 0,
    this.day = -1,
    this.missions,
    Map<String, int>? daily,
    Map<String, bool>? worldsCelebrated,
    Map<String, bool>? relics,
    Map<String, bool>? boxes,
    this.marketDay = -1,
    Map<String, bool>? marketBought,
    this.marketShields = 0,
    this.marketDouble = false,
    this.marketJoker = false,
    this.relicPieces = 0,
    this.marketSeen = false,
    Map<int, int>? dailyHistory,
    this.streakLastDay = -1,
    this.streakDays = 0,
    this.streakShield = false,
    this.calendarClaimDay = -1,
    this.calendarIndex = 0,
    this.nightmareWeek = -1,
    this.nightmareTries = 0,
    this.nightmareBest = 0,
    this.devUnlockAll = false,
  })  : dailyHistory = dailyHistory ?? {},
        marketBought = marketBought ?? {},
        completed = completed ?? {},
        skins = skins ?? ['default'],
        daily = daily ?? {'day': -1, 'best': 0},
        worldsCelebrated = worldsCelebrated ?? {},
        relics = relics ?? {},
        boxes = boxes ?? {};

  Map<String, dynamic> toJson() => {
        'v': v,
        'coins': coins,
        'completed': completed.map((k, val) => MapEntry(k.toString(), val)),
        'skins': skins,
        'activeSkin': activeSkin,
        'best': best,
        'totalPerfect': totalPerfect,
        'totalBlocks': totalBlocks,
        'levelsDone': levelsDone,
        'day': day,
        'missions': missions,
        'daily': daily,
        'worldsCelebrated': worldsCelebrated,
        'relics': relics,
        'boxes': boxes,
        'marketDay': marketDay,
        'marketBought': marketBought,
        'marketShields': marketShields,
        'marketDouble': marketDouble,
        'marketJoker': marketJoker,
        'relicPieces': relicPieces,
        'marketSeen': marketSeen,
        'dailyHistory': dailyHistory.map((k, v) => MapEntry(k.toString(), v)),
        'streakLastDay': streakLastDay,
        'streakDays': streakDays,
        'streakShield': streakShield,
        'calendarClaimDay': calendarClaimDay,
        'calendarIndex': calendarIndex,
        'nightmareWeek': nightmareWeek,
        'nightmareTries': nightmareTries,
        'nightmareBest': nightmareBest,
        'devUnlockAll': devUnlockAll,
      };

  /// JS şemasıyla aynı JSON (anahtar sırası fark etmez, alan adları aynı).
  String encode() => const JsonEncoder().convert(toJson());

  static SaveState fromJson(Map<String, dynamic> j) {
    final completed = <int, Map<String, int>>{};
    (j['completed'] as Map<String, dynamic>? ?? {}).forEach((k, val) {
      final m = (val as Map<String, dynamic>);
      completed[int.parse(k)] = {
        'stars': (m['stars'] as num).toInt(),
        'best': (m['best'] as num).toInt(),
      };
    });
    List<MissionItem> items = [];
    final mj = j['missions'] as Map<String, dynamic>?;
    if (mj != null && mj['items'] != null) {
      items = (mj['items'] as List).map((e) => MissionItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return SaveState(
      v: (j['v'] as num?)?.toInt() ?? 2,
      coins: (j['coins'] as num?)?.toInt() ?? 60,
      completed: completed,
      skins: (j['skins'] as List?)?.map((e) => e as String).toList(),
      activeSkin: j['activeSkin'] as String? ?? 'default',
      best: (j['best'] as num?)?.toInt() ?? 0,
      totalPerfect: (j['totalPerfect'] as num?)?.toInt() ?? 0,
      totalBlocks: (j['totalBlocks'] as num?)?.toInt() ?? 0,
      levelsDone: (j['levelsDone'] as num?)?.toInt() ?? 0,
      day: (j['day'] as num?)?.toInt() ?? -1,
      missions: mj == null ? null : {'day': mj['day'], 'items': items.map((e) => e.toJson()).toList()},
      daily: {
        'day': ((j['daily'] as Map<String, dynamic>?)?['day'] as num?)?.toInt() ?? -1,
        'best': ((j['daily'] as Map<String, dynamic>?)?['best'] as num?)?.toInt() ?? 0,
      },
      worldsCelebrated: (j['worldsCelebrated'] as Map<String, dynamic>? ?? {})
          .map((k, val) => MapEntry(k, val == true)),
      relics: (j['relics'] as Map<String, dynamic>? ?? {}).map((k, val) => MapEntry(k, val == true)),
      boxes: (j['boxes'] as Map<String, dynamic>? ?? {}).map((k, val) => MapEntry(k, val == true)),
      marketDay: (j['marketDay'] as num?)?.toInt() ?? -1,
      marketBought: (j['marketBought'] as Map<String, dynamic>? ?? {})
          .map((k, val) => MapEntry(k, val == true)),
      marketShields: (j['marketShields'] as num?)?.toInt() ?? 0,
      marketDouble: j['marketDouble'] == true,
      marketJoker: j['marketJoker'] == true,
      relicPieces: (j['relicPieces'] as num?)?.toInt() ?? 0,
      marketSeen: j['marketSeen'] == true,
      dailyHistory: (j['dailyHistory'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(int.parse(k), (v as num).toInt())),
      streakLastDay: (j['streakLastDay'] as num?)?.toInt() ?? -1,
      streakDays: (j['streakDays'] as num?)?.toInt() ?? 0,
      streakShield: j['streakShield'] == true,
      calendarClaimDay: (j['calendarClaimDay'] as num?)?.toInt() ?? -1,
      calendarIndex: (j['calendarIndex'] as num?)?.toInt() ?? 0,
      nightmareWeek: (j['nightmareWeek'] as num?)?.toInt() ?? -1,
      nightmareTries: (j['nightmareTries'] as num?)?.toInt() ?? 0,
      nightmareBest: (j['nightmareBest'] as num?)?.toInt() ?? 0,
      devUnlockAll: j['devUnlockAll'] == true,
    );
  }
}

/* ============ PB-034: günlük takvim + streak (saf mantık) ============ */

/// 7 günlük takvim ödülleri — 7. gün büyük ödül (C-019 cömertlik ilkesi).
const List<int> kCalendarRewards = [25, 30, 35, 40, 50, 60, 100];

/// Gün açılışı: streak sayacını günceller. Zaten bugün görüldüyse dokunmaz.
/// Telafi kalkanı [streakShield] tam 1 gün kaçırma affeder (kalkan tüketilir).
/// Dönen değer: yeni streak (bilgi amaçlı).
int touchStreak(SaveState s, int today) {
  if (s.streakLastDay == today) return s.streakDays;
  final gap = today - s.streakLastDay;
  if (s.streakLastDay == -1 || gap == 1) {
    s.streakDays += 1;
  } else if (gap == 2 && s.streakShield) {
    s.streakShield = false; // kalkan dünü affetti
    s.streakDays += 1;
  } else {
    s.streakDays = 1;
  }
  s.streakLastDay = today;
  return s.streakDays;
}

/// Günün takvim ödülünü talep eder; bugün zaten talep edildiyse null.
/// 7. slot (index 6) büyük ödül + telafi kalkanı kazandırır.
/// Dönen: (verilen para, slot indeksi).
(int, int)? claimCalendar(SaveState s, int today) {
  if (s.calendarClaimDay == today) return null;
  final slot = s.calendarIndex % 7;
  s.calendarClaimDay = today;
  s.calendarIndex = (slot + 1) % 7;
  if (slot == 6) s.streakShield = true;
  return (kCalendarRewards[slot], slot);
}

/* ---- PB-035 B3: Kabus Kulesi (saf mantık) ---- */

/// Haftanın kalan hakları — hafta değişince sayaç sıfırlanır (yan etki yok:
/// okuma çağrısı kaydı güncellemez; consume ayrı).
int nightmareTriesLeft(SaveState s, int week) {
  if (s.nightmareWeek != week) return 3;
  return (3 - s.nightmareTries).clamp(0, 3);
}

/// Bir hak tüket (hafta değişimini de kalıcılaştırır).
void consumeNightmareTry(SaveState s, int week) {
  if (s.nightmareWeek != week) {
    s.nightmareWeek = week;
    s.nightmareTries = 0;
  }
  s.nightmareTries = (s.nightmareTries + 1).clamp(0, 3);
}

/// Kabus sonucu: kayıp CEZASIZ (hiçbir şey düşülmez); kazanım rekoru günceller.
void recordNightmare(SaveState s, int week, int blocks, bool reached) {
  if (s.nightmareWeek != week) {
    s.nightmareWeek = week;
    s.nightmareTries = 0;
  }
  if (reached && blocks > s.nightmareBest) s.nightmareBest = blocks;
}

/// Defter sayacı: eksik parça = toplanmamış kalıntı (10 dünya kalıntısı).
int missingRelicPieces(SaveState s) {
  var missing = 0;
  for (final r in kRelics) {
    if (s.relics[r.stage.toString()] != true) missing++;
  }
  return missing;
}

SaveState createSave() => SaveState();

SaveState load(KeyValueStorage storage) {
  try {
    final raw = storage.getString(kSaveKey);
    if (raw != null) {
      final s = SaveState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (s.v == 2 || s.v == 3) {
        // v2 kayıt → v3 alanları varsayılanla açılır (migrasyon geriye dönük)
        return s;
      }
    }
    return createSave();
  } catch (_) {
    return createSave();
  }
}

void save(SaveState state, KeyValueStorage storage) {
  try {
    storage.setString(kSaveKey, state.encode()).ignore(); // hata asla yukarı sıçramaz
  } catch (_) {}
}

int totalStars(SaveState state) {
  var t = 0;
  for (final e in state.completed.values) {
    t += e['stars'] ?? 0;
  }
  return t;
}

/// Bölüm açık mı: önceki bölüm bitirilmiş VE dünya yeterli yıldızda mı
/// (aynı dünyadaysa yıldız şartı aranmaz — progress.js isUnlocked birebir).
bool isUnlocked(SaveState state, int i, LevelDef lv) {
  // PB-036 geliştirici modu: bayrak açıkken tüm bölümler (yalnız debug UI açar;
  // kayıt alanı v3 üst-kümeleri — normal oyuncuda hep false, C-002 etkilenmez)
  if (state.devUnlockAll) return true;
  if (i <= 0) return true;
  final prev = state.completed[i - 1];
  if (prev != null) {
    final need = requiredStars(lv.stage);
    return totalStars(state) >= need || lv.stage == stageOf(i - 1);
  }
  return false;
}

/// Bölüm bitirilince ödül çıktısı.
class CompleteResult {
  int coins;
  int stars;
  bool firstClear;
  bool boxDropped;
  CompleteResult({this.coins = 0, this.stars = 0, this.firstClear = false, this.boxDropped = false});
}

/// Bölüm bitirildi: ödülleri hesapla ve uygula (progress.js completeLevel birebir).
/// res: {blocks, perfects, reached, stars?}
CompleteResult completeLevel(SaveState state, LevelDef def,
    {required int blocks, required int perfects, required bool reached, int? stars}) {
  state.totalBlocks += blocks;
  state.totalPerfect += perfects;

  final out = CompleteResult();

  if (def.endless) {
    if (blocks > state.best) state.best = blocks;
    return out;
  }

  if (def.daily) {
    out.coins = reached ? (def.coins + perfects * 2) : 2;
    state.coins += out.coins;
    return out;
  }

  if (reached) state.levelsDone += 1;

  if (!reached) {
    out.coins = 2; // teselli: her deneme biraz kazandırır
    state.coins += out.coins;
    return out;
  }

  final st = (stars == null || stars == 0) ? 1 : stars;
  out.stars = st;
  final first = state.completed[def.i] == null;
  out.firstClear = first;
  final prev = state.completed[def.i];
  if (first || st > (prev?['stars'] ?? 0)) {
    state.completed[def.i] = {
      'stars': first ? st : (st > (prev?['stars'] ?? 0) ? st : prev!['stars']!),
      'best': first ? blocks : (blocks > (prev?['best'] ?? 0) ? blocks : prev!['best']!),
    };
  }

  final mult = def.modifier == 'altin' ? 2 : 1;
  out.coins = (def.coins + st * 5 + perfects * 2) * mult;
  state.coins += out.coins;

  if (def.box && state.boxes[def.i.toString()] != true) {
    state.boxes[def.i.toString()] = true;
    out.boxDropped = true;
  }
  return out;
}

/// Sürpriz kutusu sonucu.
class BoxResult {
  final String type; // 'skin' | 'coins'
  final Skin? skin;
  final int? amount;
  BoxResult({required this.type, this.skin, this.amount});
}

/// Sürpriz kutusu: para ya da yeni görünüm (progress.js openBox birebir).
BoxResult openBox(SaveState state, LevelDef def, double Function()? rand) {
  final r = rand != null ? rand() : _random();
  final owned = state.skins.toSet();
  final locked = kSkins.where((s) => s.price > 0 && !owned.contains(s.id)).toList();

  if (locked.isNotEmpty && r < 0.35) {
    final s = locked[(((rand != null ? rand() : _random()) * locked.length).floor())];
    state.skins.add(s.id);
    return BoxResult(type: 'skin', skin: s);
  }
  final amount = 30 + ((def.num > 0 ? def.num : 1) * 1.5).round() + ((rand != null ? rand() : _random()) * 40).round();
  state.coins += amount;
  return BoxResult(type: 'coins', amount: amount);
}

final math.Random _rng = math.Random();

double _random() => _rng.nextDouble(); // testler openBox'a rand enjekte eder

/* ------------------------- Günlük görevler ------------------------- */

class MissionTemplate {
  final String stat;
  final String label;
  final int base;
  final int step;
  final int reward;
  const MissionTemplate(this.stat, this.label, this.base, this.step, this.reward);
}

const List<MissionTemplate> kMissionTemplates = [
  MissionTemplate('totalPerfect', 'mükemmel bırakış', 10, 5, 30),
  MissionTemplate('totalBlocks', 'blok diz', 60, 20, 25),
  MissionTemplate('levelsDone', 'bölüm bitir', 2, 1, 45),
];

int dayOf(DateTime now) => now.millisecondsSinceEpoch ~/ 86400000;

/// Gün değiştiyse görevleri yenile (başlangıç değerleri anlık toplamlardan).
Map<String, dynamic> ensureMissions(SaveState state, DateTime now) {
  final day = dayOf(now);
  final m = state.missions;
  if (m != null && m['day'] == day) return m;
  final items = <Map<String, dynamic>>[];
  for (var idx = 0; idx < kMissionTemplates.length; idx++) {
    final t = kMissionTemplates[idx];
    items.add({
      'stat': t.stat,
      'label': t.label,
      'goal': t.base + ((day + idx) % 3) * t.step,
      'reward': t.reward,
      'base': _statOf(state, t.stat),
      'claimed': false,
    });
  }
  state.missions = {'day': day, 'items': items};
  return state.missions!;
}

int _statOf(SaveState state, String stat) {
  switch (stat) {
    case 'totalPerfect':
      return state.totalPerfect;
    case 'totalBlocks':
      return state.totalBlocks;
    case 'levelsDone':
      return state.levelsDone;
  }
  return 0;
}

List<Map<String, dynamic>> missionItems(SaveState state) =>
    (state.missions?['items'] as List? ?? []).cast<Map<String, dynamic>>();

int missionProgress(SaveState state, Map<String, dynamic> item) {
  final v = _statOf(state, item['stat'] as String);
  final base = (item['base'] as num?)?.toInt() ?? 0;
  return (v - base) > 0 ? (v - base) : 0;
}

int? claimMission(SaveState state, Map<String, dynamic> item) {
  if (item['claimed'] == true) return null;
  if (missionProgress(state, item) < (item['goal'] as int)) return null;
  item['claimed'] = true;
  final reward = item['reward'] as int;
  state.coins += reward;
  return reward;
}

/* ---------------- Dünya tamamlama töreni + sürpriz ödüller ---------------- */

bool isWorldComplete(SaveState state, int stage) {
  final start = stage * kLevelsPerStage;
  for (var k = 0; k < kLevelsPerStage; k++) {
    if (state.completed[start + k] == null) return false;
  }
  return true;
}

int worldBonus(int stage) => 50 + stage * 25;

/// Kalıntı: dünya başına bir kez, kalıcı yadigâr.
Relic? awardRelic(SaveState state, int stage) {
  if (state.relics[stage.toString()] == true) return null;
  final r = relicFor(stage);
  if (r == null) return null;
  state.relics[stage.toString()] = true;
  return r;
}

/// Dünya aydınlanır: bir kez bonus + kalıntı ver.
int? applyWorldComplete(SaveState state, int stage) {
  if (state.worldsCelebrated[stage.toString()] == true) return null;
  state.worldsCelebrated[stage.toString()] = true;
  awardRelic(state, stage);
  final c = worldBonus(stage);
  state.coins += c;
  return c;
}

/* ---------------- Günlük meydan okuma + skor tahtası ---------------- */

int recordDaily(SaveState state, int day, int blocks) {
  if (state.daily['day'] != day) {
    state.daily = {'day': day, 'best': 0};
  }
  if (blocks > (state.daily['best'] ?? 0)) state.daily['best'] = blocks;
  // PB-020: rekor yayı — günün en iyisi, son 7 gün tutulur
  final prev = state.dailyHistory[day] ?? 0;
  state.dailyHistory[day] = blocks > prev ? blocks : prev;
  if (state.dailyHistory.length > 7) {
    final keys = state.dailyHistory.keys.toList()..sort();
    while (state.dailyHistory.length > 7) {
      state.dailyHistory.remove(keys.removeAt(0));
    }
  }
  return state.daily['best']!;
}

/// PB-020: bugünün tahtasında geçilen rakip sayısı (0..9).
int beatenCount(SaveState state) {
  final day = state.daily['day'] ?? -1;
  final best = state.daily['best'] ?? 0;
  if (day < 0 || best <= 0) return 0;
  return rivalsFor(day, best).where((r) => r.score < best).length;
}

/// PB-020: ardışık günlük serisi (son günden geriye).
int dailyStreak(SaveState state) {
  final days = state.dailyHistory.keys.toList()..sort();
  if (days.isEmpty) return 0;
  var streak = 1;
  for (var i = days.length - 1; i > 0; i--) {
    if (days[i] - days[i - 1] == 1) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

/// PB-020: 7 gün üst üste günlük → sezonluk rozet.
bool weeklyBadge(SaveState state) => dailyStreak(state) >= 7;

/// Günün skor tahtası rakipleri: deterministik LCG (progress.js rivalsFor birebir).
class Rival {
  final String name;
  final int score;
  const Rival(this.name, this.score);
}

const List<String> _rivalNames = [
  'Kaptan', 'Mıstık', 'NeonRıza', 'Zeynep', 'BlokUsta', 'Ayşe', 'Pixel', 'Mert', 'Luna',
];

List<Rival> rivalsFor(int day, int playerScore) {
  var seed = ((day.toInt()) * 2654435761) % 2147483647;
  if (seed <= 0) seed += 2147483646;
  double rnd() {
    seed = (seed * 48271) % 2147483647;
    return seed / 2147483647;
  }

  final out = <Rival>[];
  for (var i = 0; i < _rivalNames.length; i++) {
    final base = (playerScore != 0 ? playerScore : 10) * (0.55 + rnd() * 0.95);
    final s = base + (rnd() - 0.5) * 6;
    final score = (s >= 3 ? s : 3).round();
    out.add(Rival(_rivalNames[i], score));
  }
  return out;
}

int applySurpriseCoins(SaveState state, Surprise? surprise) {
  if (surprise != null && surprise.effect == 'coinStart') {
    state.coins += surprise.coins;
    return surprise.coins;
  }
  return 0;
}

/* ---------------------------- Görünümler ---------------------------- */

class BuyResult {
  final bool ok;
  final String? reason; // 'owned' | 'coins'
  final Skin? skin;
  BuyResult({required this.ok, this.reason, this.skin});
}

BuyResult buySkin(SaveState state, String id) {
  final s = skinById(id);
  if (state.skins.contains(id)) return BuyResult(ok: false, reason: 'owned');
  if (state.coins < s.price) return BuyResult(ok: false, reason: 'coins');
  state.coins -= s.price;
  state.skins.add(id);
  state.activeSkin = id;
  return BuyResult(ok: true, skin: s);
}

bool equipSkin(SaveState state, String id) {
  if (!state.skins.contains(id)) return false;
  state.activeSkin = id;
  return true;
}
