/// Typed failure hierarchy — domain layer error types.
/// These are never HTTP-aware. Repositories translate exceptions → failures.
library;

import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];

  @override
  String toString() => message;
}

/// Could not reach the server (no internet, timeout, etc.)
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection. Please try again.']);
}

/// Server returned an unexpected error (5xx)
final class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Auth-related failure (wrong credentials, expired token, etc.)
final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Email not verified yet
final class UnverifiedEmailFailure extends Failure {
  const UnverifiedEmailFailure([
    super.message = 'Please verify your email before logging in.',
  ]);
}

/// Resource not found
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'The requested resource was not found.']);
}

/// Validation failure (input data is malformed)
final class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;
  const ValidationFailure(super.message, {this.fieldErrors});

  @override
  List<Object?> get props => [message, fieldErrors];
}

/// Unexpected / unknown failure
final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong. Please try again.']);
}

/// Cache / local storage failure
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Failed to read or write local data.']);
}
