/// Stack Tower Game — sürpriz motoru: twist türleri ve dağıtım yasası.
/// ADR-006: çekirdek bırakma matematiği değişmez; twist'ler üst katman
/// kancalarıyla (spawn yönü/açısı, çarpanlar, bölüm olayları) eklenir.
/// RESEARCH-market.md §4 D1 (kullanıcı yönü 2026-10-25).
library;

enum TwistType {
  zitakis, // spawn yönü her mükemmelle değişir
  ruzgargulu, // blok hafif açıyla süzülür
  dargecit, // yan duvarlar daralır — geçit hedefi daraltır
  altinyagmuru, // rastgele bloklar altındır — para patlaması
  sicrayan, // bırakınca bir kez en yakın hizaya toparlanır (affedici)
  kritik, // mükemmeller %20 ihtimalle ×5 kritik
  ciftkule, // (aşama 2) iki kule, toplam hedef
  golgeblok, // (aşama 2) hayalet ikiz farklı hızda
}

class Twist {
  final TwistType type;
  final String name;
  final String icon;
  final String hint;
  const Twist(this.type, this.name, this.icon, this.hint);
}

const Map<TwistType, Twist> kTwists = {
  TwistType.zitakis: Twist(TwistType.zitakis, 'ZİT AKIŞ', '⇄', 'Blok yönü her mükemmelle değişir!'),
  TwistType.ruzgargulu: Twist(TwistType.ruzgargulu, 'RÜZGAR GÜLÜ', '✥', 'Blok hafif salınarak gelir — ritmini bul.'),
  TwistType.dargecit: Twist(TwistType.dargecit, 'DAR GEÇİT', '◫', 'Duvarlar daralıyor — geçit daralır!'),
  TwistType.altinyagmuru: Twist(TwistType.altinyagmuru, 'ALTIN YAĞMURU', '✨', 'Bazı bloklar altın — para patlar!'),
  TwistType.sicrayan: Twist(TwistType.sicrayan, 'SIÇRAYAN', '⤾', 'Bloklar bir kez toparlanarak oturur — affedici.'),
  TwistType.kritik: Twist(TwistType.kritik, 'KRİTİK', '⚡', 'Mükemmeller bazen ×5 KRİTİK vurur!'),
  TwistType.ciftkule: Twist(TwistType.ciftkule, 'ÇİFT KULE', '⑊', 'İki kule, tek hedef — seçim senin.'),
  TwistType.golgeblok: Twist(TwistType.golgeblok, 'GÖLGE BLOK', '◬', 'Hayalet blok farklı hızda dolaşır.'),
};

/// İlk 5 bölüm: 5 FARKLI deneyim (hard-coded şema — C-017).
const List<TwistType?> kFirstFive = [
  null, // 1. bölüm: çekirdeği öğretir
  TwistType.altinyagmuru, // 2: ilk büyük sürpriz (para yağmuru)
  TwistType.ruzgargulu, // 3: hareket hissi
  TwistType.zitakis, // 4: yön zekâsı
  TwistType.kritik, // 5: büyük patlama patronu
];

/// Yeni-tür havuzu (ilk-5 sonrası döngü).
const List<TwistType> kTwistPool = [
  TwistType.dargecit,
  TwistType.altinyagmuru,
  TwistType.sicrayan,
  TwistType.zitakis,
  TwistType.kritik,
  TwistType.ruzgargulu,
];

/// Dağıtım yasası (C-017):
/// - i<5 → kFirstFive[i]
/// - aksi: her 3 bölümden 1'i (i%3==2) twist alır; ardışık aynı tür ≤2.
TwistType? twistFor(int i) {
  if (i < 0) return null; // günlük/serbest: twist yok
  if (i < kFirstFive.length) return kFirstFive[i];
  if (i % 3 != 2) return null;
  final pick = kTwistPool[(i ~/ 3) % kTwistPool.length];
  // ardışık tekrar koruması: önceki iki twist ile aynıysa havuzda ilerle
  if (twistFor(i - 1) == pick || twistFor(i - 2) == pick) {
    final alt = kTwistPool[(kTwistPool.indexOf(pick) + 1) % kTwistPool.length];
    if (twistFor(i - 1) != alt && twistFor(i - 2) != alt) return alt;
  }
  return pick;
}
