# RESEARCH: Sosyal Katman Raporu — Mesajlaşma, Rütbe Sembolleri, 1:1 Chat (2026-11)

- **Tarih:** 2026-11-03
- **Kapsam:** 13 oyunun sosyal katmanı (mesajlaşma, rütbe sembolleri, bildirim, moderasyon, offline/sahte-rakip, rank-up töreni, maliyet sinyali) + çocuk güvenliği politikaları + Flutter gerçek zamanlı altyapı seçimi (2025-2026)
- **Yöntem:** Web araması — 6+ kaynak türü: (1) App/Play mağaza listeleri + top-charts verileri (Sensor Tower/PocketGamer), (2) resmî yardım merkezleri (King, Dream Games, Peak, Playrix, PeopleFun, Sybo, Supercell), (3) Deconstructor of Fun, (4) Naavik, (5) GameRefinery + mobil oyun basını (mobilegamer.biz, PocketGamer.biz), (6) Reddit (r/gamedev, r/ClashRoyale, r/Gardenscapes, r/wordscapes, r/Supabase, r/androiddev), (7) Firebase RTDB / Supabase Realtime / Cloudflare Durable Objects resmî dokümanları, (8) düzenleyici kaynaklar (Apple Guideline 1.2, Google Play Families, UK ICO Children's Code, ESRB/COPPA). Skorlar belgelenmiş mekanikler üzerinden 1-10; gözleme dayalılar konservatif verilmiştir (INFERRED işaretli).
- **İlgili mevcut kod:** `worker/` (Cloudflare Workers + D1: auth/me/leaderboard/score/account — kod DONE, **deploy edilmedi**), `lib/services/leaderboard_service.dart` (kalıcı skor kuyruğu + flush), `lib/services/session.dart` (JWT oturum, hesap silme), `lib/game/progress.dart` (LCG rakip tahtası — bot DNA'sı), `lib/game/levels.dart` (gün tohumlu seed — "beat my score" aynı-bölüm garantisinin temeli), `lib/screens/flow_overlays.dart` (ToastHost yuva kuyruğu — bildirim altyapısı)
- **Kısıt uyumu:** C-005 (tam çevrimdışı + skor kaybetmez), C-006 (yalnız ücretsiz bulut katmanı), C-010 (reklam/3. parti veri yok), C-012 (Türkçe UI), C-014 (e-posta yok), C-016 (premium kalite), C-024 (bot/ajans yok). Önerilerin tamamı meta/servis katmanındadır; drop_core/motor matematiği (C-002) dokunulmaz.
- **Kardeş raporlar:** `RESEARCH-endgame-2026-11.md` (rank-up töreni dramaturjisi bu raporun C6 kriterini besler), `RESEARCH-map-2026-11.md`

---

## 1. Yönetici Özeti: 8 Sosyal Yasası

1. **Sosyal görünürlük menüde değil, ANA DÖNGÜDE yaşar:** Clash Royale/Brawl Stars'ta sosyal her ekranda nefes alır (profil çerçevesi, savaş sonu emote'u, kulüp rozeti). Candy Crush'ta ligler var ama iletişim sıfır — bu yüzden "sosyal ama sessiz" hissi verir. Sembol ana döngüde görünmüyorsa rütbe yok sayılır.
2. **Hazırcümle (quick-chat) çocuk güvenliğinin anahtarıdır:** Nintendo (Mario Kart Tour) ve Supercell (16 yaş altı serbest metin kapalı + Family Friendly klan filtresi) aynı yolda: serbest metni yaş kapısının arkasına koy, çocuğa yalnız hazır iletişim ver. Apple 1.2'nin dört mekanizması (filtre/şikâyet/engelle/iletişim) her UGC'de zorunlu; ICO (Ağustos 2026) çocukların yabancılarla sohbetini "yüksek riskli özellik" ilan etti.
3. **Bot şeffafsa meşru, gizliyse dava:** AviaGames gerçek-para turnuvalarında gizli bot kullandığı için dava edildi (NYU JIPEL 2024). Öte yandan Naavik doğrulama aşamasında "AI botlar sahte multiplayer'ı taklit edebilir" der — şeffaf etiketle. Bizde LCG bot DNA'sı zaten var (`progress.dart`); etiketli bot = çevrimdışı sosyal dolgu (C-005 ile mükemmel uyum).
4. **Rütbe töreni = endgame dramaturjisinin sosyal hali:** Brawl Stars 22 rütbe/7 madalya kademesini yıldız pips'leriyle gösterir ve her yükseliş animasyonludur. Lig yükselişi görsel törensiz olursa Candy Crush'ın kaderine düşer: var ama hiç kimse fark etmiyor.
5. **"Beat my score" sektörde neredeyse boş alan:** 13 oyunun hiçbirinde aynı-seed asenkron meydan okuma + oyun-içi 1:1 chat birleşimi yok. En yakın desen: Subway Surfers Friend Tag/QR dost ekleme + NEON ARCADE tarzı "aynı bulmacayı paylaş" bağlantısı. Bizim LCG seed mimarisi (150 bölüm deterministik) bu özelliği sıfır maliyetle mümkün kılıyor — rakiplerin yapamayacağı şey.
6. **Ekip sohbeti artık yeterli değil:** Naavik'in clan derinlemesine incelemesi net: "bugünün piyasasında yalnızca sohbetten ibaret klan çok incedir" — anlamlı etkileşim (hediye, ortak etkinlik, meydan okuma) şart. Survivor.io'nun oyun-içi sohbeti ölü, topluluk Discord'da yaşıyor — oyun-içi sosyal başarısızlığın kanıtı.
7. **Bağlantı faturası zirve anında patlar:** Supabase Realtime aylık ZİRVE eşzamanlı bağlantı üzerinden faturalanır (501 kişi bir an bile çevrimiçi olursa aşım); Cloudflare Durable Objects ise hibernation sırasında süre ücreti almaz ve Nisan 2025'ten beri ücretsiz planda (SQLite backend). Mevcut altyapımız (Workers+D1) ile tek satıcıda kalmanın maliyet avantajı net.
8. **Bildirim = kırmızı nokta + eylem kartı:** sektörün evrensel kalıbı ikon-üstü nokta+sayı (Toon Blast sohbet, CR klan sekmesi); en iyi örnekler noktayı bir EYLEM kartına bağlar (meydan kartı haritada). Oyun içi bildirim yalnız quick-chat balonu olabilir — odak bozan bildirim ölür.

---

## 2. Kriterler ve Kıyaslama Tablosu

**Kriterler (1-10):**
- **C1** İlk-dakika sosyal görünürlük (sosyal öğe ilk oturumun ilk dakikasında ekranDA mı?)
- **C2** Rütbe sembol çeşitliliği/görünürlüğü (madalyon/rozet sayısı + ana döngüde görünürlük)
- **C3** Mesajlaşma derinliği (hazırcümle? serbest metin? klan/ekip? oyun içi?)
- **C4** Moderasyon/çocuk güvenliği (filtre, yaş kapısı, ebeveyn kontrolü, şikâyet/engelle)
- **C5** Çevrimdışı/sahte-rakip varlığı (net yokken sosyal his veriyor mu?)
- **C6** Rank-up töreni hissi (yükseliş anı kutlaması, görsel şölen)
- **C7** Maliyet/karmaşıklık sinyali (10 = bu katmanı bizim koşullarda taklit etmek UCUZ/yalın; 1 = tam gerçek zamanlı sunucu filosu gerektirir)

| Oyun | C1 | C2 | C3 | C4 | C5 | C6 | C7 | /70 | İmza sosyal özellik |
|---|---|---|---|---|---|---|---|---|---|
| **Brawl Stars** | 8 | 10 | 9 | 8 | 1 | 9 | 1 | **46** | 22 rütbe/7 madalya kademesi (yıldız pips'li crest) + kulüp sohbeti + oyun içi pin/emote |
| **Clash Royale** | 9 | 9 | 8 | 8 | 1 | 8 | 1 | **44** | Kupa+arena nişanı + klan sohbeti (serbest metin) + savaş içi emote |
| **Candy Crush Saga** | 5 | 7 | 2 | 9 | 6 | 7 | 6 | **42** | Haftalık 5 lig (Bronz→Elmas); rozet profilde + tahtada; sohbet YOK |
| **Wordscapes** | 6 | 6 | 6 | 6 | 7 | 6 | 5 | **42** | Takım ligi 7 kademe (Bronz→Elmas) + yıldız turnuvası + takım sohbeti |
| **Royal Match** | 7 | 4 | 7 | 7 | 6 | 6 | 4 | **41** | Liderlik + takım savaşı + takım sohbeti; ebeveyn kontrolünden sohbet kapatma |
| **Toon Blast** | 7 | 4 | 7 | 6 | 5 | 6 | 4 | **39** | Takım sohbeti (filtreli) + takım sandığı; ayarlardan sohbet aç/kapat |
| **Gardenscapes** | 5 | 4 | 6 | 7 | 5 | 5 | 4 | **36** | 50 kişilik takım + sohbet + can isteme; ÖZEL MESAJ YOK |
| **Woodoku** | 2 | 2 | 1 | 9 | 10 | 2 | 10 | **36** | Tek oyunculu + skor tahtası; sosyal YOK |
| **Block Blast!** | 2 | 3 | 1 | 9 | 10 | 2 | 9 | **36** | Tek oyunculu + istatistik/kontes tahtası; 2025'in en çok indirileni ama asosyal |
| **Subway Surfers** | 3 | 2 | 2 | 9 | 8 | 5 | 7 | **36** | Friend Tag/QR ile dost ekleme + Top Run arkadaş tahtası |
| **Ball Sort Puzzle** | 1 | 1 | 1 | 9 | 10 | 1 | 10 | **33** | Tamamen asosyal; tam çevrimdışı |
| **Survivor.io** | 4 | 5 | 4 | 5 | 4 | 5 | 3 | **30** | Klan + klan seferi; oyun içi sohbet zayıf — topluluk Discord'da |
| **Triple Match 3D** | 3 | 2 | 2 | 7 | 7 | 2 | 6 | **29** | Arkadaş skor karşılaştırma; gerçek zamanlı/co-op yok (mağaza yorumu teyitli) |

**Gerekçeler (oyun başına özet):**

- **Brawl Stars (46):** C2=10: Bronz→Ustalar 7 madalya × 3 kademe = 22 rütbe; crest üstündeki yıldız sayısı kademe gösterir (0 yıldız=Diamond 3). Profil, zafer ekranı ve ana ekranda win-streak "tövbe-show" mekaniği üç ayrı yerde görünür (DoF 2024). C3=9: kulüp sohbeti (serbest metin) + maç içi pin/emote. C4=8: Supercell yaş kapısı — 16 altı hesapta serbest metin kapalı, Family Friendly kulüplerde güçlü filtre. C5=1: tamamen çevrimiçi. C7=1: gerçek zamanlı PvP + sohbet = ağır sunucu yatırımı.
- **Clash Royale (44):** C1=9: PvP oyun — ilk maç zaten sosyal; klan daveti erken gelir. C2=9: kupa sayısı + arena nişanları + lig ikonları profil çerçevesinde. C6=8: kupa yolu kilometre taşları + arena açılış kutusu. C4=8: Supercell Young Players politikası + klan sohbet filtresi.
- **Candy Crush (42):** C2=7: haftalık 5 lig (Bronz/Gümüş/Altın/Platin/Elmas), rozet profil + tahta girişinde; ancak lig sembolü ana haritada hemen görünmez (C1=5). C3=2: hiçbir sohbet yok — mesajlaşma tamamen dışarıda (King Community). C6=7: lig terfi/tenzil ekranı + ödül.
- **Wordscapes (42):** C2=6: 7 takım ligi (Bronz, Gümüş, Altın, Yakut, Safir, Zümrüt, Elmas) — kademe sayısı en yüksek casual örneği; C3=6: takım sohbeti + hazır yardım istekleri ("5 yardım = ücretsiz ipucu" — sosyal eylemi ödülle bağlar!); C4=6: moderasyon destek üzerinden (oyuncu moderatörü yok).
- **Royal Match (41):** C1=7: liderlik düğmesi alt navigasyonda, ilk dakikada görünür; profil özelleştirme liderlik sahnesinde görünür. C3=7: takım sohbeti serbest metin. C4=7: Ayarlar→Ebeveyn Kontrolü'nden sohbet kapatma + İletişim Kuralları. C7=4: takım etkinlikleri sunucu ister ama gerçek zamanlı değil.
- **Toon Blast (39):** C3=7: takım sohbeti serbest metin, filtreli; takım lideri sohbeti kapatamaz, yalnız temizleyebilir (r/ToonBlast). C4=6: Ayarlar→Sohbet Aç/Kapat (sohbet kapalıyken can yardımı yine çalışır — katkı ile sohbeti ayırmanın zarif yolu). C2=4: kişisel rütbe sembolü zayıf, takım tahtası var.
- **Gardenscapes (36):** C3=6: takım sohbeti + can/kart isteme; ancak ÖZEL MESAJ hiç yok — r/Gardenscapes'te şikâyet konusu (1u3po2w). Playrix bilinçli seçim: DM açarsan moderasyon yükü açılır.
- **Woodoku / Block Blast! / Ball Sort (33-36):** C5=10 ve C4=9 ortak: UGC olmadığı için güvenlik bedava, tam çevrimdışı. C1-C3 ~1-2: sosyal katman fiilen yok. **Block Blast!'ın 2025'i indirme şampiyonu olarak asosyal yaşayabilmesi = sosyal KATMANIN değil, çekirdek oyunun önemli olduğu kanıtı; ama aynı zamanda "34M DAU'ya sosyal verilebilirdi" boşluğu = bizim fırsat.** C7=9-10: taklit edilecek bir şey de yok.
- **Subway Surfers (36):** C1=3: Top Run arkadaş sekmesi menünün derinliğinde. Friend Tag/QR dost ekleme (telefon rehberi/hesap bağlamadan) = çocuk güvenli dost modelinin en iyi pratik örneği. C5=8: oyun tam çevrimdışı oynanır.
- **Survivor.io (30):** C3=4: oyun içi sohbet sınırlı, koordinasyon Discord'da — oyun-içi sosyal başarısız. C2=5: sezon rütbe ikonları var.
- **Triple Match 3D (29):** mağaza yorumu teyitli: "arkadaşlarla skor karşılaştırma var ama etkileşimli çok oyunculu veya co-op yok." Takım pazarlaması (Instagram) içeriği karşılamıyor.

**Okuma:** Sosyal derinlik sıralaması net bir spektrum veriyor: **Supercell ucu** (tam sosyal, ağır sunucu, yaş kapılı serbest metin) ↔ **asosyal bulmaca ucu** (tam çevrimdışı, sıfır UGC). **Bulunmayan orta: çevrimdışı-first bir bulmacaya, çocuk-güvenli hazır iletişim + şeffaf bot + asenkron meydan eklenmiş hâl.** Bu raporun öneri paketi tam olarak bu boşluktur.

---

## 3. "Nasıl Göstermişler" — Görsel/UI Kalıp Kataloğu

### 3.1 Rütbe sembolleri

| Oyun | Sembol sistemi | Görsel dil | Nerede görünür |
|---|---|---|---|
| Candy Crush | 5 haftalık lig: Bronz→Gümüş→Altın→Platin→Elmas | Madalya/rozet (kalkon), renk kademesi tek değişken | Profil kartı, lig tahtası girişleri; terfi/tenzil ekranı |
| Clash Royale | Kupa sayısı (sürekli) + arena nişanı (kesintili) + profil seviyesi | Arena nişanları sahne temasıyla uyumlu ARMALAR; kupa barı her ekranda | Profil, maç girişi VS ekranı, klan üye listesi |
| Brawl Stars | 7 madalya kademesi × 3 = 22 rütbe; crest üstü yıldız pips'leri kademe gösterir (0 yıldız=Diamond 3) | HEXAGONAL kalkon; renk: bronz→gümüş→altın→mavi(elmas)→mor(mitik)→turuncu-kırmızı(efsane)→Ustalar | Profil, sıralama lobi, zafer ekranı, win-streak 3 lokasyon (DoF) |
| Wordscapes | 7 takım ligi; madalya/tugay rozetleri turnuva bracket'ında | Bracket + madalya ikonları; renk adları değer taşları (Yakut/Safir/Zümrüt) | Takım sayfası, turnuva ekranı, sohbette takım adı yanında |
| Survivor.io | Sezonluk klan/sıralama derecesi ikonları | Kalkon + fildişi/maden kademesi | Klan sayfası, sezon ödül ekranı |

**Ortak desenler:** (1) renk kademesi bronz→gümüş→altın→elmas endüstri standardıdır — oyuncular anında okur; (2) kesintili kademeye ek yıldız/pips Brawl Stars'ın icadı değil ama en rafine hali; (3) sembolün DEĞERİ göründüğü yer sayısıyla orantılı — tek ekranda görünen madalyon süs, üç ekranda görünen madalyon kimliktir; (4) en iyi örneklerde sembol oyun temasına bağlanır (CR arena armaları) — generic kupa ikonu değildir.

### 3.2 Mesaj UI kalıpları

| Kalıp | Örnek | Ne zaman kullanılıyor | Yapısal özellik |
|---|---|---|---|
| **Emote/pin balonu** | Clash Royale savaş içi, Brawl Stars maç içi pin'leri | Gerçek zamanlı maç sırasında | Karakter yüzü/küçük kart; HUD üstü kısa süreli balon; serbest metin YOK |
| **Hazırcümle damga** | Mario Kart Tour ("Hello!", damga+emoji) | Yarış sırasında, çocuk kitlesi | Tamamen ön-tanımlı liste; hiç serbest metin yok; COPPA-uyumlu iletişimin referans uygulaması |
| **Hazır yardım isteği** | Wordscapes takım sohbeti ("can ister misin" şablonları) | Takım koordinasyonu | Tek dokunuşla sohbete şablon düşer; 5 yardım = ipucu ödülü |
| **Serbest metin sohbet** | Toon Blast/Gardenscapes/Royal Match takım sohbeti, CR/BS klan sohbeti | Kulüp/takım ekranı (oyun DIŞI) | Filtreli; Supercell'de 16 yaş altına kapalı; Playrix'te DM yok; oyuncu listesi → balon → yazma alanı; **oyun İÇİNDE asla** |
| **Sistem mesajı şeridi** | Takıma katıldı/ayrıldı, mileston duyuruları (Naavik "activity feed" önerisi) | Sohbet akışında gri şerit | Oyuncu mesajından ayırt edilecek stil |

**Kritik gözlem:** Hiçbir casual bulmacada OYUN SIRASINDA serbest metin yoktur — iletişim ya (a) oyun dışı ekranlarda serbest metin, ya (b) oyun içi hazırcümle/emote'tur. "İkisi aynı anda, 1:1, aynı tohumlu bölümde" kalıbı 13 oyunda da yok.

### 3.3 "Mesaj geldi" bildirim kalıbı

1. **İkon-üstü kırmızı nokta + sayı** (evrensel): Toon Blast sohbet sekmesi, CR klan sekmesi, Wordscapes takım sekmesi. Ucuz, anlaşılır, işlevi bitince kaybolur.
2. **Menü içi toast/snackbar**: girişte "X sana can gönderdi" satırı; ToastHost benzeri kuyruk — eşzamanlı bildirim üst üste binmez.
3. **Eylem kartı**: bildirim + tek dokunuşla eylem (canı kabul et, meydana cevap ver). En zayıf halka: çoğu oyun bildirimi bir sayfaya yönlendirir, eylemi orada bitirir — ekstra 2-3 tık.
4. **Oyun içi balon** (yalnız hazırcümle/emote): maç sırasında gelir, 1-2 sn görünür, kaybolur; odak bozmaz. Mario Kart Tour damgaları ve CR emote'ları bu kalıbın kanıtı.
5. **Push (opsiyonel, opt-in)**: CR klan sohbeti push'u, takım daveti push'u. Çocuk kitlesinde varsayılan KAPALI olmalı (ICO privacy-by-default).
6. **Sesli + haptic onay**: bildirim geldiğinde kısa chime; ama çoğu bulmaca oyununda sessiz — C6 boşluğuyla aynı.

---

## 4. ELEŞTİRİ: Zayıf Yönler ve Bizim Üstümüzü Çizeceğimiz Yerler

1. **"Sosyal ama sessiz" sendromu (Candy Crush, Block Blast, Woodoku, Ball Sort):** Lig/tahta var ama tek kelime iletişim yok. Skor karşılaştırma tek yönlü vitrin. → **Biz:** her skor bir CONVERSATION STARTER olacak: sonuç ekranından tek dokunuşla "Geçebilir misin?" meydanı; rakip cevap verince zincir kurulur.
2. **Sosyal öğe ana döngünün dışında saklanmış (Subway Surfers, Survivor.io, Triple Match):** Dostlar sekmesi 3 derinlikte; sonuç: ölü özellik. Survivor.io'da topluluk Discord'a taşındı = oyun-içi sosyal iflas. → **Biz:** sosyal giriş noktası menü + harita + SONUÇ EKRANI'nda (doruk anı — RESEARCH-endgame §1 yasa 4: doruk geleceğe yatırılır).
3. **Serbest metin = moderasyon bedeli (Playrix DM açmıyor, Supercell 16 kapısı):** UGC derinliği arttıkça ya kapatıyorsun ya 7/24 moderasyon parası ödüyorsun. İki uç da oyuncuya değer katmıyor. → **Biz:** v1'de hazır cümle + tepki + şeffaf bot: iletişim HISSESİ tam, moderasyon yükü ~sıfır; serbest metin moderasyon bütçesi oturunca F5'te.
4. **Rank-up töreni eksik/kibrit çöpü:** Candy Crush lig terfisi görünmez bir ekran; Wordscapes bracket sonu ödül listesi. Brawl Stars dışında yükseliş anı KUTLANMAZ. Oysa endgame araştırmamız (RESEARCH-endgame §2 E1) terfi anının ilk 1 saniyesinin üç kanalla vurulması gerektiğini gösterdi. → **Biz:** terfi = MonumentCeremony sınıfı tam ekran tören (ışık köprüleri zaten var) + haptic + madalyon reveal; düşüş = cömert konsolasyon (C-019 cömertlik ilkesi).
5. **Bildirim eyleme bağlanmıyor:** nokta var, tıklayınca sohbet açılıyor, eylem 3 tık sonrası. → **Biz:** "meydan kartı" haritaya düşer; dokun → önizleme → oyna. 2 tık, aynı tohum.
6. **Sahte rakip şeffaflığı riski (AviaGames davası, WWF bot şüpheleri):** gizli bot = hukuki/itibar mayını. → **Biz:** botlar daima "BOT/YAPAY" etiketli; LCG rakip tahtamız zaten deterministik — etiketlemek maliyetsiz, güven kârı.
7. **Dost ekleme ya hesap bağımlı ya yok:** Facebook bağlama (Subway Surfers eski model) çocuklar için uygun değil; çoğu bulmacada dost ekleme HİÇ yok. → **Biz:** Friend Tag (6 haneli kod + QR) — telefon rehberi/e-posta/3. parti hesap gerekmez; ICO/COPPA uyumlu; Subway Surfers'ın yeni modelinden alındı.
8. **Zirve bağlantı faturası tuzağı (Supabase):** 501. eşzamanlı oyuncu tek an bile görünürsa tüm ay aşım faturalanır. → **Biz:** Durable Objects hibernation — boş oda bedava; bizim trafik şeklimize (seans başına kısa oda) birebir.

---

## 5. SOMUT ÖNERİ PAKETİ

### 5.1 Sekiz Rütbeli Madalyon Sistemi — "Kule Diyarı Nişanları"

Tema: OYUNUN KENDİSİ (kule yığma) — nişanlar kule inşaat hiyerarşisi anlatır; generic bronz/gümüş/altın klonu değil. Renkler `lib/game/levels.dart` kThemes paletlerinden + premium aurora token'larından (PB-031) beslenir. Adlar Türkçe (C-012). Haşat puanı = haftalık sezon puanı (en yüksek skorlar toplanır; UTC hafta — mevcut `worker/` gün mantığına paralel).

| # | Rütbe | Eşik (haftalık puan) | Renk | Madalyon biçimi | Ek görsel |
|---|---|---|---|---|---|
| 1 | **TEMEL** | 0 (herkes) | Taş grisi | Tek kare blok, düz kenar | — |
| 2 | **TUĞLA** | 150 | Kiremit | İki blok üst üste | Harç çizgisi |
| 3 | **KULE** | 400 | Amber | Üç blok + tek pencere | İnce hale |
| 4 | **KALFA** | 900 | Bakır/bronz | Dört blok + kemer kapı | Kemerde ışık |
| 5 | **USTA** | 1.800 | Gümüş | Beş blok + kubbe | Gümüş yansıma |
| 6 | **MİMAR** | 3.500 | Altın | Kule + tepe yıldızı | Altın halka |
| 7 | **BAŞ MİMAR** | 7.000 | Platin/buz mavisi | Kule + aurora halkası (aurora_background DNA'sı) | Işık köprüleri (MonumentCeremony DNA'sı) |
| 8 | **DİYAR EFSANESİ** | 12.000+ (üst %1 hedefi) | Aurora/elmas | Taçlı kule + yıldız saçılımı (PB-033 B1 final rotasyonu konfeti dilini kullanır) | Arka plana 4 sn aurora dalgalanması |

**Kademeler (Brawl Stars pips deseni):** her rütbe 3 alt kademe; madalyon altında 0-2 yıldız pips'i (3. pips = sonraki rüyeye geçiş). Böylece 8 rütbe × 3 = 24 görünür kademe; ilerleme hissi sıklaşır.

**Görünürlük kuralları (yasadan değil, gözlemden):** madalyon şu 6 lokasyonda zorunlu: (1) menü profil rozeti, (2) tahta satırı sol kenarı, (3) sonuç ekranı imza alanı, (4) meydan kartı (davet edenin nişanı — "ÜSTADIN meydanı"), (5) quick-chat baloncuğu yanında mini ikon, (6) profil sayfası büyük görünüm + rütbe geçmişi şeridi. **Terfi anı:** flow_overlays'e yeni adım — tam ekran: madalyon eski→yeni morph (0.8s), ışık köprüleri, CountUpText ile puan, haptic (mevcut ceremony v2 yıldız pop + haptic deseni). **Tenzil anı:** madalyon kısılır AMA "Kalkan" (streakShield DNA'sı) ile sezon ilk tenzil affedilir — C-019 cömertlik.

**Teknik not:** madalyonlar `CustomPainter` ile prosedürel çizilir (ikon seti üreticisi `test/tools/gen_icons_test.dart` DNA'sı); 24 kademe asset değil parametrik çizim = paket boyutu ~0.

### 5.2 Minimum-Viable Sosyal Katman (v1)

**Kapsam: 1:1 dost + hazırcümle sohbet + tepkiler + şeffaf bot + aynı-tohum meydan. Kamusal meydan YOK (kullanıcı kararı). Serbest metin YOK (v1).**

**a) Dost modeli — Friend Tag (Subway Surfers deseni):**
- 6 haneli kod + QR; ekleyen-eklenen karşılıklı onay. Telefon rehberi/e-posta/sosyal hesap YOK. Takma ad otomatik üretim (TD-002 çözümü: "Kuleci-482" tarzı; oyuncu istesser hazır listeden değiştirir — serbest metin isim de YOK).
- Dost sayısı tavan 20 (veri minimizasyonu; ICO ölçülülük standardı).

**b) 1:1 quick-chat — 32 hazır cümle, 6 kategori (Türkçe):**
- Selam: "Merhaba!", "Selam kuleci!", "Neredesin?", "Hoş geldin!"
- Meydan: "Geçebilir misin?", "Seni yendim!", "Rövanş?", "Aynı bölümde oynayalım mı?"
- Tebrik: "Muhteşem!", "Rekor!", "Helal olsun!", "Ne oyundu be!"
- Yakın skor: "Neredeyse!", "1 blok kalmıştı!", "Az kaldı, hadi!", "Bu bölüm yalanıyor..."
- Yardım/strateji: "İpucu: önce kenarları", "Altın bloğu kurtar!", "Sakin sakin", "Twist'e dikkat!"
- Veda/esprı: "Sonra görüşürüz!", "Molâ zamanı", "Kule yine devrildi 😄", "Yarın rövanş!"
- **UI:** iMessage-tarzı balonlar; gönderen tarafında madalyon mini ikonu; balon üstüne uzun bas = 5 tepki (👍❤️😂😮🔥). Balonlar 30 gün sonra otomatik silinir (D1 TTL; veri minimizasyonu).
- **Oyun içi (aynı bölüm oynanırken):** yalnızca 4 hızlı damga ("Hadi!", "Muhteşem!", "Neredeyse!", "Kaybettim bile 🙂") — HUD üstünde 1.5 sn balon (Mario Kart Tour/CR emote kalıbı); odak bozmaz, InputGate'e takılmaz (sadece görsel katman).

