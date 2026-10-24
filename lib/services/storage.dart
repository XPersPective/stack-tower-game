/// Depolama soyutlaması — progress.js'in tarayıcı localStorage soyutlamasının
/// Flutter karşılığı. Üretimde SharedPreferences, testte MemoryStorage.
library;

import 'package:shared_preferences/shared_preferences.dart';

abstract class KeyValueStorage {
  String? getString(String key);
  Future<void> setString(String key, String value);
}

class SharedPreferencesStorage implements KeyValueStorage {
  SharedPreferencesStorage(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
}

/// Test amaçlı bellek içi depo.
class MemoryStorage implements KeyValueStorage {
  final Map<String, String> _m = {};

  @override
  String? getString(String key) => _m[key];

  @override
  Future<void> setString(String key, String value) async {
    _m[key] = value;
  }

  void seed(String key, String value) => _m[key] = value;
}
