
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/services/progress_upload_client.dart';
import '../../domain/entities/upload_draft.dart';

class UploadRemoteDataSource {
  UploadRemoteDataSource(this._client, this.supabaseUrl, this.anonKey);

  final SupabaseClient _client;
  final String supabaseUrl;
  final String anonKey;

  ProgressUploadClient? _activeUploader;

  Future<String> publish({
    required UploadDraft draft,
    required void Function(double progress) onProgress,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final accessToken = _client.auth.currentSession?.accessToken;
    if (userId == null || accessToken == null) {
      throw AppException.unauthorized();
    }

    final videoFile = draft.videoFile;
    if (videoFile == null) {
      throw AppException.unknown('No video selected.');
    }

    // Postgres generates the real `videos.id` on insert, but the storage
    // path needs *some* id up front — a client-generated one is fine
    // since it's just a filename segment, not a primary key.
    final storageVideoId = _generateUuid();

    final uploader = ProgressUploadClient(
      supabaseUrl: supabaseUrl,
      anonKey: anonKey,
      accessToken: accessToken,
    );
    _activeUploader = uploader;

    try {
      // 1) Upload the video file — this is the slow part, so it gets
      // the visible 0-90% of the progress bar.
      final videoExt = videoFile.path.split('.').last;
      final videoPath = '$userId/$storageVideoId.$videoExt';
      await uploader.uploadFile(
        bucket: AppConstants.videosBucket,
        path: videoPath,
        file: videoFile,
        contentType: 'video/$videoExt',
        onProgress: (p) => onProgress(p * 0.9),
      );

      // 2) Upload the thumbnail, if the user picked one (0.9-0.97).
      String? thumbnailPath;
      final thumbFile = draft.thumbnailFile;
      if (thumbFile != null) {
        final thumbExt = thumbFile.path.split('.').last;
        thumbnailPath = '$userId/$storageVideoId.$thumbExt';
        await uploader.uploadFile(
          bucket: AppConstants.thumbnailsBucket,
          path: thumbnailPath,
          file: thumbFile,
          contentType: 'image/$thumbExt',
          onProgress: (p) => onProgress(0.9 + p * 0.07),
        );
      }

      // 3) Insert the videos row (0.97-1.0). Editing-mode extras ride
      // along: the color-grade preset picked in the Filter step (null =
      // original) and background-music metadata from the Music step —
      // the actual audio mixing is a later server-side job, mirroring how
      // trimStart/trimEnd persist now and act later.
      final row = await _client
          .from('videos')
          .insert({
            'user_id': userId,
            'video_path': videoPath,
            'thumbnail_path': thumbnailPath,
            'caption': draft.caption,
            'visibility': draft.privacy.dbValue,
            'filter_preset': _nonNull(draft.filterPresetId),
            ..._musicMetadata(draft),
            'animation_preset': _nonNull(draft.animationPresetId),
          })
          .select('id')
          .single();
      final newVideoId = row['id'] as String;

      // 4) Upsert + link hashtags parsed from the caption.
      if (draft.hashtags.isNotEmpty) {
        await _linkHashtags(newVideoId, draft.hashtags);
      }

      onProgress(1.0);
      return newVideoId;
    } on PostgrestException {
      throw AppException.unknown(
        'Could not save your video. Please try again.',
      );
    } finally {
      _activeUploader = null;
    }
  }

  Future<void> _linkHashtags(String videoId, List<String> tags) async {
    try {
      for (final tag in tags) {
        final row = await _client
            .from('hashtags')
            .upsert({'tag': tag}, onConflict: 'tag')
            .select('id')
            .single();
        await _client.from('video_hashtags').insert({
          'video_id': videoId,
          'hashtag_id': row['id'],
        });
      }
    } catch (_) {
      // Hashtag linking failing shouldn't fail the whole publish — the
      // video is already live at this point. Swallow and let search
      // simply not index these tags rather than losing the upload.
    }
  }

  void cancel() => _activeUploader?.cancel();

  /// 'none' vs null: keep the no-filter case an explicit value so
  /// "user chose Original" is distinguishable from "pre-dates editing".
  String? _nonNull(String? value) =>
      (value == null || value.isEmpty) ? null : value;

  Map<String, dynamic> _musicMetadata(UploadDraft draft) {
    final track = draft.musicTrack;
    if (track == null) return {};
    return {
      'music_title': track.title,
      'music_artist': track.artist,
      'music_url': _nonNull(track.previewUrl),
      'music_volume': draft.musicVolume.clamp(0.0, 1.0),
      'mute_original_audio': draft.muteOriginalAudio,
    };
  }

  String _generateUuid() {
    // Lightweight v4-ish UUID without an extra package dependency —
    // only used as a storage path segment, not as a DB primary key
    // (Postgres generates the real `videos.id` on insert).
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final rnd2 = identityHashCode(this) ^ rnd;
    return '${rnd.toRadixString(16)}-${rnd2.toRadixString(16)}';
  }
}
