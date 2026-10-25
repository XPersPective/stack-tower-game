# STACK TOWER GAME — TASARIM V2: "DİYAR" (Antoloji Motoru + Görünür İnşaat Meta)

Tarih: 2026-10-25 · Tetikleyici: kullanıcı yönü — "her bölüm farklı OYUN içermeli;
yukarıdan bir şey düşürmek zorunda değiliz; bir amaç olmalı, amaç tamamlandıkça arkada
güzel bir şey inşa edilmeli; bağımlılık yapan kurgu; harika efektler."
Durum: Project Brain'e entegre (ADR-008/009 + PB-022..030). RESEARCH-market.md'nin
üzerine BİNEN ikinci araştırma turudur; önceki sürpriz/twist işi (PB-015) geçerliliğini
korur ama artık STACK türünün İÇ çeşitliliğidir.

---

## 1. TEŞHİS: Önceki tasarım neden yetmedi

Önceki tur (RESEARCH-market.md) aynı çekirdeğe **modifier** ekledi: hâlâ "yukarıdan
blok iner, dizmeye çalışırsın". Kullanıcının istediği bu değil — **çekirdek fiilin
kendisi** bölüm bölüm değişmeli. Pazar verisi bunu destekliyor: tek-düğme oyunları en
az 8 farklı fiil ailesine sahip (release/charge, aim-rotate, dodge/jump, switch,
context-sensitive, layered press; ayrıca stack/sort/merge/draw-line/timing/rise-fall
mekanik aileleri). Yani "tek dokunuş" kısıtı tek oyun türü demek DEĞİL.

İkinci eksik: **amaç**. Meta katmanı (koleksiyon, görünür inşaat) D3-D5'te oyunu
yeniden açmanın ASIL sebebi olmalı; bizde meta yalnız sayısal (yıldız/para) idi.

## 2. ARAŞTIRMA BULGULARI (tur 2)

### 2.1 Tek-girdi oyunlarda fiil aileleri
[Game Developer — One Button Games]: release/charge (güç biriktir-bırak), aim-rotate
(dönen nişanı kilitle), dodge/jump (zamanlama), switch/toggle (iki durum tek basış),
context-sensitive (aynı basış duruma göre farklı eylem), button-loading (bas=A,
bırak=B). Kural: **tutarlılık sadelikten önemli**; doğal kurallar (atalet, yerçekimi,
tork) katmanlanarak derinlik çarpanı olur; zamanlama pencereleri daralarak zorluk artar.

### 2.2 Mekanik aileleri
[Game-Ace]: Momentum (swerve/turn/stack), Progression (rise-fall/merge/idle),
Precision (draw-line/timing). Merge 2020 sonrası baskın hibrit arketip oldu — çünkü
basit çekirdek + meta katmanı oturumu uzatıyor. Pratik kısıt: **çekirdek döngü tek
girdi ve 3 saniyede okunur kalmalı; ek mekanik meta katmanında yaşamalı.**

### 2.3 Meta katmanı = tutunma motoru
[GGA Hybrid-Casual 2026]: D3-D5'te meta yeniden açma sebebi olmalı. Sistemler:
koleksiyon/galeri (tamamlama döngüleri), harita/bölüm ilerlemesi, sezonluk olaylar,
kozmetik, ve **home/village build** (uzun vadeli sahiplenme). "Görünür dekorasyon ve
inşaat, oyunculara çekirdek mekaniğin ötesinde kalıcı bir dönüş sebebi veren uzun
vadeli sahiplenme döngüleri olarak işlev görür." Katman sırası: **hook → session →
meta → ekonomi**. D7 benchmark ~%20 (başarılı hibrit-casual), pazar medyanı %3.4-3.9.

### 2.4 Juice yasaları
[BloodMoon]: her eyleme anında görsel+işitsel yanıt; **yoğunluk eylemin önemine
orantılı**; geri bildirim türlerini katmanla; **çeşitlilik alışkanlığı önler**;
fazla juice doygunluk yaratır.

