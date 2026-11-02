/// Stack Tower Game — oturum akışı (ui.js portunun Dart karşılığı).
/// Kazanma zinciri: kutu → dünya töreni → günlük tahta → sonuç → harita.
/// Kayıt her önemli olayda anında yazılır (SPEC §5).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gameplay.dart';
import 'levels.dart';
import 'market.dart' as market;
import 'progress.dart' as prog;
import '../map/construction.dart';
import '../services/leaderboard_service.dart';
import '../services/storage.dart';
import 'market.dart' show addRelicPiece;

/// Sonuç sonrası oynatılacak adımlar (ui.js chain karşılığı).
enum FlowStep { construction, box, world, board, result, showMap }

class WorldCeremony {
  final int stage;
  final int bonus;
  final prog.Relic? relic;
  const WorldCeremony(this.stage, this.bonus, this.relic);
}

class BoardRow {
  final String name;
  final int score;
  final bool me;
  const BoardRow(this.name, this.score, {this.me = false});
}

/// Bölüm başlangıç parametreleri.
class LevelStart {
  final int hue;
  final int shields;
  final Surprise? surprise;
  const LevelStart({required this.hue, required this.shields, this.surprise});
}

/// Uygulama çapında tek oturum: kayıt + akış. Provider ile sağlanır (ADR-004).
class GameSession extends ChangeNotifier {
  GameSession(this.storage, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    state = prog.load(storage);
    prog.ensureMissions(state, _clock());
    // PB-034: gün açılışı — streak sayacı (takvim talebi kullanıcıda, UI'dan)
    prog.touchStreak(state, prog.dayOf(_clock()));
    // Eski kayıtlar: bitirilmiş + kutlanmış dünyaların kalıntılarını geriye dönük ver.
    for (var st = 0; st < kStageCount; st++) {
      if (prog.isWorldComplete(state, st) &&
          state.worldsCelebrated[st.toString()] == true) {
        prog.awardRelic(state, st);
      }
    }
    persist();
  }

  final KeyValueStorage storage;
  final DateTime Function() _clock;

  /// PB-021: ilk-5 mini sürpriz kapısı — test enjeksiyonu ve son ödül etiketi.
  math.Random? firstRunRand;
  String? lastFirstRunGift;
  bool pendingMarketDiscovery = false;

  late prog.SaveState state;
  LevelDef? currentDef;
  LevelResult? pendingResult;
  prog.CompleteResult? pendingRewards;
  Surprise? currentSurprise;
  String? lastNightmareRelic; // PB-035 B3: kabus kazanımında kalıntı adı
  bool doubleCoinsThisLevel = false;
  WorldCeremony? lastCeremony;
  List<BoardRow> boardRows = [];
  int boardDay = 0;

  /// Tahtada gösterilen satırlar bulut görünümü mü? (yoksa yerel rakipler)
  bool boardIsCloud = false;
  bool muted = false;

  /// Bulut skor tahtası servisi (PB-031). null → yalnız yerel rakipler.
  LeaderboardService? leaderboard;

  /// Son bölümün inşaat katkısı (ADR-009: görünür amaç).
  ConstructionEvent? lastConstruction;

  final List<FlowStep> _chain = [];
  FlowStep? get nextStep => _chain.isEmpty ? null : _chain.first;

  int get totalStars => prog.totalStars(state);
  String get activeSkinId => state.activeSkin;
  int get activeSkinHue => prog.skinById(state.activeSkin).hue;

  void persist() {
    prog.save(state, storage);
    notifyListeners();
  }

  /// Kaydı yazar ama dinleyicileri uyarmaz (build sırasında güvenli).
  void persistQuiet() => prog.save(state, storage);

  /* ------------------------- Bölüm başlatma ------------------------- */

