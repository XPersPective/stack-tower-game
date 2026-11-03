/// Stack Tower Game — bölüm ve tema tanımları (saf katman, test edilebilir).
/// `reference/www/levels.js` birebir portu (SPEC §2): 10 dünya × 15 bölüm =
/// 150 bölüm + günlük meydan okuma + serbest mod. Matematik değiştirilmez.
library;

import 'dart:math' as math;

import '../theme/tokens.dart' show WorldTheme, kThemes;

const int kStageCount = 10;
const int kLevelsPerStage = 15;
const int kLevelCount = kStageCount * kLevelsPerStage;

/// Bölüm türleri: her biri farklı zorluk/sürpriz (levels.js MODIFIERS birebir).
class Modifier {
  final String id;
  final String name;
  final String icon;
  final String hint;
  const Modifier(this.id, this.name, this.icon, this.hint);
}

const Map<String, Modifier> kModifiers = {
  'normal': Modifier('normal', 'KLASİK', '▦', 'Blok tam üstüne düşsün.'),
  'ruzgar': Modifier('ruzgar', 'RÜZGAR', '≋', 'Rüzgar bloğu sağa sola savuruyor!'),
  'hizli': Modifier('hizli', 'HIZLI', '⚡', 'Blok çok hızlı gidiyor, refleks zamanı!'),
  'karanlik': Modifier('karanlik', 'KARANLIK', '◐', 'Karanlık! Sadece kuleyi görebiliyorsun.'),
  'altin': Modifier('altin', 'ALTIN', '★', 'Altın bölüm: her mükemmel bırakış 2 kat para!'),
  'yavas': Modifier('yavas', 'HUZUR', '☽', 'Sakin bir bölüm: nefes al, ritmini bul. Ödül yüksek!'),
  'deprem': Modifier('deprem', 'DEPREM', '〰', 'Zemin sarsılıyor! Sarsıntı anında bırakma.'),
  'akan': Modifier('akan', 'AKAN', '≈', 'Blok hızı dalgalanıyor — zamanlamayı kestiremezsin.'),
  'patron': Modifier('patron', 'PATRON', '♛', 'Uzun ve hızlı bölüm. Seriye devam!'),
};

int stageOf(int i) => i ~/ kLevelsPerStage;
int indexInStage(int i) => i % kLevelsPerStage;

/// Bir dünya, yeterli yıldız toplanmadan kilitli kalır (yol haritası kapısı).
int requiredStars(int stage) => stage * 10;

/// Sürpriz kutusu olan bölümler (7'nin katları).
bool isBoxLevel(int i) => (i + 1) % 7 == 0;

/// Bölüm tanımı — levelDef(i) çıktısı (levels.js ile birebir).
class LevelDef {
  final int i;
  final int stage;
  final int idx;
  final int num;
  final WorldTheme theme;
  final int target;
  final double speed;
  final int tol;
  final String modifier;
  final int coins;
  final bool box;
  final String name;
  final bool daily;
  final bool endless;
  final bool nightmare; // PB-035 B3: haftalık Kabus Kulesi (stack tabanlı etkinlik)

  const LevelDef({
    required this.i,
    required this.stage,
    required this.idx,
    required this.num,
    required this.theme,
    required this.target,
    required this.speed,
    required this.tol,
    required this.modifier,
    required this.coins,
    required this.box,
    required this.name,
    this.daily = false,
    this.endless = false,
    this.nightmare = false,
  });
}

