# RESEARCH: HUD ve Buton DNA Raporu — Mobil Oyun HUD Anatomisi (2026-11)

- **Tarih:** 2026-11-02
- **Kapsam:** 28 oyun/örnek (hyper-casual stacking + top-grossing casual puzzle + aksiyon/roguelike + referans minimal tasarımlar), B1-B7 kriter puanlaması
- **Yöntem:** Web araması + Game UI Database / Interface In Game ekran görüntü arşivleri + Behance/Pinterest UI galerileri + sektörel dekonstrüksiyon makaleleri (Deconstructor of Fun, Funovus, UX Collective) + YouTube HUD breakdown'ları (Game Maker's Toolkit)
- **Tetikleyici:** Kullanıcı şikâyeti — "oyun içi HUD dikdörtgen dikdörtgen çirkin, yukarıdan aşağıya dikdörtgen şeyler yapmışsın; buton araştır; göstergeler (puan) çok basit; KABUS butonu küçük ve yazısı kayıyor"
- **İlgili kısıtlar:** C-001 (kalite tabanı), C-010 (tek dokunuş), C-012 (3 sn okunabilirlik), C-015/C-016 (premium kalite), C-018 (çevrimdışı). Tüm öneriler sunum katmanı — çekirdek matematiğe (C-002) dokunmaz.
- **Mevcut kod referansları:** `lib/screens/play_screen.dart` (satır 345-620: HUD, _hudButton, _HudProgress, _HudCombo, _HudShields), `lib/screens/map_screen.dart` (satır 406-436: _NightmareGate / KABUS), `lib/ui/premium_kit.dart` (GradientButton), `lib/theme/tokens.dart` (NeonPalette, AppSpace, AppRadius)

---

## 1. Yönetici Özeti: 10 HUD Yasası

28 örnekte tekrar eden, Stack Tower HUD yenilemesinin omurgası olacak yasalar:

| # | Yasa | Kanıt oyunlar |
|---|------|---------------|
| H1 | **Tek bant kuralı:** Oyun içi bilgi TEK yatay bantta toplanır; altına ikinci-üçüncü dikdörtgen bant dizilmez. İkinci satır gerekiyorsa aynı kapsülün içine gömülür. | Subway Surfers, Clash Royale, Royal Match, Block Blast! |
| H2 | **0.3 sn kuralı:** Skor + hedef + can/hak tek bakışta okunur; yüksek kontrast (beyaz metin + koyu yarı saydam zemin + kontur/glow) bunu mümkün kılar. | Candy Crush (skor/hamle), Stack (skor), Subway Surfers (para) |
| H3 | **Skor bir yıldızdır, etiket değil:** Ana gösterge en az 28-32px, w800+, renk/glow/gradyan taşır; sayı değişince pop+CountUp yapar. Skor HUD'un görsel merkezidir. | Stack, Candy Crush, Block Blast!, Royal Match |
| H4 | **Dikdörtgen değil kapsül/daire:** Oyun içi HUD öğeleri hep pill (stadium) veya dairedir; keskin dikdörtgen yalnız menü/panel dilinde kullanılır. | Brawl Stars, Royal Match, Toon Blast, Block Blast! |
| H5 | **Cam, ucuz siyah değil:** Hyper-casual "siyah %22 daire + %12 kenar" yerine premium katman: yarı saydam dolgu + blur + 1.5px açık kenar + üst iç ışık çizgisi + renkli dış glow. | Brawl Stars (derinlik), Royal Match, 2025 glassmorphism dalgası (Apple Liquid Glass) |
| H6 | **Basış her zaman cevap verir:** scale ~0.92 + glow açılması + haptic, 140-160ms; statik kalan buton "ölü" hissi verir. | Clash Royale (gleam), Brawl Stars, GradientButton'ımız (HUD butonlarında eksik!) |
| H7 | **48dp dokunma zemini:** Görsel ≥44-48dp; hit alanı görselden büyük olabilir. CTA (KABUS gibi tek primarı) 56-64dp'dir. | Apple HIG 44pt, WCAG 2.5.5 AAA, Material 48dp |
| H8 | **Kenarlarda yaşa, merkezde oyna:** HUD köşelere/kenara çakılıdır; sahne merkezi hiçbir zaman kapanmaz. Safe-area + notch üst boşluk bırakır. | Tümü; Archero/Stack uç örnek |
| H9 | **HUD oyuna nefes verir:** Gereksiz öğe gizlenir/solur (combo yoksa rozet görünmez); kalıcı HUD ≤4-5 öğe. | Stack, Archero, Crossy Road, Block Blast! |
| H10 | **Tür/zor rozeti kimlik taşır:** "KABUS KULESİ" gibi özel mod, ayrı renk kimliği (mor/karanlık palet) + ikon + glow ister; sıradan beyaz hap içinde kaybolmaz. | Clash Royale (arena rozetleri), Royal Match (etkinlik rozetleri) |

