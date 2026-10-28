import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token storage with memory fallback.
class TokenStorage {
  const TokenStorage();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'nexusai_access_token';
  static String? _inMemoryToken;

  Future<void> saveAccessToken(String token) async {
    _inMemoryToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // In-memory fallback if secure storage is restricted on web
    }
  }

  Future<String?> readAccessToken() async {
    if (_inMemoryToken != null && _inMemoryToken!.isNotEmpty) {
      return _inMemoryToken;
    }
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        _inMemoryToken = token;
      }
      return token;
    } catch (_) {
      return _inMemoryToken;
    }
  }

  Future<void> clear() async {
    _inMemoryToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }
}
