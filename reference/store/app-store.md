# App Store yayını — mağaza metinleri

> Gereken: bir **Mac** (Xcode ile derleme) ve **Apple Developer Program**
> üyeliği ($99/yıl). Apple'ın paket kimliğini (Bundle ID) yayın sonrası
> değiştirmek çok zordur; `capacitor.config.json` içindeki `appId`'yi baştan
> doğru seç.

## Temel bilgiler

| Alan | Değer |
|---|---|
| Uygulama adı | NEON KULE |
| Alt başlık (≤30 karakter) | 10 dünya, 150 bölümlük kule |
| Kategori | Games → Arcade |
| Fiyat | Ücretsiz (uygulama içi satın alma yok) |
| Yaş | 4+ (uygun) |
| URL'ler | Web sitesi ve destek URL'si istenir — GitHub Pages yeterli |
| Gizlilik etiketi | Veri toplanmaz (yok) |

## Anahtar kelimeler (≤100 karakter)

```
kule,blok,stack,arcade,macera,bölüm,skor,görev,neon,ödül
```

## Açıklama (App Store Connect → Uygulama Metni)

```
10 dünya, 150 bölüm, 3B harita, günlük skor tahtası… neon kule macerası!

NEON KULE, refleksini ve zamanlamasını sınıyan premium bir kule oyunu. Yana
kayan bloğu bırak, dünyaları keşfet, görünümleri topla.

NASIL OYNANIR
• Bloğu en üstteki bloğun tam üstüne bırak — ekrana dokun
• MÜKEMMEL bırakışta kule kırpılmaz, seri büyür (×2, ×3…)
• Her bölümde hedefe ulaş, yıldız kazan — 3 yıldız kusursuz demek
• Yıldızların yeni dünyaların kilidini açar

KEŞFEDECEK ÇOK ŞEY
• GÖKTE YÜZEN 3B DÜNYALAR: her ada bir köy — bitirdikçe binalar çoğalır
• Her bölüme dokun: o dünyanın canlı sinematik önizlemesi + gizemli fısıltısı
• 10 benzersiz dünya: Neon Şehir, Bio Orman, Altın Çöl, Buz, Uzay, Volkan,
  Bulut Şehir, Derin Deniz, Kristal Mağara, Son Kule·Zirve
• 150 bölüm: klasik, rüzgar, hız, karanlık, altın, huzur, deprem, akan, patron
• KALINTILAR: her dünyayı bitir, kalıcı bir yadigâr kazan ve sergile
• GÜNLÜK MEYDAN OKUMA + SKOR TAHTASI: herkes aynı bölüm, sıralama seni bekler
• Haritada mücevher rengi bölüm türünü gösterir — ne oynayacağını önceden görürsün
• Sürpriz kutuları: yeni kule görünümleri ve madeni paralar çıkar
• Her bölümde kalkan: ilk hatanı dramatik bir anla bağışlar
• Sürpriz anlar: şanslı bölümlerde çift para, çift kalkan seni bekler
• Bir dünyanın 15 bölümünü bitir → dünya aydınlanır, hikâyesi açılır
• Topladığın yıldızlar menüde gökte takımyıldız olur
• 8 kilitlenebilir kule görünümü: Altını, Alev, Okyanus, Süpernova, Gökkuşağı…
• Her gün yenilenen görevler ve ödüller
• Sonsuz "Serbest Mod" ile rekor kovala

ÖZELLİKLER
• Tek parmakla oynanır, saniyeler içinde öğrenilir
• Neon görseller, tema dünyaları, kutlama konfetileri, titreşim
• İnternet ve hesap gerekmez; reklam yok, satın alma yok
• İlerlemen cihazında saklanır, Android ve iOS'ta aynı

Mükemmel bırakışı yakala, dünyaları fethet, kuleyi zirveye çıkar!
```

## App Store Connect yükleme adımları

1. Xcode'da `ios/App/App.xcworkspace` aç → hedefte kendi Team'ini seç
   (Apple Developer hesabı) → sürüm numarasını kontrol et
2. Product → Archive → Organizer aç → **Distribute App → App Store Connect**
   → yükle
3. https://appstoreconnect.apple.com → My Apps → + New App (NEON KULE,
   Türkçe, Bundle ID'yi seç) → yukarıdaki metinleri gir
4. Gizlilik: "Veri Toplanmıyor" seç (oyun yalnızca cihazda yüksek skoru tutar)
5. Yaş sorunsalı: tümü "Hayır" → büyük ihtimalle 4+
6. Fiyat ve dağıtım: Ücretsiz, tüm bölgeler → gönder → Apple incelemesi
   genellikle 24–48 saat sürer

## Ekran görüntüsü

- 6.7" (1290×2796) zorunlu; 6.5" ve 5.5" için de ekran görüntüsü ekle
- Cihaz simülatöründe: Xcode menüsü → Window → Devices and Simulators →
  simülatörü aç → Device → take Screenshot; veya `xcrun simctl io booted screenshot ekran.png`
- İkon (`assets/icon-1024.png`) hazır — App Store Connect'e yüklenebilir,
  alfa kanalsız (Apple şeffaflık kabul etmez)

## Sürüm notu (What's New)

```
İlk sürüm: NEON KULE
• Tek dokunuşla kule oyunu
• Mükemmel bırakış serisi ve kule büyüme mekaniği
• Rekor takibi (cihazda)
```
