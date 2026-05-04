/// Auth state + Riverpod provider.
///
/// [AuthStatus] is the sealed discriminator.
/// [AuthNotifier] exposes actions (login, register, logout, etc.)
/// Screens observe [authStatusProvider] and react to state changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class AuthStatus {
  const AuthStatus();
}

final class AuthInitial extends AuthStatus {
  const AuthInitial();
}

final class AuthAuthenticated extends AuthStatus {
  final User user;
  const AuthAuthenticated(this.user);
}

final class AuthUnauthenticated extends AuthStatus {
  const AuthUnauthenticated();
}

/// Session expired — token refresh failed. Triggers an auto-logout snackbar on login page.
final class AuthSessionExpired extends AuthStatus {
  const AuthSessionExpired();
}

/// Email exists but hasn't been verified yet.
final class AuthEmailUnverified extends AuthStatus {
  final String email;
  const AuthEmailUnverified(this.email);
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AuthStatus> {
  late AuthRepository _repo;
  bool _hasInitialized = false;

  /// True only during the initial session check on app startup.
  bool get isInitializing => !_hasInitialized && state.isLoading;

  @override
  Future<AuthStatus> build() async {
    _repo = ref.watch(_authRepositoryProvider);

    // Check stored session on startup
    final hasSession = await _repo.hasValidSession();
    if (!hasSession) {
      _hasInitialized = true;
      return const AuthUnauthenticated();
    }

    try {
      final user = await _repo.getMe();
      _hasInitialized = true;
      return AuthAuthenticated(user);
    } on AuthFailure {
      await _repo.logout();
      _hasInitialized = true;
      return const AuthUnauthenticated();
    } catch (_) {
      _hasInitialized = true;
      return const AuthUnauthenticated();
    }
  }

  // ── Login ────────────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    // copyWithPrevious keeps the previous AuthUnauthenticated value visible
    // so the router does NOT treat this as "initializing" and redirect to /splash.
    state = const AsyncLoading<AuthStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final user = await _repo.login(email: email, password: password);
      return AuthAuthenticated(user);
    });
  }

  // ── Register ────────────────────────────────────────────────────────────

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required double openingBalance,
  }) async {
    state = const AsyncLoading<AuthStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.register(
        name: name,
        email: email,
        password: password,
        openingBalance: openingBalance,
      );
      return AuthEmailUnverified(email);
    });
  }

  // ── Verify email ─────────────────────────────────────────────────────────

  Future<void> verifyEmail(String token) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.verifyEmail(token);
      // After verification the user still needs to log in
      return const AuthUnauthenticated();
    });
  }

  Future<void> resendVerificationEmail(String email) async {
    await _repo.resendVerificationEmail(email);
  }

  // ── Forgot / reset password ───────────────────────────────────────────────

  Future<void> forgotPassword(String email) async {
    await _repo.forgotPassword(email);
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _repo.resetPassword(token: token, newPassword: newPassword);
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    state = const AsyncLoading();
    await _repo.logout();
    state = const AsyncData(AuthUnauthenticated());
  }

  /// Called by the TokenInterceptor when the refresh token is invalid/expired.
  /// Sets [AuthSessionExpired] so the login page can show an explanatory snackbar.
  Future<void> forceLogout() async {
    await _repo.logout();
    state = const AsyncData(AuthSessionExpired());
  }

  // ── Profile editing ───────────────────────────────────────────────────────

  /// Update name and immediately reflect the change in the authenticated state.
  Future<void> updateName(String name) async {
    final updatedUser = await _repo.updateName(name);
    if (state.valueOrNull is AuthAuthenticated) {
      state = AsyncData(AuthAuthenticated(updatedUser));
    }
  }

  /// Initiate the 2-step email change flow.
  /// Does NOT change state — the user stays logged in and sees a snackbar.
  Future<void> requestEmailChange(String newEmail) async {
    await _repo.requestEmailChange(newEmail);
  }

  /// Change password. Session stays alive.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  User? get currentUser {
    final s = state.valueOrNull;
    return s is AuthAuthenticated ? s.user : null;
  }

  bool get isAuthenticated => state.valueOrNull is AuthAuthenticated;
}

// ─── Providers ───────────────────────────────────────────────────────────────

/// Provides the [AuthRemoteDataSource].
final _authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ApiClient.instance);
});

/// Provides the [AuthRepository] implementation.
final _authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(_authRemoteDataSourceProvider),
    SecureStorage.instance,
  );
});

/// Observable auth status — watch this in the router and screens.
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthStatus>(AuthNotifier.new);

/// Convenience: current authenticated user or null.
final currentUserProvider = Provider<User?>((ref) {
  final status = ref.watch(authNotifierProvider).valueOrNull;
  return status is AuthAuthenticated ? status.user : null;
});