**c) Tepkiler (reactions):**
- Mesaja 5 tepki + SONUÇ EKRANINA 5 tepki (rakibin skor kartına "ateş" vermek = asenkron alkış). Tepkiler UGC sayılmaz (ön-tanımlı) → moderasyon yükü sıfır, ama sosyal sıcaklık sağlar.

**d) Şeffaf offline bot sohbeti (C-005 ile örtüşür):**
- Bot = `progress.dart` LCG rakip DNA'sı; "BOT" etiketi balon ve kart üzerinde HER ZAMAN görünür (AviaGames dersi — şeffaflık pazarlık konusu değil).
- Davranış: dostun çevrimdışı olduğu tespit edilince ( veya kullanıcı "botla oyna" seçerse) bot 3-8 sn insan gecikmesiyle kategoriden hazırcümle döndürür; meydan kabulünde bot deterministik skorla oynar (aynı seed'e bot politikası). Ağ gelince gerçek dost oturumu bot oturumunu gölgeler; skorlar uzlaştırılır (leaderboard_service kuyruk deseni — skor asla kaybolmaz C-005/C-007).

**e) "Beat my score" + aynı-tohum 1:1:**
- Meydan kartı = base64({seed, skor, rütbe, takma-ad-hash, imza}); seed zaten `levels.dart` deterministik üretim → karşı taraf BİREBİR AYNI bölümü oynar. Parola/yapı gerektirmez; kart D1'de + offline deep-link olarak paylaşılabilir (faz 2'de QR/link).
- **Eşzamanlı mod ("ikimiz aynı bölümde"):** Durable Object oda: 2 oyuncu + presence + damga broadcast + canlı skor çubuğu ("Rakip: 3.210"); bitişte karşılaştırma töreni (endgame raporu E1: ilk 1 sn üç kanal). Girişte "Rakibin hazır" splash'ı; biri çıkarsa bot devralır (şeffaf etiketle).
- **Sezon ligi (faz 3):** Wordscapes 7 kademelik takım ligi modeli bireyselleştirilir: 8 rütbe ligi gibi davranır; haftalık kapanışta terfi/tenzil töreni.

