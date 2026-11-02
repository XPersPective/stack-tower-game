# RESEARCH: Endgame DNA Raporu — Kazanma/Kayıp/Geçiş Sekansları (2026-11)

- **Tarih:** 2026-11-02
- **Kapsam:** 15 oyunun oyun-bitişi DNA'sı (kazanma şöleni, kayıp konsolasyonu, bölüm geçişi) + UX/juice literatürü
- **Yöntem:** Web araması (oyun wikileri, Deconstructor of Fun, Naavik, GameRefinery, Funovus, mağaza/topluluk kaynakları) + gameplay kayıtlarından sekans rekonstrüksiyonu. **ms değerleri OBSERVED (wiki-teyitli mekanik) + INFERRED (video temelli tahmin) karışımıdır — mutlak gerçek değil, tasarım hedefi olarak okunmalı.**
- **İlgili mevcut kod:** `lib/game/gameplay.dart` (hit-stop/finale/zoom), `lib/screens/flow_overlays.dart` (result/_AnimatedStar/CountUpText/NEREDEYSE), `lib/game/game_session.dart` (onWin/onLose zinciri), `lib/ui/premium_kit.dart` (CountUpText)
- **Kısıt uyumu:** tüm öneriler sunum/meta katmanındadır; drop_core/motor matematiği (C-002) ve twist şeması (C-017) dokunulmaz. Juicе yasaları (C-023), cömertlik (C-019), AmbientMotion test kapısı korunur.
- **Kardeş rapor:** `RESEARCH-dna-2026-11.md` (18 oyun genel DNA) — bu rapor o geniş taramanın **oyun-bitişi (endgame) derinleştirmesi**dir.

---

## 1. Yönetici Özeti: 7 Endgame Yasası

1. **Şölen oyuncunun kaynaklarından doğar:** Candy Crush'ta kazanma anı sabit bir animasyon değildir — kalan hamlelerin şekerlere dönüşüp SIRAYLA patlamasıdır. Her kazanç, oyuncunun o turdaki artığıyla benzersizdir. Statik "Tebrikler!" şablonunun 100. gösterimi bayatlar; oyuncu kaynaklı şölen bayatmaz.
2. **İlk 1 saniye = üç kanal aynı karede:** kazanma anında donma/flaş/ses/dokunuş aynı ~100ms penceresinde tetiklenir (Stack Ball fire finali, Toon Blast patlaması). Gecikmeli tek kanal = soğuk kazanç.
3. **Ödül uçuşu ödülün kendisidir:** Royal Match'in kuralı — kaynak nereden çıktı, nereye uçtu FİZİKSEL olarak gösterilir ("fly from the place it was unlocked to the container"). Uçmayan ödül, verilmiş sayılmaz.
4. **Kazanç anı geleceğe yatırılır:** Royal Match Butler's Gift, kazanç ekranında bir SONRAKİ bölümün booster'ını verir — doruk anı, hemen sonraki oturumun sözü haline gelir.
5. **Kayıp = duygusal zirve; cömertlik orada konumlanır:** Block Blast ikinci şans, Candy Crush "+5 hamle", Royal Match'in Kral tepkisi. Kaybın hemen ardından verilen cömertlik, kazanma ödülünden daha güçlü bağ kurar. Ama match-3'lerin versiyonu faturaya dönüşür — reklamsız çeviri (bizim alan) boşluktur.
6. **Geçiş sürtünmesi ≤1 sn:** Stack/Stack Ball/Helix/Tomb'da yenilgiden yeni oyuna ≤1 sn. Match-3'lerde meta zinciri 3-4 tık ekler — ama doruk (skor/yıldız) GENELLİKLE zincirin sonuna atılır; dramaturji tersten akar.
7. **Ses ve sayı senkronu:** Stack'in pitch merdiveni sahne içinde mükemmeldir ama meta katmanına hiç taşınmamıştır; count-up'ların neredeyse tamamı sessizdir. Sayaç + artan perde + bitişte chime = endüstride boş alan.

---

## 2. Kriterler ve Skor Tablosu

