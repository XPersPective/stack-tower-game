/// Stack Tower Game — oturum servisi (PB-011 + PB-031, SPEC §7.2/§7.5).
/// Kimlik = sağlayıcı `sub`; e-posta HİÇBİR yerde saklanmaz/gösterilmez.
/// Belirteç yalnız [SecureStore]'da (native: keychain/keystore) tutulur,
/// loglara yazılmaz.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'leaderboard_service.dart';
import 'storage.dart';

/// Güvenli saklama soyutlaması.
/// - Varsayılan/Web: [PrefsSecureStore] (SharedPreferences).
/// - Test: [MemorySecureStore].
/// - Üretim (native): [FlutterSecureStore] → keychain (iOS) / keystore (Android).
///
/// [hydrate] async başlangıç yüküdür; senkron [read] bellek yansımasından okur,
/// böylece oturum durumu UI'da senkron erişilebilir kalır (C-013 anında yazım).
abstract class SecureStore {
  String? read(String key);
  void write(String key, String value);
  void delete(String key);

  /// Async: dayanıklı depoyu belleğe yükle. Varsayılan no-op.
  Future<void> hydrate() async {}
}

class PrefsSecureStore implements SecureStore {
  PrefsSecureStore(this.storage);
  final KeyValueStorage storage;
  @override
  String? read(String key) => storage.getString(key);
  @override
  void write(String key, String value) => storage.setString(key, value);
  @override
  void delete(String key) => storage.setString(key, '');
  @override
  Future<void> hydrate() async {}
}

class MemorySecureStore implements SecureStore {
  MemorySecureStore([this._initial]);
  final Map<String, String>? _initial;
  final Map<String, String> _m = {};
  @override
  String? read(String key) => _m[key] ?? _initial?[key];
  @override
  void write(String key, String value) => _m[key] = value;
  @override
  void delete(String key) => _m.remove(key);
  @override
  Future<void> hydrate() async {}
}

/// Üretim güvenli deposu: flutter_secure_storage (keychain/keystore).
/// Yazma = eşzamanlı bellek yansıması + arka planda kalıcı yazım.
class FlutterSecureStore implements SecureStore {
  FlutterSecureStore([FlutterSecureStorage? box]) : _box = box ?? const FlutterSecureStorage();

  final FlutterSecureStorage _box;
  final Map<String, String> _cache = {};

  @override
  Future<void> hydrate() async {
    try {
      final all = await _box.readAll();
      _cache.clear();
      _cache.addAll(all);
    } catch (_) {
      // İlk çalıştırma / erişim reddi → boş oturum.
    }
  }

  @override
  String? read(String key) => _cache[key];

  @override
  void write(String key, String value) {
    _cache[key] = value;
    unawaited(_box.write(key: key, value: value));
  }

  @override
  void delete(String key) {
    _cache.remove(key);
    unawaited(_box.delete(key: key));
  }
}

/// Sağlayıcı kimlik belirteci üreticisi (Google/Apple SDK'ları).
abstract class AuthProvider {
  /// idToken döner; kullanıcı iptal ederse/erişilemezse null.
  Future<String?> idToken();
}

/// Hiçbir native bağlama olmadan (yalnız yerel / test).
class NoopAuthProvider implements AuthProvider {
  const NoopAuthProvider();
  @override
  Future<String?> idToken() async => null;
}

/// Google Sign-In → idToken (RS256, workers JWKS ile doğrulanır).
/// google_sign_in v7: singleton + tek seferlik [initialize] + [authenticate].
class GoogleAuthProvider implements AuthProvider {
  const GoogleAuthProvider({this.serverClientId});

  /// iOS/Android yapılandırmasında kullanılan web client id (sunucu akışı).
  /// Boş bırakılırsa platform varsayılan OAuth yapılandırması kullanılır.
  final String? serverClientId;

  static bool _initialized = false;

  @override
  Future<String?> idToken() async {
    try {
      final google = GoogleSignIn.instance;
      if (!_initialized) {
        await google.initialize(serverClientId: serverClientId);
        _initialized = true;
      }
      final account = await google.authenticate();
      return account.authentication.idToken;
    } catch (_) {
      return null;
    }
  }
}

/// Sign in with Apple → identityToken.
/// iOS 13+ gerektirir; diğer platformlarda try/catch ile null döner.
class AppleAuthProvider implements AuthProvider {
  const AppleAuthProvider();

  @override
  Future<String?> idToken() async {
    try {
      // Kapsam istenmez (C-014 veri minimizasyonu): isim/e-posta kullanılmıyor;
      // Apple'ın paylaşım istemi çıkmaz, yalnız kimlik doğrulama olur.
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [],
      );
      return credential.identityToken;
    } catch (_) {
      return null;
    }
  }
}

class SessionService {
  SessionService({required this.store, required this.transport});

  static const String kTokenKey = 'stacktower_session_v1';
  static const String kNameKey = 'stacktower_display_name_v1';

  final SecureStore store;
  final HttpTransport transport;

  /// runApp öncesi: kalıcı oturumu belleğe yükle (C-013 anında erişim).
  Future<void> init() => store.hydrate();

  String? get token => store.read(kTokenKey);
  bool get signedIn => (token ?? '').isNotEmpty;
  String? get displayName => store.read(kNameKey);

  /// Google/Apple kimlik belirtecini oturuma çevirir.
  Future<bool> signIn(String provider, String idToken) async {
    final path = provider == 'apple' ? '/auth/apple' : '/auth/google';
    final res = await transport.post(path, {'idToken': idToken});
    if (!res.ok) return false;
    final j = res.json;
    final sessionToken = j?['sessionToken'] as String?;
    if (sessionToken == null || sessionToken.isEmpty) return false;
    store.write(kTokenKey, sessionToken);
    final name = j?['displayName'] as String?;
    if (name != null && name.isNotEmpty) store.write(kNameKey, name);
    return true;
  }

  Future<bool> signInWithProvider(AuthProvider provider, {String kind = 'google'}) async {
    final idToken = await provider.idToken();
    if (idToken == null || idToken.isEmpty) return false;
    return signIn(kind, idToken);
  }

  /// /me: sunucudaki kimlik özeti (e-posta yok).
  Future<Map<String, dynamic>?> me() async {
    final t = token;
    if (t == null) return null;
    final res = await transport.get('/me', token: t);
    if (!res.ok) return null;
    return res.json;
  }

  /// Hesap silme: sunucu kaydı + yerel belirteç temizlenir (SPEC §7.6).
  Future<bool> deleteAccount() async {
    final t = token;
    if (t == null) return false;
    final res = await transport.delete('/account', token: t);
    if (!res.ok) return false;
    signOutLocal();
    return true;
  }

  void signOutLocal() {
    store.delete(kTokenKey);
    store.delete(kNameKey);
  }
}

/// Kuyruk gönderiminde kullanılacak belirteci oturumdan okur.
String? tokenOf(SessionService s) => s.token;

/// Test yardımcısı: JSON gövdeyi okurken hata yutulur.
Map<String, dynamic>? decodeMap(String body) {
  try {
    final v = jsonDecode(body);
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}
