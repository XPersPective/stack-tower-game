# RESEARCH: Saga Haritası DNA Raporu — Sonsuzluk, Teaser, Dünya Kimliği, Uzay Arka Planı (2026-11)

- **Tarih:** 2026-11-02
- **Kapsam:** 12 oyunun harita/ilerleme ekranı DNA'sı (sonsuzluk hissi, kilitli teaser, dünya-başı değişim, yol canlılığı, arka plan derinliği, okunurluk, performans) + harita tasarım literatürü + Flutter CustomPainter performans kaynakları
- **Yöntem:** Web araması (oyun wikileri, Deconstructor of Fun, Naavik, Game Developer, GameRefinery envanteri, geliştirici resmî blog/help merkezleri, topluluk: Reddit/King Community, tasarımcı portföyleri, akademik: Loewenstein/DiGRA, mühendislik: Game Programming Patterns + Flutter issue takipleri) — **8 kaynak türü**. Skorlar belgelenmiş mekanikler üzerinden 1-10; doğrudan kanıtı olmayan hücreler konservatif verilmiştir (INFERRED olarak okunmalı).
- **İlgili mevcut kod:** `lib/map/journey_map.dart` (dikey kıvrımlı yol, 150 düğüm, 10 kapı, 5 gizem segmenti, süsler, paralaks yıldız, metin önbelleği), `lib/screens/map_screen.dart` (sürükleme + atalet, `lockedWorldHint` teaser), `lib/game/levels.dart` (kWorldTeaser, kMysteries, 10 dünya), `lib/theme/tokens.dart` (WorldTheme: hues/bg/weather/silhouette), `lib/game/progress.dart` (`isUnlocked` yıldız kapısı).
- **Kullanıcı yönü (tur 6-7 özeti):** "harita aşağı indikçe hepsi gelebilsin, sonu gözükmesin; kilitli segmentlerde efektli parıltılı açıklamalar (içerik sızmaz); yolunda/arkasında/kilidinde efektler; her dünya kendine göre; yıldızlar parlaksın; arkasına güzel uzay."
- **Kısıt uyumu:** tüm öneriler harita sunum katmanındadır; `progress.isUnlocked` (JS birebir, C-002 alanı) ve çekirdek parite dokunulmaz; AmbientMotion test kapısı korunur; PB-036 metin önbelleği ve canlı-listener boyama mimarisi zemin alınır.

---

## 1. Yönetici Özeti: 8 Harita Yasası

1. **Sonsuzluk içerikle değil perdeyle yapılır:** Candy Crush'ın 20.000 seviyesi bile bir gün biter; ama haritada "bitiş duvarı" asla görünmez — önünüzde daima adı olan bir sonraki bölüm, adı olunca da sis/bulut perdesi vardır. Bizimki zaten 5 gizem segmentiyle başladı; doğru olan bu perdeyi **sonsuza kadar uzatmak** (formülle üretilen isim + daima ≥5 sisli segment ileride).
2. **15-25 seviyelik tema ritmi endüstri standardı:** Candy Crush 15/episod, Royal Match 20/area, Two Dots 25/world, Game Developer spec'i "1.5-2 ekran boyu = 15-25 seviye" der. Bizim 15/dünya ritmi doğru; eksik olan dünyaların **üçlü görsel imzası** (silüet şekli + parçacık + çapa objesi) tam çeşitliliği — `_paintSilhouettes` yalnız 'city'yi özel çizer, diğer 9 dünya aynı jenerik silüette eriyor.
3. **Teaser'da gösterilecek şey: KATEGORİ, gizlenecek şey: İÇERİK.** Royal Match "NEW BLOCK" kartıyla mekanik tipini gösterir ama tahtayı göstermez; P&D ödül kategorisini gösterir rare-invade'i gizler; Candy Crush kilitli düğümü sessizce kilitler (taptan yanıt yok — endüstride zayıf örnek). Formül: **isim/mood + yıldız şartı + ödül KATEGORİSİ göster; seviye numarası, tür, twist, değer gizle.**
4. **Görünür hedef sonsuz yakıttır:** Best Fiends'in "Mount Boom'a yolculuk" davası (540. seviyede hâlâ varılmamış dağ) tek başına 7 yıllık topluluk söylemi üretti. Haritanın en tepesinde daima sisin içinde bir şey parlamalı: "ufukta bir kule var ama oraya ışın yok."
5. **Yıldız üç iş yapar: ölçer, kilitler, ödüllendirir.** Royal Match/Toon Blast yıldızı sert kapıdan çıkarıp sandık/turnuvaya çevirdi (sürtünme azaldı, ödül döngüsü arttı); Candy Crush kapıyı bıraktı. Bizim `stage*10` sert kapı + 3-yıldız kaydı kombinasyonu meşru; ama yıldızın haritadaki GÖRÜNTÜSÜ (parlak madalyon) ödül hissinin ta kendisi — soluk yıldız = soluk ödül.
6. **Arka plan 5 katmandır ve blur pahalıdır:** uzay DNA'sı = (1) derin gradyan, (2) nebula blobları, (3) uzak yıldız, (4) yakın yıldız+glint, (5) silüet/çapa objesi — hız katmanları 0.15×/0.3×/0.55×/1.0×. Flutter'da `MaskFilter.blur` obje başına verilmez; nebula önceden render edilmiş `ui.Picture`, yıldız `drawPoints`, glint RadialGradient shader'dır.
7. **Node başına canlılık: durum başına bir davranış.** Bitmiş = sakin madalyon; mevcut = kometa/nabız; kilitli = yavaş nefes + seyrek pırltı + dokununca teaser kartı. Candy Crush kilitliye dokununca hiçbir şey olmaması = boş dokunuş; her dokunuş bir yanıt bulur.
8. **Harita bittikçe değil, "doldukça" güzelleşir:** Gummy Drop'ın anıt mekanizması (her anıt +10 seviye açar, harita fiziksel inşa edilir) bizim PB-029 inşaat meta'sının birebir endüstri kanıtı — inşaat kulesini dünyanın çapa objesi yapınca harita oyuncunun eseriyle dolar.

