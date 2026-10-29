/// PB-011 — skor tahtası istemcisi: kuyruk, flush, kayıp yok, oturum.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stack_tower_game/game/progress.dart' as prog;
import 'package:stack_tower_game/services/leaderboard_service.dart';
import 'package:stack_tower_game/services/session.dart';
import 'package:stack_tower_game/services/storage.dart';

/// Sahte ağ taşıyıcısı: çağrıları kaydeder, sıradaki yanıtı döndürür.
class FakeTransport implements HttpTransport {
  FakeTransport();
  final List<String> calls = [];
  HttpReply nextPost = const HttpReply(200, '{}');
  HttpReply nextGet = const HttpReply(200, '{"rows":[]}');
  HttpReply nextDelete = const HttpReply(200, '{}');
  bool throwOnPost = false;
  Map<String, dynamic>? lastPostBody;
  String? lastToken;

  @override
  Future<HttpReply> post(String path, Map<String, dynamic> body, {String? token}) async {
    calls.add('POST $path');
    lastPostBody = body;
    lastToken = token;
    if (throwOnPost) throw StateError('ağ yok');
    return nextPost;
  }

  @override
  Future<HttpReply> get(String path, {String? token}) async {
    calls.add('GET $path');
    lastToken = token;
    return nextGet;
  }

  @override
  Future<HttpReply> delete(String path, {String? token}) async {
    calls.add('DELETE $path');
    lastToken = token;
    return nextDelete;
  }
}

void main() {
  group('kuyruk', () {
    test('aynı board+day için yalnız en yüksek skor tutulur', () {
      final storage = MemoryStorage();
      final lb = LeaderboardService(storage: storage, transport: FakeTransport());
      lb.enqueue('daily', 10, 30);
      lb.enqueue('daily', 10, 12); // düşük → yok sayılır
      expect(lb.queue.single.score, 30);
      lb.enqueue('daily', 10, 55);
      expect(lb.queue.single.score, 55);
      expect(lb.queue.length, 1);
    });

    test('farklı board/gün ayrı kayıt; tavan 50 (en eski düşer)', () {
      final lb = LeaderboardService(
          storage: MemoryStorage(), transport: FakeTransport(), maxQueue: 50);
      for (var i = 0; i < 60; i++) {
        lb.enqueue('daily', i, 10 + i);
      }
      expect(lb.queue.length, 50);
      expect(lb.queue.first.day, 10, reason: 'en eski 10 gün düştü');
      expect(lb.queue.last.day, 59);
    });

    test('kuyruk kalıcı: yeni servis aynı kayıtları okur', () {
      final storage = MemoryStorage();
      LeaderboardService(storage: storage, transport: FakeTransport())
          .enqueue('daily', 3, 42);
      final lb2 = LeaderboardService(storage: storage, transport: FakeTransport());
      expect(lb2.queue.single.score, 42);
    });
  });

  group('flush (skor asla kaybolmaz)', () {
    test('oturum yoksa gönderilmez, kuyruk korunur', () async {
      final t = FakeTransport();
      final lb = LeaderboardService(storage: MemoryStorage(), transport: t);
      lb.enqueue('daily', 1, 20);
      expect(await lb.flush(), isFalse);
      expect(lb.queue.length, 1);
      expect(t.calls, isEmpty);
    });

    test('başarılı gönderim kuyruğu boşaltır', () async {
      final t = FakeTransport()..nextPost = const HttpReply(200, '{"ok":true}');
      final lb = LeaderboardService(storage: MemoryStorage(), transport: t)
        ..sessionToken = 'tok';
      lb.enqueue('daily', 1, 20);
      lb.enqueue('endless', -1, 90);
      expect(await lb.flush(), isTrue);
      expect(lb.queue, isEmpty);
      final entries = (t.lastPostBody!['entries'] as List).length;
      expect(entries, 2, reason: 'toplu gönderim');
    });

    test('sunucu hatası → kuyruk AYNEN kalır, sonraki denemede gider', () async {
      final t = FakeTransport()..nextPost = const HttpReply(500, '');
      final storage = MemoryStorage();
      final lb = LeaderboardService(storage: storage, transport: t)
        ..sessionToken = 'tok';
      lb.enqueue('daily', 1, 20);
      expect(await lb.flush(), isFalse);
      expect(lb.queue.length, 1, reason: 'kayıp yok');
      // kalıcılık: yeniden yükleme de kuyruğu görür
      expect(
          LeaderboardService(storage: storage, transport: t).queue.length, 1);

      t.nextPost = const HttpReply(200, '{}');
      expect(await lb.flush(), isTrue);
      expect(lb.queue, isEmpty);
    });

    test('ağ istisnası → kuyruk korunur', () async {
      final t = FakeTransport()..throwOnPost = true;
      final lb = LeaderboardService(storage: MemoryStorage(), transport: t)
        ..sessionToken = 'tok';
      lb.enqueue('daily', 2, 15);
      expect(await lb.flush(), isFalse);
      expect(lb.queue.length, 1);
    });
  });

  group('tahta getirme', () {
    test('hata → null (ekran yerel rakiplere düşer)', () async {
      final t = FakeTransport()..nextGet = const HttpReply(503, '');
      final lb = LeaderboardService(storage: MemoryStorage(), transport: t);
      expect(await lb.fetchBoard('daily', day: 3), isNull);
    });

    test('başarı → satırlar + kendi sırası', () async {
      final t = FakeTransport()
        ..nextGet = HttpReply(
            200,
            jsonEncode({
              'rows': [
                {'name': 'Kaptan', 'score': 90},
                {'name': 'Ben', 'score': 40, 'me': true},
              ],
              'rank': 2,
              'score': 40,
            }));
      final lb = LeaderboardService(storage: MemoryStorage(), transport: t);
      final view = await lb.fetchBoard('daily', day: 3);
      expect(view, isNotNull);
      expect(view!.rows.length, 2);
      expect(view.rows.last.me, isTrue);
      expect(view.myRank, 2);
      expect(view.myScore, 40);
      expect(t.calls.single, contains('board=daily'));
    });
  });

  group('oturum', () {
    test('giriş belirteci secure store a yazılır, oyun kaydına sızmaz', () async {
      final storage = MemoryStorage();
      final secure = MemorySecureStore();
      final t = FakeTransport()
        ..nextPost = const HttpReply(
            200, '{"sessionToken":"secret-token","displayName":"Oyuncu"}');
      final session = SessionService(store: secure, transport: t);
      expect(await session.signIn('google', 'id-token'), isTrue);
      expect(session.token, 'secret-token');
      expect(session.displayName, 'Oyuncu');
      // oyun kaydı (KeyValueStorage) belirteci içermez
      final save = storage.getString(prog.kSaveKey);
      expect(save ?? '', isNot(contains('secret-token')));
    });

    test('hesap silme: sunucu çağrısı + yerel belirteç temizlenir', () async {
      final secure = MemorySecureStore();
      final t = FakeTransport()
        ..nextPost = const HttpReply(200, '{"sessionToken":"tok"}');
      final session = SessionService(store: secure, transport: t);
      await session.signIn('google', 'id');
      expect(session.signedIn, isTrue);
      expect(await session.deleteAccount(), isTrue);
      expect(session.signedIn, isFalse);
      expect(t.calls, contains('DELETE /account'));
    });

    test('sağlayıcı belirteci yoksa giriş yapılmaz', () async {
      final session = SessionService(
          store: MemorySecureStore(), transport: FakeTransport());
      expect(await session.signInWithProvider(const NoopAuthProvider()), isFalse);
      expect(session.signedIn, isFalse);
    });
  });
}
