# RESEARCH: Blok Görselliği — "Kristalize Işıyan Yapılar" Derin Araştırma (2026-11)

- **Tarih:** 2026-11-02
- **Soru:** "Tuğla çok basit, parlatılmış olsun, küp/üçgen gibi değişik şekiller gelsin, tuğla oyununa sıkışıp kalmasın, kristalize ışıyan yapılar olsun." (App Store premium hedefi)
- **Yöntem:** Geniş web araştırması — üst sıralama oyunları (Stack, Stack Ball, Helix Jump, Cube Surfer, Tower Crusher, Stack Colors!, Slice It All!, Ball Stack 3D), premium puzzler'lar (Tetris Effect, Monument Valley, Alto's Odyssey), poliomino variantları (Block Blast!, Woodoku, Hexa Sort, Tetris Blitz), fizik variantı (Tricky Towers), gömülü shader tekniği kaynakları (fresnel, thin-film, bloom taklidi) ve Flutter render belgeleri (FragmentShader, Impeller, saveLayer maliyeti).
- **Mevcut kod gerçeği (doğrulandı):** `lib/game/scene_painter.dart` `_drawBlock` (satır 727–841) — 3-duraklı linear gradyan ön yüz + statik beyaz spec bandı + bevel çizgi + neon kontur + 4 şekil patikası (PB-036: klasik/silindir/altıgen/kama, yalnız görsel) + ateş modu glint + bossTop çift kontur. Juice paketi (PB-016) ve sunum katmanı (PB-033: Picture LRU önbelleği, plus-blend halkalar, ateş izi) hazır.
- **İlgili kısıtlar:** C-002 (drop_core paritesi dokunulmaz), ADR-002 (CustomPainter motoru, Flame yok), C-001 (kalite tabanı), PB-033 LOD/önbellek altyapısı.

---

## 1. Yönetici Özeti

> **Bulgu:** Mevcut blok, hiper-casual standartlarının ÜSTÜNDE (tablo puanı 37/60) ama "kristal" hissinden uzak — çünkü blok **ışık yansıtan plastik** gibi çiziliyor, **ışık yayılan mineral** gibi değil. Kristal hissi tek bir efektle gelmez; 5 katmanın (facet + iç çekirdek + fresnel rim + canlı glint + bloom dışaşımı) birlikte çalışmasıyla gelir.
>
> **Tavsiye özeti:** (1) `_drawBlock`'a hue-shifted facet + iç ışık çekirdeği + fresnel rim (CustomPainter, sıfır bağımlılık); (2) moving block için tek FragmentShader hero versiyonu (iridescence + glint sweep); (3) bloom taklidi için blok başına halo değil, **kule başına tek plus-blend geçişi** (saveLayer ≤ 2/frame).

---

## 2. Kıyaslama Tablosu (17 oyun × K1–K6)

Puan 1–10. K1 blok madde hissi (kristal/metal/ahşap derinliği) · K2 çeşitlilik (farklı blok görünümü/türü sayısı) · K3 ışık/parıltı kalitesi (bloom, rim light, iç ışık) · K4 parçacık/iz efekti (trail, kırılma, toz) · K5 tema-blok uyumu (dünya teması bloğa yansıyor mu) · K6 perf sinyali (60fps iddiası).