### 5.3 Bildirim Akışı

```
[Meydan geldi] ──► Dostlar ikonu: kırmızı nokta + sayı (kalıcı)
                ──► Menü girişinde toast: "Kuleci-482 seni yendi: 12.450 — Rövanş?" (ToastHost yuva kuyruğu)
                ──► Haritada meydan kartı (1.2s ease-out iniş — construction DNA'sı)
Dokunuş ──► Bölüm önizleme (aynı seed) ──► Oyna ──► Sonuç ekranı
        ──► Otomatik mesaj: kazandıysan "Seni yendim: <skor>" / kaybettiyse "Rövanş?" hazır cümlesi seçili
[Oyun sırasında dost damgası] ──► HUD üstü 1.5 sn balon; ses yok, haptic hafif; oyun durmaz
[Push] (faz 2, opt-in, çocuklarda varsayılan KAPALI): "X sana meydan okudu!" → deep-link kart
[Kurallar] (1) oyun içi bildirim YALNIZ damga; (2) eşzamanlı toast'lar kuyrukta (PB-015 yuva yasası); (3) her bildirim tek dokunuş eylem içerir; (4) sessiz saat 22:00-08:00 yerel.
```

### 5.4 Çocuk Güvenliği Kısıtları (mağaza politikaları zorunlu kılar)

