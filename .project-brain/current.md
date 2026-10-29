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
- `lib/game/mini_game.dart` + `lib/game/kinds/*` — antoloji: MiniGame sözleşmesi + 7 mini-oyun (stack,catcher,ring,launch,merge,path,sort)
- `lib/preview/preview_painter.dart` — önizleme sahnesi painter'ı (preview.js draw birebir; PB-009 kabul)
- `lib/game/audio.dart` — ses denetleyicisi (varlıklar PB-010'da üretilir; eksik varlık güvenli)
- `lib/screens/*` — menu, map(hub), preview, play+HUD, flow_overlays(kutu→tören→tahta→sonuç), shop+relics, missions, settings, router
- `lib/theme/tokens.dart` — THEMES 10 palet + NeonPalette + Inter (variable font)
- `lib/services/storage.dart` — KeyValueStorage (SharedPreferences/Memory)
- `test/` — 23 dosya / 233 test öğesi (flutter test 2026-10-26): parite snapshot, ekonomi, drop, motor, twist, ekran akışları, antoloji mini-oyunlar
- `tools_js/gen_levels_snapshot.js` — JS parite fixture üreteci (node)
- `worker/` — HENÜZ YOK (SPEC §7 backend; PB-012)

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
- harita şu an işlevsel hub (grid) — PB-008 3B perspektife yükseltecek
- önizleme sinematik ekranı preview.js/ui.js sadakatli (PB-009 DONE: review PASS — günlük slot sırası, saveLayer hale, introLock düzeltildi; emülatör kayıt kanıtı evidence/PB-009/)
- twist duyuru toast'u play_screen'de (PB-015): Türkçe ad+hint, IgnorePointer, ToastHost yuva kuyruğu — eşzamanlı toast'lar üst üste binmez

### anthology
Status: OBSERVED (CATCH PB-023 + RING PB-024 + PATH/SORT PB-027 inceleme PASS ile kabul; LAUNCH/MERGE kodlandı+testlendi — görev akışları PB-025/PB-026 hâlâ READY; 10 türden 8'i oynanabilir)
Sources: `lib/game/mini_game.dart`, `lib/game/kinds/*.dart`, `test/{catch,ring,launch,merge,path,sort}_test.dart`
- MiniGame sözleşmesi; antoloji host play_screen içinde; RING tek halka uygulandı (çoklu iç/dış halka kapsam dışı — PB-024 inceleme MINOR)

### construction-meta
Status: OBSERVED (PB-029 kodlandı: tamamlanan bölüm adada yapı parçası yükseltir; görev akışı açık)
Sources: `lib/game/game_session.dart`, `lib/screens/flow_overlays.dart`

### theme
Status: VERIFIED (kThemes 10/10 alan bağımsız karşılaştırmayla eşleşti; Inter variable woff2→ttf)

### services
Status: OBSERVED (storage soyutlaması VERIFIED; leaderboard/session henüz yok — PB-011)

### backend
Status: UNKNOWN (worker/ yok; SPEC §7.3-7.4 tanımlı — PB-012)

## Known Unknowns
- map.js/preview.js satır satır port detayları (PB-008/009'da okunacak)
- Ses varlık üretimi WebAudio parametre birebirliği (PB-010)
- Eşzamanlı oturum riski: bu makinede başka bir ajan (zcode-glm53) Brain görevlerini araya girip sahipleniyor — atomik takeover+accept komutlarıyla yönetiliyor