### 2.5 Bağımlılık döngüsü psikolojisi (tur 1'den taşınan)
Beklenti > ödül (Appcues); değişken oran ödül doğrudan tutunmayı artırır (2025 JCM);
kısa+orta+uzun hedef merdiveni şart.

## 3. YENİ MİMARİ: DİYAR

### 3.1 A — Antoloji Motoru: her bölüm farklı OYUN
`GameKind` — 10 farklı oynanabilir oyun, hepsi tek dokunuşla:

| # | Tür | Çekirdek fiil | Oynanış (tek dokunuş) | Neden tatmin edici |
|---|---|---|---|---|
| 1 | **STACK** (mevcut) | bırak | Süzülen bloğu hizala | Görünür kule büyümesi, kırpma gerilimi |
| 2 | **CATCH** | kaydır/kaç | Düşen yıldızları yakala, bombalardan kaç (dokun = yön değiştir) | Toplama coşkusu + risk okuma |
| 3 | **RING** | durdur | Dönen halkanın hedef diliminde dokun (release/timing) | Tam isabet hazzı, pencere daralır |
| 4 | **LAUNCH** | nişan al-bırak | Dönen nişan + güç şarjı; hedefi vur (charge) | Fizik öngörüsü, tatmin edici patlama |
| 5 | **MERGE** | sürükle-birleştir | Aynı sayıları birleştir, hedefe ulaş | Görünür büyüme, "bir daha" hissi |
| 6 | **PATH** | çiz | Tek çizgiyle tüm düğümleri ziyaret et | Bulmaca çözümü, paylaşılabilir an |
| 7 | **SORT** | sırala | Renkleri doğru kutuya taşı | Düzen kurma tatmini |
| 8 | **BALANCE** | dengele | Dengeyi koru (bas = tarafa ağırlık ver) | Gerilim + mikro düzeltme |
| 9 | **DEFEND** | durdur | Gelen dalgayı doğru anda kalkanla kes | Kahramanlık anı, dalga ritmi |
| 10 | **RHYTHM** | ritme dokun | Vuruşlarda dokun (timing on beat) | Müzikal akış, kombo doruğu |

**Dağıtım yasası (C-020):** Ardışık aynı tür ≤1. Her dünyanın 15 bölümü 10 türün
döngüsüyle harmanlanır; dünya patronu (15. bölüm) o dünyanın imza türüdür.
**İlk 5 bölüm = 5 FARKLI tür** (hook): CATCH → RING → STACK → LAUNCH → MERGE.

### 3.2 B — Görünür İnşaat Meta: "Diyarı İnşa Et"
Kullanıcı gereksinimi: "amaç tamamlandıkça arkada o bölümde tamamlanan bir şey
görülmeli, çok güzel olmalı; birkaç aşamadan sonra hep bir şeyler tamamlanmalı."

**Üç hedef merdiveni:**
1. **Kısa (1 bölüm):** bölüm sonunda adada bir yapı parçası ANİMASYONLA yükselir
   (temel → duvar → çatı → ışık). Her bölüm = görünür bir katkı.
2. **Orta (3-5 bölüm):** bir yapı TAMAMLANIR (ev/kule/köprü/bahçe) — kutlama:
   konfeti + ışık dalgası + adaya kalıcı isim plakası. 3. bölüm sonrası PAZAR yeri
   açılır (ADR-007).
3. **Uzun (15 bölüm = dünya):** DÜNYA ANITI töreni — adanın merkezinde anıt yükselir,
   kalıntı kazanılır, takımada göğü aydınlanır. 10 dünya = **DİYAR TAMAM** finali:
   tüm adalar ışık köprüleriyle birleşir.

**Bekleme/merak:** haritada kilitli adada **inşaat planı (blueprint)** siluet olarak
görünür — "burada ne yükselecek?" merakı. Kilitli dünyalar sisli, ipuçlu (PB-019).

**Koleksiyon/galeri:** Ödül Odası genişler: 10 kalıntı + tamamlanan yapılar albümü +
takımyıldız parçaları (her dünya 1 takım yıldız çizgisi).