/// 0 tabanlı global indeksten bölüm tanımı (levels.js levelDef birebir).
LevelDef levelDef(int i) {
  final stage = stageOf(i);
  final idx = indexInStage(i);
  final theme = kThemes[stage < kThemes.length ? stage : kThemes.length - 1];

  final target = 8 + (i * 0.16).round() + (idx == kLevelsPerStage - 1 ? 6 : 0);
  var speed = (0.9 + i * 0.028) < 3.0 ? (0.9 + i * 0.028) : 3.0;
  var tol = stage >= 4 ? 4 : (stage >= 2 ? 5 : 6);

  var modifier = 'normal';
  if (idx == kLevelsPerStage - 1) {
    modifier = 'patron';
  } else if (idx == 4 || idx == 9) {
    modifier = 'altin';
  } else if (stage >= 1 && idx % 7 == 3) {
    modifier = 'ruzgar';
  } else if (stage >= 2 && idx % 7 == 5) {
    modifier = 'hizli';
  } else if (stage >= 3 && idx % 7 == 6) {
    modifier = 'karanlik';
  } else if (stage >= 4 && idx % 7 == 2) {
    modifier = 'yavas';
  } else if (stage >= 6 && idx % 7 == 4) {
    modifier = 'deprem';
  } else if (stage >= 8 && idx % 7 == 1) {
    modifier = 'akan';
  }

  if (modifier == 'hizli') speed = (speed * 1.45) < 3.2 ? (speed * 1.45) : 3.2;
  if (modifier == 'ruzgar') speed = (speed * 1.1) < 3.2 ? (speed * 1.1) : 3.2;
  if (modifier == 'patron') speed = (speed * 1.3) < 3.4 ? (speed * 1.3) : 3.4;
  if (modifier == 'yavas') {
    speed = speed * 0.6;
    tol = 7;
  }

  var coins = 10 + (i * 0.5).round();
  if (modifier == 'altin') coins += 25;
  if (modifier == 'patron') coins += 30;
  if (modifier == 'yavas') coins += 15;
  if (modifier == 'deprem') coins += 20;
  if (modifier == 'akan') coins += 20;
  if (isBoxLevel(i)) coins += 10;

  return LevelDef(
    i: i,
    stage: stage,
    idx: idx,
    num: i + 1,
    theme: theme,
    target: target,
    speed: speed,
    tol: tol,
    modifier: modifier,
    coins: coins,
    box: isBoxLevel(i),
    name: '${theme.name} ${idx + 1}',
  );
}

/// Yıldız: hedefe ulaş = 1; mükemmel oranına göre 2 ve 3 (levels.js starsFor).
int starsFor(int perfects, int target) {
  if (target <= 0) return 1;
  final s2 = (target * 0.3).ceil();
  final s3 = (target * 0.6).ceil();
  if (perfects >= s3) return 3;
  if (perfects >= s2) return 2;
  return 1;
}

/// Günlük meydan okuma: herkes için aynı, güne göre tohumlu (levels.js dailyDef).
LevelDef dailyDef(int day) {
  final d = day.toInt();
  const mods = ['normal', 'ruzgar', 'hizli', 'karanlik', 'altin', 'deprem'];
  final stage = d % kThemes.length;
  final target = 12 + (d % 5) * 2;
  final speedRaw = 1.2 + (d % 7) * 0.2;
  final speed = speedRaw < 2.6 ? speedRaw : 2.6;
  return LevelDef(
    i: -2,
    stage: stage,
    idx: 0,
    num: 0,
    theme: kThemes[stage],
    target: target,
    speed: speed,
    tol: 5,
    modifier: mods[d % mods.length],
    coins: 60 + (d % 5) * 10,
    box: false,
    name: 'GÜNLÜK MEYDAN OKUMA',
    daily: true,
  );
}

/// Hafta indeksi (7 günlük) — Kabus Kulesi tohumu (PB-035 B3).
int weekOf(int day) => day ~/ 7;