**E1** Kazanma anının ilk 1 saniyesi (anında patlama var mı?) · **E2** Ödül sunumu dramaturjisi (count-up, yıldız süpürme, sandık, uçuş) · **E3** Geçiş akıcılığı (sahne içi mi overlay mi; sürtünme) · **E4** Kayıp anı affedişliği (NEREDEYSE/comeback/ikinci şans) · **E5** Tekrar-oyna sürtünmesi (≤1 sn restart?) · **E6** Sürpriz/gizem dozu (değişken ödül, jackpot) · **E7** Ses/müzik katkısı · **TOPL** /70

Skorlar belgelenmiş mekanikler + gameplay gözlemi üzerinden 1-10; tahmine dayalılar konservatif verilmiştir.

| Oyun | E1 | E2 | E3 | E4 | E5 | E6 | E7 | TOPL | İmza |
|---|---|---|---|---|---|---|---|---|---|
| **Candy Crush Saga** | 10 | 10 | 8 | 9 | 3 | 8 | 10 | **58** | Sugar Crush: kalan hamle şölene dönüşür |
| **Royal Match** | 9 | 9 | 8 | 9 | 7 | 8 | 8 | **58** | Coin uçuşu + Butler's Gift (geleceğe ödül) |
| **Block Blast!** | 8 | 8 | 9 | 10 | 9 | 7 | 7 | **58** | Duygusal zirvede ikinci şans + adaptif zorluk |
| **Subway Surfers** | 6 | 10 | 7 | 9 | 9 | 10 | 8 | **59** | Mystery Box jackpot + çiftle teklifi |
| **Toon Blast** | 9 | 9 | 8 | 7 | 5 | 7 | 9 | **54** | Üçlü patlama haptiği + Toon Pass rozeti |
| **Spiral Roll** | 9 | 7 | 9 | 5 | 9 | 5 | 9 | **53** | Birikmiş spiral son dilimi devirir (klimaks) |
| **Stack Ball** | 9 | 6 | 10 | 6 | 10 | 4 | 8 | **53** | Fire finali + buldozer zemin ezme |
| **Tomb of the Mask** | 7 | 5 | 10 | 7 | 10 | 6 | 8 | **53** | Anında respawn, 30 sn seans |
| **Woka Woka** (marble) | 8 | 8 | 7 | 7 | 7 | 8 | 8 | **53** | Yıldız barı + bonus çark geleneği |
| **Helix Jump** | 8 | 5 | 10 | 6 | 10 | 4 | 7 | **50** | Fire mode: kuleyi yukarıdan aşağı yıkma |
| **Gardenscapes** | 8 | 8 | 7 | 6 | 5 | 7 | 8 | **49** | 1 yıldız = bahçede görünür iş |
| **Homescapes** | 8 | 8 | 7 | 6 | 5 | 7 | 8 | **49** | Aynı DNA, ev meta'sı |
| **Crossy Road** | 7 | 9 | 8 | 7 | 9 | 10 | 7 | **57** | Ölüm kamerası + karakter makinesi gizemi |
| **Beatstar** | 8 | 8 | 8 | 7 | 9 | 6 | 10 | **56** | Şarkı bitişi müzikal vurgu + sonraki şarkı |
| **Stack** | 6 | 3 | 10 | 5 | 10 | 2 | 10 | **46** | Pitch merdiveni + halka; ödül katmanı YOK |

**Okuma:** E1+E4+E6'da zirve yapanlar (CC/RM/Block Blast/Subway) meta derinliği olan oyunlar; E3+E5'te zirve yapanlar hiper-casual. **Hiçbir oyun yedi kriterde birden zirve değil** — bizim fırsat alanımız tam olarak bu kesişim: hiper-casual geçiş disiplini + match-3 dramaturjisi.

---

## 3. En İyi 3 Kazanma Sekansı (ms zaman çizelgesi)

### 3.1 Candy Crush — Sugar Crush ("kalan hamlen = havai fişekin") — şablon dramaturjisi
Sahne içi; harici overlay yok, tahta kendi sahnesidir. Wiki-teyitli mekanik (OBSERVED), ms INFERRED.

