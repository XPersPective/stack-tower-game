/* ============================================================
   NEON KULE — Çevrimiçi skor tahtası servis katmanı
   Game Center (iOS) / Play Games Services (Android) köprüsü.

   Tasarım ilkeleri:
   • Skorlar asla kaybolmaz: gönderilemeyen her skor yerel kuyruğa
     yazılır (localStorage), bağlantı geldiğinde toplu gönderilir.
   • Köprü yoksa (web/önizleme/test) sessizce çevrimdışı moda düşer;
     oyun mevcut deterministik rakip tahtasıyla çalışmaya devam eder.
   • Tahta kimliği platforma göre ayrışır (www/lb-config.js).

   Köprü sözleşmesi (Capacitor eklentisi "Leaderboard"):
     authenticate() → { ok: boolean, platform: string }
     submit({ boardId, score }) → { ok: boolean }
     show({ boardId }) → { ok: boolean }   (yerel sıralama ekranı)
   ============================================================ */
(function (root) {
  'use strict';

  var QUEUE_KEY = 'neonkule_lb_queue_v1';
  var MAX_QUEUE = 50;

  function memStorage() {
    var m = {};
    return {
      getItem: function (k) { return m[k] === undefined ? null : m[k]; },
      setItem: function (k, v) { m[k] = String(v); }
    };
  }

  /* opts: { storage?, native?, platform?, ids? }
     native — köprü nesnesi (Capacitor.Plugins.Leaderboard gibi)
     platform — 'android' | 'ios' | 'web' (algılama yerine test için) */
  function create(opts) {
    opts = opts || {};
    var storage = opts.storage || memStorage();
    var ids = opts.ids || {};
    var platform = opts.platform || detectPlatform();
    var nativeBridge = opts.native !== undefined ? opts.native : null;
    var authed = false;
    var flushing = false;

    function detectPlatform() {
      var ua = (root.navigator && root.navigator.userAgent) || '';
      if (/Android/i.test(ua)) return 'android';
      if (/iPhone|iPad|iPod/i.test(ua)) return 'ios';
      return 'web';
    }

    function loadQueue() {
      try {
        var raw = storage.getItem(QUEUE_KEY);
        var q = raw ? JSON.parse(raw) : [];
        return Array.isArray(q) ? q : [];
      } catch (e) { return []; }
    }

    function saveQueue(q) {
      try { storage.setItem(QUEUE_KEY, JSON.stringify(q.slice(-MAX_QUEUE))); } catch (e) {}
    }

    function boardId(key) {
      var b = ids && ids[key];
      if (!b) return null;
      var id = b[platform];
      return (typeof id === 'string' && id.length) ? id : null;
    }

    function isAvailable() {
      return !!nativeBridge && (platform === 'android' || platform === 'ios');
    }

    function authenticate(cb) {
      cb = cb || function () {};
      if (!isAvailable()) { authed = false; cb({ ok: false, native: false, platform: platform }); return; }
      try {
        nativeBridge.authenticate().then(function (res) {
          authed = !!(res && res.ok);
          if (authed) flush();
          cb({ ok: true, native: true, platform: platform, authed: authed });
        }, function (err) {
          cb({ ok: false, native: true, platform: platform, reason: String((err && err.message) || err || 'auth-failed') });
        });
      } catch (e) {
        cb({ ok: false, native: true, platform: platform, reason: String(e) });
      }
    }

    /* Skoru kuyruğa yaz ve mümkünse hemen gönder.
       cb({ ok, queued, sent?, reason? }) */
    function submit(key, score, cb) {
      cb = cb || function () {};
      score = Math.max(0, Math.round(score || 0));
      if (score <= 0) { cb({ ok: false, reason: 'zero-score' }); return; }
      var q = loadQueue();
      q.push({ key: key, score: score, ts: Date.now() });
      saveQueue(q);
      if (!isAvailable()) { cb({ ok: true, queued: true, reason: 'offline' }); return; }
      if (!authed) { cb({ ok: true, queued: true, reason: 'not-authed' }); return; }  // kimlik doğrulanmadan gönderme
      flush(function (res) { cb({ ok: true, queued: res.pending > 0, sent: res.sent, reason: res.reason }); });
    }

    /* Kuyruğu toplu gönder: her tahta için en yüksek skor (kaybedilen
       sıralama yarışları geri alınmaz) */
    function flush(cb) {
      cb = cb || function () {};
      if (flushing) { cb({ pending: loadQueue().length, sent: 0, reason: 'busy' }); return; }
      var q = loadQueue();
      if (!q.length) { cb({ pending: 0, sent: 0 }); return; }
      if (!isAvailable() || !nativeBridge.submit) { cb({ pending: q.length, sent: 0, reason: 'offline' }); return; }
      if (!authed) { cb({ pending: q.length, sent: 0, reason: 'not-authed' }); return; }

      var best = {};
      for (var i = 0; i < q.length; i++) {
        var e = q[i];
        if (!boardId(e.key)) continue;
        best[e.key] = Math.max(best[e.key] || 0, e.score);
      }
      var keys = Object.keys(best);
      if (!keys.length) { cb({ pending: q.length, sent: 0, reason: 'no-board-id' }); return; }

      flushing = true;
      var sent = 0, failed = false, done = 0;
      keys.forEach(function (k) {
        try {
          nativeBridge.submit({ boardId: boardId(k), score: best[k] }).then(function () {
            sent++; done++; step();
          }, function () { failed = true; done++; step(); });
        } catch (e) { failed = true; done++; step(); }
      });

      function step() {
        if (done < keys.length) return;
        flushing = false;
        if (!failed) {
          /* gönderilenleri kuyruktan düş, gidemeyenleri koru */
          var remain = loadQueue().filter(function (e) { return !best.hasOwnProperty(e.key) || !boardId(e.key); });
          saveQueue(remain);
        }
        cb({ pending: remainCount(), sent: sent, reason: failed ? 'send-failed' : undefined });
      }
    }

    function remainCount() { return loadQueue().length; }

    /* Yerel platform sıralama ekranını aç */
    function open(key, cb) {
      cb = cb || function () {};
      if (!isAvailable() || !nativeBridge.show) { cb({ ok: false, reason: 'unavailable' }); return; }
      var id = boardId(key);
      if (!id) { cb({ ok: false, reason: 'no-board-id' }); return; }
      try {
        nativeBridge.show({ boardId: id }).then(function () { cb({ ok: true }); },
          function (err) { cb({ ok: false, reason: String((err && err.message) || err) }); });
      } catch (e) { cb({ ok: false, reason: String(e) }); }
    }

    function configure(newIds) { ids = newIds || {}; }

    return {
      isAvailable: isAvailable,
      platform: function () { return platform; },
      isAuthenticated: function () { return authed; },
      authenticate: authenticate,
      submit: submit,
      flush: flush,
      open: open,
      boardId: boardId,
      configure: configure,
      pendingCount: remainCount
    };
  }

  /* Tarayıcıdan erişilebilir köprüyü bul (Capacitor.Plugins.Leaderboard) */
  function detectNative() {
    try {
      var cap = root.Capacitor;
      if (!cap) return null;
      if (cap.Plugins && cap.Plugins.Leaderboard) return cap.Plugins.Leaderboard;
    } catch (e) {}
    return null;
  }

  var API = {
    create: create,
    detectNative: detectNative,
    detectPlatform: function () {
      var ua = (root.navigator && root.navigator.userAgent) || '';
      if (/Android/i.test(ua)) return 'android';
      if (/iPhone|iPad|iPod/i.test(ua)) return 'ios';
      return 'web';
    }
  };

  if (root) root.NeonLeaderboard = API;
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
})(typeof globalThis !== 'undefined' ? globalThis : this);