### 3.3 C — Efekt barı (harika efektler)
Juice yasaları uygulanır: her eyleme anında V+A; yoğunluk ∝ önem; katmanlı geri
bildirim; tür çeşitliliği alışkanlığı kırar. Somut: hit-stop, squash&stretch, renk
flaşları, parçacık cömertliği, kombo ses merdiveni, yapı yükselirken "inşaat"
efektleri (iskele → ışık → parıltı), dünya anıtında ekran geneli ışık dalgası.

### 3.4 D — Bağımlılık döngüsü
- Değişken oran ödül: her bölüm sonunda mini-sürpriz kapısı (PB-021).
- Seri/streak: günlük meydan okuma + 7 gün rozetleri (PB-020).
- Beklenti: blueprint önizleme + "sırada ne var" kartı.
- Kısa oturum: 3-6 dakika (GGA), her oturumda en az 1 tamamlanma hissi.

## 4. TEKNİK MİMARİ

```
lib/game/
  kinds/                 # YENİ: antoloji motoru
    game_kind.dart       # GameKind enum + KindSpec (isim, ikon, ipucu, renk)
    stack_game.dart      # mevcut gameplay.dart sarmalanır
    catch_game.dart      # düşenleri yakala
    ring_game.dart       # dönen halka zamanlama
    launch_game.dart     # nişan + şarj
    merge_game.dart      # birleştir
    path_game.dart       # tek çizgi
    sort_game.dart       # sırala
    balance_game.dart    # denge
    defend_game.dart     # savun
    rhythm_game.dart     # ritim
  mini_game.dart         # MiniGame arayüzü: start/tick/render/onTap/result
  levels.dart            # kindFor(i) dağıtım yasası eklenir
lib/screens/play_screen.dart  # MiniGame host: türü seçer, ortak HUD
lib/map/construction.dart     # yapı parçaları + yükselme animasyonu + blueprint
```

**MiniGame sözleşmesi** (tüm türler aynı arayüz — play_screen tür-agnostik):
```dart
abstract class MiniGame {
  GameKind get kind;
  void resize(double w, double h);
  void start(LevelDef def, MiniGameHost host);
  void tick(double dt);
  void onTap(Offset local);
  void render(Canvas canvas, Size size);
  MiniGameResult result();   // {blocks/points, perfects, reached, crits...}
  bool get isOver;
}
```
Ortak: hedef (def.target), mükemmel sayacı, kalkan, ses/efekt kancaları, sonuç
payload'ı → GameSession.onWin/onLose (ekonomi değişmez).

## 5. UYGULAMA SIRASI
| Görev | Kapsam |
|---|---|
| PB-022 | MiniGame arayüzü + GameKind kaydı + play_screen host + STACK sarmalayıcı (regresyon yok) |
| PB-023 | CATCH oyunu (düşen yıldız/bomba, yön değiştirme, yakalama efektleri) |
| PB-024 | RING oyunu (dönen halka, hedef dilim, daralan pencere) |
| PB-025 | LAUNCH oyunu (dönen nişan + şarj, hedef patlatma) |
| PB-026 | MERGE oyunu (sürükle-birleştir, hedefe ulaş) |
| PB-027 | PATH + SORT oyunları |
| PB-028 | BALANCE + DEFEND + RHYTHM oyunları |
| PB-029 | Görünür inşaat meta: yapı parçaları, yükselme animasyonu, blueprint, dünya anıtı |
| PB-030 | kindFor dağıtım yasası + ilk-5 hook şeması + testler + cömert ödül ayarı |

## 6. KAYNAKLAR (tur 2)
- [Game Developer — One Button Games](https://www.gamedeveloper.com/design/one-button-games)
- [Game-Ace — Hyper-Casual Game Mechanics](https://game-ace.com/blog/hyper-casual-game-mechanics)
- [GameGrowthAdvisor — Hybrid Casual 2026 Strategy](https://gamegrowthadvisor.com/blog/2026-04-16-hybrid-casual-game-design-strategy-2026)
- [BloodMoon — Juice in Game Design](https://www.bloodmooninteractive.com/articles/juice.html)
- Tur 1 kaynakları: RESEARCH-market.md §7
