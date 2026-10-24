# Google Play yayını — mağaza metinleri

> Paket adını (`com.ornek.neonkule`) **yayınlamadan önce** kendi benzersiz
> kimliğinle değiştir (bkz. README). Play Console'da paket adı yayınlandıktan
> sonra DEĞİŞTİRİLEMEZ.

## Temel bilgiler

| Alan | Değer |
|---|---|
| Uygulama adı | NEON KULE |
| Kısa açıklama (≤80 karakter) | 10 dünya, 150 bölüm, 3B harita, skor tahtası! Ödüllü kule macerası. |
| Kategori | Oyunlar → Aksiyon veya Arcade |
| Varsayılan ülke/dil | Türkiye / Türkçe |
| Fiyat | Ücretsiz |
| Reklam | Yok |
| Uygulama içi satın alma | Yok |
| Hesap gerektirir | Hayır |
| Yaş derecelendirmesi | 3+ (şiddet/içerik yok — anketi "hayır" ile doldurunca büyük ihtimalle 3 çıkar) |

## Tam açıklama (Play Console → Mağaza listingi → Uygulama açıklaması)

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

## Ekran görüntüsü gereksinimleri

- En az 2, en iyi 4–8 adet **telefon** ekran görüntüsü (1080×1920 veya 1080×2280)
- Nasıl üretilir: Android Studio'da uygulamayı çalıştır → Device Explorer /
  `adb exec-out screencap -p > ekran.png`
- İlk görüntüler: (1) oyun içi kule, (2) "OYUN BİTTİ" + rekor ekranı, (3) menü
- Tablet ekran görüntüsü istenmiyor ama 7" ve 10" için zorunlu değildir

## Play Console yükleme adımları

1. https://play.google.com/console → uygulama oluştur → paket adını gir
2. Mağaza listingi → yukarıdaki metinleri yapıştır
3. Hesap kimliği → gizlilik politikası URL'si: `store/gizlilik-politikasi.html`
   dosyasını GitHub Pages gibi bir yere yayınla ve URL'yi ver
4. İçerik derecelendirme anketi → tümü "Hayır"/"Yok" → genellikle 3+ çıkar
5. Hedef kitle: "18 yaş üstü" işaretle (çocuklara yönelik reklam kuralları başlar)
6. Uygulamalar → sürüm → yeni sürüm → `app-release.aab` yükle → kapalı test →
   açık test → üretim (her aşamada bir kaç saat – birkaç gün onay süresi olabilir)

## İlk sürüm notu (Sürüm notları alanı)

```
İlk sürüm: NEON KULE
• Tek dokunuşla kule oyunu
• Mükemmel bırakış serisi ve kule büyüme mekaniği
• Rekor takibi (cihazda)
```
