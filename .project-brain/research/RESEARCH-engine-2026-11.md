# RESEARCH: Motor Kararı — Flutter'da Kal + Cilala mı, Unity/Godot'a Göç mü? (2026-11)

- **Tarih:** 2026-11-02
- **Soru:** "Flutter oyunu güzelleştiremiyorsa Unity'ye (veya başka motora) geçilmeli mi? Paketler/motorlar/ses internetten araştırılıp karar verilecek."
- **Yöntem:** Web araştırması — resmi dokümanlar (Flutter, Unity, Godot, FMOD, Wwise), pub.dev, bağımsız benchmark (filiph.net), topluluk deneyimleri (Reddit/forümler), lisans sayfaları.
- **Mevcut kod tabanı gerçeği (doğrulandı):** ~42 Dart dosyası `lib/` altında (~16.400 satır), test+worker ile ~84 dosya; 10 mini-oyun türü, 150 bölüm, ekonomi/kayıt şeması (v3), Cloudflare Workers backend, 336 yeşil test (JS parite + ekonomi + motor + ekran akışları), Türkçe UI, CustomPainter motoru (ADR-002: Flame/fizik yok).
- **İlgili kısıtlar:** C-001 (kalite tabanı), C-009/C-017 (çekirdek parite dokunulmaz), ADR-002 (CustomPainter motoru), ADR-003 (üretilmiş ses varlıkları).

---

## 1. Yönetici Özeti ve NİHAİ TAVSİYE

> ### KARAR: **Flutter'da kal + hedefli premium cilâ (shader + ses). Unity/Godot'a göç YOK.**

Gerekçenin özü üç cümle:

1. **Bu oyunun türü Flutter'ın güçlü bölgesidir.** Bağımsız benchmark (filiph.net, Eski Flutter ekibi üyesi; Flutter 3.24 vs Unity 2022.3 vs Godot 4.2): Flutter/Flame kart oyunu/deste/strateji tipi **düşük-orta varlıklı 2D oyunlarda** açılış hızı (~2,6× daha hızlı), CPU/pil verimliliği ve bellek açısından Unity'yi geçer. "Binlerce varlık" gerektiren aksiyon oyunlarında Unity/Godot kazanır — **Stack Tower bu değil**: sahnede onlarca sprite + parçacık havuzu var, binlerce düşman yok.
2. **Görsel tavan sorunu motor sorunu değil, yatırım sorunudur.** Flutter 3.10+ GLSL fragment shader, 3.29+ Impeller (Android varsayılan; shader derleme takılmaları ölü), Paint.blend-mode'lar ve Rive runtime ile 2D casual tavanına ulaşabilir (kanıt: aşağıdaki çıkmış oyunlar). Bu türün hit'leri (Stack, Helix Jump) zaten **düz gradyan + juice** estetiğidir; "premium" his motorun değil, juice yasalarının (RESEARCH-dna L1–L12) ve sesin sonucudur.
3. **Göç maliyeti kıyaslanamaz biçimde yüksek.** 16,4k satır + 336 JS-parite testini C#'a sıfırdan yazmak 2–4 ay tam zamanlı iş, test güvencesi ve parite disiplini sıfırlanır; karşılığında bu oyuna Unity'nin tek somut katkısı olmaz (boyut +15–25 MB, açılış yavaşlar, splash ekran zorunlu).

---

## 2. Flutter'ın Görsel Tavanı (2025–26 Durumu)

### 2.1 Araç kutusu

