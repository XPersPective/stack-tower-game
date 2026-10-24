# STACK TOWER GAME — DEVİR BRİFİNGİ (tek yetkili spec)

Bu belge projenin tek yetkili kaynağıdır (Project Brain target.md'nin eki). Flutter
yeniden yazımını yapan yapay zekâ/mühendis tüm kararları bu belgeye göre verecek;
burada yazmayan hiçbir özellik varsayılmayacak, burada yazan hiçbir özellik atlanmayacak.

> Köken: "NEON KULE" adlı HTML/JS + Capacitor oyununun devir brifingiydi; proje
> kullanıcının kararıyla **Stack Tower Game** olarak yeniden adlandırıldı (ADR-001).
> Oyunun içeriğinde "Neon Kule" geçen hiçbir metin kullanıcıya görünmeyecek.

## 0. Görev Özeti
Mevcut oyun (HTML/JS + Capacitor kabuğu, `reference/www/`) Flutter ile sıfırdan, aynı
veya daha iyi görsel/duysal kalitede, üretim düzeyinde yeniden yazılacak.

| Kural | Değer |
|---|---|
| Hedef platformlar | Android (Google Play) + iOS (App Store) |
| Teknoloji | Flutter (tek kod tabanı) |
| Kalite barı | Mevcut sürümün altına kesinlikle düşülmeyecek; görsel/animasyon kalitesi eşit veya üstü. Hedef: 60 fps kesintisiz, premium stüdyo hissi |
| Sunucu | Cloudflare (ücretsiz katman) — Workers + D1 (SQLite) |
| Kimlik | Google ile Giriş + iOS'ta Sign in with Apple (Guideline 4.8; ADR-005) |
| Skor tahtası | Global çevrimiçi skor tahtası — her oyuncu kendini ve diğerlerini sıralamada görür |
| Maliyet | Tüm servisler ücretsiz katmanda çalışacak |
| Çevrimdışı | Oyun internet olmadan tam oynanabilir; skorlar bağlantı gelince sunucuya toplu gönderilir (asla kaybolmaz) |

## 1. Mevcut Kaynak Kod Haritası (port edilecek referans)
`reference/www/` klasörü tek doğruluk kaynağıdır. Flutter tarafına dosya dosya eşleme:

| Kaynak (JS) | Ne yapar | Flutter karşılığı |
|---|---|---|
| `www/levels.js` | 10 tema + 150 bölüm tanımı + denge formülleri + günlük/serbest tanım + hikâye metinleri (saf fonksiyon, saf veri) | `lib/game/levels.dart` — birebir matematik taşınacak, test edilebilir saf Dart |
| `www/progress.js` | Kayıt/ödül ekonomisi: para, yıldız, görünümler, kalıntılar, görevler, kutular, günlük rekor (saf + depolama soyutlamalı) | `lib/game/progress.dart` + depolama arayüzü → shared_preferences |
| `www/game.js` | Oyun motoru: blok hareketi, bırakma matematiği, bölüm türleri, paralaks arka planlar, efektler, ses (WebAudio) | `lib/game/drop_core.dart` (saf çekirdek) + `lib/game/gameplay.dart` + `lib/game/audio.dart` — saf CustomPainter + Ticker (ADR-002) |
| `www/map.js` | Perspektifli 3B yüzen takımada haritası: sürükle→yörünge kamera, dikey sürükle→dünya geçişi, büyüyen köyler, sis/bulut/aurora | `lib/screens/map_screen.dart` — CustomPainter + Matrix4 perspektif |
| `www/preview.js` | Sinematik bölüm önizlemesi: dünya silueti + hava efektleri + gizem cümlesi | `lib/screens/preview_screen.dart` |
| `www/ui.js` | Ekran akışları: menü, harita, sonuç, kutu, ödül odası, mağaza, görevler, tahta, günlük | `lib/screens/*` — ekranlar ve geçişler |
| `www/style.css` + `index.html` | Neon estetik: glow, gradyanlar, tema paletleri, font (Inter) | `lib/theme/` — tema token'ları; Inter fontu `assets/fonts/` altına |
| `www/leaderboard.js` | Çevrimiçi tahta köprüsü + offline kuyruk + en-yüksek-skor mantığı (zip'te eski GC/PGS köprüsü; §7 mimarisiyle değiştirilir) | `lib/services/leaderboard_service.dart` — §7 mimarisiyle aynı davranış |
| `test.js`, `smoke.js` | Davranış spesifikasyonu (§8 kabul testleri bunlardan türetilecek) | Dart test paketi |
| `assets/` (simge/mağaza görselleri) ve `store/` (mağaza metinleri) | Yeniden kullanılacak/kösteklenecek | `reference/assets/`, `reference/store/` |
| `android/`, `ios/`, `capacitor.config.json` | Capacitor'a özgü | Flutter projesine kopyalanmaz (atılır) |

## 2. Oyun Spesifikasyonu (değiştirilmeden taşınacak)
### 2.1 Temel döngü
Tek dokunuş kule oyunu. Blok yan yana süzülür; dokununca bırakılır. Üstteki bloğun
tam üstüne düşerse kırpılmaz (MÜKEMMEL) ve seri (×2, ×3…) artar; hizalama kaçarsa blok
kırpılır. Kule 6px altta kalırsa çöker.

| Kural | Değer |
|---|---|
| Mükemmel bırakış | Kule kırpılmaz + seri çarpanı + hafif titreşim |
| Geri büyüme | 4 mükemmelette kule %4 geri büyür — HIZLI ve PATRON bölümlerinde yok |
| Çökme eşiği | Blok genişliği 6px'in altına inirse kule çöker |
| Kalkan | Bölüm başına 1 ikinci şans: ilk kaçırmayı ağır çekimle kurtarır, blok biraz kırpılır |
| Yıldız | Hedefe ulaş = 1★ · %30 mükemmel = 2★ · %60 mükemmel = 3★ (ceil) |
| Ödül | (bölümParası + yıldız×5 + mükemmel×2) × altınsa×2; başarısız denemede teselli 2 para |

### 2.2 Yapı
10 dünya × 15 bölüm = 150 bölüm + günlük meydan okuma + serbest (sonsuz) mod.
- Kilidi açma: önceki bölüm bitirildi VE toplam yıldız ≥ dünyaNumarası×10 (aynı dünyadaysa yıldız şartı aranmaz).
- Her dünyanın 15. bölümü PATRON (uzun, hızlı). 4. ve 9. bölümler ALTIN (2× ödül).
- 7'nin katı olan bölümler sürpriz kutusu düşürür (para %65 / yeni görünüm %35).
- Dünyanın tamamı bitince "DÜNYA AYDINLANDI" töreni: hikâye cümlesi + 50 + dünya×25
  para + kalıcı kalıntı (10 dünya = 10 kalıntı, Ödül Odası'nda sergilenir).

### 2.3 Denge formülleri (birebir taşınacak — bunlar oyunun ruhu)
```text
target    = 8 + round(i × 0.16) + (son bölüm ise +6)        // i: 0..149 global indeks
speed     = min(3.0, 0.9 + i × 0.028)
tol       = dünya ≥ 4 → 4px · dünya ≥ 2 → 5px · aksi 6px
HIZLI     ×1.45 hız (tavan 3.2)   RÜZGAR ×1.1 (tavan 3.2)   PATRON ×1.3 (tavan 3.4)
HUZUR     ×0.6 hız, tol 7px, +15 para
para      = 10 + round(i × 0.5) + (tür bonusu: ALTIN 25, PATRON 30, HUZUR 15, DEPREM 20, AKAN 20) + (kutulu bölüm +10)
```
Hareket çekirdeği (game.js CORE): `travelRange(w)=w×2.1` · `movingBounds` minX=`x−w×1.05`,
aralık = `w×2.1` · hız = `travelRange×0.5×min(3, 0.9+placed×0.055)×speedScale` · geri
büyüme: `combo>0 && combo%4==0 → min(baseW, w×1.04)` · mükemmel: `|Δx|≤tol && |Δw|≤tol`.

### 2.4 Bölüm türleri (9)
KLASİK · RÜZGAR (bloğu savurur) · HIZLI · KARANLIK (sadece kule görünür) · ALTIN (2×
para) · HUZUR (yavaş+geniş+yüksek ödül) · DEPREM (zemin sarsılır) · AKAN (hız dalgalanır:
`×(1+0.55×sin(t×2.6))`) · PATRON (uzun+hızlı). Dağılım kalıbı (idx = bölümün dünyadaki
sırası, stage ≥ n şartıyla): `patron: idx14` · `altin: idx4, idx9` · `ruzgar: idx%7==3`
· `hizli: idx%7==5` · `karanlik: idx%7==6` · `yavas: idx%7==2` · `deprem: idx%7==4` ·
`akan: idx%7==1`. Tam dağılım `reference/www/levels.js → levelDef()`.

### 2.5 Sürpriz anlar
~%25 bölümde deterministik: `(i + gün) % 4 === 0` → havuzdan biri (`(i+gün)%3` seçer):
ŞANSLI AN (+20 para) · ALTIN RUH (2× ödül) · ÇİFT KALKAN (2 kalkan).

### 2.6 Ekonomi & koleksiyon
Başlangıç 60 para. 8 kule görünümü (NEON 0 · ALTIN 120 · ALEV 150 · OKYANUS 160 ·
YOSUN 180 · BUZ 200 · SÜPERNOVA 240 · GÖKKUŞAĞI 320 para; hue'lar progress.js SKINS).
Görevler: her gün 3 görev (10-20 mükemmel / 60-100 blok / 2-4 bölüm; hedef =
`base + ((gün+idx)%3)×step`), gün değişince yenilenir, ödül 25-45 para.
Gökyüzü: menüde topladığın her yıldız gökte bir yıldıza dönüşür (takımyıldız).

### 2.7 Günlük meydan okuma (global tahta adayı)
Herkes için aynı güne göre tohumlu bölüm:
```text
dünya = gün % 10 · hedef = 12 + (gün%5)×2 · hız = min(2.6, 1.2 + (gün%7)×0.2)
tol 5 · tür = [normal,rüzgâr,hızlı,karanlık,altın,deprem][gün % 6] · para 60 + (gün%5)×10
```
Rekor gün bazlı tutulur (`daily: {day, best}`). Bu bölümün tahtası çevrimiçi olacak (§7).

### 2.8 Arayüz ekranları
Menü · Harita (3B yüzen adalar, sürükle→yörünge, dikey sürükle→dünya) · Sinematik
bölüm önizlemesi (siluet + fısıltı + gizem cümlesi) · Oyun (HUD: ‹ÇIK, ses, kalkan) ·
Sonuç (yıldız/ödül animasyonu) · Kutu açılışı · Ödül Odası (kalıntılar) · Mağaza
(görünümler) · Görevler · Skor tahtası · Ayarlar (ses, titreşim).

## 3. Görsel / Duyusal Kalite Barı (üretim düzeyi — pazarlık dışı)
Mevcut sürümün standartlarıdır; aşağısına düşülmeyecek:
- Canlı paralaks arka plan: çok katmanlı ufuk, süzülen bulutlar, ön plan derinlik katmanı
- Tema atmosferleri (10 dünya): neon şehir, bio orman (yaprak), altın çöl (kum), buz
  (kar), uzay (yıldız), volkan (kor), bulut şehir, derin deniz, kristal mağara, zirve —
  her temanın kendi `[bg1,bg2]` gradyanı, glow tonu ve hava efekti var (levels.js THEMES)
- Aurora, sis, yıldız yağmuru, bulut denizi; derinlik sıralaması (z-ordering); ay/aya
  halesi, uzak adalar, kule ışık huzmesi, zemin platformu (kristaller, gölge, halo)
- Harita: gerçek perspektif hissi (Matrix4), adalar arası orbit kamera geçişi, adalarda
  biten her bölümle büyüyen köy (teras, kristaller, anıt, ışıklı yol)
- Bırakış geri bildirimi: MÜKEMMEL'de ekran titreşimi + seri çarpanı; kalkan kurtarması
  ağır çekim (0.55s boyunca dt×0.35)
- Font: Inter (`reference/www/fonts/`, OFL lisanslı — taşınacak)
- Neon estetik: koyu zemin + parlak cyan/magenta/amber glow, gradyanlı bloklar, glowlu
  kenarlar, 3B derinlik yanı (depthX/depthY), cam parlaması
- Ses: her olay için ses (bırakma, mükemmel seri, ödül, kutu, tören) + sessize alma (ADR-003)
- Dikey mod her iki platformda kilitli

## 4. Flutter Mimarisi
```text
lib/
  main.dart
  theme/            — neon tema token'ları, font, boşluklar
  game/
    levels.dart     — levels.js'ten birebir (saf Dart, unit test)
    progress.dart   — progress.js'ten birebir (saf Dart + Storage arayüzü)
    drop_core.dart  — game.js CORE birebir (saf Dart, unit test)
    gameplay.dart   — oyun döngüsü/fiziği (CustomPainter + Ticker; ADR-002)
    audio.dart      — ses servisi
  screens/          — menu, map, preview, play, result, box, reward_room, shop, missions, board, settings
  services/
    storage.dart    — kayıt (shared_preferences)
    leaderboard.dart— §7: çevrimiçi tahta + offline kuyruk
    session.dart    — §7: oturum token'ı (flutter_secure_storage)
```
Paketler: google_sign_in, sign_in_with_apple, flutter_secure_storage,
shared_preferences, http, provider (ADR-004). State abartılmayacak.

Port sırası: 1) levels+progress+drop_core+testler → 2) oyun motoru + bırakma hissi →
3) ekranlar/tema → 4) harita/sinematik → 5) backend + skor tahtası → 6) ses/efekt cilası.