| Zorunluluk | Kaynak | Bizim uygulama |
|---|---|---|
| Yayın-öncesi istenmeyen içerik filtresi | Apple Guideline 1.2 (dört mekanizmanın TAMAMI şart; eksikte reddiye; 2026 Şubat güncellemesi rastgele/anonim sohbeti de kapsıyor) | v1'de serbest metin yok → filtre yükü ~0; takma ad hazır listeden; YİNE DE istemci+sunucu kelime filtresi katmanı baştan kurulur (F5 serbest metin için) |
| İçerik şikâyet mekanizması + zamanında müdahale (reddiyelerde 24 saat beklentisi) | Apple 1.2 | Ayarlar→Yardım→Şikâyet akışı (Wordscapes deseni): mesaj/dost seç → neden → ekran görüntüsü opsiyonel; D1'de `reports` tablosu; şikâyet edilen mesaj şikâyet anında şikâyet edene gizli |
| Kötü niyetli kullanıcıyı ENGELLEME | Apple 1.2 | Dost listesinden "Engelle" — D1 `blocks`; engellenen: mesaj gönderemez, meydan açamaz, listede görünmez; karşılıklı |
| İletişim bilgisi yayımlama | Apple 1.2 | `store/` gizlilik politikası + ayarlara destek e-postası (zaten var) |
| Çocuklara yönelik uygulamada UGC kısıtları | Google Play Families (çocuk hedefli UGC/sohbet kısıt; karma kitlede modere sohbet + rapor/engelle) | Hedef kitle geniş; en katı senaryoya tasarlanır: serbest metin yok, push varsayılan kapalı, reklam/izleyici yok (C-010 zaten) |
| Yabancılarla konuşma = yüksek riskli özellik, kısıtlanacak; gizlilik varsayılan olarak korumacı | UK ICO Children's Code (Ağustos 2026 mobil oyun taraması; oyunlar top-10 incelemeye alındı) | Dostluk yalnız karşılıklı kod/QR ile; profil alanı minimal (takma ad + madalyon; foto/bio/yaş YOK — COPPA veri minimizasyonu); DM yalnız dostlar |
| Yaş kapısı | Supercell pratiği (16 altı serbest metin kapalı), ESRB/COPPA | Yaş sormuyoruz (veri toplamamak > yaş sormak); HERKES hazırcümle modelinde → kapıya gerek kalmaz |
| Ebeveyn kontrolü | Royal Match (Ayarlar→Ebeveyn Kontrolü→Sohbet kapat), Toon Blast (sohbet aç/kapat) | Ayarlar: "Sohbet: Açık/Kapalı" + "Push: Açık/Kapalı"; sohbet kapalıyken meydan + bot çalışmaya devam eder (Toon Blast dersi: katkı ile sohbeti ayır) |

