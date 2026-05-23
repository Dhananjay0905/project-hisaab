/// Typed exception hierarchy — data layer / network layer.
/// Caught by repositories and converted to [Failure] types for the domain.
library;

sealed class AppException implements Exception {
  final String message;
  final int? statusCode;
  const AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Network / connectivity issue
final class NetworkException extends AppException {
  const NetworkException([
    super.message = 'No internet connection.',
  ]);
}

/// Backend returned a 5xx
final class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

/// Backend returned 401 / 403
final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Session expired. Please log in again.'])
      : super(statusCode: 401);
}

/// Backend returned 404
final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Resource not found.'])
      : super(statusCode: 404);
}

/// Backend returned 422 / validation
final class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;
  const ValidationException(super.message, {this.fieldErrors, super.statusCode = 422});
}

/// Email not verified (custom backend status)
final class UnverifiedEmailException extends AppException {
  const UnverifiedEmailException()
      : super('Please verify your email before logging in.', statusCode: 403);
}

/// Local storage failure
final class CacheException extends AppException {
  const CacheException([super.message = 'Local storage error.']);
}

/// Any other unexpected exception
final class UnknownException extends AppException {
  const UnknownException([super.message = 'An unexpected error occurred.']);
}