## 5. Kayıt (Yerel) — taşınacak davranış
JSON şeması: `coins, completed{levelIdx:{stars,best}}, skins[], activeSkin, best,
totalPerfect, totalBlocks, levelsDone, day, missions{day,items[]}, daily{day,best},
worldsCelebrated{}, relics{}, boxes{}`. Kayıt her önemli olayda anında yazılır (kapanma
güvenliği). Kayıt anahtarı ve başlangıç durumu (60 para) aynen korunur; eski Capacitor
localStorage'ına erişim yoktur → v1→v2 migration yeni kurulumda geçersizdir (ADR-001).

## 6. Çevrimiçi Tasarım Prensibi
- Skor asla kaybolmaz: gönderilemeyen her skor cihazda kuyruğa yazılır; bağlantı/oturum
  geldiğinde toplu gönderilir (kuyruk tavanı 50).
- Sadece en yüksek skor gönderilir/puanlanır — kaybettiren denemeler sıralamayı düşürmez.
- Sunucu yoksa/kopuksa oyun sessizce yerel deterministik rakip tahtasıyla devam eder
  (`rivalsFor`); oyun asla kırılmaz.

## 7. Sunucu + Kimlik + Global Skor Tahtası (Cloudflare, ücretsiz)
### 7.1 Altyapı
Workers (100K istek/gün) API için; D1 (5GB) kullanıcılar + skor tabloları. R2 gerekmez.

