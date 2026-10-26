/// Stack Tower Game — sürpriz motoru: twist türleri ve dağıtım yasası.
/// ADR-006: çekirdek bırakma matematiği değişmez; twist'ler üst katman
/// kancalarıyla (spawn yönü/açısı, çarpanlar, bölüm olayları) eklenir.
/// RESEARCH-market.md §4 D1 (kullanıcı yönü 2026-10-25).
///
/// Tür-farkındalık (inceleme bulgusu, 2026-10-26): twist'ler yalnız KULE
/// (stack) motorunda etkin; dağıtım yasası bu yüzden yalnız stack bölümlerine
/// atama yapar — atanan her twist oyuncuya gerçekten ulaşır.
library;

import 'levels.dart' show GameKind, kindFor;

enum TwistType {
  zitakis, // spawn yönü her mükemmelle değişir
  ruzgargulu, // blok ±15° açıyla süzülür, oturunca düzelir
  dargecit, // yan duvarlar daralır — geçit hedefi daraltır
  altinyagmuru, // rastgele bloklar altındır — para patlaması
  sicrayan, // bırakınca bir kez en yakın hizaya toparlanır (affedici)
  kritik, // mükemmeller %20 ihtimalle ×5 kritik (para ×5)
  golgeblok, // hayalet ikiz farklı hızda dolaşır — hiçbir kuralı etkilemez
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
  TwistType.golgeblok: Twist(TwistType.golgeblok, 'GÖLGE BLOK', '◬', 'Hayalet blok farklı hızda dolaşır.'),
};

/// İlk 5 STACK bölümü: 5 FARKLI deneyim (hard-coded şema — C-017).
/// 1. stack bölümü çekirdeği öğretir (twistsiz); sırasıyla para, hareket,
/// yön zekâsı ve patlama sürprizi gelir.
const List<TwistType?> kFirstFive = [
  null, // 1. stack bölümü: çekirdeği öğretir
  TwistType.altinyagmuru, // 2: ilk büyük sürpriz (para yağmuru)
  TwistType.ruzgargulu, // 3: hareket hissi
  TwistType.zitakis, // 4: yön zekâsı
  TwistType.kritik, // 5: büyük patlama patronu
];

/// Yeni-tür havuzu (ilk-5 sonrası döngü). Sıra, 150 bölümde 7 türün
/// tamamının en az bir kez atanmasını garanti eder.
const List<TwistType> kTwistPool = [
  TwistType.dargecit,
  TwistType.sicrayan,
  TwistType.golgeblok,
  TwistType.altinyagmuru,
  TwistType.zitakis,
  TwistType.kritik,
  TwistType.ruzgargulu,
];

/// i kaçıncı STACK bölümü (0 tabanlı)? Stack değilse -1.
int stackOrdinalOf(int i) {
  var n = -1;
  for (var k = 0; k <= i; k++) {
    if (kindFor(k) == GameKind.stack) n++;
  }
  return n;
}

/// Dağıtım yasası (C-017, tür-farkında — 2026-10-26 revizyonu):
/// - i<0 (günlük/serbest) veya stack olmayan bölüm → twist yok
/// - 1. stack bölümü (n=0) çekirdeği öğretir → twist yok
/// - ilk 5 stack bölümünden n=1..4 → kFirstFive (stack sırasıyla)
/// - sonraki HER stack bölümü → havuz rotasyonu (7 tür döngüsü);
///   ardışık atanan aynı tür ≤2 (koruma havuzda ilerletir).
/// Yoğunluk notu: 10 tür döngüsünde stack ~1/10 sıklıkta; %3 seyreltmesi
/// twist'i ~5/150 bölüme düşürüp sürpriz amacını boğar — ilk-5 şemasıyla
/// tutarlı olarak her stack bölümü twist taşır.
TwistType? twistFor(int i) {
  if (i < 0) return null;
  // bölümün kendisi stack değilse (catcher/ring/...) ordinal'i ne olursa olsun twist yok
  if (kindFor(i) != GameKind.stack) return null;
  final n = stackOrdinalOf(i);
  if (n <= 0) return null;
  if (n < kFirstFive.length) return kFirstFive[n];
  // atama sırasına göre havuz rotasyonu + ardışık tekrar koruması
  final assigned = <TwistType>[];
  for (var m = kFirstFive.length; m <= n; m++) {
    var pick = kTwistPool[assigned.length % kTwistPool.length];
    final p1 = assigned.isNotEmpty ? assigned.last : null;
    final p2 = assigned.length > 1 ? assigned[assigned.length - 2] : null;
    if (pick == p1 && pick == p2) {
      pick = kTwistPool[(kTwistPool.indexOf(pick) + 1) % kTwistPool.length];
    }
    assigned.add(pick);
    if (m == n) return pick;
  }
  return null;
}
