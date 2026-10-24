# NEON KULE 🗼

10 dünya · 150 bölüm · 3B harita · günlük meydan okuma · sürpriz kutuları · ödüller.
Büyük bir stüdyo kalitesinde, bitmesi zor premium bir kule macerası.
**Tek kod tabanı → hem Google Play (Android) hem App Store (iOS).**
Windows oyunu değil; Windows yalnızca Android derlemesinin yapılabildiği bir
makinedir (iOS derlemesi için Mac gerekir).

Tek dokunuş. Bir kule. Sonsuz macera. Bloğu en üstteki bloğun tam üstüne bırak,
**MÜKEMMEL** bırakışta kule kırpılmasın, yıldızları topla, dünyaların kilidini aç.

## Oyun sistemi

| Sistem | Detay |
|---|---|
| Yükseliş haritası (3B) | Gerçek perspektifli, gökte yüzen **dev adalar**: sürükle → yörünge, dikey sürükle → dünyalar arası geçiş. Sis, bulut denizi, aurora, yıldızlar ve derinlik sıralaması |
| Yaşayan köy | Her ada bir dünya; bitirdiğin her bölüm adada **yeni bir bina** açar. Teras, kristaller, anıt, ışıklı yol ve büyüyen kasaba |
| Yol haritası | 10 dünya × 15 bölüm = **150 bölüm**; yıldız topla, dünyaları aç (D2: 10★, D3: 20★ … D10: 90★) |
| Sinematik önizleme | Kilitli/açık her bölüme dokun → o dünyanın canlı siluet sahnesi, fısıltısı ve **gizem cümlesi**. Sürpriz asla açıklanmaz |
| Kalıntılar | Her dünyayı bitirince kalıcı bir **yadigâr** kazanılır; Ödül Odası'nda 10 kalıntı sergilenir |
| Bölüm türleri | KLASİK · RÜZGAR · HIZLI · KARANLIK · ALTIN · HUZUR (yavaş+geniş) · DEPREM · AKAN (dalgalı hız) · PATRON |
| Bölüm türü | Haritadaki kristalin rengi = bölüm türü; giriş ekranı türü ve ödülü önceden gösterir |
| Günlük meydan okuma | Herkes için aynı tohumlu bölüm + **skor tahtası** (9 rakip + SEN, sıralama vurgulu) |
| Yıldız | Hedefe ulaş = 1★ · %30 mükemmel = 2★ · %60 mükemmel = 3★ |
| Ödül | Bölüm + yıldız + mükemmel bonusu madeni para; her deneme teselli parası |
| Sürpriz kutuları | 7'nin katı bölümler kutu düşürür: para veya yeni görünüm |
| Mağaza | 8 kilitlenebilir kule görünümü (Altını, Alev, Okyanus, Yosun, Buz, Süpernova, Gökkuşağı) |
| Görevler | Her gün 3 yeni görev (mükemmel/blok/bölüm) — ödül al, tekrar dene |
| Canlı arka plan | Paralaks ufuk katmanları, sürüklenen bulutlar, hava efektleri, ön plan derinlik katmanı |
| Serbest mod | Sonsuz kule, rekor takibi (eski tek skor kaydı da taşındı) |
| Kalkan | Her bölümde 1 ikinci şans: ilk kaçırmayı ağır çekimle kurtarır (blok biraz kırpılır) |
| Sürpriz anlar | ~%25 bölümde deterministik sürpriz: ŞANSLI AN (+20 🪙), ALTIN RUH (2× ödül), ÇİFT KALKAN |
| Dünya töreni | Bir dünyanın 15 bölümünü bitir → "DÜNYA AYDINLANDI" + hikâye + bonus para |
| Gökyüzü | Topladığın her yıldız menüde gökte bir yıldıza dönüşür (takımyıldız doğar) |
| Konsept | *Her blok bir an. Her kule bir hikâye.* — yükseldikçe dünyalar ve gök aydınlanır |
| Kayıt | localStorage; reklam yok, sunucu yok, hesap yok |