### 7.2 Kimlik akışı — Google ile Giriş (+ Apple)
- Flutter `google_sign_in` → `authentication.idToken` → `POST /auth/google {idToken}`.
- Worker ID token doğrular: JWKS `googleapis.com/oauth2/v3/certs`, kid'e göre anahtar,
  Cache-Control'e göre önbellek, bilinmeyen kid'de bir kez yenile; kontroller: alg=RS256,
  imza, aud=OAuth client ID, iss=accounts.google.com, exp. Kimlik = `sub`.
- Worker kendi oturum JWT'sini üretir (HMAC, 30 gün). Uygulama flutter_secure_storage'da
  tutar. Yeni kullanıcı D1'e kaydedilir (display_name = hesap adı).
- iOS (Guideline 4.8): Sign in with Apple da sunulur, aynı sub-tabanlı hesaba bağlanır
  (varsayılan karar; kullanıcı onayı open decision TD-002'de).
### 7.3 D1 şeması
```sql
CREATE TABLE users (sub TEXT PRIMARY KEY, provider TEXT NOT NULL, display_name TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE scores (user_sub TEXT NOT NULL, board TEXT NOT NULL, day INTEGER NOT NULL DEFAULT 0, score INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY (user_sub, board, day));
CREATE INDEX idx_board_score ON scores(board, day, score DESC);
```
### 7.4 API uçları
`POST /auth/google` · `POST /auth/apple` · `GET /me` · `GET /leaderboard?board=daily&day=<gün>`
(ilk 100 + kullanıcının sırası) · `GET /leaderboard?board=endless` · `POST /score`
(yalnızca yüksek skor kabul: upsert where excluded.score > scores.score) · `DELETE /account`.
Kurallar: her uç oturum ister; gün UTC'de sunucuda hesaplanır; sanity tavan (daily ≤2000,
endless ≤100000); kullanıcı başına ~10 istek/dk hız sınırı.
### 7.5 Davranış
Günlük tahta günü UTC'de; yeni günde tahta sıfırlanır. Tahtada e-posta asla görünmez.
### 7.6 Mağaza gizlilik etkisi
Play Data Safety + App Privacy: "Hesap" + "Oyun içi ilerleme" beyanı; gizlilik politikası
URL zorunlu (silme hakkı dahil güncellenecek); uygulama içinden hesap silme (DELETE
/account); reklam/analitik yok.

