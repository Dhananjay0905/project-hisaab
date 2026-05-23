/// AuthRepositoryImpl — bridges the data layer with the domain contract.
/// Translates [AppException] → [Failure] and manages token persistence.
library;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final SecureStorage _storage;

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required double openingBalance,
    required bool policyAccepted,
  }) async {
    try {
      await _remote.register(
        name: name,
        email: email,
        password: password,
        openingBalance: openingBalance,
        policyAccepted: policyAccepted,
      );
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message, fieldErrors: e.fieldErrors);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> verifyEmail(String token) async {
    try {
      await _remote.verifyEmail(token);
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _remote.resendVerificationEmail(email);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<({User user, bool accountRecovered})> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remote.login(email: email, password: password);
      final user = result['user'] as User;
      final accessToken = result['accessToken'] as String;
      final refreshToken = result['refreshToken'] as String;
      final accountRecovered = result['accountRecovered'] as bool? ?? false;

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _storage.saveUserSession(
        userId: user.id,
        email: user.email,
        name: user.name,
        currency: user.currency,
        currencySymbol: user.currencySymbol,
      );

      return (user: user, accountRecovered: accountRecovered);
    } on UnauthorizedException catch (e) {
      throw AuthFailure(e.message);
    } on UnverifiedEmailException {
      throw const UnverifiedEmailFailure();
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<String> refreshToken(String refreshToken) async {
    try {
      return await _remote.refreshToken(refreshToken);
    } on AppException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> logout() async {
    try {
      final token = await _storage.getRefreshToken();
      if (token != null) await _remote.logout(token);
    } catch (_) {
      // Best effort logout — always clear local storage
    } finally {
      await _storage.clearAll();
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _remote.forgotPassword(email);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _remote.resetPassword(token: token, newPassword: newPassword);
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<User> getMe() async {
    try {
      return await _remote.getMe();
    } on UnauthorizedException catch (e) {
      throw AuthFailure(e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<User> updateName(String name) async {
    try {
      return await _remote.updateName(name);
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> requestEmailChange(String newEmail) async {
    try {
      await _remote.requestEmailChange(newEmail);
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<DateTime> deleteAccount(String password) async {
    try {
      return await _remote.deleteAccount(password);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<bool> hasValidSession() => _storage.hasSession();

  @override
  Future<User?> getCachedUser() async {
    try {
      final userId = await _storage.getUserId();
      final email = await _storage.getUserEmail();
      final name = await _storage.getUserName();
      final currency = await _storage.getCurrency();
      final currencySymbol = await _storage.getCurrencySymbol();
      if (userId == null || email == null || name == null) return null;
      return User(
        id: userId,
        email: email,
        name: name,
        isVerified: true, // cached users are always verified
        currency: currency ?? 'INR',
        currencySymbol: currencySymbol ?? '₹',
        openingBalance: 0,
        createdAt: DateTime.now(),
        // policyAcceptedAt unknown from cache — getMe() will fetch the real value
        policyAcceptedAt: null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> acceptPolicy() async {
    try {
      await _remote.acceptPolicy();
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
