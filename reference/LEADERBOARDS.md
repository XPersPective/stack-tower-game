# NEON KULE — Çevrimiçi Skor Tahtaları (Game Center / Play Games Services)

## Ne uygulandı

| Katman | Dosya | Görev |
|--------|-------|-------|
| JS servis | `www/leaderboard.js` | Köprü algılama, kalıcı kuyruk, platforma göre tahta kimliği, kimlik doğrulama sonrası toplu gönderim |
| Tahta kimlikleri | `www/lb-config.js` | Play Console / App Store Connect ID'leri (boşsa oyun çevrimdışı tahtayla devam eder) |
| Android köprüsü | `android/.../LeaderboardPlugin.java` | Play Games Services v2: `authenticate`, `submit`, `show` |
| Android başlatıcı | `android/.../KuleApplication.java` | `PlayGamesSdk.initialize(this)` |
| iOS köprüsü | `ios/App/App/LeaderboardPlugin.swift` | Game Center: `GKLocalPlayer.authenticateHandler`, `GKLeaderboard.submitScore`, `GKGameCenterViewController` |
| iOS köprü VÇ | `ios/App/App/NeonBridgeViewController.swift` | Capacitor 6+ gereği eklentiyi `capacitorDidLoad()` içinde kaydeder |
| Yetki | `ios/App/App/NeonKule.entitlements` | `com.apple.developer.game-center` (hedefe bağlı) |

**Davranış:**
- Günlük meydan okuma ve serbest mod skorları bitiminde otomatik gönderilir.
- Kimlik doğrulanmadan gönderim yapılmaz; gönderilemeyen her skor
  `localStorage` kuyruğunda (`neonkule_lb_queue_v1`) saklanır ve sonraki
  açılışta/kimlikte toplu gönderilir. Aynı tahtada yalnızca en yüksek skor gider.
- Köprü yoksa (web, önizleme, test) oyun mevcut çevrimdışı rakip tahtasıyla
  çalışır; "🌍 ÇEVRİMİÇİ SIRALAMA" düğmeleri gizlenir.

## 1) Google Play Console kurulumu (Android)

1. [Play Console](https://play.google.com/console) → oyunu oluşturun
   (paket adı: `com.ornek.neonkule`).
2. **Play Games Services** bölümünü açın ve proje kimliğini alın
   (`Cgk...` ile başlar) →
   `android/app/src/main/res/values/strings.xml` içindeki
   `game_services_project_id` değerini bununla değiştirin.
3. **Leaderboards** → iki tahta oluşturun (örn. `Günlük Meydan Okuma`,
   `Serbest Mod`) ve her birinin **ID** değerini kopyalayın.
4. Android kimlik bilgisi (credential) ekleyin: paket adı + SHA-1 parmak izi.
   Play App Signing kullanıyorsanız **app-signing** sertifikasının parmak
   izini girin; `debug` için de ayrı credential ekleyin:
   `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`
5. Kendi Google hesabınızı **test hesabı** olarak ekleyin; tahtayı
   yayınlamadan önce test sürümüne (internal testing) atayın.
6. Skor tahtası ID'lerini `www/lb-config.js` → `daily.android` ve
   `endless.android` alanlarına yapıştırın.

Not: Play Games Services yapılandırması yayınlanana kadar API'ler
cihazda hata verebilir; değişkenlik 2 saate kadar sürebilir.

## 2) App Store Connect kurulumu (iOS)

1. App Store Connect → uygulamanız → **Oyun Merkezi** → **Sıralamalar** →
   iki tahta oluşturun (örn. `tr.com.ornek.neonkule.daily`,
   `tr.com.ornek.neonkule.endless`).
2. ID'leri `www/lb-config.js` → `daily.ios` ve `endless.ios` alanlarına girin.
3. Xcode'da hedefe imzalama kimliği ile Game Center yeteneğinin bağlı
   olduğunu doğrulayın (`NeonKule.entitlements` proje dosyasına bağlıdır;
   Apple Developer hesabında App ID'nin Game Center capability'si açık olmalı).
4. Cihaz testi için Game Center hesabıyla oturum açın ve imzalı bir build
   kullanın (simülatörde Game Center sınırlıdır).

## 3) Derleme ve senkronizasyon

```bash
npm run sync          # www/ → android/ios asset senkronu
npm run open:android  # Android Studio ile aç, build & Run
npm run open:ios      # Xcode ile aç, build & Run
```

## Doğrulama durumu (dürüstlük notu)

- JS servis katmanı **tamamen test edildi**: `node test.js` (kuyruk,
  toplu gönderim, en yüksek skor seçimi, hata dayanıklılığı, platform
  kimlik eşlemesi) ve `node smoke.js` (akış içi çevrimdışı davranış).
- **Android/iOS yerel kod bu bulut ortamında derlenemedi** (Android SDK /
  Xcode yok) ve gerçek Game Center / Play Games Services hesaplarıyla
  uçtan uca test edilemedi. Cihaz testi sizin tarafınızda yapılmalıdır:
  kimlik doğrulama ekranı → skor gönderimi → yerel tahta ekranı.
- `show()` çağrısı platformun yerel tahta ekranını açar; kapattıktan sonra
  oyun kaldığı yerden devam eder.
