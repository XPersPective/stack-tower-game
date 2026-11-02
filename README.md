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
flutter test          # 341 test
flutter analyze
flutter run           # bağlı cihaz/emülatör
```

> **Proxy notu (Windows/CI):** `flutter test` bazı ortamlarda `HTTP(S)_PROXY`
> değişkenleri yüzünden `flutter_tester` websocket'ine bağlanamaz. Testleri
> `env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy flutter test`
> ile koşun.

## Premium arayüz katmanı

Ortak bileşenler `lib/ui/` altında toplandı — yeni ekranlar bunları kullanmalı:

| Dosya | İçerik |
|---|---|
| `lib/ui/premium_kit.dart` | `GlassPanel`, `GradientButton`, `PressableCard`, `PremiumHeader`, `ResourceChip`, `CountUpText`, `GradientTitle`, `FadeSlideIn`, `InfoChip`, `CoinGlyph`, `StarGlyph` |
| `lib/ui/aurora_background.dart` | `AuroraBackground` — canlı aurora gökyüzü, paralaks yıldız alanı, ışınlı gezegen, vinyet |
| `lib/ui/ambient.dart` | `AmbientMotion` — ortam animasyonu kapısı |

**Ortam animasyonu kuralı (test güvenliği):** Widget testlerinde
`pumpAndSettle` sonsuz bir animasyonla asla "durulmaz". Bu yüzden sürekli
akan arka plan animasyonları `AmbientMotion` kapısına bağlıdır: uygulama
açılışında (`main()`) açılır, testte kapalı kalır. Ayrıca premium kitte
`Future.delayed`/`Timer` **kullanılmaz** — gecikmeler `AnimationController` +
`Interval` ile ifade edilir (pending timer hatasını önler).

## Ses varlıkları

Sesler depoya **üretilmiş WAV** olarak girer (ADR-003), çalışma anında sentez yok:

```bash
dart run tools/gen_sounds.dart           # 27 dosya üretir
dart run tools/gen_sounds.dart --check   # eksik dosya varsa hata
```

Kombo katmanları (`layer1-3.wav`) 4 bar × 120 BPM loop'tur; `AudioController.setCombo`
3/6/10 eşiklerinde açar, kombo kırılınca 220 ms fade-out yapar.

Arayüz sesleri (`tap`, `whoosh`, `reward`, `unlock`, `error`, `pop`) buton
dokunuşu, ödül kazanımı ve hata geri bildirimini sesle destekler.

## İkonlar

`reference/assets/icon-1024.png` tek kaynaktır. Üretmek için:

```bash
PB_ICONS=1 flutter test test/tools/gen_icons_test.dart
```

Android mipmap'leri (legacy + adaptive foreground) ve iOS AppIcon setini yeniden yazar.
Adaptive icon arka planı `#0A0A1E`.

## Backend (skor tahtası + kimlik, isteğe bağlı)

`worker/` — Cloudflare Workers + D1 (ücretsiz katman). Kurulum, uçlar ve testler:
[`worker/README.md`](worker/README.md).

```bash
cd worker && node --experimental-strip-types --test test/*.test.ts
```

İstemci tarafı hazırdır:
- `lib/services/leaderboard_service.dart` — kalıcı kuyruk ("skor asla kaybolmaz", C-005),
  oturum varsa bulut tahtasına flush.
- `lib/services/session.dart` — `SessionService` + `GoogleAuthProvider` /
  `AppleAuthProvider` + `FlutterSecureStore` (keychain/keystore).

### Üretim için tamamlanması gereken adımlar (PB-031 + PB-032)

Kod bağlıdır; yayın öncesi aşağıdaki gizli değerler geliştirici hesabınızdan girilmelidir:

1. **Backend dağıtımı:** `worker/` → Cloudflare'a deploy. Worker URL'sini
   `--dart-define=LB_API_BASE=https://<sub>.workers.dev` ile derlemede verin
   (varsayılan placeholder güvenle başarısız olur, oyun çevrimdışı devam eder).
