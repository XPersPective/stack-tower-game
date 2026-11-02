# Target Architecture
Status: CONFIRMED

Confirmed intent only. Authoritative full spec: `docs/SPEC.md` (devir brifingi, rebranded).

## Goal
"Bu oyunu Flutter'da sıfırdan premium kalitede yapacağız; hem iOS hem Android'e
entegre edilebilecek. Çok daha iyi olabilir ama eksik olamaz; mantık her şey çok daha
iyi olabilir ama daha kötü olamaz. Projenin ismi Stack Tower Game, Neon Kule olmayacak.
Bütün yapılacakların hepsini Project Brain'e ekle; tek gerçek kaynak Project Brain olsun." (user, 2026-10-24)

"Ya açıkçası bu hep böyle mi olacak? Yani yukarıdan şeyler gelecek ve bunları dizmeye
mi çalışacak? Başka bir mantık yok mu? Her oyun, her bölüm farklı oyun içermeli...
Oyunu bağımlılık haline getirebilecek bir şekle çevirmen gerekiyor. Ve oyunun bir
amacı olmalı. Amaç tamamlandıkça arkada o bölümde tamamlanan bir şey gösterilmeli ve
çok güzel olmalı... birkaç aşamadan sonra hep böyle bir şeyler tamamlanmalı. Her oyun
farklı mantıkla değişik sürprizler içermeli. Çok güzel efektler, harika efektleri
olmalı. Bunu öyle kurgula." (user, 2026-10-25 ikinci yön — DESIGN-V2-diyar.md)

"Oyun çok tekdüze olmuş... Hiçbir sürprizi yok. Her oyun birbirinin aynısı... Daha
değişik mantıklar, daha değişik içerikler konabilir. Özellikle ilk birkaç bölüm çok
sürprizli olmalı... Değişik sürprizler konması ve efektler mükemmel olmalı. Sesler de
öyle... Pazar yeri gibi bir şeyler olması gerekiyor... harita neyle karşılaşacağı ile
ilgili gizemli bir şekilde birkaç şey göstermeli... Ödüllendirmeleri bol olması
gerekiyor... bir pazar araştırması yap... sağlam bir rapor oluştur. Bunu proje brain'e
entegre edeceksin ama yapılacakları ondan sonra uygulayacaksın." (user, 2026-10-25 — yön
değişikliği: RESEARCH-market.md §4 tasarım kararları + PB-015..021)

"Kapsamlı şekilde iOS ve premium düzeyde bitir; zevkli görseller, harika efektler,
test etme/emülatörde test etme, üretim düzeyini bitir." (user, 2026-10-29/30 —
.workbuddy-ai memory'de kayıtlı; PB-031 premium kapanışının yetki kaynağı)

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
- menu, map (3B takımada — PB-008), preview (sinematik), play+HUD, result, box,
  reward_room, shop, missions, board, settings — akış `reference/www/ui.js` ile aynı.
### anthology (YENİ — DESIGN-V2 §3.1)
- 10 farklı MiniGame türü (STACK/CATCH/RING/LAUNCH/MERGE/PATH/SORT/BALANCE/DEFEND/RHYTHM);
  her bölüm farklı tür (ardışık aynı ≤1); ilk 5 bölüm 5 farklı tür.
### construction-meta (YENİ — DESIGN-V2 §3.2)
- Görünür inşaat: her bölüm adada yapı parçası yükseltir; 3-5 bölümde yapı tamamlanır;
  dünyada anıt töreni; 10 dünya = Diyar finali. Haritada blueprint merakı.
### gameplay-variety (kullanıcı yönü 2026-10-25 tur 1)
- 8 yeni twist türü + garantili ilk-5 şeması; her 3 bölümden biri yeni tür; juice
  paketi (hit-stop, squash&stretch, flaş, haptic); ses katmanları.
### economy-market (YENİ)
- Haritada pazar yeri binası: günlük rotasyon + gizli sandık; cömertlik ilkesi
  (4-5 bölümde 1 satın alma gücü).
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
  yatay mod yok (dikey kilitli); görsel yeniden keşif yalnız premium katmanla sınırlı
  (C-009 revizyonu + 2026-10-29/30 yönü; çekirdek JS paritesi bozulmaz);
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
