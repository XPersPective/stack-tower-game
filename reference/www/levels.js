/* ============================================================
   NEON KULE — Bölüm ve tema tanımları (saf katman, test edilebilir)
   10 dünya × 15 bölüm = 150 bölüm + serbest mod.
   ============================================================ */
(function (root) {
  'use strict';

  var STAGE_COUNT = 10;
  var LEVELS_PER_STAGE = 15;

  /* Dünyalar: renk paleti, arka plan, hava durumu efekti (sürpriz görsellik) */
  var THEMES = [
    { id: 'sehir',  name: 'NEON ŞEHİR', hues: [210, 268, 322], bg: ['#0c0a20', '#1e1046'], glow: 268, weather: 'stars',    silhouette: 'city'   },
    { id: 'orman',  name: 'BİYO ORMAN', hues: [130, 160, 95],  bg: ['#04140d', '#0d2c1a'], glow: 150, weather: 'leaves',  silhouette: 'trees'  },
    { id: 'col',    name: 'ALTIN ÇÖL',  hues: [35, 48, 22],    bg: ['#1c0f04', '#3a2410'], glow: 35,  weather: 'sand',    silhouette: 'dunes'  },
    { id: 'buz',    name: 'BUZ DÜNYA',  hues: [195, 205, 178], bg: ['#04121e', '#0d2f42'], glow: 195, weather: 'snow',    silhouette: 'ice'    },
    { id: 'uzay',   name: 'UZAY',       hues: [282, 300, 255], bg: ['#08041a', '#1a0b36'], glow: 290, weather: 'stars',   silhouette: 'rocks'  },
    { id: 'volkan', name: 'VOLKAN',     hues: [4, 25, 350],    bg: ['#1c0404', '#3a1208'], glow: 12,  weather: 'embers',  silhouette: 'volcano'},
    { id: 'bulut',   name: 'BULUT ŞEHİR', hues: [205, 218, 190], bg: ['#0a1430', '#20406e'], glow: 212, weather: 'snow',    silhouette: 'dunes'},
    { id: 'deniz',   name: 'DERİN DENİZ', hues: [188, 198, 168], bg: ['#02101c', '#062a3e'], glow: 192, weather: 'stars',   silhouette: 'trees'},
    { id: 'kristal', name: 'KRİSTAL MAĞARA', hues: [292, 262, 322], bg: ['#140a26', '#2a1450'], glow: 288, weather: 'embers', silhouette: 'volcano'},
    { id: 'zirve',   name: 'SON KULE · ZİRVE', hues: [355, 40, 200], bg: ['#160a20', '#3a1830'], glow: 340, weather: 'embers', silhouette: 'volcano'}
  ];

  /* Bölüm türleri: her biri farklı zorluk/sürpriz */
  var MODIFIERS = {
    normal:    { name: 'KLASİK',  icon: '▦', hint: 'Blok tam üstüne düşsün.' },
    ruzgar:    { name: 'RÜZGAR',  icon: '≋', hint: 'Rüzgar bloğu sağa sola savuruyor!' },
    hizli:     { name: 'HIZLI',   icon: '⚡', hint: 'Blok çok hızlı gidiyor, refleks zamanı!' },
    karanlik:  { name: 'KARANLIK',icon: '◐', hint: 'Karanlık! Sadece kuleyi görebiliyorsun.' },
    altin:     { name: 'ALTIN',   icon: '★', hint: 'Altın bölüm: her mükemmel bırakış 2 kat para!' },
    yavas:     { name: 'HUZUR',   icon: '☽', hint: 'Sakin bir bölüm: nefes al, ritmini bul. Ödül yüksek!' },
    deprem:    { name: 'DEPREM',  icon: '〰', hint: 'Zemin sarsılıyor! Sarsıntı anında bırakma.' },
    akan:      { name: 'AKAN',    icon: '≈', hint: 'Blok hızı dalgalanıyor — zamanlamayı kestiremezsin.' },
    patron:    { name: 'PATRON',  icon: '♛', hint: 'Uzun ve hızlı bölüm. Seriye devam!' }
  };

  function stageOf(i) { return Math.floor(i / LEVELS_PER_STAGE); }
  function indexInStage(i) { return i % LEVELS_PER_STAGE; }
  function levelCount() { return STAGE_COUNT * LEVELS_PER_STAGE; }

  /* Bir dünya, yeterli yıldız toplanmadan kilitli kalır (yol haritası kapısı). */
  function requiredStars(stage) { return stage * 10; }

  /* Sürpriz kutusu olan bölümler (7'nin katları) */
  function isBoxLevel(i) { return (i + 1) % 7 === 0; }

  /* 0 tabanlı global indeksten bölüm tanımı */
  function levelDef(i) {
    var stage = stageOf(i);
    var idx = indexInStage(i);
    var theme = THEMES[Math.min(stage, THEMES.length - 1)];

    var target = 8 + Math.round(i * 0.16) + (idx === LEVELS_PER_STAGE - 1 ? 6 : 0);
    var speed = Math.min(3.0, 0.9 + i * 0.028);
    var tol = stage >= 4 ? 4 : stage >= 2 ? 5 : 6;

    var modifier = 'normal';
    if (idx === LEVELS_PER_STAGE - 1) modifier = 'patron';
    else if (idx === 4 || idx === 9) modifier = 'altin';
    else if (stage >= 1 && idx % 7 === 3) modifier = 'ruzgar';
    else if (stage >= 2 && idx % 7 === 5) modifier = 'hizli';
    else if (stage >= 3 && idx % 7 === 6) modifier = 'karanlik';
    else if (stage >= 4 && idx % 7 === 2) modifier = 'yavas';
    else if (stage >= 6 && idx % 7 === 4) modifier = 'deprem';
    else if (stage >= 8 && idx % 7 === 1) modifier = 'akan';

    if (modifier === 'hizli') speed = Math.min(3.2, speed * 1.45);
    if (modifier === 'ruzgar') speed = Math.min(3.2, speed * 1.1);
    if (modifier === 'patron') speed = Math.min(3.4, speed * 1.3);
    if (modifier === 'yavas') { speed = speed * 0.6; tol = 7; }

    var coins = 10 + Math.round(i * 0.5) +
      (modifier === 'altin' ? 25 : 0) +
      (modifier === 'patron' ? 30 : 0) +
      (modifier === 'yavas' ? 15 : 0) +
      (modifier === 'deprem' ? 20 : 0) +
      (modifier === 'akan' ? 20 : 0) +
      (isBoxLevel(i) ? 10 : 0);

    return {
      i: i, stage: stage, idx: idx, num: i + 1,
      theme: theme, target: target, speed: speed, tol: tol,
      modifier: modifier, coins: coins,
      box: isBoxLevel(i),
      name: theme.name + ' ' + (idx + 1)
    };
  }

  /* Yıldız: hedefe ulaş = 1; mükemmel oranına göre 2 ve 3 */
  function starsFor(perfects, target) {
    if (target <= 0) return 1;
    var s2 = Math.ceil(target * 0.3);
    var s3 = Math.ceil(target * 0.6);
    if (perfects >= s3) return 3;
    if (perfects >= s2) return 2;
    return 1;
  }

  /* Günlük meydan okuma: herkes için aynı, güne göre tohumlu */
  function dailyDef(day) {
    var d = day | 0;
    var mods = ['normal', 'ruzgar', 'hizli', 'karanlik', 'altin', 'deprem'];
    var stage = d % THEMES.length;
    var target = 12 + (d % 5) * 2;
    var speed = Math.min(2.6, 1.2 + (d % 7) * 0.2);
    return {
      i: -2, daily: true, stage: stage, idx: 0, num: 0,
      theme: THEMES[stage], target: target, speed: speed, tol: 5,
      modifier: mods[d % mods.length],
      coins: 60 + (d % 5) * 10, box: false,
      name: 'GÜNLÜK MEYDAN OKUMA'
    };
  }

  /* Serbest mod (sonsuz kule) tanımı */
  function endlessDef(theme) {
    return {
      i: -1, stage: 0, idx: 0, num: 0,
      theme: theme || THEMES[0],
      target: 0, speed: 1.05, tol: 6, modifier: 'normal',
      coins: 0, box: false, name: 'SERBEST MOD', endless: true
    };
  }

  /* Her dünyanın hikâyesi — konsept: yükseldikçe göğü aydınlatıyorsun */
  var WORLD_LORE = [
    'Neon Şehir uyanıyor… her blok bir ışık, her kule bir umut.',
    'Bio Orman fısıldıyor: kökler derine, sen zirveye.',
    'Altın Çölde zaman kumla akar; sabır altını doğurur.',
    'Buz Dünyası sessiz… sessizlikte ustalık gizli.',
    'Uzayda yerçekimi yok; yalnızca niyetin var.',
    'Volkanın kalbinde son perde: kule değil, sen yükseliyorsun.',
    'Bulut Şehir gökyüzünde duruyor; düşmek de bir yükseliştir.',
    'Derin Denizde ışık az, cesaret çok. Nefesini tut ve diz.',
    'Kristal Mağara seni yansıtır: her hata, her mükemmellik sendedir.',
    'Son Kule · Zirve: bütün dünyalar burada birleşir. Hikâyenin sonu değil, doruğu.'
  ];

  /* Bölüm önizlemesinde gösterilen kısa dünya fısıltısı (tamamı değil — gizem) */
  var WORLD_TEASER = [
    'Neon yağmuru camda ritim tutuyor. Kule bu gece uyanık.',
    'Köklerin arasında bir şey nefes alıyor. Adımlarını yavaş at.',
    'Kumun altında bir kapı var. Anahtar: sabır.',
    'Sessizlik burada bir dil. Kule onu dinliyor.',
    'Yerçekimi yok; yalnızca niyetin var.',
    'Dağın kalbi atıyor. Her blok bir nabız.',
    'Şehir bulutların üstünde süzülüyor. Düşmek serbest.',
    'Derinlerde bir ışık yanıp sönüyor. Nefesini tut.',
    'Her yüzey seni geri yansıtıyor. Hangisi gerçek?',
    'Bütün yollar burada bitiyor. Ama kule hâlâ yükseliyor.'
  ];

  /* Gizem cümleleri: bölümün sürprizini ele vermez, merak uyandırır */
  var MYSTERIES = [
    'Bu bölümde bir şey saklı. Açığa çıkarmak sana kalmış.',
    'Fısıltılar doğru söylemiyor. Dikkatli dinle.',
    'Yıldızlar bu gece farklı hizalanmış…',
    'Kulenin gölgesinde bir sürpriz bekliyor.',
    'Bir şey eksik. Belki de bilmen gereken tek şey bu.',
    'Bu dünya sırrını kolay vermiyor.'
  ];

  function mysteryFor(i) {
    var k = Math.abs((i | 0) * 7 + 3) % MYSTERIES.length;
    return MYSTERIES[k];
  }

  /* Sürpriz an: ~%25 bölümde deterministik olarak bir sürpriz düşer */
  function surpriseFor(i, day) {
    if (i < 0) return null;
    var d = day || 0;
    if ((i + d) % 4 !== 0) return null;
    var pool = [
      { id: 'coinStart',   name: 'ŞANSLI AN',  desc: '+20 madeni para hesabında!', effect: 'coinStart', coins: 20 },
      { id: 'doubleCoins', name: 'ALTIN RUH',  desc: 'Bu bölümde tüm ödüller 2 kat!', effect: 'doubleCoins' },
      { id: 'shieldUp',    name: 'ÇİFT KALKAN',desc: 'Bu bölümde 2 kalkanın var!', effect: 'shieldUp' }
    ];
    return pool[(i + d) % pool.length];
  }

  var CORE = {
    STAGE_COUNT: STAGE_COUNT,
    LEVELS_PER_STAGE: LEVELS_PER_STAGE,
    THEMES: THEMES,
    MODIFIERS: MODIFIERS,
    stageOf: stageOf,
    indexInStage: indexInStage,
    levelCount: levelCount,
    requiredStars: requiredStars,
    isBoxLevel: isBoxLevel,
    levelDef: levelDef,
    starsFor: starsFor,
    endlessDef: endlessDef,
    WORLD_LORE: WORLD_LORE,
    WORLD_TEASER: WORLD_TEASER,
    MYSTERIES: MYSTERIES,
    mysteryFor: mysteryFor,
    surpriseFor: surpriseFor,
    dailyDef: dailyDef
  };

  if (root) root.NeonLevels = CORE;
  if (typeof module !== 'undefined' && module.exports) module.exports = CORE;
})(typeof globalThis !== 'undefined' ? globalThis : this);