### 5.5 Flutter Teknoloji Seçimi (2025-2026)

| Kriter | **Firebase RTDB** | **Supabase Realtime** | **Cloudflare D1 + Durable Objects (WS hibernation)** |
|---|---|---|---|
| Gerçek zamanlı model | JSON ağacı, ms-düzeyi sync, sunucusuz kurallar dili | Kanal: broadcast + presence + postgres_changes; RLS ile yetki | DO = oda-başına stateful nesne; standart WebSocket; hibernation API |
| Presence / onDisconnect | YERLEŞİK (onDisconnect, presence hazır) | YERLEŞİK (presence track/untrack) | Elle yazılır (~50 satır DO kodu) |
| Çevrimdışı destek | YERLEŞİK disk persistence + reconnect birleştirme | Sınırlı (kendi kuyruğun) | KENDİ kuyruğun — ama bizde zaten VAR (`leaderboard_service` kalıcı kuyruk deseni; C-005) |
| Ücretsiz katman | 100 eşzamanlı bağlantı; 1 GB depo, 10 GB/ay indirim | ~200 eşzamanlı, 100 mesaj/sn | Nisan 2025'ten beri VAR (SQLite-backed DO); Workers free sınırları: günlük ~100k istek |
| Ücretli model/ risk | Blaze: 200k bağlantı; $1/GB indirim — mesaj başına ücret YOK | **$2.50/1M mesaj + $10/1.000 ZİRVE eşzamanlı** — tek zirve anı tüm ayı faturalandırabilir | Hibernation'da süre ücreti YOK; ~$0.15/M istek (gelen WS mesajı=request); $12.50/M GB-s aktif süre |
| Mevcut projeye entegrasyon bedeli | İKİNCİ backend: yeni hesap, FlutterFire kurulum, kural dili öğrenimi, C-006'ya gerilme (Firebase ücretsiz ama ayrı satıcı) | İKİNCİ backend: ayrı Postgres + satıcı; JWT köprüsü yazılır | **SIFIR yeni satıcı:** `worker/` + D1 + HS256 oturum ZATEN yazılı (deploy bekliyor); C-006 birebir |
| Flutter tarafı | firebase_database (FlutterFire) | supabase_flutter / realtime_client | `web_socket_channel` (Flutter resmî paketi) — standart WS, kilitlenme yok |
| Kilitlenme | Yüksek (Google) | Orta | Düşük (standart WS + SQL) |
| Bizim işimize uyan kesin özellik | Offline persistence + presence bedava | RLS'li kanallar zarif | Oda=DO: "aynı bölümde 2 kişi + damga + canlı skor" tam olarak bir DO; boş oda bedava |

