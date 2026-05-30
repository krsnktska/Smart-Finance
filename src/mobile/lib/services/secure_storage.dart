import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _keyRefreshToken = 'refreshToken';
  static const _keyExpiry = 'refreshExpiry';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveRefreshToken(String token, DateTime expiry) async {
    try {
      print(
        '🗂️ [Storage] Saving refresh token (expires: ${expiry.toIso8601String()})',
      );
      await _storage.write(key: _keyRefreshToken, value: token);
      await _storage.write(key: _keyExpiry, value: expiry.toIso8601String());
      print('🗂️ [Storage] Token saved successfully');
    } catch (e) {
      print('❌ [Storage] Failed to save token: $e');
      rethrow;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      print('🗂️ [Storage] Reading refresh token from storage');
      final token = await _storage.read(key: _keyRefreshToken);
      final expiryStr = await _storage.read(key: _keyExpiry);

      print('🗂️ [Storage] Token found: ${token != null}');
      print('🗂️ [Storage] Expiry found: ${expiryStr != null}');

      if (token == null || expiryStr == null) {
        print('🗂️ [Storage] Token or expiry is null');
        return null;
      }

      try {
        final expiry = DateTime.parse(expiryStr);
        final now = DateTime.now();
        print('🗂️ [Storage] Token expiry: $expiry, now: $now');

        if (now.isAfter(expiry)) {
          print('🗂️ [Storage] Token expired, clearing storage');
          await clear();
          return null;
        }
        print('🗂️ [Storage] Token is valid');
        return token;
      } catch (e) {
        print('❌ [Storage] Failed to parse expiry: $e');
        await clear();
        return null;
      }
    } catch (e) {
      print('❌ [Storage] Error reading token: $e');
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiry);
  }
}