/// KABUS KULESİ (PB-035 B3): haftalık, 3 haklı, kayıp cezasız bonus kule.
/// Hafta tohumuyla zorlaşır; HER ZAMAN stack türü. Ödül oturumda özel işlenir.
LevelDef nightmareDef(int week) {
  final target = 14 + (week % 3) * 2;
  final speed = math.min(3.4, 1.9 + (week % 5) * 0.18);
  const tol = 4;
  final modifier = const ['hizli', 'karanlik', 'ruzgar'][week % 3];
  return LevelDef(
    i: -2 - (week % 1000) * 1000, // çakışmasın: twistedengelle + completed'a düşmez
    stage: 9,
    idx: 0,
    num: 0,
    theme: kThemes[9], // SON KULE · ZİRVE — karanlık atmosfer
    target: target,
    speed: speed,
    tol: tol,
    modifier: modifier,
    coins: 40,
    box: false,
    name: 'KABUS KULESİ',
    nightmare: true,
  );
}

/// Serbest mod (sonsuz kule) tanımı.
LevelDef endlessDef([WorldTheme? theme]) => LevelDef(
      i: -1,
      stage: 0,
      idx: 0,
      num: 0,
      theme: theme ?? kThemes[0],
      target: 0,
      speed: 1.05,
      tol: 6,
      modifier: 'normal',
      coins: 0,
      box: false,
      name: 'SERBEST MOD',
      endless: true,
    );

/// Her dünyanın hikâyesi — konsept: yükseldikçe göğü aydınlatıyorsun.
const List<String> kWorldLore = [
  'Neon Şehir uyanıyor… her blok bir ışık, her kule bir umut.',
  'Bio Orman fısıldıyor: kökler derine, sen zirveye.',
  'Altın Çölde zaman kumla akar; sabır altını doğurur.',
  'Buz Dünyası sessiz… sessizlikte ustalık gizli.',
  'Uzayda yerçekimi yok; yalnızca niyetin var.',
  'Volkanın kalbinde son perde: kule değil, sen yükseliyorsun.',
  'Bulut Şehir gökyüzünde duruyor; düşmek de bir yükseliştir.',
  'Derin Denizde ışık az, cesaret çok. Nefesini tut ve diz.',
  'Kristal Mağara seni yansıtır: her hata, her mükemmellik sendedir.',
  'Son Kule · Zirve: bütün dünyalar burada birleşir. Hikâyenin sonu değil, doruğu.',
];

/// Bölüm önizlemesinde gösterilen kısa dünya fısıltısı.
const List<String> kWorldTeaser = [
  'Neon yağmuru camda ritim tutuyor. Kule bu gece uyanık.',
  'Köklerin arasında bir şey nefes alıyor. Adımlarını yavaş at.',
  'Kumun altında bir kapı var. Anahtar: sabır.',
  'Sessizlik burada bir dil. Kule onu dinliyor.',
  'Yerçekimi yok; yalnızca niyetin var.',
  'Dağın kalbi atıyor. Her blok bir nabız.',
  'Şehir bulutların üstünde süzülüyor. Düşmek serbest.',
  'Derinlerde bir ışık yanıp sönüyor. Nefesini tut.',
  'Her yüzey seni geri yansıtıyor. Hangisi gerçek?',
  'Bütün yollar burada bitiyor. Ama kule hâlâ yükseliyor.',
];

/// Gizem cümleleri: bölümün sürprizini ele vermez, merak uyandırır.
const List<String> kMysteries = [
  'Bu bölümde bir şey saklı. Açığa çıkarmak sana kalmış.',
  'Fısıltılar doğru söylemiyor. Dikkatli dinle.',
  'Yıldızlar bu gece farklı hizalanmış…',
  'Kulenin gölgesinde bir sürpriz bekliyor.',
  'Bir şey eksik. Belki de bilmen gereken tek şey bu.',
  'Bu dünya sırrını kolay vermiyor.',
];

String mysteryFor(int i) {
  final k = ((i.toInt()) * 7 + 3).abs() % kMysteries.length;
  return kMysteries[k];
}

/// Sürpriz an tanımı.
class Surprise {
  final String id;
  final String name;
  final String desc;
  final String effect;
  final int coins;
  const Surprise(this.id, this.name, this.desc, this.effect, [this.coins = 0]);
}