| # | Oyun | K1 | K2 | K3 | K4 | K5 | K6 | Top | Gerekçe (kısa) |
|---|------|----|----|----|----|----|----|-----|----------------|
| 1 | **Stack** (Ketchapp, 2017) | 5 | 3 | 4 | 5 | 4 | 10 | **31** | Blok düz plastik ama **hue-döngüsü kuleyi ilerleme çubuğuna çevirir**; perfect halkası + düşen dilim fiziği; ışık/rim yok — sadelik zirvesi |
| 2 | **Stack Ball** (AZUR, 2018) | 4 | 4 | 5 | 8 | 3 | 10 | **34** | Mat diskler; **fire mode glow** tehlike ödül döngüsü taşır; siyah blok = okunur tehlike dili; patlama parçacıkları doygun |
| 3 | **Helix Jump** (Voodoo, 2018) | 4 | 3 | 5 | 8 | 3 | 10 | **33** | Top trail + fireball + platform kırılması taşıyan juice; diskler mat, madde hissi yok |
| 4 | **Cube Surfer** (Voodoo, 2020) | 3 | 2 | 3 | 5 | 3 | 10 | **26** | Tek mavi küp, tek görünüm; mekanik (kule binme/büzülme) güzelse de görsel en zayıf ucu |
| 5 | **Tower Crusher** (Voodoo) | 3 | 3 | 4 | 8 | 3 | 10 | **31** | Yıkım parçacığı dolu, blok kimliği yok — "satisfying" parçalanma anına yaslanır |
| 6 | **Stack Colors!** (Voodoo) | 3 | 4 | 3 | 6 | 6 | 10 | **32** | Renk eşleştirme oyunun kimliği olduğundan K5 tavan-vari; blok görünümü yine düz |
| 7 | **Slice It All!** (Voodoo) | 4 | 3 | 3 | 8 | 3 | 10 | **31** | Dilimleme kesiti efekti temiz; bloklar düz — kesit anı dışında bellek yok |
| 8 | **Ball Stack 3D** klon ailesi | 3 | 3 | 4 | 7 | 2 | 10 | **29** | ASMR yıkım + tekrar; tema-blok uyumu düşük, klonlar kimliksiz |
| 9 | **Tetris Effect** (Monstars/Enhance, 2018) | 8 | 8 | 10 | 10 | 10 | 6 | **52** | **Tablonun zirvesi**: her aşamanın bloğu farklı materyal (cam, metal, ışık kümesi); HDR bloom + her girdiye reaktif parçacık + müzik senkronu; K6 düşük çünkü konsol/PC hedefli, mobil Connected 60fps ama sahne pahalı |
| 10 | **Tetris Blitz** (EA, 2013) | 4 | 6 | 6 | 8 | 5 | 7 | **36** | Fever mode patlamaları + power-up görsel dili güçlü; blok materyali ise standart |
| 11 | **Tricky Towers** (WeirdBeard, 2016) | 6 | 5 | 4 | 7 | 5 | 7 | **34** | **Gerçek fizik tetromino**: sallanma/devrilme görsel gerilim üretir; blok dokusu temiz ama parlaklık kısık; tek oyunda "şekil=mekanik" dersinin kaynağı |
| 12 | **Monument Valley** (ustwo, 2014) | 9 | 8 | 6 | 4 | 10 | 8 | **45** | **Materyal hissi zirvesi**: düz renkli yüzeyler ama hue-shifted hacim; her bölüm bir anıt; bloom yok — ışık-derece (L) disiplini parıltıyı aratmıyor; parçacık az |
| 13 | **Alto's Odyssey** (Team Alto, 2018) | 5 | 6 | 9 | 6 | 10 | 9 | **45** | Blok oyunu değil ama **dinamik ışık/gündüz-gece döngüsü** ve atmosfer-biyoçeşitlilik dersinin en iyisi; zemin/sahne malzemesi (kum, su) canlı |
| 14 | **Block Blast!** (Hungry, 2021; 368M indirme/yıl) | 5 | 6 | 5 | 7 | 3 | 10 | **36** | Canlı gradyanlı küpler + satır temizleme glow'u; sistem/mühendislik hiti — görsel değil, retansiyon kazandırdı (Deconstructor of Fun) |
| 15 | **Woodoku** (Tripledot) | 8 | 6 | 3 | 5 | 8 | 10 | **40** | **Ahşap malzeme dersi**: doku + bevel ile "sıcak materyal" hissi parıltısız kurulur; tema tutarlığı yüksek |
| 16 | **Hexa Sort** (2024 dalgası) | 5 | 4 | 4 | 6 | 4 | 10 | **33** | Parlak plastik altıgenler; altıgen formun kule temasında "crystal" çağrışımı; madde hissi orta |
| 17 | **Stack Tower Game — mevcut** (PB-036) | 4 | 6 | 5 | 7 | 6 | 9 | **37** | Hiper-casual ortalamasının üstü: 4 şekil + boss konturu + juice paketi; ama blok hâlâ **yansıyan plastik** (bkz. §4) |

