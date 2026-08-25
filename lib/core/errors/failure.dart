import 'app_exception.dart';

/// Lightweight sealed-style failure type. Notifiers catch AppException
/// and store a Failure in state so widgets can render Loading / Success /
/// Empty / Error consistently across every feature.
class Failure {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  factory Failure.fromException(Object error) {
    if (error is AppException) {
      return Failure(error.message, code: error.code);
    }
    return Failure(error.toString());
  }

  @override
  String toString() => message;
}