const List<Surprise> _surprisePool = [
  Surprise('coinStart', 'ŞANSLI AN', '+20 madeni para hesabında!', 'coinStart', 20),
  Surprise('doubleCoins', 'ALTIN RUH', 'Bu bölümde tüm ödüller 2 kat!', 'doubleCoins'),
  Surprise('shieldUp', 'ÇİFT KALKAN', 'Bu bölümde 2 kalkanın var!', 'shieldUp'),
];

/// ~%25 bölümde deterministik olarak bir sürpriz düşer (levels.js surpriseFor).
Surprise? surpriseFor(int i, [int day = 0]) {
  if (i < 0) return null;
  final d = day;
  if ((i + d) % 4 != 0) return null;
  return _surprisePool[(i + d) % _surprisePool.length];
}

/* ================= BÖLÜM İMZASI (PB-033 — sunum çeşitliliği) ================= */

/// Bölümün görsel imzası: aynı dünya içindeki 15 bölümün paleti/gökyüzü/silueti
/// birbirinden farklı görünsün diye deterministik sunum sapmaları. Oyun
/// matematiğine (C-002) dokunmaz — yalnız render parametreleridir.
class LevelSignature {
  final double hueShift; // tema renginde kayma (derece, ±13)
  final int skyPhase; // gökyüzü/paralaks fazı 0..3
  final int silVariant; // siluet dizilim varyantı 0..2
  final int shape; // blok şekil varyantı 0..3 (YALNIZ GÖRSEL — C-002 dışı):
  // 0 = yuvarlak köşe (klasik) · 1 = silindir · 2 = altıgen · 3 = kama (üçgen üst)
  const LevelSignature({
    required this.hueShift,
    required this.skyPhase,
    required this.silVariant,
    this.shape = 0,
  });
}

/// [i] indeksli bölümün imzası — tohumlu ve deterministik (aynı bölüm her
/// açılışta aynı görsel deneyimi verir; kayıt şemasına dokunulmaz).
LevelSignature levelSignature(int i) {
  final r = math.Random(0x51A6 + i * 7919);
  return LevelSignature(
    hueShift: (r.nextDouble() - 0.5) * 26,
    skyPhase: r.nextInt(4),
    silVariant: r.nextInt(3),
    shape: r.nextInt(4), // PB-036: tuğla oyununa sıkışma — her bölüm farklı form
  );
}

/// Bölüm sonu şöleni stilleri (DNA raporu B1 — imza final rotasyonu).
enum FinaleStyle { konfeti, meteor, kus, aurora }

/// 4 final tipinin rotasyonu: ardışık bölümlerde aynı final tekrarlanmaz.
FinaleStyle finaleFor(int i) {
  const order = FinaleStyle.values;
  return order[i % order.length];
}

/* ===================== ANTLOJİ: oyun türleri (ADR-008) ===================== */

/// Bölümün OYUN TÜRÜ — her bölüm farklı bir oyun olabilir (DESIGN-V2 §3.1).
/// PB-041: antoloji 11→13 türe büyüdü (colorGate/neonClean/darkHole) —
/// dağıtım yasası C-020 korunur.
enum GameKind {
  stack,
  catcher,
  ring,
  launch,
  merge,
  path,
  sort,
  balance,
  defend,
  rhythm,
  colorGate,
  neonClean,
  darkHole,
  hexaMerge, // PB-042: HEXA NEON (2048 düşüş)
  pinRoute, // PB-042: PİN SIRRI (yönlendirme)
  flowLink, // PB-042: NEON AKIŞ (flow)
  timeFreeze, // PB-043: ZAMAN KIRICI (dondurma)
  gravityFlip, // PB-043: YERÇEKİMİ KAPISI (ters dönme)
  katamariRoll, // PB-043: KATAMARİ ROLL (büyüme)
  crystalCut, // PB-044: KRİSTAL KESİK (kesme)
  wreckingCrew, // PB-044: YIKIM EKİBİ (yıkım)
}

