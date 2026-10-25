# Brain V2 entegrasyonu: DESIGN-V2-diyar
import re

# --- target.md: Goal ekleme ---
p = '.project-brain/target.md'
s = open(p, encoding='utf-8').read()
if 'her bölüm farklı OYUN' not in s:
    s = s.replace('''"Oyun çok tekdüze olmuş...''', '''"Ya açıkçası bu hep böyle mi olacak? Yani yukarıdan şeyler gelecek ve bunları dizmeye
mi çalışacak? Başka bir mantık yok mu? Her oyun, her bölüm farklı oyun içermeli...
Oyunu bağımlılık haline getirebilecek bir şekle çevirmen gerekiyor. Ve oyunun bir
amacı olmalı. Amaç tamamlandıkça arkada o bölümde tamamlanan bir şey gösterilmeli ve
çok güzel olmalı... birkaç aşamadan sonra hep böyle bir şeyler tamamlanmalı. Her oyun
farklı mantıkla değişik sürprizler içermeli. Çok güzel efektler, harika efektleri
olmalı. Bunu öyle kurgula." (user, 2026-10-25 ikinci yön — DESIGN-V2-diyar.md)

"Oyun çok tekdüze olmuş...''', 1)
# yeni hedef alanı
s = s.replace('### gameplay-variety (YENİ — kullanıcı yönü 2026-10-25)',
'''### anthology (YENİ — DESIGN-V2 §3.1)
- 10 farklı MiniGame türü (STACK/CATCH/RING/LAUNCH/MERGE/PATH/SORT/BALANCE/DEFEND/RHYTHM);
  her bölüm farklı tür (ardışık aynı ≤1); ilk 5 bölüm 5 farklı tür.
### construction-meta (YENİ — DESIGN-V2 §3.2)
- Görünür inşaat: her bölüm adada yapı parçası yükseltir; 3-5 bölümde yapı tamamlanır;
  dünyada anıt töreni; 10 dünya = Diyar finali. Haritada blueprint merakı.
### gameplay-variety (kullanıcı yönü 2026-10-25 tur 1)''')
open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('target ok')

# --- constraints ---
p = '.project-brain/constraints.md'
s = open(p, encoding='utf-8').read()
if 'C-020' not in s:
    s += '''- C-020: HER BÖLÜM FARKLI OYUN TÜRÜ içerebilir; ardışık aynı tür ≤1; ilk 5 bölüm 5 farklı tür (source: user 2026-10-25 tur2, DESIGN-V2 §3.1)
- C-021: Görünür amaç: her bölüm sonunda adada yapı parçası yükselir; 3-5 bölümde yapı tamamlanır; dünya anıtı töreni (source: user, DESIGN-V2 §3.2)
- C-022: Tüm türler TEK dokunuşla oynanır ve 3 saniyede okunur; ek mekanik meta katmanında yaşar (source: Game-Ace/GGA araştırması)
- C-023: Juice yasaları: her eyleme anında görsel+işitsel yanıt; yoğunluk ∝ önem; çeşitlilik alışkanlığı kırar (source: BloodMoon)
'''
    open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('constraints ok')

