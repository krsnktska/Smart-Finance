import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _keyRefreshToken = 'refreshToken';
  static const _keyExpiry = 'refreshExpiry';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveRefreshToken(String token, DateTime expiry) async {
    try {
      if (kDebugMode) {
        print(
          '🗂️ [Storage] Saving refresh token (expires: ${expiry.toIso8601String()})',
        );
      }
      await _storage.write(key: _keyRefreshToken, value: token);
      await _storage.write(key: _keyExpiry, value: expiry.toIso8601String());
      if (kDebugMode) {
        print('🗂️ [Storage] Token saved successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [Storage] Failed to save token: $e');
      }
      rethrow;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      if (kDebugMode) {
        print('🗂️ [Storage] Reading refresh token from storage');
      }
      final token = await _storage.read(key: _keyRefreshToken);
      final expiryStr = await _storage.read(key: _keyExpiry);

      if (kDebugMode) {
        print('🗂️ [Storage] Token found: ${token != null}');
      }
      if (kDebugMode) {
        print('🗂️ [Storage] Expiry found: ${expiryStr != null}');
      }

      if (token == null || expiryStr == null) {
        if (kDebugMode) {
          print('🗂️ [Storage] Token or expiry is null');
        }
        return null;
      }

      try {
        final expiry = DateTime.parse(expiryStr);
        final now = DateTime.now();
        if (kDebugMode) {
          print('🗂️ [Storage] Token expiry: $expiry, now: $now');
        }

        if (now.isAfter(expiry)) {
          if (kDebugMode) {
            print('🗂️ [Storage] Token expired, clearing storage');
          }
          await clear();
          return null;
        }
        if (kDebugMode) {
          print('🗂️ [Storage] Token is valid');
        }
        return token;
      } catch (e) {
        if (kDebugMode) {
          print('❌ [Storage] Failed to parse expiry: $e');
        }
        await clear();
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [Storage] Error reading token: $e');
      }
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiry);
  }
}
