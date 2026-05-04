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
      await _storage.saveAccessToken(newAccessToken);

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
    } catch (_) {
      // Refresh failed — clear session and notify the app
      await _storage.clearAll();
      _pendingQueue.clear();
      // Notify the app so it can redirect to login with an explanatory message
      await onSessionExpired?.call();
      handler.next(err);
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