## Proje yapısı

```
www/                    — oyunun kendisi (tarayıcıda da çalışır)
  index.html  style.css
  levels.js    — 10 tema + 150 bölüm + hikâyeler/fısıltılar/gizem (saf)
  progress.js  — kayıt/ödül: para, yıldız, görünümler, kalıntılar, görevler, kutular (saf)
  game.js      — motor: mekanik, bölüm türleri, temalı/paralaks arka planlar, efekt, ses
  map.js       — perspektifli 3B takımada: yüzen dünyalar, büyüyen köyler, yörünge kamerası
  preview.js   — sinematik bölüm önizlemesi: dünya silueti, hava, kule, gizem geçidi
  ui.js        — ekranlar: menü, harita, sinematik giriş, sonuç, kutu, ödül odası, tahta
android/                — Capacitor'ın ürettiği Android projesi (Android Studio)
ios/                    — Capacitor'ın ürettiği iOS projesi (Xcode, Mac)
capacitor.config.json   — paket adı, uygulama adı, açılış perdesi, dikey mod
assets/                 — mağaza görselleri: icon-512, icon-1024, feature-1024x500
store/                  — Google Play + App Store metinleri, gizlilik politikası
tools/make-icons.js     — tüm simgeleri/açılış görsellerini üreten saf Node betiği
test.js  smoke.js       — birim testler + headless uçtan uca duman testi
```

## ⚠️ Yayınlamadan önce: paket adını değiştir

Şu an geçici bir kimlik var: `com.ornek.neonkule`. **Kendi benzersiz kimliğini
seç** (ör. `com.adiadsoyadi.neonkule` — ters alan adı kuralı) ve şuralarda
değiştir:

1. `capacitor.config.json` → `"appId"`
2. `android/app/build.gradle` → `applicationId` **ve** `namespace`
3. `ios/App/App.xcodeproj/project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER`
   (tek dosyada arat-değiştir ya da Xcode'da hedef → General → Bundle Identifier)

Sonra `npm run sync`. **Play Store'da paket adı, App Store'da bundle ID yayınlandıktan
sonra değiştirilemez** — baştan doğru seç.

## Gereksinimler

| | Google Play (Android) | App Store (iOS) |
|---|---|---|
| Makine | Windows/Linux/Mac + Android Studio | **Mac** + Xcode |
| Hesap | Google Play Developer ($25, tek seferlik) | Apple Developer Program ($99/yıl) |
| Derleme | `.aab` (Android Studio → Gradle) | Archive (Xcode → App Store Connect) |

Derleme araçları bu projeye dahil değildir; kendi bilgisayarında kurarsın.
Proje bağımlılıkları: `npm install` (bir kez).

## Android — Google Play adımları

```bash
npm install            # bağımlılıklar (bir kez)
npm run sync           # www/ içeriğini android/ içine kopyalar
```

1. **Android Studio**'yu aç → `android/` klasörünü aç → Gradle beklesin
2. Telefonda dene: telefonu USB ile bağla (Geliştirici seçenekleri + Hata
   ayıklama açık) → Run ▶
3. İmzalı paket: **Build → Generate Signed Bundle / APK → Android App Bundle**
   → anahtar (keystore) oluştur → `app-release.aab`
4. https://play.google.com/console → uygulamayı oluştur → `.aab`'i yükle
5. Mağaza metinlerini `store/google-play.md` içinden yapıştır, gizlilik
   politikası URL'si olarak `store/gizlilik-politikasi.html` dosyasını bir
   yerde yayımla (GitHub Pages yeterli)

Detaylı metinler ve ekran görüntüsü rehberi: [store/google-play.md](store/google-play.md)

## iOS — App Store adımları

```bash
npm install
npm run sync           # www/ içeriğini ios/ içine kopyalar
```

1. **Mac**'te `ios/App/App.xcworkspace`'ı Xcode ile aç
2. Hedef → General → Bundle Identifier'ı kendi kimliğinle değiştir, kendi
   Team'ini seç, sürüm numarasını kontrol et
3. **Product → Archive → Distribute App → App Store Connect → yükle**
4. https://appstoreconnect.apple.com → New App → mağaza metinlerini
   `store/app-store.md` içinden yapıştır → "Veri Toplanmıyor" seç → gönder
   (Apple incelemesi genelde 24–48 saat)

İkon hazır: App Store Connect'e `assets/icon-1024.png` (alfa kanalsız) ve
açılış ekranı için `ios/.../Splash.imageset` zaten dolu.

## Oyun kimlikleri (store ayarları)

| | Değer |
|---|---|
| Uygulama adı | NEON KULE |
| Kategori | Games → Arcade |
| Yaş | 3+ (Play) / 4+ (Apple) |
| Reklam, analiz, hesap, uygulama içi satın alma | **Yok** — bu, gizlilik formunu çok kolaylaştırır |
| Dikey mod | Evet (her iki platformda da kilitli) |

## Geliştirme komutları

```bash
npm test               # çekirdek mantık testleri (bırakma matematiği, hız, büyüme)
npm run smoke          # headless duman testi: boot → 400 bırakış → oyun sonu → klavye
npm run serve          # www/ klasörünü tarayıcıda önizle (http://localhost:3000)
npm run icons          # tüm simgeleri/açılış görsellerini yeniden üret
npm run sync           # www/ → android/ + ios/ senkronu (değişiklik sonrası KOŞ)
npm run open:android   # Android Studio'da aç
npm run open:ios       # Xcode'da aç (Mac gerekir)
```

Sürümr notları: `package.json` → `version`, `android/app/build.gradle` →
`versionCode` (her mağaza sürümünde +1) ve `versionName`, Xcode hedefindeki
`CURRENT_PROJECT_VERSION` / `MARKETING_VERSION`.

## Telefonda denemek (mağaza yüklemeden)

- Android: Android Studio'da Run ▶ ya da `npx cap run android`
- iOS: Xcode'da Run ▶ (simülatör veya cihaz)
- Tarayıcı: `npm run serve` → `www/` klasörü doğrudan tarayıcıda da çalışır
  (zip'leyip arkadaşına göndermek için yeterli — internet bile gerekmez)

## Oynanış

| Eylem | Tuş |
|---|---|
| Bırak | Dokunma, sol tık, BOŞLUK |
| Tekrar oyna | R (klavye) veya sonuç ekranından |
| Ses aç/kapat | M veya sağ üstteki düğme |
| Çık | HUD'daki ‹ ÇIK veya Esc / geri tuşu |
| Geri tuşu (Android) | Menüde uygulamayı kapatır, oyun sırasında haritaya döner |

- MÜKEMMEL bırakışta kule kırpılmaz, seri (`×2`…) titreşimle ödüllendirilir
- Klasik/rüzgar/karanlık/altın bölümlerde 4 mükemmelette kule %4 geri büyür
  (HIZLI ve PATRON bölümlerde büyüme yok — meydan okuma)
- Kule `6px` altına inerse çöker; hedefe ulaşırsan bölüm biter ve ödül verilir

## Denge ayarları (`www/game.js` başında)

| Sabit | Değer | Ne yapar |
|---|---|---|
| `levels.js → levelDef()` | hedef `8 + i×0.16`, hız `0.9 + i×0.028` | bölüm başına zorluk eğrisi (tavan ~3.4) |
| `tol` | dünya 0-1: 6 · dünya 3-4: 5 · dünya 5-6: 4 px | ilerledikçe tolerans daralır |
| `MIN_BLOCK_WIDTH` (game.js) | 6 | bundan ince kule çöker |
| `growthWidth()` | 4 seride %4 | geri büyüme (HIZLI/PATRON hariç) |
| `starsFor()` (levels.js) | %30 / %60 mükemmel | 2 ve 3 yıldız eşiği |
| `MISSION_TEMPLATES` (progress.js) | 10-20 mükemmel · 60-100 blok · 2-4 bölüm | günlük görevler |