**KARAR — Cloudflare D1 + Durable Objects (önerilen) + plan B Firebase RTDB:**
1. C-006 (yalnız ücretsiz katman) tek satıcıyla karşılanır; `worker/` zaten D1'de 12 testle yeşil — deploy eden gün sosyal uçlar aynı depoda açılır.
2. Trafik şeklimiz (2 kişilik kısa ömürlü odalar, çoğu zaman boş) hibernation maliyet modeli için idealdir; Supabase'in zirve-bağlantı faturası ve Firebase'in ikinci-satıcı bağı gereksiz risk.
3. Presence/handshake'i DO'da elle yazmak ~gün işi; karşılığında standart WebSocket + `web_socket_channel` ile kilitlenmesiz istemci.
4. Plan B (RTDB), DO kodu beklenmedik biçimde yetersiz kalırsa: offline persistence + presence bedava, 100 ücretsiz bağlantı ilk yıla yeter.

### 5.6 Worker uçları (D1 şeması taslağı — mevcut `worker/logic.ts` uzantısı)

```
POST /friends/request {code}        → karşılıklı onay; tavan 20 dost
GET  /friends                       → liste (takma ad, rütbe, son-çevrimiçi gürültülenmiş ±1sa)
POST /challenge {friendId, seed, score, sig} → meydan kartı yazar
GET  /challenges/inbox              → gelen meydanlar (kart + durum)
POST /challenge/:id/result {score}  → iki taraf sonuçlandı → çift-result kilitli
POST /chat/:friendId {phraseId}     → YALNIZ sunucu-tanımlı phraseId (int) kabul eder — serbest metin taşınmaz
GET  /chat/:friendId?after=cursor   → geçmiş (30 gün TTL)
POST /report {messageId|friendId, reason}
POST /block {friendId} / DELETE
WS   /room/:challengeId             → DO: presence + damga broadcast + canlı skor (2 bağlantı tavanı)
```
D1 tabloları: `friends`, `challenges`, `chat_messages(phraseId INT, reaction INT)`, `reports`, `blocks`, `season_scores(user, week, best)` — mevcut `users/scores` ile HS256 oturum paylaşır.

