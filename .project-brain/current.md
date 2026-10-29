# Current Architecture

Verified present reality only. Markers: VERIFIED | OBSERVED | INFERRED | STALE | UNKNOWN.

## Runtime
- Flutter (tek kod tabanı, Android+iOS); Flutter 3.47.2 stable / Dart 3.13.2, Windows host (VERIFIED)
- Paket kimliği (geliştirme): com.stacktower.stack_tower_game; uygulama adı "Stack Tower Game" (VERIFIED)
- Kaynak oyun: HTML/JS + Capacitor; `reference/www/` içinde donduruldu (VERIFIED)

## Map
<!-- path — role. Orientation index: read this instead of exploring. <=40 lines. -->
- `docs/SPEC.md` — yetkili spec (devir brifingi, Stack Tower Game rebrand)
- `lib/game/levels.dart` — 10 tema + 150 bölüm + günlük/serbest (JS birebir; 150×12 alan snapshot paritesi)
- `lib/game/progress.dart` — ekonomi/kayıt (JS birebir; SaveState SPEC §5 şeması, LCG rakipler)
- `lib/game/drop_core.dart` — saf bırakma matematiği (game.js CORE birebir)
- `lib/game/twists.dart` — 7 twist türü + tur-farkında dağıtım yasası (yalnız stack bölümleri; ilk-5 şeması sabit)
- `lib/game/gameplay.dart` — motor durumu/tik/efekt havuzları (game.js birebir; ADR-002)
- `lib/game/scene_painter.dart` — tüm render katmanları (game.js render birebir; inceleme PASS)
- `lib/game/game_session.dart` — oturum/akış orkestrasyonu (ui.js onEngineEvent karşılığı)
- `lib/game/mini_game.dart` + `lib/game/kinds/*` — antoloji: MiniGame sözleşmesi + 10 mini-oyun (stack,catcher,ring,launch,merge,path,sort,balance,defend,rhythm) + opsiyonel yetenek arayüzleri (HapticPatternHost, InputGate, HoldGame)
- `lib/game/market.dart` — pazar yeri saf mantığı (gün tohumlu rotasyon, satın alma, sandık, kalıntı parçası)
- `lib/preview/preview_painter.dart` — önizleme sahnesi painter'ı (preview.js draw birebir; PB-009 kabul)
- `lib/game/audio.dart` — ses denetleyicisi (varlıklar PB-010'da üretilir; eksik varlık güvenli)
- `lib/screens/*` — menu, map(3B takımada), preview, play+HUD, flow_overlays(kutu→tören→tahta→sonuç), market, shop+relics, missions, settings, router
- `lib/theme/tokens.dart` — THEMES 10 palet + NeonPalette + Inter (variable font)
- `lib/services/storage.dart` — KeyValueStorage (SharedPreferences/Memory)
- `lib/services/leaderboard_service.dart` — kalıcı skor kuyruğu + toplu flush + fetchBoard (dart:io taşıyıcı, ek paket yok)
- `lib/services/session.dart` — oturum belirteci (SecureStore soyutlaması), AuthProvider arayüzü, hesap silme
- `test/` — 35+ dosya / 336 test öğesi (flutter test 2026-10-29): parite snapshot, ekonomi, drop, motor, twist, juice, ekran akışları, antoloji mini-oyunlar, pazar, dağıtım, duman + entegrasyon, skor istemcisi
- `tools_js/gen_levels_snapshot.js` — JS parite fixture üreteci (node)
- `worker/` — Cloudflare Workers + D1 API (auth/me/leaderboard/score/account; jwt.ts + providers.ts + logic.ts; node:test 12 test)
- `store/` — mağaza metinleri + gizlilik politikası; `.github/workflows/build.yml` — CI (analyze/test/appbundle)
- `tools/gen_sounds.dart` — 21 ses varlığı üreteci; `test/tools/gen_icons_test.dart` — ikon seti üreteci (PB_ICONS=1)

## Domains

### game-core
Status: VERIFIED (levels/progress/drop_core birebir port; JS snapshot + birim testler; bağımsız inceleme PASS; twist dağıtım yasası PB-015 DONE — review PASS)
Sources: `lib/game/{levels,progress,drop_core,twists}.dart`, `test/{levels,progress,drop_core,twists}_test.dart`
- Kayıt anahtarı stacktower_save_v2; 60 para başlangıç; şema SPEC §5 (ADR-001)
- twist yasası: yalnız stack bölümleri twist alır, 1. stack twistsiz, ilk-5 [null,altın,rüzgar,zıt,kritik], ardışık ≤2; mevcut 9 modifier aynen (çiftkule C-002 kapsam dışı)

### game-engine
Status: VERIFIED (gameplay+scene_painter JS birebir; 13 motor testi; inceleme PASS — MAJOR karanlık perde durakları düzeltildi; twist kancaları PB-015 DONE; juice paketi PB-016 DONE — ADR-010)
Sources: `lib/game/{gameplay,scene_painter,twists}.dart`, `test/{gameplay,twists}_test.dart`
- render sırası game.js render() ile aynı; dt clamp 0.05 play_screen'de
- twist kancaları (spawn yönü/açısı, daralan duvar + uçuş clamp'i, altın/kritik zarı, hayalet ikiz, hit-stop) `twist != null` koşullu — twistsiz bölümlerde referans pacing birebir; drop_core paritesine dokunmaz (C-002); KRİTİK ×5 + altın blok paraları onWin'de cüzdana ödenir
- juice (PB-016, ADR-010): hit-stop her mükemmelde 40ms+4ms×kombo (tavan 70ms, kritik dahil), squash&stretch 120ms ±%12, tam-ekran flaş (mükemmel α0.18 tema / kritik α0.35 beyaz, 90ms), haptic desenleri (`HapticPatternHost`, başlangıç anları), 12 konfeti + yıldız izi, `_fxRnd` sunum RNG'si; efektler `fxDt` saatiyle akar; hit-stop penceresinde dokunuş `InputGate` ile yok sayılır

### screens
Status: OBSERVED (tüm ekranlar emülatörde çalışıyor: menü→harita→önizleme→oyun→sonuç→mağaza/görevler; ekran kanıtları .project-brain/evidence/PB-006/)
Sources: `lib/screens/**`, `lib/preview/**`, `test/{widget,play_screen,screens,preview}_test.dart`
- harita 3B takımada + inşaat önizlemesi; dünya panelinde "SIRADA: <yapı> · n/m" ipucu (metin + Semantics)
- önizleme sinematik ekranı preview.js/ui.js sadakatli (PB-009 DONE: review PASS — günlük slot sırası, saveLayer hale, introLock düzeltildi; emülatör kayıt kanıtı evidence/PB-009/)
- twist duyuru toast'u play_screen'de (PB-015): Türkçe ad+hint, IgnorePointer, ToastHost yuva kuyruğu — eşzamanlı toast'lar üst üste binmez
- önizleme tür kartı (PB-030): "BU BÖLÜM: <tür>" + ipucu + "SIRADA: <sonraki tür>" — oyuncu bölüme girmeden oyunu bilir
- dağıtım (PB-030): 150 bölümde ardışık aynı tür yok, ilk-5 beş farklı tür, patron imza türleri 10/10 farklı; tür ödülü: stack 0 (twist parası ayrı), diğerleri 2/3 — rapor=cüzdan

### anthology
Status: VERIFIED (10/10 tür oynanabilir; PB-022/023/024/027/028 + PB-025/026 kabul edildi — denetimde LAUNCH hedeflerinin (0,0)'da doğması ve MERGE tahtasının hiç dolmaması düzeltildi)
Sources: `lib/game/mini_game.dart`, `lib/game/kinds/*.dart`, `test/{catch,ring,launch,merge,path,sort}_test.dart`
- MiniGame sözleşmesi; antoloji host play_screen içinde; RING tek halka uygulandı (çoklu iç/dış halka kapsam dışı — PB-024 inceleme MINOR)

### construction-meta
Status: VERIFIED (PB-029 DONE: tamamlanan bölüm adada yapı parçası yükseltir; haritada 1.2s ease-out yükselme + parıltı, blueprint metin/Semantics ipucu; dünya anıtı töreni görseli PB-030'da)
Sources: `lib/map/construction.dart`, `lib/map/map3d.dart`, `lib/screens/map_screen.dart`, `lib/screens/flow_overlays.dart`

### theme
Status: VERIFIED (kThemes 10/10 alan bağımsız karşılaştırmayla eşleşti; Inter variable woff2→ttf)

### services
Status: VERIFIED (storage + skor kuyruğu + oturum; PB-011 DONE)
- kuyruk: board+day başına en yüksek skor, tavan 50, kalıcı; flush tek eşzamanlı, hata → kuyruk korunur; fetchBoard hata → null (yerel tahtaya düşer)
- oturum: belirteç SecureStore'da (üretimde PrefsSecureStore; native keychain PB-031), e-posta yok, hesap silme yerel temizlikle

### backend
Status: VERIFIED kod (worker/ DONE; deploy edilmedi — wrangler + D1 hesabı gerekir)
- uçlar: POST /auth/google|apple, GET /me, GET /leaderboard, POST /score, DELETE /account; HS256 oturum (30g), RS256+JWKS sağlayıcı doğrulama, UTC gün, tavanlar, hız sınırı
- testler: node --experimental-strip-types --test → 12/12 (D1 entegrasyonu miniflare gerektirir, koşulmadı)

## Known Unknowns
- dünya anıtı töreni (ışık köprüleri) henüz görsel değil (PB-031 sonrası polish)
- native giriş SDK'ları bağlı değil (google_sign_in / Sign in with Apple / secure storage) — PB-031
- TD-001 yayın paket kimliği açık; TD-002 tahtada ad (şu an otomatik takma ad)
- Ses varlık üretimi WebAudio parametre birebirliği (PB-010)
- Eşzamanlı oturum riski: bu makinede başka bir ajan (zcode-glm53) Brain görevlerini araya girip sahipleniyor — atomik takeover+accept komutlarıyla yönetiliyor