## 8. Kabul Testleri (reference/test.js + smoke.js'den türetilecek)
Birim (saf Dart):
- `levelDef(i)`: 150 bölümün hedef/hız/tol/para değerleri JS çıktısıyla birebir aynı.
- `starsFor`: %30/%60 eşiği; 1★ her durumda.
- `completeLevel`: ilk temizlik, yıldız yükseltmesi, altın çarpanı, teselli parası,
  sonsuz modda rekor, günlükte bölüm ilerlemesine dokunmama.
- `isUnlocked/isWorldComplete/applyWorldComplete`: yıldız kapısı + tören bonusu bir kez.
- `openBox/buySkin/claimMission`: ekonomi bütünlüğü (para asla negatife düşmez).
- `surpriseFor/dailyDef/rivalsFor/ensureMissions`: deterministik tohum davranışı.
- Bırakma matematiği: kırpma, min genişlik 6, çökme, geri büyüme (HIZLI/PATRON hariç).

Duman (headless simülasyon): boot → 400 rastgele bırakış → bölüm sonu → sonucu kapat →
tekrar oyna; çökme yok. Skor tahtası servisi: oturumsuz kuyruğa yazma → oturum gelince
toplu gönderim → gönderim hatasında skor kaybolmaz → yalnızca en yüksek skor gider.

Manuel (yayın öncesi): en az 1 ucuz Android + 1 orta Android + 1 iPhone; 60 fps, geri
tuşu, dikey kilit, ses/titreşim, çevrimdışı oyun, ani kesintide kayıt korunur.

## 9. Sürüm & Yayın
pubspec version `1.0.0+1`; Android versionCode her yayında +1. Paket kimliği
geliştirmede `com.stacktower.game` (yer tutucu; yayın öncesi kesin kimlik TD-001).
Mağaza metinleri `reference/store/` kösteklenecek (isimler Stack Tower Game'e uyarlanacak).
CI önerisi: GitHub Actions (appbundle + iOS Archive macos runner'da).

## 10. Karar Vericilere Açık Sorular
- TD-001 Paket kimliği: `com.stacktower.game` kalıcı mı? (Yayın öncesi kararlaştırılır; geliştirmeyi bloklamaz.)
- TD-002 Tahtada görünecek ad: hesap adı mı, oyuncunun seçtiği takma ad mı? (Öneri: ilk girişte takma ad sor.)
- TD-003 Skor tahtası başlangıçta Cloudflare mi, yoksa faza göre Game Center/Play Games mi? (Brifing: Cloudflare; varsayılan uygulanır.)