| T+ | Ne olur | Neden işler |
|---|---|---|
| 0 ms | Son hedef tamamlanır; tahta hafif karartılır, kontrol kilitlenir; **"Sugar Crush!"** bandı + jingle (~200 ms'de yerleşir) | An beklenebilir bir gösteriye tahsis edilir; kimse "bitti mi?" diye şüphelenmez |
| 200–800 ms | Kalan her hamle rastgele bir **şeritli şekere** dönüşür (hamle başına ~150 ms aralıklı; hamle başına +6.000 puan) | Oyuncunun artığı çarpımla ödüllendirilir → "kazanırken daha çok kazanırım" |
| 800 ms – 5 sn | Dönüşen şekerler **SIRAYLA** patlar (her patlama 80–120 ms), kalan özel şekerler de tetiklenir; jöle türlerinde balık ordusu yüzer | Kaskadın uzunluğu = o tura özgü; hiçbir iki Sugar Crush aynı değildir |
| kaskad sonu | Yıldızlar skor eşiğine göre pop + jingle; 3. yıldız büyük burst | Performans geri bildirimi şölenin DORUĞUNDA gelir |
| +1–2 sn | Skor count-up → bölüm haritası | Count-up sessiz (zayıf nokta) |

**Ders:** ödül sabiti kaldır; kazanma anını oyuncunun o turdaki artığından türet.

### 3.2 Royal Match — Win + Butler's Gift ("ödül uçar, gelecek verilir")
Sahne içi kutlama + kısa win kartı. Funovus/Fandom/DoF kaynaklı (OBSERVED mekanik, ms INFERRED).

| T+ | Ne olur | Neden işler |
|---|---|---|
| 0 ms | Son eşleşme → tahta merkezinden **coin patlaması** (partikül + halka) + jingle; Kral sahnede sevinir | E1 dolu: tek karede görsel+ses |
| ~400 ms | **Coin'ler cüzdan ikonuna FİZİKSEL uçuş** (~600 ms), varışta sayı pop'u | Yasa 3: ödül uçuşu; UI metnini gereksiz kılar |
| ~1.000 ms | Kutlama bandı; alan ilerlemesi rozetleri hafif parlar | Meta ilerlemesi kazancın İÇİNDE hatırlatılır |
| ~1.500 ms | **Butler's Gift:** bir SONRAKİ bölüm başında kullanılacak ücretsiz booster(lar) sunulur; seri arttıkça içeriği büyür | Yasa 4: doruk anı gelecek oturumun sözüne döner; streak kaybı korkusu üretilir |
| ~2.200 ms | Tek tık → sonraki bölüm | Zorluk yükselecekse bile giriş sürtünmesi yok |

**Ders:** kazanç ekranı bir dağıtım faturası değil, bir VAAT ekranıdır.

### 3.3 Stack Ball — Fire Finale ("hak edilmiş gösteri + sıfır sürtünme")
Sahne içi; hyper-casual geçiş disiplininin şahidi (INFERRED, gameplay kayıtları).

| T+ | Ne olur | Neden işler |
|---|---|---|
| −2 s | Ateş modu: top kırmızı/alevli, tüm katmanlar (siyah dahil) kırılır; ses yükselir | Birikim: final HAK EDİLMİŞ hissi |
| 0 ms | Son katman+zemin **buldozer gibi ezilir**: kamera sarsıntısı + beyaz flaş | Klimaks tek karede |
| ~300 ms | Tam ekran konfeti + havai fişek, "PERFECT!" | Şölen tekrar çalışır — ama bu kez birikimden |
| ~800 ms | Yeni bölüm yüklendi; oyuncu zaten oynuyor | E5=10: şölen akışı KESMEZ |

**Ders:** şölen ile restart çelişmez; şölenin içinden bir sonraki oyuna geçilir.

**Onur kutusu:** Block Blast (rekor finalinde ateş artışı + ekran şenliği), Subway Surfers (mystery box'ın 100K jackpot şansı — E6 zirvesi), Spiral Roll (birikimin final klimaksı).

---

## 4. En İyi 3 Kayıp / Konsolasyon Sekansı

### 4.1 Block Blast — İkinci Şans + Adaptif Merhamet (reklamsız çevirisi bize ait)
- **T+0:** tahta dolmuştur; bloklar ~300 ms'de sönerek kararır — ölüm sahne içinde, hak edilmiş ve okunur.
- **T+~400 ms:** ikinci şans kartı (orijinalde reklam; bizim karşılığı: **ücretsiz kurtarma/comeback bonusu**). Retention'ın en güçlü noktası: cömertlik duygusal zirvede verilir.
- Adaptif zorluk parça dağıtımını oyuncunun durumuna göre yumuşatır; kayıp sonrası yeni tahta cömerttir — "haksız bitiş" algısı yok.
- Tekrar ≤1 sn. **Bizim NEREDEYSE ekranı + TEKRAR-birincil (PB-035 A7) doğru yöndedir; üstüne 2. ardışık kayıpta "BU TUR ×2 PARA" rozeti eklenmeli.**

### 4.2 Royal Match — "Neredeyse" Hisli Kayıp + Kral Aynası
- Kayıptan hemen önce Kral karakteri **sinirlenir** — sahne içi duygusal ayna; oyuncu "yaklaştım" hissini metinden değil karakterden okur.
- Kayıp ekranı hedefe kalan mesafeyi gösterir (öge sayısı) → NEREDEYSE algısı; coin ile "+5 hamle devam" kapısı vardır (monetize ama mesafe gösterimi sağlıklıdır).
- Kayıp serisinde booster cömertliği artar; DoF'un önerdiği **Streak Freeze** (Duolingo modeli) fikri — **bizim streakShield (PB-034) tam olarak budur; görünür kılınmalı.**
- Kısa bölüm uzunluğu + cömert booster = kayıplar bile "bir tur daha" hissi üretir.

### 4.3 Candy Crush — Fail-Forward (dersi alın, faturası alınmasın)
- Kayıp ekranı hedefe kalan jöle/öge sayısıyla **yakınlığı gösterir**; art arda kayıplarda "+10, +15 hamle" artan teklifler (+105'e kadar gözlemlenmiş) — kayıp aversion + sunk cost düzeneği.
- Canlar zamanla dolar → kayıp, bekleme kancasına dönüştürülür.
- **ELEŞTİRİ:** bu yol karanlık desendir (dinamik fiyat, 1000+ deneme hikâyeleri). Alınacak olan SADECE "yakınlık gösterimi + affedici sonraki tur"dir; para karşılığı hamle satışı değil. Bizde karşılığı zaten çevrimdışı-cömert: kabus kulesi kaybı = 40 para + kalıntı (PB-035 B3).

---

## 5. Eleştiri: Ortak Zayıflıklar ve Aşılabilir Noktalar

1. **Ölü tahta / statik overlay:** Şölen sahnenin içinde yaşanır, ödül ekranı açılır açılmaz dünya ölür (CC, RM, Toon). → **Aşım:** overlay'in ARKASINDA sahne yaşamaya devam etsin (bizde _CelebrationBackdrop var; bir adım öteye: sahne içi coin uçuşu overlay'e devredilsin).
2. **Her kazanç aynı şablon:** 3 yıldız + para + butonlar, bölüm farkı yoktur. → **Aşım:** finaleFor imza rotasyonu (BİZDE VAR) + gün tohumlu sürpriz rozeti (%20 ×2 para / ekstra kutu) — sürprizi sandıktan SUNUMUN kendisine taşıyan ilk oyun olabiliriz.
3. **Sessiz count-up:** endüstride kural; sayı artar, hiçbir şey söylemez. → **Aşım:** CountUpText + pitch merdiveni (her ~4 tikte pop, perde artar, bitişte chime). Stack'in pitch merdivenini meta katmanına taşıyan ilk oyun. 27-ses üreteci bunu paketsiz yapar.
4. **Kayıp ya boş ya fatura:** Stack'te boş skor, CC'de satış teklifi. → **Aşım:** üçüncü yol: yakınlık (%N barı) + cömertlik (comeback ×2 para) + anında tekrar — reklamsız, kandırmayan.
5. **Dramaturji tersten:** kazanç zincirlerinde (kutu→tahta→sonuç) temel ödül ekranı en SONDA gelir; doruk, oyuncu yorgunken tüketilir. CC/RM şöleni İLK saniyede yaşatır. → **Aşım: result-first sırası** — sonuç (yıldız+count-up) T+950'de, meta şölenleri (inşaat→kutu→dünya) sonra YÜKLENEN ölçekte. Zincir kuralları `game_session` sunum katmanındadır; C-002/C-017 dokunulmaz.
6. **Uçuş yok:** ödüller hep metinle verilir ("+120"). → **Aşım:** coin partikülü skor HUD'ına uçsun (Royal Match dersi; painter'da tek emitter).

---

## 6. Stack Tower Game — Kazanç/Kayıp Sekans ŞABLONU

### 6.0 Mevcut envanter (şablonun üzerine kurulacağı zemin)
| Bileşen | Değer | Yer |
|---|---|---|
| Kazanç bekleme | endTimer 0.95 s | gameplay.dart |
| Kayıp bekleme | 0.55 s / 0.35 s | gameplay.dart |
| Hit-stop | 40 ms + 4 ms×kombo (tavan 70 ms) | gameplay.dart:560 |
| Flaş | mükemmel α0.18 tema / kritik α0.35 beyaz, 90 ms | gameplay.dart |
| Zoom | genişleme 0.92 (8+ blok), kazanınca fit; lerp dt×2.5 | gameplay.dart:829 |
| Finale | finaleFor(i) 4 stil: konfeti 120 / meteor 50 / kuş 60 / aurora 40 | gameplay.dart:646 |
| Yıldız | _AnimatedStar: elasticOut 380 ms, iniş 370/590/810 ms + haptic | flow_overlays.dart:454 |
| Sayı | CountUpText: 460 ms easeOutCubic (sessiz) | premium_kit.dart:419 |
| Kayıp ekranı | NEREDEYSE! + "Rekoruna N blok kaldı" + TEKRAR birincil (A7) | flow_overlays.dart:408 |
| Zincir | construction → box → world → board → result → showMap | game_session.dart:228 |
| Ses | win/lose/fanfare/coin/box/mystery/reward/crit/pop/whoosh | audio.dart |
| Arka plan | _CelebrationBackdrop: 42 konfeti + 3 ışık halkası, 4 s döngü | flow_overlays.dart:617 |

### 6.1 KAZANÇ SEKANSI (ms)
```
T+0      son blok oturur → MEVCUT hit-stop(70) + beyaz flaş(0.35, 90ms)
         + YENİ: kazanç donması 120ms (hit-stop'tan ayrı, InputGate açık kalsın)
         + YENİ: zoom-fit lerp hızını dt×3.5 → kadraj ~400ms'de oturur
T+120    fanfare + win + HAPTIC ÇİFT nabız (30/90 ms; mevcut tek nabzın yerine)
T+120-900 finaleFor stili sahnesi (MEVCUT) + konfeti ×1.5 yoğunluk
         + YENİ: kule tabanından yukarı ışık süpürmesi (tek gradient bandı, 500 ms)
T+300    YENİ: kombo/kritik parası coin partikülü olarak skor HUD'ına uçar
         (~400 ms, varışta coin sesi; onWin'de ödenen twistCoins'ün görseli)
T+950    endTimer dolusu (MEVCUT) → RESULT EKRANI İLK (YENİ SIRA):
         başlık pop → yıldızlar 370/590/810 ms + haptic (MEVCUT)
         → CountUpText + YENİ pitch merdiveni (her ~4 tik pop, perde artar, bitişte chime)
         → YENİ sürpriz rozeti: gün tohumlu %20 (×2 PARA / EKSTRA KUTU) — E6
T+1600+  meta şölenleri YÜKLENEN ölçekte: construction → box → world → board (MEVCUT adımlar)
         her adım tek tık; zincir toplamı ≤4 tık; arkada celebration backdrop yaşıyor (MEVCUT)
```
Zincir sırası değişikliği `game_session.dart` _chain kurulumunda sunum kararıdır; ödül hesaplaması (C-002) değişmez.

### 6.2 KAYIP SEKANSI (ms)
```
T+0      kule kıyameti → YENİ kayıp donması 150 ms (kazançtan uzun: ölüm anı dramatik)
         + AMBER çatlama flaş α0.25 (120 ms; kırmızı değil — affedicilik) + shake 20 (MEVCUT büyük kademe)
T+150    blok savrulması fizikle (MEVCUT) + YENİ sahne %35 karartma (600 ms, "perde iniyor")
T+350    lose sesi + YENİ minör-akor varyantı (zafer jingle'ının minör hali — imza)
T+550    endTimer (MEVCUT 0.55) → NEREDEYSE! ekranı (MEVCUT)
         + rekor farkı (MEVCUT) + YENİ: hedefe %N ilerleme barı (Candy Crush yakınlık dersi)
         + YENİ comeback rozeti: 2. ardışık kayıpta TEKRAR üstünde "BU TUR ×2 PARA"
           (Block Blast ikinci şansın reklamsız çevirisi; C-019 cömertlik — kayıpta PARA ödemez, ÇARPIM verir)
T+?      TEKRAR dokunuş → yeni oyun ≤1 sn (ölçülebilir kabul kriteri)
```
Kabus Kulesi kaybı mevcut haliyle kalır (kayıp=kazanç, 40 para + kalıntı, B3).

### 6.3 Eklenecek efekt listesi (mevcutların ÜSTÜNE)
| # | Efekt | Model | Nerede |
|---|---|---|---|
| X1 | Kazanç donması 120 ms + zoom-fit hızlanması | Stack Ball klimaks | gameplay.dart endTimer bloğu |
| X2 | Kule ışık süpürmesi (tabandan yukarı band, 500 ms) | Royal Match sahne kutlaması | scene_painter finale katmanı |
| X3 | Coin uçuşu (sahne→HUD, ~400 ms + varış sesi) | Royal Match uçuş yasası | play_screen overlay + painter emitter |
| X4 | Pitch-merdivenli count-up (pop per ~4 tik + bitiş chime) | Stack sahne merdiveninin meta'ya taşıması | premium_kit CountUpText veya result ekranı |
| X5 | Sürpriz rozeti (gün tohumlu %20: ×2 para / ekstra kutu) | Subway mystery dozu | game_session onWin + result UI |
| X6 | Kayıp donması 150 ms + amber çatlak flaş + sahne karartması | Block Blast ölüm sunumu | gameplay + scene_painter |
| X7 | Hedefe %N barı (NEREDEYSE ekranında) | Candy Crush yakınlık gösterimi | flow_overlays result |
| X8 | Comeback ×2 para rozeti (2. ardışık kayıpta) | Block Blast ikinci şans (reklamsız) | game_session onLose + result UI |
| X9 | Result-first zincir sırası | CC/RM "şölen önce" | game_session _chain |
| X10 | Çift haptic nabız (30/90) + minör-akor lose sesi | Toon Blast haptik yoğunluğu | play_screen + gen_sounds |
Tümü AmbientMotion kapısına bağlı; pop/chime/süpürme sesleri tools/gen_sounds.dart'a 3-4 varlık.

---

## 7. Kabul Kriterleri Checklist

1. **İlk 1 saniye:** kazanmada T+100 ms içinde donma+flaş+fanfare+haptic aynı pencerede tetiklenir; result overlay T+950 ms'ten önce gelmez (sahne şöleni yaşanır). Kayıpta T+150 ms donma + amber flaş, T+550 ms'te NEREDEYSE + %N barı + rekor farkı görünür.
2. **Dramaturji sırası:** result ekranı başlık→yıldız (370/590/810 ms + haptic)→sesli count-up→sürpriz rozeti sırasıyla açılır; dokunmadan ≤3.5 sn, her adımda tıkla-geç çalışır.
3. **Zincir:** result-first (sonuç→inşaat→kutu→dünya→tahta), her adım tek tık, toplam ≤4 tık; ödül matematiği birebir korunur (C-002 diff boş — test kanıtı).
4. **Kayıp affi:** TEKRAR birincil buton; dokunuştan yeni oyun başlangıcı ≤1 sn; 2. ardışık kayıpta ×2 para rozeti sunulur ve ancak kazanırsa ödenir.
5. **Sürpriz + test:** sürpriz rozeti gün tohumlu deterministik (test edilebilir); finaleFor ardışık çakışmaz; tüm yeni animasyonlar AmbientMotion kapalıyken tek karede doğrulanır; widget/snapshot testleri güncellenir.

---

## 8. Kaynaklar

- Sugar Crush mekanik: [Candy Crush Wiki — Sugar Crush](https://candycrush.fandom.com/wiki/Sugar_Crush), [Level](https://candycrush.fandom.com/wiki/Level), [CC Friends Wiki](https://candycrushfriends.fandom.com/wiki/Sugar_Crush)
- Candy Crush fail teklifleri: [r/candycrush +105 moves](https://www.reddit.com/r/candycrush/comments/1555k4s/105_extra_moves_for_10_gold_bars_candy_crush), [extra move counter](https://www.reddit.com/r/candycrush/comments/1ae5gyx/how_far_can_you_push_the_gold_bar_extra_move)
- Royal Match: [Funovus — What Designers Can Learn](https://www.funovus.com/blogs/royal-match-dominates-match-3-what-can-all-designers-learn), [Butler's Gift — RM Wiki](https://royalmatch.fandom.com/wiki/Butler%27s_Gift), [Naavik — Success Through Iteration](https://naavik.co/digest/royal-match-finding-success-through-iteration)
- Win streak / cömertlik: [Deconstructor of Fun — Win Streak](https://www.deconstructoroffun.com/blog/2024/8/5/win-streak-the-gift-that-keeps-on-giving)
- Block Blast: [Baron Media — Why Is Block Blast So Addicting](https://baronmedianetwork.com/2025/03/17/why-is-block-blast-so-addicting)
- Subway Surfers sandıklar: [Subway Wiki — Mystery Box](https://subwaysurf.fandom.com/wiki/Mystery_Box), [SYBO Help — Jackpot](https://sybo.helpshift.com/hc/en/5-subway-surfers/faq/204-mystery-boxes-jackpot/?p=web)
- Playrix yıldız ekonomisi: [Gardenscapes Help — Stars](https://playrix.helpshift.com/hc/en/5-gardenscapes/faq/61-what-are-stars), [Homescapes Wiki — Levels](https://homescapes.fandom.com/wiki/Levels)
- Toon Blast ödülleri: [Peak Help — Toon Pass](https://peakgames.helpshift.com/hc/en/4-toon-blast/faq/322-what-is-toon-pass), [Toon Blast — Google Play](https://play.google.com/store/apps/details?id=net.peakgames.toonblast)
- Beatstar: [Deconstructor of Fun — Beatstar](https://www.deconstructoroffun.com/blog/2021/9/12/beatstar)
- Juice/dopamin literatürü: [Juice it or lose it (Jonasson & Purho, 2012)](https://www.youtube.com/watch?v=Fy0aCDmgnxg), [Socratopia — Game feel](https://www.socratopia.app), [akdarrah — Juice It](https://akdarrah.com/posts/juice-it), [Screenwise — Psychology Behind Game Design](https://screenwiseapp.com/guides/the-psychology-behind-game-design), [Prototypr — Feeding an Addiction?](https://blog.prototypr.io/are-your-designs-adding-value-or-are-you-feeding-an-addiction-6ad0267aeaf0)
- GameRefinery canlı-op ödül tasarımı: [Rewarded Ads — Double Level Up Reward](https://www.gamerefinery.com/how-to-build-better-mechanics-for-rewarded-in-game-ads), [1v1 Events — Casual Puzzle](https://www.gamerefinery.com/event-spotlight-how-mobile-game-developers-can-boost-engagement-in-the-casual-puzzle-genre-with-competitive-1v1-events)
- Stack analizi: kardeş rapor RESEARCH-dna-2026-11.md + [cematayakut — Game feel](https://www.cematayakut.com/en/lab/game-feel)