# --- ADR-008 / 009 ---
open('.project-brain/decisions/ADR-008.md', 'w', encoding='utf-8', newline='\n').write('''# ADR-008 — Antoloji motoru: her bölüm farklı oyun türü

## Karar
Oyun tek çekirdekten (STACK) 10 türü kapsayan bir ANTLOJİYE dönüşür: STACK, CATCH,
RING, LAUNCH, MERGE, PATH, SORT, BALANCE, DEFEND, RHYTHM (DESIGN-V2 §3.1). Tüm türler
ortak `MiniGame` sözleşmesini uygular (start/tick/onTap/render/result/isOver); play_screen
tür-agnostik host olur; ekonomi/sonuç akışı (GameSession.onWin/onLose) DEĞİŞMEZ.
Dağıtım: kindFor(i) — ardışık aynı tür ≤1, ilk 5 bölüm 5 farklı tür, dünya patronu
imza tür.

## Gerekçe
- Kullanıcı yönü (2026-10-25 tur 2): "her bölüm farklı oyun içermeli; illa yukarıdan
  bir şey gelmek zorunda değil."
- Araştırma: tek-girdi oyunları ≥8 fiil ailesine sahip (Game Developer); mekanik
  aileleri momentum/progression/precision (Game-Ace); çekirdek 3 saniyede okunur
  kalmalı, ek mekanik meta katmanında yaşamalı (C-022).

## Sonuçlar
- lib/game/kinds/* her tür ayrı dosya; lib/game/mini_game.dart sözleşme.
- gameplay.dart (STACK) MiniGame arayüzüne sarmalanır; mevcut testler korunur.
- levels.dart'a kindFor(i) eklenir; mevcut 150 bölüm denge formülleri TÜRLER ARASINDA
  ortak parametre olarak kalır (target/speed/tol/coins).
- Her tür kendi efekt/ses setini getirir (C-023); PB-016/017 juice işi türlere yayılır.
''')
open('.project-brain/decisions/ADR-009.md', 'w', encoding='utf-8', newline='\n').write('''# ADR-009 — Görünür inşaat meta: "Diyarı İnşa Et"

## Karar
Her tamamlanan bölüm, 3B haritadaki adada GÖRÜNÜR bir yapı parçası yükseltir (temel →
duvar → çatı → ışık, animasyonlu). 3-5 bölümde bir yapı tamamlanır (kutlama: konfeti +
ışık dalgası + plaka). Dünya tamamlanınca ANIT töreni. 10 dünya = Diyar finali (ışık
köprüleri). Haritada kilitli adada blueprint silueti görünür (merak). Ödül Odası
genişler: kalıntılar + yapı albümü + takımyıldız parçaları.

## Gerekçe
- Kullanıcı: "amacı olmalı; amaç tamamlandıkça arkada tamamlanan bir şey gösterilmeli,
  çok güzel olmalı."
- Araştırma (GGA 2026): home/village build uzun vadeli sahiplenme döngüsü; D3-D5'te
  meta yeniden açma sebebi olmalı; hook→session→meta→ekonomi sırası.

## Sonuçlar
- lib/map/construction.dart: yapı parçaları + yükselme animasyonu + blueprint çizimi.
- SaveState: builtPieces{levelIdx}, structures{stage:count} (şema genişletme, geriye uyumlu).
- map3d.dart köy binaları construction modeline bağlanır.
''')
print('adr ok')

