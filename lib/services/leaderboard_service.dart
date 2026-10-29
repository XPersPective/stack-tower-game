/// Stack Tower Game — skor tahtası istemci servisi (PB-011, SPEC §6/§7).
/// "Skor asla kaybolmaz": gönderim başarısız olursa kayıt kuyrukta kalır.
/// Ağ katmanı enjekte edilir (test: sahte taşıyıcı; üretim: dart:io HttpClient).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'storage.dart';

/* ------------------------------ taşıyıcı ------------------------------ */

class HttpReply {
  final int status;
  final String body;
  const HttpReply(this.status, this.body);

  bool get ok => status >= 200 && status < 300;
  Map<String, dynamic>? get json {
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}

/// Ağ taşıyıcısı — testte sahte, üretimde [IoHttpTransport].
abstract class HttpTransport {
  Future<HttpReply> post(String path, Map<String, dynamic> body, {String? token});
  Future<HttpReply> get(String path, {String? token});
  Future<HttpReply> delete(String path, {String? token});
}

/// dart:io tabanlı gerçek taşıyıcı (ek paket gerekmez).
class IoHttpTransport implements HttpTransport {
  IoHttpTransport(this.baseUrl, {this.timeout = const Duration(seconds: 8)});
  final String baseUrl;
  final Duration timeout;

  Future<HttpReply> _send(String method, String path,
      {Map<String, dynamic>? body, String? token}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client
          .openUrl(method, Uri.parse('$baseUrl$path'))
          .timeout(timeout);
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.set('authorization', 'Bearer $token');
      if (body != null) req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      return HttpReply(res.statusCode, text);
    } catch (_) {
      return const HttpReply(0, '');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<HttpReply> post(String path, Map<String, dynamic> body, {String? token}) =>
      _send('POST', path, body: body, token: token);

  @override
  Future<HttpReply> get(String path, {String? token}) =>
      _send('GET', path, token: token);

  @override
  Future<HttpReply> delete(String path, {String? token}) =>
      _send('DELETE', path, token: token);
}

/* ------------------------------ kuyruk ------------------------------ */

class ScoreEntry {
  final String board;
  final int day;
  final int score;
  const ScoreEntry(this.board, this.day, this.score);

  Map<String, dynamic> toJson() => {'board': board, 'day': day, 'score': score};

  static ScoreEntry? fromJson(Map<String, dynamic> j) {
    final board = j['board'];
    if (board is! String || board.isEmpty) return null;
    return ScoreEntry(
      board,
      (j['day'] as num?)?.toInt() ?? -1,
      (j['score'] as num?)?.toInt() ?? 0,
    );
  }

  String get key => '$board:$day';
}

class LeaderboardRow {
  final String name;
  final int score;
  final bool me;
  const LeaderboardRow(this.name, this.score, {this.me = false});
}

class LeaderboardView {
  final List<LeaderboardRow> rows;
  final int? myRank;
  final int? myScore;
  const LeaderboardView(this.rows, {this.myRank, this.myScore});
}

/* ------------------------------ servis ------------------------------ */

class LeaderboardService {
  LeaderboardService({
    required this.storage,
    required this.transport,
    this.sessionToken,
    this.maxQueue = 50,
  }) {
    _load();
  }

  static const String kQueueKey = 'stacktower_lb_queue_v1';

  final KeyValueStorage storage;
  final HttpTransport transport;
  final int maxQueue;

  /// Oturum belirteci (yalnız bellekte; kalıcı kopya SessionService'te).
  String? sessionToken;

  final List<ScoreEntry> _queue = [];
  bool _flushing = false;

  List<ScoreEntry> get queue => List.unmodifiable(_queue);
  bool get flushing => _flushing;

  void _load() {
    _queue.clear();
    final raw = storage.getString(kQueueKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        for (final e in list) {
          final entry = ScoreEntry.fromJson(e as Map<String, dynamic>);
          if (entry != null) _queue.add(entry);
        }
      }
    } catch (_) {
      // bozuk kuyruk: sessizce boş başla (oyun asla kırılmaz)
    }
  }

  void _persist() {
    try {
      storage.setString(
          kQueueKey, jsonEncode([for (final e in _queue) e.toJson()]));
    } catch (_) {}
  }

  /// Kuyruğa yazar: aynı board+day için YALNIZ en yüksek skor tutulur.
  /// Kuyruk tavanı aşılırsa en eski kayıt düşer.
  void enqueue(String board, int day, int score) {
    final key = '$board:$day';
    final i = _queue.indexWhere((e) => e.key == key);
    if (i >= 0) {
      if (score > _queue[i].score) {
        _queue[i] = ScoreEntry(board, day, score);
      }
    } else {
      _queue.add(ScoreEntry(board, day, score));
      while (_queue.length > maxQueue) {
        _queue.removeAt(0);
      }
    }
    _persist();
  }

  /// Oturum varsa kuyruğu toplu gönderir. Başarısızlıkta kuyruk AYNEN kalır.
  /// Eşzamanlılık: aynı anda tek flush.
  Future<bool> flush() async {
    if (_flushing || _queue.isEmpty) return false;
    final token = sessionToken;
    if (token == null) return false;
    _flushing = true;
    try {
      final res = await transport.post('/score', {
        'entries': [for (final e in _queue) e.toJson()],
      }, token: token);
      if (!res.ok) return false;
      _queue.clear();
      _persist();
      return true;
    } catch (_) {
      return false;
    } finally {
      _flushing = false;
    }
  }

  /// Tahtayı getirir (ilk 100 + kendi sırası). Ağ yok/hata → null
  /// (ekran yerel `rivalsFor` tahtasına düşer).
  Future<LeaderboardView?> fetchBoard(String board, {int? day}) async {
    try {
      final q = day == null ? '' : '&day=$day';
      final res = await transport.get('/leaderboard?board=$board$q',
          token: sessionToken);
      if (!res.ok) return null;
      final j = res.json;
      if (j == null) return null;
      final rows = <LeaderboardRow>[];
      final list = j['rows'];
      if (list is List) {
        for (final r in list.take(100)) {
          final m = r as Map<String, dynamic>;
          rows.add(LeaderboardRow(
            (m['name'] as String?) ?? '—',
            (m['score'] as num?)?.toInt() ?? 0,
            me: m['me'] == true,
          ));
        }
      }
      return LeaderboardView(rows,
          myRank: (j['rank'] as num?)?.toInt(),
          myScore: (j['score'] as num?)?.toInt());
    } catch (_) {
      return null;
    }
  }

  /// Hesap silinince yerel kuyruk da temizlenir (sunucuya gönderilmez).
  void clearQueue() {
    _queue.clear();
    _persist();
  }
}
