/// SecureStorage wrapper — persists JWT tokens and user session data.
///
/// Uses TWO storage backends:
///   • flutter_secure_storage (EncryptedSharedPreferences on Android, Keychain
///     on iOS) for secrets like JWTs.
///   • SharedPreferences for non-secret session metadata (user id, name, email,
///     a logged-in flag). SharedPreferences is rock-solid across app kills; the
///     Android Keystore behind EncryptedSharedPreferences can transiently fail
///     after the process is swiped from recents on some devices.
///
/// The `hasSession()` check uses SharedPreferences so we never falsely think
/// the user is logged out just because the Keystore was temporarily unavailable.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// SharedPreferences keys (prefixed to avoid collisions).
abstract final class _PrefKeys {
  static const String isLoggedIn = 'hisaab_is_logged_in';
  static const String userId = 'hisaab_user_id';
  static const String userEmail = 'hisaab_user_email';
  static const String userName = 'hisaab_user_name';
  static const String currency = 'hisaab_currency';
  static const String currencySymbol = 'hisaab_currency_symbol';
}

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _secure = FlutterSecureStorage(
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
        _secure.write(key: StorageKeys.accessToken, value: accessToken),
        _secure.write(key: StorageKeys.refreshToken, value: refreshToken),
      ]);
    } catch (e) {
      throw const CacheException('Failed to save auth tokens.');
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _secure.read(key: StorageKeys.accessToken);
    } catch (e) {
      // Keystore transiently unavailable — return null rather than crash.
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _secure.read(key: StorageKeys.refreshToken);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveAccessToken(String token) async {
    try {
      await _secure.write(key: StorageKeys.accessToken, value: token);
    } catch (e) {
      throw const CacheException('Failed to save access token.');
    }
  }

  Future<void> saveRefreshToken(String token) async {
    try {
      await _secure.write(key: StorageKeys.refreshToken, value: token);
    } catch (e) {
      throw const CacheException('Failed to save refresh token.');
    }
  }

  // ─── User session (dual-write: secure storage + SharedPreferences) ────────

  Future<void> saveUserSession({
    required String userId,
    required String email,
    required String name,
    required String currency,
    required String currencySymbol,
  }) async {
    // Write to SharedPreferences FIRST (reliable, fast, survives app kills).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_PrefKeys.isLoggedIn, true);
    await prefs.setString(_PrefKeys.userId, userId);
    await prefs.setString(_PrefKeys.userEmail, email);
    await prefs.setString(_PrefKeys.userName, name);
    await prefs.setString(_PrefKeys.currency, currency);
    await prefs.setString(_PrefKeys.currencySymbol, currencySymbol);

    // Also write to secure storage (best-effort; tokens are more important).
    try {
      await Future.wait([
        _secure.write(key: StorageKeys.userId, value: userId),
        _secure.write(key: StorageKeys.userEmail, value: email),
        _secure.write(key: StorageKeys.userName, value: name),
        _secure.write(key: StorageKeys.currency, value: currency),
        _secure.write(key: StorageKeys.currencySymbol, value: currencySymbol),
      ]);
    } catch (_) {
      // Non-fatal: SharedPreferences already has the data.
    }
  }

  Future<String?> getUserId() => _readWithFallback(StorageKeys.userId, _PrefKeys.userId);
  Future<String?> getUserEmail() => _readWithFallback(StorageKeys.userEmail, _PrefKeys.userEmail);
  Future<String?> getUserName() => _readWithFallback(StorageKeys.userName, _PrefKeys.userName);
  Future<String?> getCurrency() => _readWithFallback(StorageKeys.currency, _PrefKeys.currency);
  Future<String?> getCurrencySymbol() => _readWithFallback(StorageKeys.currencySymbol, _PrefKeys.currencySymbol);

  /// Try secure storage first; on any failure, fall back to SharedPreferences.
  Future<String?> _readWithFallback(String secureKey, String prefKey) async {
    try {
      final value = await _secure.read(key: secureKey);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // Keystore unavailable — fall through.
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefKey);
  }

  // ─── Session check (SharedPreferences — always reliable) ──────────────────

  Future<bool> hasSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_PrefKeys.isLoggedIn) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ─── Clear ────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    // Clear SharedPreferences first.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_PrefKeys.isLoggedIn);
      await prefs.remove(_PrefKeys.userId);
      await prefs.remove(_PrefKeys.userEmail);
      await prefs.remove(_PrefKeys.userName);
      await prefs.remove(_PrefKeys.currency);
      await prefs.remove(_PrefKeys.currencySymbol);
    } catch (_) {}

    // Clear secure storage.
    try {
      await _secure.deleteAll();
    } catch (e) {
      throw const CacheException('Failed to clear storage.');
    }
  }

  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _secure.delete(key: StorageKeys.accessToken),
        _secure.delete(key: StorageKeys.refreshToken),
      ]);
    } catch (e) {
      throw const CacheException('Failed to clear tokens.');
    }
  }
}