---

## 2. Kriterler ve Skor Tablosu

**H1** Sonsuzluk hissi (harita bitmez/duvar yok) · **H2** Kilitli içerik merakı (teaser: göster/gizle dengesi) · **H3** Dünya-başı görsel değişim · **H4** Yol/node canlılığı (animasyon, durum efektleri) · **H5** Arka plan derinliği (paralaks/nebula/atmosfer) · **H6** Bilgi hiyerarşisi (isim/görev/ödül okunurluğu) · **H7** Performans sinyali (uzun harita akıcılığı) · **TOPL** /70

| Oyun | H1 | H2 | H3 | H4 | H5 | H6 | H7 | TOPL | İmza |
|---|---|---|---|---|---|---|---|---|---|
| **Candy Crush Saga** | 10 | 6 | 9 | 8 | 6 | 9 | 8 | **56** | 20k seviye + haftalık episod; bitiş duvarı yok |
| **Royal Match** | 7 | 9 | 9 | 8 | 6 | 9 | 9 | **57** | 20 seviyelik area + NEW BLOCK intro kartı |
| **Gummy Drop!** | 7 | 8 | 9 | 7 | 6 | 7 | 7 | **51** | Anıt inşaatı haritayı fiziksel doldurur (+10 seviye/anıt) |
| **Two Dots** | 7 | 8 | 9 | 5 | 6 | 8 | 9 | **52** | Konuk sanatçı dünya skinleri + haftalık hazine haritası |
| **Best Fiends** | 8 | 7 | 8 | 7 | 7 | 7 | 7 | **51** | Görünür hedef: Mount Boom uzak silüeti |
| **Angry Birds Journey** | 7 | 6 | 8 | 6 | 6 | 8 | 8 | **49** | Mevsimsel bölüm temaları (Toadstool Towers…) |
| **Gardenscapes** | 5 | 8 | 8 | 5 | 7 | 8 | 8 | **49** | Harita yok — "1 yıldız = bahçede görünür iş" |
| **Monument Valley** | 4 | 6 | 10 | 5 | 9 | 7 | 9 | **50** | Her bölüm poster kalitesinde anıt; chapter select sanat galerisi |
| **Lily's Garden** | 5 | 7 | 7 | 4 | 6 | 7 | 8 | **44** | Hikâye kapılı area açılımı |
| **Toon Blast** | 6 | 5 | 4 | 4 | 3 | 9 | 10 | **41** | "Saga'nın ölümü": çipler + lonca + etkinlik |
| **Puzzle & Dragons** | 6 | 8 | 5 | 3 | 4 | 6 | 8 | **40** | Program panosu + rare-invade sır perdesi |
| **Fishdom** | 6 | 7 | 6 | 6 | 6 | 9 | 9 | **49** | Seviye zinciri + akvaryum; temiz sayı hiyerarşisi |

