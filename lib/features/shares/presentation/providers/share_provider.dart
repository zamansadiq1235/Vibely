// ignore_for_file: deprecated_member_use

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/supabase_client_provider.dart';
import '../../../feed/domain/entities/video_post.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../data/datasources/share_remote_data_source.dart';
import '../../data/repositories/share_repository_impl.dart';
import '../../domain/repositories/share_repository.dart';

// ---------- Dependency injection ----------

final shareRemoteDataSourceProvider = Provider<ShareRemoteDataSource>((ref) {
  return ShareRemoteDataSource(ref.watch(supabaseClientProvider));
});

final shareRepositoryProvider = Provider<ShareRepository>((ref) {
  return ShareRepositoryImpl(ref.watch(shareRemoteDataSourceProvider));
});

/// Wraps the two share entry points from spec §14: the native OS share
/// sheet (`share_plus`) and "copy link." Both record a `video_shares`
/// row and bump the feed's displayed `sharesCount` — the real count
/// still comes from the server-side trigger (migration 0003) and
/// self-corrects on refresh, same pattern as likes/saves/reposts.
///
/// Note: there's no web app or custom deep-link domain yet (spec's
/// architecture explicitly anticipates a CDN/streaming integration
/// later), so the "link" shared today is the direct Supabase Storage
/// URL for the video file rather than a `vibely.app/video/:id` page.
/// Swapping this for a real shareable page URL is a drop-in change once
/// one exists — everything else in this class stays the same.
class ShareActions {
  ShareActions(this._ref);
  final Ref _ref;

  Future<void> shareNatively(VideoPost post) async {
    final text = post.caption.isNotEmpty
        ? '${post.caption}\n\n${post.videoUrl}'
        : post.videoUrl;
    await Share.share(text, subject: 'Check out this video on Vibely');
    await _recordAndBumpCount(post.id, 'native');
  }

  Future<void> copyLink(VideoPost post) async {
    await Clipboard.setData(ClipboardData(text: post.videoUrl));
    await _recordAndBumpCount(post.id, 'copy_link');
  }

  Future<void> _recordAndBumpCount(String videoId, String shareType) async {
    _ref
        .read(feedProvider.notifier)
        .patchVideo(
          videoId,
          (post) => post.copyWith(sharesCount: post.sharesCount + 1),
        );
    await _ref
        .read(shareRepositoryProvider)
        .recordShare(videoId: videoId, shareType: shareType);
  }
}

final shareActionsProvider = Provider((ref) => ShareActions(ref));
