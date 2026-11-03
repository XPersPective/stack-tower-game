# DESIGN: 20 BENZERSİZ PREMIUM OYUN TASARIMI (PB-040, tur 11)

> Kullanıcı hedefi: "her oyun birbirinden farklı, zekice tasarlanmış, var
> olanlardan daha iyi; kaybetse bile tekrar oynamak istenecek; premium efektli;
> basit istifleme mantığına takılıp kalmasın." Mevcut STACK çekirdeği bir oyun
> olarak kalır (isimler kalabilir); aşağıdaki 20 tür ANTİOLOJİYE eklenir.
> Her tasarım: RESEARCH-organic yasaları + RESEARCH-mechanics kataloğu +
> RESEARCH-endgame sekanslarıyla uyumlu; tek dokunuş (C-022); Türkçe UI.

## Ortak yasalar (her tasarımda zorunlu)
- L1 **3-sn anlaşılabilirlik**: ilk ekranda ne yapılacağı tek glif + tek cümle.
- L2 **Kayıpta-comeback**: her kayıp "neredeyse!" hissi verir (hedef barı,
  comeback ×2) — ölü-duruş yok.
- L3 **Süpüren glint + parçacık**: her etkileşimde anında görsel+ses yanıt
  (C-023 juice yasası).
- L4 **Oturum sonu cliff-hanger**: oyun bitişi bir sonraki oturumu özletir
  (günlük tohum, koleksiyon parçası, meydan skoru).