**Okuma:** Tek kriterde bile tam puan yok; H1+H2 uçlarını ancak uzun-metrajlı saga haritaları (CC, RM, Best Fiends) alıyor. H7 zirvesi haritayı küçülten oyunlarda (Toon/Fishdom/P&D) — **bizim fırsat: Royal Match'in teaser disiplini + Candy Crush'un sonsuzluk hissi + Toon'un performans sıfırı** aynı haritada. Stack Tower mevcut durumu kabaca H2=6, H3=5, H4=6, H5=4, H6=7, H7=6 bandında; raporun kalanı bu boşlukları doldurma reçetesidir.

---

## 3. "Sonsuzluk" Teknikleri (H1)

### 3.1 Candy Crush: 20.000 seviye nasıl taşınır
- **İçerik üretimi prosedürel değil, şablonlu-insanlı boru hattı:** ~6 hedef tipi (jelly/ingredient/order/… ) × grid şekilleri × engeller × özel şekerler = kombinatorik çeşitlilik; King "magic and data" der (tasarımcı sezgisi + churn/ zorluk analitiği); resmî çerçeve "4T" (Theory, Thought, Tools, Testing); topluluk 18k+ seviyeleri şablon-ağırlıklı, 6-9k arasını el yapımı görür. Yılda ~1000+ seviye; 15k Ağustos 2023, 20k Ağustos 2025.
- **Harita tarafı:** episod = 15 seviyelik TemALI sayfa; "tiles/pages that load inside a scrolling map" — motor oyuncunun penceresine yakın episodları yükler, gerisi veri. 2023 "New Saga Map" yenilemesi: mevsimle değişen zemin, "oyunun nasıl oynanmasının istendiğini anlatan" düzen; episod bannerları (Candice fontu, ayrı banner/yol renkleri) dönemin kimliğini taşır.
- **Bizim karşılığı:** 150 bölüm tek `journeyLayout`'ta hesaplanıyor ama painter pencere dışını zaten atlıyor (`p.dy < -90 || > h+90 continue`). Eksik tek şey **gizem segmentlerinin sınırsızlaştırılması**: bugün `journeyHeight()` sabit (+5 segment) ve scroll clamp orada bitiyor → oyuncu "duvarı" görebilir. Aşağıda §6(a).