**Okuma:** Hiper-casual ailesi (1–8, 14, 16) K4/K6'da tavan, K1/K3'te tabandadır — "juice var, madde yok." Premium uç (9, 12, 13) bunun tersini yapar. Stack Tower'ın boşluğu tam burada: **K1 +3 ve K3 +4 puanlık kristal katmanı**, mevcut K4/K6'yı bozmadan eklenebilir (§4–§5'teki tarif 60fps bütçesiyle bunu hedefler).

---

## 3. En İyiler Nasıl Yapmış — Teknik Döküm

### 3.1 Stack — hue-döngüsü (kule = ilerleme çubuğu)
- **Teknik:** Her blok `hue(t) = baseHue + i·ΔHue` ile HSL kanalında küçük sabit adım kayar; ön/yan/üst yüzler **aynı hue, farklı L** ile hacim sahteler. Gökyüzü gradyanı aynı döngüyü takip eder — kule ve dünya tek renk sistemine kilitlidir. Graphic Design StackExchange dekonstruksiyonu bu sistemin "döngüde hue artırma" olduğunu doğruluyor.
- **Neden tatmin edici:** Renk pasif bir ilerleme çubuğu; kaybetmek bile görsel olarak "buraya kadar geldim" der.
- **Flutter karşılığı:** Bizde zaten `blockHue(i)` + `levelSignature(i)` palet fazı var (PB-033). **Eksik olan:** gradyan stoplarının hue'su sabit (AŞAMA 1'de düzeltilir) ve gökyüzü-blok aynı döngüde değil (levelSignature'ı `AuroraBackground` ile paylaşmak tek satır işi).

### 3.2 Tetris Effect — shader parıltısı (HDR bloom zinciri)
- **Teknik:** Bloklar **emissive** (HDR değeri > 1) çizilir; post-process bloom sadece eşiği aşan pikselleri bulanıklaştırıp ekran üstüne **additive** ekler; parçacık ve ışık darbeleri müzik tempo haritasına bağlı; her girdi sahneden yanıt alır (Mizuguchi'nin GDC 2019 "Making Tetris Effect-ive" sunumu: hedef "flow" durumu). O kadar yoğun ki Steam'de parçacıkları kapatan oyuncular var — doygunluk sınırı dersi.
- **Flutter karşılığı:** Gerçek HDR bloom pipeline'ı yok; 4 taklit yolu:
  1. **Additive geçiş:** `canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.plus)` → ışık çizen parçaların üstüne normalde çizilemeyecek parlak haleler → restore. **Kural: karede ≤ 2 saveLayer** (Impeller'da saveLayer kare-başı offscreen hedef açar — raster thread'i yorar; mevcut popup LRU önbelleği doğru yönde).
  2. **Önceden bulanık glow sprite:** `Picture.toImageSync` ile hue-signature başına bir kez radial glow üret → kule alt bloklarına `drawImage` (tek dokunuş). En ucuz.
  3. `MaskFilter.blur` tek draw başına (küçük yarıçap ucuz, büyük pahalı).
  4. **Impeller-only:** `ImageFilter.shader` — BackdropFilter ile sahneye gerçek bloom benzeri geçiş; ama API 29+ şartı → şimdilik kaçın (§6).
- **Ders:** Bloom yoğunluğu **olaylara** (mükemmel/kritik/final) bölünmeli; sürekli açık bloom gözü yorar ve premium'u ucuzlaştırır.

### 3.3 Monument Valley — materyal hissi (hue-shifted flat shading)
- **Teknik:** Blok düz renklidir ama yüzler arasında **hue da kayar**: üst yüz = `H+8, L+14`; ön = `H, L`; gölge yan = `H−10, L−20` (Japanese woodblock + Escher disiplini: tek ışık yönü, sıfır speküler). "Parlatma" değil **renk derecelendirmesi** ile hacim. ustwo'nun kendi yazısı: hedef "etkileşimli Escher baskısı".
- **Neden premium:** Tutarlı ışık yönü + dünyaya özel palet → her ekran bir baskı.
- **Flutter karşılığı:** 3 Paint yeter; bizim 3-duraklı gradyan (L 66→54→40, hue sabit) MV'nin tekliğine yakın ama **hue kayması eksik** — bu tek değişiklik bile bloğu "cila"dan "mineral"e taşır.

### 3.4 Kristalın 4 çekirdek shader deseni (3D → 2D çeviri)
| Desen | 3D tanımı | 2D/Flutter karşılığı |
|-------|-----------|----------------------|
| **Fresnel rim** | `rim = pow(1 − \|dot(N, V)\|, p)` — bakış açısına paralel yüzeyler parlar (Kyle Halladay temel ders; Linden Reid rim highlight) | Kenara yakınlık = SDF. Pratik: (a) dış halo — `drawPath` stroke + `MaskFilter.blur` + `plus`; (b) iç rim — `clipPath(front)` içinde stroke: yarı dışı kırpılır, iç kenarda ince parlak hat kalır; FragmentShader'da `d = min kenar mesafesi; rim = pow(1 − d/maxD, 3)` |
| **Specular band** | Dar glossy highlight, ışık vektörüne dik | Diagonal (≈24°) bant + zamanla süpüren dar glint şeridi — **statik spec = plastik, süpüren spec = cam** |
| **Noise-kırılım / iridescence** | Thin-film: hue, `sin(kalınlık / dalga-boyu)` ile kanal başına kayar (Zucconi car-paint; GShade ThinFilm.fx) | `t = noise(uv·k + time)` → **IQ cosine paleti** `col = a + b·cos(2π(c·t + d))` → taban rengin %15–20'si kadar karıştır. Shadertoy "holographic" örnekleri birebir taşınabilir |
| **Facet** | Düz normalli düşük-poli mücevher (80 Level faceted gemstone) | Ön yüzü 2–3 düzleme böl; her düzleme farklı L (±6) ve ±4 hue — düşük-poli gem görünümü, deterministik (seed = blok indeksi) |

### 3.5 Woodoku — madde hissi parıltısız da kurulur
Ahşap doku + bevel bandı + mat kenar → "sıcak malzeme". Ders: **her dünya kristal istemez**; orman/ahşap dünyasında parlaklık kısılmalı, dokuya kayılmalı (K1 puanı 8'i bundan aldı). Kristal katman parametrik olmalı: dünya → malzeme profili (§5.2).

### 3.6 Block Blast! — çeşitlilik ucuzsa çeşitli değil
368M indirme/yıl; görsel kimliği "canlı gradyan küp"tekiler ötesine geçmez — sistemi kazandı. Ders: **şekil/malzeme çeşitliliği mağaza ekranını ve ilk 10 saniyeyi satar**, ama yeni görünüm每 dünya + boss başına anlamlı olmalı; blok başına 20 skin kirlilik üretir.

---

## 4. Eleştiri + DAHA İYİSİ: Mevcut Bloktan Kristal Bloğa

### 4.1 Mevcut `_drawBlock` (scene_painter.dart:727–841) nerede eksik?
Var olanlar: 3-duraklı linear gradyan (aynı hue, L 66→54→40) · statik beyaz spec bandı (üst %42) · beyaz bevel çizgi · ateş modu gezinen glint · neon kontur (L82, α0.45, uniform) · bossTop ikinci kontur · üst yüz gradyanı + "iç ışık çizgisi" · 4 şekil patikası (PB-036).

| # | Eksik | Sonucu (oyuncunun algısı) |
|---|-------|---------------------------|
| 1 | **Hue kayması yok** — gradyan stopları aynı hue, yalnız L değişir | "Sabun/PLA baskı" hissi; Stack ve MV bile shading'de hue kaydırır |
| 2 | **Spec bandı tek ve statik** — ışık kaynağı kavramı yok, açı yok, hareket yok | Ekran görüntüsü ile canlı görüntü ayırt edilemez → "basit" damgası |
| 3 | **Fresnel rim yok** — siluet kenarı zeminden ton farkıyla değil yalnız konturla ayrışır | Neon kontur **çizgi gibi** davranır, ışık gibi değil (uniform alpha, blur yok); kristal kenarı kendinden parlar |
| 4 | **İç ışık yok** — blok yalnız yansıtıyor; ışık **içeriden** gelmiyor | Kristal = transmisyon; olmadığında blok "boyalı kutu" kalır |
| 5 | **Facet yok** — ön yüz tek düzlem | Düşük-poli mücevher okuması imkânsız; "kristalize" hissin birincil imzası budur |
| 6 | **Blok-blok temas AO'su yok** | Bloklar birbirine "yapışık yüzer" görünür; kule katman derinliği kaybolur |
| 7 | **Bloom dışaşımı yok** (blok başına) | Işık konturdan taşmaz → glow yalnız tower-beam ve fx'te var, bloğun kendisinde yok |

### 4.2 Adım adım "Kristalize Işıyan Blok" tarifi — CustomPainter (sıfır bağımlılık)

Tüm değişiklik `_drawBlock` içine; hitbox/drop_core'a dokunulmaz (C-002).

**AŞAMA 1 — Hue-shifted malzeme paleti** (MV dersi; #1 düzeltir)
```dart
// ön yüz stopları: L ile birlikte H de kayar
final topC = hslColor(hue + 6, 92, 72);
final midC = hslColor(hue, 95, 58);
final botC = hslColor(hue - 8, 86, 38);
```

**AŞAMA 2 — İç ışık çekirdeği** (kristal ışığı içeriden; #4)
```dart
// frontPath clip İÇİNDE, merkez-üstte radial core, plus blend
canvas.save(); canvas.clipPath(frontPath);
canvas.drawRect(rect, Paint()
  ..blendMode = BlendMode.plus
  ..shader = ui.Gradient.radial(
    Offset(x + w / 2, y + h * 0.35), w * 0.75,
    [hsla(hue, 100, 85, 0.50), hsla(hue, 95, 60, 0.12), hsla(hue, 0, 0, 0)],
    const [0, 0.55, 1]));
```

**AŞAMA 3 — Facet düzlemleri** (düşük-poli gem; #5)
```dart
// diyagonal bölme: sol düzlem açık, sağ düzlem koyu (deterministik i seed'li yön)
final facet = Path()
  ..moveTo(x + w * 0.62, y)..lineTo(x + w * 0.46, y + h)
  ..lineTo(x + w, y + h)..lineTo(x + w, y)..close();
canvas.drawPath(facet, Paint()..color = hsla(hue + 3, 90, 64, 0.55));
canvas.drawLine(Offset(x + w * 0.62, y), Offset(x + w * 0.46, y + h),
    Paint()..color = hsla(hue, 100, 90, 0.30)..strokeWidth = 0.8); // facet kenarı
```

**AŞAMA 4 — Fresnel rim (dış halo + iç kenar)** (#3)
```dart
// dış: blur'lu stroke, plus — bloğu çevreleyen ince ışık
canvas.drawPath(frontPath, Paint()
  ..color = hsla(hue, 100, 80, 0.30)..style = PaintingStyle.stroke
  ..strokeWidth = 2.5 * e.scale
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
  ..blendMode = BlendMode.plus);
// iç: clip altında stroke → dış yarısı kırpılır, iç kenarda parlak hat
canvas.drawPath(frontPath, Paint()
  ..color = hsla(hue, 100, 88, 0.35)..style = PaintingStyle.stroke
  ..strokeWidth = 2 * e.scale); // clip hâlâ açık
```

**AŞAMA 5 — Spec bandı 2.0: diyagonal + süpüren glint** (#2)
```dart
// mevcut dikey bandı ~24° diyagonale çevir (Offset(x+w*0.7, y) → Offset(x+w*0.3, y+h*0.55))
// üstüne deterministik kayan dar glint:
final t = (e.time * 0.45 + i * 0.37) % 1.0;
final gx = x + w * (0.12 + 0.76 * t);
// genişlik w*0.06, alpha 0.5·sin(π·t) — giriş-çıkış yumuşak, plus blend
```

**AŞAMA 6 — Kırılım glint (yıldız)** — facet kenar kesişiminde 2 kısa beyaz çizgi (+ biçimi), `blur 2`, plus; parlaklık `0.4 + 0.4·sin(2π·time·0.8 + hash(i))`. (Mevcut ateş glint'i genel forma genişletilir.)

**AŞAMA 7 — Temas AO** (#6) — üstteki bloğun tabanında, altındaki bloğun üst kenarına 3–4 px koyu bant (α 0.16, `blur 1`): katman ayrımı okunur.

**AŞAMA 8 — Bloom taklidi, kule ölçeğinde** (#7)
- **Halo (ucuz yol):** her görünür üst blok için blok arkasına radial halo (`plus`, radius ≈ w·1.15, α ~0.14) — saveLayer'sız, plus tek geçişte birikir.
- **Tören anı (pahalı yol, karede 1 kez):** `saveLayer(bounds, plus)` → glow katmanı (halo'lar + ateş izi + perfect halkası) → restore. Mükemmel/kritik anlarında α'yı pop yap.
- **LOD (perf yasası):** üst 3 blok + moving = tam kristal (A1–A6); alt bloklar = A1+A7 + **Picture önbelleği** (PB-033 LRU'ya hue-signature anahtarıyla) — kule 50 blok olsa da kare maliyeti sabit. Kırpılmayan kule bloklarında blur'lu kontur çizmeyin: `shouldRepaint` her tik true olduğundan her tik yeniden çizilir.

**AŞAMA 9 — FragmentShader hero versiyonu (yalnız moving block)**
Dosya: `shaders/crystal_block.frag`; pubspec `flutter: shaders:`; `FragmentProgram.fromAsset` main'de precache; **shader örneği bir kez yaratılıp yeniden kullanılır** (resmî perf notu).
```glsl
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;   // blok px
uniform float uTime;
uniform float uHue;   // 0..1
uniform float uGlow;  // combo/ateş 0..1
out vec4 fragColor;
// hsl2rgb, hash, value-noise yardımcıları (Book of Shaders kalıbı)
void main() {
  vec2 p = FlutterFragCoord() / uSize;              // 0..1
  vec3 base = hsl2rgb(vec3(uHue + (p.y - 0.5) * -0.05, 0.9,
                           mix(0.70, 0.38, p.y)));   // A1: hue-shifted gradyan
  float facet = smoothstep(0.46, 0.54, fract(p.x * 1.2 + p.y * 0.35));
  base = mix(base * 1.12, base * 0.86, facet);        // A3: iki düzlem
  float d = min(min(p.x, 1.0 - p.x) * uSize.x,
                min(p.y, 1.0 - p.y) * uSize.y);
  float rim = pow(1.0 - clamp(d / (uSize.y * 0.5), 0.0, 1.0), 3.0);
  float core = exp(-6.0 * dot(p - vec2(0.5, 0.35), p - vec2(0.5, 0.35)));
  core *= 0.75 + 0.25 * sin(uTime * 2.0);             // A2: nefes alan iç ışık
  float iri = 0.15 + 0.85 * noise(p * 3.0 + uTime * 0.08);
  vec3 irid = 0.5 + 0.5 * cos(6.28318 * (iri + vec3(0.0, 0.33, 0.67))); // IQ paleti
  float sweep = smoothstep(0.06, 0.0, abs(fract(p.x * 0.8 - uTime * 0.25) - 0.5));
  vec3 c = base + rim * vec3(1.0) * 0.35 + core * 0.45
         + irid * iri * 0.18 + sweep * 0.25;
  fragColor = vec4(c * (1.0 + uGlow * 0.5), 1.0);
}
```
Dart tarafı: `Paint()..shader = shader` ile blok rect'ine `drawRect`; uniform'ları her tikte `setFloat` (uSize/uHue ucuza). Path şekilleri (altıgen/kama) shader'ın ÜSTÜNE normal katman olarak çizilir — shader tam dikdörtgeni kaplar, alpha kenarı için shader'ın kendi SDF'i clip'e gerek bırakmaz (kenar rim zaten kenarı tanımlar).

**Perf bütçesi (özet):** karede ≤ 2 saveLayer · blur yarıçapı ≤ 6 (blok ölçeğinde) · alt kule = cached Picture · FragmentShader yalnız 1 blok · `toImageSync` halo sprite'ları signature başına 1 kez. Bu bütçe mevcut PB-033 mimarisiyle (RepaintBoundary + LRU) 60fps hedefiyle uyumlu; Impeller (3.29+ varsayılan) shader-derleme takılması riskini taşıyor.

---

## 5. Şekil Varyantları: Görsel mi, Mekanik mi?

**Mevcut karar (PB-036) doğrudur: şekil = yalnız görsel, hitbox dikdörtgen.** Gerekçeler:
1. Tricky Towers'ın "gerçek fizik" kulesi (sallanma, kayma, devrilme) drop_core matematik paritesini kırar → C-002 ihlali; ayrıca fizik parametreleri JS referansına bağlı test güvencesini boşaltır.
2. Blok Puzzle Collection/Hexa Sort ekosistemi gösteriyor ki **biçim çeşitliliği hitbox bağımsız** tedarik edilebilir; Tricky Towers dersi ("şekil=gerilim") bizde zaten twist sistemiyle (rüzgar, zıt, daralan duvar) **mekanik düzeyde** karşılanıyor — ikinci mekanik katman gereksiz.
3. PB-036'daki 4 patika (klasik/silindir/altıgen/kama) + bossTop zaten görsel çeşitlilik omurgası; eksik olan şekil sayısı değil, şekillere **malzeme ruhu** giydirmek (§4).

**Öneri: Dünya → Şekil + Malzeme profili (parametrik kristal katman)**

| Dünya örnekleri | Şekil (patika) | Malzeme profili | Zorluk rolü |
|---|---|---|---|
| Buz/Kristal dünyaları | Altıgen (2) | facet yüksek, rim güçlü, hue soğuk; kırılma partikülü cam tonu | Görsel okunabilirlik tavan — yeni oyuncu dünyası |
| Lav/Obsidyen | Kama (3) | **koyu mat kabuk + turuncu iç çekirdek** (magmacore), rim zayıf | "Kesit" anlatısı: kama = magma görünen dilim |
| Orman/Ahşap | Klasik (0) | Woodoku dersi: bevel + doku hissi, **parıltı kısık** | Kontrast dünyası: kristal doygunluğundan soluklaşma |
| Gökyüzü/Bulut | Silindir (1) | yumuşak rim, düşük doygunluk, halo geniş | Hafiflik hissi |
| Uzay/Kozmik + Boss | Klasik + **elmas (rombus)** | iridescence (IQ paleti) + çift kontur (mevcut bossTop) | Premium şov dünyası; boss = tam shader hero |

- **Elmas (rombus):** yeni patika; üst-alt sivri — hitbox aynı, görsel "değerli taş" çağrışımı en güçlü form. Patron/bonus bloklara ayır.
- **Halka: blok olarak önerilmez** — stack hitbox'ı dolu dikdörtgenken görselde delik "sahte fizik" sinyali verir (oyuncu içinden geçeceğini sanır). Halka zaten RING mini-oyununun ve ödül/hedef objelerinin dili; orada doğru.
- **Zorluk etkisi:** şekil çeşitliliği zorluğu değil **öğrenme eğrisini** taşısın: dünya 1–2 yalnız klasik (öğretici netliği), 3+ altıgen, 5+ kama, 7+ elmas/iridescence. Şekil değişimi bölüm imzasına (`levelSignature.shape`) bağlanır — mevcut alan, 15 bölümün palet fazı gibi.

---

## 6. Flutter Paket / Teknoloji Önerileri (2025–26)

| Araç | Bu proje için karar | Gerekçe / maliyet |
|---|---|---|
| **dart:ui FragmentShader** | **EVET — hero blok için** (§4.2 A9) | Sıfır bağımlılık, `Paint..shader` CustomPainter'a birebir oturur (docs). Kurallar: `FragmentProgram` precache + shader örneğini yeniden kullan; sadece float uniform + `sampler2D`; `FlutterFragCoord()` kullan (`gl_FragCoord` değil); renkler premultiplied. Maliyet: 1 GPU pass — ihmal edilebilir |
| **`flutter_shaders` / `glow_effects` paketi** | HAYIR (prod) / prototipte opsiyonel | Sarmalayıcı konfor; API zaten 20 satır — bağımlılık gereksiz |
| **CustomPainter + plus blend + MaskFilter.blur** | **EVET — birincil glow aracı** (A2/A4/A8) | Ucuz ve mevcut mimariye tam oturur; **saveLayer ≤ 2/kare** (Impeller saveLayer = offscreen hedef). Impeller'da blend+opacity kuşkusu bilinen tuzak (flutter#126532): alpha'yı renkte değil katmanda yönet |
| **`Picture.toImageSync` glow sprite** | **EVET** — alt kule halo'ları | Signature başına 1 kez üret → `drawImage`; En ucuz bloom taklidi |
| **ImageFilter.shader (BackdropFilter)** | ŞİMDİLİK HAYIR | Impeller-only (API 29+; altı throwing) — minSdk/fallback yükü; gerçek bloom ihtiyacı doğarsa ayrı PB |
| **Flame** | HAYIR | ADR-002: mevcut motor tik/efekt havuzlu; Flame'in ParticleSystem'i motor değişimi pahasına gelmez. FX genişlerse mevcut FX havuzuna yeni emitter kalıbı (PB-016 konfeti örneği) yeter |
| **Rive** | HAYIR (oyun içi) / menü-tören sinematiğinde opsiyonel | Vektör-kemik animasyon CPU raster'ı kare-başı blok çiziminden pahalı; kristal "canlılık" proc edeyim zamanla (u_time) — Rive'in işi değil |
| **Impeller** | Zaten varsayılan (3.29+) | Shader-derleme jank ölü; yine de perf overlay ile frame pacing izle |

---

## 7. Kabul Kriterleri — "Kristal Hissi Testi" (5 madde)

1. **Siluet testi (fresnel):** Ekran görüntüsünü gri tonlamaya çevir — üst bloğun kenarı zemin/siluetten **kontur çizgisi olmadan** bile ayrışmalı. Ayrışmıyorsa rim yetersiz.
2. **Merkez parlaklık testi (iç ışık):** Bloğun en parlak noktası üst-sol köşe **DEĞİL**, merkez-üst olmalı. Üst-sol en parlaksa blok "plastik yansıma", merkez parlaksa "ışık geçiriyor" okunur.
3. **Düzlem sayımı (facet):** Bloğa zoom — en az **2 farklı aydınlıkta düzlem** ayırt edilmeli. Tek düzgün gradyan görünüyorsa facet katmanı başarısız.
4. **3 saniye canlılık testi (glint):** Blok dururken 3 sn izle — glint/parıltı konumu veya yoğunluğu **en az bir kez** değişmeli. Hiç değişmiyorsa "statik etiket" hissi (Tetris Effect dersi: ışık canlıdır).
5. **Bloom dışaşımı + perf:** Mükemmel dizilişte ışık blok konturundan **dışarı taşmalı** (halo) ve DevTools perf overlay **yeşil kalmalı**. Taşma yoksa glow cılız; fps düşüyorsa LOD/saveLayer bütçesi (§4.2) aşılmış demektir.

---

## 8. Kaynaklar

**Teknik shader/malzeme:**
- Kyle Halladay — Fresnel Shaders From The Ground Up: https://kylehalladay.com/blog/tutorial/2014/02/18/Fresnel-Shaders-From-The-Ground-Up.html
- Linden Reid — Rim Highlight in Unity: https://lindenreidblog.com/2018/03/03/rim-highlight-in-unity
- Alan Zucconi — Thin-Film Interference (iridescence): https://www.alanzucconi.com/2017/10/27/carpaint-shader-thin-film-interference
- GShade ThinFilm.fx (GLSL referans): https://github.com/Mortalitas/GShade/blob/master/Shaders/ThinFilm.fx
- 80 Level — Real-Time Faceted Gemstone in Unity: https://80.lv/articles/beautiful-real-time-faceted-gemstone-in-unity
- Unity Shader Graph — Fresnel Effect Node: https://docs.unity3d.com/Packages/com.unity.shadergraph@17.4/manual/Fresnel-Effect-Node.html
- Agate Dragon — Shadertoy simple noise: https://agatedragon.blog/2024/01/27/shadertoy-simple-noise
- Team Dog Pit — Glow without post effects (fake bloom): https://www.patreon.com/teamdogpit/posts/no-bloom-no-post-53965598
- Unity Discussions — HDR emissive + bloom threshold: https://discussions.unity.com/t/how-to-make-a-sprite-glow/779242
- Gem ışık davranışı (faceted gems): https://naturalgemstones.com/education/light-behavior-in-faceted-gems/

**Oyun analizi:**
- GDC 2019 — Tetsuya Mizuguchi, "Making Tetris Effect-ive": https://media.gdcvault.com/gdc2019/presentations/Mizuguchi_Tetsuya_MakingTetrisEffect-ive.pdf
- Deconstructor of Fun — From Tetris to Block Blast (Ocak 2026): https://www.deconstructoroffun.com/blog/2026/1/19/from-tetris-to-block-blast-why-block-puzzles-never-stop-printing
- Inc. — Block Blast dekompilasyonu (368M indirme): https://www.inc.com/jelinda-montes/is-block-blast-rigged-a-developer-decompiled-the-viral-game-to-find-out/91419957
- ustwo — Escher and Monument Valley: https://medium.com/@ustwogames/escher-and-monument-valley-3531cb4ae4d8
- Harry Nesbitt — The Making of Alto's Adventure: http://www.harrynesbitt.com/blog/the-making-of-altos-adventure
- Alto's Odyssey press kit (dinamik ışık/hava): https://altosodyssey.com/press
- Graphic Design SE — Stack renk döngüsü dekonstruksiyonu: https://graphicdesign.stackexchange.com/questions/71842
- Stack Unity klonu (mekanik döküm): https://github.com/llapuras/the-Stack
- Seeles.ai — Helix Jump trail/fireball dökümü: https://www.seeles.ai/games/casual/helix-jump-addictive-ball-drop-game
- Tricky Towers incelemeleri (PSU): https://www.psu.com/reviews/tricky-towers-review-ps4/ · Tetris Wiki — Tetris Blitz: https://tetris.fandom.com/wiki/Tetris_Blitz
- Cube Surfer (App Store): https://apps.apple.com/us/app/cube-surfer-3d/id1531463817 · Stack Colors!: https://www.gameflare.com/online-game/stack-colors · Slice It All!: https://slice-it-all.en.aptoide.com/app
- Woodoku vs Block Blast karşılaştırma: https://dhamakablocks.com/blog/woodoku-vs-block-blast
- Hexa Sort: https://galaxystore.samsung.com/detail/com.sm.HexaSort.color.sorting.puzzle.game.challenge
- Stack Ball (App Store): https://apps.apple.com/ca/app/stack-ball-helix-blast/id1484261776

**Flutter render:**
- Resmî — Writing and using fragment shaders: https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- Resmî — Impeller: https://docs.flutter.dev/perf/impeller
- Impeller saveLayer/blend tuzuakları: https://github.com/flutter/flutter/issues/126532 · https://medium.com/@abied.abiad/flutter-impeller-performance-what-actually-moves-the-raster-thread-now-that-skia-is-gone-4df5ec17ae7f
- PlugFox — High-Performance Canvas Rendering: https://plugfox.dev/high-performance-canvas-rendering
- glow_effects paketi (11 fragment glow efekti): https://pub.dev/packages/glow_effects
- Droids on Roids — Fragment shaders intro: https://www.thedroidsonroids.com/blog/fragment-shaders-in-flutter-app-development
- Glassmorphism Flutter (BackdropFilter): https://medium.com/@divyadave1205/implementing-glassmorphism-in-flutter-a-complete-guide-93612a694d35