class KindSpec {
  final GameKind kind;
  final String name;
  final String icon;
  final String hint;
  final int accentHue;
  const KindSpec(this.kind, this.name, this.icon, this.hint, this.accentHue);
}

const Map<GameKind, KindSpec> kKindSpecs = {
  GameKind.stack: KindSpec(GameKind.stack, 'KULE', '▦', 'Süzülen bloğu tam üstüne bırak.', 200),
  GameKind.catcher: KindSpec(GameKind.catcher, 'YILDIZ AVCISI', '✦', 'Düşen yıldızları yakala, bombalardan kaç!', 48),
  GameKind.ring: KindSpec(GameKind.ring, 'HALKA', '◎', 'Dönen işaretçi hedef dilimdeyken dokun.', 280),
  GameKind.launch: KindSpec(GameKind.launch, 'FIRLAT', '➹', 'Nişan dönüyor — doğru anda bırak.', 12),
  GameKind.merge: KindSpec(GameKind.merge, 'BİRLEŞTİR', '⬢', 'Aynı parçaları birleştir, büyüt.', 150),
  GameKind.path: KindSpec(GameKind.path, 'TEK ÇİZGİ', '〰', 'Tüm düğümleri tek çizgide gez.', 190),
  GameKind.sort: KindSpec(GameKind.sort, 'SIRALA', '⬒', 'Renkleri kendi kutusuna taşı.', 320),
  GameKind.balance: KindSpec(GameKind.balance, 'DENGE', '⚖', 'Düşmeden önce dengeyi koru.', 95),
  GameKind.defend: KindSpec(GameKind.defend, 'SAVUN', '⛨', 'Dalga geldiğinde kalkanı kaldır.', 220),
  GameKind.rhythm: KindSpec(GameKind.rhythm, 'RİTİM', '♪', 'Vuruşlarda dokun, komboyu bırakma.', 340),
  GameKind.colorGate: KindSpec(GameKind.colorGate, 'RENK KAPI', '◐', 'Pencere renginle eşleşince zıpla; perde rengini değiştirsin!', 288),
  GameKind.neonClean: KindSpec(GameKind.neonClean, 'NEON TEMİZLİK', '⧉', 'Parçayı seç, tahtaya koy; tam satır veya sütunu patlat!', 190),
  GameKind.darkHole: KindSpec(GameKind.darkHole, 'UZUN KARANLIK', '⬤', 'Deliği yönlendir, neon parçaları yut; karanlığa dokunma!', 262),
  GameKind.hexaMerge: KindSpec(GameKind.hexaMerge, 'HEXA NEON', '⬡', 'Sayılı altıgeni sütuna düşür; aynı sayılar katlansın!', 168),
  GameKind.pinRoute: KindSpec(GameKind.pinRoute, 'PİN SIRRI', '⌇', 'Pimi çek; altını huniye, karanlığı çukura yönlendir!', 46),
  GameKind.flowLink: KindSpec(GameKind.flowLink, 'NEON AKIŞ', '≋', 'Uçları seç, komşuya dokuyarak akışı bağla!', 202),
  GameKind.timeFreeze: KindSpec(GameKind.timeFreeze, 'ZAMAN KIRICI', '❄', 'Basılı tut — zaman donsun, gemiyi mermilerden süz!', 195),
  GameKind.gravityFlip: KindSpec(GameKind.gravityFlip, 'YERÇEKİMİ KAPISI', '⇅', 'Dokun — yerçekimi ters dönsün, engellerden kaç!', 12),
  GameKind.katamariRoll: KindSpec(GameKind.katamariRoll, 'KATAMARİ ROLL', '●', 'Yuvarlan, küçükleri yut, büyü; büyüklere dokunma!', 165),
  GameKind.crystalCut: KindSpec(GameKind.crystalCut, 'KRİSTAL KESİK', '◈', 'Işık kesik hedef dilime gelince dokun — tam merkez MÜKEMMEL!', 288),
  GameKind.wreckingCrew: KindSpec(GameKind.wreckingCrew, 'YIKIM EKİBİ', '⚒', 'Nişan dönerken dokun — kuleyi baştan aşağı dök!', 20),
};

