# PB-015..021 gorev spesifikasyonlarini yazar (kullanici yonu 2026-10-25)
import re

specs = {
 'PB-015': {
  'title': 'Surpriz motoru: 8 yeni twist turu + garantili ilk-5 semasi',
  'areas': '`lib/game/levels.dart`, `lib/game/twists.dart`, `lib/game/gameplay.dart`, `test/twists_test.dart`',
  'objective': '"Hicbir surprizi yok. Her oyun birbirinin aynisi... ilk bolumler cok surprizli olmali" (user) — modifier havuzunu 17\'ye cikar ve monotonlugu matematiksel kir (ADR-006).',
  'steps': [
   "1. `lib/game/twists.dart` (yeni): 8 twist tanimi — zitakis (spawn yonu alternansi her mukemmelle), ciftkule (iki hedef kule, toplam hedef), ruzgargulu (blok +-=15 aciyle gelir, birakince toparlanir), dargecit (yan duvarlar daralir), altinyagmuru (rastgele altin bloklar), golgeblok (hayalet ikiz farkli hizda), sicrayan (birakince 1 ziplayip en yakin hizaya oturur — affedici), kritik (%20 ihtimalle x5 para).",
   "2. levels.dart: `twistFor(i)` — dagitim yasasi: her 3 bolumden 1'i yeni-tur havuzundan; ardisik ayni tur <=2; ilk 5 bolum hard-coded [klasik, altinyagmuru, ruzgargulu, zitakis, kritik]. Mevcut 9 modifier kalibi AYNEN korunur (SPEC 2.4).",
   "3. gameplay.dart twist kancalari: spawnSide parametresi, spawnAngle, wallWidth, secondTower, ghostBlock, bounceOnLand, critChance — cekirdek resolveDrop/growthWidth DOKUNULMAZ (C-002).",
   "4. test/twists_test.dart: dagitim yasasi (150 bolumde ardisik tekrar <=2, her 3'te 1 yeni tur), ilk-5 semasi sabit, her twistin motor etkisi (zitakis yon degisimi, kritik x5, sicrayan affi) birim testleri.",
  ],
  'accept': [
   '[machine] dagitim yasasi testleri: 150 bolumde ardisik tekrar <=2 + her 3\'te 1 yeni tur + ilk-5 semasi sabit',
   '[machine] mevcut 150 bolum JS paritesi AYNEN gecer (levels_test regresyon)',
   '[machine] her twistin motor etkisi birim testli (zitakis yon, kritik x5, sicrayan affi)',
   '[visual] cihazda 3 farkli twist bolumu kaydi — surpriz hissi',
   '[interaction] her twist tek girdiyle oynanir; ekstra UI gerektirmez',
  ],
  'verify': ['flutter test test/twists_test.dart', 'flutter test'],
 },
 'PB-016': {
  'title': 'Juice paketi: hit-stop + squash&stretch + flas + haptic desenleri',
  'areas': '`lib/game/gameplay.dart`, `lib/game/scene_painter.dart`, `test/gameplay_test.dart`',
  'objective': '"efektler mukemmel olmali" (user) — RESEARCH-market bolum 4 D3 juice paketi.',
  'steps': [
   "1. gameplay.dart: hitStop alani — mukemmelle 40ms + kombo basina +4ms (tavan 70ms); tick() basinda hitStop>0 ise hareket dt=0 (efektler yine akar).",
   "2. scene_painter: blok yerlesim squash&stretch — yerlesen bloklar icin age alani, 120ms boyunca %12 squash (genislik +12%, yukseklik -12%) easeOut.",
   "3. Renk flasi: mukemmelle tema-glow tam-ekran flas (alpha 0.18, 90ms fade); kritikte beyaz flas 0.35.",
   "4. Haptic desenleri: onHaptic kancasi — mukemmel 10ms, kritik cift vurus (10+40ms), cokme 60ms, kutu 3'lu desen.",
   "5. Partikul comertligi: mukemmelle konfeti 12 parca + yildiz izi; kritikte 40 parca + 2 halka.",
   "6. Test: hitStop suresi, squash easing, flas alpha zamanlamasi birim testleri.",
  ],
  'accept': [
   '[machine] hit-stop/squas/flas zamanlama testleri gecer',
   '[machine] mevcut motor testleri AYNEN gecer (regresyon)',
   '[visual] cihaz kaydi: mukemmel/kritik/cokme anlari — juice kaniti',
   '[interaction] juice 60 fps dusurmez (profiler kaniti)',
  ],
  'verify': ['flutter test test/gameplay_test.dart', 'flutter test'],
 },
 'PB-017': {
  'title': 'Ses katmanlari: kombo merdiveni + kritik/serbest sesleri',
  'areas': '`tools/gen_sounds.dart`, `assets/sounds/**`, `lib/game/audio.dart`',
  'objective': '"Sesler de oyle. Yani cok farkli olmali" (user) — RESEARCH-market bolum 4 D3 ses merdiveni.',
  'steps': [
   "1. gen_sounds.dart: yeni tonlar — crit.wav (cift oktav arpej), layer1/2/3.wav (ritim katmanlari: kick/hat/bass 4 bar loop), fanfare.wav (x10), mystery.wav (sandik gizemi).",
   "2. audio.dart: katman oynatici — combo >=3 katman1, >=6 katman1+2, >=10 hepsi dongude; kombo kirilinca fade-out.",
   "3. Mukemmel serisi: combo <=4 mevcut perfectN; >4 perfectN + katman.",
   "4. Mute kaliciligi ve eksik varlik guvenligi korunur.",
   "5. audio_test: katman secim mantigi + yeni dosya listesi.",
  ],
  'accept': [
   '[machine] katman secimi combo esiklerinde dogru (test)',
   '[machine] tum varliklar --check ile dogrulanir',
   '[visual/duyusal] cihazda kombo merdiveni duyulur (kayit kaniti)',
  ],
  'verify': ['flutter test test/audio_test.dart', 'dart run tools/gen_sounds.dart --check'],
 },
 'PB-018': {
  'title': 'Pazar yeri: harita binasi + gunluk rotasyon + gizli sandik',
  'areas': '`lib/game/progress.dart`, `lib/game/market.dart`, `lib/map/map3d.dart`, `lib/screens/market_screen.dart`, `test/market_test.dart`',
  'objective': '"Pazar yeri gibi bir seyler olmali. Odullendirmeleri bol olmali" (user) — ADR-007.',
  'steps': [
   "1. lib/game/market.dart (yeni, saf): MarketEntry {id, kind, price, stock}; dailyStock(day) — gun tohumlu 3 urun (gorunum/kalkan/carpan/joker) + 1 gizli sandik; buy(state, entry) — para dus, stok azalt; fiyatlar bolum kazanc olceginde (40-150).",
   "2. SaveState: marketDay, marketBought{} alanlari (JSON sema genisletme; eski kayit okunur kalir).",
   "3. map3d.dart: 3+ tamamlanmis bolumlu adalarda PAZAR binasi (isikli, tiklanabilir — hitTest 'market').",
   "4. market_screen.dart: rotasyon urunleri + gizli sandik acilisi (variable-ratio: rastgele odul animasyonuyla).",
   "5. test/market_test.dart: gunluk rotasyon determinizmi, satin alma ekonomisi (para asla negatif), stok tukenmesi, gizli sandik rastgeleligi (sahte rand).",
  ],
  'accept': [
   '[machine] rotasyon determinizmi + ekonomi butunlugu testleri',
   '[machine] eski kayit (market alanlari yok) sorunsuz yuklenir',
   '[interaction] haritadan pazara girilir, satin alinir, bakiye guncellenir',
   '[visual] pazar binasi + sandik acilis animasyonu cihaz kaniti',
  ],
  'verify': ['flutter test test/market_test.dart', 'flutter test'],
 },
 'PB-019': {
  'title': 'Harita gizem katmani: kilitli dunya sisi + ipucu + mikro-animasyon',
  'areas': '`lib/map/map3d.dart`, `lib/screens/map_screen.dart`',
  'objective': '"harita neyle karsilasacagi ile ilgili gizemli bir sekilde birkac sey gostermeli... animasyon olmali. Ama cok az" (user) — RESEARCH-market bolum 4 D5.',
  'steps': [
   "1. map3d: kilitli ada uzeri animasyonlu sis (3-4 sinus hareketli yari saydam damla); ada adi '???' + temaya ipuclu renk.",
   "2. Kilitli dunya karti: name yerine kademeli ipucu (WORLD_TEASER ilk yarisi + '...'); unlock kosulu metni.",
   "3. Mikro-animasyonlar: adalarda donen uydu halkasi, kus surusu (2-3 ucgen), yildiz pariltisi — dusuk maliyet (paint icinde zaman bazli).",
   "4. Acilan dunya: sis kalici acilir (complete bazli) + kisa parilti.",
  ],
  'accept': [
   '[machine] sis/opaklik durumu worldOpen ile tutarli (test)',
   '[visual] kilitli dunya sisi + ipucu cihaz kaniti',
   '[interaction] 60 fps korunur (mikro-animasyonlar ucuz)',
  ],
  'verify': ['flutter test test/map3d_test.dart', 'flutter analyze'],
 },
 'PB-020': {
  'title': 'Tahta canliligi: rekor yaji + sezonluk rozetler',
  'areas': '`lib/game/game_session.dart`, `lib/game/progress.dart`, `lib/screens/flow_overlays.dart`, `test/screens_test.dart`',
  'objective': '"Tahta da oyle [mukemmel olmali]" (user) — RESEARCH-market bolum 4 D6.',
  'steps': [
   "1. SaveState: dailyHistory (son 7 gun best) alani; recordDaily gecmisi yazar.",
   "2. Tahta ekrani: kisisel rekor yaji (7 gun cizgi grafigi) + 'bu hafta X kisi gectin' satiri (rivalsFor karsilastirmasi).",
   "3. Sezonluk rozetler: 7 gun ust uste gunluk tamamla -> rozet (odul odasi gosterimi).",
   "4. Widget test: yaji verisi + rozet kazanimi.",
  ],
  'accept': [
   '[machine] history/rozet mantigi testli',
   '[visual] tahta yaji cihaz kaniti',
  ],
  'verify': ['flutter test test/screens_test.dart', 'flutter test'],
 },
 'PB-021': {
  'title': 'Ilk-5 deneyim passi + mini-surpriz kapisi + pazar kesfi',
  'areas': '`lib/game/game_session.dart`, `lib/screens/flow_overlays.dart`, `test/first_run_test.dart`',
  'objective': '"Ilk bolumler harika olmali... kullaniciyi tutmasi lazim" (user) — RESEARCH-market bolum 4 D2.',
  'steps': [
   "1. Ilk 5 bolumde her bolum sonunda mini-surpriz kapisi: variable-ratio odul (para 20-60 / gorunum %15 / kalinti parcasi %5) — deterministik tohum + rand enjeksiyonu.",
   "2. Tol affordansi: bolum 1'de ilk 5 blok tol 12px (runtime override; JS paritesi dosyada bozulmaz).",
   "3. 3. bolum sonrasi pazar kesfi: haritaya donunce pazar binasi parlar + tek seferlik toast.",
   "4. test/first_run_test.dart: 5 bolumun odul akisi + kesif tetikleyicisi bir kez.",
  ],
  'accept': [
   '[machine] ilk-5 odul/kesif akisi testli',
   '[machine] tol affordansi yalniz bolum 1 (digerleri JS paritesi)',
   '[visual] yeni kurulumda ilk 5 bolum cihaz kaydi',
  ],
  'verify': ['flutter test test/first_run_test.dart', 'flutter test'],
 },
}

