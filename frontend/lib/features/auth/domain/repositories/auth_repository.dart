/// Abstract AuthRepository — defines the contract for the auth data layer.
/// Implementations live in the data layer.
library;

import '../entities/user.dart';

abstract interface class AuthRepository {
  /// Register a new user. Sends Brevo verification email.
  /// Throws [AppException] subtypes on failure.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required double openingBalance,
  });

  /// Verify email using the token from the email link.
  Future<void> verifyEmail(String token);

  /// Resend verification email.
  Future<void> resendVerificationEmail(String email);

  /// Login with email + password. Returns authenticated [User].
  Future<User> login({
    required String email,
    required String password,
  });

  /// Refresh access token using the stored refresh token.
  Future<String> refreshToken(String refreshToken);

  /// Logout — invalidates refresh token on server + clears local storage.
  Future<void> logout();

  /// Send forgot-password email via Brevo.
  Future<void> forgotPassword(String email);

  /// Reset password using token from email link.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  /// Fetch the currently authenticated user profile.
  Future<User> getMe();

  /// Update the user's display name.
  Future<User> updateName(String name);

  /// Start email change — sends confirmation link to current email.
  Future<void> requestEmailChange(String newEmail);

  /// Change password (session stays alive).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Returns true if an access token exists in local storage.
  Future<bool> hasValidSession();
}
