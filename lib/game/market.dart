/// Stack Tower Game — PAZAR YERİ (PB-018, RESEARCH-market §4 D4).
/// Günlük rotasyon (3 ürün) + gizli sandık; saf mantık, UI'dan bağımsız.
/// C-019 cömertlik: her 4-5 bölümde 1 satın alma gücü; fiyatlar bölüm kazancı
/// ölçeğinde (40-150), günde tek stok.
library;

import 'dart:math' as math;

import 'progress.dart' as prog;

enum MarketKind { skin, shield, double, joker, coins, chest }

class MarketEntry {
  final String id;
  final MarketKind kind;
  final String name;
  final String icon;
  final String hint;
  final int price;
  final int hue;
  final String? skinId;

  const MarketEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.icon,
    required this.hint,
    required this.price,
    required this.hue,
    this.skinId,
  });

  bool get isChest => kind == MarketKind.chest;
}

class MarketPurchase {
  final bool ok;
  final String message;
  final int coinsSpent;
  final String? skinId;
  const MarketPurchase(
      {required this.ok,
      required this.message,
      this.coinsSpent = 0,
      this.skinId});
}

MarketPurchase _fail(String why) =>
    MarketPurchase(ok: false, message: why);

/* ----------------------------- rotasyon ----------------------------- */

/// Gün tohumlu deterministik LCG (kayıt dışı, tekrar üretilebilir).
int _seedFor(int day) => ((day + 1) * 1103515245 + 12345) & 0x7FFFFFFF;

class _Lcg {
  int _s;
  _Lcg(this._s);
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7FFFFFFF;
    return _s / 0x7FFFFFFF;
  }

  int nextInt(int n) => n <= 0 ? 0 : (next() * n).floor().clamp(0, n - 1);
}

const List<int> _productHues = [45, 192, 322, 130, 280, 12];

/// Günün 3 ürünü + 1 gizli sandık. Tezgah YALNIZ güne bağlıdır: satın alma
/// rotasyonu değiştirmez (aynı gün aynı ürünler, stok kapanır).
List<MarketEntry> dailyStock(int day) {
  final rnd = _Lcg(_seedFor(day));
  final entries = <MarketEntry>[];

  final paidSkins =
      prog.kSkins.where((s) => s.price > 0).toList(growable: false);

  // 1) görünüm (indirimli)
  {
    final s = paidSkins[rnd.nextInt(paidSkins.length)];
    entries.add(MarketEntry(
      id: 'skin:${s.id}',
      kind: MarketKind.skin,
      name: 'GÖRÜNÜM: ${s.name}',
      icon: '🎨',
      hint: 'Mağazada ${s.price} 🪙 — pazarda indirimli.',
      price: math.max(40, (s.price * 0.55).round()),
      hue: s.hue,
      skinId: s.id,
    ));
  }

  // 2) kalkan (sonraki bölüm +1 kalkan)
  entries.add(const MarketEntry(
    id: 'shield',
    kind: MarketKind.shield,
    name: 'KALKAN',
    icon: '🛡',
    hint: 'Sonraki bölümde +1 kalkan.',
    price: 50,
    hue: 192,
  ));

  // 3) çarpan / joker (gün çiftine göre)
  if (day.isEven) {
    entries.add(const MarketEntry(
      id: 'double',
      kind: MarketKind.double,
      name: 'ALTIN ÇARPAN',
      icon: '✨',
      hint: 'Sonraki bölümün parası ×2.',
      price: 80,
      hue: 45,
    ));
  } else {
    entries.add(const MarketEntry(
      id: 'joker',
      kind: MarketKind.joker,
      name: 'JOKER',
      icon: '🃏',
      hint: 'Sonraki kazanılan bölümde +1 yıldız.',
      price: 70,
      hue: 280,
    ));
  }

  // 4) gizli sandık (değişken oran — her gün, tek adet)
  entries.add(const MarketEntry(
    id: 'chest',
    kind: MarketKind.chest,
    name: 'GİZLİ SANDIK',
    icon: '🎁',
    hint: 'İçinde ne var? Değişken oran: para / görünüm / kalıntı.',
    price: 120,
    hue: 322,
  ));

  // hue rotasyonu (gün bazlı renk tazeliği)
  final shift = rnd.nextInt(_productHues.length);
  return [
    for (var i = 0; i < entries.length; i++)
      entries[i].isChest
          ? entries[i]
          : MarketEntry(
              id: entries[i].id,
              kind: entries[i].kind,
              name: entries[i].name,
              icon: entries[i].icon,
              hint: entries[i].hint,
              price: entries[i].price,
              hue: _productHues[(shift + i) % _productHues.length],
              skinId: entries[i].skinId,
            ),
  ];
}

