/// Stack Tower Game — bölüm ve tema tanımları (saf katman, test edilebilir).
/// `reference/www/levels.js` birebir portu (SPEC §2): 10 dünya × 15 bölüm =
/// 150 bölüm + günlük meydan okuma + serbest mod. Matematik değiştirilmez.
library;

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
