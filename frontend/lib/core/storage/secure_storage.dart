/// SecureStorage wrapper — persists JWT tokens and user session data.
/// Uses flutter_secure_storage under the hood (Keychain on iOS, EncryptedSharedPreferences on Android).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error/exceptions.dart';

abstract final class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userName = 'user_name';
  static const String currency = 'currency';
  static const String currencySymbol = 'currency_symbol';
}

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ─── Token operations ─────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: StorageKeys.accessToken, value: accessToken),
        _storage.write(key: StorageKeys.refreshToken, value: refreshToken),
      ]);
    } catch (e) {
      throw const CacheException('Failed to save auth tokens.');
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: StorageKeys.accessToken);
    } catch (e) {
      throw const CacheException('Failed to read access token.');
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: StorageKeys.refreshToken);
    } catch (e) {
      throw const CacheException('Failed to read refresh token.');
    }
  }

  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: StorageKeys.accessToken, value: token);
    } catch (e) {
      throw const CacheException('Failed to save access token.');
    }
  }

  // ─── User session ─────────────────────────────────────────────────────────

  Future<void> saveUserSession({
    required String userId,
    required String email,
    required String name,
    required String currency,
    required String currencySymbol,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: StorageKeys.userId, value: userId),
        _storage.write(key: StorageKeys.userEmail, value: email),
        _storage.write(key: StorageKeys.userName, value: name),
        _storage.write(key: StorageKeys.currency, value: currency),
        _storage.write(key: StorageKeys.currencySymbol, value: currencySymbol),
      ]);
    } catch (e) {
      throw const CacheException('Failed to save user session.');
    }
  }

  Future<String?> getUserId() => _storage.read(key: StorageKeys.userId);
  Future<String?> getUserEmail() => _storage.read(key: StorageKeys.userEmail);
  Future<String?> getUserName() => _storage.read(key: StorageKeys.userName);
  Future<String?> getCurrency() => _storage.read(key: StorageKeys.currency);
  Future<String?> getCurrencySymbol() => _storage.read(key: StorageKeys.currencySymbol);

  Future<bool> hasSession() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── Clear ────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw const CacheException('Failed to clear storage.');
    }
  }

  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: StorageKeys.accessToken),
        _storage.delete(key: StorageKeys.refreshToken),
      ]);
    } catch (e) {
      throw const CacheException('Failed to clear tokens.');
    }
  }
}
