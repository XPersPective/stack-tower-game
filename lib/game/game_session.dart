/// Stack Tower Game — oturum akışı (ui.js portunun Dart karşılığı).
/// Kazanma zinciri: kutu → dünya töreni → günlük tahta → sonuç → harita.
/// Kayıt her önemli olayda anında yazılır (SPEC §5).
library;

import 'package:flutter/material.dart';

import 'gameplay.dart';
import 'levels.dart';
import 'progress.dart' as prog;
import '../map/construction.dart';
import '../services/storage.dart';

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
    // Eski kayıtlar: bitirilmiş + kutlanmış dünyaların kalıntılarını geriye dönük ver.
    for (var st = 0; st < kStageCount; st++) {
      if (prog.isWorldComplete(state, st) &&
          state.worldsCelebrated[st.toString()] == true) {
        prog.awardRelic(state, st);
      }
    }
    persist();
    _constructing = false;
  }

  final KeyValueStorage storage;
  final DateTime Function() _clock;

  late prog.SaveState state;
  LevelDef? currentDef;
  LevelResult? pendingResult;
  prog.CompleteResult? pendingRewards;
  Surprise? currentSurprise;
  bool doubleCoinsThisLevel = false;
  WorldCeremony? lastCeremony;
  List<BoardRow> boardRows = [];
  int boardDay = 0;
  bool muted = false;

  /// Son bölümün inşaat katkısı (ADR-009: görünür amaç).
  ConstructionEvent? lastConstruction;

  final List<FlowStep> _chain = [];
  FlowStep? get nextStep => _chain.isEmpty ? null : _chain.first;

  bool _constructing = true;

  int get totalStars => prog.totalStars(state);
  String get activeSkinId => state.activeSkin;
  int get activeSkinHue => prog.skinById(state.activeSkin).hue;

  void persist() {
    prog.save(state, storage);
    if (!_constructing) notifyListeners();
  }

  /* ------------------------- Bölüm başlatma ------------------------- */

  /// openIntro + startCurrentLevel karşılığı: sürprizi belirle, motoru hazırla.
  LevelStart prepareLevel(LevelDef def) {
    currentDef = def;
    currentSurprise =
        (def.endless || def.daily) ? null : surpriseFor(def.i, prog.dayOf(_clock()));
    doubleCoinsThisLevel = currentSurprise?.effect == 'doubleCoins';
    final shields = currentSurprise?.effect == 'shieldUp' ? 2 : 1;
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
    final stars = starsFor(perfects, def.target);
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
    if (def.daily) prog.recordDaily(state, prog.dayOf(_clock()), blocks);

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

  /// lose sonrası (ui.js onEngineEvent 'lose'). Twist coin'leri yalnız
  /// kazanılan bölümde ödenir — kayıpta para birikmez.
  prog.CompleteResult onLose(int blocks, int perfects) {
    final def = currentDef!;
    final rw =
        prog.completeLevel(state, def, blocks: blocks, perfects: perfects, reached: false);
    if (doubleCoinsThisLevel) {
      final extra = rw.coins;
      rw.coins += extra;
      state.coins += extra;
    }
    if (def.daily) prog.recordDaily(state, prog.dayOf(_clock()), blocks);
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

  /// boardStep: yerel deterministik rakipler + SEN.
  void buildBoard() {
    final day = prog.dayOf(_clock());
    boardDay = day;
    final blocks = pendingResult?.blocks ?? state.daily['best'] ?? 0;
    final rows = prog.rivalsFor(day, blocks).map((r) => BoardRow(r.name, r.score)).toList();
    rows.add(BoardRow('SEN', blocks, me: true));
    rows.sort((a, b) => b.score.compareTo(a.score));
    boardRows = rows;
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
