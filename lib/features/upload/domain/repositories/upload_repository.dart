import '../entities/upload_draft.dart';

abstract class UploadRepository {
  /// Uploads video + optional thumbnail, inserts the `videos` row (and
  /// linked hashtags), and reports progress via [onProgress] (0.0-1.0).
  /// Returns the new video's id. Throws AppException on failure;
  /// callers should surface a retry action rather than silently losing
  /// the draft.
  Future<String> publish({
    required UploadDraft draft,
    required void Function(double progress) onProgress,
  });

  /// Aborts an in-flight publish() call, if any.
  void cancel();
}