  /// openIntro + startCurrentLevel karşılığı: sürprizi belirle, motoru hazırla.
  LevelStart prepareLevel(LevelDef def) {
    currentDef = def;
    currentSurprise =
        (def.endless || def.daily || def.nightmare)
            ? null
            : surpriseFor(def.i, prog.dayOf(_clock()));
    doubleCoinsThisLevel = currentSurprise?.effect == 'doubleCoins';
    var shields = currentSurprise?.effect == 'shieldUp' ? 2 : 1;
    // PB-018 pazar: satın alınan kalkan/çarpan bir sonraki bölümde tüketilir
    if (state.marketShields > 0) {
      shields += state.marketShields;
      state.marketShields = 0;
    }
    if (state.marketDouble) {
      doubleCoinsThisLevel = true;
      state.marketDouble = false;
    }
    persistQuiet(); // initState/build sırasında notify yok
    return LevelStart(hue: activeSkinHue, shields: shields, surprise: currentSurprise);
  }

  /// coinStart sürprizini uygula (bölüm başında para).
  int applyCoinStart() {
    if (currentSurprise?.effect != 'coinStart') return 0;
    final got = prog.applySurpriseCoins(state, currentSurprise);
    persist();
    return got;
  }

  /* --------------------------- Motor olayları --------------------------- */

  /// win sonrası ödül hesabı + zincir kurulumu (ui.js onEngineEvent 'win').
  /// [crits]/[goldBlocks] (STACK twist sayaçları) para olarak ödenir:
  /// KRİTİK mükemmelin ×5'i (taban 2 completeLevel'de ödenir, burada +8 → toplam 10),
  /// altın blok 10 (inceleme bulgusu).
  prog.CompleteResult onWin(int blocks, int perfects,
      {int crits = 0, int goldBlocks = 0}) {
    final def = currentDef!;
    // PB-035 B3: KABUS KULESİ — kayıp cezasız, kazanç: 40 para + kalıntı
    // parçası + rekor; normal bölüm ekonomisine (completed/yıldız) girmez.
    if (def.nightmare) {
      final week = weekOf(prog.dayOf(_clock()));
      prog.recordNightmare(state, week, blocks, true);
      final gained = 40;
      state.coins += gained;
      final relic = market.addRelicPiece(state); // cömertlik: kalıntı parçası
      persist();
      pendingResult = LevelResult(blocks, perfects, true);
      pendingRewards = prog.CompleteResult(coins: gained, firstClear: false);
      _chain.clear();
      _chain.add(FlowStep.result);
      _chain.add(FlowStep.showMap);
      lastNightmareRelic = relic;
      return pendingRewards!;
    }
    var stars = starsFor(perfects, def.target);
    // PB-018 pazar jokeri: sonraki kazanılan bölümde +1 yıldız (tavan 3)
    if (state.marketJoker) {
      state.marketJoker = false;
      stars = math.min(3, stars + 1);
    }
    final rewards = prog.completeLevel(state, def,
        blocks: blocks, perfects: perfects, reached: true, stars: stars);
    if (def.kind == GameKind.stack) {
      final twistCoins = crits * 8 + goldBlocks * 10;
      if (twistCoins > 0) {
        rewards.coins += twistCoins;
        state.coins += twistCoins;
      }
    }
    // PB-030: tür başına cömertlik bonusu (kayıpta ödenmez, C-019)
    final kindCoins = kindBonus(def.kind, perfects: perfects);
    if (kindCoins > 0) {
      rewards.coins += kindCoins;
      state.coins += kindCoins;
    }
    if (doubleCoinsThisLevel) {
      // sürpriz ödül×2 hem rapora hem cüzdana yansır
      final extra = rewards.coins;
      rewards.coins += extra;
      state.coins += extra;
    }
    // PB-021: ilk 5 bölümde her bölüm sonunda mini sürpriz kapısı
    lastFirstRunGift = null;
    if (rewards.firstClear && !def.daily && !def.endless && def.i >= 0 && def.i < 5) {
      final gift = _firstRunGift(def.i);
      if (gift.coins > 0) {
        rewards.coins += gift.coins;
        state.coins += gift.coins;
      }
      final skin = gift.skinId;
      if (skin != null) state.skins.add(skin);
      lastFirstRunGift = gift.label;
    }
    // PB-021: 3. bölümden sonra pazar keşfi bir kez duyurulur
    if (!def.daily && !def.endless && state.levelsDone >= 3 && !state.marketSeen) {
      pendingMarketDiscovery = true;
    }

    if (def.daily) _recordDailyScore(blocks);

    int? worldBonusCoins;
    final lastOfWorld =
        !def.endless && !def.daily && indexInStage(def.i) == kLevelsPerStage - 1;
    lastCeremony = null;
    if (lastOfWorld && prog.isWorldComplete(state, def.stage)) {
      worldBonusCoins = prog.applyWorldComplete(state, def.stage);
      if (worldBonusCoins != null) {
        lastCeremony = WorldCeremony(def.stage, worldBonusCoins, prog.relicFor(def.stage));
      }
    }
    persist();

    pendingResult = LevelResult(blocks, perfects, true);
    pendingRewards = rewards;
    // GÖRÜNÜR İNŞAAT: bu bölüm adada bir parça yükseltti (ADR-009)
    lastConstruction =
        (!def.endless && !def.daily) ? constructionFor(state, def.i) : null;
    _chain.clear();
    if (lastConstruction != null) _chain.add(FlowStep.construction);
    if (rewards.boxDropped) _chain.add(FlowStep.box);
    if (lastCeremony != null) _chain.add(FlowStep.world);
    if (def.daily) _chain.add(FlowStep.board);
    _chain.add(FlowStep.result);
    _chain.add(FlowStep.showMap);
    return rewards;
  }

