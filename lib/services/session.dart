/// Stack Tower Game — oturum servisi (PB-011, SPEC §7.2/§7.5).
/// Kimlik = sağlayıcı `sub`; e-posta HİÇBİR yerde saklanmaz/gösterilmez.
/// Belirteç yalnız [SecureStore]'da tutulur, loglara yazılmaz.
library;

import 'dart:convert';

import 'leaderboard_service.dart';
import 'storage.dart';

/// Güvenli saklama soyutlaması. Üretimde platform keychain/keystore
/// (flutter_secure_storage) bağlanır; bu repoda bağımlılıksız varsayılan
/// [PrefsSecureStore] kullanılır ve PB-031'de native katman bağlanacak.
abstract class SecureStore {
  String? read(String key);
  void write(String key, String value);
  void delete(String key);
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
}

class MemorySecureStore implements SecureStore {
  final Map<String, String> _m = {};
  @override
  String? read(String key) => _m[key];
  @override
  void write(String key, String value) => _m[key] = value;
  @override
  void delete(String key) => _m.remove(key);
}

/// Sağlayıcı kimlik belirteci üreticisi (Google/Apple SDK'ları).
/// Native SDK bağlanana kadar [NoopAuthProvider] kullanılır.
abstract class AuthProvider {
  Future<String?> idToken();
}

class NoopAuthProvider implements AuthProvider {
  const NoopAuthProvider();
  @override
  Future<String?> idToken() async => null;
}

class SessionService {
  SessionService({required this.store, required this.transport});

  static const String kTokenKey = 'stacktower_session_v1';
  static const String kNameKey = 'stacktower_display_name_v1';

  final SecureStore store;
  final HttpTransport transport;

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
