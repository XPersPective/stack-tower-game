# STACK TOWER GAME — PAZAR ARAŞTIRMASI VE TASARIM RAPORU

Tarih: 2026-10-25 · Tetikleyici: kullanıcı geri bildirimi ("oyun tekdüze olmuş, sürprizi yok,
ilk bölümler harika olmalı, pazar yeri olsun, harita gizemli olsun, efektler mükemmel olsun")
Durum: Project Brain'e entegre edildi (ADR-006/007 + PB-015..PB-020). Bu rapor tasarım
kararlarının gerekçesidir; uygulama sırası §6'da.

---

## 1. Yönetici Özeti

Mevcut oyun sağlam bir çekirdek döngüye sahip (tek dokunuş + kırpma matematiği) ama
**tek bir oyun türü** olarak kurulu: her bölüm aynı "yukarıdan inen blok" deneyiminin
zorluk-farklı varyantları. Pazar verisi bunun türün en büyük kırılma noktası olduğunu
doğruluyor: hiper-casual oyunlar **ilk iki oturuşmada** oyuncunun büyük çoğunluğunu
kaybeder ve çözüm sektörde "hybrid-casual" adıyla kurumsallaştı — çekirdek döngü
basit kalır, üzerine **çeşitlilik + sürpriz + meta katman + cömert ekonomi** eklenir.

Bu raporun sonucunda 6 çalışma alanı tanımlandı: (1) Sürpriz motoru ve çeşitlilik,
(2) İlk-5 bölüm deneyimi, (3) Efekt/ses mükemmelliği ("juice"), (4) Pazar yeri +
cömert ödüllendirme, (5) Haritada gizem katmanı, (6) Canlı skor tahtası.

## 2. Neden Oyuncu Sıkılır — Teşhis

| Bulgular (pazar) | Bizim oyundaki karşılığı |
|---|---|
| Erken churn'in #1 sebebi **tekdüze zorluk artışı**; oyuncu 2-3. bölümde "hepsi aynı" hissederse terk eder (GameAnalytics) | 150 bölüm aynı hareket+bırakma döngüsü; değişen yalnız hız/tolerans |
| Oyuncu mekaniği **3 saniyede** anlamalı, "aha" anı ilk oturuşmada yaşanmalı (Innovecs, CrazyLabs) | "Aha" anı var (mükemmel kırpma) ama tekrarları şaşırtmıyor |
| Belirsizlik + beklenti = dopamin; **ödülün beklentisi ödülün kendisinden fazla** dopamin üretir (Appcues, Dodefy) | Ödüller deterministik formülle geliyor; sürpriz havuzu (~%25) çok seyrek ve sönük |
| Tek-düğme oyunlarında monotonluk **kısıtları değiştirerek** kırılır; mekaniği değil hedefi/blokçuyu döndür (Gamedev SE) | Modifier'lar yalnız sayısal (hız/karanlık/deprem); yeni OYUN DURUMU eklenmemiş |
| Juice eksikliği "ucuz" hissi yaratır; screen shake + hit-stop + squash&stretch + haptic standart (BloodMoon, Feel) | Shake/particle var ama hit-stop, squash&stretch, renk flaşı, kombo müziği yok |

## 3. Araştırma Bulguları

### 3.1 İlk oturuşma ve ilk bölümler
- Mekanik **ilk bölümde öğretilir**, zorluk 2-3. bölümden sonra rampa yapar; ilk
  deneyim "kolay galibiyet + tatmin edici geri bildirim" olmalı (GameAnalytics,
  CrazyLabs).
- Onboarding overlay ile değil, **oynayarak** verilir (Medium/UX).
- D1 tutunma için: kısa oturuşma hedefleri, günlük dönüş sebepleri, zamanlı ilk
  ilerleme olayları (AppFollow, r/gamedev).

### 3.2 Değişken ödül psikolojisi
- **Değişken oran (variable-ratio) ödül** doğrudan engagement/tutunmayı artırır
  (2025 akademik çalışma; Guul).
- Anticipation (bekleme/gizem) ödülün kendisinden daha güçlü; bu yüzden **açılış
  animasyonlu sandıklar, "ne çıkacak?" göstergeleri ve gizemli önizlemeler** işler
  (Appcues).
- Etik çizgi: gerçek para/gacha YOK — oyun içi kazanımla çalışan sürprizler.

### 3.3 Tek-düğme türünde çeşitlilik sözlüğü (Ballz, Dunk Shot, Stack)
- Stack (Ketchapp) viral olmasının sebebi: tek girdi + anında geri bildirim + **görünür
  ustalık** + minimal-estetik. Ama Stack'in kendi yeniden çıkışında "yeni modlar"
  eklendi — tek mod yeterli değil.
- Çeşitlilik kalıpları: **hedef değişimi**, **kısıt değişimi**, **engel/güçleyici
  girişi**, **streak/ateş durumları**, **hareketli hedefler**, **günlük rastgele
  modifier'lar** (Miniclip günlük görev çantaları).
- Kural: her seviyede **tek bir yeni twist**; çekirdek kimlik bozulmaz.

### 3.4 Hybrid-casual meta katmanları
- Sektör formülü: **hook → session → meta → ekonomi** sıralamasıyla katmanla
  (GameGrowthAdvisor 2026).
- 7 meta türü: anlatı, dekorasyon, kişiselleştirme, yükseltme, koleksiyon… (Adjust).
- Ekonomi katmanı: mağaza/premium para/planlı satın alma alanları (MondayOFF) —
  bizde gerçek para yok, ama **pazar yeri hissi** (rotasyon, indirim, gizli ürün)
  aynı psikolojiyi ücretsiz ekonomiyle verir.
- LiveOps: günlük etkinlikler + sezonluk görevler D7-D30 tutunmayı taşıyan
  yapılar (GameAnalytics).

### 3.5 Juice / oyun hissi
- Standart paket: **hit-stop** (mükemmelde mikro duraklama), **squash & stretch**
  (blok yerleşirken), **screen shake** (ölçekli), **partikül patlamaları**, **renk
  flaşı/chromatic aberration**, **haptic desenleri** (BloodMoon, Unity Feel, eGmatic).
- Kritik: juice **çekirdek eylemi** ödüllendirmeli; her efekt anlamlı bir olaya
  bağlanmalı (GameAnalytics).

### 3.6 Görsel trendler (2025-2026)
- Neon gradyan + yüksek kontrast + koyu zemin: premium/genç odaklı eğilim (Figma
  trends). İridesan/metalik gradyanlar düz minimalizmin yerini alıyor (Envato).
- Mevcut neon temamız doğru çizgide; eksik olan **iridesan vurgular, gradyan
  animasyonları ve derinlik (paralaks katman artışı)**.

### 3.7 Haritada gizem
- Fog-of-war kalıbı: keşfedilmeyen **sisle kaplı**, siluetler/ipuçları görünür;
  keşif kalıcı açar (FOG/Fog of World uygulamaları; roguelike tasarım notları).
- Merak boşluğu (curiosity gap): "sıradaki dünyada NE var?" sorusu görsel ipucuyla
  beslenmeli — tam gösterme, parça göster.

## 4. STACK TOWER GAME İÇİN TASARIM KARARLARI

### D1 — Sürpriz Motoru (ADR-006)
Modifier havuzu 9'dan **17'ye** çıkar. Yeni oyun-durumu twist'leri (tümü çekirdek
döngüde tek girdiyle çalışır):
1. **ZİT AKIŞ** — bloklar sağdan-soldan değil dönüşümlü iki yönden gelir, yön her
   mükemmelde değişir.