/// İlk 5 bölüm = 5 FARKLI tür (hook — C-020).
const List<GameKind> kFirstFiveKinds = [
  GameKind.catcher, // 1: anında eğlence, toplama coşkusu
  GameKind.ring, // 2: tam isabet hazzı
  GameKind.stack, // 3: klasik kimlik
  GameKind.launch, // 4: fizik şaşırtması
  GameKind.merge, // 5: büyüme tatmini
];

/// Antoloji döngüsü (ilk-5 sonrası) — PB-041 dalgası: colorGate/neonClean/darkHole.
const List<GameKind> kKindCycle = [
  GameKind.stack, GameKind.catcher, GameKind.ring, GameKind.launch, GameKind.merge,
  GameKind.path, GameKind.sort, GameKind.balance, GameKind.defend, GameKind.rhythm,
  GameKind.colorGate, GameKind.neonClean, GameKind.darkHole,
  GameKind.hexaMerge, GameKind.pinRoute, GameKind.flowLink, GameKind.timeFreeze,
  GameKind.gravityFlip, GameKind.katamariRoll,
  GameKind.crystalCut, GameKind.wreckingCrew,
  // STACK kimlik oyunudur: antolojide seyrelmesin diye çift slot (C-003)
  GameKind.stack,
];

/// Dünya patronu imza türleri (stage % uzunluk).
const List<GameKind> kBossKinds = [
  GameKind.ring, GameKind.defend, GameKind.balance, GameKind.rhythm, GameKind.launch,
  GameKind.catcher, GameKind.sort, GameKind.path, GameKind.merge, GameKind.stack,
];

/// Dağıtım yasası (ADR-008 / C-020):
/// - i<0 (günlük/serbest) → stack
/// - i<5 → kFirstFiveKinds[i]
/// - dünya patronu (idx==14) → o dünyanın imza türü (stage'e göre)
/// - aksi: antoloji döngüsü; ardışık aynı tür ≤1 (patron sınırı dâhil)
GameKind kindFor(int i) {
  if (i < 0) return GameKind.stack;
  if (i < kFirstFiveKinds.length) return kFirstFiveKinds[i];
  final stage = stageOf(i);
  final idx = indexInStage(i);
  if (idx == kLevelsPerStage - 1) {
    // patron: dünya imza türü (tema atmosferine uygun)
    return kBossKinds[stage % kBossKinds.length];
  }
  var n = (i - kFirstFiveKinds.length) % kKindCycle.length;
  var k = kKindCycle[n];
  // ardışık tekrar koruması — patronu tak eden bölüm de çakışmasın (PB-041)
  final bossAhead = idx == kLevelsPerStage - 2
      ? kBossKinds[stage % kBossKinds.length]
      : null;
  while (k == kindFor(i - 1) || (bossAhead != null && k == bossAhead)) {
    n = (n + 1) % kKindCycle.length;
    k = kKindCycle[n];
  }
  return k;
}

/// PB-030: tür başına cömertlik bonusu (yalnız KAZANILAN bölümde ödenir).
/// C-019: her 4-5 bölümde 1 satın alma gücü — stack dışı türler taban 2,
/// 3+ mükemmelde +1. Stack'in bonusu twist paralarıdır (çift ödeme olmasın).
int kindBonus(GameKind kind, {required int perfects}) {
  if (kind == GameKind.stack) return 0;
  return perfects >= 3 ? 3 : 2;
}

/// LevelDef'e tür ekleyen yardımcı (def.kind).
extension LevelDefKind on LevelDef {
  GameKind get kind => (daily || endless) ? GameKind.stack : kindFor(i);
  KindSpec get kindSpec => kKindSpecs[kind]!;
}
