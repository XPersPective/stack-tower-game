/// Stack Tower Game — SOSYAL KATMAN MVP (PB-038).
///
/// Kullanıcı isteği: "kullanıcılar birbirleriyle mesajlaşabilsin; oyuncu
/// listesi; oyun oynarken yanda akış; aynı tohumlu bölümde daha yüksek puan
/// meydan okuması." MVP istemci-içi: 5 BOT rakip (ŞEFFAF 'BOT' etiketli —
/// kandırma yok, RESEARCH-social AviaGames dersi), 32 Türkçe hazırcümle
/// (serbest metin YOK — Apple 1.2 güvenlik), tohumlu meydan okuma.
/// Gerçek çok oyunculu F0 worker deploy kararıyla ayrı görevdir.
library;

import 'dart:math' as math;

import 'progress.dart' as prog;

/// Kategori türleri — hazırcümle şeridi sekmeleri.
enum SocialCategory { selam, tebrik, meydan, iddia, veda }

/// Tek quick-chat hazırcümlesi.
class QuickPhrase {
  final SocialCategory category;
  final String text;
  const QuickPhrase(this.category, this.text);
}

/// 32 Türkçe hazırcümle — serbest metin yok (Apple 1.2 çocuk güvenliği).
const List<QuickPhrase> kQuickPhrases = [
  // selam (6)
  QuickPhrase(SocialCategory.selam, 'Merhaba!'),
  QuickPhrase(SocialCategory.selam, 'Selam! Nasılsın?'),
  QuickPhrase(SocialCategory.selam, 'İyi oyunlar!'),
  QuickPhrase(SocialCategory.selam, 'Hoş geldin!'),
  QuickPhrase(SocialCategory.selam, 'Ne oynuyorsun bugün?'),
  QuickPhrase(SocialCategory.selam, 'Kule kaç oldu?'),
  // tebrik (7)
  QuickPhrase(SocialCategory.tebrik, 'Harika kule!'),
  QuickPhrase(SocialCategory.tebrik, 'Bravo, mükemmel bırakış!'),
  QuickPhrase(SocialCategory.tebrik, 'Rekor kırdın!'),
  QuickPhrase(SocialCategory.tebrik, 'Muhteşem kombolar!'),
  QuickPhrase(SocialCategory.tebrik, 'Çok temiz oynadın!'),
  QuickPhrase(SocialCategory.tebrik, 'O baharı gördüm, efsane!'),
  QuickPhrase(SocialCategory.tebrik, 'Patronu da ezdin, helal!'),
  // meydan (7)
  QuickPhrase(SocialCategory.meydan, 'Meydan okuyorum!'),
  QuickPhrase(SocialCategory.meydan, 'Kuleme yetişebilir misin?'),
  QuickPhrase(SocialCategory.meydan, 'Bu hafta Kabus benim!'),
  QuickPhrase(SocialCategory.meydan, 'Rekoruma gel!'),
  QuickPhrase(SocialCategory.meydan, 'Günlük tahtada görüşürüz!'),
  QuickPhrase(SocialCategory.meydan, 'Seni geçeceğim, haberin olsun!'),
  QuickPhrase(SocialCategory.meydan, 'Son turda buluşalım!'),
  // iddia (6)
  QuickPhrase(SocialCategory.iddia, 'Bugün 20 blok atacağım!'),
  QuickPhrase(SocialCategory.iddia, 'Kabus Kulesi\'ni yerle bir edeceğim!'),
  QuickPhrase(SocialCategory.iddia, '5 mükemmel seri geliyor!'),
  QuickPhrase(SocialCategory.iddia, 'Günlük tahtada 1 numara ben olacağım!'),
  QuickPhrase(SocialCategory.iddia, 'Altın Hazine benim!'),
  QuickPhrase(SocialCategory.iddia, 'Bu akşam rekor kırma zamanı!'),
  // veda (6)
  QuickPhrase(SocialCategory.veda, 'Kolay gelsin!'),
  QuickPhrase(SocialCategory.veda, 'Görüşürüz, iyi oyunlar!'),
  QuickPhrase(SocialCategory.veda, 'Yarın devam!'),
  QuickPhrase(SocialCategory.veda, 'Ben kaçtım, iyi eğlenceler!'),
  QuickPhrase(SocialCategory.veda, 'Sonra konuşuruz!'),
  QuickPhrase(SocialCategory.veda, 'Bol şans!'),
];

/// 5 BOT rakip profili — ŞEFFAF 'BOT' etiketli (kandırma yok).
class SocialPlayer {
  final String name;
  final int rankPoints;
  final int avatarHue;
  final bool isBot;
  const SocialPlayer({
    required this.name,
    required this.rankPoints,
    required this.avatarHue,
    this.isBot = true,
  });
}

/// 5 bot rakip — isim/hue deterministik (LCG değil, sabit tablo).
const List<SocialPlayer> kBotPlayers = [
  SocialPlayer(name: 'NeonKule', rankPoints: 340, avatarHue: 210),
  SocialPlayer(name: 'KuleUstası', rankPoints: 720, avatarHue: 268),
  SocialPlayer(name: 'BlokAvcısı', rankPoints: 1180, avatarHue: 45),
  SocialPlayer(name: 'GölgeDokunan', rankPoints: 1650, avatarHue: 322),
  SocialPlayer(name: 'ZirveAvcısı', rankPoints: 2400, avatarHue: 130),
];