---

## 6. Uygulama Sırası (Etki/Maliyet) + Kabul Kriterleri

| Faz | İçerik | Etki | Maliyet | Kabul kriterleri |
|---|---|---|---|---|
| **F0 — Köprü** | `worker/` deploy (wrangler + D1 hesabı — README "Üretim adımları" hazır); skor kuyruğu canlı tahtaya bağlanır | TÜM bulutun kapısı; sosyal bunun üstüne gelir | 1 gün (geliştirici adımı) | Bulut tahtası gerçekte görünüyor ("Bulut tahtası" rozeti yanar); skor kuyruğu uçak-modu testinde skor kaybetmiyor (C-005) |
| **F1 — Madalyon** | 8 rütbe × 3 kademe, CustomPainter prosedürel; 6 görünürlük lokasyonu; terfi/tenzil töreni (flow_overlays yeni adım); haftalık sezon puanı hesabı | En yüksek etki/maliyet: %100 istemci-içi, sunucusuz çalışır, oyun "sosyal" görünür | 3-4 gün | 24 kademe snapshot testi (tema paletiyle uyum); terfi töreni 60fps + haptic; tenzil kalkanı 1 kez çalışıyor; 336 test yeşili bozulmadı |
| **F2 — Dost + Meydan** | Friend Tag/QR, 3 REST ucu + 4 D1 tablosu; meydan kartı haritada; offline bot meydanı (LCG, "BOT" etiketli); sonuç otomatik mesajı | "Beat my score" — 13 oyunda olmayan çekirdek döngü | 4-5 gün | İki cihaz: kod ekle → meydan gönder → aynı seed açılıyor → iki taraf sonuç → otomatik mesaj; uçak-modunda bot meydanı tam akıyor; engel testi (blocked kullanıcı meydan açamıyor) |
| **F3 — Quick-chat + Eşzamanlı 1:1** | 32 hazırcümle + 5 tepki; Durable Object oda (presence + damga + canlı skor); HUD damga balonu | Kullanıcının istediği "aynı bölümde sohbet" | 5-6 gün | İki cihaz aynı odada: damga <300 ms; biri çıkınca bot devralıyor (etiketli); serbest metin YALNIZ sunucuda phraseId olarak doğrulanıyor (enjeksiyon testi); oyun içi balon odak/InputGate bozmuyor |
| **F4 — Bildirim + Güvenlik** | kırmızı nokta + sayaç, toast kuyruğu, meydan kartı akışı; şikâyet/engelle UI + D1; ebeveyn sohbet anahtarı; push (opt-in, çocuklarda kapalı) | mağaza onayının sigortası (Apple 1.2 dörtlüsü) | 3-4 gün | Apple 1.2 dört mekanizma demo kaydıyla belgeli; 22:00-08:00 sessiz; push opt-in dışı gönderilmiyor; engel/şikâyet uçtan uca test |
| **F5 — Uzak faz** | Serbest metin (moderasyon bütçesi oturunca: filtre + manuel inceleme SLA), sezon ligi takım modu, guild | — | haftalar | yalnız F0-F4 ölçümleri (meydan kabul oranı, sohbet kullanımı) elverirse |

**Ölçüm hedefleri (kabul sonrası izleme):** meydan gönderen oyuncu oranı >%10 (D1 sayacı); meydan kabul→oynama dönüşümü >%40; quick-chat günlük mesaj/aktif >1; D1/DO ücretsiz kota içinde kalma (aylık rapor).

**Kısıt muhasebesi:** C-002/C-017 dokunulmaz (sosyal tamamen meta katman); C-005 korunur (her şeyin offline botlu ikizi var); C-006 (yalnız CF ücretsiz katman); C-010 (push bile 3. parti adsiz FCM/APNs); C-012 (32 cümle + 8 rütbe adı Türkçe); C-014 (e-posta/isim/foto yok); TD-002 bu paketle çözülür (otomatik takma ad önerilir).

---

## 7. Kaynaklar