2. **ÇİFT KULE** — iki kulenin arasında gidip gelirsin, hangisine bırakacağını seçersin
   (iki ayrı kule, hedef toplam).
3. **RÜZGAR GÜLÜ** — blok döner açıyla gelir; bırakınca açı toparlanır (±15°).
4. **DAR GEÇİT** — kulenin iki yanından duvarlar daralır; geçit boyutu hedeftir.
5. **ALTIN YAĞMURU** — bölüm boyunca rastgele altın bloklar; onları bırakınca para
   patlaması.
6. **GÖLGE BLOK** — gerçek bloğun hayalet ikizi farklı hızda dolaşır; hangisi
   bıraktığına karar verirsin.
7. **SIÇRAYAN** — bırakılan blok bir kez zıplar, en yakın hizaya oturur (mükemmel
   vermez ama affedicidir).
8. **KRİTİK** — her mükemmelde %20 ihtimalle ×5 kritik para + büyük patlama.

Dağıtım kuralı (monotonluğu matematiksel kırar): **her 3 bölümden biri** yeni-tür
olur; ardışık aynı tür 2'yi geçmez; ilk 5 bölümde 5 FARKLI tür garantisi (hard-coded
şema: 1 KLASİK öğretir → 2 ALTIN YAĞMURU sürpriz → 3 RÜZGAR GÜLÜ → 4 ZİT AKIŞ →
5 KRİTİK patron). Mevcut 9 modifier dağılımı korunur (SPEC §2.4 sadakati).

