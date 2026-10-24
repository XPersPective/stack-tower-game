# Current Architecture

Verified present reality only. Markers: VERIFIED | OBSERVED | INFERRED | STALE | UNKNOWN.

## Runtime
- Hedef: Flutter (tek kod tabanı, Android+iOS); geliştirme Windows host, Flutter 3.47.2 stable / Dart 3.13.2 (VERIFIED)
- Kaynak oyun: HTML/JS + Capacitor; referans olarak `reference/www/` içinde donduruldu (VERIFIED)

## Map
<!-- path — role. Orientation index: read this instead of exploring. <=40 lines. -->
- `docs/SPEC.md` — yetkili spec (devir brifingi, Stack Tower Game olarak rebrand edildi)
- `reference/www/levels.js` — 10 tema + 150 bölüm + denge formülleri (saf; port kaynağı)
- `reference/www/progress.js` — ekonomi/kayıt katmanı (saf + storage soyutlaması; port kaynağı)
- `reference/www/game.js` — motor: CORE saf çekirdek + render/ses/akış (port kaynağı)
- `reference/www/map.js` — 3B perspektif takımada haritası (70KB; port kaynağı)
- `reference/www/preview.js` — sinematik bölüm önizlemesi (port kaynağı)
- `reference/www/ui.js` + `index.html` + `style.css` — ekran akışları + neon stil (port kaynağı)
- `reference/www/leaderboard.js` + `lb-config.js` — ESKİ GC/PGS köprüsü; davranış (kuyruk/en-yüksek-skor) korunur, taşıyıcı Cloudflare olur
- `reference/test.js`, `reference/smoke.js` — çalışan davranış spesifikasyonu (Dart test kaynağı)
- `reference/assets/` — simge/mağaza görselleri; `reference/store/` — mağaza metinleri
- `lib/`, `test/`, `worker/` — hedef yapı (SPEC §4); oluştukça buraya işlenir

## Domains

### game-core
Status: UNKNOWN (port edilmedi; kaynak referans/www/{levels,progress}.js okundu, anlaşıldı)
Sources: `reference/www/levels.js`, `reference/www/progress.js`
- Saf fonksiyonlar + saf veri; Dart karşılığı `lib/game/{levels,progress,drop_core}.dart`
- Denge formülleri SPEC §2.3'te özetlendi; tek doğruluk kaynağı JS dosyaları

### game-engine
Status: UNKNOWN (port edilmedi; kaynak referans/www/game.js okundu: CORE + tick/render akışı)
Sources: `reference/www/game.js`
- resolveDrop/travelRange/movingBounds/speedMultiplier/stepMoving/growthWidth saf çekirdek;
  motor durumu idle|playing|won|lost; efekt havuzları debris/particles/rings/popups/confetti

### screens
Status: UNKNOWN (port edilmedi; ekran envanteri çıkarıldı: menu, map, hud, intro/preview,
result, box, shop, relics, missions, board, settings)

### theme
Status: UNKNOWN (port edilmedi; kaynak THEMES 10 palet + style.css + Inter fontu reference/www/fonts/)

### services (storage/leaderboard/session)
Status: UNKNOWN (port edilmedi; kaynak leaderboard.js kuyruk mantığı + SPEC §7 hedef mimarisi)

### backend
Status: UNKNOWN (`worker/` henüz yok; şema+uçlar SPEC §7.3-7.4'te tanımlı)

## Known Unknowns
- map.js/preview.js ayrıntıları henüz satır satır okunmadı (port sırasında okunacak; boyut 70KB+17KB)
- Ses üretimi: WebAudio ton karşılığı ADR-003 yaklaşımıyla doğrulanacak
