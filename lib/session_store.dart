import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'session_token';
  static const _userKey = 'session_user';
  static const _backgroundedAtKey = 'session_backgrounded_at';

  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));
    await _storage.delete(key: _backgroundedAtKey);
  }

  static Future<({String token, Map<String, dynamic> user})?>
  readSession() async {
    final token = await _storage.read(key: _tokenKey);
    final userJson = await _storage.read(key: _userKey);
    if (token == null || token.isEmpty || userJson == null) return null;
    final decoded = jsonDecode(userJson);
    if (decoded is! Map<String, dynamic>) return null;
    return (token: token, user: decoded);
  }

  static Future<void> markBackgrounded(DateTime time) => _storage.write(
    key: _backgroundedAtKey,
    value: time.toUtc().toIso8601String(),
  );

  static Future<DateTime?> readBackgroundedAt() async {
    final value = await _storage.read(key: _backgroundedAtKey);
    if (value == null) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  static Future<void> clearBackgroundedAt() =>
      _storage.delete(key: _backgroundedAtKey);

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _backgroundedAtKey);
  }
}