/// Oyuncunun Friend Tag'i — kayıttan deterministik 6 karakter (A-Z0-9).
String friendTagFor(prog.SaveState s) {
  final seed = s.totalBlocks * 31 + s.levelsDone * 7 + s.totalPerfect;
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = math.Random(seed.clamp(1, 1 << 30));
  return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Bir mesaj — 1:1 sohbet balonu.
class SocialMessage {
  final String sender; // 'SEN' | bot adı
  final String text;
  final bool mine;
  final bool isChallenge; // meydan okuma mesajı
  const SocialMessage(this.sender, this.text,
      {required this.mine, this.isChallenge = false});
}

/// Bot yanıt motoru — kullanıcı hazırcümlesinin kategorisine göre
/// deterministik yanıt (LCG tohumlu; aynı giriş → aynı yanıt).
String botReply(String botName, SocialCategory userCategory, int turnIndex) {
  final r = math.Random(botName.hashCode + turnIndex * 31);
  switch (userCategory) {
    case SocialCategory.selam:
      return const ['Merhaba!', 'Selam, hoş geldin!', 'İyi oyunlar!'][
          r.nextInt(3)];
    case SocialCategory.tebrik:
      return const [
        'Sağol, sende de!',
        'Teşekkürler!',
        'Senin kuleler de efsane!'
      ][r.nextInt(3)];
    case SocialCategory.meydan:
      return const [
        'Kabul! Meydan okumaya hazırsın.',
        'Gel bakalım, rekorumu koruyorum!',
        'Seni bekliyorum!'
      ][r.nextInt(3)];
    case SocialCategory.iddia:
      return const [
        'Hmm, iddialısın! Görürüz.',
        'Bahis yapmazdım ama bakarız!',
        'O zaman ben de artırıyorum!'
      ][r.nextInt(3)];
    case SocialCategory.veda:
      return const ['Görüşürüz!', 'İyi oyunlar, yarın devam!', 'Kolay gelsin!'][
          r.nextInt(3)];
  }
}

/// Meydan okuma tohumu — hafta + bot adından deterministik rakip skoru.
/// Kullanıcı bu tohumla aynı bölümü oynar; skoru rakibi geçerse kazanır.
int challengeBotScore(String botName, int week) {
  final r = math.Random(botName.hashCode + week * 7919);
  return 10 + r.nextInt(12); // 10..21 blok
}

/// Sohbet sekmesi durumu — bot başına son N mesaj (uygulama-içi, kalıcı değil).
class ChatThread {
  final String botName;
  final List<SocialMessage> messages = [];
  int _turn = 0;
  ChatThread(this.botName) {
    // açılış selamı — bot başlar
    messages.add(SocialMessage(botName, 'Merhaba! İyi oyunlar!',
        mine: false, isChallenge: false));
  }

  void addMine(String text, {bool isChallenge = false}) {
    messages.add(SocialMessage('SEN', text,
        mine: true, isChallenge: isChallenge));
    if (isChallenge) {
      // meydan okuma yanıtında bot skoru da paylaşır
      final week = DateTime.now().millisecondsSinceEpoch ~/ 86400000 ~/ 7;
      final score = challengeBotScore(botName, week);
      messages.add(SocialMessage(
          botName,
          'Kabul! Ben $score blok dizdim. Sen kaç yapabilirsin?',
          mine: false));
      return;
    }
    final cat = _categoryOf(text);
    messages.add(SocialMessage(botName, botReply(botName, cat, _turn++),
        mine: false));
  }

  /// Hazırcümle metninden kategori eşleme (quick-chat şeridi için).
  static SocialCategory _categoryOf(String text) {
    for (final p in kQuickPhrases) {
      if (p.text == text) return p.category;
    }
    return SocialCategory.selam;
  }

  /* ---------------- PB-039: kalıcılık ---------------- */

  /// Kayıttan sohbet kurar (boş kayıt → açılış selamı).
  ChatThread.fromLogs(this.botName, List<String> logs) {
    for (final line in logs) {
      final parts = line.split('|');
      if (parts.length < 2) continue;
      final mine = parts[0] == 'M';
      final isChallenge = parts.length > 2 && parts[2] == '1';
      messages.add(SocialMessage(mine ? 'SEN' : botName, parts[1],
          mine: mine, isChallenge: isChallenge));
    }
    if (messages.isEmpty) {
      messages.add(SocialMessage(botName, 'Merhaba! İyi oyunlar!',
          mine: false));
    }
    _turn = messages.where((m) => m.mine).length;
  }

  /// Sohbeti kayıt satırlarına sıkıştırır (son 40 mesaj).
  List<String> serialize() => messages
      .takeLast(40)
      .map((m) =>
          '${m.mine ? 'M' : 'B'}|${m.text}${m.isChallenge ? '|1' : ''}')
      .toList();
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int n) =>
      length <= n ? toList() : sublist(length - n);
}

/// PB-039: günlük bot selamı — gün tohumlu bot + mesaj (bildirim balonu).
(String bot, String text) dailyBotGreeting(int day) {
  final bot = kBotPlayers[day % kBotPlayers.length];
  final r = math.Random(day * 31 + 7);
  final pool = const [
    'Bugün 20 blok atacağım, seni bekliyorum!',
    'Kabus Kulesi bu hafta benim!',
    'Günlük tahtada görüşürüz!',
    'Rekorumu gördüm — tekrar oyna da geç beni!',
    'İyi oyunlar! Meydan okumaya var mısın?',
  ];
  return (bot.name, pool[r.nextInt(pool.length)]);
}