2. **Android imza anahtarı:** `android/key.properties` oluşturun (repoya
   GİRMEZ, `.gitignore`'da):

   ```properties
   storePassword=<keystore parolası>
   keyPassword=<anahtar parolası>
   keyAlias=upload
   storeFile=<path/to/upload-keystore.jks>
   ```

   Anahtarı üretin: `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA
   -keysize 2048 -validity 10000 -alias upload`. Bu dosya yoksa release derlemesi
   **debug anahtarıyla** imzalanır (CI artifact'i için çalışır, mağaza teslimi
   için YETERSİZDİR).
3. **Google Sign-In:** Google Cloud Console'dan iOS + Android OAuth istemci id'leri alın.
   - `ios/Runner/Info.plist` → `GIDClientID` ve `CFBundleURLSchemes` (ters çevrilmiş
     istemci id) gerçek değerlerle değiştirin (`YOUR_IOS_CLIENT_ID...` yer tutucuları).
   - Android: `android/app/google-services.json` ekleyin (SHA-1/SHA-256 parmak izi).
4. **Sign in with Apple:** Apple Developer'da "Sign in with Apple" yeteneğini etkinleştirin
   (Xcode → Signing & Capabilities). `ios/Runner/Runner.entitlements` hazır; geliştirici
   hesabında yetenek etkin olmalıdır. `GoogleAuthProvider`/`AppleAuthProvider` kod
   tarafında hazırdır; iOS 13+ gerektirir.
5. **Gizlilik:** `store/privacy-policy.html` yayımlanmalı; uygulama içi hesap silme
   (Ayarlar → HESABI SİL) ve yerel veri temizliği mevcuttur (SPEC §7.6).

> OAuth/gizli değerler repoya KONMAZ. Tanımsızsa uygulama tamamen çevrimdışı çalışır ve
> yerel rakip tahtasını kullanır.

### Android release derlemesi (PB-032)

Release derlemesi artık üretim hazırdır:

- **INTERNET izni** ana manifest'te (`android/app/src/main/AndroidManifest.xml`) —
  önceden yalnız debug/profile manifestlerinde vardı; release'de olmadığı için
  giriş ve bulut skor tahtası üretimde çalışmıyordu.
- **R8** etkin: `isMinifyEnabled` + `isShrinkResources`; kurallar
  `android/app/proguard-rules.pro` dosyasında (Flutter + native kimlik SDK'ları +
  secure storage + audioplayers için keep kuralları).
- **Android 12+ splash ekranı** (`values-v31/styles.xml`) — açılışta beyaz flaş yok.
- **Desugaring** etkin — `java.time` API'leri minSdk'ta da çalışır.

```bash
flutter build appbundle --release   # mağaza paketi (AAB)
flutter build apk --release         # doğrudan APK
```

## Mağaza paketi

- `store/google-play.md`, `store/app-store.md` — metinler + veri güvenliği tabloları
- `store/privacy-policy.html` — yayımlanacak gizlilik politikası
- `.github/workflows/build.yml` — analyze + test + appbundle artifact

### Sürüm

`pubspec.yaml` → `version: 1.0.0+1` (semver+build). Android `versionCode` bu build
numarasından gelir; her mağaza yüklemesinde +1 artırın. Paket kimliği geliştirme
sürümünde `com.stacktower.stack_tower_game` (Android **ve** iOS'ta aynı — PB-032'de
hizalandı); yayın kimliği (TD-001) netleşince `android/app/build.gradle.kts` ve
iOS bundle id birlikte güncellenmelidir.

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

### Premium katman (PB-032) — görsel doğrulama

- [ ] Menü: aurora arka plan akıyor, logo nefes alıyor, butonlara basınca
      ölçek + parlama tepkisi var
- [ ] Mağaza/görev/pazar/ayarlar: cam paneller, gradient başlıklar, kayma yok
- [ ] HUD: skor değişince "pop" yapıyor, hedef çubuğu hedefe yaklaşınca parlıyor,
      kombo rozeti ısıya göre renk değiştiriyor
- [ ] Sürpriz kutusu: kapak fırlıyor, ışık huzmesi ve yükselen yıldızlar çıkıyor
- [ ] Sonuç ekranı: konfeti arka planı, ödül sayacı yukarı doğru sayıyor
- [ ] Arayüz sesleri: buton dokunuşu, ödül kazanımı, hata sesi duyuluyor
- [ ] Sayfa geçişi: yumuşak fade+scale, oyun ekranında hızlı

## Lisans

`LICENSE` dosyasına bakın. Yazı tipi: Inter (SIL OFL, `assets/fonts/OFL.txt`).
