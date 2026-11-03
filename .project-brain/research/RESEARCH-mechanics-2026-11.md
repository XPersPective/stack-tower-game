# RESEARCH: Mekanik Kataloğu 2026-11 — 20 Benzersiz Premium Mini-Tür Tasarımı

- **Tarih:** 2026-11-03
- **Kapsam:** 38 çekirdek mekanik (istifleme çekirdeği VE mevcut 10 mini-tür dışında), 2024-2026 pazar trendleri, premium indie vizyonu, virallik psikolojisi
- **Yöntem:** Web araması (AppMagic/Game Refinery/Liftoff/GameAnalytics trend verileri, Apple Design Award kayıtları, viral analizler) + mevcut kod tabanının mekanik envanteri (`lib/game/kinds/*` fiil haritası) + tasarım dekonstrüksiyonu
- **Hedef:** Kullanıcı yönü 2026-11: "20 benzersiz premium oyun tasarımı — her biri farklı mekanik, basit istifleme DEĞİL; küp, üçgen, 3B farklı şeyler; her bölüm birbirinden farklı; kullanıcı kaybetse bile tekrar oynamak isteyecek."
- **İlgili kısıtlar:** C-022 (TEK dokunuş + 3 sn okunabilirlik), C-020/C-017 (bölüm çeşitlilik yasası), C-023 (juice yasaları), C-001/C-016 (premium kalite tabanı), C-015 (paket serbestliği ama karar kriteri kalite), C-018 (gacha/gerçek para yok), C-002 (STACK çekirdek paritesi bozulmaz), ADR-002 (Flame/fizik motoru YOK — CustomPainter).
- **Mevcut 10 tür (SAYILMAZ — bunların dışındaki mekanikler kataloglandı):** STACK (yatay kayar + dikey istif), CATCH (dodge/collect), RING (dönen işaretçiyi dilimde durdur), LAUNCH (nişan+şarj fırlatma), MERGE (eşit çift birleşme, eriyen süre), PATH (Euler düğüm çizimi), SORT (sütun topları ayırma), BALANCE (tahterevalli), DEFEND (dalga kesiş kalkanı), RHYTHM (vuruş çizgisi notaları).

---

## 0. Yönetici Özeti

1. **Pazar 2025'te rotayı çevirdi:** hiper-casual öldü, **hybrid-casual** varsayılan model oldu (D7: ~5-8% → hedef 15-20%). 2025'in kırılan hit'leri (Color Block Jam, Screwdom, Crowd Express) hepsi "hiper-casual mekanik + tasarlanmış bölüm + meta derinlik" formülüyle büyüdü. AppMagic'in ifadesiyle hybrid-casual, "viral hiper-casual mekaniklerin ikinci hayatının yaşandığı yer" haline geldi. Bu, tam olarak bu projenin zaten kurduğu yapıdır (150 bölüm + pazar yeri + günlük kancalar + görünür inşaat): **eksik olan tek şey mekanik çeşitliliğidir.**
2. **38 mekanik kataloglandı; 20'si seçildi.** Seçim filtresi: tek dokunuş (C-022), 3 sn okunabilirlik, CustomPainter'da 60fps (ADR-002), mevcut 10 tür + istifleme ile fiil düzeyinde çakışmama, organik virallik (klip-lenebilir doruk anı), premium görsel potansiyeli.
3. **"Kaybetse bile tekrar oynamak isteyecek" = near-miss mühendisliği.** Block Blast'ın ~70M DAU'ya taşınmasının arka planı: zorluk dağıtımının "hileli sandığı" spekülasyonu değil, kaybı "neredeyse" hissettiren adaptif dağıtım + anında yeniden başlama. Projede PB-033 C5 "NEREDEYSE! Rekoruna N blok kaldı" satırı zaten bu yasanın ilk taşını koydu; yeni 20 türün hepsi bu yasayla doğacak.
4. **En güçlü 5 (etki/maliyet):** Vidayla-Sökme, Açı-Bounce Kırma, Işık-Karanlık Keşif, Ayna-Kopya Karakter, Halat Sallanma.
5. **Önerilen 3 dalga:** Dalga 1 (6 tür, düşük maliyet, mevcut juice/ses/ekonomi altyapısına en yakın), Dalga 2 (9 tür, orta maliyet, yüksek farklılaşma), Dalga 3 (5 tür, imza/premium vizyonu).

---

## 1. Pazar Bağlamı (2024-2026): Sayılarla

### 1.1 Hybrid-casual devrimi

| Veri | Değer | Kaynak |
|------|-------|--------|
| Hiper-casual D7 tutundurma | ~%5-8 | r/gamedev tartışması |
| Hybrid-casual D7 hedefi | %15-20 | r/gamedev + Appier |
| GameAnalytics 2025 medyan | D1 ~%22, D7 ~%4-5, D30 ~%0.7 | GameAnalytics Mobile Benchmarks 2025 |
| En iyi hiper-casual D1 | %38-40 | Sensor Tower / appagent |
| Hybrid-casual Q1 2025 net IAP | 87M$, +%67 YoY | AppMagic |
| Q1 2025 lideri | "The Great Puzzle" — Hole.io-tür çekirdeğe ilerleme katmanı | AppMagic |
| Q3 2025 liderleri | Color Block Jam (33M$), Screwdom, Crowd Express, Screw Sort Pin Jam 3D — Rollic 4 sıra | AppMagic |
| Block Blast ölçek | ~70M DAU / ~300M MAU (2025 sonu-2026 başı) | Inc./Wikipedia |
| Screwdom zorluk ayarı | bazı seviyelerde ~%2.3 başarı → booster/IAP itici | AppMagic analizi |

**Ders:** 2025-2026'da "viral mekanik" yalnız değildir; onu taşıyan şey **bölüm tasarımı + meta ilerleme + tören** üçlüsüdür. Projede bu üçlü VERIFIED durumda (construction-meta, pazar yeri, anıt töreni). Yeni mekanikler bu iskelete takıldığında hybrid-casual üstünlüğü kod seviyesinde hazır gelir.

### 1.2 Viral mekaniklerin anatomisi (2025 kanıtları)

- **Color Block Jam:** viral hiper-casual mekanik (blok kaydırma) → tasarlanmış seviyeler + IAP ile ikinci hayat. Mekanik yalnız; paketleme her şey.
- **Screwdom:** sökme/vidalama — dokunsal ASMR tatmin + "altında ne var" merakı + agresif zorluk tavanı.
- **Block Blast:** %5'ten az fikir üretime giriyor ("experience equality" — Hungry Studio); uzun-ömürlü oyuncu bahsi; near-miss odaklı dağıtım algısı (decompile analizi).
- **Crazy Cattle 3D:** kaotik fizik komedyası + meme-potansiyeli; UA parası yerine TikTok/Reddit organik yayılımı (Nisan 2025). Ders: **klip-lenebilir kaos** organik viralliğin motorudur.
- **Core Ball:** saf tek-tap zamanlama gerilimi; "kolay öğren, zor ustalaş" DNA'sı.
- **TikTok formatı:** "satisfying max-level run" + CapCut hızlı kesme + altyazı; yüksek enerjili "imkansız oynanış" kancaları. Yani yeni türlerin **doruğu 3-5 saniyelik klip için tasarlanmalı** (RESEARCH-dna L6 "bölüm sonu şöleni"nin kısa-video formu).

### 1.3 Premium vizyon (Apple Design Award çizgisi)

