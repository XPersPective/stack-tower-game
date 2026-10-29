# Stack Tower Game

Tek dokunuşla oynanan neon kule oyunu — Flutter (Android + iOS).
150 bölüm, 10 farklı oyun türü, günlük meydan okuma, görünür inşaat meta'sı ve
günlük tazelenen pazar yeri.

Proje durumu ve iş listesi `.project-brain/` altında tutulur (tek gerçek kaynak):
`current.md` (mevcut mimari), `target.md` (hedef), `tasks/` (açık işler),
`decisions/` (ADR'ler).

## Gereksinimler

- Flutter 3.47.x (Dart 3.13.x), `flutter doctor` temiz
- Android: JDK 17 + Android SDK; iOS: Xcode 15+ (yalnız macOS)

## Kurulum

```bash
flutter pub get
flutter test          # 320+ test
flutter analyze
flutter run           # bağlı cihaz/emülatör
```

> **Proxy notu (Windows/CI):** `flutter test` bazı ortamlarda `HTTP(S)_PROXY`
> değişkenleri yüzünden `flutter_tester` websocket'ine bağlanamaz. Testleri
> `env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy flutter test`
> ile koşun.

## Ses varlıkları

Sesler depoya **üretilmiş WAV** olarak girer (ADR-003), çalışma anında sentez yok:

```bash
dart run tools/gen_sounds.dart           # 21 dosya üretir
dart run tools/gen_sounds.dart --check   # eksik dosya varsa hata
```

Kombo katmanları (`layer1-3.wav`) 4 bar × 120 BPM loop'tur; `AudioController.setCombo`
3/6/10 eşiklerinde açar, kombo kırılınca 220 ms fade-out yapar.

## İkonlar

`reference/assets/icon-1024.png` tek kaynaktır. Üretmek için:

```bash
PB_ICONS=1 flutter test test/tools/gen_icons_test.dart
```

Android mipmap'leri (legacy + adaptive foreground) ve iOS AppIcon setini yeniden yazar.
Adaptive icon arka planı `#0A0A1E`.

## Backend (skor tahtası, isteğe bağlı)

`worker/` — Cloudflare Workers + D1 (ücretsiz katman). Kurulum, uçlar ve testler:
[`worker/README.md`](worker/README.md).

```bash
cd worker && node --experimental-strip-types --test test/*.test.ts
```

İstemci tarafı `lib/services/leaderboard_service.dart` (kalıcı kuyruk, "skor asla
kaybolmaz") ve `lib/services/session.dart` (oturum) hazırdır. Native giriş SDK'larının
bağlanması PB-031'de planlıdır; o zamana kadar uygulama tamamen çevrimdışı çalışır ve
yerel rakip tahtasını kullanır.

## Mağaza paketi

- `store/google-play.md`, `store/app-store.md` — metinler + veri güvenliği tabloları
- `store/privacy-policy.html` — yayımlanacak gizlilik politikası
- `.github/workflows/build.yml` — analyze + test + appbundle artifact

### Sürüm

`pubspec.yaml` → `version: 1.0.0+1` (semver+build). Android `versionCode` bu build
numarasından gelir; her mağaza yüklemesinde +1 artırın. Paket kimliği geliştirme
sürümünde `com.stacktower.stack_tower_game`; yayın kimliği (TD-001) netleşince
`android/app/build.gradle.kts` ve iOS bundle id birlikte güncellenmelidir.

## Yayın öncesi manuel cihaz listesi

Otomatik testlerin kapsamadığı, cihazda elle doğrulanacak maddeler:

- [ ] Dikey kilit her iki platformda (döndürme yok)
- [ ] Geri tuşu: oyun içinde çift dokunma onayı, haritada çıkış
- [ ] Ses aç/kapat kalıcı; uygulama yeniden açıldığında korunuyor
- [ ] Titreşim ayarı cihazda etkili (juice haptic desenleri duyuluyor)
- [ ] Kombo merdiveni: 3/6/10'da katmanlar duyuluyor, kombo kırılınca sönüyor
- [ ] 60 fps: en yoğun anda (kritik + konfeti) kare düşmesi yok
- [ ] Uçak modu: 150 bölüm + günlük + pazar tam çalışır
- [ ] Pazar: gün değişiminde tezgah tazelenir, satın alma bakiyeyi düşürür
- [ ] İnşaat: bölüm sonunda ada parçası yükselir, dünya bitince anıt
- [ ] Erişilebilirlik: büyük yazı boyutunda taşma yok, Semantics ipuçları okunuyor
- [ ] Düşük güç modu: ses/animasyon çökme yok

## Lisans

`LICENSE` dosyasına bakın. Yazı tipi: Inter (SIL OFL, `assets/fonts/OFL.txt`).