---

## 2. B1-B7 Değerlendirme Tablosu (28 örnek)

Kriterler: **B1** okunurluk (0.3 sn), **B2** dokunma hedefi (≥44-48dp), **B3** estetik uyum (tema), **B4** cam/derinlik hissi, **B5** animasyon davranışı (basış/geri bildirim), **B6** ekran yerleşimi (gölgelenme, safe-area), **B7** minimalizm (oyuna engel değil).

Puanlar Game UI Database / Interface In Game ekran arşivleri + aşağıdaki kaynak makalelerdeki HUD dekonstrüksiyonlarından türetildi (10 = türün en iyisi).

| Oyun | B1 | B2 | B3 | B4 | B5 | B6 | B7 | HUD imzası / kaynak |
|------|----|----|----|----|----|----|----|---------------------|
| **Stack** (Ketchapp) | 10 | — | 10 | 5 | 6 | 10 | 10 | Tek merkezli skor; buton yok; hue döngülü gökyüzü. [App Store](https://apps.apple.com/us/app/stack/id1080487957) |
| **Stack Ball** (Azur) | 9 | 6 | 8 | 5 | 8 | 8 | 9 | Üst merkez skor + ateş modu ısınma göstergesi. [Unity proje referansı](https://discussions.unity.com/t/release-stack-ball-complete-project-editor/741753) |
| **Helix Jump** (Voodoo) | 9 | 6 | 8 | 5 | 7 | 8 | 9 | Skor + yan seviye çubuğu; ateş modunda top alevlenir. [Unity tutorial kültürü](https://www.codester.com/items/30627/stack-ball-fall-helix-tower-unity-project) |
| **Subway Surfers** | 9 | 7 | 8 | 4 | 7 | 8 | 8 | Sol üst para (ikon+sayı), sağ üst skor; pause kenarda. [Behance UI/UX galerisi](https://www.behance.net/gallery/188445103/Subway-Surfers-UIUX) |
| **Clash Royale** (Supercell) | 9 | 9 | 10 | 6 | 9 | 9 | 8 | Üst kaynak barı (altın/gem), chunky Supercell butonları, basışta gleam. [Gamegrin UI analizi](https://www.gamegrin.com/articles/what-can-online-apps-learn-from-clash-royales-user-interface) |
| **Brawl Stars** (Supercell) | 9 | 10 | 9 | 6 | 9 | 9 | 7 | Dev joystick+atak butonu, Super şarj halkası; minimal çatışma HUD'u. [IXD@Pratt eleştirisi](https://ixd.prattsi.org/2025/02/design-critique-brawl-stars), [Interface In Game](https://interfaceingame.com/games/brawl-stars) |
| **Candy Crush Saga** (King) | 9 | 8 | 9 | 5 | 9 | 8 | 7 | Skor+hamle üstte, hedef paneli, booster dock'u; tören animasyonları. [UX Collective analizi](https://uxdesign.cc/does-candy-crush-have-a-good-ux-3c1a865d24e) |
| **Royal Match** (Dream) | 10 | 9 | 9 | 6 | 10 | 9 | 9 | Hedef üst-sol, hamle üst-orta, booster alt dock; animasyonla odak yönetimi. [Funovus breakdown](https://www.funovus.com/blogs/royal-match-dominates-match-3-what-can-all-designers-learn) |
| **Toon Blast** (Peak) | 9 | 9 | 9 | 4 | 9 | 8 | 8 | Kalın konturlu hap göstergeler, büyük booster butonları. [Medium oyun analizi](https://medium.com/@ekinmelissezer/game-analysis-for-royal-match-and-toon-blast-9c4bff8ef48b) |
| **Gardenscapes** (Playrix) | 8 | 8 | 9 | 5 | 8 | 8 | 7 | Yoğun üst bar: kalp+para+yıldız; ikonlu kaynak hapları. [Tasarım dekonstrüksiyonu](https://richard-marmura.squarespace.com/rich-marmura/2018/12/15/game-design-analysis-gardenscapes) |
| **Homescapes** (Playrix) | 8 | 8 | 9 | 5 | 8 | 8 | 7 | Gardenscapes kardeş şablonu; yıldız+para üst hapları. [Game UI Database](https://www.gameuidatabase.com) |
| **Block Blast!** (Hungry Studio) | 10 | 8 | 8 | 5 | 7 | 9 | 10 | Skor+rekor pill kartları, düz zemin, sıfır gürültü. [ROOM 8 UI galerisi](https://it.pinterest.com/pin/125749014585078076) |
| **Survivor.io** (Habby) | 7 | 8 | 8 | 5 | 8 | 7 | 6 | Yoğun roguelike HUD: HP+XP+sarı hız çubuğu; skill seçimi kare bazlı. [BlueStacks rehberi](https://www.bluestacks.com/blog/game-guides/survivor-io/sio-skills-evolution-guide-en.html) |
| **Archero** (Habby) | 9 | 8 | 8 | 4 | 8 | 8 | 9 | Neredeyse boş çatışma ekranı; düşman HP'si üstlerinde, bölüm göstergesi minimal. [Deconstructor of Fun](https://www.deconstructoroffun.com/) |
| **Crossy Road** | 10 | 7 | 9 | 4 | 6 | 9 | 10 | Tek skor + tek köşe butonu; sıfır gürültü. [Game UI Database](https://www.gameuidatabase.com) |
| **Tomb of the Mask** | 9 | 6 | 8 | 3 | 7 | 8 | 9 | Retro neon skor + günlük mücadele kancası; düz 8-bit HUD. [DNA raporu §2](RESEARCH-dna-2026-11.md) |
| **Spiral Roll** (Homa) | 9 | 6 | 8 | 5 | 7 | 8 | 9 | Üst skor + seviye çubuğu; ASMR odaklı sade HUD. |
| **Cube Surfer** (Supersonic) | 9 | 6 | 7 | 4 | 7 | 8 | 9 | Küp sayacı + seviye barı; minimal. |
| **Bridge Race** (Supersonic) | 9 | 7 | 7 | 4 | 7 | 8 | 8 | Renk kodlu blok sayacı üstte; rakip sıralaması yan. |
| **Count Masters** (Freeplay) | 9 | 7 | 7 | 4 | 7 | 8 | 8 | Kalabalık sayacı + kapı aritmetiği HUD'u. |
| **Join Clash 3D** (Supersonic) | 9 | 7 | 7 | 4 | 7 | 8 | 8 | Kalabalık sayacı + final göstergesi. |
| **Woodoku** (Tripledot) | 9 | 8 | 8 | 5 | 7 | 9 | 9 | Skor + combo göstergesi üst pill; taş tepsisi altta. |
| **Water Sort Puzzle** | 9 | 7 | 7 | 4 | 6 | 8 | 9 | Üst bar: skor + geri alma/kanal ekleme ikon butonları. |
| **Ballz** (Ketchapp) | 10 | 6 | 6 | 3 | 6 | 9 | 10 | Tek sayı; sıfır krom. |
| **Fruit Ninja** (Halfbrick) | 9 | 9 | 8 | 4 | 8 | 8 | 8 | Köşede dev ikon butonlar, merkezde skor; en eski "köşe buton bloğu" şablonu. |
| **Angry Birds 2** (Rovio) | 8 | 9 | 9 | 5 | 9 | 8 | 7 | Yoğun üst kaynak barı + bölümler arası skor kartları. |
| **Alto's Odyssey** | 8 | 7 | 10 | 8 | 6 | 9 | 10 | Nefes alan tek skor; tema bütünlüğü referans standardı. |
| **Monument Valley** (ustwo) | 9 | 8 | 10 | 7 | 6 | 9 | 10 | Diegetik minimal; köşe butonları bile sahne malzemesi gibi. |

**Okuma:** B1-B2'de zayıf olan neredeyse yok (pazar bunu zorunlu kılmış); ayrışma **B3-B5**'te (tema uyumu + canlı geri bildirim) ve **B7**'de (minimalizm) oluyor. Premium hissi = B4 (derinlik) + B5 (dokunuş cevabı) kombinasyonu — bizim HUD'un ikisi de zayıf.

### Görsel/video referans havuzları (screenshot kanıtı)
- [Game UI Database](https://www.gameuidatabase.com) — 1.300+ oyun, 55.000+ UI ekran görüntüsü; "Gameplay & HUD" filtresi
- [Interface In Game](https://www.interfaceingame.com) — oyun başına HUD ekran görüntüsü + video
- [Subway Surfers UI/UX (Behance)](https://www.behance.net/gallery/188445103/Subway-Surfers-UIUX)
- [Block Blast! UI (ROOM 8, Pinterest)](https://it.pinterest.com/pin/125749014585078076)
- [Royal Match UI galerisi (Pinterest)](https://kr.pinterest.com/gameuiisgui/game-royal-matchs)
- [Game Maker's Toolkit — "The Power of Video Game HUDs" (YouTube, ~1M izlenme)](https://www.youtube.com/playlist?list=PLh8h0GLRNtdM2MCsHd-sfSa-yM7M8icRV)
- [Brawl Stars HUD (Interface In Game)](https://interfaceingame.com/games/brawl-stars)

---

## 3. HUD Anatomisi: En Yaygın 4 Desen

### Desen A — "Yekpare Üst Bar" (en yaygın; bizim hedef desen)
Tek yatay bant: `[geri/çoklu] [kaynak hapları] [skor merkez] [ses/ayar]`. Altında ayrı bant YOK; hedef/ilerleme barı bu bandın içine gömülü veya bantla bitişik tek ince şerit.
- **Kullanan:** Subway Surfers, Clash Royale, Gardenscapes, Angry Birds 2, Homescapes
- **Tür:** Runner, mid-core, ekonomi ağırlıklı casual
- **Ölçüler:** bant yüksekliği 56-64dp, köşe yarıçapı pill veya 20-24dp, kenardan 12-16dp içeride, safe-area + 8dp

### Desen B — "İskelet Minimal" (hyper-casual stacking'in klasiği)
Tek merkezli büyük skor; buton ya yok ya da tek köşe (pause). Her şey sahnede.
- **Kullanan:** Stack, Ballz, Crossy Road, Block Blast! (skor pill'leriyle hafif versiyon)
- **Tür:** Hyper-casual stacking/puzzle
- **Not:** Stack Tower'ın soyu bu desen; ama bizde tür rozeti + hedef + günlük/kabus girişleri var → **A+B melezi doğru cevap** (tek kapsül üst bar + merkez skor)

### Desen C — "Köşe Buton Blokları"
Sol üst bilgi köşesi (bölüm/can), sağ alt büyük aksiyon butonu(lar), köşe rozetleri (etkinlik, super şarjı).
- **Kullanan:** Brawl Stars, Fruit Ninja, Survivor.io, Archero (ikon yetenekleri)
- **Tür:** Aksiyon, roguelike, arena
- **Ölçü:** aksiyon butonu 64-96dp; ikonik köşe butonu 48-56dp

### Desen D — "Hedef + Araç Dock"
Hedef rozetleri üstte (mavi arka planlı hedef kartları), hamle sayacı, altta booster dock'u.
- **Kullanan:** Royal Match, Candy Crush, Toon Blast, Gardenscapes (bölüm içi)
- **Tür:** Match/burst puzzle
- **Not:** "Bölüm hedefi" konsepti bizim `_hudTarget` ilerlemesinin şablonu — Royal Match hedef kartları hem ikon hem sayıyı tek hapta taşır.

**Bizim eşleşmemiz:** Stack Tower = Desen B iskeleti + Desen A kapsülü + Desen D'nin hedef fikri. Aşağıda §5'te somutlaştırıldı.

---

## 4. BUTON Tasarım Kuralları

### 4.1 Şekil seçimi
| Şekil | Ne zaman | Örnek |
|-------|----------|-------|
| **Daire** | İkonlu, etiketsiz, ikincil eylem (geri, ses, ayar, pause) | Clash Royale üst bar, Fruit Ninja köşeler, Subway Surfers pause |
| **Hap (stadium)** | Etiketli ikincil bilgi/aksiyon; kaynak göstergesi; rozet | Subway Surfers para, Woodoku skor, Block Blast! rekor pill |
| **Kare-yuvarlak (radius 20-28)** | Tek primari CTA, menü dilinde | Supercell butonları, Royal Match "Devam" |
| **Keskin dikdörtgen** | Oyun içi HUD'da YASAK; yalnız panel/liste dili | (anti-örnek: bizim alt bantlar) |

### 4.2 Cam efekti (glassmorphism) tarifi — 2025 standardı
[Apple Liquid Glass (WWDC 2025)](https://ratragaurav.medium.com/liquid-glass-apples-bold-step-to-bring-glassmorphism-back-to-life-920516c2395d) dalgasından sonra premium oyun HUD'larında beklenen katman:
1. **Dolgu:** beyaz %10-14 (bizde %8 — düşük) veya NeonPalette.glass %B3
2. **Blur:** arka plan blur sigma 4-8 (BackdropFilter, ClipRect ile sınırlı; maliyet notu §6)
3. **Kenar:** 1-1.5px beyaz %25-30 (bizde %12-18 — kayıp); NeonPalette.glassBorder hazır ama HUD'da kullanılmıyor
4. **Üst iç ışık:** kenarın üst yarısında 1px beyaz %40 gradyan — "ışık üstten geliyor" hissi
5. **Dış glow (opsiyonel, vurgulu öğe):** tema renginde BoxShadow blur 16-24, alpha .30-.45

### 4.3 Basış animasyonu standardı
- **scale 0.92** (140ms easeOutCubic in, 160ms easeOutBack out) + **glow alpha 0 → .45** + **haptic light**
- İkon butonda ek olarak ikon rengi dim → tam; hap butonda arka plan alpha +0.06
- Basılıyken dış glow'u kare başına blur değiştirerek ANİME ETME — blur animasyonu pahalıdır (§6); glow'u sabit tutup alpha/transform oynat
- GradientButton'ımız (premium_kit.dart) bu standardı zaten sağlıyor; **HUD'daki `_hudButton` sağlamıyor** (InkWell, scale/glow yok)

### 4.4 Boyut standardı
| Öğe | Görsel yükseklik | Hit alanı | Kaynak |
|-----|------------------|-----------|--------|
| HUD ikon butonu (daire) | 48-52dp | ≥44dp | [Apple HIG / WCAG 2.5.5](https://www.browserstack.com/docs/app-accessibility/rule-repository/rules-list/touch-target/touch-target-size), [Material 48dp](https://www.facebook.com/fb-answers/mobile-app-button-size-guidelines) |
| Kaynak/rozet hapı | 36-44dp | tam hap | Subway Surfers, Woodoku |
| Skor kapsülü | 48-56dp | dokunulmaz (bilgi) | Block Blast!, Stack |
| Primari CTA (KABUS, DEVAM) | 56-64dp | tam buton | Royal Match/Supercell CTA'ları |
| Aksiyon oyun butonu | 64-96dp | dev | Brawl Stars, Fruit Ninja |

- Etiketli buton metni: 15-16px, w800, **letterSpacing ≥1.2** (bizim labelLarge 1.2 doğru); Türkçe büyük harfli kısa etiketlerde (KABUS) letterSpacing 2.0-2.5 premium soluk verir
- Tek satır garantisi: etiket kısalt + bilgi ikinci görsel öğeye taşınacak (rozet sayacı ayrı kapsül) — Flexible+ellipsis tek başına çözüm değil (kayma/kısalma algısı)

---

## 5. ELEŞTİRİ: Mevcut HUD Nerede Eksik?

### 5.1 "Yukarıdan aşağıya dikdörtgen dizilimi"nin anatomisi (play_screen.dart:349-399)
Mevcut kolon sırası: **(1)** Row [ÇIK daire | tür hapı | skor | ses daire] → **(2)** tam genişlik `_HudProgress` 8px şerit → **(3)** Row [combo sol uç | kalkan sağ uç]. Üç ayrı yatay katman + kombinasyon:
- `_HudProgress` tam genişlik, yüksekliği 8px, ClipRRect'li ama görsel olarak **ince siyah dikdörtgen şerit** — Desen A'da bu bar bandın İÇİNE gömülür veya skor kapsülünün alt kenarında olur, asla ayrı bant olmaz (H1 ihlali)
- Combo sol uçta, kalkan sağ uçta → iki uç arasında boşluk; "dağınık üç bant" algısı
- Tüm katmanların zemini yok (bantlar şeffaf) → aurora/sahne üstünde yüzen kopuk dikdörtgenler

### 5.2 `_hudButton` (play_screen.dart:433-452)
```
siyah %22 daire + beyaz %12 kenar + InkWell — cam yok, basış animasyonu yok
```
- **B4=2:** düz siyah dolgu; glassBorder (%2E) ve üst iç ışık yok → "geçici placeholder" görünümü
- **B5=1:** InkWell yalnız ripple; scale 0.92 + glow + haptic yok — GradientButton standardımızın altında (H6 ihlali)
- Kenar beyaz %12 çoğu arka planda görünmez → buton sınırı belirsiz
- 48×48 min doğru (B2 geçer), ama ikon 24px butonun %50'si — premium HUD'da ikon/buton oranı ~%55-60 (22-26px / 44-48px makul, sorun değil)

### 5.3 Skor göstergesi (play_screen.dart:456-466)
`headlineMedium` (22px, w800) + tek cyan shadow (blur 16, α.45). H3'ün altında:
- 22px "çok basit" şikâyetinin birinci nedeni — Block Blast!/Stack skorları 28-34px
- Tek shadow = düz neon; premium skor = gradyan dolgu + çift katman glow + pop (var) + CountUp (premium_kit'te var, HUD'da yok)
- `12/30` biçimi iyi (hedefli), ama hedef bilgisinin yarısı ayrı progress şeridinde tekrarlanıyor — bilgi gereksiz çoğalıyor, krom artıyor

### 5.4 Tür rozeti (play_screen.dart:355-372)
Beyaz %8 dolgu + beyaz %18 kenar + `bodyMedium` (14px, textDim #aab4d8):
- textDim kontrastı düşük; rozet "soluk gri hap" — H10 ihlali: tür kimliği (STACK, CATCHER, KABUS…) oyuncunun strateji seçtiği bilgi, öne çıkmalı
- İkon emoji (`spec.icon`) + metin; ellipsis ile kesilebilir

### 5.5 KABUS butonu (map_screen.dart:406-436)
`GradientButton(label: 'KABUS KULESİ · N HAK', height: 54, expand: true, ikon: moon, mor gradyan)`:
- **"Yazısı kayıyor":** (a) `Flexible + ellipsis` etiketi kısaltınca metin ortalama noktası kayıyor; (b) `shine: true` 1400ms parlama süpürmesi giriş anında metnin üstünden geçip "yazı kayıyor" algısı yaratıyor; (c) '·' ile birleşik uzun etiket dar ekranda (360dp − 2×padding − ikon) sığmıyor
- **"Küçük":** 54dp, tek primari haftalık CTA için zayıf — Royal Match/Supercell CTA 64dp; ayrıca glow (mor dış ışıma) GradientButton'da var ama koyu-mor gradyan (#3B0D54→#54146B) arka planla (koyu aurora) az ayrışıyor → buton ekranda "küçük ve koyu" algılanıyor
- Hak sayısı bilgi olarak etikete gömülü ('· 3 HAK') — ayrı rozet kapsülü daha premium okunur (H10)

### 5.6 Somut iyileştirme listesi (öncelik sırasıyla)
1. **Tek kapsül üst bar (H1):** Row + progress + combo/kalkan → TEK cam kapsül içinde: `[ÇIK] | tür rozeti | SKOR (büyük, glow) | [ses]`; hedef çubuğu kapsülün alt kenarına 3-4px gömülü ince şerit; combo+kalkan skorun altına ortalanmış tek mini satır (yoksa hiç görünmez)
2. **Cam cila (H5):** dolgu beyaz %12 (veya glass), kenar glassBorder 1.2px, üst iç ışık çizgisi, çIK/ses butonlarına scale 0.92 + glow + haptic basışı (GradientButton birebir kopyası, daire varyant)
3. **Skoru yıldızlaştır (H3):** 30-32px w900, beyaz→cyan dikey gradyan metin, çift glow (cyan blur 20 α.5 + beyaz blur 8 α.3), pop mevcut, CountUp bağla
4. **KABUS'u büyüt (H7/H10):** height 64, etiket 'KABUS KULESİ' + hak rozetini ayrı kapsüle al (sağda '3 HAK' amber rozet), letterSpacing 2.2, gradyanı aydınlat (#6A1B9A orta ton ekle), dış mor glow alpha .45, shine'ı metin değil buton yüzeyinde tut (veya ilk açılışta 1 kez)
5. **Ekran yerleşimi (H8):** kapsül üstten SafeArea + 4dp; 360×640'ta skor 26px'e düşsün (MediaQuery ile ölçek)

---

## 6. Stack Tower HUD Şablonu (uygulanmaya hazır ölçüler)

### 6.1 Üst bar kapsülü (Desen A+B melezi)
```
┌──────────────────────────────────────────────────┐
│ (◀)  STACK · 3    ┌ 1.284/30 ┐        (🔊)       │  ← yükseklik 60dp
│      tür rozeti    │ ▁▁▁▁▁▁░░ │                       │
└──────────────────┴───────────┴────────────────────┘
   çIK/ses: 48dp daire          skor: 30px w900
   ×6 combo + 🛡×1 → kapsül altında ortalanmış mini satır (24dp)
```

| Öğe | Ölçü | Renk/katman |
|-----|------|-------------|
| Kapsül | H 60dp, pill, kenarlardan 12dp, üstten safe+4dp | dolgu `NeonPalette.glass` (%B3) veya beyaz %12; BackdropFilter blur σ6, ClipRect'li |
| Kenar | 1.2px | `glassBorder` (%2E9FB4FF) + üst iç ışık: üst kenar boyunca 1px beyaz %35 |
| ÇIK/ses butonu | 48dp daire, ikon 22px | dolgu beyaz %14, kenar beyaz %28; basışta scale .92 + cyan glow α.4 + HapticFeedback.lightImpact |
| Tür rozeti | hap H 32dp, pad 12×6, metin 13px w800 letterSpacing 1.5 | tema hue'sünde: `hslColor(world.glow, 90, 78)` metin, aynı hue α.16 dolgu, α.55 kenar — KABUS'ta mor #B388FF |
| Skor | 30px w900 (360dp ekranda 26px) | dikey gradyan beyaz→cyan; shadow1 cyan blur 20 α.5, shadow2 beyaz blur 8 α.3; pop 320ms easeOutBack (mevcut _PopText) + CountUp |
| Hedef şeridi | skor kapsülü alt kenarında H 4dp, genişlik kapsülün %60'ı, pill | cyan→magenta gradyan (mevcut _HudProgress renkleri), hedefe yaklaşınca parlar (mevcut near mantığı korunur) |
| Combo | mini hap H 24dp, 13px | mevcut amber/magenta mantık korunur; konum: kapsül altı ortalanmış |
| Kalkan | ikon 18px + ×N | mevcut mint mantık korunur; combo ile aynı satır |

### 6.2 KABUS / GÜNLÜK butonu (harita ekranı)
| Özellik | Değer |
|---------|-------|
| Yükseklik | **64dp** (primari CTA standardı; 54 → 64) |
| Genişlik | tam genişlik (mevcut expand) |
| Metin | `KABUS KULESİ` — 16px w900, **letterSpacing 2.2** |
| Hak rozeti | etiketten AYRILIR: sağda amber kapsül `3 HAK` (13px w800, amber α.18 dolgu, α.65 kenar) — bittiğinde gri `BU HAFTA BİTTİ` |
| Gradyan | `[#4A1060, #6A1B9A, #2A0B45]` — orta ton aydınlatıldı (mevcut #54146B yerine) |
| Glow | BoxShadow mor (#9d7bff) blur 24 α.45 — koyu aurora zeminden ayrışma |
| İkon | moon 20px, altın-amber ton (#FFC247) — karanlık temayı ısıtır |
| Basış | GradientButton mevcut scale+gleam korunur; `shine` metin üstünden değil buton yüzeyinden süpürsün (mevcut impl. zaten yüzeyde — algı sorunu için giriş shine'ı yalnız ilk açılışta 1 kez) |
| Basılmaz durum | enabled:false mevcut soluk palet + `%0` yerine rozet `0 HAK` |

### 6.3 Neden bu şablon 0.3 sn kuralını geçirir
- Skor tek renk şeridi (cyan glow) → göz kontrast çapa; H2
- Tek kapsül → bant sayısı 3 → 1; H1
- Tür rozeti tema hue'sünde → dünya kimliğiyle B3 uyumu; KABUS moru özel mod kimliği; H10

---

## 7. Flutter Uygulama Notları

### 7.1 BackdropFilter maliyeti
- Resmî uyarı: "relatively expensive" — [BackdropFilter docs](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html); listelerde hücre bazında kullanım klasik anti-örnek ([flutter#32804](https://github.com/flutter/flutter/issues/32804))
- **Bizim durum özel:** HUD kapsülünün arkasındaki sahne HER KAREDE değişiyor → backdrop her karede yeniden örnekleme+blur → GPU maliyeti sürekli. Çözüm: (a) σ≤6 tut, (b) kapsülü `ClipRect` ile sınırla (blur bölgesi kapsül kadar), (c) HUD zaten `RepaintBoundary` ile sahneden izole (play_screen.dart:336) — bunu koru
- **B planı (düşük cihaz):** blur'suz "sahte cam": beyaz %12 dolgu + glassBorder kenar + üst iç ışık — %80 cam algısı, sıfır blur maliyeti; `AmbientMotion` kapısı gibi bir `GlassQuality` kapısı önerilir
- Menü/overlay'de (statik arka plan) BackdropFilter rahatça kullanılabilir — gskinner tavsiyesi: overlay/modal'da kullan, per-frame içerikte kullanma ([kaynak](https://blog.gskinner.com/archives/2022/09/flutter-rendering-optimization-tips.html))

### 7.2 Decorative box shadows
- saveLayer en pahalı işlemlerden — [Flutter perf best practices](https://docs.flutter.dev/perf/best-practices); büyük blurRadius rasterized pahalı
- Kurallar: glow'u ANİME ederken blurRadius/offset sabit, yalnız **alpha ve scale** oynat (Transform ucuz, blur re-rasterization pahalı); HUD kapsülünde tek BoxShadow yeter; combo rozetindeki glow mevcut ve statik — sorun değil
- Gradyan metin glow'u Text shadow olarak 2 katman — Text shadow CompositeLayer'ı BoxShadow'dan ucuz, kabul edilebilir

### 7.3 Semantics
- Mevcut iyi: `_hudButton` Semantics(button,label) var; KABUS kapısı zengin label var
- Eklenmeli: skor `Semantics(liveRegion: true, label: 'Puan 1284, hedef 30')` — CountUp sırasında label'a ara değer yazma (sadece son değeri duyur); dekoratif glow/ışık katmanlarına `ExcludeSemantics`; kapsül tek `Semantics(container: true)` ile bütünlensin (ÇIK | tür | puan | ses çocukları ayrı duyulur)
- Combo/kalkan mini satırı görünmez olduğunda Semantics'ten de düşsün (`SizedBox.shrink` zaten düşürüyor — koru)

---

## 8. Kabul Kriterleri: Premium HUD Testi (5 madde)

1. **0.3 sn okunurluk:** Oyun açıkken skor+hedef+kalan hak tek bakışta okunuyor (3 kişilik hızlı göz testi / ekran kaydı ile doğrula) — H2
2. **Tek bant + dokunma:** HUD tek kapsülde toplanmış; her HUD butonu görsel ≥48dp, hit ≥44dp; KABUS yüksekliği 64dp ve etiketi 360dp genişlikte tek satır (rozet ayrık) — H1, H7
3. **Cam standardı:** Kapsül dolgu beyaz %12 + glassBorder kenar + üst iç ışık; blur σ≤6 ClipRect'li; performance overlay 60fps'de sarı/kırmızı çizgi yok (düşük cihazda sahte-cam B planı devreye alınabilir) — H5
4. **Dokunuş cevabı:** ÇIK/ses/KABUS basışında scale 0.92 + glow + light haptic, 140-160ms; GradientButton ile aynı his — H6
5. **Safe-area + erişilebilirlik:** 390×844 ve 360×640 snapshot'larında üst bar notch'a ve kenara taşmıyor; skor liveRegion ile ekran okuyucuya duyuruluyor; mevcut 336 test + yeni snapshot'lar yeşil — H8

---

## Kaynaklar
- [Game UI Design: Complete Interface Guide 2025](https://generalistprogrammer.com/tutorials/game-ui-design-complete-interface-guide-2025)
- [Argentics — Game HUD Design: Types, Best Practices & Examples](https://www.argentics.io/game-hud-design)
- [Pageflows — Game HUD Essentials](https://pageflows.com/resources/game-hud)
- [Procreator — 5 Best Practices for Game UI Design](https://procreator.design/blog/best-practices-for-game-ui-design)
- [Gamegrin — What Can Online Apps Learn from Clash Royale's UI](https://www.gamegrin.com/articles/what-can-online-apps-learn-from-clash-royales-user-interface)
- [IXD@Pratt — Brawl Stars Design Critique](https://ixd.prattsi.org/2025/02/design-critique-brawl-stars)
- [Interface In Game — Brawl Stars](https://interfaceingame.com/games/brawl-stars)
- [UX Collective — Does Candy Crush have a good UX?](https://uxdesign.cc/does-candy-crush-have-a-good-ux-3c1a865d24e)
- [Funovus — Royal Match Dominates Match-3](https://www.funovus.com/blogs/royal-match-dominates-match-3-what-can-all-designers-learn)
- [UserWise — 5 Simple UX Lessons From Royal Match](https://blog.userwise.io/blog/5-simple-ux-lessons-from-royal-match)
- [Medium — Royal Match & Toon Blast analizi](https://medium.com/@ekinmelissezer/game-analysis-for-royal-match-and-toon-blast-9c4bff8ef48b)
- [Design Bootcamp — Match-3 tasarım analizi](https://medium.com/design-bootcamp/design-analysis-of-match-3-games-fb63879ecd8f)
- [Gardenscapes tasarım dekonstrüksiyonu](https://richard-marmura.squarespace.com/rich-marmura/2018/12/15/game-design-analysis-gardenscapes)
- [Behance — Subway Surfers UI/UX](https://www.behance.net/gallery/188445103/Subway-Surfers-UIUX)
- [ROOM 8 — Block Blast! UI](https://it.pinterest.com/pin/125749014585078076)
- [BlueStacks — Survivor.io rehberi](https://www.bluestacks.com/blog/game-guides/survivor-io/sio-skills-evolution-guide-en.html)
- [Stack — App Store](https://apps.apple.com/us/app/stack/id1080487957) · [Google Play](https://play.google.com/store/apps/details?id=com.ketchapp.stack&hl=en_US)
- [Unity Discussions — Stack Ball proje referansı](https://discussions.unity.com/t/release-stack-ball-complete-project-editor/741753)
- [Game Maker's Toolkit — The Power of Video Game HUDs (YouTube)](https://www.youtube.com/playlist?list=PLh8h0GLRNtdM2MCsHd-sfSa-yM7M8icRV)
- [Game UI Database](https://www.gameuidatabase.com) · [Interface In Game](https://www.interfaceingame.com)
- [BrowserStack — Touch Target Size (44dp/44pt)](https://www.browserstack.com/docs/app-accessibility/rule-repository/rules-list/touch-target/touch-target-size)
- [Orange Design System — Touch Targets](https://system.design.orange.com/0c1af118d/p/022400-touch-targets)
- [BostonUX — Optimal Touch Target Size](https://www.bostonux.com/blog/determining-the-optimal-touch-target-size-is-a-3-d-problem)
- [Medium — Liquid Glass (Apple WWDC 2025) ve glassmorphism](https://ratragaurav.medium.com/liquid-glass-apples-bold-step-to-bring-glassmorphism-back-to-life-920516c2395d)
- [Clay — Why Everything Is Going Glassmorphism](https://clay.global/blog/glassmorphism-ui)
- [Vocal Media — 2025 Mobile Gaming UI Trends](https://vocal.media/gamers/dynamic-ui-design-trends-in-2025-mobile-gaming-app-interfaces-qas802c4)
- [Flutter — BackdropFilter docs](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)
- [Flutter — Performance best practices](https://docs.flutter.dev/perf/best-practices)
- [gskinner — Flutter Rendering Optimization Tips](https://blog.gskinner.com/archives/2022/09/flutter-rendering-optimization-tips.html)
- [flutter/flutter#32804 — BackdropFilter liste anti-örneği](https://github.com/flutter/flutter/issues/32804)
- Deconstructor of Fun — Archero/hiper-casual dekonstrüksiyonları; Udonis — Archero diseksiyonu
