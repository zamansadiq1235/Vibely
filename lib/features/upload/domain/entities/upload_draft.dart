import 'dart:io';

import 'music_track.dart';
import 'video_filter_preset.dart';

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

/// Everything collected across the Create -> Edit -> Music -> Preview ->
/// Thumbnail -> Caption -> Privacy steps (spec §17), held in one place so
/// each step screen just reads/writes fields on this rather than passing
/// a dozen separate arguments around.
class UploadDraft {
  UploadDraft({
    this.videoFile,
    this.thumbnailFile,
    this.caption = '',
    this.privacy = VideoPrivacy.public,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.filterPresetId = VideoFilterPreset.noneId,
    this.musicTrackId,
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

  /// Color-grade chosen in the editor's Filter step. Persisted by id and
  /// re-applied at playback time via [VideoFilterPreset.byId].
  final String filterPresetId;

  VideoFilterPreset get filterPreset =>
      VideoFilterPreset.byId(filterPresetId) ?? VideoFilterPreset.none;

  /// Library track picked for background music, or null for original
  /// audio only. Metadata-only persistence — mixing happens server-side
  /// (same phase-deferral rationale as trim).
  final String? musicTrackId;

  MusicTrack? get musicTrack => MusicTrack.byId(musicTrackId);

  /// Hashtags parsed live from [caption] rather than a separate field —
  /// matches how TikTok/Reels-style composers work (spec §17, §19).
  List<String> get hashtags {
    final matches = RegExp(r'#(\w+)').allMatches(caption);
    return matches.map((m) => m.group(1)!.toLowerCase()).toSet().toList();
  }

  bool get hasMusic => musicTrackId != null;

  UploadDraft copyWith({
    File? videoFile,
    File? thumbnailFile,
    bool clearThumbnail = false,
    String? caption,
    VideoPrivacy? privacy,
    Duration? trimStart,
    Duration? trimEnd,
    String? filterPresetId,
    bool clearMusic = false,
    String? musicTrackId,
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
      filterPresetId: filterPresetId ?? this.filterPresetId,
      musicTrackId: clearMusic ? null : (musicTrackId ?? this.musicTrackId),
    );
  }
}