**Oyun/resmî kaynaklar**
- King Community — Candy Crush Milestone Badges: https://community.king.com/en/candy-crush-saga/discussion/414408/candy-crush-milestone-badges
- Candy Crush Solitaire Support — Weekly Leagues (Bronz→Elmas 5 lig): https://candycrushsolitaire.zendesk.com/hc/en-us/articles/34222473375645--Weekly-Leagues
- Dream Games Help — Royal Match Leaderboard: https://dreamgames.helpshift.com/hc/fa/3-royal-match/faq/286-what-is-leaderboard · Friends: https://dreamgames.helpshift.com/hc/ro/3-royal-match/faq/46-how-can-i-see-the-game-progress-of-my-friends · Communication Guidelines: https://dreamgames.helpshift.com/hc/nl/3-royal-match/faq/80-communication-guidelines · Team Battle: https://dreamgames.helpshift.com/hc/nl/3-royal-match/faq/109-team-battle/?p=ios
- Peak Games Help — Toon Blast team leaderboard: https://peakgames.helpshift.com/hc/en/4-toon-blast/faq/41 · Toon Blast Wiki (Teams): https://toonblast.fandom.com/wiki/Teams · r/ToonBlast team chat: https://www.reddit.com/r/ToonBlast/comments/sud2sm/team_chat
- Playrix Help — Gardenscapes Teams: https://playrix.helpshift.com/hc/en/5-gardenscapes/faq/3044-what-are-teams · r/Gardenscapes DM yok: https://www.reddit.com/r/Gardenscapes/comments/1u3po2w/do_you_think_playrix_will_ever_enable_private
- PeopleFun Help — Wordscapes Teams/Team League: https://peoplefun.helpshift.com/hc/en/20-wordscapes-solitaire/faq/818-what-are-team-league-tournaments · https://peoplefun.helpshift.com/hc/en/20-wordscapes-solitaire/faq/817-team-overview · Wordscapes Wiki (Star Tournament): https://wordscapes.fandom.com/wiki/Star_Tournament · Report cheating: https://peoplefun.helpshift.com/hc/en/6-wordscapes/faq/296-how-to-report-cheating/
- Sybo Help — Subway Surfers Top Run/Friends: https://sybo.helpshift.com/hc/en/5-subway-surfers/faq/207-top-run
- Supercell — Younger Players: https://support.supercell.com/mo-co/en/articles/younger-players.html · Clan Chat Filters: https://support.supercell.com/clash-of-clans/en/articles/clan-chat-filters-2.html · Parent's Guide: https://supercell.com/en/parents · r/ClashRoyale 16-altı sohbet kapalı: https://www.reddit.com/r/ClashRoyale/comments/1diru1q/if_you_cant_chat_because_you_put_your_age_as
- Brawl Stars ranked kademe/crest yıldız pips: https://boosting.games/blogs/guides/brawl-stars-ranked-guide · r/Brawlstars crest tartışması · Woodoku AMA (r/Woodoku): https://www.reddit.com/r/Woodoku/comments/xv9s5a/we_are_the_woodoku_product_team_ask_us_anything
- Survivor.io klan/co-op durum notları (r/Survivorio; Discord'a taşınan topluluk)

**Analiz kaynakları**
- Naavik — Get Social: Building Effective Clan Features: https://naavik.co/f2p-mobile/building-clan-features · Live Ops Trends Powering Mobile Puzzle: https://naavik.co/digest/live-ops-trends-powering-mobile-puzzle
- Deconstructor of Fun — Brawl Stars, to the moon!: https://www.deconstructoroffun.com/blog/2024/2/11/brawl-stars-to-the-moon · Clash Royale deconstruction: https://www.deconstructoroffun.com/blog//2016/02/clash-royale-next-billion-dollar-game.html
- GameRefinery — Mobile Game Market Review (sosyal hangout eğilimi): https://www.gamerefinery.com/mobile-game-market-review-november-2021
- PocketGamer.biz — top-grossing yeniden şekilleniyor: https://www.pocketgamer.biz/royal-kingdom-is-here-are-new-hits-reshaping-the-top-grossing-mobile-games-charts
- mobilegamer.biz — EU çocuk çevrimiçi oyun düzenleme önerisi: https://www.linkedin.com/posts/mobilegamerbiz_video-games-europe-warns-against-sweeping-activity-7506439583212003328-aOam
- Fake multiplayer / bot etiği: NYU JIPEL — AviaGames bot davası (2024): gizli bot litigation; r/gamedev "Is fake multiplayer allowed": https://www.reddit.com/r/gamedev/ (fake multiplayer thread); "Mobile Gaming: The Fake Multiplayer Epidemic" (LinkedIn, J. Jungck)

**Düzenleyici/Politika**
- Apple App Review Guidelines 1.2 (UGC: filtre+şikâyet+engelle+iletişim; 2026 Şubat anonim sohbet güncellemesi): https://developer.apple.com/app-store/review/guidelines · https://developer.apple.com/news/?id=d75yllv4
- Google Play Families policies: https://support.google.com/googleplay/android-developer/answer/9893335
- UK ICO Children's Code — Our work with mobile gaming services (Ağustos 2026; yabancı sohbeti yüksek riskli): https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/children-s-code-strategy-progress-update-august-2026/our-work-with-mobile-gaming-services · Freeths analizi: https://www.freeths.co.uk/insights-events/legal-articles/2026/ico-launches-scrutiny-of-children-s-privacy-practices-in-mobile-gaming
- ESRB — çocuk gizliliği/COPPA pratikleri: https://www.esrb.org/blog/what-parents-need-to-know-about-privacy-in-mobile-games-five-tips-for-your-parenting-toolkit

**Teknoloji dokümanları**
- Firebase RTDB (offline persistence, rules, Flutter): https://firebase.google.com/docs/database · Fiyat (100/200k bağlantı): https://firebase.google.com/pricing
- Supabase Realtime (broadcast/presence/RLS): https://supabase.com/docs/guides/realtime · Fiyat ($2.50/1M mesaj, $10/1k zirve bağlantı): https://supabase.com/docs/guides/realtime/pricing · Limitler: https://supabase.com/docs/guides/realtime/limits
- Cloudflare Durable Objects WebSocket Hibernation (faturalandırma, chat/multiplayer kullanım alanları): https://developers.cloudflare.com/durable-objects/best-practices/websockets/ · Ücretsiz plan (7 Nisan 2025, SQLite-backed): https://developers.cloudflare.com/changelog/post/2025-04-07-durable-objects-free-tier · Fiyat: https://developers.cloudflare.com/durable-objects/platform/pricing
- Flutter WebSocket (web_socket_channel resmî kitap): https://docs.flutter.dev/cookbook/networking/web-sockets
- Karşılaştırma literatürü: https://ably.com/compare/firebase-vs-supabase · https://justinmckelvey.com/blog/supabase-vs-firebase · r/Supabase zirve bağlantı fatura tuzağı: https://www.reddit.com/r/Supabase/comments/1fjhj05/
- Mario Kart Tour preset damga/sohbet yok (COPPA-uyumlu iletişim örneği): https://www.reddit.com/r/MarioKartTour/comments/1bx346x/
- NEON ARCADE "beat my score" aynı-bulmaca paylaşım bağlantısı (desen örneği): https://neonarcade.net/updates.html
