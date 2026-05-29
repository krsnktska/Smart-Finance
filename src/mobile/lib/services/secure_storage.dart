import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _keyRefreshToken = 'refreshToken';
  static const _keyExpiry = 'refreshExpiry';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveRefreshToken(String token, DateTime expiry) async {
    await _storage.write(key: _keyRefreshToken, value: token);
    await _storage.write(key: _keyExpiry, value: expiry.toIso8601String());
  }

  Future<String?> readRefreshToken() async {
    final token = await _storage.read(key: _keyRefreshToken);
    final expiryStr = await _storage.read(key: _keyExpiry);
    if (token == null || expiryStr == null) return null;
    try {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isAfter(expiry)) {
        await clear();
        return null;
      }
      return token;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiry);
  }
}
