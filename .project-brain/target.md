# Target Architecture
Status: CONFIRMED

Confirmed intent only. Authoritative full spec: `docs/SPEC.md` (devir brifingi, rebranded).

## Goal
"Bu oyunu Flutter'da sıfırdan premium kalitede yapacağız; hem iOS hem Android'e
entegre edilebilecek. Çok daha iyi olabilir ama eksik olamaz; mantık her şey çok daha
iyi olabilir ama daha kötü olamaz. Projenin ismi Stack Tower Game, Neon Kule olmayacak.
Bütün yapılacakların hepsini Project Brain'e ekle; tek gerçek kaynak Project Brain olsun." (user, 2026-10-24)

## Target State
### game-core (saf mantık — birebir port)
- `lib/game/levels.dart`, `progress.dart`, `drop_core.dart`: reference/www JS ile
  matematik birebir aynı; saf Dart, tam birim test paritesi (SPEC §2, §8).
### game-engine
- `lib/game/gameplay.dart`: CustomPainter + Ticker döngüsü; hareket/bırakma/kalkan/
  kazanma-kaybetme, kamera, enkaz-parçacık-halka-popup-konfeti, paralaks gökyüzü
  (aurora/ay/adalar/silüet/bulut denizi/hava/takımyıldız), 3B blok görünümü, karanlık
  perdesi, 60 fps (SPEC §3).
### screens
- menu, map (perspektif takımada), preview (sinematik), play+HUD, result, box,
  reward_room, shop, missions, board, settings — akış `reference/www/ui.js` ile aynı.
### theme
- Neon token'lar (THEMES paletleri, glow, Inter fontu) `lib/theme/`.
### services
- storage (shared_preferences, anında yazım), session (secure storage),
  leaderboard (offline kuyruk ≤50 + toplu gönderim + yalnız en yüksek skor).
### backend
- `worker/`: Cloudflare Workers + D1; /auth/google, /auth/apple, /me, /leaderboard,
  /score, /account (SPEC §7). Yerel deterministik rakip tahtası fallback.
### audio
- Olay sesleri (place/perfect/win/lose/coin/box/shield/start) + mute; üretilmiş varlıklar (ADR-003).

## Non-Goals
- Reklam/analitik/3. parti veri paylaşımı yok; Flame/fizik motoru yok (ADR-002);
  yatay mod yok (dikey kilitli); görsel yeniden keşif yok (estetik sadakat);
  R2/görsel CDN yok; mağazaya yükleme bu repoda yapılmaz (release skill).

## Open Decisions
- TD-001 OPEN: Yayın paket kimliği (`com.stacktower.game` yer tutucu) -> blocks release-only tasks
- TD-002 OPEN: Tahtada görünecek ad hesap adı mı, takma ad mı? (öneri: takma ad) -> blocks PB-011 kimlik UI detayı
- TD-003 OPEN: Skor tahtası ilk fazda Cloudflare (varsayılan, uygulanıyor) -> alternatif GC/PGS

## Success Conditions
- `flutter test` yeşil: JS parite testleri (150 bölüm snapshot, ekonomi, drop matematiği) + duman simülasyonu.
- Oyun Android'de baştan sona oynanabilir: menü→harita→150 bölüm+günlük+serbest→kutu/mağaza/görevler/ödül odası; çevrimdışı çalışır.
- Görsel kalite barı SPEC §3 karşılanır (kanıt: ekran kaydı/görsel evidence).
- Worker uçları yerel wrangler/D1 testinden geçer; skor kuyruğu hiçbir durumda skor kaybetmez.
- Dikey kilit + geri tuşu + ses/titreşim ayarları cihazda doğrulanır.