# --- görevler PB-022..030 ---
tasks = [
 ('PB-022', 'MiniGame arayüzü + antoloji host + STACK sarmalayıcı', 'P1', 'H', 'HIGH',
  '`lib/game/mini_game.dart`, `lib/game/kinds/**`, `lib/screens/play_screen.dart`, `test/minigame_test.dart`',
  'DESIGN-V2 §4: tüm türler ortak sözleşme; play_screen tür-agnostik host; STACK regresyonsuz sarılır.',
  ['1. `lib/game/mini_game.dart`: MiniGame soyut sınıfı (kind/resize/start/tick/onTap/render/result/isOver) + MiniGameResult + MiniGameHost (olay/ses/haptic kancaları).',
   '2. `lib/game/kinds/stack_game.dart`: mevcut GamePlay\'i MiniGame olarak saran adaptör (sonuç alanları aynı).',
   '3. `lib/screens/play_screen.dart`: def.kindFor → uygun MiniGame örneği; ortak HUD (skor/hedef/kalkan/ses); onTap → game.onTap.',
   '4. `lib/game/levels.dart`: `kindFor(i)` — ilk 5: [catch, ring, stack, launch, merge]; sonrası 10 tür döngüsü, ardışık aynı ≤1; dünya patronu imza tür.',
   '5. `test/minigame_test.dart`: kindFor dağıtım yasası; STACK adaptörü mevcut davranışı korur (skor/mükemmel/sonuç paritesi).'],
  ['[machine] kindFor: 150 bölümde ardışık aynı tür ≤1 + ilk-5 şeması sabit',
   '[machine] STACK adaptörü: mevcut gameplay/scren testleri AYNEN geçer (regresyon)',
   '[machine] MiniGame sözleşmesi: her tür start/tick/onTap/result döngüsünde exception yok (parametrik test)',
   '[interaction] cihazda 3 farklı tür art arda oynanır; HUD tutarlı',
   '[accessibility] her tür tek dokunuşla oynanır, 48dp hedefler korunur'],
  ['flutter test', 'flutter analyze']),
 ('PB-023', 'CATCH oyunu: düşen yıldızları yakala, bombalardan kaç', 'P1', 'M', 'MEDIUM',
  '`lib/game/kinds/catch_game.dart`, `test/catch_test.dart`',
  'DESIGN-V2 §3.1 tür 2 — dodge/collect fiili; toplama coşkusu + risk okuma.',
  ['1. `catch_game.dart`: sepet alt kenarda; dokun = yön değiştir (sol/sağ). Yıldızlar (+1) ve bombalar (-1 can) düşer; hedef = N yıldız.',
   '2. Efektler: yakalamada parçacık + ses; bombada shake + kırmızı flaş; kombo yıldızlarda altın iz.',
   '3. Zorluk: hız def.speed ile; yıldız/bomba oranı def.tol tersine; kalkan = 1 bomba affı.',
   '4. `test/catch_test.dart`: yakalama/kaçırma mantığı, kombo, kalkan affı, hedefe ulaşma.'],
  ['[machine] yakalama/kaçırma/kombo/kalkan testleri geçer',
   '[visual] cihaz kanıtı: yıldız yağmuru + yakalama efektleri',
   '[interaction] tek dokunuşla yön değişir; 60 fps'],
  ['flutter test test/catch_test.dart', 'flutter analyze']),
 ('PB-024', 'RING oyunu: dönen halkanın hedef diliminde durdur', 'P1', 'M', 'MEDIUM',
  '`lib/game/kinds/ring_game.dart`, `test/ring_test.dart`',
  'DESIGN-V2 §3.1 tür 3 — release/timing fiili; tam isabet hazzı, daralan pencere.',
  ['1. `ring_game.dart`: merkez etrafında dönen işaretçi; hedef dilim(ler) renkli; dokun = durdur. Hedefte dur → mükemmel (+1); değilse can kaybı.',
   '2. Seviye ilerledikçe: dönüş hızı artar, hedef dilim daralır, çoklu hedef halkalar (iç/dış) eklenir.',
   '3. Efektler: isabette halka patlaması + hit-stop; kaçırınca kırmızı titreme.',
   '4. `test/ring_test.dart`: açı hesabı, isabet/ıskala sınırları, daralan pencere.'],
  ['[machine] açı/isabet sınırı testleri geçer',
   '[visual] halka patlama efekti cihaz kanıtı',
   '[interaction] dokunma gecikmesi < 1 frame hissi'],
  ['flutter test test/ring_test.dart', 'flutter analyze']),
 ('PB-025', 'LAUNCH oyunu: dönen nişan + şarj, hedefi vur', 'P1', 'M', 'MEDIUM',
  '`lib/game/kinds/launch_game.dart`, `test/launch_test.dart`',
  'DESIGN-V2 §3.1 tür 4 — aim-rotate + charge fiili; fizik öngörüsü.',
  ['1. `launch_game.dart`: nişan döner; basılı tut = güç şarj (görsel gösterge); bırak = fırlat. Hedefler patlar; N hedef = bölüm tamam.',
   '2. Fizik: basit balistik (yerçekimi), duvar sekmesi; güç ∝ mesafe.',
   '3. Efektler: fırlatma izi, patlama parçacıkları, slow-mo kritik vuruş.',
   '4. `test/launch_test.dart`: balistik entegrasyonu, güç/açı → hedef isabeti.'],
  ['[machine] balistik + isabet testleri geçer',
   '[visual] fırlatma/patlama efektleri cihaz kanıtı',
   '[interaction] bas-bırak şarj hissi net (görsel geri bildirim)'],
  ['flutter test test/launch_test.dart', 'flutter analyze']),
 ('PB-026', 'MERGE oyunu: aynı parçaları birleştir', 'P1', 'M', 'MEDIUM',
  '`lib/game/kinds/merge_game.dart`, `test/merge_test.dart`',
  'DESIGN-V2 §3.1 tür 5 — merge fiili; görünür büyüme (2020 sonrası baskın arketip).',
  ['1. `merge_game.dart`: 4x4 ızgara; dokun = yeni parça düşer; aynı parçalar bitişikse sürükle-birleştir (tek dokunuş alternatifi: dokun-dokun seç).',
   '2. Hedef: N seviyesine ulaş. Birleşmede patlama + seviye atlama efekti.',
   '3. `test/merge_test.dart`: birleşme kuralları, hedef, ızgara taşması = kayıp.'],
  ['[machine] birleşme/hedef/taşma testleri geçer',
   '[visual] birleşme patlaması cihaz kanıtı',
   '[interaction] tek dokunuş akışı (seç→hedefle) net'],
  ['flutter test test/merge_test.dart', 'flutter analyze']),
 ('PB-027', 'PATH + SORT oyunları', 'P2', 'M', 'MEDIUM',
  '`lib/game/kinds/path_game.dart`, `lib/game/kinds/sort_game.dart`, `test/path_sort_test.dart`',
  'DESIGN-V2 §3.1 tür 6-7 — draw-line ve sort fiilleri.',
  ['1. `path_game.dart`: düğümleri tek çizgiyle ziyaret et (dokun-sürükle); tüm düğümler = tamam.',
   '2. `sort_game.dart`: renkli topları doğru kutuya taşı (dokun = al, dokun = bırak).',
   '3. Efektler: çizgi izi neon; sıralamada renk patlaması.',
   '4. `test/path_sort_test.dart`: yol geçerliliği, sıralama kuralları.'],
  ['[machine] yol/sıralama kuralları testli',
   '[visual] neon çizgi izi cihaz kanıtı',
   '[interaction] sürükle akışı doğal'],
  ['flutter test test/path_sort_test.dart', 'flutter analyze']),
 ('PB-028', 'BALANCE + DEFEND + RHYTHM oyunları', 'P2', 'M', 'MEDIUM',
  '`lib/game/kinds/balance_game.dart`, `lib/game/kinds/defend_game.dart`, `lib/game/kinds/rhythm_game.dart`, `test/bdr_test.dart`',
  'DESIGN-V2 §3.1 tür 8-10 — switch, defend, timing-on-beat fiilleri.',
  ['1. `balance_game.dart`: tahterevalli; dokun = tarafa ağırlık; T saniye dengede kal.',
   '2. `defend_game.dart`: dalgalar gelir; doğru anda dokun = kalkan; N dalga = tamam.',
   '3. `rhythm_game.dart`: vuruşlarda dokun; kombo müzik katmanları (PB-017 ile).',
   '4. `test/bdr_test.dart`: denge fiziği, dalga zamanlaması, ritim penceresi.'],
  ['[machine] üç türün kuralları testli',
   '[visual] kalkan/dalga/ritim efektleri cihaz kanıtı',
   '[interaction] ritimde dokunma hissi (latency < 1 frame)'],
  ['flutter test test/bdr_test.dart', 'flutter analyze']),
 ('PB-029', 'Görünür inşaat meta: yapı parçaları + yükselme animasyonu + blueprint', 'P1', 'H', 'HIGH',
  '`lib/map/construction.dart`, `lib/map/map3d.dart`, `lib/game/progress.dart`, `test/construction_test.dart`',
  'DESIGN-V2 §3.2 / ADR-009 — kullanıcı: "amaç tamamlandıkça arkada tamamlanan bir şey gösterilmeli, çok güzel olmalı."',
  ['1. `lib/map/construction.dart`: StructureType (ev/kule/köprü/bahçe/pazar/anıt) + parça listesi (temel/duvar/çatı/ışık) + pieceFor(levelIdx, stage).',
   '2. Yükselme animasyonu: bölüm bitince haritada parça 1.2s ease-out ile yükselir + parıltı + ses.',
   '3. Yapı tamamlanınca (3-5 parça) kutlama: konfeti + ışık dalgası + plaka.',
   '4. Blueprint: kilitli adada siluet çizim + "burada ne yükselecek?" ipucu.',
   '5. Dünya anıtı + Diyar finali (10 dünya = ışık köprüleri).',
   '6. SaveState: builtPieces/structures alanları; `test/construction_test.dart`: parça ilerlemesi + determinizm.'],
  ['[machine] parça/yapı ilerlemesi deterministik testli',
   '[visual] yükselme animasyonu + tamamlanma kutlaması cihaz kanıtı',
   '[interaction] bölüm bitince haritada görünür değişiklik (tek dokunuş akışı)',
   '[accessibility] blueprint/ipucu metinle de okunur'],
  ['flutter test test/construction_test.dart', 'flutter test']),
 ('PB-030', 'Dağıtım yasası + ilk-5 hook + cömert ödül ayarı + bağımlılık döngüsü', 'P1', 'M', 'HIGH',
  '`lib/game/levels.dart`, `lib/game/game_session.dart`, `test/distribution_test.dart`',
  'DESIGN-V2 §3.1/§3.4 — her bölüm farklı tür; kısa/orta/uzun hedef merdiveni; değişken oran ödül.',
  ['1. kindFor(i) dağıtım yasası (ADR-008): 10 tür döngüsü, ardışık aynı ≤1, ilk-5 hook, dünya patronu imza.',
   '2. Önizleme ekranı: tür kartı (isim/ikon/ipucu) + "sırada ne var" merak kartı.',
   '3. Cömert ödül: her tür kendi bonusunu verir; mini-sürpriz kapısı her bölüm (PB-021 ile birleşir).',
   '4. `test/distribution_test.dart`: 150 bölüm tür dağılımı + ilk-5 + ödül tutarlılığı.'],
  ['[machine] dağılım testleri: ardışık aynı ≤1, ilk-5 farklı, patron imza tür',
   '[machine] her türün ödülü ekonomi bütünlüğünü korur (para ≥0)',
   '[visual] önizleme tür kartı cihaz kanıtı',
   '[interaction] ilk 5 bölüm 5 farklı deneyim (cihaz kaydı)'],
  ['flutter test test/distribution_test.dart', 'flutter test']),
]

for tid, title, prio, tier, risk, areas, objective, steps, accept, verify in tasks:
    body = f'''# {tid} — {title}
Status: READY
Priority: {prio}
Tier: {tier}
Risk: {risk}
Owner:
Depends: -
Areas: {areas}
Domains: anthology,construction-meta

## Objective
{objective}

## Steps
{chr(10).join(steps)}

## Acceptance
{chr(10).join('- [ ] ' + a for a in accept)}

## Verify
{chr(10).join('- `' + v + '`' for v in verify)}

## Escalate if
- kapsam başka görevin alanına taşıyorsa

## Evidence

## Review

## Notes
revised 2026-10-25: DESIGN-V2-diyar.md (kullanıcı yönü tur 2) temel alındı
'''
    open(f'.project-brain/tasks/{tid}.md', 'w', encoding='utf-8', newline='\n').write(body)
    print('wrote', tid)