  /// PB-021: ilk-5 kapısı — %80 para (20-60), %15 görünüm, %5 kalıntı parçası.
  ({String label, int coins, String? skinId}) _firstRunGift(int levelIdx) {
    final rnd = firstRunRand ?? math.Random(levelIdx * 7919 + 17);
    final r = rnd.nextDouble();
    if (r < 0.80) {
      final coins = 20 + rnd.nextInt(41); // 20..60
      return (label: 'SÜRPRİZ: +$coins 🪙', coins: coins, skinId: null);
    }
    if (r < 0.95) {
      final locked = prog.kSkins
          .where((s) => s.price > 0 && !state.skins.contains(s.id))
          .toList(growable: false);
      if (locked.isNotEmpty) {
        final s = locked[rnd.nextInt(locked.length)];
        return (label: 'SÜRPRİZ: ${s.name} GÖRÜNÜMÜ', coins: 0, skinId: s.id);
      }
      return (label: 'SÜRPRİZ: +40 🪙', coins: 40, skinId: null);
    }
    final relic = addRelicPiece(state);
    return (
      label: relic == null
          ? 'SÜRPRİZ: KALINTI PARÇASI (${state.relicPieces}/3)'
          : 'SÜRPRİZ: $relic KALINTISI',
      coins: 0,
      skinId: null
    );
  }

  /// lose sonrası (ui.js onEngineEvent 'lose'). Twist coin'leri yalnız
  /// kazanılan bölümde ödenir — kayıpta para birikmez.
  prog.CompleteResult onLose(int blocks, int perfects) {
    final def = currentDef!;
    // PB-035 B3: kabus kaybı CEZASIZ — teselli bile bozmadan sadece sonuç
    if (def.nightmare) {
      final week = weekOf(prog.dayOf(_clock()));
      prog.recordNightmare(state, week, blocks, false);
      persist();
      pendingResult = LevelResult(blocks, perfects, false);
      pendingRewards = prog.CompleteResult();
      _chain.clear();
      _chain.add(FlowStep.result);
      return pendingRewards!;
    }
    final rw =
        prog.completeLevel(state, def, blocks: blocks, perfects: perfects, reached: false);
    if (doubleCoinsThisLevel) {
      final extra = rw.coins;
      rw.coins += extra;
      state.coins += extra;
    }
    if (def.daily) _recordDailyScore(blocks);
    persist();

    pendingResult = LevelResult(blocks, perfects, false);
    pendingRewards = rw;
    _chain.clear();
    if (def.daily) _chain.add(FlowStep.board);
    _chain.add(FlowStep.result);
    return rw;
  }

