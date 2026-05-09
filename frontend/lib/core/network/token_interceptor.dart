/// Token interceptor — attaches JWT on every request, handles 401 by
/// refreshing the access token and retrying the original request once.
/// If refresh fails, logs out the user and clears storage.
library;

import 'package:dio/dio.dart';

import '../error/exceptions.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

class TokenInterceptor extends Interceptor {
  final Dio _dio;
  final SecureStorage _storage;
  /// Called when the refresh token is expired/invalid — triggers forced logout in the app.
  final Future<void> Function()? onSessionExpired;
  // Tracks if a token refresh is already in flight to prevent concurrent refreshes.
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingQueue = [];

  TokenInterceptor(this._dio, this._storage, {this.onSessionExpired});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token injection for requests that explicitly opt out (e.g. refresh
    // call and retried requests that already carry a fresh token in headers).
    if (options.extra['skipInterceptor'] == true) {
      return handler.next(options);
    }

    // Don't inject token for auth endpoints
    if (_isAuthEndpoint(options.path)) {
      return handler.next(options);
    }

    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    if (response?.statusCode != 401 || _isAuthEndpoint(err.requestOptions.path)) {
      return handler.next(err);
    }

    // 401 received — attempt token refresh
    if (_isRefreshing) {
      // Queue the request and wait for the ongoing refresh
      final pending = _PendingRequest(err.requestOptions, handler);
      _pendingQueue.add(pending);
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        throw const UnauthorizedException('No refresh token found.');
      }

      // Call refresh endpoint directly (not via the intercepted Dio)
      final refreshResponse = await _dio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
        options: Options(
          extra: {'skipInterceptor': true},
        ),
      );

      final newAccessToken = refreshResponse.data['accessToken'] as String;
      final newRefreshToken = refreshResponse.data['refreshToken'] as String?;
      await _storage.saveAccessToken(newAccessToken);
      // CRITICAL: save the rotated refresh token — the old one is now revoked on the server.
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.saveRefreshToken(newRefreshToken);
      }

      // Retry the original request
      final retryResponse = await _retry(err.requestOptions, newAccessToken);
      handler.resolve(retryResponse);

      // Drain the queue with the new token
      for (final pending in _pendingQueue) {
        try {
          final r = await _retry(pending.options, newAccessToken);
          pending.handler.resolve(r);
        } catch (e) {
          pending.handler.next(err);
        }
      }
      _pendingQueue.clear();
    } catch (e) {
      // Distinguish between a real auth failure and a transient network error.
      final isNetworkError = e is DioException &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionError);

      if (!isNetworkError) {
        // Genuine auth failure (server explicitly rejected the refresh token).
        // Clear session and notify the app.
        await _storage.clearAll();
        _pendingQueue.clear();
        await onSessionExpired?.call();
        handler.next(err);
      } else {
        // Network error during refresh (e.g. Render cold-start timeout).
        // Keep tokens intact and reject with a network error — NOT the original
        // 401. This causes getMe() to throw NetworkFailure, so auth_provider
        // restores the user from cache rather than wiping the session.
        _pendingQueue.clear();
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            type: DioExceptionType.connectionError,
            error: 'Network error during token refresh — session preserved.',
          ),
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options, String token) {
    return _dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: Options(
        method: options.method,
        // Bypass the interceptor so our fresh token is never overwritten by
        // a storage read in onRequest.
        extra: {...options.extra, 'skipInterceptor': true},
        headers: {...options.headers, 'Authorization': 'Bearer $token'},
      ),
    );
  }

  bool _isAuthEndpoint(String path) {
    const authPaths = [
      '/auth/login',
      '/auth/register',
      '/auth/refresh',
      '/auth/forgot-password',
      '/auth/reset-password',
      '/auth/verify-email',
      '/auth/resend-verification',
    ];
    return authPaths.any((p) => path.contains(p));
  }
}

class _PendingRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _PendingRequest(this.options, this.handler);
}