- **Balatro** (2025 ADA "Delight and Fun" galibi): tek çekirdek döngü × sonsuz kombinatorik çeşitlilik = "bir daha oyna" bağımlılığı. 
- **NYT Games** (2024 ADA galibi): günlük ritüel + streak koleksiyonu (projedeki takvim/streak yasasının ADA kanıtı).
- **Monument Valley 3** (ustwo, 2024): perspektif-döndürme geometrisi; ilk 2 bölüm ücretsiz + tek premium IAP; PC/konsola açıldı (2025). Mobilde premium sanat stilleri yaşadığını gösterir; MRV serisi ~15M$ ömür-boyu gelirle referans.
- **Alto's Odyssey**: zen atmosfer + görsel ton değişimi = "mekanik değişmeden içerik çeşitliliği" (bizde `levelSignature` hue-fazı zaten bu yasayı uygular).
- **Limbo/Inside/Gris/Journey**: tek dokunuş-mahalle girdiler + karanlık/ışık/atmosfer anlatımı; "satisfying" değil "duygusal" tırtıklama. Kataloğdaki Işık-Karanlık ve Duet satırları bu çizgiden beslenir.

### 1.4 "Kaybetse bile tekrar oynamak" psikolojisi

- **Near-miss etkisi:** açıkça kaybetmekten "neredeyse" daha çokdır tetikleyici; çalışma, başarının "elinin altında" olduğu noktada motivasyonun zirve yaptığını gösterir (Logicsimplified; ResearchGate bullet-heaven tezi).
- **Anında yeniden başlama:** kayıp sürtünmesini sıfırlar; öfke-anını yeniden deneme anına çevirir.
- **Ufak ödül dopamini:** rekor kırıldığındaki ufak animasyon/ses; Jabali: "oyuncu istemsizce 'bir daha' derse döngü çalışır."
- **Projeye yansıma:** her yeni türde (a) kayıp anı klip-lenebilir bir "neredeyse" sahnesiyle bitecek, (b) yeniden başlatma ≤1 dokunuş, (c) kayıp ekranı rekor deltasını gösterecek (PB-033 C5 zaten mevcut).

### 1.5 CustomPainter 60fps kanıtı

- Saf `Ticker + CustomPainter` ile 60fps arcade-puzzle tek-kişilik geliştirme raporu (r/FlutterDev) + canvas partikül motorları + balloon-physics 60fps örnekleri: konsensüs, arcade ölçeğinde Flame'e gerek yoktur. Projenin ADR-002'si (Flame YOK) bu konsensüsle uyumlu; mevcut `fx` havuzları + `RepaintBoundary` + alt-adım döngüsü (PB-033) yeni türlerin de aynı altyapıda koşacağı anlamına gelir.
- Sınır değerler: serbest-biçim çizim fiziği, hücresel kum/su simülasyonu, yüzlerce-cisimli kalabalık = ZOR (katalogda işaretli; ya çevrimdışı-önişlem ya kapsam dışı).

---

## 2. Kapsam Tanımı: Fiil Haritası (Neler SAYILMAZ)

Mevcut 10 türün fiili birebir kataloğa girmedi; "komşu ama farklı" satırlar ayrıca işaretlendi:

| Tür | Fiil | Komşuluk riski taşıyan katalog satırları | Karar |
|-----|------|------------------------------------------|-------|
| STACK | yatay kayar + dikey istif | Grid Temizleme (Block Blast), Suika fizik-düşüş | kataloğa girdi ama istifleme-tema yakınlığıyla elendi (§4) |
| CATCH | dodge/collect, yön değiştir | Renk Anahtarı, Yut-Büyü Küre | renk koşullu geçiş ≠ toplama; tutuldu |
| RING | dönen işaretçiyi dilimde durdur | Bıçak Saplama, AA Pin Döngü | zamanlama-fiili çakışıyor; katalogda işaretli, elendi |
| LAUNCH | nişan döner + şarj fırlat | Sapan Çek-Ger, Orbital Sapan | çek-ger girdi-fiili ve fiziği farklı; tutuldu |
| MERGE | eşit çift tap-birleşme | Suika, Numara Düşür-Zincir | birleşme-ailesi yakınlığı; işaretli, elendi |
| PATH | Euler düğüm sırası | Serbest Çizgi Fiziği | serbest-çizim geometri üretir, düğüm-sekans değil; katalogda |
| SORT | sütun seç → taşı | Su Akıtma, Buz Kaydırma | akış-yönlendirme ≠ renk-ayrıştırma; tutuldu (kum/su ZOR işaretli) |
| BALANCE | tarafa ağırlık ver | Duet Çift-Dönüş | döner-çift dodge ≠ devrilme; tutuldu |
| DEFEND | dalga kesme kalkanı | Zaman Dondurma | dondurma = dünya-saati manipülasyonu; tutuldu |
| RHYTHM | vuruş çizgisi notaları | Amanotes lane-ailesi | müzik-lane satırı açılmadı (doğrudan çakışır) |

---

## 3. Mekanik Kataloğu (38 satır, puanlı)

