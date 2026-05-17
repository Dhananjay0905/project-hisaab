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
  /// True when the user logged in during a scheduled-deletion grace period,
  /// cancelling the deletion. The home screen shows a recovery banner.
  final bool accountRecovered;
  const AuthAuthenticated(this.user, {this.accountRecovered = false});
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

/// Account deletion has been scheduled (5-day grace period starts).
final class AuthAccountDeletionScheduled extends AuthStatus {
  final DateTime scheduledDeleteAt;
  const AuthAccountDeletionScheduled(this.scheduledDeleteAt);
}

/// Logged in but hasn't accepted the Privacy Policy & ToS yet.
/// Router redirects to /accept-policy. Cannot be dismissed.
final class AuthPolicyPending extends AuthStatus {
  final User user;
  const AuthPolicyPending(this.user);
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

    // Check stored session on startup — use refresh token as the
    // persistence signal (access token expires in 15m; refresh in 30d).
    final hasSession = await _repo.hasValidSession();
    if (!hasSession) {
      _hasInitialized = true;
      return const AuthUnauthenticated();
    }

    try {
      final user = await _repo.getMe();
      _hasInitialized = true;
      // If user hasn't accepted PP/ToS yet, hold them at the policy gate
      if (user.policyAcceptedAt == null) return AuthPolicyPending(user);
      return AuthAuthenticated(user);
    } on AuthFailure {
      // Server explicitly rejected the refresh token → real logout.
      await _repo.logout();
      _hasInitialized = true;
      return const AuthUnauthenticated();
    } catch (_) {
      // ANY other error (network timeout, server error, parsing, etc.)
      // → do NOT log out. Restore from cached session data.
      _hasInitialized = true;
      final cached = await _repo.getCachedUser();
      // Cached user has no policyAcceptedAt — assume pending until getMe() succeeds
      if (cached != null) return AuthPolicyPending(cached);
      return const AuthUnauthenticated();
    }

  }

  // ── Login ────────────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    // copyWithPrevious keeps the previous AuthUnauthenticated value visible
    // so the router does NOT treat this as "initializing" and redirect to /splash.
    state = const AsyncLoading<AuthStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final result = await _repo.login(email: email, password: password);
      final user = result.user;
      // Gate on policy acceptance before granting full access
      if (user.policyAcceptedAt == null) return AuthPolicyPending(user);
      return AuthAuthenticated(user, accountRecovered: result.accountRecovered);
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
        policyAccepted: true, // Checkbox is required to submit the form
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
    await _repo.logout();
    state = const AsyncData(AuthUnauthenticated());
  }

  /// Snap state to Unauthenticated synchronously.
  /// Used by the verify-email page's "Back to sign in" button so the
  /// router stops redirecting back to /verify-email.
  void goToLogin() {
    state = const AsyncData(AuthUnauthenticated());
  }

  /// Called by the TokenInterceptor when the refresh token is invalid/expired.
  /// Sets [AuthSessionExpired] so the login page can show an explanatory snackbar.
  Future<void> forceLogout() async {
    await _repo.logout();
    state = const AsyncData(AuthSessionExpired());
  }

  // ── Policy acceptance ───────────────────────────────────────────────

  /// Called when the user taps "I Accept" on the policy acceptance page.
  /// Sends the acceptance to the server, then transitions to [AuthAuthenticated].
  Future<void> acceptPolicy() async {
    final currentState = state.valueOrNull;
    if (currentState is! AuthPolicyPending) return;
    state = const AsyncLoading<AuthStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.acceptPolicy();
      return AuthAuthenticated(currentState.user);
    });
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

  /// Schedule account deletion. Clears auth state and routes to deletion screen.
  Future<void> scheduleAccountDeletion(String password) async {
    final scheduledDeleteAt = await _repo.deleteAccount(password);
    // Clear local session — tokens are already revoked server-side
    await _repo.logout();
    state = AsyncData(AuthAccountDeletionScheduled(scheduledDeleteAt));
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
