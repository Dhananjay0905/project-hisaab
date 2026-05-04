/// AuthRemoteDataSource — all raw HTTP calls for auth.
/// Throws [AppException] subtypes on failure.
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);
  final ApiClient _client;

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required double openingBalance,
  }) async {
    await _client.post(ApiEndpoints.register, data: {
      'name': name,
      'email': email,
      'password': password,
      'currency': 'INR',
      'currencySymbol': '₹',
      'openingBalance': openingBalance,
    });
  }

  Future<void> verifyEmail(String token) async {
    await _client.post(ApiEndpoints.verifyEmail, data: {'token': token});
  }

  Future<void> resendVerificationEmail(String email) async {
    await _client.post(ApiEndpoints.resendVerification, data: {'email': email});
  }

  /// Returns [UserModel] and token map: { user, accessToken, refreshToken }
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    final payload = response.data!['data'] as Map<String, dynamic>;
    return {
      'user': UserModel.fromJson(payload['user'] as Map<String, dynamic>),
      'accessToken': payload['accessToken'] as String,
      'refreshToken': payload['refreshToken'] as String,
    };
  }

  Future<String> refreshToken(String refreshToken) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.refresh,
      data: {'refreshToken': refreshToken},
    );
    final payload = response.data!['data'] as Map<String, dynamic>;
    return payload['accessToken'] as String;
  }

  Future<void> logout(String refreshToken) async {
    await _client.post(ApiEndpoints.logout, data: {'refreshToken': refreshToken});
  }

  Future<void> forgotPassword(String email) async {
    await _client.post(ApiEndpoints.forgotPassword, data: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _client.post(ApiEndpoints.resetPassword, data: {
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<UserModel> getMe() async {
    final response = await _client.get<Map<String, dynamic>>(ApiEndpoints.me);
    final payload = response.data!['data'] as Map<String, dynamic>;
    return UserModel.fromJson(payload);
  }

  Future<UserModel> updateName(String name) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.updateProfile,
      data: {'name': name},
    );
    final payload = response.data!['data'] as Map<String, dynamic>;
    return UserModel.fromJson(payload);
  }

  Future<void> requestEmailChange(String newEmail) async {
    await _client.post(ApiEndpoints.requestEmailChange, data: {'newEmail': newEmail});
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(ApiEndpoints.changePassword, data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