/// Gün değişince stok sıfırlanır (satın alınanlar yeni günde tazelenir).
void rollDay(prog.SaveState state, int day) {
  if (state.marketDay == day) return;
  state.marketDay = day;
  state.marketBought.clear();
}

bool soldOut(prog.SaveState state, MarketEntry e) =>
    state.marketBought[e.id] == true;

/* ----------------------------- satın alma ----------------------------- */

/// Satın alma: para düşer, stok kapanır. Sandık değişken oranlıdır ([rand]
/// enjeksiyonu test için). Para asla negatife düşmez.
MarketPurchase buy(prog.SaveState state, MarketEntry e,
    {math.Random? rand, int stage = 0}) {
  if (soldOut(state, e)) return _fail('TÜKENDİ');
  if (e.kind == MarketKind.skin && e.skinId != null && state.skins.contains(e.skinId)) {
    return _fail('ZATEN SAHİPSİN');
  }
  if (state.coins < e.price) return _fail('YETERSİZ PARA');

  state.coins -= e.price;
  state.marketBought[e.id] = true;

  switch (e.kind) {
    case MarketKind.skin:
      final id = e.skinId;
      if (id != null && !state.skins.contains(id)) state.skins.add(id);
      return MarketPurchase(
          ok: true,
          message: 'YENİ GÖRÜNÜM AÇILDI',
          coinsSpent: e.price,
          skinId: id);
    case MarketKind.shield:
      state.marketShields += 1;
      return MarketPurchase(
          ok: true, message: 'SONRAKİ BÖLÜM +1 KALKAN', coinsSpent: e.price);
    case MarketKind.double:
      state.marketDouble = true;
      return MarketPurchase(
          ok: true, message: 'SONRAKİ BÖLÜM ×2 PARA', coinsSpent: e.price);
    case MarketKind.joker:
      state.marketJoker = true;
      return MarketPurchase(
          ok: true, message: 'SONRAKİ BÖLÜM +1 YILDIZ', coinsSpent: e.price);
    case MarketKind.coins:
      state.coins += 90;
      return MarketPurchase(
          ok: true, message: '+90 PARA', coinsSpent: e.price);
    case MarketKind.chest:
      return _openChest(state, e, rand ?? math.Random(), stage);
  }
}

/// Kalıntı parçası ekler; 3'e ulaşınca sıradaki kalıntıyı açar.
/// Dönüş: açılan kalıntının adı (parça 3'e ulaşmadıysa null).
String? addRelicPiece(prog.SaveState state) {
  state.relicPieces += 1;
  if (state.relicPieces < 3) return null;
  state.relicPieces -= 3;
  final missing =
      prog.kRelics.where((r) => state.relics[r.stage.toString()] != true);
  if (missing.isEmpty) {
    state.coins += 150; // tüm kalıntılar açık → paraya çevrilir
    return null;
  }
  final relic = missing.first;
  state.relics[relic.stage.toString()] = true;
  return relic.name;
}

/// Sandık: %45 para, %30 görünüm, %25 kalıntı parçası (3 parça = 1 kalıntı).
MarketPurchase _openChest(prog.SaveState state, MarketEntry e, math.Random rnd, int stage) {
  final r = rnd.nextDouble();
  if (r < 0.45) {
    state.coins += 120;
    return MarketPurchase(
        ok: true, message: 'SANDIK: +120 PARA', coinsSpent: e.price);
  }
  if (r < 0.75) {
    final locked = prog.kSkins
        .where((s) => s.price > 0 && !state.skins.contains(s.id))
        .toList(growable: false);
    if (locked.isNotEmpty) {
      final s = locked[rnd.nextInt(locked.length)];
      state.skins.add(s.id);
      return MarketPurchase(
          ok: true,
          message: 'SANDIK: ${s.name} GÖRÜNÜMÜ',
          coinsSpent: e.price,
          skinId: s.id);
    }
    state.coins += 120;
    return MarketPurchase(
        ok: true, message: 'SANDIK: +120 PARA', coinsSpent: e.price);
  }
  // kalıntı parçası
  final relicName = addRelicPiece(state);
  if (relicName != null) {
    return MarketPurchase(
        ok: true,
        message: 'SANDIK: $relicName KALINTISI',
        coinsSpent: e.price);
  }
  return MarketPurchase(
      ok: true,
      message: state.relicPieces == 0
          ? 'SANDIK: +150 PARA'
          : 'SANDIK: KALINTI PARÇASI (${state.relicPieces}/3)',
      coinsSpent: e.price);
}