### D2 — İlk-5 bölüm deneyim pass'i
- Bölüm 1: serbest galibiyet, bol hit-stop ile "mükemmel" hissi öğretilir; %100
  başarıya ayarlı (tol 12px ilk 5 blok).
- Her bölüm sonunda **mini-sürpriz kapısı**: " Bir şey buldun!" → rastgele küçük ödül
  (para/görünüm parçası/kalıntı parçası) — variable-ratio.
- İlk gün hedefi: 3 bölümden sonra pazar yeri keşfi tetiklenir (tutorial-yok, olayla).

### D3 — Juice paketi (efekt/ses mükemmelliği)
- Hit-stop: mükemmelle 40-70ms duraklama (komboda artar).
- Squash & stretch: blok yerleşirken %12 squash, 120ms.
- Renk flaşı: mükemmelle arka plana tema-glow flaşı; kritikte beyaz flaş.
- Kombo ses/efekt merdiveni: ×3'ten itibaren ritim katmanı girer, ×6 arpej, ×10'te
  tema müziği açılır (ADR-003 üretim hattına katman ekleme).
- Haptic desenleri: mükemmel=tik(10ms), kritik=çift vuruş, çökme=uzun(60ms).
- Partikül cömertliği: mükemmelle konfeti patlaması + halka + yıldız izi.

### D4 — Pazar yeri + cömert ekonomi (ADR-007)
- Haritada her dünyanın adasında **PAZAR yeri binası** (3. tamamlanmış bölümden
  sonra açılır): her gün 3 rotasyonlu ürün (görünüm/kalkan/altın çarpanı/joker) +
  1 gizli ürün (fiyat görünmez, "gizemli sandık").
- Para kazanma alanları genişler: kritik mükemmel, kombo şenlikleri (×5'te para
  yağmuru), günlük görevlere bonus tur, "mükemmel serisi" mağaza kuponu.
- Fiyat erişimi: her 4-5 bölümde 1 satın alma gücü (cömertlik ilkesi).

