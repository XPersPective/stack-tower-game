# Current Architecture

Verified present reality only. Markers: VERIFIED | OBSERVED | INFERRED | STALE | UNKNOWN.

## Runtime
- Flutter (tek kod tabanı, Android+iOS); Flutter 3.47.2 stable / Dart 3.13.2, Windows host (VERIFIED)
- Paket kimliği (geliştirme): com.stacktower.stack_tower_game; uygulama adı "Stack Tower Game" (VERIFIED)
- Kaynak oyun: HTML/JS + Capacitor; `reference/www/` içinde donduruldu (VERIFIED)
- Premium katman: aurora canlı gökyüzü + cam panel + gradyan buton kütüphanesi `lib/ui/`; ortam animasyonları `AmbientMotion` kapısıyla testte kapalı (VERIFIED — PB-031 kapanışı)

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
- `lib/game/audio.dart` — ses denetleyicisi (27 varlık; eksik varlık güvenli); +6 premium WAV (assets/sounds/)
- `lib/screens/*` — menu, map(3B takımada), preview, play+HUD, flow_overlays(kutu→tören→tahta→sonuç), market, shop+relics, missions, settings, router
- `lib/ui/{premium_kit,aurora_background,ambient}.dart` — premium ortak kit (cam panel, gradyan buton, giriş animasyonları, canlı gökyüzü, AmbientMotion kapısı)
- `lib/widgets/{gift_box,monument_ceremony}.dart` — hediye kutusu + dünya anıtı töreni (ışık köprüleri)
- `lib/ui/premium_kit.dart` — **ortak premium bileşenler** (PB-032): GlassPanel, GradientButton, PressableCard, PremiumHeader, ResourceChip, CountUpText, GradientTitle, FadeSlideIn, InfoChip, CoinGlyph, StarGlyph
- `lib/ui/aurora_background.dart` — **canlı arka plan** (PB-032): aurora şeritleri, paralaks yıldız, gezegen, vinyet
- `lib/ui/ambient.dart` — **ortam animasyonu kapısı** (PB-032): üretimde açık, testte kapalı
- `lib/widgets/gift_box.dart` — hediye kutusu açılış animasyonu (PB-032)
- `lib/widgets/construction_art.dart`, `lib/widgets/monument_ceremony.dart` — inşaat + dünya töreni görselleri + premium sayfa geçişleri
- `lib/services/storage.dart` — KeyValueStorage (SharedPreferences/Memory)
- `lib/services/leaderboard_service.dart` — kalıcı skor kuyruğu + toplu flush + fetchBoard (dart:io taşıyıcı, ek paket yok)
- `lib/services/session.dart` — oturum belirteci (SecureStore soyutlaması), AuthProvider arayüzü, hesap silme
- `test/` — 336 test öğesi (flutter test 2026-10-30, hepsi yeşil): parite snapshot, ekonomi, drop, motor, twist, juice, ekran akışları, antoloji mini-oyunlar, pazar, dağıtım, duman + entegrasyon, skor istemcisi, premium anlık görüntü + ayarlar etkileşimi
- `tools_js/gen_levels_snapshot.js` — JS parite fixture üreteci (node)
- `worker/` — Cloudflare Workers + D1 API (auth/me/leaderboard/score/account; jwt.ts + providers.ts + logic.ts; node:test 12 test, 2026-10-30 yeşil)
- `store/` — mağaza metinleri + gizlilik politikası; `.github/workflows/build.yml` — CI (analyze/test/appbundle)
- `android/app/**` + `ios/Runner/**` — platform kabukları (ikon/splash PB-014, native kimlik yapılandırması PB-031: Podfile, Info.plist yer tutucuları)
- `tools/gen_sounds.dart` — 27 ses varlığı üreteci; `test/tools/gen_icons_test.dart` — ikon seti üreteci (PB_ICONS=1)
- `README.md` — kurulum + test + Üretim adımları (OAuth id'leri, Apple yeteneği, worker deploy)

## Domains

### game-core
Status: VERIFIED (levels/progress/drop_core birebir port; JS snapshot + birim testler; bağımsız inceleme PASS; twist dağıtım yasası PB-015 DONE — review PASS)
Sources: `lib/game/{levels,progress,drop_core,twists}.dart`, `test/{levels,progress,drop_core,twists}_test.dart`
- Kayıt anahtarı stacktower_save_v2; 60 para başlangıç; şema SPEC §5 (ADR-001)
- twist yasası: yalnız stack bölümleri twist alır, 1. stack twistsiz, ilk-5 [null,altın,rüzgar,zıt,kritik], ardışık ≤2; mevcut 9 modifier aynen (çiftkule C-002 kapsam dışı)

### game-engine
Status: VERIFIED (gameplay+scene_painter JS birebir; 13 motor testi; inceleme PASS — MAJOR karanlık perde durakları düzeltildi; twist kancaları PB-015 DONE; juice paketi PB-016 DONE — ADR-010; **PB-033 sunum katmanı: repaint onarımı + alt-adım + imza/zoom/ateş/final — inceleme sürüyor**)
Sources: `lib/game/{gameplay,scene_painter,twists}.dart`, `lib/game/levels.dart`, `test/{gameplay,twists,levels}_test.dart`
- render sırası game.js render() ile aynı; dt clamp 0.05 play_screen'de
- twist kancaları (spawn yönü/açısı, daralan duvar + uçuş clamp'i, altın/kritik zarı, hayalet ikiz, hit-stop) `twist != null` koşullu — twistsiz bölümlerde referans pacing birebir; drop_core paritesine dokunmaz (C-002); KRİTİK ×5 + altın blok paraları onWin'de cüzdana ödenir
- juice (PB-016, ADR-010): hit-stop her mükemmelde 40ms+4ms×kombo (tavan 70ms, kritik dahil), squash&stretch 120ms ±%12, tam-ekran flaş (mükemmel α0.18 tema / kritik α0.35 beyaz, 90ms), haptic desenleri (`HapticPatternHost`, başlangıç anları), 12 konfeti + yıldız izi, `_fxRnd` sunum RNG'si; efektler `fxDt` saatiyle akar; hit-stop penceresinde dokunuş `InputGate` ile yok sayılır
- **PB-033 sunum katmanı (kayıma kök nedeni onarıldı):** play_screen `_MiniGamePainter` artık `repaint` listenable bağlı (`_SceneRepaint`, her tik notify) + `RepaintBoundary` — PB-022'de kopan kare-başı render döndü (kamera inişi/süzülen blok her karede); dt sabit alt-adım (≤1/60, tavan 3) host'ta; kamera zoom A4 (8+ blok 0.92, kazanınca fit, pivot alt-merkez); ateş modu A2 (combo≥3 kor izi `_fxRnd`'li); A1 parlak 2. halka; B1 final rotasyonu `finaleFor(i)` 4 stil (konfeti/meteor/kuş/aurora, ardışık çakışmasız); popup Picture önbelleği (LRU 240, alpha 12 adım); `levelSignature(i)` deterministik hue/skyPhase/silVariant — dünya içinde 15 bölüm farklı palet fazında (A3: 60sn ±4° hue döngüsü); C-002 korunur (drop_core diff boş); **oynanabilirlik onarımı: resize() taban bloğu (w-baseW)/2'ye sabitleyip kuleyi aynı deltayla taşır (initState w=0 dünyası + ilk-kare-sonrası resize akışı kuleyi sol kenarda yarı kesik doğuruyordu — kullanıcı raporu, birim testli)**

### screens
Status: OBSERVED (tüm ekranlar emülatörde çalışıyor: menü→harita→önizleme→oyun→sonuç→mağaza/görevler; ekran kanıtları .project-brain/evidence/PB-006/)
Sources: `lib/screens/**`, `lib/preview/**`, `lib/ui/**`, `test/{widget,play_screen,screens,preview,premium_snapshot}_test.dart`
- harita 3B takımada + inşaat önizlemesi; dünya panelinde "SIRADA: <yapı> · n/m" ipucu (metin + Semantics)
- önizleme sinematik ekranı preview.js/ui.js sadakatli (PB-009 DONE: review PASS — günlük slot sırası, saveLayer hale, introLock düzeltildi; görsel kanıt evidence/PB-030/kind_card.png + PB-031)
- twist duyuru toast'u play_screen'de (PB-015): Türkçe ad+hint, IgnorePointer, ToastHost yuva kuyruğu — eşzamanlı toast'lar üst üste binmez
- önizleme tür kartı (PB-030): "BU BÖLÜM: <tür>" + ipucu + "SIRADA: <sonraki tür>" — oyuncu bölüme girmeden oyunu bilir
- dağıtım (PB-030): 150 bölümde ardışık aynı tür yok, ilk-5 beş farklı tür, patron imza türleri 10/10 farklı; tür ödülü: stack 0 (twist parası ayrı), diğerleri 2/3 — rapor=cüzdan
- menü takımyıldızı (PB-033 tur 2): _SkyPainter bağlantı çizgisi PaintingStyle.stroke'suzdu — FILL dolgu dev gri açısal poligonlar çiziyordu (kullanıcı raporu); stroke + yakın-2-komşu takımyıldız ağı; aurora şeritleri yuvarlak join/cap + doygun-dar
- arka plan müziği (PB-033 tur 2): prosedürel dikişsiz döngü music_loop.wav (84 BPM, I–V–vi–IV pad+arp+bas, 8 bar ≈ 22.9 sn, 22050 Hz mono ~1 MB; gen_sounds musicLoop); AudioController.ensureMusic — mute'ta duraklar, açınca sürer; main'de başlatılır
- bölüm imzası (PB-033): `levelSignature(i)` önizleme paletine + oyun sahnesi temasına kayma uygular; önizleme parça sayıları değişmez (preview_test korunur)
- yenilgi ekranı (PB-033 C5): bölüm kaybında "NEREDEYSE!" + "Rekoruna N blok kaldı" amber satırı (endless/daily metni korunur)
- premium katman (PB-031): aurora zemin + cam kartlar + gradyan butonlar; menü nefes alan logo; ayarlar G/Ç + hesap silme (onaylı, hata yolunda oturum korunur); 390×844 + 360×640'da taşmasız (snapshot + widget test kanıtı)

### anthology
Status: VERIFIED (10/10 tür oynanabilir; PB-022/023/024/027/028 + PB-025/026 kabul edildi — denetimde LAUNCH hedeflerinin (0,0)'da doğması ve MERGE tahtasının hiç dolmaması düzeltildi)
Sources: `lib/game/mini_game.dart`, `lib/game/kinds/*.dart`, `test/{catch,ring,launch,merge,path,sort}_test.dart`
- MiniGame sözleşmesi; antoloji host play_screen içinde; RING tek halka uygulandı (çoklu iç/dış halka kapsam dışı — PB-024 inceleme MINOR)

### construction-meta
Status: VERIFIED (PB-029 DONE: tamamlanan bölüm adada yapı parçası yükseltir; haritada 1.2s ease-out yükselme + parıltı, blueprint metin/Semantics ipucu; dünya anıtı töreni görseli + harita obeliski PB-031 premium kapanışında: `MonumentCeremony` (ışık köprüleri) + `_drawMonument`)
Sources: `lib/map/construction.dart`, `lib/map/map3d.dart`, `lib/screens/map_screen.dart`, `lib/screens/flow_overlays.dart`, `lib/widgets/monument_ceremony.dart`

### theme
Status: VERIFIED (kThemes 10/10 alan bağımsız karşılaştırmayla eşleşti; Inter variable woff2→ttf; premium token'ları + Cupertino sayfa geçişleri PB-031)

### services
Status: VERIFIED (storage + skor kuyruğu + oturum; PB-011 DONE; native kimlik PB-031)
- kuyruk: board+day başına en yüksek skor, tavan 50, kalıcı; flush tek eşzamanlı, hata → kuyruk korunur; fetchBoard hata → null (yerel tahtaya düşer)
- oturum: belirteç FlutterSecureStore'da (keychain/keystore; PrefsSecureStore yalnız testte); GoogleAuthProvider/AppleAuthProvider; Apple butonu yalnız iOS (C-011); e-posta yok; hesap silme YALNIZ sunucu onayından sonra yerel temizlik (hata → oturum korunur)
- tahta: `boardIsCloud` bayrağı — "Bulut tahtası" rozeti yalnız gerçek bulut görünümü uygulanınca görünür

### backend
Status: VERIFIED kod (worker/ DONE; deploy edilmedi — wrangler + D1 hesabı gerekir)
- uçlar: POST /auth/google|apple, GET /me, GET /leaderboard, POST /score, DELETE /account; HS256 oturum (30g), RS256+JWKS sağlayıcı doğrulama, UTC gün, tavanlar, hız sınırı
- testler: node --experimental-strip-types --test → 12/12 (D1 entegrasyonu miniflare gerektirir, koşulmadı)

## Known Unknowns
- dünya anıtı töreni ÇÖZÜLDÜ: `MonumentCeremony` widget'ı (flow_overlays world adımı) + haritada tamamlanan dünyalarda `_drawMonument` (ışık köprüli obelisk) — construction-meta kapsamında PB-031 ile kapandı.
- native giriş SDK'ları BAĞLANDI (google_sign_in v7 / sign_in_with_apple / flutter_secure_storage) — PB-031 DONE. Gerçek OAuth istemci id'leri + Sign in with Apple yeteneği + worker deploy = geliştirici adımı (README "Üretim adımları"). Tanımsızsa çevrimdışı çalışır.
- TD-001 yayın paket kimliği açık; TD-002 tahtada ad (şu an otomatik takma ad)
- Ses varlık üretimi WebAudio parametre birebirliği (PB-010) — DONE (27 WAV, analyze/test yeşil)
- **PB-032 ÜRETIM DÜZELTMESİ:** release (APK/AAB) derlemesinde INTERNET izni YOKTU (yalnız debug/profile manifestlerinde vardı) → Google/Apple girişi ve bulut skor tahtası üretimde sessizce ölüydü. Ana manifest'e eklendi. Release imzası `key.properties` ile, R8 + shrink etkin, ProGuard kuralları eklendi, Android 12+ splash eklendi.
- **PB-032 TEST KIRILGANLIĞI DÜZELTİLDİ:** `test/market_test.dart` tarihe bağlıydı (prepareLevel → günün sürpriz döngüsü) → her 4 günde bir kendiliğinden kırılıyordu. Saat enjeksiyonu ile deterministik yapıldı.
- Eşzamanlı oturum riski: bu makinede başka bir ajan (zcode-glm53) Brain görevlerini araya girip sahipleniyor — atomik takeover+accept komutlarıyla yönetiliyor