| Araç | Sürüm/durum (2026-11) | Bu oyuna kazandırdığı |
|------|----------------------|------------------------|
| **Fragment shaders** (`FragmentProgram`, `.frag`) | Flutter 3.10+ stabil; Impeller üzerinde de çalışır | GPU başına-piksel efektler: aurora/güneş gökyüzü, ısıl kırılma, kromatik sapma, sıvı gradyanlar, vinyet. `CustomPainter` ile doğrudan kullanılır — mevcut mimariye birebir oturur (scene_painter). Resmi doküman: [docs.flutter.dev/fragment-shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders) |
| **Impeller** | Android'de **3.29'dan beri varsayılan** render motoru (proje Flutter 3.47) | Runtime shader derleme takılmaları ("ilk kullanımda donma") tarihe karıştı; öngörülebilir raster. Dikkat: kötü yerleştirilmiş `saveLayer`/blur hâlâ raster ipliğini yorar — mevcut popup Picture LRU önbelleği doğru yöndedir. [Impeller dokümanı](https://docs.flutter.dev/perf/impeller) |
| **Flame** | 1.38.2 (Flutter 3.47 uyumlu) | Oyun döngüsü/sprite/çarpışma/parçacık/efekt modülleri. **Bu projede gerekmez** (ADR-002): CustomPainter motoru zaten Flame'in yaptığı işi yapıyor; flame_i18n değil ama parçacık sistemi ilham kaynağı olabilir. [pub.dev/packages/flame](https://pub.dev/packages/flame) |
| **flutter_shaders / flutter_shader_kit** | pub.dev'de aktif | Hazır sarmalayıcı widget'ları; hızlı başlangıç için. [flutter_shaders](https://pub.dev/packages/flutter_shaders), [flutter_shader_kit](https://pub.dev/packages/flutter_shader_kit/versions/0.1.0) |
| **Rive** | `rive` pub paketi + editör | Menü logo sinematiği, anıt töreni, hediye kutusu gibi **vekör-kemikli** sahne animasyonları; runtime'da durum-eğitimli (state machine). Flutter vitrininde resmî gösterilen entegrasyon. [rive.app](https://rive.app), [pub.dev/packages/rive](https://pub.dev/packages/rive), [flutter.dev/showcase/rive](https://flutter.dev/showcase/rive) |
| **Blend mode'lar / saveLayer** | Çekirdek | Glow, additive parlama, ekran karıştırma — mobil GPU'da ucuz; blur+aşırı saveLayer katmanlaması pahalı (Impeller notu yukarıda). |

### 2.2 Çıkmış, mağazada kanıtlanmış Flutter oyunları

- **Trivia Crack** — Flutter'ın en büyük ticari başarısı, **100M+ indirme** ([r/FlutterDev](https://www.reddit.com/r/FlutterDev/comments/18sdwu6/biggest_commercial_flutter_game)).
- **awesome-flame galerisi** — mağaza linkli onlarca çıkmış oyun ([github.com/flame-engine/awesome-flame](https://github.com/flame-engine/awesome-flame)); Flame'in kendi galerisi (Idle Horizons, Gunslinger vb.).
- **Google resmî:** [flutter.dev/games](https://flutter.dev/games) — Casual Games Toolkit + Super Dash (VGV Flame şablonu), yani Google'ın kendisi casual oyun senaryosunu Flutter ile resmen destekliyor.
- Sonuç: Flutter'da "mağaza kalitesinde" 2D casual **kanıtlanmiş**; eksik görünen örnekler çoğunlukla yatırım eksikliği (indie, 2 haftalık projeler), motor tavanı değil.

### 2.3 Flutter'ın gerçek sınırları (dürüst liste)

1. **Varlık sayısı:** vanilla Flutter ~400+ meşgul sprite sonrası kare düşürmeye eğilimli (benchmark); bullet-hell tarzı için değil. Bu oyunun sahne yoğunluğu bu sınırın çok altında.
2. **2D ışıklandırma/normal-map, shader graph, eklem iskeleti** yerleşik değil — elle GLSL yazmak gerekir (istediğimiz efekt sayısı az: gökyüzü + parıltı + final).
3. **Ağır blur/saveLayer bileşimi** raster ipliğini yorar; Picture önbelleği (zaten var) ve `RepaintBoundary` (zaten var) ile yönetilir.
4. Flutter'ın bu benchmark'taki iki SDK hatası (web bellek, font önbelleği) giderilme sürecindeydi — mobil etkisi sınırlı.

**Ara not:** Filiph'in benchmark'ındaki sonuç "Flutter casual/düşük-yoğunluk 2D'de en iyi açılış+pil; yoğun aksiyonda Unity/Godot" — [kaynak](https://filiph.net/text/benchmarking-flutter-flame-unity-godot.html).

---

## 3. Unity 2D Değerlendirmesi

| Boyut | Bulgu |
|-------|-------|
| **Maliyet** | Personal plan **ücretsiz** (son 12 ay gelir/kaynak < **200.000 USD**); Runtime Fee 09/2024'te iptal edildi. Üstü Pro ~185 $/ay/koltuk. [unity.com/pricing-updates](https://unity.com/products/pricing-updates) |
| **Splash ekran** | Personal'da zorunlu Unity splash (kaldırmak Pro) — premium his için negatif. |
| **Build boyutu** | Boş Android projesi **~18–32 MB** (ARM64+IL2CPP); Flutter taban ~**4,5–5 MB**, Flame eklentisi ~0. Bu oyun APK'sına +15–25 MB demektir. |
| **Açılış süresi** | Benchmark: Flutter ~2,6× daha hızlı ilk etkileşim; Unity splash zorunlu ~2,9 sn+. |
| **Öğrenme eğrisi** | C#, sahne/prefab sistemi, URP render hattı, TextMesh/UGUI, Addressables — mevcut Dart/CustomPainter yetkinliğinin üzerine **tamamen yeni yığın**. |
| **Güçlü yanları** | Asset Store, URP ile 2D ışık/normal-map/post-processing, binlerce varlık, FMOD/Wwise birinci sınıf entegrasyon. |
| **Ses middleware** | FMOD ücretsiz (geliştirme bütçesi <600k $ VE yıllık gelir <200k $; üstü tek seferlik ~2.000 $) — [fmod.com/licensing](https://www.fmod.com/licensing); Wwise ücretsiz indie (üretim bütçesi <250k $, gelir sınırı yok; ticari ~6.000 $+) — [Audiokinetic](https://www.audiokinetic.com/wwise/pricing/for-games). Her ikisi de Unity'ye güçlü bağlanır ama **Flutter'da da FMOD'un Flutter eklentisi** mevcut; bu oyunda 27 olay sesi için middleware **aşırı yatırım**. |

**Sonuç:** Unity'nin üstünlükleri (yoğun aksiyon, 3D, fizik yığını, asset pipeline) **bu oyunun hiçbir ihtiyacına** denk gelmiyor; bedelleri (boyut, splash, açılış, sıfırdan öğrenme/yazma) tam fiili.

---

## 4. Godot 4 Değerlendirmesi

- 2D kalitesi ve ücretsiz/açık kaynak durumu güçlü; mobil 2D 2025'te **üretime hazır** sayılıyor (çıkmış örnekler var) — [forum](https://forum.godotengine.org/t/does-anyone-use-godot-4-for-mobile-games/43673), [r/godot 4.4 deneyimi](https://www.reddit.com/r/godot/comments/1o25g5b/my_experience_building_a_mobile_game_in_godot_44).
- **Boyut:** minimal Godot 4 dışa aktarımı **~13–20 MB** (Godot 3'te ~8,5 MB idi) — Unity'den küçük, Flutter'dan 3–4× büyük.
- **Gotcholar:** Android imzalama/AAB dışa aktarım akışı, doku içe aktarma ayarları (yanlış ayar 244 KB projeyi 114 MB APK yapabiliyor) — [örnek](https://forum.godotengine.org/t/absurd-file-size-increase-when-my-project-is-exported-to-apk/130000), [rehber](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html), [2026 retrospektifi](https://juliapottinger.com/godot-for-a-mobile-game-in-2026).
- **Sonuç:** Unity'den makul alternatif ama aynı yeniden yazım bedeli + daha küçük ekosistem/paket havuzu + Flutter'a hiçbir görsel üstünlük sağlamadığı için **bu proje için hiçbir senaryoda öne çıkmıyor**.

---

## 5. Göç Maliyeti Gerçeklik Kontrolü (bu repo için)

Yeniden yazım kapsamı, taşınamayan/varılan her kalemin durumu:

| Bileşen | Unity'ye göçte kader | Emek |
|---------|---------------------|------|
| game-core (levels/progress/drop_core, JS birebir) | C#'a yeniden yazım + parite harness yeniden kurulum | Yüksek — matematik birebir kalmalı (C-002) |
| 336 test (150×12 snapshot parite, ekonomi, motor, ekran) | **Tamamen kayıp**; yeni test süitinin yazımı | Çok yüksek |
| 10 mini-oyun türü + 7 twist + juice paketi | Yeniden yazım | Yüksek |
| CustomPainter render (aurora, paralaks, 3B blok, imza, final) | UGUI/Sprite renderer'a çeviri; görsel kimlik yeniden inşa | Yüksek |
| Ekranlar (menu/map/preview/play/box/shop/missions/board/settings) | Yeni UI sistemi + Türkçe metin yeniden yerleşim | Yüksek |
| Cloudflare Workers (auth/score) | **Kurtulur** — REST istemcisi yeniden yazılır | Düşük (avantaj) |
| Kayıt şeması (v3, streak/takvim) | Ya Unity'ye taşıp migrasyon yazılır ya kullanıcı kaybı | Orta-yüksek risk |
| Auth (google_sign_in/sign_in_with_apple/secure storage) | Native SDK entegrasyonu yeniden | Orta |
| Çıraklık durumu | 2–4 ay tam zamanlı gerçekçi tahmin; bu süre zarfında **özellik gelişimi sıfır** | — |

Aynı emeğin Flutter'a yatırımı: fragment shader paketi (~3–7 gün), ses katmanı yenileme (~1–2 gün), Rive sinematikleri (opsiyonel ~2–4 gün), performans profilleme (~1–2 gün). **Toplam 1–3 hafta**, test güvencesi ve parite aynen durur, kullanıcı kaydı ve CI akışı değişmez.

**Kırılma noktası testi (dürüstlük):** Unity'yi haklı çıkaracak tek senaryo, oyunun gelecekte 3D'ye veya yüzlerce eşzamanlı varlık gerektiren aksiyona dönmesi olurdu. Hedef (target.md) bunları açıkça dışlıyor (yatay mod yok, tek dokunuş, 2D).

---

## 6. Karşılaştırma Tablosu (istenen: görsel tavan / maliyet / risk / süre)

| Kriter | **Flutter + cilâ (KARAR)** | Unity 2D (yeniden yazım) | Godot 4 (yeniden yazım) |
|--------|---------------------------|--------------------------|--------------------------|
| **Görsel tavan (bu tür için)** | Yeterli-üst: GLSL shader + Impeller + blend mode + Rive; türün hit'leri (Stack, Helix Jump) daha azıyla 100M+ indirme | En yüksek teorik tavan (URP, 2D ışık, post-processing) — ama bu türde fark oyuncuya görünmez | Unity'ye yakın; Flutter'a pratik üstünlüğü yok |
| **Maliyet** | 1–3 hafta dev emeği; $0 lisans; $0 yeni araç | 2–4 ay; $0 lisans (<200k $) ama splash ekran + öğrenme + asset üretimi | 2–4 ay; $0 lisans; daha küçük ekosistem |
| **Risk** | Düşük — 336 test ve parite aynen; kademeli (her shader bağımsız) | Yüksek — parite/test/ekonomi/kayıt migrasyonu; 2+ ay görünürlük kaybı; splash + APK boyutu mağaza algısını düşürür | Yüksek + dışa aktarım gotchoları |
| **Süre (premium kapanış)** | ~1–3 hafta | ~2–4 ay (pariteye) | ~2–4 ay |
| **APK boyutu (taban)** | ~4,5–5 MB + sesler | ~18–32 MB taban | ~13–20 MB taban |
| **Açılış / pil** | En hızlı / en verimli | Yavaş (splash) / orta | Orta / benchmark'ta iOS'ta zayıf |
| **Ses middleware** | Gerek yok (27 olay sesi + müzik döngüsü zaten mimaride); FMOD Flutter eklentisi var | FMOD/Wwise ücretsiz katmanlar mevcut (üst kademelerde ücretli) | FMOD/Wwise desteği var |
| **Test güvencesi** | Korunur (336 test) | Sıfırdan | Sıfırdan |

---

## 7. Ses: Premium Ses Kaynakları ve Şimdi Yapılabilecekler

### 7.1 Kaynak envanteri (araştırma sonucu)

| Kaynak | Lisans | Fiyat | Bu oyunda kullanım |
|--------|--------|-------|--------------------|
| **Sonniss GDC Bundle** (2015–2026 arşivi; 2026 paketi 7,47 GB / 347 WAV) | Tam royalti-free, **atıf gerekmez**, ticari serbest ([lisans](https://sonniss.com/gdc-bundle-license), [arşiv](https://sonniss.com/gameaudiogdc)) | Ücretsiz | En yüksek kalite/hacim: UI dokunuş, sandık açılışı, konfeti, anıt töreni, kalabalık jingle |
| **Kenney.nl ses paketleri** (UI Audio, Interface Sounds, Digital Audio, Music Jingles) | **CC0** — atıf/kişisel-ticari sınır yok ([kenney.nl/assets](https://kenney.nl/assets)) | Ücretsiz | Olay sesleri (coin/place/perfect) için tutarlı tek-yapımcı seti |
| **Freesound.org** | Ses başına değişir: **CC0** (atıfsız ticari serbest) / CC-BY (atıf şart) / NC (ticari YASAK) — her ses tek tek kontrol edilmeli ([rehber](https://selektaudio.com/guides/is-freesound-safe-for-commercial-use)) | Ücretsiz | Atmosfer/ambiyans dolguları; yalnız CC0 filtresi ile |
| **jsfxr / sfxr.me** (+ Bfxr, ChipTone) | Üretilen ses kullanıcıya ait | Ücretsiz | Retro/casual vurgular; mevcut `gen_sounds` prosedürel yaklaşımıyla aynı felsefe ([sfxr.me](https://sfxr.me), [itch.io araçları](https://itch.io/tools/tag-audio/tag-jsfxr)) |
| **AudioJungle / Envato Elements** | Royalti-free ama **oyun/stream Content ID gotcha'ları** bildirilmiş — müzik lisansı dikkat | Tek ses ~birkaç–30 $; Elements abonelik ~16,50 $/ay | Yalnız gereken tek müzik parçası için; toplu dönüş için değil |
| **FMOD for Games** | Geliştirme bütçesi <600k $ ve yıllık gelir <200k $ → ücretsiz ([fmod.com/licensing](https://www.fmod.com/licensing)) | $0 / üstü ~2.000 $ tek seferlik | Bu ölçekte **gerek yok** (audioplayers + 27 varlık mimarisi yeterli) |
| **Wwise indie** | Üretim bütçesi <250k $ → ücretsiz, gelir sınırı yok ([Audiokinetic](https://www.audiokinetic.com/wwise/pricing/for-games)) | $0 / ticari ~6.000 $+ | Gerek yok |

### 7.2 Sesin "premium" kaldıracağı yer (RESEARCH-dna L11 ile hizalı)

1. **Pitch merdiveni:** ardışık mükemmel yerleştirmede her vuruş bir yarım ton yükselsin (Stack'in bağımlılık imzası) — `audioplayers` ile `rate` parametresi, yeni varlık gerekmez, **1 gün** iş.
2. **Katmanlı kazanma anı:** kazanma jingle'ı + kalabalık konfeti + son blok "tok" vuruşu üst üste (Sonniss/Kenney'den seçme, ~1–2 gün).
3. **Dünya jingle kimliği:** 10 dünyaya kısa (2 sn) giriş jingle'ı (Kenney Music Jingles'tan ayrıştırma, ~1 gün).
4. **ASMR dokunuş:** blok yerleşim sesini yumuşak/possessif kaymalarla değiştir (Sonniss'ten "click/whoosh" ailesi).
5. Prosedürel döngü müzik (PB-033'te var) korunur; üstüne dünya-temalı hafif varyasyon filtresi (düşük öncelik).

---

## 8. Karar ve Yol Haritası

### 8.1 Nihai karar

**Flutter'da kalın.** Görsel premium hedefine ulaşmak için motor değişikliği gerekmiyor; gereken araçların tamamı (fragment shader, Impeller, blend mode, Rive) mevcut mimariye eklenir. Göç, hiçbir karşılık sağlamayan 2–4 aylık risk penceresidir. Bu karar ADR-002 (Flame yok / CustomPainter) ve C-009 (çekirdek parite dokunulmaz) ile uyumludur; yeni bir ADR olarak kaydedilmesi önerilir.

### 8.2 Önerilen cilâ paketi (öncelik sırası)

1. **Ses maratonu (1–2 gün):** Sonniss GDC 2026 + Kenney CC0'dan seçkiler; pitch merdiveni + katmanlı kazanma (§7.2). En yüksek etki/efor oranı.
2. **Fragment shader'lar (~1 hafta):** (a) aurora/gökyüzü shader'ı (scene_painter'daki katman çizimini tek .frag'e indirme → daha zengin renk geçişi), (b) mükemmel vuruşta kromatik sapma/şok halkası shader'ı, (c) final töreni ışık köprüsü shader'ı. Her biri bağımsız, `AmbientMotion` kapısıyla testte kapatılabilir.
3. **Glow/additive katman taraması (1–2 gün):** blend-mode geçişleri + Impeller altında raster profil (saveLayer sayısını düşürme).
4. **Rive (opsiyonel, 2–4 gün):** yalnız menü logo sinematiği + anıt töreni; başka hiçbir şeye gerek yok.
5. **Flame eklenmez** — ADR-002 geçerli; bu kararın gerekçesi yukarıda (mevcut motor Flame'in işini zaten yapıyor).

### 8.3 İzleme/kabul ölçütü

- Görsel: 3 düşük uçlu cihazda (360×640 dahil) shader'lı sahneler 60 fps / profil modunda raster ipliği < 8 ms.
- Ses: her etkileşimde ≤ 40 ms gecikmeyle geri bildirim (audioplayers preload açık).
- Test: `flutter test` 336+ yeşil kalır; drop_core parite diff'i boş (C-002).

---

## 9. Kaynaklar

- Filiph motor benchmark'ı (Flutter/Flame vs Unity vs Godot, 09/2024): [filiph.net](https://filiph.net/text/benchmarking-flutter-flame-unity-godot.html)
- Flutter fragment shaders (resmî): [docs.flutter.dev](https://docs.flutter.dev/ui/design/graphics/fragment-shaders) · Impeller: [docs.flutter.dev/perf/impeller](https://docs.flutter.dev/perf/impeller) · [GitHub wiki](https://github.com/flutter/flutter/wiki/Impeller)
- Flame 1.38.x: [pub.dev/packages/flame](https://pub.dev/packages/flame) · [flame-engine.org](https://flame-engine.org) · awesome-flame: [GitHub](https://github.com/flame-engine/awesome-flame)
- flutter_shaders: [pub.dev](https://pub.dev/packages/flutter_shaders) · flutter_shader_kit: [pub.dev](https://pub.dev/packages/flutter_shader_kit/versions/0.1.0)
- Rive: [rive.app](https://rive.app) · [pub.dev/packages/rive](https://pub.dev/packages/rive) · [flutter.dev/showcase/rive](https://flutter.dev/showcase/rive)
- Flutter Casual Games Toolkit / Super Dash: [flutter.dev/games](https://flutter.dev/games) · Trivia Crack 100M+: [r/FlutterDev](https://www.reddit.com/r/FlutterDev/comments/18sdwu6/biggest_commercial_flutter_game)
- Unity fiyatlandırma (Personal <200k $, Runtime Fee iptali): [unity.com/products/pricing-updates](https://unity.com/products/pricing-updates)
- Unity vs Flutter APK boyutları: [r/Unity3D](https://www.reddit.com/r/Unity3D) ~18 MB boş APK / [Unity Discussions](https://discussions.unity.com) ~32 MB ARM64 · Flutter minimal APK 4,48–4,7 MB ([GitHub issue #16833](https://github.com/flutter/flutter/issues/16833))
- Godot 4 mobil: [forum 13–20 MB](https://forum.godotengine.org/t/does-anyone-use-godot-4-for-mobile-games/43673) · [4.4 mobil deneyimi](https://www.reddit.com/r/godot/comments/1o25g5b/my_experience_building_a_mobile_game_in_godot_44) · [Android dışa aktarma](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) · [2026 retrospektifi](https://juliapottinger.com/godot-for-a-mobile-game-in-2026)
- Ses: Sonniss GDC arşivi/lisans: [sonniss.com/gameaudiogdc](https://sonniss.com/gameaudiogdc) · [gdc.sonniss.com](https://gdc.sonniss.com) · Kenney CC0: [kenney.nl/assets](https://kenney.nl/assets) · Freesound lisans rehberi: [selektaudio.com](https://selektaudio.com/guides/is-freesound-safe-for-commercial-use) · jsfxr: [sfxr.me](https://sfxr.me) · AudioJungle/Envato: [Envato](https://elements.envato.com) (oyun lisansı gotcha'ları için r/gamedev) · FMOD: [fmod.com/licensing](https://www.fmod.com/licensing) · Wwise: [Audiokinetic](https://www.audiokinetic.com/wwise/pricing/for-games)
- Proje içi bağlam: `AGENTS.md`, `.project-brain/target.md`, `.project-brain/current.md`, `.project-brain/research/RESEARCH-dna-2026-11.md` (L1–L12 juice yasaları, L11 ses imzası)