  /// Zincirdeki sıradaki adımı tüket.
  FlowStep? popStep() {
    if (_chain.isEmpty) return null;
    final s = _chain.removeAt(0);
    notifyListeners();
    return s;
  }

  /* ------------------------- Günlük tahta ------------------------- */

  /// Günlük skoru kaydeder (yerel + bulut kuyruğu). "Skor asla kaybolmaz":
  /// gönderim başarısızsa [LeaderboardService] kuyrukta tutar (C-005).
  void _recordDailyScore(int blocks) {
    final day = prog.dayOf(_clock());
    prog.recordDaily(state, day, blocks);
    final lb = leaderboard;
    if (lb != null) {
      lb.enqueue('daily', day, blocks);
      // Bölüm sonu: oturum varsa tek eşzamanlı flush denemesi (PB-031).
      if (lb.sessionToken != null) lb.flush();
    }
  }

  /// boardStep: yerel deterministik rakipler + SEN (anında gösterim),
  /// oturum varsa arka planda bulut tahtasıyla yenilenir.
  void buildBoard() {
    final day = prog.dayOf(_clock());
    boardDay = day;
    _buildLocalBoard(day);
    final lb = leaderboard;
    if (lb != null && lb.sessionToken != null) {
      _refreshCloudBoard(lb, day);
    }
  }

  void _buildLocalBoard(int day) {
    final blocks = pendingResult?.blocks ?? state.daily['best'] ?? 0;
    final rows = prog.rivalsFor(day, blocks).map((r) => BoardRow(r.name, r.score)).toList();
    rows.add(BoardRow('SEN', blocks, me: true));
    rows.sort((a, b) => b.score.compareTo(a.score));
    boardRows = rows;
    boardIsCloud = false;
  }

  Future<void> _refreshCloudBoard(LeaderboardService lb, int day) async {
    final view = await lb.fetchBoard('daily', day: day);
    if (view == null || view.rows.isEmpty) return;
    if (day != boardDay) return; // gecikmiş eski-gün yanıtı bugünün tahtasını ezmesin
    boardRows = view.rows
        .map((r) => BoardRow(r.name, r.score, me: r.me))
        .toList();
    boardIsCloud = true;
    notifyListeners();
  }

  /* --------------------------- Kutu --------------------------- */

  prog.BoxResult? openBoxNow({double Function()? rand}) {
    if (currentDef == null) return null;
    final prize = prog.openBox(state, currentDef!, rand);
    persist();
    return prize;
  }

  /* --------------------------- Mağaza --------------------------- */

  prog.BuyResult buySkin(String id) {
    final r = prog.buySkin(state, id);
    if (r.ok) persist();
    return r;
  }

  bool equip(String id) {
    final ok = prog.equipSkin(state, id);
    if (ok) persist();
    return ok;
  }

  /* --------------------------- Görevler --------------------------- */

  List<Map<String, dynamic>> refreshMissions() {
    prog.ensureMissions(state, _clock());
    persist();
    return prog.missionItems(state);
  }

  /// Build içinde güvenli okuma (mutasyon/notify yok).
  List<Map<String, dynamic>> missionItemsSafe() => prog.missionItems(state);

  int? claimMissionAt(int index) {
    final items = prog.missionItems(state);
    if (index < 0 || index >= items.length) return null;
    final got = prog.claimMission(state, items[index]);
    if (got != null) persist();
    return got;
  }

  /* --------------------------- Harita verisi --------------------------- */

  int worldDone(int stage) {
    var c = 0;
    for (var k = 0; k < kLevelsPerStage; k++) {
      if (state.completed[stage * kLevelsPerStage + k] != null) c++;
    }
    return c;
  }

  bool worldOpen(int stage) => stage == 0 || totalStars >= requiredStars(stage);
}
