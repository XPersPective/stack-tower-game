/* ============================================================
   NEON KULE — İlerleme/ödül sistemi (saf katman, test edilebilir)
   Kayıt: yıldızlar, madeni paralar, kule görünümleri, günlük
   görevler, sürpriz kutuları. Depolama arayüzü soyutlanmıştır
   (tarayıcıda localStorage, testte bellek içi sahte).
   ============================================================ */
(function (root) {
  'use strict';

  var SAVE_KEY = 'neonkule_save_v2';
  var LEGACY_KEY = 'neonkule_best_v1';

  /* Kilitlenebilir kule görünümleri (hue: blok paletinin başlangıç rengi) */
  var SKINS = [
    { id: 'default',  name: 'NEON',        price: 0,   hue: 200 },
    { id: 'altin',    name: 'ALTIN KULE',  price: 120, hue: 45  },
    { id: 'alev',     name: 'ALEV',        price: 150, hue: 10  },
    { id: 'okyanus',  name: 'OKYANUS',     price: 160, hue: 192 },
    { id: 'orman',    name: 'YOSUN',       price: 180, hue: 130 },
    { id: 'buz',      name: 'BUZ',         price: 200, hue: 205 },
    { id: 'pembe',    name: 'SÜPERNOVA',   price: 240, hue: 322 },
    { id: 'gokkusagi',name: 'GÖKKUŞAĞI',   price: 320, hue: 0   }
  ];

  function skinById(id) {
    for (var i = 0; i < SKINS.length; i++) if (SKINS[i].id === id) return SKINS[i];
    return SKINS[0];
  }

  /* Dünya kalıntıları: her dünyayı bitirince kalıcı bir yadigâr kazanılır */
  var RELICS = [
    { stage: 0, name: 'NEON KORU',     icon: '💠', lore: 'Şehrin ilk ışığı. Hâlâ içinde bir nabız atıyor.' },
    { stage: 1, name: 'YAŞAM TOHUMU',  icon: '🌱', lore: 'Bir ormanı tek başına taşıyabilecek kadar ağır.' },
    { stage: 2, name: 'KUM SAATİ',     icon: '⏳', lore: 'İçindeki kum hiç bitmiyor; sabrı ödüllendiriyor.' },
    { stage: 3, name: 'EZELİ KRİSTAL', icon: '❄️', lore: 'Sessizliğin donmuş hâli. Dokununca bir nota çalıyor.' },
    { stage: 4, name: 'YILDIZ ÇEKİRDEĞİ', icon: '🪐', lore: 'Bir yıldızın kalbi; avucunda hafifçe titriyor.' },
    { stage: 5, name: 'MAGMA KALBİ',   icon: '🌋', lore: 'Volkanın son atışı. Sıcaklığı hiç geçmiyor.' },
    { stage: 6, name: 'GÖK YELKENİ',   icon: '☁️', lore: 'Bulut şehrin rüzgârını içine hapsetmiş bir bez.' },
    { stage: 7, name: 'İNCİ FENERİ',   icon: '🐚', lore: 'Derinlerde yanan tek ışık; yolunu o çiziyor.' },
    { stage: 8, name: 'YANKI PRİZMASI',icon: '🔮', lore: 'Sana baktığında seni değil, olmak istediğini gösteriyor.' },
    { stage: 9, name: 'ZİRVE TACI',    icon: '👑', lore: 'Yükselişin son kanıtı. Ama gökyüzü hâlâ bitmedi.' }
  ];

  function relicFor(stage) {
    for (var r = 0; r < RELICS.length; r++) if (RELICS[r].stage === stage) return RELICS[r];
    return null;
  }

  function createSave() {
    return {
      v: 2,
      coins: 60,               // ilk gün hediyesi
      completed: {},           // levelIndex -> { stars, best }
      skins: ['default'],
      activeSkin: 'default',
      best: 0,                 // serbest mod rekoru
      totalPerfect: 0,
      totalBlocks: 0,
      levelsDone: 0,
      day: -1,
      missions: null,
      daily: { day: -1, best: 0 },   // günlük meydan okuma rekoru
      worldsCelebrated: {},     // stage -> true (dünya tamamlama töreni bir kez)
      relics: {},               // stage -> true (dünya kalıntısı kazanıldı)
      boxes: {}                // boxLevelIndex -> true
    };
  }

  /* Eski tek skor kaydını yeni sisteme taşı */
  function migrate(legacyBest) {
    var s = createSave();
    if (legacyBest > 0) s.best = legacyBest;
    return s;
  }

  function load(storage) {
    try {
      var raw = storage.getItem(SAVE_KEY);
      if (raw) {
        var s = JSON.parse(raw);
        if (s && s.v === 2) {
          if (!s.worldsCelebrated) s.worldsCelebrated = {};   // eski kayıt uyumu
          if (!s.daily) s.daily = { day: -1, best: 0 };
          if (!s.relics) s.relics = {};
          return s;
        }
      }
      var legacy = parseInt(storage.getItem(LEGACY_KEY), 10) || 0;
      return legacy > 0 ? migrate(legacy) : createSave();
    } catch (e) {
      return createSave();
    }
  }

  function save(state, storage) {
    try { storage.setItem(SAVE_KEY, JSON.stringify(state)); } catch (e) {}
  }

  function totalStars(state) {
    var t = 0;
    for (var k in state.completed) if (state.completed[k]) t += state.completed[k].stars;
    return t;
  }

  /* Bölüm açık mı: önceki bölüm bitirilmiş VE dünya yeterli yıldızda mı */
  function isUnlocked(state, i, lv, levelsApi) {
    if (i <= 0) return true;
    if (state.completed[i - 1]) {
      var need = levelsApi.requiredStars(lv.stage);
      return totalStars(state) >= need || lv.stage === levelsApi.stageOf(i - 1);
    }
    return false;
  }

  /* Bölüm bitirildi: ödülleri hesapla ve uygula */
  function completeLevel(state, def, res) {
    /* res: { blocks, perfects, reached } */
    state.totalBlocks += res.blocks;
    state.totalPerfect += res.perfects;

    var out = { coins: 0, stars: 0, firstClear: false, boxDropped: false };

    if (def.endless) {
      if (res.blocks > state.best) state.best = res.blocks;
      return out;
    }

    /* Günlük meydan okuma: bölüm ilerlemesine dokunmaz, sadece ödül verir */
    if (def.daily) {
      out.coins = res.reached ? (def.coins + res.perfects * 2) : 2;
      state.coins += out.coins;
      return out;
    }

    state.levelsDone += res.reached ? 1 : 0;

    if (!res.reached) {
      out.coins = 2;                  // teselli: her deneme biraz kazandırır
      state.coins += out.coins;
      return out;
    }

    var stars = res.stars || 1;
    out.stars = stars;
    var first = !state.completed[def.i];
    out.firstClear = first;
    if (first || stars > state.completed[def.i].stars) {
      state.completed[def.i] = {
        stars: Math.max(stars, first ? stars : state.completed[def.i].stars),
        best: Math.max(res.blocks, first ? res.blocks : (state.completed[def.i].best || 0))
      };
    }

    var mult = def.modifier === 'altin' ? 2 : 1;
    out.coins = (def.coins + stars * 5 + res.perfects * 2) * mult;
    state.coins += out.coins;

    if (def.box && !state.boxes[def.i]) {
      state.boxes[def.i] = true;
      out.boxDropped = true;
    }
    return out;
  }

  /* Sürpriz kutusu: para ya da yeni görünüm */
  function openBox(state, def, rand) {
    var r = rand ? rand() : Math.random();
    var owned = {};
    for (var i = 0; i < state.skins.length; i++) owned[state.skins[i]] = true;
    var locked = SKINS.filter(function (s) { return s.price > 0 && !owned[s.id]; });

    if (locked.length && r < 0.35) {
      var s = locked[Math.floor((rand ? rand() : Math.random()) * locked.length)];
      state.skins.push(s.id);
      return { type: 'skin', skin: s };
    }
    var amount = 30 + Math.round((def.num || 1) * 1.5) + Math.round((rand ? rand() : Math.random()) * 40);
    state.coins += amount;
    return { type: 'coins', amount: amount };
  }

  /* ------------------------- Günlük görevler ------------------------- */

  var MISSION_TEMPLATES = [
    { stat: 'totalPerfect', label: 'mükemmel bırakış', base: 10, step: 5,  reward: 30 },
    { stat: 'totalBlocks',  label: 'blok diz',        base: 60, step: 20, reward: 25 },
    { stat: 'levelsDone',   label: 'bölüm bitir',     base: 2,  step: 1,  reward: 45 }
  ];

  function dayOf(now) { return Math.floor((now || Date.now()) / 86400000); }

  /* Gün değiştiyse görevleri yenile (başlangıç değerleri anlık toplamlardan) */
  function ensureMissions(state, now) {
    var day = dayOf(now);
    if (state.missions && state.missions.day === day) return state.missions;
    state.missions = {
      day: day,
      items: MISSION_TEMPLATES.map(function (t, idx) {
        return {
          stat: t.stat,
          label: t.label,
          goal: t.base + ((day + idx) % 3) * t.step,
          reward: t.reward,
          base: state[t.stat],        // baz anlık toplam
          claimed: false
        };
      })
    };
    return state.missions;
  }

  function missionProgress(state, item) {
    return Math.max(0, (state[item.stat] || 0) - item.base);
  }

  function claimMission(state, item) {
    if (item.claimed || missionProgress(state, item) < item.goal) return null;
    item.claimed = true;
    state.coins += item.reward;
    return item.reward;
  }

  /* ---------------- Dünya tamamlama töreni + sürpriz ödülleri ---------------- */

  function isWorldComplete(state, stage, levelsApi) {
    var start = stage * levelsApi.LEVELS_PER_STAGE;
    for (var k = 0; k < levelsApi.LEVELS_PER_STAGE; k++) {
      if (!state.completed[start + k]) return false;
    }
    return true;
  }

  function worldBonus(stage) { return 50 + stage * 25; }

  /* Kalıntı: dünya başına bir kez, kalıcı yadigâr */
  function awardRelic(state, stage) {
    if (!state.relics) state.relics = {};
    if (state.relics[stage]) return null;
    var r = relicFor(stage);
    if (!r) return null;
    state.relics[stage] = true;
    return r;
  }

  /* Dünya aydınlanır: bir kez bonus + kalıntı ver */
  function applyWorldComplete(state, stage) {
    if (!state.worldsCelebrated) state.worldsCelebrated = {};
    if (state.worldsCelebrated[stage]) return null;
    state.worldsCelebrated[stage] = true;
    awardRelic(state, stage);
    var c = worldBonus(stage);
    state.coins += c;
    return c;
  }

  /* ---------------- Günlük meydan okuma + skor tahtası ---------------- */

  function recordDaily(state, day, blocks) {
    if (!state.daily || state.daily.day !== day) state.daily = { day: day, best: 0 };
    if (blocks > state.daily.best) state.daily.best = blocks;
    return state.daily.best;
  }

  /* Günün skor tahtası rakipleri: deterministik (aynı gün herkeste aynı) */
  function rivalsFor(day, playerScore) {
    var NAMES = ['Kaptan', 'Mıstık', 'NeonRıza', 'Zeynep', 'BlokUsta', 'Ayşe', 'Pixel', 'Mert', 'Luna'];
    var seed = ((day | 0) * 2654435761) % 2147483647;
    if (seed <= 0) seed += 2147483646;
    function rnd() { seed = (seed * 48271) % 2147483647; return seed / 2147483647; }
    var out = [];
    for (var i = 0; i < NAMES.length; i++) {
      var base = (playerScore || 10) * (0.55 + rnd() * 0.95);
      out.push({ name: NAMES[i], score: Math.max(3, Math.round(base + (rnd() - 0.5) * 6)) });
    }
    return out;
  }

  function applySurpriseCoins(state, def, surprise) {
    if (surprise && surprise.effect === 'coinStart') {
      state.coins += surprise.coins;
      return surprise.coins;
    }
    return 0;
  }

  /* ---------------------------- Görünümler ---------------------------- */

  function buySkin(state, id) {
    var s = skinById(id);
    if (state.skins.indexOf(id) >= 0) return { ok: false, reason: 'owned' };
    if (state.coins < s.price) return { ok: false, reason: 'coins' };
    state.coins -= s.price;
    state.skins.push(id);
    state.activeSkin = id;
    return { ok: true, skin: s };
  }

  function equipSkin(state, id) {
    if (state.skins.indexOf(id) < 0) return false;
    state.activeSkin = id;
    return true;
  }

  var API = {
    SAVE_KEY: SAVE_KEY,
    SKINS: SKINS,
    RELICS: RELICS,
    relicFor: relicFor,
    awardRelic: awardRelic,
    skinById: skinById,
    createSave: createSave,
    load: load,
    save: save,
    totalStars: totalStars,
    isUnlocked: isUnlocked,
    completeLevel: completeLevel,
    openBox: openBox,
    isWorldComplete: isWorldComplete,
    worldBonus: worldBonus,
    applyWorldComplete: applyWorldComplete,
    applySurpriseCoins: applySurpriseCoins,
    recordDaily: recordDaily,
    rivalsFor: rivalsFor,
    dayOf: dayOf,
    ensureMissions: ensureMissions,
    missionProgress: missionProgress,
    claimMission: claimMission,
    buySkin: buySkin,
    equipSkin: equipSkin
  };

  if (root) root.NeonProgress = API;
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
})(typeof globalThis !== 'undefined' ? globalThis : this);
