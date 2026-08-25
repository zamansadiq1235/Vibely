/// Thrown by data sources/repositories when an operation fails.
/// Presentation-layer code catches this (never raw PostgrestException /
/// AuthException) and maps it to a user-friendly message.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  factory AppException.network() => const AppException(
    'No internet connection. Please try again.',
    code: 'network',
  );

  factory AppException.timeout() => const AppException(
    'The request timed out. Please try again.',
    code: 'timeout',
  );

  factory AppException.unauthorized() => const AppException(
    'Your session has expired. Please log in again.',
    code: 'unauthorized',
  );

  factory AppException.unknown([String? detail]) => AppException(
    detail ?? 'Something went wrong. Please try again.',
    code: 'unknown',
  );

  @override
  String toString() => message;
}
