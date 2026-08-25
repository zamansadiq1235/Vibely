import 'dart:io';

enum VideoPrivacy { public, friends, private }

extension VideoPrivacyX on VideoPrivacy {
  String get dbValue => switch (this) {
    VideoPrivacy.public => 'public',
    VideoPrivacy.friends => 'friends',
    VideoPrivacy.private => 'private',
  };

  String get label => switch (this) {
    VideoPrivacy.public => 'Public',
    VideoPrivacy.friends => 'Friends',
    VideoPrivacy.private => 'Private',
  };
}

/// Everything collected across the Create -> Preview -> Thumbnail ->
/// Caption -> Privacy steps (spec §17), held in one place so each step
/// screen just reads/writes fields on this rather than passing a dozen
/// separate arguments around.
class UploadDraft {
  UploadDraft({
    this.videoFile,
    this.thumbnailFile,
    this.caption = '',
    this.privacy = VideoPrivacy.public,
    this.trimStart = Duration.zero,
    this.trimEnd,
  });

  final File? videoFile;
  final File? thumbnailFile;
  final String caption;
  final VideoPrivacy privacy;

  /// Trim points are stored as metadata describing which portion of the
  /// source file to publish. Actually re-encoding the file to those
  /// bounds requires a video-processing package or server-side job that
  /// isn't in this phase's dependency list (see README note in this
  /// phase) — for now the full file uploads and trimStart/trimEnd are
  /// kept on the draft so a Phase 13 CDN/transcoding step has them ready
  /// to act on.
  final Duration trimStart;
  final Duration? trimEnd;

  /// Hashtags parsed live from [caption] rather than a separate field —
  /// matches how TikTok/Reels-style composers work (spec §17, §19).
  List<String> get hashtags {
    final matches = RegExp(r'#(\w+)').allMatches(caption);
    return matches.map((m) => m.group(1)!.toLowerCase()).toSet().toList();
  }

  UploadDraft copyWith({
    File? videoFile,
    File? thumbnailFile,
    bool clearThumbnail = false,
    String? caption,
    VideoPrivacy? privacy,
    Duration? trimStart,
    Duration? trimEnd,
  }) {
    return UploadDraft(
      videoFile: videoFile ?? this.videoFile,
      thumbnailFile: clearThumbnail
          ? null
          : (thumbnailFile ?? this.thumbnailFile),
      caption: caption ?? this.caption,
      privacy: privacy ?? this.privacy,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
    );
  }
}
