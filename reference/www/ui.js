/* ============================================================
   NEON KULE — Arayüz katmanı
   Menü · 3B dünya haritası · sinematik bölüm girişi · sonuç/ödül ·
   sürpriz kutusu · ödül odası (görünümler + kalıntılar) · görevler
   ============================================================ */
(function () {
  'use strict';

  var levels = window.NeonLevels;
  var prog = window.NeonProgress;
  var engine = window.NeonEngine;
  var mapMod = window.NeonMap;
  var preview = window.NeonPreview;

  /* Çevrimiçi skor tahtası: Game Center / Play Games köprüsü yoksa
     sessizce çevrimdışı (mevcut rakip tahtası) modda kalır */
  var lbMod = window.NeonLeaderboard;
  var lb = lbMod ? lbMod.create({
    storage: window.localStorage,
    native: lbMod.detectNative(),
    platform: lbMod.detectPlatform(),
    ids: window.NeonKuleLbIds || {}
  }) : {
    isAvailable: function () { return false; },
    authenticate: function (cb) { if (cb) cb({ ok: false, native: false }); },
    submit: function () {},
    open: function (k, cb) { if (cb) cb({ ok: false, reason: 'unavailable' }); },
    pendingCount: function () { return 0; }
  };

  function el(id) { return document.getElementById(id); }
  function setText(id, v) { var e = el(id); if (e) e.textContent = v; }
  function show(id) { var e = el(id); if (e) e.classList.remove('hidden'); }
  function hide(id) { var e = el(id); if (e) e.classList.add('hidden'); }
  function on(id, fn) { var e = el(id); if (e) e.addEventListener('click', fn); }

  var save = null;
  var currentDef = null;
  var pendingResult = null;      // kutudan sonra gösterilecek sonuç
  var inLevel = false;
  var currentSurprise = null;    // bölüm sürprizi (oyuncuya açıklanmaz — gizem)
  var doubleCoinsThisLevel = false;
  var chain = [];                // kazanınca sırayla: kutu → dünya töreni → sonuç

  /* --------------------------- Kayıt --------------------------- */

  function persist() { prog.save(save, window.localStorage); }

  function updateBadges() {
    var stars = prog.totalStars(save);
    setText('coinCount', String(save.coins));
    setText('mapCoins', String(save.coins));
    setText('starCount', String(stars));
    setText('mapStars', String(stars));
    setText('menuBest', String(save.best));
    setText('skyCount', String(stars));
    engine.setProgressStars(stars);   // gökte yıldızlar yansın
  }

  /* ------------------------- Ekran geçişleri ------------------------- */

  function hideAllOverlays() {
    ['ovIntro', 'ovResult', 'ovBox', 'ovShop', 'ovMissions', 'ovWorld', 'ovBoard'].forEach(hide);
    if (preview) preview.close();
  }

  function showMenu() {
    inLevel = false;
    hideAllOverlays();
    hide('screen-map');
    hide('hud');
    show('screen-menu');
    updateBadges();
  }

  function showMap() {
    inLevel = false;
    hideAllOverlays();
    hide('screen-menu');
    hide('hud');
    show('screen-map');
    updateBadges();
    ensureMap();
  }

  function toast(msg) {
    var t = el('toast');
    if (!t) return;
    t.textContent = msg;
    t.classList.remove('show');
    void t.offsetWidth;
    t.classList.add('show');
  }

  /* --------------------------- Harita --------------------------- */

  var mapReady = false;

  function ensureMap() {
    var cv = el('mapCanvas');
    if (!cv || !mapMod) return;
    if (!mapReady) {
      mapMod.init(cv, {
        save: save,
        levels: levels,
        prog: prog,
        onFocus: updateMapLabels,
        onTapNode: function (i, unlocked) {
          engine.unlockAudio();
          /* kilitli olsa bile dünyayı önizle — oyuncu neyi kaçırdığını görsün */
          openIntro(levels.levelDef(i), { locked: !unlocked });
        },
        onTapDaily: function () {
          engine.unlockAudio();
          openIntro(levels.dailyDef(prog.dayOf(Date.now())));
        }
      });
      mapReady = true;
      buildMapDots();
    } else {
      mapMod.setSave(save);
      mapMod.refresh();
      mapMod.centerCurrent();
    }
    updateMapLabels();
  }

  function updateMapLabels(info) {
    var stage = mapMod ? mapMod.getFocus() : 0;
    var data = info || (mapMod && mapMod.worldInfo ? mapMod.worldInfo() : null);
    if (!data) return;
    setText('mapWorldKicker', 'DÜNYA ' + (stage + 1));
    setText('mapWorldName', data.name);
    setText('mapWorldSub', data.open
      ? (data.done + '/' + data.total + ' · ★ ' + data.stars + '/' + data.maxStars)
      : ('🔒 ' + prog.totalStars(save) + '/' + data.need + ' yıldız'));
    var prev = el('mapPrevWorld');
    var next = el('mapNextWorld');
    if (prev) prev.disabled = stage <= 0;
    if (next) next.disabled = stage >= levels.STAGE_COUNT - 1;
    var dots = el('mapDots');
    if (dots && dots.children.length) {
      for (var i = 0; i < dots.children.length; i++) {
        var d = dots.children[i];
        d.className = 'map-dot' + (i === stage ? ' active' : '')
          + (i === 0 || prog.totalStars(save) >= levels.requiredStars(i) ? ' open' : ' locked');
      }
    }
  }

  function buildMapDots() {
    var box = el('mapDots');
    if (!box) return;
    box.innerHTML = '';
    for (var s = 0; s < levels.STAGE_COUNT; s++) {
      (function (stage) {
        var b = document.createElement('button');
        b.type = 'button';
        b.className = 'map-dot' + (stage === 0 ? ' open' : ' locked');
        b.textContent = String(stage + 1);
        b.setAttribute('aria-label', 'Dünya ' + (stage + 1));
        b.addEventListener('click', function () { mapMod.setFocus(stage); updateMapLabels(); });
        box.appendChild(b);
      })(s);
    }
  }

  /* ------------------------ Bölüm girişi ------------------------ */

  function openIntro(d, opts) {
    hideAllOverlays();          // sonuç ekranı açık kalmasın (ilerleme hatası düzeltmesi)
    currentDef = d;
    var locked = !!(opts && opts.locked);
    var mod = levels.MODIFIERS[d.modifier];

    setText('introTitle', d.daily ? 'GÜNLÜK MEYDAN OKUMA' : 'BÖLÜM ' + d.num);
    setText('introWorld', d.daily ? 'BUGÜN HERKES İÇİN AYNI' : ('DÜNYA ' + (d.stage + 1) + ' · ' + d.theme.name));
    setText('introWorldProg', d.daily ? 'GÜNLÜK' : (worldDone(d.stage) + '/' + levels.LEVELS_PER_STAGE));
    setText('introTeaser', d.daily ? 'Bugünün bölümü herkes için aynı. Tahtada yerini al.'
      : (levels.WORLD_TEASER[d.stage] || ''));
    setText('introModIcon', mod.icon);
    setText('introModName', mod.name);
    setText('introHint', mod.hint);
    setText('introTarget', d.target + ' blok');
    setText('introReward', d.coins + ' 🪙' + (d.box ? ' + 🎁' : ''));

    var prevStars = (!d.daily && save.completed[d.i]) ? save.completed[d.i].stars : 0;
    var starBox = el('introStars');
    if (starBox) {
      starBox.innerHTML = '';
      for (var s = 1; s <= 3; s++) {
        var i2 = document.createElement('i');
        i2.className = s <= prevStars ? 'on' : '';
        i2.textContent = '★';
        starBox.appendChild(i2);
      }
    }

    var surprise = (d.endless || d.daily) ? null : levels.surpriseFor(d.i, prog.dayOf(Date.now()));
    currentSurprise = surprise;
    var mysteryText = levels.mysteryFor(d.i);
    if (surprise) mysteryText = 'Altın bir fısıltı… şans bu bölümde senden yana olabilir.';
    setText('introMysteryText', mysteryText);
    var mEl = el('introMystery');
    if (mEl) mEl.className = 'mystery' + (surprise ? ' gold' : '');

    /* sürpriz adı asla açıklanmaz — gizem korunur */
    hide('introSurprise');

    var startBtn = el('btnStart');
    if (locked) {
      var need = levels.requiredStars(d.stage);
      var reason = (d.stage > 0 && prog.totalStars(save) < need)
        ? ('BU DÜNYA İÇİN ' + need + ' YILDIZ GEREKİYOR')
        : ('ÖNCE BÖLÜM ' + (d.num - 1) + '\'İ BİTİR');
      setText('introLockText', reason);
      show('introLock');
      if (startBtn) { startBtn.disabled = true; setText('btnStart', '🔒 KİLİTLİ'); }
    } else {
      hide('introLock');
      if (startBtn) { startBtn.disabled = false; setText('btnStart', 'BAŞLA ▶'); }
    }

    show('ovIntro');
    if (preview) preview.open(d);
  }

  function worldDone(stage) {
    var c = 0, per = levels.LEVELS_PER_STAGE;
    for (var k = 0; k < per; k++) if (save.completed[stage * per + k]) c++;
    return c;
  }

  function startCurrentLevel() {
    if (!currentDef) return;
    hideAllOverlays();
    hide('screen-map');
    show('hud');
    inLevel = true;
    var skin = prog.skinById(save.activeSkin);

    var surprise = (currentDef.endless || currentDef.daily)
      ? null : levels.surpriseFor(currentDef.i, prog.dayOf(Date.now()));
    currentSurprise = surprise;
    doubleCoinsThisLevel = !!(surprise && surprise.effect === 'doubleCoins');
    var shields = surprise && surprise.effect === 'shieldUp' ? 2 : 1;

    engine.startLevel(currentDef, { hue: skin.hue, shields: shields }, onEngineEvent);

    if (surprise && surprise.effect === 'coinStart') {
      var got = prog.applySurpriseCoins(save, currentDef, surprise);
      persist();
      updateBadges();
      toast('✨ Gizem çözüldü: +' + got + ' 🪙');
    } else if (surprise) {
      toast('✨ Gizem çözüldü: ' + surprise.name);
    }
    updateHud();
    updateShieldHud();
  }

  function startEndless() {
    currentDef = levels.endlessDef(levels.THEMES[0]);
    hideAllOverlays();
    hide('screen-menu');
    show('hud');
    inLevel = true;
    var skin = prog.skinById(save.activeSkin);
    engine.startLevel(currentDef, { hue: skin.hue }, onEngineEvent);
    updateHud();
  }

  /* ---------------------------- HUD ---------------------------- */

  function updateHud() {
    var p = engine.getProgress();
    if (p.target > 0) {
      setText('hudScore', p.placed + '/' + p.target);
      el('progressFill').style.width = Math.min(100, p.placed / p.target * 100) + '%';
      el('progressWrap').style.opacity = '1';
    } else {
      setText('hudScore', String(p.placed));
      el('progressWrap').style.opacity = '0.25';
    }
    setText('combo', p.combo >= 2 ? '×' + p.combo : '');
    updateShieldHud();
  }

  function updateShieldHud() {
    var s = engine.getShield();
    setText('shieldBadge', '🛡 ×' + s);
    var b = el('shieldBadge');
    if (b) b.style.opacity = s > 0 ? '1' : '0.3';
  }

  /* ------------- Kazanma zinciri: kutu → dünya töreni → sonuç ------------- */

  function nextStep() {
    var f = chain.shift();
    if (f) f();
  }

  function makeWorldStep(stage, bonus) {
    return function () {
      setText('worldTitle', 'DÜNYA ' + (stage + 1) + ' AYDINLANDI');
      setText('worldLore', levels.WORLD_LORE[stage] || '');
      setText('worldCoins', '+' + bonus + ' 🪙');
      var relic = prog.relicFor(stage);
      if (relic && save.relics && save.relics[stage]) {
        setText('worldRelicIcon', relic.icon);
        setText('worldRelicName', relic.name);
        setText('worldRelicLore', relic.lore);
        show('worldRelic');
      } else {
        hide('worldRelic');
      }
      show('ovWorld');
      engine.haptic(50);
    };
  }

  /* Günlük meydan okuma → skor tahtası */
  function boardStep() {
    var day = prog.dayOf(Date.now());
    var rows = prog.rivalsFor(day, pendingResult.data.blocks).map(function (r) {
      return { name: r.name, score: r.score, me: false };
    });
    rows.push({ name: 'SEN', score: pendingResult.data.blocks, me: true });
    rows.sort(function (a, b) { return b.score - a.score; });

    var list = el('boardList');
    list.innerHTML = '';
    rows.forEach(function (r, idx) {
      var row = document.createElement('div');
      row.className = 'board-row' + (r.me ? ' me' : '');
      row.innerHTML =
        '<span class="rank">' + (idx + 1) + '</span>' +
        '<span class="bname">' + r.name + '</span>' +
        '<span class="bscore">' + r.score + '</span>';
      list.appendChild(row);
    });
    setText('boardDay', new Date(day * 86400000).toLocaleDateString('tr-TR') + ' · herkes aynı bölüm');
    var onlineBtn = el('btnOnlineBoard');
    if (onlineBtn) onlineBtn.style.display = lb.isAvailable() ? '' : 'none';
    show('ovBoard');
    engine.haptic(30);
  }

  /* ------------------------ Motor olayları ------------------------ */

  function onEngineEvent(name, data) {
    if (name === 'place') {
      updateHud();
    } else if (name === 'shield') {
      updateShieldHud();
    } else if (name === 'win') {
      var stars = levels.starsFor(data.perfects, currentDef.target);
      var rewards = prog.completeLevel(save, currentDef, { blocks: data.blocks, perfects: data.perfects, reached: true, stars: stars });
      if (doubleCoinsThisLevel) rewards.coins *= 2;   // ALTIN RUH sürprizi
      if (currentDef.daily) prog.recordDaily(save, prog.dayOf(Date.now()), data.blocks);
      if (currentDef.daily) lb.submit('daily', data.blocks);   // çevrimiçi tahtaya gönder

      var worldBonusCoins = null;
      var lastOfWorld = !currentDef.endless && !currentDef.daily && levels.indexInStage(currentDef.i) === levels.LEVELS_PER_STAGE - 1;
      if (lastOfWorld && prog.isWorldComplete(save, currentDef.stage, levels)) {
        worldBonusCoins = prog.applyWorldComplete(save, currentDef.stage);
      }

      persist();
      updateBadges();
      pendingResult = { win: true, data: data, rewards: rewards };
      chain = [];
      if (rewards.boxDropped) chain.push(showBox);
      if (worldBonusCoins !== null) chain.push(makeWorldStep(currentDef.stage, worldBonusCoins));
      if (currentDef.daily) chain.push(boardStep);
      chain.push(flushResult);
      // Sonuç ekranı bittikten sonra haritayı otomatically göster
      chain.push(function () { setTimeout(showMap, 1200); });
      nextStep();
    } else if (name === 'lose') {
      var rw = prog.completeLevel(save, currentDef, { blocks: data.blocks, perfects: data.perfects, reached: false });
      if (doubleCoinsThisLevel) rw.coins *= 2;
      if (currentDef.daily) prog.recordDaily(save, prog.dayOf(Date.now()), data.blocks);
      if (currentDef.endless) lb.submit('endless', data.blocks);  // serbest mod rekoru
      persist();
      updateBadges();
      pendingResult = { win: false, data: data, rewards: rw };
      if (currentDef.daily) {
        chain = [];
        chain.push(boardStep);
        chain.push(flushResult);
        nextStep();
      } else {
        flushResult();
      }
    } else if (name === 'back') {
      engine.stopLevel();
      showMap();
    }
  }

  /* -------------------------- Sonuç ekranı -------------------------- */

  function flushResult() {
    var r = pendingResult;
    pendingResult = null;
    if (!r) return;
    inLevel = false;

    var endless = currentDef.endless;
    var daily = currentDef.daily;
    setText('resTitle', endless ? 'SERBEST BİTTİ' : daily ? 'GÜNLÜK BİTTİ!' : (r.win ? 'BÖLÜM TAMAM!' : 'BİTİYORDU!'));
    setText('resDetail', (endless || daily)
      ? ('Kule boyu: ' + r.data.blocks + (daily
          ? ' · Günün rekoru: ' + (save.daily ? save.daily.best : 0)
          : ' · Rekor: ' + save.best))
      : (r.data.perfects + ' mükemmel bırakış'));

    var starsEl = el('resStars');
    starsEl.innerHTML = '';
    var starCount = r.win ? levels.starsFor(r.data.perfects, currentDef.target) : 0;
    for (var s = 1; s <= 3; s++) {
      var i2 = document.createElement('i');
      i2.className = 'star ' + (s <= starCount ? 'on' : '');
      i2.style.animationDelay = (0.15 + s * 0.22) + 's';
      i2.textContent = '★';
      starsEl.appendChild(i2);
    }

    setText('resCoins', '+' + r.rewards.coins + ' 🪙');
    setText('resBest', endless ? ('Rekor: ' + save.best)
      : daily ? 'Her gün yeni tahta, yeni şans!'
      : ('Toplam yıldız: ' + prog.totalStars(save)));

    var hasNext = r.win && !endless && !daily && currentDef.i + 1 < levels.levelCount();
    el('btnNext').style.display = hasNext ? '' : 'none';
    setText('btnNext', hasNext ? 'SONRAKİ BÖLÜM →' : 'SONRAKİ');

    var resOnline = el('btnResOnline');
    if (resOnline) resOnline.style.display = ((endless || daily) && lb.isAvailable()) ? '' : 'none';

    show('ovResult');
  }

  /* ------------------------- Sürpriz kutusu ------------------------- */

  function showBox() {
    setText('boxPrize', '');
    setText('boxTitle', 'SÜRPRİZ KUTU KAZANDIN! 🎁');
    el('btnOpenBox').style.display = '';
    el('boxContinue').style.display = 'none';
    show('ovBox');
  }

  function openBoxNow() {
    var prize = prog.openBox(save, currentDef);
    persist();
    updateBadges();
    engine.haptic(40);
    if (prize.type === 'skin') {
      setText('boxTitle', 'YENİ GÖRÜNÜM!');
      setText('boxPrize', '✦ ' + prize.skin.name + ' ✦\nÖdül Odasından kuşanabilirsin.');
    } else {
      setText('boxTitle', 'MADENİ PARA!');
      setText('boxPrize', '+' + prize.amount + ' 🪙');
    }
    el('btnOpenBox').style.display = 'none';
    el('boxContinue').style.display = '';
  }  /* ------------------------ Ödül odası ------------------------ */

  var shopTab = 'skins';

  function switchShopTab(tab) {
    shopTab = tab;
    var skinsBtn = el('shopTabSkins'), relicsBtn = el('shopTabRelics');
    if (skinsBtn) skinsBtn.className = 'shop-tab' + (tab === 'skins' ? ' active' : '');
    if (relicsBtn) relicsBtn.className = 'shop-tab' + (tab === 'relics' ? ' active' : '');
    var sp = el('shopSkinsPane'), rp = el('shopRelicsPane');
    if (sp) sp.classList.toggle('hidden', tab !== 'skins');
    if (rp) rp.classList.toggle('hidden', tab !== 'relics');
  }

  /* Mini kule önizlemesi: oyundaki blok istifi + neon parıltı (CSS) */
  function towerPreview(hue) {
    return '<div class="skin-preview">' +
      '<i style="--h:' + hue + '"></i>' +
      '<i style="--h:' + ((hue + 12) % 360) + '"></i>' +
      '<i style="--h:' + ((hue + 24) % 360) + '"></i>' +
      '</div>';
  }

  function renderShop() {
    setText('shopCoins', save.coins + ' 🪙');
    var grid = el('shopGrid');
    grid.innerHTML = '';
    prog.SKINS.forEach(function (s) {
      var owned = save.skins.indexOf(s.id) >= 0;
      var equipped = save.activeSkin === s.id;
      var afford = save.coins >= s.price;
      var card = document.createElement('div');
      card.className = 'skin-card' + (equipped ? ' equipped' : '')
        + (owned ? ' owned' : '')
        + (!owned && !afford ? ' cant' : '');
      card.innerHTML =
        towerPreview(s.hue) +
        '<div class="skin-name">' + s.name + '</div>' +
        '<div class="skin-state">' +
        (equipped ? '<span class="skin-badge eq">✓ KUŞANILDI</span>'
          : owned ? '<span class="skin-badge">KUŞAN</span>'
          : '<span class="skin-price' + (afford ? '' : ' red') + '">' + s.price + ' 🪙</span>') +
        '</div>';
      card.addEventListener('click', function () {
        if (equipped) return;
        if (owned) {
          prog.equipSkin(save, s.id);
          toast('✦ Görünüm kuşanıldı: ' + s.name);
        } else {
          var r = prog.buySkin(save, s.id);
          if (!r.ok) {
            toast(r.reason === 'coins' ? 'Yeterli paran yok! Bölüm bitir, kutu aç.' : 'Zaten senin!');
            return;
          }
          engine.haptic(30);
          toast('✦ Yeni görünüm: ' + s.name);
        }
        persist();
        updateBadges();
        renderShop();
      });
      grid.appendChild(card);
    });
    renderRelics();
    switchShopTab(shopTab);
  }

  function renderRelics() {
    var grid = el('relicGrid');
    if (!grid) return;
    /* koleksiyon ilerlemesi */
    var ownedCount = 0;
    for (var st = 0; st < levels.STAGE_COUNT; st++) if (save.relics && save.relics[st]) ownedCount++;
    setText('relicCountTab', ownedCount + '/' + prog.RELICS.length);
    var fill = el('relicProgressFill');
    if (fill) fill.style.width = Math.round(ownedCount / prog.RELICS.length * 100) + '%';

    grid.innerHTML = '';
    prog.RELICS.forEach(function (r) {
      var owned = !!(save.relics && save.relics[r.stage]);
      var worldName = levels.THEMES[r.stage] ? levels.THEMES[r.stage].name : '';
      var card = document.createElement('div');
      card.className = 'relic-card' + (owned ? ' owned' : '');
      card.innerHTML =
        '<div class="relic-icon">' + (owned ? r.icon : '🔒') + '</div>' +
        '<div class="relic-body">' +
        '<div class="relic-name">' + (owned ? r.name : 'KİLİTLİ') + '</div>' +
        '<div class="relic-lore">' + (owned ? r.lore : worldName + ' aydınlanınca kazanılır') + '</div>' +
        '</div>';
      grid.appendChild(card);
    });
  }

  /* --------------------------- Görevler --------------------------- */

  function renderMissions() {
    prog.ensureMissions(save, Date.now());
    persist();
    var list = el('missionList');
    list.innerHTML = '';
    save.missions.items.forEach(function (m) {
      var p = prog.missionProgress(save, m);
      var done = p >= m.goal;
      var row = document.createElement('div');
      row.className = 'mission-row' + (done ? ' done' : '');
      row.innerHTML =
        '<div class="mission-info"><b>' + m.goal + ' ' + m.label + '</b>' +
        '<div class="mission-bar"><span style="width:' + Math.min(100, Math.round(p / m.goal * 100)) + '%"></span></div>' +
        '<small>' + Math.min(p, m.goal) + '/' + m.goal + '</small></div>' +
        '<button class="mission-claim"' + (done && !m.claimed ? '' : ' disabled') + '>' +
        (m.claimed ? 'ALINDI ✓' : '+' + m.reward + ' 🪙') + '</button>';
      var btn = row.querySelector('.mission-claim');
      if (btn && done && !m.claimed) {
        btn.addEventListener('click', function () {
          var got = prog.claimMission(save, m);
          if (got !== null) {
            engine.haptic(25);
            persist();
            updateBadges();
            renderMissions();
            toast('Görev ödülü alındı: +' + got + ' 🪙');
          }
        });
      }
      list.appendChild(row);
    });
  }

  /* ----------------------------- Girdi ----------------------------- */

  function bind() {
    on('btnPlay', function () { engine.unlockAudio(); showMap(); });
    on('btnEndless', function () { engine.unlockAudio(); startEndless(); });
    on('btnShop', function () { renderShop(); show('ovShop'); });
    on('btnMissions', function () { renderMissions(); show('ovMissions'); });
    on('shopClose', function () { hide('ovShop'); });
    on('missionsClose', function () { hide('ovMissions'); });
    on('btnMute', function () {
      var muted = engine.toggleMute();
      el('btnMute').textContent = muted ? '🔇' : '🔊';
    });
    on('mapBack', showMenu);
    on('mapPrevWorld', function () { mapMod.prevWorld(); updateMapLabels(); });
    on('mapNextWorld', function () { mapMod.nextWorld(); updateMapLabels(); });
    on('introClose', function () { hideAllOverlays(); });
    on('btnStart', startCurrentLevel);
    on('btnRetry', startCurrentLevel);
    on('btnNext', function () {
      if (!currentDef) return;
      // Önce haritayı güncelle, sonra siguiente level'ı aç
      if (mapMod) mapMod.setFocus(mapMod.getFocus());
      var n = currentDef.i + 1;
      if (n < levels.levelCount()) {
        // Kilit kontrolünü atla — her biten sonraki level açılsın
        openIntro(levels.levelDef(n), { locked: false });
      } else {
        showMap();
      }
    });
    on('btnMap', showMap);
    on('hudBack', function () {
      engine.stopLevel();
      showMap();
    });
    on('btnOpenBox', openBoxNow);
    on('boxContinue', function () { hide('ovBox'); nextStep(); });
    on('btnWorldContinue', function () { hide('ovWorld'); nextStep(); });
    on('btnBoardContinue', function () { hide('ovBoard'); nextStep(); });
    on('btnShopRelics', function () { switchShopTab('relics'); renderShop(); show('ovShop'); });
    on('shopTabSkins', function () { switchShopTab('skins'); });
    on('shopTabRelics', function () { switchShopTab('relics'); });
    on('btnOnlineBoard', function () {
      lb.open('daily', function (r) {
        if (!r.ok) toast('Çevrimiçi tahta bu cihazda kullanılamıyor.');
      });
    });
    on('btnResOnline', function () {
      var key = currentDef && currentDef.daily ? 'daily' : 'endless';
      lb.open(key, function (r) {
        if (!r.ok) toast('Çevrimiçi tahta bu cihazda kullanılamıyor.');
      });
    });

    window.addEventListener('keydown', function (e) {
      if (e.code === 'Space' || e.key === ' ') {
        e.preventDefault();
        if (e.repeat) return;
        if (inLevel) engine.drop();
      } else if (e.key === 'r' || e.key === 'R') {
        if (inLevel) startCurrentLevel();
      } else if (e.key === 'm' || e.key === 'M') {
        el('btnMute').textContent = engine.toggleMute() ? '🔇' : '🔊';
      } else if (e.key === 'Escape') {
        if (!el('ovIntro').classList.contains('hidden')) hideAllOverlays();
        else if (inLevel) { engine.stopLevel(); showMap(); }
        else if (!el('screen-map').classList.contains('hidden')) showMenu();
      }
    });

    /* dokunma da bıraksın (canvas tüm ekranı kaplar) */
    window.addEventListener('pointerdown', function (e) {
      if (!inLevel) return;
      if (e.target && e.target.closest && e.target.closest('.overlay, #hud button, #topbar')) return;
      engine.drop();
    });
  }

  /* ---------------------------- Başlangıç ---------------------------- */

  function boot() {
    save = prog.load(window.localStorage);
    prog.ensureMissions(save, Date.now());
    if (!save.relics) save.relics = {};
    /* eski kayıtlar: bitirilmiş dünyaların kalıntılarını geriye dönük ver */
    for (var st = 0; st < levels.STAGE_COUNT; st++) {
      if (prog.isWorldComplete(save, st, levels) && save.worldsCelebrated[st]) {
        prog.awardRelic(save, st);
      }
    }
    persist();

    engine.init(el('game'));
    if (preview) preview.init(el('previewCanvas'));
    el('btnMute').textContent = engine.isMuted() ? '🔇' : '🔊';
    bind();
    updateBadges();
    showMenu();

    /* çevrimiçi tahta: kimlik doğrulama + bekleyen skorları gönder */
    lb.authenticate(function () {});

    document.addEventListener('backbutton', function (e) { e.preventDefault(); });
  }

  window.NeonKule = {
    boot: boot,
    api: {
      getSave: function () { return save; },
      startLevelByIndex: function (i) { currentDef = levels.levelDef(i); startCurrentLevel(); },
      openDaily: function () { openIntro(levels.dailyDef(prog.dayOf(Date.now()))); },
      playDaily: function () { currentDef = levels.dailyDef(prog.dayOf(Date.now())); startCurrentLevel(); },
      startEndless: startEndless,
      isInLevel: function () { return inLevel; },
      showMap: showMap,
      showMenu: showMenu,
      openIntro: openIntro,
      leaderboard: lb,
      refreshMap: function () { if (mapReady) { mapMod.setSave(save); mapMod.refresh(); mapMod.draw(); } }
    }
  };

  if (typeof document !== 'undefined' && document.readyState !== 'loading') boot();
  else if (typeof document !== 'undefined') document.addEventListener('DOMContentLoaded', boot);
})(window);
