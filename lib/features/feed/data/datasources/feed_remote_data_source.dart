// ignore_for_file: use_null_aware_elements

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';

class FeedRemoteDataSource {
  FeedRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchFeedRows({required int page}) async {
    final from = page * AppConstants.feedPageSize;
    final to = from + AppConstants.feedPageSize - 1;

    try {
      // RLS (migration 0005) already filters this to videos the current
      // user is allowed to see, honoring public/friends/private — no
      // extra visibility filtering needed client-side.
      final rows = await _client
          .from('videos')
          .select('*, profiles!videos_user_id_fkey(username, avatar_path)')
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load the feed.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  /// A single user's own uploads, newest first — backs the Profile
  /// screen's "Videos" tab (spec §5). RLS still applies, so viewing
  /// someone else's profile only returns what you're allowed to see of
  /// theirs; viewing your own returns everything including private ones.
  Future<List<Map<String, dynamic>>> fetchUserVideoRows({
    required String userId,
    required int page,
  }) async {
    final from = page * AppConstants.feedPageSize;
    final to = from + AppConstants.feedPageSize - 1;
    try {
      final rows = await _client
          .from('videos')
          .select('*, profiles!videos_user_id_fkey(username, avatar_path)')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw AppException.unknown(
        e.message.isNotEmpty ? e.message : 'Could not load these videos.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.network();
    }
  }

  /// One round trip instead of three (Phase 13 performance pass — see
  /// migration 0007). Replaces the separate fetchLikedVideoIds /
  /// fetchSavedVideoIds / fetchRepostedVideoIds queries below, which are
  /// kept only as a documented fallback in case the RPC isn't deployed
  /// yet in a given environment.
  Future<VideoInteractionFlags> fetchInteractionFlags(
    List<String> videoIds,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || videoIds.isEmpty) {
      return VideoInteractionFlags.empty();
    }
    try {
      final rows = await _client.rpc(
        'get_video_interaction_flags',
        params: {'p_video_ids': videoIds},
      );
      final liked = <String>{};
      final saved = <String>{};
      final reposted = <String>{};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final id = row['video_id'] as String;
        if (row['is_liked'] == true) liked.add(id);
        if (row['is_saved'] == true) saved.add(id);
        if (row['is_reposted'] == true) reposted.add(id);
      }
      return VideoInteractionFlags(
        liked: liked,
        saved: saved,
        reposted: reposted,
      );
    } catch (_) {
      // Falls back to the three-query path so a not-yet-migrated
      // environment (RPC missing) degrades gracefully instead of
      // breaking every video list in the app.
      final results = await Future.wait([
        fetchLikedVideoIds(videoIds),
        fetchSavedVideoIds(videoIds),
        fetchRepostedVideoIds(videoIds),
      ]);
      return VideoInteractionFlags(
        liked: results[0],
        saved: results[1],
        reposted: results[2],
      );
    }
  }

  /// Which of the given video ids the current user has liked. Superseded
  /// by [fetchInteractionFlags] for normal use; kept as the fallback path
  /// above and because it's still a reasonable standalone primitive.
  Future<Set<String>> fetchLikedVideoIds(List<String> videoIds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || videoIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('video_likes')
          .select('video_id')
          .eq('user_id', userId)
          .inFilter('video_id', videoIds);
      return (rows as List).map((r) => r['video_id'] as String).toSet();
    } catch (_) {
      // Non-critical — a missed like-state just shows an outline heart.
      return {};
    }
  }

  /// Same idea as fetchLikedVideoIds, for the bookmark icon's fill state.
  Future<Set<String>> fetchSavedVideoIds(List<String> videoIds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || videoIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('saved_videos')
          .select('video_id')
          .eq('user_id', userId)
          .inFilter('video_id', videoIds);
      return (rows as List).map((r) => r['video_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Same idea again, for the repost icon's fill state.
  Future<Set<String>> fetchRepostedVideoIds(List<String> videoIds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || videoIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('reposts')
          .select('video_id')
          .eq('user_id', userId)
          .inFilter('video_id', videoIds);
      return (rows as List).map((r) => r['video_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> recordView(String videoId) async {
    final userId = _client.auth.currentUser?.id;
    try {
      await _client.from('video_views').insert({
        'video_id': videoId,
        if (userId != null) 'user_id': userId,
      });
    } catch (_) {
      // Views are best-effort — never surface a failure to the user for this.
    }
  }

  String resolveVideoUrl(String path) =>
      _client.storage.from(AppConstants.videosBucket).getPublicUrl(path);

  String? resolveThumbnailUrl(String? path) => path == null
      ? null
      : _client.storage.from(AppConstants.thumbnailsBucket).getPublicUrl(path);

  String? resolveAvatarUrl(String? path) => path == null
      ? null
      : _client.storage.from(AppConstants.avatarsBucket).getPublicUrl(path);
}

/// Result of [FeedRemoteDataSource.fetchInteractionFlags] — three id sets
/// in one bundle so callers don't juggle three separate futures/results.
class VideoInteractionFlags {
  const VideoInteractionFlags({
    required this.liked,
    required this.saved,
    required this.reposted,
  });

  final Set<String> liked;
  final Set<String> saved;
  final Set<String> reposted;

  factory VideoInteractionFlags.empty() =>
      const VideoInteractionFlags(liked: {}, saved: {}, reposted: {});
}
