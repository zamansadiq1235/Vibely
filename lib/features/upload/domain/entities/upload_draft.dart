import 'dart:io';

import 'music_track.dart';
import 'video_animation_preset.dart';
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
    this.musicTitle,
    this.musicArtist,
    this.musicUrl,
    this.musicThumbnailUrl,
    this.musicVolume = 0.8,
    this.muteOriginalAudio = false,
    this.animationPresetId = VideoAnimationPreset.noneId,
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
  final String animationPresetId;

  VideoFilterPreset get filterPreset =>
      VideoFilterPreset.byId(filterPresetId) ?? VideoFilterPreset.none;

  /// Motion preset chosen in the editor's Edit step (animations rail).
  /// Re-applied at playback time via [VideoAnimationPreset.byId] —
  /// same metadata-only pattern as the color grade above.

  /// Library/API track picked for background music, or null for original
  /// audio only. Curated tracks are keyed by [musicTrackId]; a track
  /// searched live from the MusicAPI stores its metadata inline ([musicTitle],
  /// [musicArtist], [musicUrl], [musicThumbnailUrl]) since it doesn't exist in
  /// the static library. Mixing the audio into the file is deferred (server-side
  /// / at playback), same rationale as trim/filter.

  final String? musicTrackId;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicUrl;
  final String? musicThumbnailUrl;

  /// Playback preference: how loud the added track plays (0.0-1.0)
  final double musicVolume;

  /// When a track is added, mute the video's own audio (play only music).
  final bool muteOriginalAudio;

  MusicTrack? get musicTrack {
    final curated = MusicTrack.byId(musicTrackId);
    if (curated != null) return curated;
    final title = musicTitle;
    final url = musicUrl;
    if (title == null || url == null) return null;
    return MusicTrack(
      id: musicTrackId ?? 'api_track',
      title: title,
      artist: musicArtist ?? 'MusicAPI',
      genre: 'Search',
      previewUrl: url,
      thumbnailUrl: musicThumbnailUrl,
    );
  }

  /// Hashtags parsed live from [caption] rather than a separate field —
  /// matches how TikTok/Reels-style composers work (spec §17, §19).
  List<String> get hashtags {
    final matches = RegExp(r'#(\w+)').allMatches(caption);
    return matches.map((m) => m.group(1)!.toLowerCase()).toSet().toList();
  }

  bool get hasMusic => musicTrackId != null || musicUrl != null;

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
    String? musicTitle,
    String? musicArtist,
    String? musicUrl,
    String? musicThumbnailUrl,
    double? musicVolume,
    bool? muteOriginalAudio,
    String? animationPresetId,
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
      musicTitle: clearMusic ? null : (musicTitle ?? this.musicTitle),
      musicArtist: clearMusic ? null : (musicArtist ?? this.musicArtist),
      musicUrl: clearMusic ? null : (musicUrl ?? this.musicUrl),
      musicThumbnailUrl: clearMusic ? null : (musicThumbnailUrl ?? this.musicThumbnailUrl),
      musicVolume: musicVolume ?? this.musicVolume,
      muteOriginalAudio: clearMusic ? false : (muteOriginalAudio ?? this.muteOriginalAudio),
      animationPresetId: animationPresetId ?? this.animationPresetId,

    );
  }
}