- L5 **Beceri tavanı**: ustalaşmaya sonsuz alan (seed'li varyasyon).
- L6 **Tek dokunuş + hold** (C-022): karmaşık kontrol yok.

---

## 1. KRİSTAL KESİK — "Slicing" (KESME)
- **Mekanik**: havadan süzülen kristal bloklar parmakla kesilir; her kesim
  iki parçaya ayrılır ve kenarları ışıldar. Yanlış kesilen parça platforma
  düşer — 3 hatada oyun biter.
- **Döngü**: gör → kes → parçalar patlar + para saçılır → sıradaki blok hızlanır.
- **Bağımlılık kancası**: "tam ortadan kesmek" = PERFECT → zincir çarpanı;
  kesik yüzey gerçek kristal faset efektiyle parlar (RESEARCH-blocks tarifi).
- **Premium efektler**: kesim çizgisi neon iz bırakır; slow-mo perfect kesimde;
  parça fiziği + kenar ışık kırılımı.
- **Dünya**: BİYO ORMAN (yaprak kristalleri) — orman teması gerçek yaprak
  parçacıklarıyla.
- **Flutter**: orta (path clip + fizik) — 60fps mümkün.
- **Benzersizlik**: mevcut 10 türde kesme yok; Fruit Ninja'dan farkı: kristal
  faset görseli + hedef-kesim (belirli orandan kesme görevi).

## 2. GÖK FÜZESİ — "Sling" (ÇEK-BIRAK)
- **Mekanik**: füzeyi geri çek (lastik), bırakınca fizikle uçar; yoldaki
  yıldızları topla, hedef kuleye çarpar; kule blokları düşer.
- **Döngü**: çek → nişan çizgisi (iz öngörü) → uçuş → yıkım şöleni → yeni kule.
- **Bağımlılık kancası**: iz öngörü çizgisi "bir daha tam ona nişan alayım" hissi.
- **Premium efektler**: roket alev partikülleri, kamera sarsıntısı, yıkım debris.
- **Dünya**: ALTIN ÇÖL (piramit kuleleri).
- **Flutter**: orta (basit balistik).
- **Benzersizlik**: Angry Birds'ten farkı: tek dokunuş-sürükle, kule yıkımı
  istifleme DNA'sıyla birleşir (düşen bloklar skor).

## 3. UZUN KARANLIK — "Hole" (DELİK)
- **Mekanik**: ekranda parmağını sürükle, siyah delik büyür; düşen neon
  parçaları yutar; yanlış renk yutulursa delik küçülür.
- **Döngü**: sürükle → yut → büyü → daha büyük parçalar → combo.
- **Bağımlılık kancası**: Hole.io'nun "yutma memnuniyeti" + renk eşleme zekâsı.
- **Premium efektler**: yutulan parça deliğe spiral çekilir; delik kenarı neon
  rim; combo'da delik kenarı renk değiştirir.
- **Dünya**: DERİN DENİZ (kara delik = girdap).
- **Flutter**: kolay.
- **Benzersizlik**: Hole.io'dan farkı: renk-eşleme kuralı (zeka öğesi).

## 4. RENK KAPI — "Color Gate" (RENK SIÇRAMA)
- **Mekanik**: top sürekli düşer; dokun → zıpla; kapılar renkli — topun
  RENGİNİ kapıdan geçirerek değiştir; eşleşmeyen renk duvarı = ölüm.
- **Döngü**: zıpla → renk değiştir → kapı geç → hız artar.
- **Bağımlılık kancası**: Color Switch'in "tek yanlış renk" gerilimi; her
  kapıdan geçişte partikül patlaması.
- **Premium efektler**: renk geçişinde top morph + halka dalgası; arka plan
  topun rengine göre canlı nefes alır.
- **Dünya**: KRİSTAL MAĞARA.
- **Flutter**: kolay.
- **Benzersizlik**: Color Switch'ten farkı: kapı + engel kombinasyonu, müzik
  ritmiyle senkron zıplama (mevcut RHYTHM altyapısıyla).

## 5. PİN SIRRI — "Pull the Pin" (PİN ÇEK)
- **Mekanik**: pinleri doğru sırayla çek; altın toplar hazneye düşsün, tehlike
  topları (siyah) altına karışmasın.
- **Döngü**: düşün → çek → akış izle → hedef → sonraki seviye (150 el).
- **Bağımlılık kancası**: "bir pin daha" hissi; her el 30-60 sn; başarısızlık
  bile "acaba" bırakır.
- **Premium efektler**: toplar fizikle yuvarlanır; pin çekilince metal "ting"
  sesi; hazneye düşen altın coin partikülü.
- **Dünya**: VOLKAN (lav teması; siyah toplar = kor).
- **Flutter**: orta (basit top-top çarpışması).
- **Benzersizlik**: Pull the Pin'den farkı: bölüm parametreleri mevcut
  levels.dart tohum sistemiyle (150 el, günlük tohum, Kabus Kulesi entegre).

## 6. HEXA NEON — "Hexa Merge" (HEXA BİRLEŞTİR)
- **Mekanik**: altıgen tahtaya düşen sayılı altıgenler; aynı sayılar birleşir
  katlanır (2048 düşüş versiyonu); tahta dolarsa biter.
- **Döngü**: yerleştir → birleş → zincir → temizle.
- **Bağımlılık kancası**: zincir birleşme "bir daha denesem daha iyi zincir
  çıkar" hissi; her birleşme pitch merdiveni (mevcut audio katmanları).
- **Premium efektler**: birleşme halka şöleni + sayı glow; zincirde ekran
  kenarı renk dalgası.
- **Dünya**: UZAY (yörünge tahtası).
- **Flutter**: kolay-orta.
- **Benzersizlik**: 2048/Tetris hibrit; altıgen geometri görsel ayrım.

## 7. HALAT SALINCI — "Swing" (SALLANMA)
- **Mekanik**: dokun→halata tutun, bırak→salınarak uçuş; uçtan uca ilerle;
  her halat daha uzakta.
- **Döngü**: salın → bırak → uçuş → yakala → momentum artar.
- **Bağımlılık kancası**: momentum-ustalığı ("bir salınımda 3 halat" combo).
- **Premium efektler**: halat gerilme yaylanması, uçuş izi, yakalamada partikül.
- **Dünya**: BULUT ŞEHİR.
- **Flutter**: orta (sarkaç fiziği).
- **Benzersizlik**: Stickman_hook'tan farkı: bulut şehir dikey tırmanış +
  mevcut SKIN sistemi (karakter görünümü).

## 8. AYNA İKİZ — "Mirror" (AYNA)
- **Mekanik**: iki karakter aynı anda hareket eder (ayna simetrisi); ikisini
  de eş zamanlı hedeflere ulaştır; biri ölürse ikisi de.
- **Döngü**: düşün → tek dokunuş ikisini yönet → eşzamanlı çözüm → bölüm.
- **Bağımlılık kancası**: "zeka bulmacası" prestiji; çözüm anı satisfaction.
- **Premium efektler**: ayna düzleminde ışık hattı; ikizlerin izleri simetrik.
- **Dünya**: AYNALAR DÜNYASI (yeni dünya önerisi).
- **Flutter**: orta.
- **Benzersizlik**: mevcut antolojide yok; zeka-türü çeşitliliği.

## 9. ZAMAN KIRICI — "Time Freeze" (ZAMAN DONMA)
- **Mekanik**: mermiler/bloklar havada süzülür; dokun→zamanı 1 sn dondur,
  güvenli yolu çiz; bırak→akar.
- **Döngü**: izle → dondur → planla → akıt → geç.
- **Bağımlılık kancası**: "neo-matrix" güç fantazisi; dondurma anında ekranda
  kristal buz efekti (kristal DNA).
- **Premium efektler**: dondurma buz faset overlay; akışta zaman izi.
- **Dünya**: BUZ DÜNYA.
- **Flutter**: kolay.
- **Benzersizlik**: antolojide yok; SUPERHOT prensibinin tek dokunuş hali.

## 10. KUTUP DEĞİŞTİR — "Polarity" (MANYETİZMA)
- **Mekanik**: top + veya − kutuplu; dokun→kutup değiş; aynı kutup itilir,
  zıt çeker; manyetik alanda süzülerek hedefe ulaş.
- **Döngü**: geç → it/çek → momentum → bölüm.
- **Bağımlılık kancası**: fizik-ustalığı; "tam zamanında kutup değiş" akışı.
- **Premium efektler**: kutup değişiminde manyetik halka dalgası; çekişte
  ışık iplikleri.
- **Dünya**: ELEKTRİK ŞEHİR (yeni dünya önerisi).
- **Flutter**: orta.
- **Benzersizlik**: antolojide yok; Ikaruga türevi tek dokunuş.

## 11. KATAMARİ ROLL — "Büyüme" (BÜYÜTME)
- **Mekanik**: top yuvarlanır (dokun→sağa/sola yuvarla); küçük blokları yutar
  büyür; büyüyünce büyük engelleri de ezer.
- **Döngü**: yuvarla → ye → büyü → ez → biter (30sn sprint).
- **Bağımlılık kancası**: büyüme memnuniyeti (Katamari/Katana ZERO).
- **Premium efektler**: yutulan bloklar topa katılır (görsel büyüme), ezme
  sarsıntısı + parçacık.
- **Dünya**: NEON ŞEHİR (sokaklar).
- **Flutter**: kolay.
- **Benzersizlik**: Agar.io'dan farkı: yuvarlanma fiziği + şehir teması.

## 12. YERÇEKİMİ KAPISI — "Gravity Flip" (YERÇEKİMİ DÖNDÜR)
- **Mekanik**: top corridor'da düşer; dokun→yerçekimi ters döner (tavan/zemin);
  engellere çarpmadan ilerle.
- **Döngü**: düş → çevir → düş → ritim.
- **Bağımlılık kancası**: Gravity Guy/AA ritmi; bölümler müzik senkronlu.
- **Premium efektler**: çevirmede ekran hafif döner his (kamera roll), iz.
- **Dünya**: NEON ŞEHİR (tünel).
- **Flutter**: kolay.
- **Benzersizlik**: antolojide yok; tek dokunuş sürekli-koşu DNA'sı.

## 13. PORTAL ÇİFTİ — "Portal" (TELEPORT)
- **Mekanik**: blok bir portaldan girer diğerinden çıkar (momentum korunur);
  hedef tüm yıldızları toplamak.
- **Döngü**: nişanla → fırlat → portal → yeniden açı → topla.
- **Bağımlılık kancası**: portal-zeka; her bölüm 3-5 yıldız + gizli yıldız.
- **Premium efektler**: portal girişi/çıkışı swirl; momentum vektör çizgisi.
- **Dünya**: UZAY.
- **Flutter**: orta.
- **Benzersizlik**: antolojide yok; Portal/Orbit türevi.

## 14. NEON AKIŞ — "Flow Free" (SU AKIŞI)
- **Mekanik**: eş renkli noktaları parmakla çizerek birleştir; tahtayı
  doldur; kesişme = hata (parmak izi neon akar).
- **Döngü**: çiz → doldur → bölüm → sonraki (150 el).
- **Bağımlılık kancası**: Flow Free'nin kanıtlanmış "tamamlandı" tatmini;
  her el 20-40 sn.
- **Premium efektler**: akış neon boru gibi parlar (glow stroke), tamamlanınca
  tahta dalgalanır.
- **Dünya**: KRİSTAL MAĞARA.
- **Flutter**: kolay.
- **Benzersizlik**: Flow Free'den farkı: neon estetik + dünya temaları +
  günlük tohum.

## 15. AYNA LABİRENTİ — "Light Beam" (IŞIK HUZMESİ)
- **Mekanik**: aynaları sürükle/döndür; ışık huzmesini hedefe ulaştır;
  prizmalar rengi böler.
- **Döngü**: yerleştir → ışık akar → hedef → bölüm.
- **Bağımlılık kancası**: Monument Valley prestiji; "çözdüm" anı satisfaction.
- **Premium efektler**: ışık huzmesi gerçek-time yansıma; prizma renk ayrıştırma
  (gökkuşağı); hedefte partikül şöleni.
- **Dünya**: KRİSTAL MAĞARA.
- **Flutter**: orta.
- **Benzersizlik**: antolojide yok; zeka-türü prestij oyunu.

## 16. YIKIM EKİBİ — "Smash" (KULE YIKMA)
- **Mekanik**: sınırlı mermiyle kuleyi dengeden düşür; enkaz hedef bölgeye
  dökülür; fizik parametreleri her atışta farklı.
- **Döngü**: nişan → ateş → fizik çöküş → skor (yıkılan blok sayısı).
- **Bağımlılık kancası**: fizik-çöküş memnuniyeti (Angry Birds yıkım DNA'sı);
  her kule farklı mimari.
- **Premium efektler**: çökme zinciri + toz bulutu + debris fiziği + yavaş
  çekim son blok.
- **Dünya**: VOLKAN (kaya kuleler).
- **Flutter**: orta-zor (rigid body — basitleştirilmiş bağlantı fiziği yeterli).
- **Benzersizlik**: Angry Birds'ten farkı: nişan değil kesme açısı (kesim yeri
  seç → kule o kesitten çöker — mevcut KESME DNA'sıyla hibrit).

## 17. NEON TEMİZLİK — "Clear" (TETRIMINO TEMİZLEME)
- **Mekanik**: tetrimino benzeri şekiller tahtaya yerleşir; tam satır/sütun
  dolunca temizlenir (Blockudoku+Block Blast hibrit); taşarsa biter.
- **Döngü**: seç → yerleştir → temizle → zincir.
- **Bağımlılık kancası**: Block Blast!'ın kanıtlanmış "temizle memnuniyeti";
  zincir temizlemede çarpan.
- **Premium efektler**: temizlenen satır neon patlaması + parçacık; combo'da
  ekran kenarı glow.
- **Dünya**: NEON ŞEHİR.
- **Flutter**: kolay.
- **Benzersizlik**: Block Blast!'tan farkı: satır+SÜTUN temizleme + mevcut
  müzik katmanları + dünya teması.

## 18. HAYATTA KAL — "Survive" (ARENA)
- **Mekanik**: arena daralır; dokun→topu ileri/geri it; dalga engellerden
  kaç; hayatta kalma süresi = skor.
- **Döngü**: kaç → daralma → panik → süre.
- **Bağımlılık kancası**: "bir tur daha dayanabilirim" ; daralma cliff-hanger.
- **Premium efektler**: arena kenarı neon duvar; engel türleri dünyaya göre;
  süresi uzayan skorda renk ısıması.
- **Dünya**: VOLKAN.
- **Flutter**: kolay.
- **Benzersizlik**: antolojide DEFEND'ten farkı: arena daralması + serbest
  hareket (dalga savma değil kaçma).

## 19. YANKI — "Echo" (YANKI KLONU)
- **Mekanik**: 5 sn boyunca yaptığın hareketleri 5 sn sonra YANKI (gölge
  klonun) tekrar eder; klonunla iş birliği yap (düğmeye birlikte bas).
- **Döngü**: kaydet → yankı izle → iş birliği → bölüm.
- **Bağımlılık kancası**: "kendinle iş birliği" zeka bulmacası; zaman-oyunu.
- **Premium efektler**: yankı yarı-şeffaf neon silüet; zaman çizgisi şeridi.
- **Dünya**: AYNALAR DÜNYASI.
- **Flutter**: orta (kayıt/geri oynatma).
- **Benzersizlik**: antolojide yok; Indie hit (The Swapper/Echo) prensibi.

## 20. DÜĞÜM ÇÖZ — "Untangle" (DÜĞÜM)
- **Mekanik**: çaprazlanan çizgileri düğümleri çözülünceye kadar sürükle;
  her bölüm daha karmaşık örgü.
- **Döngü**: gör → sürükle → çöz → bölüm.
- **Bağımlılık kancası**: zen-satisfaction (Planarity kanıtı); sıfır stres
  arası oyun (HUZUR türü kardeşi).
- **Premium efektler**: çizgiler neon kablolar; çözülen kesişim partikülü;
  tamamlandığında düğüm çiçek açar.
- **Dünya**: BİYO ORMAN.
- **Flutter**: kolay.
- **Benzersizlik**: antolojide yok; HUZUR (yavaş tür) slotunu doldurur.

---

## ÖNCELİK SIRASI (RESEARCH-organic yasaları + etki/maliyet)
| # | Oyun | Mekanik yeni mi | Flutter maliyet | Organik potansiyel |
|---|------|-----------------|-----------------|---------------------|
| 1 | RENK KAPI | Evet (antoloji dışı) | Kolay | Ç yüksek (Color Switch kanıtı) |
| 2 | NEON TEMİZLİK | Hibrit | Kolay | Y (Block Blast kanıtı) |
| 3 | UZUN KARANLIK | Evet | Kolay | Y (Hole.io) |
| 4 | HEXA NEON | Hibrit | Kolay-orta | O (2048) |
| 5 | PİN SIRRI | Evet | Orta | Y (Pull the Pin) |
| 6 | KRİSTAL KESİK | Evet | Orta | O |
| 7 | NEON AKIŞ | Evet | Kolay | O (Flow Free) |
| 8 | ZAMAN KIRICI | Evet | Kolay | O |
| 9 | YERÇEKİMİ KAPISI | Evet | Kolay | O |
| 10 | KATAMARİ ROLL | Evet | Kolay | O |
| 11-20 | (kalanlar) | ... | ... | ... |

## UYGULAMA DALGALARI
- **PB-041**: RENK KAPI + NEON TEMİZLİK + UZUN KARANLIK (3 kolay yüksek-etki)
- **PB-042**: HEXA NEON + PİN SIRRI + NEON AKIŞ (bulmaca üçlüsü)
- **PB-043**: ZAMAN KIRICI + YERÇEKİMİ KAPISI + KATAMARİ ROLL (fizik üçlüsü)
- **PB-044**: KRİSTAL KESİK + YIKIM EKİBİ (kesme/yıkım ikilisi)
- **PB-045**: AYNA İKİZ + YANKI + DÜĞÜM ÇÖZ + IŞIK HUZMESİ (zeka dörtlüsü)
- Her oyun: saf motor (testli) → painter → HUD → PNG doğrulama → antoloji
- Harita: 150 bölüm yeniden dağıtılır (30 tür × kriterli dağıtım yasası)
- Görsel varyasyon önerisi: her yeni oyun için 2 alternatif görünüm sunulur
  (kullanıcı seçer) — tur 11 isteği

## TEKNOLOJİ KARARI (önbilgi)
RESEARCH-engine: Flutter yeterli (Impeller + fragment shader). Yeni mekanikler
CustomPainter 60fps bütçesinde; ağır fizik gerekenler (YIKIM) basitleştirilmiş
bağlantı fiziğiyle. Flame katmanına geçiş gerekirse PB-044 öncesi karar raporu.
