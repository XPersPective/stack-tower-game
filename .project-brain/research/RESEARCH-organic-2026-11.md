# RESEARCH: Organik Viralite Raporu — Reklamsız, Sosyalsiz Büyümenin Bilimi (2026-11)

- **Tarih:** 2026-11-03
- **Kapsam:** 52 oyun derin tablo analizinde + ~40 dolaylı oyun/klon ailesi (Flappy klonları 1000+, 2048 klonları, .io ailesi, hyper-casual prototip kütüphaneleri) — toplam 90+ oyun teması
- **Soru:** Bazı mobil oyunlar çıkışta reklam bütçesi, sosyal ağ, pazarlama olmaksızın 10M–1B indirmeye nasıl ulaşır? Bunun BİLİMSEL ilkeleri nelerdir?
- **Yöntem:** Web araması — (1) sektör dekonstrüksiyonu: Deconstructor of Fun (Voodoo analizi), Naavik (Hypercasual: Past/Present/Future), GameAnalytics, GameRefinery; (2) resmî veri: AppMagic/Sensor Tower kamu verileri, AppBrain, mağaza sayfaları; (3) tasarımcı birincil kaynakları: Voodoo "How to Hypercasual" destesi (System 1, 3-sn kuralı, "Snackable/Youtubable"), Ketchapp yayıncı notları, Crossy Road GDC postmortem, Dong Nguyen/Flappy Bird röportajları, Reichelt (Color Switch), SYBO CEO (Sub Club); (4) akademik: Csikszentmihalyi flow + Jenova Chen tezi, Ryan/Rigby/Przybylski 2006 (SDT/PENS), Skinner değişken-oran pekiştirme + near-miss dopamin çalışmaları, Kahneman-Tversky kayıp-aversiyonu + Duolingo streak araştırmaları, Zeigarnik/endowed-progress/goal-gradient; (5) postmortemler: r/gamedev, howtomarketagame (Vampire Survivors).
- **Dürüstlük notu:** "Organik" iddiaları üçe ayrıldı — **TAM** (kaynağa göre sıfır/near-zero pazarlama: Flappy Bird, Wordle, 2048, Slither.io, Suika, Crossy Road, Hill Climb), **KISMEN** (organik döngü güçlü ama yayıncı cross-promo/UA katalizörü vardı: Voodoo/Azur/Ketchapp/Lion/SayGames/Supersonic kataloğu), **HAYIR** (UA ana sürücü, organik tutunma yan ürün: Block Blast, Stack Ball'in scale fazı). İndirme hızları kamu verilerinden yaklaşık (≈); kesin ilk-30-gün verisi nadiren ifşa edilir.
- **İlgili kısıtlar:** C-010 (reklam/3. parti veri yok), C-005 (tam çevrimdışı), C-012 (Türkçe UI), C-018 (3 sn okunabilirlik), C-022 (tek dokunuş), C-024 (bot/ajans yok), C-002 (drop_core paritesi dokunulmaz). Bu raporun TÜM önerileri sunum/akış/meta katmanındadır.
- **Kardeş raporlar:** `RESEARCH-dna-2026-11.md` (12 DNA yasası — bu rapor onları BİLİMSEL temele oturtur ve kancayı "indirme" tarafına taşır), `RESEARCH-social-2026-11.md`, `RESEARCH-endgame-2026-11.md`, `RESEARCH-hud-2026-11.md`

---

## 1. Yönetici Özeti

**Bulgu 1 — Organik viralite şans değil, üçlü bir kanıt zinciridir.** İncelenen 52 oyunun hepsinde aynı zincir tekrar eder: **(A) İlk 5 saniyede anlaşılan tek kural → (B) sıfır sürtünmeli tekrar döngüsü (ölüm→restart <1 sn) → (C) dışa aktarılabilir bir konuşma nesnesi (skor, klip, "neredeyse" anı).** A eksikse oyun anlaşılmaz, B eksikse kimse ikinci kez açmaz, C eksikse büyüme plateau'ya oturur. Flappy Bird (C: paylaşılabilir frustrasyon), Wordle (C: spoiler'sız emoji grid), Crossy Road (C: YouTuber klon kültürü) aynı zincirin farklı varyantlarıdır.

**Bulgu 2 — Voodoo verisi organikliği nicelleştirir:** D1 ≥ %50 yeşil ışık barı, "Snackable, Youtubable, Straightforward, Not punitive, Innovative" beşlisi, ~10 sn anlaşılma eşiği. Hyper-casual ortalama D1 ~%28-32 iken hit'ler %50+ tutar (Deconstructor of Fun, GameAnalytics, AppsFlyer). Kancanın ölçüsü: **kalanların yarısı ertesi gün geri geliyor.**

**Bulgu 3 — Psikoloji yığını dört katmandan ibaret:** flow kanalı (beceri-zorluk dengesi), değişken-oran pekiştirme (Skinner), kayıp-aversiyonu (Kahneman-Tversky) ve tamamlama dürtüsü (Zeigarnik/goal-gradient). Her katmanın tabloda kanıtlı oyun karşılığı var (Bölüm 4).

**Bulgu 4 — Mevcut Stack Tower Game kanca gücünü içeriğe değil KAPIYA harcıyor:** iç döngü (juice, streak, koleksiyon) hit standartlarında; ama oyuna varış 3 ekran, restart 4 aşama, dışa aktarılabilir nesne sıfır. Organik viralite modelinde "kapı + çıkış" bölümleri darboğaz (Bölüm 5).

**12 kriter → 14 yasa.** Kriterler K1-K12 (Bölüm 3), yasalar Y1-Y14 (Bölüm 6).

---

## 2. Büyük Tablo — 52 Oyun

**Kolonlar:** İlk-30-gün indirilme hızı (≈, kamu verilerinden); **Org** = organiklik (TAM / KISMEN / HAYIR — bkz. Dürüstlük notu); **Tavan** = beceri tavanı.

