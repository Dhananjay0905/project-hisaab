/// Configured Dio HTTP client with base URL, timeouts, and interceptors.
library;

import 'package:dio/dio.dart';

import '../error/exceptions.dart';
import '../storage/secure_storage.dart';
import 'token_interceptor.dart';

import 'package:flutter/foundation.dart';

String get _fallbackUrl {
  if (kReleaseMode) {
    // Production Render URL
    return 'https://project-hisaab-api.onrender.com/api';
  }

  if (kIsWeb) {
    return 'http://localhost:3000/api';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    // 192.168.29.191 is your PC's local network IP
    // This allows physical phones on the same Wi-Fi to reach your backend!
    return 'http://192.168.29.191:3000/api';
  }

  return 'http://localhost:3000/api'; // iOS and Desktop
}

final String _baseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
).isNotEmpty ? const String.fromEnvironment('API_BASE_URL') : _fallbackUrl;

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Dio? _dio;

  void init({Future<void> Function()? onSessionExpired}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      TokenInterceptor(dio, SecureStorage.instance,
          onSessionExpired: onSessionExpired),
      _LoggingInterceptor(),
    ]);

    _dio = dio;
  }

  Dio get dio => _dio!;

  // ─── Convenience methods ──────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio!.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio!.post<T>(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio!.put<T>(path, data: data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio!.patch<T>(path, data: data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) async {
    try {
      return await _dio!.delete<T>(path, data: data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ─── Error mapping ─────────────────────────────────────────────────────────

  AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkException('Connection timed out. Please try again.');
      case DioExceptionType.receiveTimeout:
        return const NetworkException('Server took too long to respond. Please try again.');
      case DioExceptionType.sendTimeout:
        return const NetworkException('Request timed out. Please try again.');
      case DioExceptionType.connectionError:
        return const NetworkException('Could not reach the server. Check your internet connection.');

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final data = e.response?.data;
        final message = _extractMessage(data) ?? 'Something went wrong. Please try again.';

        if (statusCode == 401) return UnauthorizedException(message);
        if (statusCode == 403) {
          final isUnverified = data is Map && data['code'] == 'EMAIL_UNVERIFIED';
          if (isUnverified) return const UnverifiedEmailException();
          return UnauthorizedException(message);
        }
        if (statusCode == 404) return NotFoundException(message);
        if (statusCode == 422 || statusCode == 400) {
          final fieldErrors = _extractFieldErrors(data);
          return ValidationException(message, fieldErrors: fieldErrors);
        }
        if (statusCode >= 500) {
          return ServerException(
            'Something went wrong on our end. Please try again.',
            statusCode: statusCode,
          );
        }
        return ServerException(message, statusCode: statusCode);

      default:
        return const UnknownException();
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      // Backend envelope: { success: false, error: { code, message } }
      final errorObj = data['error'];
      if (errorObj is Map<String, dynamic>) {
        return errorObj['message']?.toString();
      }
      // Fallback for flat responses: { message: '...' }
      return data['message']?.toString();
    }
    return null;
  }

  Map<String, String>? _extractFieldErrors(dynamic data) {
    if (data is Map<String, dynamic>) {
      // Backend envelope: { error: { details: { errors: {...} } } }
      final errorObj = data['error'];
      if (errorObj is Map<String, dynamic>) {
        final details = errorObj['details'];
        if (details is Map<String, dynamic> && details['errors'] is Map) {
          return Map<String, String>.from(
            (details['errors'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        }
      }
      // Fallback for flat responses
      if (data['errors'] is Map) {
        return Map<String, String>.from(
          (data['errors'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }
    }
    return null;
  }
}

/// Simple request / response logger (only active in debug mode).
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('[API] ${options.method} ${options.uri}');
      return true;
    }());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('[API] ${response.statusCode} ${response.requestOptions.uri}');
      return true;
    }());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('[API] ERROR ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
      return true;
    }());
    handler.next(err);
  }
}