Puanlar 1-10: **Ben** = benzersizlik (fiil + his benzersizliği; mevcut 10 tür + istifleme + pazar doygunluğu göz önünde), **Bağ** = bağımlılık potansiyeli (one-more-try döngüsü gücü), **Görsel** = premium görsel potansiyeli (CustomPainter'da "mükemmel efekt" üstü). **Uyg** = CustomPainter uygulama: K kolay / O orta / Z zor. TOPLAM = Ben+Bağ+Görsel (max 30).

| # | Mekanik (fiil) | Örnek oyunlar | Çekirdek döngü + tek dokunuş | Uyg | Ben | Bağ | Görsel | TOPLAM |
|---|----------------|----------------|------------------------------|-----|-----|-----|--------|--------|
| 1 | **Işık-Karanlık Keşif** (hold=ışık konisi) | Limbo, Inside, karanlık-labirent runner ailesi | Dünya simsiyah; basılı tut = fener konisi açılır, bırak = karanlık; koni içinde yollardan ilerle, ışık şarjı tükenince risk | O | 9 | 6 | 10 | 25 |
| 2 | **Zaman Döngüsü Gölge** (kaydın replay'i müttefik) | P.B. Winterbottom, Echo, Braid (zaman kancası kavram) | 3 kısa tur; her turdaki hamleler kaydedilir, sonraki turda gölge aynı zaman çizelgesinde oynar; 3. turda 3 gölge senkron kapı açar; dokun = zıpla/ilerle | O | 10 | 7 | 8 | 25 |
| 3 | **Ayna-Kopya Karakter** (simetrik ikiz) | The Swapper (klon kavramı), mirror-map platform bulmaca ailesi | Sol karakteri kontrol edersin; ayna ikizi simetrik oynar; kapı yalnız ikisi aynı anda tetiklerse açılır; dokun = zıpla (ikisi birden) | O | 9 | 7 | 8 | 24 |
| 4 | **Vidayla-Sökme** (dokun=sök, katman revelasyonu) | Screwdom (iKame), Screw Sort Pin Jam 3D (Rollic), Screw Master | Plakalar vidalı katmanlar; dokun = sıradaki vida sökülür, plaka düşer, altındaki renkler gövdeye uygun değilse sıkışma; tüm parçalar sökülecek | O | 8 | 8 | 7 | 23 |
| 5 | **Döndür-Eşle Geometri** (döndür, silüete oturt) | Monument Valley 3 (ustwo), Shadowmatic, Shape Fit | Izometrik 3B blok kümesi döner; dokun = 90° döndür; hedef silüetle örtüşünce parça kilitlenir; N parça = kazan | O | 8 | 6 | 9 | 23 |
| 6 | **Orbital Sapan** (yörüngede dön, fırla) | Orbia, Orbit: Playing with Gravity, gezegen-hop ailesi | Top gezegen yörüngesinde otomatik döner; dokun = tangent yönünde sapan; bir sonraki yörüngeye tutun, kaçırırsan boşluğa savrulursun | O | 8 | 7 | 8 | 23 |
| 7 | **Delik Yutma** (yut-büyü deliği) | Hole.io (Voodoo), Donut County, Hole Eat Grow Attack | Delik sahneyi yürür; parmağını kaydır = delik oraya akar; küçük cisimler yutulunca delik büyür, büyükler açılır; süre sonunda yutma oranı | O | 7 | 7 | 8 | 22 |
| 8 | **Halat Sallanma** (tut=sarkaç, bırak=savrulma) | Swing Loops (Homa), Spider Stickman, Hook | Karakter otomatik akar; basılı tut = halat kancaya takılır sarkaç salınır; bırak = momentumla savrulur; sonraki kancaya | O | 7 | 8 | 7 | 22 |
| 9 | **Pin Çekme** (sıra kararı, yerçekimi sonucu) | Pull the Pin (Popcore), Hero Rescue, Screw Sort Pin Jam 3D | Boruda top + tuzak + renk kapıları; dokun = pin çek; doğru sıra topu hazneye, yanlış sıra zehir/top kaybı | O | 7 | 8 | 7 | 22 |
| 10 | **Zaman Dondurma** (basılı tut = dünya yavaşlar) | SUPERHOT (kavram), hold-to-slow hiper-casual prototipleri | Sahne sürekli tehlike üretir; basılı tut = zaman %90 yavaşlar ama ışık havuzu tükenir; bırak = normale; doğru anı seç, ilerle | O | 8 | 6 | 8 | 22 |
| 11 | **Teleport-Swap** (konum değiştir) | Swap the Box, Switch (Ketchapp), teleport-platform ailesi | Dünya akar; ekran iki alandır; dokun = top ile hedef noktanın yerleri değişir; duvar/diken yerine boşluğa ışınlan | K | 8 | 7 | 7 | 22 |
| 12 | **Domino Zincir** (devirme anı, zincir şöleni) | Domino Smash (Lion Studios), Domino Run 3D, toppling-fizik ailesi | Dominolar kaplıca dizilmiş; top salınırken dokun = devirme anını seç; zincir kamera takipli devrilir; %100 devrilme = kazanç | O | 8 | 6 | 8 | 22 |
| 13 | **Açı-Bounce Kırma** (nişat döner, sekme zinciri) | Ballz (Ketchapp), BBTAN (111%), Bricks n Balls | Sayılı taş her atışta bir iner; nişat çizgisi döner; dokun = top salvosu; top sekerek taşları kırar; taş tabana inerse kayıp | O | 6 | 9 | 6 | 21 |
| 14 | **Sapan Çek-Ger** (lastik çek, bırak, yıkım) | Angry Birds (Rovio), Angry Birds 2, Catapult King | Kaydır-geri çek = şarj, bırak = mermi yıkım fiziği; hedef yapı çökünce kazanç; atış biterse kayıp | O | 5 | 8 | 8 | 21 |
| 15 | **Kesme/Slicing** (kaydır=kes, poligon bölünür) | Fruit Ninja (Halfbrick), ASMR Slicing (Crazy Labs), Slice It All! (Voodoo) | Cisim uçuşur; parmağınla kaydır = kesme çizgisi; poligon ikiye bölünür fizikle savrulur; ASMR doku sesi; bomba = kayıp | O | 6 | 7 | 8 | 21 |
| 16 | **Jam Kaydırma** (blok kilitli, çıkışa kaydır) | Color Block Jam (Rollic), Unblock Me, Rush Hour | Renkli bloklar kilitli; dokun = blok çıkış yönüne kayar (yol boşsa); tüm renkli bloklar kapıdan çıkınca kazanç; hamle biterse kayıp | K | 7 | 8 | 6 | 21 |
| 17 | **Yerçekimi Çevirme** (dokun=ters düş) | Gravity Guy (Miniclip), VVVVVV (Terry Cavanagh), gravity-flip runner ailesi | Karakter autorun; dokun = yerçekimi ters; tavan/zemin akışında engelleri aşı; engel = kayıp | K | 7 | 7 | 7 | 21 |
| 18 | **Halat Çözme** (uçları değiştir, kesişim=0) | Tangle Master 3D (Rollic), untangle-puzzle ailesi | Sarmaşık/halat düğümlü; dokun = seçilen halatın uçlarını çapraz değiştir; hiçbir çizgi kesişmediğinde kazanç | O | 8 | 7 | 6 | 21 |
| 19 | **Duet Çift-Dönüş** (döner çift, düşen segmentler) | Duet (Kumobius), çift-orbit dodge ailesi | Halkada karşılıklı iki küre; basılı tut = halka döner; düşen duvar segmentleri arasında ikisi de sağ çıkmalı | K | 7 | 7 | 7 | 21 |
| 20 | **Renk Anahtarı Sıçrama** (renk koşullu geçiş) | Color Switch, Color Hopper klon ailesi | Top otomatik zıplar; renkli segman halkalarından yalnız topun mevcut rengiyle aynı segmentten geçilir; renk halkalar arasında değişir | K | 6 | 8 | 6 | 20 |
| 21 | Kapı Aritmetiği (kalabalık × kapılar) | Count Masters (Freeplay), Gate Rusher, Join Clash (Supersonic) | Kalabalık akar; kapılar x2/+15/-20; dokun = kalabalık akışını o kapıya yönlendir; patron/duvar finali | O | 6 | 8 | 7 | 21 |
| 22 | Halat Kesme (kes, yerçekimi boru) | Cut the Rope (ZeptoLab), Cut It | Halat segmentleri şekilleri taşır; dokun = kes; şekil düşerek ağza/hazneye; yanlış kes = kayıp | O | 6 | 7 | 7 | 20 |
| 23 | Buz Kaydırma (kayana kadar kay) | klasik Pokémon buz-mağara mantığı, slide-maze ailesi | Dokun = yönde kay; engelene kadar duramazsın; tüm noktalara bas | K | 7 | 6 | 6 | 19 |
| 24 | Boya Dökme (roller, %100 doldur) | Roller Splat (Voodoo), Color Fill 3D, Paint Pop 3D | Kaydır = roller akar, izini bırakır; labirent %100 boyanınca kazanç | K | 6 | 6 | 7 | 19 |
| 25 | Kum Kazma (çiz=kum kanalı) | Sand Balls (SayGames), Dig Out (ZiMAD) | Çizgi çiz = kum hücreleri açılır, küre kanaldan akar; hepsi araca/hazneye | Z | 7 | 7 | 8 | 22 |
| 26 | Su Akıtma (kaz=su yolu) | Where's My Water (Disney), water-flow puzzle ailesi | Kaz = su akış yolu açılır; su hedefe yetmeli | Z | 6 | 7 | 7 | 20 |
| 27 | Suika Fizik Düşüş-Birleşme | Suika Game, Fruit Merge, Banana Game klon dalgası | Bırak = iki eşit çember birleşir büyür; kap dolmadan zincir | O | 6 | 9 | 8 | 23 |
| 28 | Numara Düşür-Zincir | Drop the Number, Make 7!, 2048-drop ailesi | Bırak = eşit numara komşusuyla zincir birleşir | O | 5 | 8 | 7 | 20 |
| 29 | Grid Temizleme (drag tetromino, satır patlat) | Block Blast! (Hungry Studio), Woodoku (Tripledot), 1010! | Sürükle = tetromino doldur; tam satır patlar; sığmazsa kayıp | K | 4 | 10 | 6 | 20 |
| 30 | Lane Runner (şerit değiştir) | Subway Surfers (SYBO), Temple Run (Imangi), lane-run ailesi | Kaydır = şerit; engeller/coinler | O | 5 | 7 | 6 | 18 |
| 31 | Flap Impuls (dokun=impuls vs yerçekimi) | Flappy Bird (.GEARS), Splashy Fish, flap klon dalgası | Dokun = yukarı impuls; boru aralıkları | K | 4 | 8 | 5 | 17 |
| 32 | Bıçak Saplama (dönen kütüğe fırlat) | Knife Hit (Ketchapp), knife-throw klon ailesi | Dokun = bıçak fırlat; diğer bıçağa çarpma; meyve patlaması boss finali | K | 6 | 8 | 6 | 20 |
| 33 | AA Pin Döngü (dönen çarka pin at) | AA (generator), Pin Circle, crazy-wheel klon ailesi | Dokun = pin at; diğer pine çarpma | K | 5 | 7 | 5 | 17 |
| 34 | Duvar Boşluk Geçişi | wall-gap dodge klon ailesi | Duvarlar akar; boşluğa denk gel | K | 5 | 6 | 5 | 16 |
| 35 | Yut-Büyü Küre (görünen top büyür) | Agar.io (Miniclip), Tasty Planet (Dingo), Katamari kavramı | Kaydır = küre; küçükleri yut, büyü, büyüklerden kaç | O | 6 | 6 | 7 | 19 |
| 36 | Manyetizma (tut=çek/it) | Magnet Balls, magnetic-pull ailesi | Basılı tut = mıknatıs; çubuklar/toplar çeker zincir kurar | O | 7 | 6 | 7 | 20 |
| 37 | Serbest Çizgi Fiziği (çizgi fiziksel olur) | Happy Glass (Lion Studios), Brain Dots (Translimit), fizik-çizim ailesi | Serbest çiz = çizgi katı cisim olur; top çizgiyle yönlendirilir hedefe | Z | 7 | 7 | 7 | 21 |
| 38 | Balon Pompala (tut=şişir, bırak=uçur) | pump-and-release balon ailesi | Basılı tut = balon şişer; tam şişkinlikte bırak = uçar; patlak = kayıp; risk/ödül şişkinlik ayarı | K | 7 | 6 | 6 | 19 |

**Komşuluk notları:** #27/#28 MERGE ailesi, #32/#33 RING zamanlama ailesi, #29 istifleme-tema komşusu — katalogda puanlandı ama seçimde elendi (§4). #25/#26/#37 ZOR perf; #21 kalabalık-sim perf.

---

## 4. SEÇİM: 38 → 20 (eliminasyon gerekçeleri)

Filtre: (F1) tek dokunuş C-022; (F2) 3 sn okunabilirlik; (F3) CustomPainter 60fps; (F4) mevcut 10 tür + istifleme ile fiil çakışmazlığı; (F5) organik virallik (klip-lenebilir doruk); (F6) premium görsel potansiyeli.

**Elenecek 18 satır:**

| Satır | Gerekçe |
|-------|---------|
| Grid Temizleme (#29) | Bağımlılık kralı ama (F4): tema-çekirdek komşuluğu + pazar doygunluğu (Block Blast 70M DAU zaten var — klonu başlatma maliyeti recete değil) |
| Suika Fizik (#27) | (F4) MERGE ailesi komşuluğu |
| Numara Düşür-Zincir (#28) | (F4) MERGE ailesi komşuluğu |
| Bıçak Saplama (#32) | (F4) RING zamanlama-fiili çakışması |
| AA Pin Döngü (#33) | (F4) RING çakışması + düşük görsel tavan |
| Flap Impuls (#31) | (F6) benzersizlik tavanı çok düşük (klon dalgası doygun) |
| Lane Runner (#30) | (F3) hız-perf riski + mekanik olarak en az farklı satır |
| Duvar Boşluk (#34) | (F6) zayıf görsel/bağımlılık |
| Yut-Büyü Küre (#35) | #7 Delik Yutma ile fiil duplikasyonu (yut-büyü) |
| Serbest Çizgi (#37) | (F3) ZOR + (F1) serbest-çizim girdi riski (parmak kirliliği, okunabilirlik) |
| Kum Kazma (#25) | (F3) ZOR: hücresel kum simülasyonu 60fps riskli |
| Su Akıtma (#26) | (F3) ZOR: sıvı simülasyonu |
| Manyetizma (#36) | bağımlılık kancası zayıf; çek/it hissi yakın satırların gölgesinde |
| Boya Dökme (#24) | yedek koltuğu; %100-doldur döngüsü tek bölüm içinde hızla tükenir |
| Buz Kaydırma (#23) | yedek koltuğu; düz-maze hissi, premium görsel tavan düşük |
| Kapı Aritmetiği (#21) | (F3) kalabalık-sim perf riski + toplama-fiili CATCH'a gölge; yedek |
| Halat Kesme (#22) | #14 sapan ile sonuç-fiziği çakışması + kategori eski (Cut the Rope 2010) |
| Balon Pompala (#38) | tek-ölçekli gerilim; 20'ye giremede derinlik yok |

**Seçilen 20 (TOPLAM puan sırasıyla):** Işık-Karanlık Keşif, Zaman Döngüsü Gölge, Ayna-Kopya Karakter, Vidayla-Sökme, Döndür-Eşle Geometri, Orbital Sapan, Delik Yutma, Halat Sallanma, Pin Çekme, Zaman Dondurma, Teleport-Swap, Domino Zincir, Açı-Bounce Kırma, Sapan Çek-Ger, Kesme/Slicing, Jam Kaydırma, Yerçekimi Çevirme, Halat Çözme, Duet Çift-Dönüş, Renk Anahtarı Sıçrama.

---

## 5. EN İYİ 20 MEKANİK — Senaryolar

Her senaryo: oyun adı önerisi · dünya eşleşmesi (kThemes 10 dünyadan) · kazanma/kaybetme · bağımlılık kancası · premium efekt önerisi. Tümünde ortak yasalar: tek dokunuş (C-022), anında yeniden başlama, "NEREDEYSE!" near-miss satırı, kombo pitch-merdiveni, bölüm sonu inşaat parçası yükselişi (C-021).

### 5.1 Işık-Karanlık Keşif — "IŞIK DEVRESİ" (25 puan)
**Dünya:** KRİSTAL MAĞARA (karanlık + glow kristaller doğal sahne) / DERİN DENİZ. **Döngü:** Sahne simsiyah; basılı tut → fener konisi açılır, koni içindeki koridor yolu görünür; bırak → karanlık ve tehlikeler (dikenler, uçurum) görünmez kalır; ışık şarjı tutarken tükenir, karanlıkta yavaş dolar — oyuncu "ışık bütçesi" ile risk kumarı oynar. Hazneye ulaşan ışık tohumu = kazanma; tehlike + şarj bitişi = kayıp. **Kanca:** karanlıkta kaybetmek "neredeyse görüyordum" hissi verir — near-miss kralı; her bölümde bir "gizli karanlık odası" bonus yolu. **Premium efekt:** saveLayer + BlendMode.multiply koni saçılması; koni kenarında yansıyan kristal parıltıları; ışık sönümünde yankı-ses; PB-031 aurora zemin karanlık versiyonu. 

### 5.2 Zaman Döngüsü Gölge — "GÖLGE TURU" (25)
**Dünya:** NEON ŞEHİR (hologram gölgeler temaya birebir) / SON KULE. **Döngü:** Tur 5-6 sn; Tur 1'de hamlelerin kaydedilir; Tur 2'de gölge #1 aynı zaman çizelgesinde tekrar oynar; Tur 3'te iki gölge + sen; üçünüz aynı anda kapıları/anahtarları tetikleyip çıkışa ulaşmalısın. Dokunuş = zıpla/ileri. Gölgelerden biri ölürse tur sıfır. **Kanca:** "tek dokunuşla puzzle-koordinasyonu" — bölüm bir bulmaca; "bu turda 0.3 sn erken zıplayayım" mikrosaat ayarı = one-more-try. **Premium efekt:** gölgeler `levelSignature` hue'sunun komplementinde hayalet-ikiz render (PB-015 hayalet twist'inin tam-oyun hali); tur bitişi zaman-çizelgesi replayer şeridi (klip-lenebilir senkron an).

### 5.3 Ayna-Kopya Karakter — "AYNA EKİ" (24)
**Dünya:** KRİSTAL MAĞARA (ayna kristalleri) / BUZ DÜNYA (buz aynalar). **Döngü:** Sol karakter senin; sağ ikizi ayna simetrisiyle aynı anda zıplar; asimetrik engeller yüzünden "benim zıplamam onu öldürür" paradoksu; ikisi de hedef kapıya girmeli. Dokunuş = zıpla (ikisi birden). **Kanca:** tek düğme ile iki-kafa bulmaca; kayıp her zaman "ikisi birden, ne kadar yakın" → near-miss; 4-5 bölümden birinde ikiz rolleri tersine çeviren sürpriz (sağ senin kontrolün, sol ayna). **Premium efekt:** ayna-ayrımı ışık köprüsü (MonumentCeremony görsel diliyle aynı dil); ikiz birbirine değince kristal-gümbürtü; hit-stop + haptic çift-desen (HapticPatternHost [0,60] hazır).

### 5.4 Vidayla-Sökme — "SÖK GEÇ" (23)
**Dünya:** NEON ŞEHİR (makine kuleleri) / VOLKAN (paslı mekanik). **Döngü:** Katmanlı plaka yığını; dokun = sıradaki (öncelik-imli) vida sökülür, plaka çöker; alttaki renkler gövdeye uymayan sıradaysa plaka sıkışır ve can gider; tüm plakalar sökülüp çekirdek çıplak kalınca kazanma. **Kanca:** 2025 kanıtı — Screwdom $1M+/ay; dokunsal ASMR kulağı (sökme çınlaması) + "altında ne var" merakı; her bölümde bir gizli-kompartment bonus. **Premium efekt:** vida-söküm ses merdiveni (gen_sounds üreteci ekleme); plaka çöküşünde squash&stretch + toz partikülü (fx havuzu hazır); katman revelasyonunda karanlık-perde yükselme animasyonu.

### 5.5 Döndür-Eşle Geometri — "YANKI BLOK" (23)
**Dünya:** SON KULE (monument havası) / KRİSTAL MAĞARA. **Döngü:** Izometrik 3B blok kümesi (projedeki 3B-blok painter aynen); dokun = 90° döndür; hedef silüetiyle (kenar çizgili hayalet şekil) örtüşünce parça altın-ışıkla kilitlenir; N parça + süre = kazan; döndürme bütçesi biterse kayıp. **Kanca:** perspektif "aha!" anı — her çözüm klip-lenebilir kilitlenme töreni; Monument Valley premium dilinin tek dokunuş çevirisi. **Premium efekt:** izometrik gölge uzunluğu döndürmeyle gerçek-zamanlı değişir; kilitlenme anında genişleyen halka (Stack mükemmel-dizilim efekt dili); finalde anıt parçasına dönüştürme (construction-meta ile birebir bağ).

### 5.6 Orbital Sapan — "YÖRÜNGE" (23)
**Dünya:** UZAY (doğal sahne; aurora + gezegen painter hazır). **Döngü:** Top gezegen yörüngesinde otomatik döner; dokun = o andaki tangent yönünde fırla; bir sonraki gezegenin çekim alanına girmezsen boşluğa savrulursun (kayıp); N gezegen = kazanç; kuyruklu-yıldız bonus yolları. **Kanca:** "kaçırma her zaman merkez yakınından geçer" — görsel near-miss makinasi; savrulma anı TikTok-klipi. **Premium efekt:** yörünge izi yıldız-dumanı; gezegen atmosfer kırılması (saveLayer bloom); fırlatma anında hit-stop + haptic uzun vuruş; kamera zoom A4 fit mantığıyla galaksi düzeyine geri çekilme.

### 5.7 Delik Yutma — "GİRDAP" (22)
**Dünya:** ALTIN ÇÖL (kum deliği) / DERİN DENİZ (girdap). **Döngü:** Delik sahnenin altında ilerler; parmağını kaydır = delik akar; küçük cisimler (tümeler, kutular) yutulunca delik büyür; büyüyünce sütunlar/kuleler açılır; süre sonunda yutma oranı hedefi = kazan; büyük cisim deliğe takılırsa tıkanma hasarı. **Kanca:** yut-büyü iki-yönlü dopamin (yutulan nesne görünür şekilde yok olur + delik görünür büyür); Donut County'nin "yutulan her şeyin kayda geçmesi" merakı. **Premium efekt:** yutulan cisim delik içinde küçülme + hue-kayması; girdap çemberi koni-gölge; büyük yutulmada tam ekran flaş α0.35 (PB-016 kritik dili).

### 5.8 Halat Sallanma — "ASMA" (22)
**Dünya:** BİYO ORMAN (asmanlar doğal kancalar) / BULUT ŞEHİR (gondol kabloları). **Döngü:** Karakter akar; basılı tut = halat en yakın kancaya takılır, sarkaç salınır; bırak = momentumla savrulma; sonraki kanca; yere/dikey-kayaya çarpma = kayıp; N kanca = kazanç. **Kanca:** HoldGame arayüzü LAUNCH'tan hazır; momentum ustalığı = "bir savrulma daha" hissi; en-yavaş-atma bonus hedefi. **Premium efekt:** halat gerilme-yaylanma (verlet 2 nokta yeterli); savrulmada iz-yıldız (fx yıldız-izi hazır); kanca tutuş anında ASMR "tık" + konfeti minipatlaması.

### 5.9 Pin Çekme — "TUZAK ODASI" (22)
**Dünya:** ALTIN ÇÖL (antik tapınak tuzakları) / VOLKAN (lav boruları). **Döngü:** Dikey boru düzeninde top + tuzak (diken, zehir, lav) + renk kapıları; her pin dokunulabilir; dokun = pin çekilir, üstündeki kütle yerçekimiyle akar; doğru sıra altın topları hazneye taşır; bir tuzak kuyuyu kirletirse kayıp. **Kanca:** "sıra = zeka" tek dokunuş bulmaca; yanlış çekim anında görsel ne olduğu anlatır (3 sn kuralı); bölüm içinde ikinci-şans kalkanı (kalkan ekonomisi DEFEND'ten taşınır). **Premium efekt:** pin çekilişinde metal-yay sesi + küçük haptic; akış parçacığı ASMR; hazneye ulaşan top altın-konfeti töreni (flow_overlays kutu diline uyumlu).

### 5.10 Zaman Dondurma — "BUZ SAATİ" (22)
**Dünya:** BUZ DÜNYA (tema-birebir: donan zaman) / KRİSTAL MAĞARA. **Döngü:** Sahne sürekli tehdit akar (döken kaya, dönen kolonlar); basılı tut = dünya %90 yavaşlar ama "don-ışığı" havuzu tükenir; bırak = normale; tehditlerin arasından doğru anı seçip geç; hedef kapı = kazanç; tehdit çarpma + havuz boşalması = kayıp. **Kanca:** HoldGame + fxDt saati (PB-016 hit-stop altyapısı) hazır; "ne zaman bırak" mikrokararı = one-more-try; bölüm sonunda donmuş sahnenin eriyip akmayı sürdürmesi klip anı. **Premium efekt:** yavaşlamada tüm fx saatleri çarpanla akar (fxDt altyapısı); don alanında kar-tanesi suskunluğu + ses pitch-düşmesi; havuz azaldıkça ekran kenarı buz-kırığı vignette.

### 5.11 Teleport-Swap — "YER DEĞİŞTİR" (22)
**Dünya:** NEON ŞEHİR (ışınlanma kuleleri) / UZAY. **Döngü:** Dünya akar; ekran iki katman (üst yolu tehlikeli, alt yolu kapalı — ya da iki top); dokun = top ile ışınlan-hedefinin yerleri değişir; tehlike yerine boşluğa ışınlanmak = hayatta kalma; N ışınlanma + hedef = kazan. **Kanca:** dokunuş = çözüm; okunabilirlik 1 sn; "bir dokunuş önce" ışınlanma zamanlaması near-miss üretir. **Premium efekt:** ışınlanma mavi-hue düzlemleri (glass panel dili); eski konumda iz-kedisi (ghost trail); swap anında ekran kırpışma α0.18 tema (PB-016 mükemmel dili).

### 5.12 Domino Zincir — "DEVİR" (22)
**Dünya:** KRİSTAL MAĞARA (kristal taşlar) / NEON ŞEHİR (konteyner yığınları). **Döngü:** Kaplıca dizilmiş dominolar + salınan devirme-topu; dokun = bırakma anını seç; zincir kamera takipli devrilir; %100 devrilme = kazan; zincir koparsa kalan taşlar "neredeyse" sayılır. **Kanca:** devrilme şöleni = L6 bölüm-sonu şöleninin kendisi; "0.2 sn erken bıraktım" mikro-karar; her devrilme ASMR kum sesi dizisi. **Premium efekt:** kamera zoom takibi (PB-033 kamera altyapısı); devrilme sırası boyunca pitch-merdiveni (Stack kombo dili); final taş altın-renk + pop-up Picture cache töreni.

### 5.13 Açı-Bounce Kırma — "SEKME" (21)
**Dünya:** BUZ DÜNYA (kayan taşlar) / UZAY (asteroid alanı). **Döngü:** Sayılı taşlar her atışta bir iner; altta dönen nişat çizgisi; dokun = top salvosu (3-5 top); top sekerek taşları kırar, sekme sayısı ödülü; taş tabana inerse kayıp; T taş = kazanç. **Kanca:** Ballz ailesi 9/10 bağımlılık — sekme-zinciri ve taş-descent klasik one-more-run; combo 3+ top ateş modu (PB-033 ateş-izi hazır). **Premium efekt:** sekme anında minipatlama + haptic çift; sekme-sayısı yıldız izi; taş kırığı çarpma-havuzu (fx enkaz parçacığı hazır).

### 5.14 Sapan Çek-Ger — "KAYA SAPAN" (21)
**Dünya:** BİYO ORMAN (ağaç kulesi yıkımı) / ALTIN ÇÖL (kumtuğ kale). **Döngü:** Sapan çemberi; kaydır-geri çek = şarj, bırak = mermi; hedef yapı (3B blok yığın — mevcut painter) çökünce kazanç; atış biterse kayıp; mermi türleri (küre/küp/üçgen) mesafe-ödülü. **Kanca:** yıkım fiziği görsel dopamin zirvesi; "bir atış daha" bütçesi; kaplıca bonus hedefleri. **Premium efekt:** çöküş enkaz-parçacığı + kamera sarsıntısı (PB-016 dili); yavaş-sapma çarpma anı (slow-mo hit-stop); yıkılan yapı küçük-toz bulutları.

### 5.15 Kesme/Slicing — "BİYOL KESİT" (21)
**Dünya:** BİYO ORMAN (biyolume meyveler) / DERİN DENİZ (deniz-sever kesitleri). **Döngü:** Cisimler uçuşur; kaydır = kesme çizgisi; poligon ikiye bölünür fizikle savrulur; ASMR doku sesi (sulu/çamur/kristal); bomba = kayıp; N kesit = kazanç. **Kanca:** kesit-anı ASMR + partikül = satisfying kralı (ASMR Slicing 2025 kanıtı); kombo 3+ kesit slow-mo; her kesit "tam ikiye bölünme" micro-perfection (Stack mükemmel diline akraba). **Premium efekt:** kesit-yüzeyi parlatma (iç-doku render); savrulan yarım-polygon fizik (basit poligon bölme yeterli); kesit çizgisi iz + ekran-flaş.

### 5.16 Jam Kaydırma — "BLOK TUZAĞI" (21)
**Dünya:** NEON ŞEHİR (trafik-blok jam) / SON KULE. **Döngü:** Renkli bloklar kilitli konumda; dokun = blok çıkış yönüne kayar (yol boşsa); tüm renkli bloklar kapıdan çıkınca kazanma; hamle bütçesi biterse kayıp; kilit-donuk bloklar twist olarak. **Kanca:** 2025 kanıtı — Color Block Jam $33M; hamle-bütçe near-miss ("1 hamle kaldı"); bölüm başı 3-sn okuma + çözüm anı "aha". **Premium efekt:** blok kayması cam-çarpma sesi; kapıdan çıkışta renk-silinme + minikonfeti; bütçe son-1 hamlede ekran kenarı amber (PB-033 C5 dili).

### 5.17 Yerçekimi Çevirme — "TERS ZEMİN" (21)
**Dünya:** UZAY (yörünge-birim ters düşme) / SON KULE. **Döngü:** Karakter autorun; dokun = yerçekimi ters; tavan/zemin akışında engelleri aşı; art-arda çevirmede kombo; engel = kayıp; N mesafe = kazanç. **Kanca:** dokunuş başına dünya-değişimi — anlık-dönüşüm dopamin; combo pitch-merdiveni hazır; "1 engel kala çevirmek" near-miss. **Premium efekt:** çevirmede kamera-yıkama (flaş α0.18) + hue-derin kayma (levelSignature); yerçekimi-yönü yıldız-akış parallax ters; squash&stretch iniş anı.

### 5.18 Halat Çözme — "DÜĞÜM ÇÖZ" (21)
**Dünya:** BİYO ORMAN (sarmaşık düğümleri) / DERİN DENİZ (yosun yumağı). **Döngü:** Sarmaşık/halat düğümlü; dokun = seçilen halatın uçlarını çapraz değiştir; hiçbir çizgi kesişmediğinde kazanç; hamle bütçesi. **Kanca:** kesişim-sayacı gerçek-zamanlı — her hamlede "kaç kesişim kaldı" görünür ilerleme; çözüm anı "bütün düğüm çöktü" klip anı. **Premium efekt:** halat eğrileri Bezier yumuşatma + dokunuşta doğal salınım; kesişim noktaları kırmızı-node işareti; çözümde ışık köprüsü (MonumentCeremony dili).

### 5.19 Duet Çift-Dönüş — "ÇİFT YORUNG" (21)
**Dünya:** DERİN DENİZ (çift ışık küresi yosun halkası) / KRİSTAL MAĞARA. **Döngü:** Halkada karşılıklı iki küre; basılı tut = halka döner, bırak = durur (HoldGame); düşen duvar segmentleri arasında ikisi de sağ çıkmalı; segment çarpma = kayıp; T süre = kazanç. **Kanca:** premium akraba (Duet — ADA çizgisi); tek düğme ile "iki canım var" gerilimi; segment-ritmi kombo. **Premium efekt:** küre-izleri karşılıklı yıldız izi; segment kırılışında cam-çatlak doku; uzun tutuşta ses-yükselme merdiveni.

### 5.20 Renk Anahtarı Sıçrama — "RENK GEÇİT" (20)
**Dünya:** KRİSTAL MAĞARA (renk-segment kristalleri) / NEON ŞEHİR. **Döngü:** Top otomatik zıplar; renkli segman halkalarından yalnız topun mevcut rengiyle aynı segmentten geçilir; renk halkalar arasında değişir; yanlış renk = kayıp; N halka = kazanç. **Kanca:** renk-uyumu "hızlı oku, doğru dokunuş" — 1 sn öğrenilir; kombo pitch-merdiveni; "renk değişimi 2 halka sonra" ön-okuma merakı. **Premium efekt:** halka geçişinde renk-yayılımı (halka merkezden dışa hue-akış); doğru geçişte minipatlama + konfeti (12 parça hazır); fire-mode renk-alevi.

---

## 6. ELEŞTİRİ: STACK Çekirdeğiyle Hibrit Uyum

Kriter: aynı müzik/ses/ekonomi/juice/kamera altyapısıyla ne kadar az yeni altyapı gerektiriyor (Düşük maliyet = yüksek hibrit). Paylaşılan taban: MiniGame sözleşmesi (points → cüzdan, host haptic/ses kancaları), HoldGame (LAUNCH), InputGate (hit-stop), fx havuzları (konfeti, halka, yıldız izi, pop-up Picture cache LRU), pitch-merdiveni ses altyapısı (27 varlık + gen_sounds), kamera zoom/fit (A4), hit-stop + squash&stretch (PB-016), levelSignature hue (A3), ekonomi (cüzdan/pazar/görev/takvim — tür-agnostik), twist yasası (PB-015 — şu an yalnız stack; yeni türler seçici katılır).

| Hibrit | Türler | Paylaşılan altyapı | Not |
|--------|--------|--------------------|-----|
| **YÜKSEK** | Vidayla-Sökme, Jam Kaydırma, Açı-Bounce Kırma, Pin Çekme, Kesme/Slicing, Renk Anahtarı, Teleport-Swap, Yerçekimi Çevirme | fx havuzları + hit-stop + pitch-merdiveni + HoldGame/InputGate + ekonomi (hamle/süre → MiniGameResult.points birebir) + pazar/sandık/görev | Bu 8 tür "8. antoloji dalı" olarak mevcut iskelete en hızlı takılır; twist dağıtım yasası seçici genişler (ör. daralan-duvar → Açı-Bounce, hayalet-ikiz → Ayna-Kopya, altın-zar → Pin Çekme) |
| **ORTA** | Halat Sallanma, Delik Yutma, Domino Zincir, Duet Çift-Dönüş, Halat Çözme, Zaman Dondurma | HoldGame + fxDt saat katmanı (yavaşlama çarpanı) + kamera takip + ses katmanları; verlet/ya da daire-daire basit fizik gerektirir (ADR-002 çerçevesinde yeterli — küçük ölçek) | Yeni fizik-yaprağı gerekir ama Flame yok; küçük-N cisimlerle 60fps güvenli |
| **DÜŞÜK (imza)** | Işık-Karanlık Keşif, Zaman Döngüsü Gölge, Ayna-Kopya, Döndür-Eşle Geometri, Orbital Sapan, Sapan Çek-Ger | aurora/painter dili + kamera + ekonomi; ama kendi özel katmanı: saveLayer ışık maskesi, gölge-replay kayıt sistemi, ayna-simetri dünya modeli, izometrik döndürme matrisi, yörünge-gravitasyon | Maliyet yüksek ama premium-görsel tavanı da yüksek; marka-ayrımcı türler — DALGA 3 |

**Uyarılar:**
- **Bütçe-disiplin:** tüm 20 türü aynı sürüme sıkıştırmak C-001/C-016 kalite tabanını kırmalı; her dalga bağımsız test/inceleme döngüsüyle (PB kalıbı) açılmalı.
- **Twist seçicilik:** PB-015 twist yasası stack'e özgü; yeni türlere twist eklerken twist-tür matrisi kurulmalı (aynı twist her türe bürünmeli; örn. "altın" türe göre altın-top/altın-vida/altın-pin olur).
- **Ses genişlemesi:** gen_sounds üretim hattı ASMR ailesi (kesme/sökme/devrilme) + makyaj (ışık-ping, ışınlanma) genişletmeye hazır; varlık-bütçe her dalga ~8-12 WAV.
- **Performans tavanı:** ZOR satırları (kum, su, serbest-çizgi) hiçbir dalga önerisinde yok; ışık-maskesi saveLayer maliyeti tek koniyle sınırlı tutulmalı.

---

## 7. Uygulama Önceliği (etki/maliyet)

### Dalga 1 — Hızlı Etki (düşük maliyet; mevcut iskelete en yakın; ~6 tür)
| Sıra | Tür | Etki | Maliyet gerekçe |
|------|-----|------|-----------------|
| 1 | **Vidayla-Sökme** | 2025 pazar kanıtı, ASMR kulak | tap-dokun + katman modeli; fx/ses mevcut |
| 2 | **Açı-Bounce Kırma** | 9/10 bağımlılık, Ballz kanıtlı | daire-daire + sekme; fx hazır |
| 3 | **Jam Kaydırma** | 2025 lider mekanik, hamle-bütçe ekonomi uyumu | grid kaydırma; K-uygulama |
| 4 | **Pin Çekme** | zeka-çekiciliği + mevcut kalkan/ekonomi diline uyum | düşey boru + kütle akışı |
| 5 | **Kesme/Slicing** | ASMR viralliği, TikTok-satisfying | poligon-bölme + partikül |
| 6 | **Renk Anahtarı Sıçrama** | 1-sn öğrenilir; kombo-merdiveni hazır | renk-segment halkalar |

### Dalga 2 — Farklılaşma (orta maliyet; fizik-yaprağı ekler; ~9 tür)
7 Halat Sallanma (HoldGame hazır) · 8 Delik Yutma · 9 Teleport-Swap · 10 Yerçekimi Çevirme · 11 Domino Zincir · 12 Halat Çözme · 13 Duet Çift-Dönüş · 14 Zaman Dondurma (fxDt katmanı) · 15 Sapan Çek-Ger (yıkım fiziği).

### Dalga 3 — İmza/Premium (yüksek maliyet; marka-ayrımcı; ~5 tür)
16 **Işık-Karanlık Keşif** (saveLayer ışık maskesi — premium görünümlü satır) · 17 **Zaman Döngüsü Gölge** (replay-gölge sistemi — en benzersiz fiil) · 18 **Ayna-Kopya Karakter** (simetri dünya modeli) · 19 **Döndür-Eşle Geometri** (izometrik döndürme) · 20 **Orbital Sapan** (yörünge-gravitasyon).

**Dağıtım notu:** C-020/C-017 yasası (ardışık aynı tür ≤1, ilk-5 farklı) 30 türde de aynen genişler; patron imza türleri artık 30 havuzdan seçilir. İlk-5 şeması 5 FARKLI tür zorunluluğunu korur.

---

## 8. Kaynaklar

- [AppMagic — Top 10 Hybridcasual Games Q1 2025: The Great Puzzle](https://appmagic.rocks/blog/hybridcasual-q1-2025/?hl=en)
- [AppMagic — Top 10 Hybridcasual Q3 2025: Rollic Claims 4 Spots (Color Block Jam, Screwdom, Crowd Express, Screw Sort Pin Jam 3D)](https://appmagic.rocks/blog/q3hybrid2025)
- [Game Refinery — Mobile Game Market Review March 2025](https://www.gamerefinery.com/mobile-game-market-review-march-2025)
- [Udonis — Guide for Creating Hybrid-Casual Games](https://medium.com/udonis/guide-for-creating-hybrid-casual-games-that-succeed-udonis-3c96a26d9ebe)
- [Appier — Hybrid-Casual Games](https://www.appier.com/en/blog/hybrid-casual-game)
- [r/gamedev — Is hybrid-casual quietly becoming the default model (D7 %5-8 → %15-20)](https://www.reddit.com/r/gamedev/comments/1sai8bv/is_hybridcasual_quietly_becoming_the_default_model)
- [Gamesforum Intelligence — Hypercasual Gaming Report 2025 (2.4B downloads)](https://www.scribd.com/document/982720258/Gamesforum-Intelligence-Hypercasual-Gaming-Report)
- [Liftoff — 2025 Casual Gaming Apps Report](https://liftoff.ai/2025-casual-gaming-apps-report)
- [Adjust — Ultimate Guide to Hyper Casual Games (stacking/turning/falling mekanik sınıfları)](https://www.adjust.com/blog/how-to-make-a-hyper-casual-game-successful)
- [InnoVcs — Hyper-Casual Games: What They Are & How to Profit (timing/agility/puzzle/swerve/merge)](https://www.innovecsgames.com/blog/hyper-casual-games)
- [Inc. — Is Block Blast Rigged? (70M DAU, adaptif dağıtım soruşturması)](https://www.inc.com/jelinda-montes/is-block-blast-rigged-a-developer-decompiled-the-viral-game-to-find-out/91419957)
- [Wikipedia — Block Blast! (~300M MAU)](https://en.wikipedia.org/wiki/Block_Blast!)
- [Felix Braberg — Block Blast: 40M DAU analizi](https://felixbraberg.substack.com/p/block-blast-review-what-is-behind-b38)
- [Global Games Forum — Block Blast: 95% fikir eleme + AI/A-B ("experience equality")](https://www.globalgamesforum.com/topic-theme/how-block-blast-shattered-records-with-ai-a-b-testing-and-a-bold-bet-on-long-term-players)
- [Crazy Cattle 3D — fizik komedyası organik virallik (Nisan 2025)](https://crazycattle3d.io)
- [Core Ball — tek-tap zamanlama ailesi](https://play.google.com/store/apps/details?id=com.nexus.coreball)
- [Apple Newsroom — 2025 Apple Design Awards (Balatro: Delight and Fun)](https://www.apple.com/nz/newsroom/2025/06/apple-unveils-winners-and-finalists-of-the-2025-apple-design-awards)
- [Apple Newsroom — 2024 Apple Design Awards (NYT Games)](https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards)
- [ustwo games — Monument Valley serisi (premium perspektif-döndürme referansı)](https://www.ustwogames.com)
- [Wikipedia — Suika Game (merge-circle tür açıklaması)](https://en.wikipedia.org/wiki/Suika_Game)
- [Medium — What Is a Suika Game? The Watermelon Merge Genre Explained](https://medium.com/@harisriazrabbani/what-is-a-suika-game-the-watermelon-merge-genre-explained-88d421d135d8)
- [Crazy Labs — ASMR Slicing (Google Play)](https://play.google.com/store/apps/details?id=com.crazylabs.asmr.cut)
- [Tummygames — Best Slicing and Cutting Games for Mobile](https://tummygames.com/blog/best-slicing-games-mobile)
- [Meldplay — Best ASMR Games for iPhone](https://meldplay.com/guides/best-asmr-games-iphone)
- [Logicsimplified — The Psychology Behind Puzzle Game Appeal (near-miss dengesi)](https://logicsimplified.com/newgames/the-psychology-behind-puzzle-game-appeal-why-we-keep-coming-back)
- [r/gamedesign — How Are Addictive Gameplay Loops Designed?](https://www.reddit.com/r/gamedesign/comments/1m9z4kd/how_are_addictive_gameplay_loops_are_designed)
- [Jabali — What Is a Core Game Loop? ("one more try" testi)](https://www.jabali.ai/blog/what-is-a-core-game-loop)
- [GamesD — How to Develop Hyper Casual Games (dopamin ufak-ödül döngüsü)](https://www.gamesd.app/guide/how-to-develop-hyper-casual-games-for-beginners)
- [LinkedIn — What Keeps Players Hooked on Hyper-Casual Games](https://www.linkedin.com/pulse/what-keeps-players-hooked-hyper-casual-games-daiema-zaheer-j7o6f)
- [r/FlutterDev — How I built a 60 FPS arcade puzzle game in pure Flutter (Ticker+CustomPainter)](https://www.reddit.com/r/FlutterDev/comments/1xjaahl/how_i_built_a_60_fps_arcade_puzzle_game_in_pure)
- [cos-go — Building a Particle Simulation Engine in Flutter (SandTrace)](https://cos-go.com/en/blog/flutter-particle-simulation-sandtrace)
- [cos-go — Physics-Based Balloon Popping Game in Flutter (60fps CustomPainter)](https://cos-go.com/en/blog/flutter-balloon-pop-physics-engine)
- [Amanotes — müzik-lane ailesi (RHYTHM çakışması için dışlama kanıtı)](https://www.amanotes.com)
- [MarketJS — katalog (hole eat grow ailesi kanıtı)](https://www.marketjs.com/catalog-direct)
- [Lagged — tüm-oyun kataloğu](https://lagged.com/all-games)
- [minireview.io — Hole.io-tür döngü tanımı](https://minireview.io/puzzle/meaningless/games-like)
- [Naavik — Hypercasual: Past, Present & Future (Supersonic mekanik tarihi)](https://naavik.co)