### 3.2 Node recycling ve uzun harita performansı (H7)
- Endüstri kalıbı: **object pool + viewport culling + chunk render** (Game Programming Patterns — Object Pool; "only manage/draw objects when the player is near"); RecyclerView/ViewHolder aynı ilke UI'da; Flutter'da karşılıklar: `Path`/`TextPainter`/`ui.Picture` önbelleği, `RepaintBoundary`, `drawPoints`/`drawVertices` ile batch, saveLayer'ı katman başına 1'e indirmek.
- Flutter spesifik tuzaklar (issue takipleri): yüzlerce Bézier + zoom'da 4ms→80ms yığılma (#78543); statik içerik için Path cache + arka plan layout'u yapılamıyor (#115257); `MaskFilter.blur` iOS'ta sürekli repaint + %80 CPU (#174388); büyük blur sigma'sı klip taşırır (#136519); Impeller geçişinde saveLayer/blend maliyeti değişti — glow'u per-object blur yerine gradient + additive blend ile vermek standart.
- **Bizim durum:** PB-036 metin önbelleği kök nedeni çözdü; kalan riskler: (1) gizem segmentlerinde kare başına ~14+ `MaskFilter.blur` çağrısı (sis ovali + kemer glow + rune), (2) 90 yıldızın 90 ayrı `drawCircle` olması, (3) `shouldRepaint => true` zaten her karede boyuyor (ticker var — kabul edilebilir ama süreç her karede tüm katmanları yeniden hesaplıyor). §6(d) bütçesi bunları kapatır.

### 3.3 Tema rotasyonu / asset loop (H3)
- Game Developer saga spec: zone uzunluğu 1.5-2 ekran boyu = 15-25 seviye; her zone kendi açıklama dokümanı; format seçimi "yeni zone ekleme kolaylığına" göre; mobilde dikey en popüler.
- Asset loop kalıbı (Extra Credits/Endüstri pratiği): **tek iskelet, çok skin** — düğüm butonu/road/dekor geometrisi sabit; zone başına palette swap + 3-5 özgün dekor + banner. Two Dots bunu uç ettirdi: her treasure hunt haritasını konuk sanata (Aldo Crusher, Mauro Martins, Matt Stevens, Canopy) verdiler — "yeni dünya" hissi sıfır yeni engine maliyetiyle.
- **Bizim karşılık:** `WorldTheme` zaten hues/bg/weather/silhouette taşıyor; eksik: silhouette şekillerinin gerçekten farklılaşması (bkz. §6(b) üçlü imza) ve weather parçacıklarının haritada hiç olmaması (oyun sahnesinde var — `scene_painter` snow/sand/embers/leaves zaten yazılı, haritaya taşınabilir).

---

## 4. Kilitli Teaser Kalıpları (H2)

### 4.1 Ne gösterilir / ne gizlenir — endüstri örnekleri

| Oyun | Gösterilir | Gizlenir | Teaser taşıyıcı |
|---|---|---|---|
| Candy Crush | Sonraki episodun ADI + banner + karakter + kilitli düğüm gri | Tahta içeriği (oynayınca görülür) | Harita yolculuğu; kilitli tap → yanıt yok (zayıf) |
| Royal Match | Yeni engelin TİPİ ("NEW BLOCK" kartı, tahtasız) + area adı | Level kompozisyonu, ödül değerleri | Area öncesi intro kartı; NEW AREA anı |
| Gummy Drop | Sıradaki şehir silüeti + inşaat halindeki anıt iskelesi | Anıt bitmişi, kaynak miktarı | İskele görseli = "bunu yapacaksın" sözü |
| Best Fiends | Hedef dağın uzak silüeti; boss bölgesi adı | Boss detayı | "Mount Boom'a yolculuk" anlatısı |
| P&D | Dungeon adı + ödül kategorisi + takvim slotu | Rare invade, drop oranları | Program panosu "coming soon" |
| Two Dots | Treasure hunt teması adı + sanatçı haritası | Hazine yerleri | Haftalık yeni harita + gizli nesne |
| **Bizim mevcut** | `lockedWorldHint` (teaser'ın ilk %55'i + "…"), kapıda yıldız şartı, gizem segmentlerinde "??? · AD" | Tür/twist/ödül (doğru) | Metin; **efekt + kart yok** |

### 4.2 Psikoloji: bilgi boşluğu yasası
- Loewenstein (1994) bilgi-boşluğu kuramı: merak, "biraz bilip bütünü bilmemek"ten doğar — hiçbilmezlik değil **kısmi bilgi** çeker. DiGRA (To et al. 2016) oyunlar için 5 merak tipi ayırır (algısal, manipülatif, epistemik/karmaşık-ambigü…): harita teaser'ı **algısal + epistemik** tipleri birden vurur — parıltı görülür (algısal), ne olduğu söylenmez (epistemik).
- Zeigarnik: yarım kalan iş zihinde açık döngü olarak kalır; quest log/preview ekranlarının dayanağı. "Teaser'ı %55'te kes" bizim `lockedWorldHint` kuralı Literatürle birebir doğru — ama **tek başına metin** yeterli uyaran değil; parıltı efekti + dokunuş yanıtı eklenmeli.

### 4.3 Tap/hover önizleme davranışı (mobilde tap)
- Candy Crush: kilitli → yok (çirkin boşluk). Royal Match: kilitli area → dokunulamaz ama görünür; "View" ile geçmiş alanlara dönüş var (arkaya gitme sürtünmesi düşük).
- İyi kalıp (P&D/Two Dots/Gummy Drop birleşimi): dokun → **mikro kart**: ad/mood cümlesi + şart (yıldız) + ödül kategorisi ikonları + "şu kadar ileride" mesafesi. Kapanış: dışarı tap. Hiçbir içerik sızmaz (numara/tür/değer yok).
- Sır perdesi istisnası: P&D rare-invade gibi **sürpriz değeri olan** şey tamamen gizlenir ve rastlantıyla ödüllendirilir (bizim twist'ler ve süpriz sandık tam bu — kartta asla telaffuz edilmez).

---

## 5. Arka Plan DNA'sı: Uzay/Nebula/Paralaks Katman Sırası + Alpha Bütçesi (H5)

Endüstri reçetesi (GameMaker paralaks rehberi + GameDev SE uzay-zemini başlığı + Reddit derinlik tartışması): uzay arka planı 3-5 katman; en uzak en yavaş ve en soluk; yıldızlar küçük/soluk-uzak, büyük/parlak-yakın; nebula en arkada düşük alfa ile.

### 5.1 Katman sırası (arkadan öne) — Stack Tower haritası için

| # | Katman | Kaydırma hızı | Renk/Alfa | Yöntem |
|---|---|---|---|---|
| 0 | Dünya bandı gradyanı (bg1→bg2, üstte uzay-mürekkebine lerp) | 1.0× (banda bağlı) | mevcut (koyu ~%45-100) | LinearGradient, mevcut `_paintBackground` |
| 1 | **Nebula** (2-3 blob/ekran; dünya hue'suna kaymış mor/camgöbeği) | 0.15-0.25× | α 0.06-0.12 | RadialGradient; **dünya başına 1 kez `ui.Picture`'a render, her karede `drawImage`** |
| 2 | Uzak yıldız tarlası (yoğun, 0.4-1.1 px) | 0.30× | α 0.20-0.45, twinkle sin(t·0.4+φ) | **tek `drawPoints`** (PointMode.points), seed sabit |
| 3 | Yakın yıldız tarlası (1.0-2.2 px) | 0.55× | **α 0.55-0.95** (kullanıcı: "yıldızlar parlaksın"), en parlak ~8 tanesine 4 uçlu glint artısı | drawPoints + glint'ler RadialGradient sprite (blur YOK) |
| 4 | Ufuk/derinlik perdesi (ekran üst bandı uzay-mürekkebi) | ekran-sabit | α 0.30→0.00 gradyan | mevcut `_paintHorizon` + öneri: alfa 0.35'e ve sarımsı-mora (268 hue) sabitlenir |
| 5 | Dünya silüetleri + çapa objesi (gezegen/kristal/ağaç) | 1.0× (banda bağlı) | dolgu: hue 30% ışık %13, α ~0.85 | **dünya başına önceden derlenmiş `Path`** (şekil §6(b)) |
| 6 | Süs/glint katmanı (küre, glint, rune) | 1.0× | pulse α 0.10-0.85 | mevcut `_paintDecor`; rune halkalarında blur kaldır |

### 5.2 Alpha & blur bütçesi (CustomPainter gerçekleri)
- **Kural 1 — Kare başına `MaskFilter.blur` ≤ 8-10.** Bugün gizem segmenti başına 2-3 blur (sis + kemer + rune yakını) → ekranda 2 segment = 6, dekor rune'ları eklenince 10+ taşar. Çözüm: glow hissinin %90'ı **RadialGradient (alpha falloff) + `BlendMode.plus`/`lighten`** ile verilir; blur yalnız sis bulutu ve kemerde kalır.
- **Kural 2 — Aynı içerik her karede yeniden hesaplanmaz:** nebula blobları + yıldız tarlası dünya-hue'suna bağlı → hue bandı değişmedikçe `ui.Picture` cache; yıldız pozisyonları seed'li, twinkle yalnız alfa (pozisyon mutasyonu yok).
- **Kural 3 — Batch:** 90 `drawCircle` → 1-2 `drawPoints`; decor glint'lerinde `save/translate/rotate` per obje yerine halka başına tek matrix.
- **Kural 4 — saveLayer tek katmana:** additive glow'lar `Paint()..blendMode` ile sıralı çizilir, `saveLayer` yalnız sis bulutu kompozitinde.
- Referans zemin: PB-036 canlı-listener boyama + metin önbelleği zaten doğru; bu bütçe eklendiğinde 150 düğüm + sınırsız gizem segmenti 60 fps bütçesine oturur (frame drop'suz kaydırma = H7).

---

## 6. Stack Tower `journey_map.dart` İçin SOMUT Öneriler

### (a) Sonsuzluk mekanikleri — "sonu gözükmesin"
1. **Gizem segmentini formüle bağla:** `mysteryCount` sabit 5 yerine: görünür ilerleme + K (≥6) olacak şekilde — `visibleMystery = kStageCount + max(5, unlockedStage + 6)`; isimler kelime bulutu + seed'den: `['GİZEMLİ','YANKI','SİS','RUNE','ATEŞ','AYNA','BOŞLUK','FISILTI','KUYLU','TAŞ']` × `['BULUTLARI','KULESİ','KAPISI','VADİSİ','NOKTASI','GEÇİDİ']` kombinasyonu → her oyunda aynı, ilerledikçe yeni. `journeyHeight()`'i bu sayıdan türet; scroll clamp üst sınırını "mevcut düğüm + 6 segment"te tut, oyuncu ilerledikçe tavan büyür → **duvar asla kadrajda değil**.
2. **Derinlik perdesi:** en üstteki görünür segmentin üstünden itibaren uzay-mürekkebi gradyanı (α 0→0.85, ~1.5 ekran boyu) — segmentler sise karışır, "buradan sonrası da var" der; kesme çizgisi yok.
3. **Kapı öncesi "yol devam eder" hissi:** kilitli kapının üstünden yol 2-3 düğüm boyunca sise uzanır (kilitli düğüm şekilleri silikleşerek, α 0.6→0.15).
4. Atalet kıvrımında (flick) üst sınıra gelinince küçük bir "esneme" + sisin nabzı hızlanır — sınır cezalandırmasın, davet etsin.

### (b) Dünya-başı environment setleri — her dünya 3 görsel öge + silüet + parçacık
Mevcut `WorldTheme.weather` oyun sahnesinde yaşıyor; haritaya taşınır ve silüetler gerçekten farklılaşır. Her dünya: **1 silüet şekli + 1 parçacık + 1 çapa objesi (1-2 kez/bant, çizim pahalı olan tek şey)**:

| Dünya | Silüet (Path, cache) | Parçacık (haritada) | Çapa objesi |
|---|---|---|---|
| NEON ŞEHİR | gökdelen + ışıklı pencere noktaları | neon yağmur çizgileri (eğik, kısa) | dev holo-reklam ringi (dönen) |
| BİYO ORMAN | gerçek ağaç: gövde + katmanlı taç (2-3 yükseklik) | ateşböceği (parlak, sin nabız) | dev biyo-lambası bitki |
| ALTIN ÇÖL | kumul eğrileri (2 dalga, üst üste) | kum wisps (yatay süpürme) | ufukta alçak güneş/ay diski + vaha palmiyesi |
| BUZ DÜNYA | buz kristali sivrilikleri (yarı saydam poligon + spec çizgi) | kar (mevcut snow) | dev rün buz kristali (içi ışıldar) |
| UZAY | asteroit kayalık | yoğun yıldız (katman zaten) | halkalı gezegen (glint kuşağı) |
| VOLKAN | koni + zirve dumanı | kor (embers, yükselen) | lav çatlağı glow'u (yolun dibinde turuncu damar) |
| BULUT ŞEHİR | bulut bankları (yumuşak elips zinciri) | ışık huzmesi çizgileri | yüzen ada + kule silüeti |
| DERİN DENİZ | su yüzeyi çizgisi + kaustik shimmer (üstte) | kabarcık (yükselen) | dev denizanası glow (1 adet, çok soluk) |
| KRİSTAL MAĞARA | sarkıt/dikit kümesi | toz zerre (yavaş) | jeot (kırık kristal, iç glow) |
| SON KULE | tüm dünyaların motifleri cılız karışım + kolo · kolosal kule | yıldız + kor karışımı | takımyıldız halkası (menü ekranıyla aile) |

Uygulama: `_paintSilhouettes`'a dünya-başına switch + her şekil için `Path` önbelleği (seed sabit); çapa objeleri yalnız bant görünürken çizilir. Bu tablo PB uygulamasında görsel kanıt (evidence) listesi olarak da kullanılır.

### (c) Node tap önizleme kartı — efektli açıklama, içerik sızmaz
- **Kilitli düğüm / gizem segmenti tap →** GlassPanel teaser kartı (premium_kit var): başlık = dünya adı (kilitli dünyadaysa "DÜNYA N · 🔒 N★") veya "???" ; gövde = `kMysteries`/`kWorldTeaser` fısıltısı (mevcut havuzlar); satır 3 = **ödül kategorisi ikonları** (para/yıldız/sandık — değer yok); satır 4 = mesafe ("3 BÖLÜM İLERİDE" / "N ★ GEREKLİ"). Kapanış: dış tap; açılışta spark patlaması (12 parçacık, mevcut FX üslubu) + hafif haptic. **Asla gösterilmez:** bölüm numarası, GameKind glifi, twist, kesin ödül.
- **Unlocked node tap →** mevcut akış (preview). Kart gerekmez.
- **Done node tap →** mini "REKOR: N ★" kartı + "TEKRAR OYNA" — Candy Crush'ın replay akışı; arkaya dönüş sürtünmesini düşürür (Royal Match "View" kalıbı).
- Kartta kullanılan merak grameri: **kısmi bilgi + açık döngü** (§4.2) — "Bu bölümde bir şey saklı" cümlesi parıltı efektiyle **görülür**, içerik söylenmez.

### (d) Arka plan sparkle/nebula katmanı
§5.1'in birebir uygulaması: (1) `_paintNebula` — dünya hue'sundan 2-3 RadialGradient blob, `ui.Picture` cache, 0.2× paralaks; (2) yıldızları 2 katmana böl (`drawPoints`), yakın katman α 0.55-0.95 + ~8 glint (kullanıcı talebi "yıldızlar parlaksın" — mevcut tepe α ~0.44 yetersiz); (3) ufuk perdesini hafif büyüt; (4) mevcut `_paintDecor` glint'leri RadialGradient'e çevir (blur'suz) — aynı ışıltı, bütçe dostu. Menü ekranındaki takımyıldız ağı (PB-033 tur 2) ile aynı görsel aile: harita "gökyüzünün devamı" hissi.

### (e) Kilitli node gizemli davranışı (ve arkası/yolu)
- **Kilitli:** yavaş nefes glow halkası (tema hue, α 0.10-0.22, periyot ~2.6s, seed kaydırmalı) + ~2.4s'de bir tek pırltı çapraz geçişi (glint sprite, node üstünde 300ms) + kilit ikonu korunur. Dokun → (c) kartı. "Efektli parıltılı açıklama, içerik sızmaz" talebinin düğüm karşılığı.
- **Arkada (done):** sakin yıldız madalyonu + çok düşük nabız halo (α 0.30→0.12 nabız) — "kazanılmış toprak ışıklı"; kaydırırken geriye bakınca parıldayan bir iz. Yıldız 3/2/1'e göre madalyon içi yıldız sayısı/büyüklüğü ayrışsın (mevcut tek yıldız çizimi bilgi kaybettiriyor — H6).
- **Yolda:** akan kesikli ışık mevcut ama rengi sabit `kThemes[0]` — mevcut dünyanın hue'suna kayar; kapı 10 yol boyunca ışık "esner" (dash phase hızı kapıya yaklaşırken artar).
- **Mevcut düğüm:** kometa + pulse mevcut (iyi); ek: kometa kuyruğu son 3 bitmiş düğümden iz bıraksın (α 0.08 iz) — "yolculuk seni taşıyor" hissi.

---

## 7. Kabul Kriterleri — "Kullanıcı Cezbedilir mi?" Testi (5 madde)

1. **Duvar testi:** oyuncu ilerlemesinden bağımsız olarak haritayı en ileri noktaya kadar çektiğinde kadrajda daima ≥1 sisli gizem segmenti + derinlik perdesi vardır; "harita bitti" duvarı 0 oyuncu anında görünür. (H1)
2. **İlk-10-saniye bakış testi:** harita açılışında göz 1 sn içinde mevcut düğüme (kometa) ve en yakın parıltıya gider — ekran görüntüsünde tek odak; kilitli bir düğüm yavaş nefes glow'uyla "dokunulmaya hazır" görünür. (H4/H2)
3. **Merak testi (içerik sızmaz):** kilitli düğüme dokunan oyuncu bölüm numarası/tür/twist/ödül değeri ÖĞRENEMEZ ama dünya adı + mood fısıltısı + yıldız şartı + ödül kategorisi öğrenir; kart açılışında spark + haptic vardır, ikinci dokunuş isteği doğar. (H2)
4. **Dünya kimliği testi:** 10 dünya ekran görüntüsü yan yana konduğunda, dünya numarası etiketi gizliyken tanıdık sayısı ≥8/10 (silüet + parçacık + çapa üçlüsü benzersiz; 'city' dışı dünya jenerik silüette eremez). (H3)
5. **Akıcılık testi:** 150 düğüm + sınırsız gizem segmenti açıkken kaydırma 60 fps (düşünce-mid cihaz profili); kare başına `MaskFilter.blur` ≤10, yıldız çizimi ≤2 draw çağrısı, metin önbelleği isabeti ~%100; parlak yıldız tepe alfa ≥0.85 ("yıldızlar parlaksın" subjektif onayı + ekran kaydı kanıtı). (H5/H7)

---

## 8. Kaynaklar

**Endüstri analizi (Deconstructor of Fun / Naavik / Game Developer):**
- Deconstructor of Fun — Toon Blast and the Death of Saga: https://www.deconstructoroffun.com/blog/2017/11/6/fj7k5up2nv7hscrf99h3cyvpi64bsv
- Deconstructor of Fun — Royal Match deconstruction: https://www.deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey
- Deconstructor of Fun — Chrome Valley Customs (tema/kitlesel harita seçimi): https://www.deconstructoroffun.com/blog/2023/8/14/chrome-valley-customs-a-new-contender-in-the-match-3-race
- Naavik — Royal Match deep dive: https://naavik.co/deep-dives/royal-match
- Game Developer — All the Saga Map Specifications You Should Know: https://www.gamedeveloper.com/design/all-the-saga-map-specifications-you-should-know
- Game Developer — Crack the Match 3 Code Part 4 (Project Makeover, Om Tandon): https://www.gamedeveloper.com/business/how-to-crack-the-match-3-code---part-4-project-makeover
- Game Developer — King's Guide to Level Design (4T): https://www.gamedeveloper.com/design/video-king-s-guide-to-level-design-for-casual-games
- PocketGamer.biz — King "magic and data": https://www.pocketgamer.biz/king-on-finding-the-fun-in-candy-crush

**Oyun resmî / wiki / topluluk:**
- Candy Crush Wiki — Episode / Reality / Levels by episode: https://candycrush.fandom.com/wiki/Episode · https://candycrush.fandom.com/wiki/Reality
- King Community — New Saga Map Makeover (2023): https://community.king.com/en/candy-crush-saga/discussion/393135/new-saga-map-makeover-check-it-out
- King Help — kilitli seviye kuralları: https://candycrush.zendesk.com/hc/en-us/articles/360007248018
- Royal Match Help — Areas/View + Stars: https://dreamgames.helpshift.com/hc/en/3-royal-match/faq/18-how-can-i-access-completed-areas · …/16-how-can-i-get-stars
- Gamigion — Royal Match Level Design Insights (20-level area, victory lap): https://www.gamigion.com/royal-match-level-design-insights
- Medium (E. Sazer) — Royal Match & Toon Blast analizi: https://medium.com/@ekinmelissezer/game-analysis-for-royal-match-and-toon-blast-9c4bff8ef48b
- Toon Blast Help — Star Boxes/Tournament: https://peakgames.helpshift.com/hc/en/4-toon-blast/faq/617-how-can-i-open-star-boxes
- Best Fiends Wiki — Frozen Hills/Mount Boom: https://best-fiends.fandom.com/wiki/Ice_Halls
- Two Dots Help — Treasure Hunts: https://dots.helpshift.com/hc/cs/3-two-dots/faq/386-what-are-treasure-hunts/ · We Play Dots blog (25-level worlds): https://blog.weplaydots.com/post/97756411975
- Two Dots sanatçı haritaları: https://mauromartins.com/two-dots-artistic-avenues · https://hellomattstevens.com/blog/new-work-two-dots-maps-part-1 · https://canopydesign.co/two-dots-treasure-hunt
- Monument Valley Wiki — Chapter Walkthrough: https://monument-valley.fandom.com/wiki/Chapter_Walkthrough
- Gummy Drop Help — Cities Map Progression + Resource Buildings: https://gdgame.zendesk.com/hc/en-us/articles/43206546878737 · …/43216788134289
- Lily's Garden topluluk (area/harita algısı): https://www.reddit.com/r/Lilysgarden/comments/1kavpcm/map
- P&D NA — Ver. 16.0 Dungeon UI yenilemesi: https://www.puzzleanddragons.us/single-post/2018/12/10/ver-160-update
- Gardenscapes area/day akışı (oynanış kanıtları): https://www.youtube.com/results?search_query=gardenscapes+area+day+renovation

**Psikoloji / UX kuramı:**
- Loewenstein (1994) — The Psychology of Curiosity (bilgi boşluğu): https://www.jstor.org/stable/1179050
- To et al. (DiGRA 2016) — Integrating Curiosity and Uncertainty in Game Design: https://www.digra.org/digital-library/publications/integrating-curiosity-and-uncertainty-in-game-design/
- Psychology of Games — Zeigarnik & quest logs: https://www.psychologyofgames.com/2012/07/the-zeigarnik-effect-and-quest-logs/
- Chunks — Curiosity Gap vs Zeigarnik: https://chunks.app/help/curiosity-gap/

**Paralaks / arka plan derinliği:**
- GameMaker — Creating Depth & Immersion: Parallax: https://gamemaker.io/blog/creating-depth-and-immersion-parallax
- GameDev SE — parallax background depth (uzay, katman alfa): https://gamedev.stackexchange.com/questions/43854/how-to-give-parallax-backgrounds-more-depth
- Tuts+ — Parallax Scrolling: https://code.tutsplus.com/parallax-scrolling-a-simple-effective-way-to-add-depth-to-a-2d-game--cms-21510t
- Wikipedia — Parallax scrolling (yöntem sınıfları): https://en.wikipedia.org/wiki/Parallax_scrolling

**Flutter performans / render:**
- Game Programming Patterns — Object Pool: https://gameprogrammingpatterns.com/object-pool.html
- GameDev SE — managing thousands of objects (viewport yakınlığı): https://gamedev.stackexchange.com/questions/137410/best-way-to-manage-thousands-of-objects-in-an-multiplayer-online-game
- Flutter #78543 (Bézier/zoom yığılması) · #115257 (Path/Picture cache) · #174388 (blur sürekli repaint) · #136519 (blur sigma klip): https://github.com/flutter/flutter/issues/78543 · …/115257 · …/174388 · …/136519
- PlugFox — High-Performance Canvas Rendering: https://plugfox.dev/high-performance-canvas-rendering
- Stack Overflow — tiled pan/zoom CustomPaint: https://stackoverflow.com/questions/58037527/flutter-more-efficient-pan-and-zoom-for-custompaint
- Extra Credits — Asset Reuse (tema skin üretimi): https://www.youtube.com/watch?v=tmGxUhtKl04