for tid, spec in specs.items():
    p = '.project-brain/tasks/%s.md' % tid
    s = open(p, encoding='utf-8').read()
    s = re.sub(r'^# .*$', '# %s — %s' % (tid, spec['title']), s, count=1, flags=re.M)
    s = s.replace('Status: PLANNED', 'Status: READY')
    s = re.sub(r'^Areas: .*$', 'Areas: %s' % spec['areas'], s, count=1, flags=re.M)
    if tid == 'PB-021':
        s = s.replace('Depends: -', 'Depends: PB-015, PB-018')
    steps = '\n'.join(spec['steps'])
    s = re.sub(r'## Steps\n1\. .*?\n\n## Acceptance', '## Steps\n%s\n\n## Acceptance' % steps, s, count=1, flags=re.S)
    acc = '\n'.join('- [ ] %s' % a for a in spec['accept'])
    s = re.sub(r'## Acceptance\n- \[ \] .*?\n\n## Verify', '## Acceptance\n%s\n\n## Verify' % acc, s, count=1, flags=re.S)
    ver = '\n'.join('- `%s`' % v for v in spec['verify'])
    s = re.sub(r'## Verify\n- .*?(?:\n- .*?)*\n\n## Escalate', '## Verify\n%s\n\n## Escalate' % ver, s, count=1, flags=re.S)
    s = s.replace('## Notes\n', '## Notes\nrevised 2026-10-25: kullanici yonu (monotonluk/surpriz) — RESEARCH-market.md bolum 4\'ten turetildi\n')
    open(p, 'w', encoding='utf-8', newline='\n').write(s)
    print('wrote', tid)
