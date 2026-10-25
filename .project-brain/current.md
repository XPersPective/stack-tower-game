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
- `lib/game/gameplay.dart` — motor durumu/tik/efekt havuzları (game.js birebir; ADR-002)
- `lib/game/scene_painter.dart` — tüm render katmanları (game.js render birebir; inceleme PASS)
- `lib/game/game_session.dart` — oturum/akış orkestrasyonu (ui.js onEngineEvent karşılığı)
- `lib/game/audio.dart` — ses denetleyicisi (varlıklar PB-010'da üretilir; eksik varlık güvenli)
- `lib/screens/*` — menu, map(hub), preview, play+HUD, flow_overlays(kutu→tören→tahta→sonuç), shop+relics, missions, settings, router
- `lib/theme/tokens.dart` — THEMES 10 palet + NeonPalette + Inter (variable font)
- `lib/services/storage.dart` — KeyValueStorage (SharedPreferences/Memory)
- `test/` — 69 test: parite snapshot, ekonomi, drop, motor, ekran akışları
- `tools_js/gen_levels_snapshot.js` — JS parite fixture üreteci (node)
- `worker/` — HENÜZ YOK (SPEC §7 backend; PB-012)

## Domains

### game-core
Status: VERIFIED (levels/progress/drop_core birebir port; JS snapshot + birim testler; bağımsız inceleme PASS)
Sources: `lib/game/{levels,progress,drop_core}.dart`, `test/{levels,progress,drop_core}_test.dart`
- Kayıt anahtarı stacktower_save_v2; 60 para başlangıç; şema SPEC §5 (ADR-001)

### game-engine
Status: VERIFIED (gameplay+scene_painter JS birebir; 13 motor testi; inceleme PASS — MAJOR karanlık perde durakları düzeltildi)
Sources: `lib/game/{gameplay,scene_painter}.dart`, `test/gameplay_test.dart`
- render sırası game.js render() ile aynı; dt clamp 0.05 play_screen'de

### screens
Status: OBSERVED (tüm ekranlar emülatörde çalışıyor: menü→harita→önizleme→oyun→sonuç→mağaza/görevler; ekran kanıtları .project-brain/evidence/PB-006/)
Sources: `lib/screens/**`, `test/{widget,play_screen,screens}_test.dart`
- harita şu an işlevsel hub (grid) — PB-008 3B perspektife yükseltecek
- önizleme sinematik metin/siluet — PB-009 preview.js sadakat cilası

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