| # | Oyun | Yıl | İlk-30g (≈) | Org | Çekirdek döngü | Oturum | İlk-5-sn kanca | Yenilenme | Tavan | Neden patladı (1 cümle) |
|---|------|-----|-------------|-----|----------------|--------|----------------|-----------|-------|--------------------------|
| 1 | Flappy Bird | 2013 | 2-3M (patlama 7. ay; 50M/8 ay) | TAM | tap=kanat; boru geç | 2-6 dk | 1 sn'de ölüm + anında restart | sabit zorluk + skor rekoru | Orta | Herkes aynı boruda ölüyor; paylaşılabilir frustrasyon + sıfır sürtünme. |
| 2 | Stack (Ketchapp) | 2017 | ≈10M (App Store #1) | KISMEN (cross-promo ağı) | tap=blok diz | 3-6 dk | menü yok; blok ilk karede düşer | hue döngüsü + halka ödülü | Orta | Tek girdi + içeriksiz görsel çeşitlilik + kusursuzluk şöleni. |
| 3 | Helix Jump | 2018 | ≈20-30M (200M/6-8 ay) | KISMEN (Voodoo kütüphanesi) | swipe=kule döndür | 4-7 dk | düşen top ilk saniyede | tema rotasyonu + ateş serisi | Orta | 3-sn okunabilirlik + ateş modu comeback fantazisi. |
| 4 | Stack Ball | 2019 | ≈25-40M (dünya #1 ayı; 560M+ GP) | HAYIR (UA scale; döngü organik) | basılı tut=disk kır | 5-8 dk | dönme diski ilk karede | ateş modu + yüzlerce bölüm | Orta | Ateş modu = görünür güç fantazisi; her basışta mikro risk. |
| 5 | 2048 | 2014 | ≈10M oyuncu (23M/2 ay) | TAM (açık kaynak) | swipe birleştir | 10-20 dk | tile kaymasının fiziksel tatmini | her oyun farklı; 2048→4096 | Yüksek | Tek cümle kural + açık kaynak klon patlaması (bedava dağıtım ağı). |
| 6 | Wordle | 2021 | 90→300k/gün (2 ayda 100×) | TAM | 6 tahmin | 3-5 dk/gün | günlük tek bulmaca (kıtlık) | günlük sıfırlama | Orta-Yüksek | Spoiler'sız emoji-grid paylaşımı = merak + topluluk ritüeli. |
| 7 | Ballz | 2017 | ≈10M (100M+ toplam) | TAM/KISMEN | swipe ateş; top çoğalır | 5-10 dk | top yağmuru fiziği | sonsuz satır | Orta-Yüksek | Fizik zinciri şöleni + "bir daha" en-yakın-kayıt gerilimi. |
| 8 | Tomb of the Mask | 2016 | ≈1-2M (yavaş; 200M+ toplam) | KISMEN (sonradan Playgendary UA) | 4 yön swipe | 0.5-2 dk | duvarda fırlama hızı | günlük mücadele + 500 bölüm | Yüksek | Retro kimlik + 30 sn seans + anında respawn. |
| 9 | Crossy Road | 2014 | 10M (ilk ay; 340M+ toplam) | TAM | hop ileri | 5-10 dk | voxel kamaşma + ilk adım | karakter makinesi (değişken ödül) | Orta | Cömert F2P (hayat/timer yok) + YouTuber klon kültürü + koleksiyon. |
| 10 | Subway Surfers | 2012 | ≈5-10M (ilk yıl 100M+; 4B toplam) | TAM (UA minimal; "maaşla pazarlama") | swipe 3 şerit | 5-10 dk | muhafız kovalamacası 1 sn'de | şehir turu rotasyonu | Yüksek | Deneyim korunarak az para basmak = 13 yıl word-of-mouth. |
| 11 | Doodle Jump | 2009 | ≈0.1-0.3M (4M ödemeli/1.5 yıl) | TAM | tilt zıpla | 3-6 dk | sonsuz yükseliş | tema DLC + global skor | Orta-Yüksek | Erken App Store az rekabet + tilt input demosu. |
| 12 | Temple Run | 2011 | ≈3M (20M/5 ay) | TAM | swipe koşu | 4-8 dk | maymun korkusu (tweet'lerde paylaşıldı) | hedefler | Yüksek | Korku-paylaşımı + ölüm sonrası anında restart. |
| 13 | Temple Run 2 | 2013 | 50M/13 gün (dönem rekoru) | TAM (seri tabanı 170M) | swipe koşu | 4-8 dk | kayan kamera açılışı | hedefler | Yüksek | Seri mirası + ücretsiz geçiş. |
| 14 | Fruit Ninja | 2010 | ≈0.3-0.5M (Lite organik; 1B toplam) | TAM | swipe kes | 3-5 dk | ilk karpuz patlaması | modlar (Arcade/Zen) | Orta | Dokunmatiğin "kılıç" hissi: yeni input'un demosu. |
| 15 | Angry Birds | 2009 | ≈1M (3 ay sessiz; 50M/1 yıl) | TAM | fırlat fizik | 5-15 dk | kuş fırlatma komiği | bölüm güncellemeleri | Yüksek | Komik yıkım fizik + her yaşa okunabilir karakter IP. |
| 16 | Color Switch | 2015/16 | ≈2-5M (90M/7 ay; 2016'nın 2.'si) | TAM (tek geliştirici, no-code) | tap zıpla; renk kuralı | 2-5 dk | renk kuralı 2 sn'de | 9 mod | Yüksek | Tek kural (rengin=engel) + acımasız zorluk + minimal görsel. |
| 17 | Slither.io | 2016 | 68M/3 ay | TAM | yönlendir; büyü | 5-15 dk | dev yılan görüntüsü | her maç farklı rakip | Yüksek | Agar.io kanıtı + YouTube "dev yılan" kurgusu. |
| 18 | Agar.io | 2015 | web patlaması; mobil 10M+ | TAM | ye/büyü | 5-15 dk | isim etiketi = kimlik | maç başına | Yüksek | Reddit/4chan kültürü + tek kural rekabet. |
| 19 | Suika Game | 2023 | ≈0.1-0.3M → 2. ay patlama (JP #1 aylarca) | TAM (streamer) | bırak-birleştir | 5-15 dk | karpuz merdiveni görseli | fizik kaosu | Orta-Yüksek | İzlenebilir komik fizik + koleksiyon merdiveni. |
| 20 | Block Blast! | 2022 | 2022 sessiz; 2024 ≈18M/ay (216M/yıl) | HAYIR (UA ağırlıklı; tutunma organik) | blok yerleştir 8×8 | 20-40 dk | boş tahta özgürlüğü | streak + combo | Yüksek | Zorunlu-kayıt yok: akış bozulmadan saatler. |
| 21 | Piano Tiles 2 | 2015 | ≈5-15M (1B oyuncu iddiası) | KISMEN (Cheetah UA) | tap ritim | 2-5 dk | tanıdık melodi 2 sn'de | şarkı kütüphanesi | Yüksek (hız) | Müzik + hız yarışı; herkesin bildiği şarkıyla. |
| 22 | Knife Hit | 2017 | ≈5-10M (230M toplam) | KISMEN (cross-promo) | tap bıçak fırlat | 3-5 dk | batma sesi + titreşim | boss tekerlekleri | Orta | Game feel (Ketchapp: "tatmin edici his") + odun ritüeli. |
| 23 | Rise Up | 2018 | ≈10M (100M+ toplam) | KISMEN | kalkan çiz; balonu koru | 3-6 dk | balon kırılganlığı | sonsuz yükseliş | Orta | Koruma dürtüsü + tek parmak kale savunması. |
| 24 | aa | 2014 | ≈2-5M (50M+ toplam) | TAM/KISMEN | tap iğne batır | 1-3 dk | dönme diski | seviyeler | Yüksek | Flappy sınıfı acımasızlık + minimalizm. |
| 25 | ZigZag | 2016 | ≈3-8M (50M+ toplam) | KISMEN | tap yön değiştir | 2-5 dk | kenardan düşme gerilimi | skor | Orta | Tek tap + düşme gerilimi + minimal. |
| 26 | Amazing Brick | 2015 | ≈5-15M (App Store #1) | TAM/KISMEN | tap zıpla; çift tap ters | 1-3 dk | Flappy sonrası boşluk | skor | Yüksek | "En bare-bones" oyunda bile acımasız beceri (r/gamedev). |
| 27 | Don't Touch The Spikes | 2014 | ≈3-8M (10M+ toplam) | KISMEN | tap zıpla; dikenden kaç | 2-4 dk | ölümün komik şiddeti | kuş koleksiyonu (VR) | Orta | Komik ölüm + kuş toplama dürtüsü. |
| 28 | Twisty Arrow | 2017 | ≈5-15M (50M+ toplam) | KISMEN | tap ok at | 2-4 dk | dönme diskine ok | seviyeler | Orta | Ballz/DDTS şablonunun rafine hali. |
| 29 | Woodoku | 2020 | ≈5-15M (100M+ portföy) | KISMEN (Tripledot UA) | blok yerleştir 9×9 | 10-20 dk | satır patlaması | streak + günlük | Yüksek | Sudoku+blok hibriti: "zen ama zor" konumlaması. |
| 30 | Water Sort Puzzle | 2019 | ≈20-40M (500M+ toplam) | KISMEN | dök | 5-15 dk | renk şelalesi ASMR | zorluk + booster | Yüksek (geç) | İlk 20 bölüm neredeyse kaybettirmez (akış rampası) + ASMR. |
| 31 | Happy Glass | 2018 | 10M/haftalar | KISMEN (Lion Studios UA) | çiz; suyu doldur | 3-7 dk | üzgün bardak yüzü | 200+ bölüm | Orta | Duygusal yüz + serbest çizim (herkes farklı çözer). |
| 32 | Love Balls | 2018 | ≈10-20M (50M+ toplam) | KISMEN | çiz; iki topu buluştur | 3-6 dk | "aşk" tek cümle | bölümler | Orta | Duygu + çizim serbestliği. |
| 33 | Paper.io 2 | 2018 | ≈15-30M (100M+ GP) | KISMEN (Voodoo UA) | çember çiz; topla | 2-5 dk | bölge büyümesi | liderlik | Orta-Yüksek | Expand-or-die risk döngüsü + "sanki rakip" botlar. |
| 34 | Hole.io | 2018 | ≈10-20M (50M+ toplam) | KISMEN (Voodoo UA) | yut | 2-4 dk | şehir yutma kaosu | 2 dk maç (net oturum sonu) | Orta | Büyüme fantazisi + kısa net maç. |
| 35 | Perfect Slices | 2019 | ≈10-20M (100M+ toplam) | KISMEN (SayGames UA) | basılı tut; kes | 2-5 dk | bıçak ASMR | bölümler | Düşük-Orta | Sıfır baskı + "oddly satisfying" konumu. |
| 36 | Dancing Line | 2016 | ≈5-15M (100M+ toplam) | KISMEN (Cheetah UA) | tap yön | 3-8 dk | müzik-senkron dünya | şarkılar | Yüksek | Her tap müzikle eşzamanlı = ritim akışı. |
| 37 | Spiral Roll | 2020 | ≈5-15M (50M+ toplam) | KISMEN (Homa UA) | tut; spiral oyma | 3-6 dk | talaş ASMR | bölüm tekrar | Orta | ASMR + kule devirme şöleni. |
| 38 | Cube Surfer | 2020 | ≈5-15M (50M+ toplam) | KISMEN (Supersonic UA) | küp topla; üstünde sur | 3-5 dk | kule büyümesi anlık görünüyor | bölümler | Orta | Kaynak=koruma ikiliği: yükseklik = geçiş biletleri. |
| 39 | Bridge Race | 2020 | ≈20-40M (200M+ toplam) | KISMEN (Supersonic UA) | topla; köprü kur | 3-6 dk | renk kodu + yarış | ligler | Orta | Renk kuralı + yarış gerilimi + itme becerisi. |
| 40 | Count Masters | 2021 | ≈10-25M (100M+ toplam) | KISMEN (Freeplay UA) | kapı aritmetiği | 3-5 dk | kalabalık büyümesi anında | patron/kale ezme | Orta | x2/+15 kapıları sürekli mikro karar + kalabalık görünür ilerleme. |
| 41 | Join Clash 3D | 2020 | ≈10-25M (100M+ toplam) | KISMEN | kalabalık koşu | 3-5 dk | engel ritmi | final çatışma töreni | Orta | Aksiyon 0 sn'de başlar + final şöleni. |
| 42 | Aquapark.io | 2019 | ≈10-25M (100M+ toplam) | KISMEN (Voodoo UA) | kaydırak yarışı | 2-4 dk | yükseklikten atlama riski | bitiş çizgisi şöleni | Orta | Kısa yol riski (beceri ifadesi) + itme. |
| 43 | Cut the Rope | 2010 | 1M/9 gün (dönem rekoru; seri 600M) | TAM (Apple featuring) | kes ip fizik | 3-7 dk | Om Nom + ilk fizik gösterimi | 400+ bölüm | Orta-Yüksek | Sevimli karakter + fizik bulmacanın ilk-5-sn demosu. |
| 44 | Hill Climb Racing | 2012 | yavaş rampa (100M+/3 yıl; seri 1B/2018) | TAM ("significant investment yok" — Fingersoft) | gaz/fren pedalları | 5-10 dk | boyun sarsılması komiği | araç/harita kilidi | Orta-Yüksek | Fizik komiği + çevrimdışı + coin merdiveni. |
| 45 | Jetpack Joyride | 2011 | ≈1-2M (10M+/ilk yıl) | TAM (Halfbrick polish) | basılı tut; uç | 4-8 dk | laboratuvar yıkımı | görevler + araç oyuncakları | Orta | Tek girdi + sürekli yeni oyuncak (araç çekilişi). |
| 46 | Cookie Clicker | 2013 | web viral (milyonlarca/gün) | TAM | tık; yükselt | uzayan (idle) | kurabiye patlaması | üstel bileşik büyüme | Düşük-Orta | Değişken ödül + bileşik büyüme matematiği. |
| 47 | Threes! | 2014 | ≈0.3M ödemeli | TAM (press) | kaydır birleştir | 10-20 dk | tile evrimi | skor | Yüksek | Tek kural derinlik; ama klonu 2048 onu geçti (hız>kusursuzluk dersi). |
| 48 | Monument Valley | 2014 | ≈0.5M ilk ay ödemeli (24M/2017) | TAM (Apple featuring + estetik press) | izometri bulmaca | 5-10 dk | perspektif illüzyon | bölüm sayfaları | Orta | Screenshot-viralite: estetik = paylaşım sebebi. |
| 49 | Alto's Adventure | 2015 | ≈1M ilk hafta | TAM (press + featuring) | tek tap kayak | 3-8 dk | zen gün batımı | görev zinciri | Orta | Zen estetik + minimal input. |
| 50 | Vampire Survivors | 2022 | 30k olumlu yorum/1 ay (27k eşzamanlı) | TAM (streamer; $3 fiyat) | otomatik saldırı; kaçın | 20-30 dk | ekranı dolduran cıvata yağmuru | silah evrimi | Orta | İzlenirken bile anlaşılır + $3 fiyat + dürüst tasarım. |
| 51 | NYT Connections | 2023 | ≈5-10M oyuncu/ilk aylar | TAM (Wordle tabanı) | 4'lü grupla | 3-5 dk/gün | günlük kıtlık | günlük sıfır | Orta-Yüksek | Wordle şablonu + "mor grup" konuşma konusu. |
| 52 | Flow Free | 2012 | ≈2-5M (100M+ toplam) | TAM | çift çiz bağla | 2-5 dk | renk labirenti | 1000+ bölüm fabrikası | Orta-Yüksek | Sıfır metin + bölüm fabrikası + zen. |

**Tabloya girmeyen ama aynı kriterlerle incelenenler (~40):** Flappy klon ailesi (Swing Copters, Flappy Dunk, Flappy Golf; App Store'da dokümante 1000+ klon), 2048 klon ailesi (yüzlerce), .io ailesi (Diep.io, Mope.io, Krunker.io), Bottle Flip 3D, Flip Master, Stack Jump, Fire Rides, Rocket Sky, Woodturning, ASMR Slicing (AppMagic Nisan 2020 iOS #10, 4.1M/ay), Mr Bullet, Pull the Pin, Sling Drift, Fun Race 3D, Two Dots, Candy Crush (organik başlangıç → King cross-promo), Triple Tile, Match Triple 3D, Wordscapes (günlük puzzle + streak), Getting Over It (mobil), Tiny Wings (Voodoo'nun Dune!'un ilham kaynağı), Canabalt, Sushi Go Round tarzı ritimler, Talking Tom (etkileşim oyuncak düzlemi). Ayrıca endüstriyel ölçek: Voodoo 30 günde ABD Free top-300'e 7 oyun sokuyor, 100-200 stüdyoyla yüzlerce prototip test ediyor — "viralite bir oyun şansı değil, kriterlere vurulmuş prototip filtresi" bulgusunun endüstriyel kanıtı.

---

## 3. ORGANİK VİRALİTE KRİTER SETİ (K1-K12)

Her kriter: tanım → kanıt oyunlar → Flutter'da uygulama (CustomPainter/sahne düzeyinde).

### K1 — 3 Saniyede Anlaşılır (System 1 Açılış)
- **Tanım:** Oyuncu oyunu ANLAMADAN oynamaya başlar; kural bilinçli düşünmeyi gerektirmez (Kahneman'ın System 1'i — Voodoo destesinin resmî ilkesi). Voodoo eşiği: ~10 sn; tek girdi şart.
- **Kanıt:** Helix Jump, Stack Ball, Flappy Bird, 2048, Flow Free, Color Switch (tek kural: rengin=engel), Suika. Voodoo barı: D1 %50+ — anlaşılmayan oyun bu barı geçemez.
- **Flutter:** Açılışta MENÜ değil sahne: `runApp` → play_screen. Kural tek bir görsel olayla gösterilir (sahne_painter'a 3 sn'lik "demonstrasyon fazı": yapay blok düşer, mükemmel dizim halka efekti gösterir, sonra kontrol oyuncuya geçer — metin YOK). İlk-5 şeması sabit (twist yasası) bunun deterministik temeli.

### K2 — Menü Arkasında Oyun (Sıfır-Dilim Onboarding)
- **Tanım:** Boot → oyun. Menü en fazla ikinci tık uzaklıkta. Öğretici yok; oyuncu yaparak öğrenir. "Not punitive" (Voodoo beşlisi).
- **Kanıt:** Stack (boot direkt oyun), Flappy ("tap to start" tek satır), Ballz, aa, Tomb of the Mask, Flow Free (hiç metin yok). Crossy Road GDC postmortem: menüden önce oyun.
- **Flutter:** `scene_painter` ilk karede zaten repaint'li (PB-033). Menü ekranı "oyun sonrası" dünyaya taşınabilir: ana akış play_screen + üstte pulsing "DOKUN" CustomPainter (alpha sin dalgası, mevcut menü logo nefes animasyonu mantığı). Harita/mağaza ikinci tıkta.

### K3 — İzlenebilirlik / Watch-Me-Play (Youtubable)
- **Tanım:** Oyunu İZLEYEN 10 saniyede kuralı + gerilimi anlar; tek ekran kompozisyonu, yüksek kontrast skor, dramatik ölüm anı. Voodoo beşlisinin "Youtubable" maddesi.
- **Kanıt:** Vampire Survivors (27k eşzamanlı — izlenirken anlaşılır), Suika (streamer patlaması), Slither ("dev yılan" kurgusu), Flappy (rage klipleri), Crossy (YouTuber klon kültürü), Suika ve Subway'in uzun kuyruğu.
- **Flutter:** Tek sahne kompozisyonu: skor dev kontrast font (HUD raporunda önerilen hierarşi), kamera zoom-out (PB-033 A4 zaten var — 8+ blokta 0.92), ölümde 300ms hit-stop + sarsıntı (PB-016 hit-stop genellebilir). Klip üreten an = "ateş izi + final rotasyonu" (B1) zaten var; bunlar ekranın MERKEZİNDE olmalı, köşede değil.

### K4 — Paylaşılabilir Frustrasyon / Ortak Darboğaz
- **Tanım:** Herkes aynı noktada ölür; skor + ölüm deneyimi evrenseldir → konuşma nesnesi olur. Wordle varyantı: sonuç, cevabı spoiler'sız paylaşılır.
- **Kanıt:** Flappy Bird (boru), Color Switch (renk geçişleri), Ballz (yakın rekor), Stack (halka eksik), Wordle (emoji grid), Connections ("mor grup").
- **Flutter:** Paylaşılabilir skor kartı: `RepaintBoundary` + `toImage(pixelRatio: 3)` → PNG; kartta skor + tür ikonu + "sende kaç blok?" sorusu. Sosyal ağ bağlantısı GEREKMEZ (C-010): kart galeriye kaydeder, kullanıcı nereye koyacağına karar verir. Aynı-bölüm seed (LCG) zaten "herkes aynı bölümü oynadı" garantisini veriyor — kartta bölüm numarası göster.

### K5 — Anında Restart (Kayıp Maliyeti ~0)
- **Tanım:** Ölüm → yeni deneme <1 sn, tek dokunuş. "Not punitive." Hyper-casual ölüm-anı asla ceza ekranı değildir.
- **Kanıt:** Flappy/Tomb/aa/Amazing Brick/Stack Ball (respawn <1 sn), Deconstructor of Fun'un "not punitive" ilkesi, Block Blast (zorsuz çıkış).
- **Flutter:** Kayıpta 4 aşamalı overlay ZAYIF nokta (bkz. Bölüm 5). Kayıp yolu kısaltılmalı: sonuç → tek tap yeni deneme; kutu/tören/tahta yalnız KAZANMA yolunda tam akış. `game_session.dart` reset() tek frame'de; overlay'ler `popStep` yerine tek `Navigator.pushReplacement`.

### K6 — Başarısız Run Bile İlerleme Sayar (Fail-Forward)
- **Tanım:** Kaybedilen koşu bile ekonomiye/meta ilerlemeye katkı yazar; hiçbir 3-5 dakikalık run "boşa gitmez".
- **Kanıt:** Tomb of the Mask (yıldızlar her denemeden), Crossy (coin her koşuda), Ballz (küre kazanımı), Temple Run (hedefler), Stack (toplanan parça), Stack Ball (bölüm ilerlemesi kısmen).
- **Flutter:** Mevcut durumda twist paraları `onWin`'de ödeniyor (twist kancaları notu) — kaybeden run ekonomiye yazmıyor olabilir. Düzeltme: `onRunEnd` ödemesi (kayıpta toplanan parçalar cüzdanda kalır); bu C-002'ye dokunmaz (sunum/ödül katmanı).

### K7 — Oturum Sonu Cliff-Hanger
- **Tanım:** Oturum kapanırken "sonraki seferde ne olacak" bilgisi görünür kalır; bitiş, açık bir kapıdır.
- **Kanıt:** Water Sort (sonraki bölüm teaser'ı), Woodoku (streak gösterimi), Crossy (makinede bekleyen karakter), Wordscapes (günlük teaser), Suika (karpuz merdiveninin eksik halkası).
- **Flutter:** PB-033 C5 "NEREDEYSE!" satırı bu yasanın ilk adımı; eksik olan: sonuç ekranında `construction.dart` bir sonraki yapı parçasının SİLÜETİ + "3 parça sonra YENİ YAPI" satırı (haritadaki SIRADA ipucunun sonuç ekranına taşınması — mevcut metin+Semantics deseni yeniden kullanılır).

### K8 — Değişken Ödül Programı (Skinner VR)
- **Tanım:** Ödül TAHMİN EDİLEMEZ kuyruğun ucunda; nadir jackpot ara sıra gelir. Sabit ödül alışkanlık, değişken ödül davranış yaratır (Skinner'ın değişken-oran pekiştirmesi; slot near-miss dopamin kanıtı).
- **Kanıt:** Crossy Road karakter makinesi (ana vaka), Don't Touch The Spikes kuş çekilişi, Cookie Clicker upgrade patlaması, Subway sandıklar, Water Sort booster öncesi near-miss.
- **Flutter:** Pazar gün-tohumlu (deterministik) — sürpriz hissi zayıf. Sandık ödül dağılımı VR ağırlıklarına çekilmeli (örn. %70 yaygın / %25 nadir / %5 jackpot; `_fxRnd` değil kayıt-tohumlu LCG — adil ve tekrarlanabilir). Jackpot YOKSA "neredeyse jackpot" görseli (near-miss effect).

### K9 — Bedava Çeşitlilik (Parametrik Tema)
- **Tanım:** İçerik üretmeden yenilik hissi: hue döngüsü, palet fazı, ses imzası her oturumda/har bölümde kayar.
- **Kanıt:** Stack (sürekli hue kayması), Helix Jump (temalar), Subway (şehir turları), Piano Tiles 2 (şarkılar), Dancing Line (müzik-senkron dünyalar).
- **Flutter:** `levelSignature(i)` (PB-033) zaten bunu yapıyor — A3 60sn ±4° hue döngüsü + deterministik palet faz. Genişletme: aynı imza ses döngüsüne pitch offset verir (audio.dart playbackRate) — görsel+işitsel çeşitlilik tek deterministik fonksiyondan.

### K10 — Ses İmzası + Juice (Pitch Merdiveni, ASMR)
- **Tanım:** Seri başarıda yükselen pitch; dokunuş sesleri ASMR düzeyinde tatmin edici; feedback ekranın %50'si (Juice it or Lose it: "juicy game continually responds").
- **Kanıt:** Stack (pitch merdiveni — kombo yükseldikçe nota çıkar), Spiral Roll/Perfect Slices (ASMR), Piano Tiles (melodi ödülü), Knife Hit (Ketchapp'ın kendi açıklaması: "unique and satisfying game feel").
- **Flutter:** audio.dart 27 ses mevcut; pitch merdiveni: kombo derinliğine göre `playbackRate = 1.0 + kombo/12` (mevcut hit-stop/konfeti PB-016 ile birlikte). Juice yasaları (C-023) zaten var — eksik olan PITCH boyutu.

### K11 — Kısa Dönemsellik / Günlük Ritüel (Kıtlık)
- **Tanım:** Günlük TEK slot/streak — fazla içerik kıtlığı öldürür, kıtlık geri dönüşü zorunlu kılar (Wordle'ın tek bulmacası).
- **Kanıt:** Wordle (günde 1), Connections (günde 1), Tomb of the Mask (daily), Wordscapes (daily + streak), Woodoku (günlük), Suika (yok ama seans kısalığı tamamla).
- **Flutter:** PB-034 (günlük takvim + streak + streakShield) bu yasanın neredeyse tam uygulaması — Duolingo Streak Freeze deseniyle birebir. Korunmalı; "günlük tek serbest slot" sayısı artırilmamalı (kıtlık yasası).

### K12 — Beceri Tavanı + Skill Expressiveness (Geliyorsa-Gönder)
- **Tanım:** Usta oyuncu, yeni başlayanın yapamayacağı GÖRÜNÜR bir şey yapar (ateş modu, dev yılan, açı ustalığı); mahallede "onu o sen mi yaptın" der.
- **Kanıt:** Stack Ball ateş modu (siyah dahil kır), Helix ateş serisi, Slither dev yılan, Ballz açı hesabı, Piano Tiles hız eşiği, Tomb hız survival.
- **Flutter:** A2 ateş izi (combo≥3) var; master anı ekranı: 5+ mükemmel seride kule altın parlar + özel ses + mini hit-stop tavanı (70ms) — dışarıdan bakınca da fark edilir. Beceri ifadesi paylaşım kartına (K4) skorla birlikte "kombo X" damgası.

---

## 4. "NEDEN TUTUYOR" PSİKOLOJİSİ — 6 Katman, Oyun Kanıtı + Uygulama Yolu

### 4.1 Flow Kanalı (Csikszentmihalyi; Jenova Chen tezi; 2020 mobil çalışması)
- **Bilim:** Akış, algılanan zorluk ≈ algılanan beceri bandında oluşur; zorluk beceriyi aşarsa kaygı, beceri zorluğu aşarsa can sıkıntısı. Jenova Chen (flow/Journey) bunu dinamik zorluk ayarıyla oyuna taşır; 2020 araştırması mobilde zorluk-artışı üzerinden beceri-zorluk dengesinin "oynamaya devam dürtüsünü" doğrudan yordadığını gösterir.
- **Oyun kanıtı:** Water Sort Puzzle ilk 20 bölüm neredeyse kaybettirmez (alışkanlık/akış kurulur, sonra sürtünme); Helix/Stack Ball hız rampası; Woodoku "zen ama zor"; Stack bölüm eğrisi.
- **Bizde:** 150 bölüm rampası + twist dağıtım yasası (ardışık ≤2, ilk-5 sabit) zaten frustrasyon tavanı çiziyor. Eklenecek yasa: **asla 2 ardışık tam-frustrasyon** — kayıp sonrası bölüm zorluğu görsel olarak aynı kalsa da (C-002 paritesi) sunum tarafında "yakın olma" metaforu (NEREDEYSE) akışı onarır.

### 4.2 Öz-Belirleme Teorisi (SDT — Ryan/Rigby/Przybylski 2006, PENS)
- **Bilim:** Oyun motivasyonu üç ihtiyacın doyurulmasını yordar: **competence** (yeterlilik), **autonomy** (anlamlı seçim), **relatedness** (bağ). Kanonik makale ~5.800 atıf; oyun keyfinin ve devam motivasyonunun en güçlü yordayıcısı competence.
- **Oyun kanıtı:** Competence: Stack kusursuz dizim + halka; Ballz açı ustalığı. Autonomy: 2048/Wordle (herkes kendi stratejisi), Happy Glass (herkes farklı çizer), Woodoku taş seçimi. Relatedness: zayıf örneklerde bile leaderboard yeterli (Doodle Jump global skor; Subway friend-race).
- **Bizde:** Competence: hit-stop + kombo (var). Autonomy: 10 tür + günlük/serbest (var) — ama seçim metin ağırlıklı sunuluyor; ikonla 1-sn okunmalı. Relatedness: leaderboard_service + LCG bot tahtası var; kart paylaşımı (K4) eksiği.

### 4.3 Değişken Ödül (Skinner) + Near-Miss Dopamin
- **Bilim:** Değişken-oran pekiştirme, sabit oranadan kalıcı davranış üretir; slot "near-miss"inde dopamin ödül beklentisini yükseltir (dopamin ödül değil BEKLENTİ sinyalidir).
- **Oyun kanıtı:** Crossy karakter makinesi (uygulamanın en temiz VR örneği), Cookie Clicker, DTS kuş çekilişi, Subway sandıklar; "NEREDEYSE" ekranları near-miss'in literatür karşılığı.
- **Bizde:** Sandık dağılımını VR ağırlıkla (K8) + PB-033 C5 "Rekoruna N blok kaldı" satırı near-miss bütçesinin parçası — görsel olarak büyütülmeli (amber, CountUp).

### 4.4 Kayıp-Aversiyon (Kahneman-Tversky; Duolingo Streak)
- **Bilim:** Kayıplar eşdeğer kazançtan ~2× ağır hissedilir (prospekt teorisi). Duolingo bunu streak + Streak Freeze ile kurumsallaştırdı; streak kaybı ayrı bir churn riski olduğu için "kalkan" mekaniği şart.
- **Oyun kanıtı:** Tomb of the Mask günlük serisi, Woodoku streak, Wordscapes günlük, Subway weekly hunt.
- **Bizde:** PB-034 streakShield = Streak Freeze birebir; 7. gün büyük ödül + telafi kalkanı tasarımı literatürle örtüşüyor. Bu mevcut en güçlü organik tutunma varlığımız — görünürliği artırılmalı (menü ikonunda streak rozeti).

### 4.5 Koleksiyon / Tamamlama Dürtüsü (Zeigarnik + Endowed Progress + Goal-Gradient)
- **Bilim:** Tamamlanmamış kümeler hafızada baskın kalır (Zeigarnik); yapay başlangıç ilerlemesi motivasyonu artırır (endowed progress); hedefe yaklaştıkça çaba hızlanır (goal-gradient). Set tamamlama, kullanım değerinden bağımsız bir "daha yüksek iyi" olarak deneyimlenir (Psychology Today).
- **Oyun kanıtı:** Crossy (karakterler), DTS (kuşlar), Suika (karpuz merdiveni görsel ilerleme), Subway (karakter hunt), Wordscapes (günlük set).
- **Bizde:** "N parça eksik" defteri (PB-034 ÖDÜL ODASI) = Zeigarnik görünümü; "SIRADA: yapı · n/m" = goal-gradient görünürleştirmesi. Ekleme: yeni kayıtta ilk yapı %25 hazır başlasın (endowed progress) — cömertlik kısıtı C-019 ile uyumlu.

### 4.6 Ustalık Hissi + Ateş Modu (competence'in görünen hali)
- **Bilim:** SDT competence + flow teorisi: gelişimin GÖRÜNÜR olması gerekir. Ateş modu, beceri serisini geçici güç durumuna çevirir — hem comeback hem fantazi.
- **Oyun kanıtı:** Stack Ball ateş (siyah dahil kırar), Helix ateş serisi, Stack halka, Piano Tiles hız aşması.
- **Bizde:** A2 ateş izi combo≥3 var. Eksik: serinin ÖDÜLÜ görünmüyor — 5+ seri için "altın kule" parıltısı + ses imzası önerilir (sunum katmanı; drop_core dokunulmaz).

---

## 5. ELEŞTİRİ — Stack Tower Game Kriter Karnesi (acımasız)

**Özet:** İç döngü hit kalitesinde; kapı ve çıkış hit değil. "Kancası güçlü, kapısı yavaş oyun."

| Kriter | Skor /10 | Acımasız değerlendirme |
|--------|----------|------------------------|
| K1 3-sn anlaşılır | **4** | Oyunun kendisi 3 sn'de anlaşılır AMA oyuncu oyuna 3 ekran sonra varıyor (menü→harita→önizleme). PB-030 tür kartı + ipuçları METİN ağırlıklı; Türkçe paragraf okumak System 1'i System 2'ye çevirir. Kural gösterilmeli, anlatılmamalı. |
| K2 menü arkasında oyun | **2** | Boot menüde açılıyor. Stack/Flappy/Ballz boot→oyun derken ikinci tıkı kastederken biz üçüncü-ekrandayız. En büyük yapısal sapma. |
| K3 izlenebilirlik | **5** | Sahne net (repaint onarımı, zoom A4) ama HUD yoğun; 3B harita güzel ama oyunun kendisi tek-ekran klip üretmiyor. Ölüm anı dramatik ama "klip kapısı" yok. |
| K4 ortak darboğaz/paylaşım | **3** | LCG deterministik seed "herkes aynı bölümü" garantisini veriyor — muhteşem temel — ama paylaşılabilir nesne YOK: skor kartı, ekran görüntüsü formatı, "sende kaç?" sorusu hiçbiri yok. Viralite borusu kapalı. |
| K5 anında restart | **3** | Kazanma yolu kutu→tören→tahta→sonuç 4 aşama (türensel olarak doğru); KAYIP yolu da aynı ağırlıkta duruyor. Flappy <1 sn iken bizde kayıp→yeniden deneme ~10-20 sn. Hyper-casual ölüm standardının altında. |
| K6 fail-forward | **6** | "NEREDEYSE" satırı var; ama twist paraları onWin'de — kaybeden run ekonomiye muhtemelen yazmıyor. Kayıp run'ın bile para/parça bırakması gerekir (Tomb/Crossy standardı). |
| K7 cliff-hanger | **5** | SIRADA ipucu haritada; sonuç ekranında değil. Cliff-hanger oturum sonu anında görünmeli. |
| K8 değişken ödül | **4** | Pazar gün-tohumlu → oyuncu "yarın 3 ürün" görebiliyor (öngörülebilir!). Öngörülebilir ödül alışkanlık yaratır, dürtü yaratmaz. Sandık VR ağırlığı yok; jackpot + near-miss bütçesi yok. |
| K9 bedava çeşitlilik | **8** | levelSignature + aurora + 10 tema + 3B harita — bu raporun en güçlü alanı. |
| K10 ses imzası | **7** | 27 ses + müzik döngüsü (84 BPM) iyi; PITCH MERİ-diveni yok (Stack'in en ucuz büyüsü). |
| K11 günlük ritüel | **9** | streak + streakShield + takvim + pazar YARIN şeridi — Duolingo/Crossy standardında, hatta kalkan telafisiyle önde. |
| K12 skill expressiveness | **6** | Ateş izi var; ama "usta anı" oyunun dışına sızmıyor (paylaşım yok) ve serinin ödülü görsel zirveye çıkmıyor. |
| **Toplam** | **62/120** | İç döngü ≈ hit; giriş/bölüm/paylaşım ≈ ortalama öncesi. |

**En ölümcül 3 bulgu:** (1) İlk oyun üç ekran geride — K2 ihlali tüm organik huninin üstünü kapatır. (2) Paylaşılabilir nesne sıfır — K4 ihlali büyümeyi store-keşfine mahkûm eder. (3) Kayıp→tekrar yolundaki aşama yükü — K5 ihlali D1'inin en kritik bileşeni (anında yeniden deneme) öldürür.

**Dürüst güçlü yanlar (asla kırılmamalı):** sıfır reklam + cömertlik (C-010/C-019 — Crossy/SYBO/Vampire Survivors kanıtının tam izinde), Türkçe kimlik, streak kalkanı, parametrik tema, juice paketi, 10-tür antoloji (autonomy).

---

## 6. SONUÇ — DOĞRULANMIŞ TASARIM YASALARI (Y1-Y14)

Her yasa: ifade → kanıt → Flutter uygulama yolu.

**Y1 — İlk saniye oyun olsun.** Boot→oyun; menü ikinci tık.
*Kanıt:* Stack, Flappy, Ballz, aa, Crossy (GDC), Voodoo 3-sn kuralı. *Flutter:* ana rota play_screen; menü sahne-sonrası; "DOKUN" pulsing painter.

**Y2 — Tek cümle kuralı.** Oyun tek cümleyle anlatılır; o cümlede ölüm-kazanç nettir.
*Kanıt:* Color Switch ("rengin=engel"), Flow Free, Suika, 2048, Voodoo "Straightforward". *Flutter:* tür kartı metni ≤6 kelimeye indirilir; kural demosu K1'deki 3-sn demonstrasyon fazı.

**Y3 — Kaybın maliyeti 1 saniye.** Ölüm→restart tek dokunuş; kayıp ceza ekranı değil, eşiktir.
*Kanıt:* Flappy, Tomb, aa, Stack Ball; "Not punitive" (Voodoo). *Flutter:* kayıp yolunda tek-tap restart; kutu/tören/tahta akışı yalnız kazanma yolunda.

**Y4 — Her run ekonomiye yazar.** Kaybeden run bile para/parça bırakır; hiçbir deneme boşa çıkmaz.
*Kanıt:* Tomb, Crossy, Ballz, Temple Run hedefleri. *Flutter:* onRunEnd ödül satırı (kayıpta toplananlar cüzdanda; C-002 dokunulmaz).

**Y5 — İzleyici 10 saniyede anlar.** Sahne tek ekran kompozisyonu: skor dev, merkez olay merkezde, ölüm klibe değer.
*Kanıt:* Vampire Survivors, Suika, Slither, Flappy klipleri; "Youtubable". *Flutter:* HUD hiyerarşisi + hit-stop/sarsıntı ölümde; RepaintBoundary→toImage klip karesi.

**Y6 — Ateş modu yasa.** Seri başarı görünür, geçici güç durumuna dönüşür.
*Kanıt:* Stack Ball, Helix Jump, Stack halkası, Piano Tiles hız aşması. *Flutter:* combo≥3 ateş izi mevcut → 5+ seride altın kule + pitch tırmanışı.

**Y7 — Değişken ödül kuyruğu.** Ödül anı belirsiz kuyruğun ucunda; nadir jackpot; near-miss görüntülenir.
*Kanıt:* Crossy makinesi, DTS kuşlar, Cookie Clicker, slot near-miss dopamin. *Flutter:* sandık VR ağırlıkları (LCG kayıt-tohumlu), %5 jackpot, "neredeyse" görseli.

**Y8 — Kayıp-aversiyon hizmette.** Streak + kalkan + "neredeyse" satırı; kayıp hissini üretme, koruma hissi ver.
*Kanıt:* Duolingo Streak Freeze, Tomb/Woodoku streak. *Flutter:* PB-034 korunur; streak rozeti menü ikonuna; NEREDEYSE amber + CountUp.

**Y9 — Eksikliği görünür kıl.** "N parça eksik" her zaman görünür; bitmeye yaklaşan kümeler hızlanır.
*Kanıt:* Zeigarnik + goal-gradient; Crossy, Suika merdiven, Wordscapes set. *Flutter:* defter ilk sayfada; sonuç ekranında silüet + "3 parça sonra YENİ YAPI".

**Y10 — Bedava çeşitlilik.** İçeriksiz yenilik: deterministik parametrik tema/hue/ses imzası her bölümde kayar.
*Kanıt:* Stack hue, Helix temalar, Subway şehirler, Dancing Line. *Flutter:* levelSignature→playbackRate köprüsü; A3 döngüsü korunur.

**Y11 — Günlük kıtlık.** Günde TEK ritüel slotu; bolluk ritüeli öldürür.
*Kanıt:* Wordle, Connections, Tomb daily, Wordscapes. *Flutter:* günlük slot sayısı artırılmaz; streak görünürliği artırılır.

**Y12 — Zorluk kanalı.** Rampada asla 2 ardışık tam-frustrasyon; kayıp sonrası akış onarıcı sunum.
*Kanıt:* Water Sort erken kolaylık, Toon Blast tepe kalıbı (DNA raporu), flow araştırması. *Flutter:* twist dağıtım yasası (ardışık ≤2) dokunulmaz; NEREDEYSE + Y4 ödülü frustrasyon amortisörü.

**Y13 — Oturum sonu cliff-hanger.** Bitiş açık kapıdır: sonuç ekranında bir sonraki seferin teaser'ı.
*Kanıt:* Water Sort, Woodoku, Crossy makine birikimi. *Flutter:* sonuç ekranı + construction silüeti + günlük slot saati teaser'ı.

**Y14 — Dürüstlük = word of mouth.** Agresif monetizasyon organik büyümenin vergisini öder; cömertlik paylaşılabilirliği besler.
*Kanıt:* Crossy (hayat/timer yok → $10M/3 ay + 340M), SYBO ("para masada bırakılır"), Vampire Survivors ($3 + dürüst tasarım), Monument Valley/Alto estetik dürüstlüğü; karşı örnek: ad-estoplu klonlar hızla ölür. *Flutter:* C-010/C-019 zaten yasaklıyor — asla gevşetilmemeli.

---

## 7. Kaynaklar (seçilmiş)

- Deconstructor of Fun — [5 Ways Voodoo Dominates the Hyper-Casual Market](https://www.deconstructoroffun.com/blog/2018/8/1/5-ways-voodoo-dominates-the-hyper-casual-market); [Four Reasons Why the Hypercasual Gold Rush is Ending](https://www.deconstructoroffun.com/blog/four-reasons-why-the-hypercasual-gold-rush-is-coming-to-an-end)
- Voodoo — [How to Hypercasual destesi (Scribd)](https://www.scribd.com/presentation/476731584/VOODOO-HOW-TO-HYPERCASUAL); [Voodoo Guide: Keep Things Simple (GameAnalytics)](https://www.gameanalytics.com/blog/voodoo-guide-mobile-game-design-keep-things-simple)
- Flappy Bird — [2080.ventures: 5 Things That Got Flappy Bird 50M](https://www.2080.ventures/insights/5-things-that-got-flappy-bird-50-million-in-downloads)
- Helix Jump — [PocketGamer.biz case study](https://www.pocketgamer.biz/hot-five-october-29th-2018)
- Stack Ball/Azur — [Sensor Tower 2024 #1 publisher](https://azurgames.com/blog/sensor-tower-summarizes-2024-azur-games-ranks-1-in-downloads-among-game-publishers); [GamesBeat: 1.5B downloads](https://gamesbeat.com/how-azur-games-grew-its-hypercasual-games-to-1-5b-downloads)
- 2048 — [IndieMakerList](https://indiemakerlist.com/products/2048)
- Wordle — [Smithsonian](https://www.smithsonianmag.com/smart-news/heres-why-the-word-game-wordle-went-viral-180979439); [Go Braithwaite](https://gobraithwaite.com/thinking/why-wordle-went-viral); [CNBC psikoloji](https://www.cnbc.com/make-it/2022/02/15/bite-sized-fun-the-psychology-behind-your-sudden-wordle-obsession.html)
- Crossy Road — [Thumbsticks: How Hipster Whale reinvented F2P](https://thumbsticks.com/crossy-road-hipster-whale/); GDC postmortem kapsamı
- Subway Surfers — [RevenueCat Sub Club (SYBO CEO)](https://www.revenuecat.com/blog/growth/subway-surfers-mathias-gredal-norvig-sub-club-2025); [Business of Apps](https://www.businessofapps.com/data/subway-surfers-statistics)
- Tomb of the Mask — [martinvanblerk.com analiz](https://www.martinvanblerk.com/blog-posts/these-are-5-of-the-most-popular-hyper-casual-mobile-games-in-2024)
- Ballz/Ketchapp — [TechCrunch inceleme](https://techcrunch.com/2017/04/19/ballz-is-infuriatingly-fun/); Naavik Hypercasual Past/Present/Future
- Temple Run — [TechCrunch](https://techcrunch.com/2012/01/12/temple-run-how-evil-monkeys-chased-the-app-store-to-no-1/); TR2: [GamesIndustry.biz](https://www.gamesindustry.biz/temple-run-2-hits-50m-downloads-in-two-weeks)
- Cut the Rope — [NBC News (1M/9 gün)](https://www.nbcnews.com/tech/tech-news/superb-cut-rope-game-ties-iphone-ipad-charts-flna126717)
- Hill Climb — [PocketGamer.biz (organik, 1B)](https://www.pocketgamer.biz/fingersofts-hill-climb-racing-franchise-rolls-past-one-billion-downloads)
- Slither.io — [Root-Nation derin analiz](https://root-nation.com/en/games-en/games-articles-en/en-slither-io-and-agar-io-behind-the-game-scene)
- Color Switch — [GamesBeat: 40 oyundan sonra](https://venturebeat.com/games/after-40-mobile-games-david-reichelt-hit-gold-with-color-switch-exclusive/)
- Suika — [Nintendo Life](https://www.nintendolife.com/news/2023/10/random-switch-exclusive-watermelon-game-goes-viral-eshop-downloads-skyrocket); [Japan Times](https://www.japantimes.co.jp/business/2023/12/25/tech/suika-game-aladdin-x)
- Block Blast — [Global Games Forum (UA itirafı)](https://www.globalgamesforum.com/topic-theme/how-block-blast-shattered-records-with-ai-a-b-testing-and-a-bold-bet-on-long-term-players)
- Happy Glass/Love Balls — [Uptodown analizi](https://blog.en.uptodown.com/happy-glass-casual-love-balls)
- Paper.io 2/Hole.io — [Voodoo kataloğu + Sensor Tower](https://app.sensortower.com/overview/io.voodoo.paper2?country=IN)
- Wordscapes — [Ludocious/Naavik analizi](https://ludocious.com/index.php?p=blog&u=naav-worldscapes)
- Vampire Survivors — [HowToMarketAGame (Zukowski)](https://howtomarketagame.com/2022/01/31/vampire-survivors-success-an-opportunity-in-the-steam-marketplace); [Vice](https://www.vice.com/en/article/how-vampire-survivors-went-from-obscurity-to-27000-people-playing-at-once)
- Monument Valley/Alto — [App Samurai case study](https://appsamurai.com/blog/mobile-app-success-story-how-monument-valley-did-it)
- Akademik: [Ryan/Rigby/Przybylski 2006 (SDT)](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf); [Jenova Chen — Flow in Games](https://www.jenovachen.com/flowingames/Flow_in_games_final.pdf); [Beceri-zorluk dengesi ve devam dürtüsü (2020)](https://www.researchgate.net/publication/344654501_The_relationship_between_the_skill-challenge_balance_game_expertise_flow_and_the_urge_to_keep_playing_complex_mobile_games); [Near-miss dopamin çalışması](https://www.researchgate.net/publication/49732041_Dopamine_Modulates_Reward_Expectancy_During_Performance_of_a_Slot_Machine_Task_in_Rats_Evidence_for_a_'Near-miss'_Effect); [Duolingo streak/loss aversion](https://blog.duolingo.com/how-duolingo-streak-builds-habit); [Zeigarnik — Laws of UX](https://lawsofux.com/zeigarnik-effect); [Endowed progress](https://uxdesign.cc/endowed-progress-effect-give-your-users-a-head-start-97d52d8b0396); [Juice it or Lose it (GDC)](https://www.youtube.com/watch?v=Fy0aCDmgnxg)
- Ölçüm benchmarkları — [GameAnalytics hyper-casual raporu](https://www.gameanalytics.com/blog/the-metrics-behind-hyper-casual-games-industry-report); [Adjust puzzle retention](https://www.adjust.com/blog/how-to-make-a-hyper-casual-game-successful)

*Not: Tüm öneriler sunum/akış/meta katmanındadır; drop_core (C-002), twist dağıtım yasası (C-009/C-017) ve 10-tür antoloji kısıtları (C-020) korunur. İndirme rakamları kamu kaynaklardan yaklaşık (≈) — kesin ilk-30-gün verisi yalnızca Temple Run 2, Cut the Rope ve Crossy Road için ifşa edilmiştir.*