### D5 — Haritada gizem katmanı
- Kilitli dünyalar **sisle kaplı**: silueti seçilir, adı gizemli ("??? · buz gibi
  bir yer"), dünyaya özgü ipucu cümlesi (WORLD_TEASER zaten var — haritaya taşınır).
- Kilitli dünya düğümü hafif animasyonlu (nefes alan sis + yıldız parıltısı) — az
  ama merak uyandıran.
- Gezegen adalarında dönen uydu/kuş/parıltı mikro-animasyonları (düşük maliyetli,
  puanı yüksek).

### D6 — Canlı tahta + ödüllendirme
- Günlük tahta kişisel rekor yayı gösterir (bu hafta geçen rakipler).
- Sezonluk rozetler (7 gün üst üste günlük tamamla).

## 5. ETİK VE KISITLAR
- Gerçek para/GK&G yok; tüm sürprizler oynanışla kazanılır (C-010 ile uyumlu).
- Reklam/analitik yok kuralı korunur.
- Çekirdek matematik (resolveDrop/denge) bozulmaz; twist'ler üst katmanda
  speedScale/spawn yönü/blok çarpanı olarak eklenir (C-002 sadakati korunur).

## 6. UYGULAMA YOL HARİTASI (görev eşlemesi)
| Görev | Kapsam | Öncelik |
|---|---|---|
| PB-015 | Sürpriz motoru: 8 yeni twist + garantili ilk-5 şeması + dağıtım kuralları + testler | P1 |
| PB-016 | Juice paketi: hit-stop, squash&stretch, flaş, haptic desenleri, partikül cömertliği | P1 |
| PB-017 | Ses katmanları: kombo merdiveni, kritik/kutu/serbest sesleri, müzik yoğunlaşması | P1 |
| PB-018 | Pazar yeri: harita binası + rotasyon + gizli sandık + ekonomi testleri | P1 |
| PB-019 | Harita gizem katmanı: sis + ipucu + mikro-animasyonlar | P2 |
| PB-020 | Tahta canlılığı: rekor yayı + sezonluk rozetler + bonus tur | P2 |
| PB-021 | İlk-5 deneyim pass'i + mini-sürpriz kapısı + pazar keşfi tetikleyicisi | P1 |

## 7. KAYNAKLAR
- [GameAnalytics — 5 Common Hyper-Casual Mistakes](https://www.gameanalytics.com/blog/hyper-casual-game-common-mistakes)
- [CrazyLabs — 5 Tips for Improving Retention](https://www.crazylabs.com/blog/5-tips-for-improving-retention-in-hybrid-casual-games)
- [Innovecs — Hyper-Casual Games Guide](https://www.innovecsgames.com/blog/hyper-casual-games)
- [AppSamurai — Hybrid-Casual UA Playbook](https://appsamurai.com/blog/hybrid-casual-games-ua-playbook-how-to-acquire-and-retain-users)
- [AppFollow — Mobile Game Retention](https://appfollow.io/blog/mobile-game-retention)
- [Appcues — Variable Rewards](https://www.appcues.com/blog/variable-rewards)
- [Dodefy — Psychology of Reward Systems](https://www.dodefy.com/articles-posts/the-psychology-of-reward-systems-why-games-keep-us-hooked)
- [Guul — Psychology of Repeat Play](https://guul.games/blog/why-we-play-again-and-again-the-psychology-of-repeat-gaming)
- [2025 Dopamine Loops akademik çalışma (JCM)](https://jcoma.com/index.php/JCM/article/download/352/192)
- [Medium — Hyper-casual design (Stack örneği)](https://ch1rag.medium.com/admiring-the-game-design-in-hyper-casuals-f39839e15dc7)
- [Game-Ace — Hyper-casual mechanics](https://game-ace.com/blog/hyper-casual-game-mechanics)
- [148Apps — Stack guide](https://www.148apps.com/stack/stack-guide-how-to-build-a-great-tower)
- [Google Play — Stack](https://play.google.com/store/apps/details?id=com.ketchapp.stack)
- [GameGrowthAdvisor — Hybrid Casual 2026 tasarım/ekonomi](https://gamegrowthadvisor.com/blog/2026-04-16-hybrid-casual-game-design-strategy-2026)
- [Adjust — 7 meta layer türleri](https://www.adjust.com/blog/5-profit-driving-benefits-of-hybrid-casual-games)
- [MondayOFF — Hybrid-casual ekonomi](https://www.mondayoff.me/How-ToHC/14)
- [GameAnalytics — Hybrid-casual retention](https://www.gameanalytics.com/blog/hybrid-casual-higher-retention-better-engagement)
- [Lancaric — 2025 Hybridcasual Market](https://lancaric.substack.com/p/2025-hybridcasual-market-overview)
- [BloodMoon — Juice in Game Design](https://www.bloodmooninteractive.com/articles/juice.html)
- [eGmatic — Game Feel](https://egmatic.com/blog/how-to-make-your-game-feel-good)
- [GameAnalytics — Juice](https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design)
- [Feel — Screen Shakes](https://feel-docs.moremountains.com/screen-shakes.html)
- [Figma — Design Trends](https://www.figma.com/resource-library/web-design-trends)
- [Envato — Color Trends](https://elements.envato.com/learn/color-trends)
- [Game Developer — One Button Games](https://www.gamedeveloper.com/design/one-button-games)
- [Gamedev SE — Single-mechanic level design](https://gamedev.stackexchange.com/questions/110729/)
- [Miniclip — Daily Challenges](https://support.miniclip.com/hc/en-us/articles/360017511897-What-are-the-daily-challenges-in-Basketball-Stars)
- [Gamedev SE — Monotony kırma](https://www.reddit.com/r/gamedev/comments/vqm19o/to_both_game_designers_and_devs_how_do_you_break)
- [Fog of World](https://fogofworld.app/en) · [FOG app](https://play.google.com/store/apps/details?id=com.marenhq.fog&hl=en_US)
- [Grid Sage — Fog of War tasarımı](https://www.gridsagegames.com/blog/2013/11/fog-war)
