// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/route_names.dart';
import '../../../comments/presentation/widgets/comment_bottom_sheet.dart';
import '../../../likes/presentation/providers/like_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../reposts/presentation/providers/repost_provider.dart';
import '../../../saved_videos/presentation/providers/saved_videos_provider.dart';
import '../../../shares/presentation/widgets/share_options_sheet.dart';
import '../../domain/entities/video_post.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_video_controller_cache.dart';
import '../widgets/video_feed_item.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  final _controllerCache = FeedVideoControllerCache();
  int _currentIndex = 0;
  bool _isMuted = false;
  bool _appInBackground = false;

  /// True while the current video is deliberately paused by the user
  /// (tap, control-row button, or hold-release restoring a pause).
  /// Automatic resumes (app foregrounding, sheet dismissal) must not
  /// override it — the video stays stopped until the user plays again.
  bool _pausedByUser = false;
  Timer? _viewTimer;
  String? _viewRecordedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause playback when the app backgrounds — required so a video
    // doesn't keep playing (and burning data/battery) off-screen.
    final wasInBackground = _appInBackground;
    _appInBackground = state != AppLifecycleState.resumed;
    if (_appInBackground && !wasInBackground) {
      _controllerCache.controllerAt(_currentIndex)?.pause();
      _controllerCache.pauseMusic(_currentIndex);
    } else if (!_appInBackground && wasInBackground) {
      // Don't force-resume if the user had deliberately paused this video.
      if (!_pausedByUser) {
        _controllerCache.controllerAt(_currentIndex)?.play();
        _controllerCache.playMusic(_currentIndex);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _viewTimer?.cancel();
    _controllerCache.disposeAll();
    super.dispose();
  }

  /// Spec §37: a view counts once the video has been visible *and*
  /// playing for a minimum duration — not the instant it appears.
  /// Cancelled and restarted on every page change so a quick flick past
  /// several videos never counts a view for any of them.
  void _scheduleViewRecording(String videoId) {
    _viewTimer?.cancel();
    if (_viewRecordedFor == videoId) return;
    _viewTimer = Timer(AppConstants.minWatchDurationForView, () {
      if (!mounted) return;
      ref.read(feedRepositoryProvider).recordView(videoId);
      _viewRecordedFor = videoId;
    });
  }

  void _onPageChanged(int index, int videoCount) {
    setState(() {
      _currentIndex = index;
      // A fresh page starts playing on its own; any previous deliberate
      // pause applied to a different video.
      _pausedByUser = false;
    });
    _viewTimer?.cancel();

    // Controller strategy from spec §7/§30: only previous/current/next
    // ever exist. Preload the next `AppConstants.preloadWindow` videos,
    // keep the one behind for instant back-swipe, drop everything else.
    final keep = <int>{
      for (var i = index - 1; i <= index + AppConstants.preloadWindow; i++)
        if (i >= 0 && i < videoCount) i,
    };
    _controllerCache.trimTo(keep);
    _controllerCache.pauseAllExcept(index);
    final current = _controllerCache.controllerAt(index);
    if (current != null && current.value.isInitialized) {
      current.play();
    }
    _controllerCache.playMusic(index);

    // Fetch more once the user is within 3 videos of the loaded end.
    if (index >= videoCount - 3) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  void _ensureControllersAround(int index, List<VideoPost> videos) {
    for (var i = index -  1; i <= index + AppConstants.preloadWindow; i++) {
      if (i < 0 || i >= videos.length) continue;
      final post = videos[i];
      if (_controllerCache.controllerAt(i) == null) {
        _controllerCache.ensure(i, post.videoUrl).then((controller) {
          if (!mounted) return;
          controller.setVolume(_isMuted
              ? 0
              : (post.muteOriginalAudio == true && post.musicUrl != null ? 0 : 1));
          if (i == _currentIndex && !_appInBackground) {
            controller.play();
          }
          setState(() {});
        });
      }
      final musicUrl = post.musicUrl;
      if (musicUrl != null && _controllerCache.musicControllerAt(i) == null) {
        _controllerCache.ensureMusic(i, musicUrl, volume: _isMuted ? 0 : (post.musicVolume ?? 1)).then((_) {
          if (!mounted) return;
          if (i == _currentIndex && !_appInBackground) {
            _controllerCache.playMusic(i);
          }
          setState(() {});
        });
      }
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    final videos = ref.read(feedProvider).asData?.value.videos ?? const [];
    for (var i = _currentIndex - 1; i <= _currentIndex +  1; i++) {
      if (i < 0 || i >= videos.length) continue;
      final post = videos[i];
      _controllerCache.controllerAt(i)?.setVolume(_isMuted
          ? 0
          : (post.muteOriginalAudio == true && post.musicUrl != null ? 0 : 1));
      _controllerCache.setMusicVolume(i, _isMuted ? 0 : (post.musicVolume ?? 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: feedAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, _) => _FeedError(
          message: '$err',
          onRetry: () => ref.read(feedProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.videos.isEmpty) {
            return const _EmptyFeed();
          }

          // Kick off preloading for whatever should be alive right now —
          // called every build, but ensure() is a no-op once a
          // controller already exists for an index, and the view timer
          // is a no-op if a view was already recorded for this index.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureControllersAround(_currentIndex, state.videos);
            if (_currentIndex < state.videos.length) {
              _scheduleViewRecording(state.videos[_currentIndex].id);
            }
          });

          return RefreshIndicator(
            onRefresh: () => ref.read(feedProvider.notifier).refresh(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.87,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: state.videos.length,
                onPageChanged: (i) => _onPageChanged(i, state.videos.length),
                itemBuilder: (context, index) {
                  final post = state.videos[index];
                  return RepaintBoundary(
                    key: ValueKey(post.id),
                    child: VideoFeedItem(
                      post: post,
                      controller: _controllerCache.controllerAt(index),
                      isActive: index == _currentIndex,
                      isMuted: _isMuted,
                      onToggleMute: _toggleMute,
                      // Track deliberate play/pause so auto-resume paths
                      // (lifecycle, sheet close) respect the user's choice.
                      onPlayPauseToggled: (playing) {
                        if (index != _currentIndex) return;
                        setState(() => _pausedByUser = !playing);
                      },
                      onLikeTap: () => _handleLikeTap(post.id),
                      onDoubleTapLike: () => _handleLikeTap(post.id),
                      onRetry: () {
                        _controllerCache.trimTo({
                          for (var i = index - 1; i <= index + 1; i++)
                            if (i != index && i >= 0 && i < state.videos.length)
                              i,
                        });
                        setState(() {});
                      },
                      onCommentTap: () =>
                          _openComments(context, post.id, post.commentsCount),
                      onShareTap: () => _openShareSheet(context, post),
                      onSaveTap: () => _handleSaveTap(post.id),
                      onRepostTap: () => _handleRepostTap(post.id),
                      onAvatarTap: () => context.push(
                        RouteNames.userProfile.replaceFirst(
                          ':userId',
                          post.userId,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Toggles like state with an immediate optimistic UI update, then
  /// persists it to `video_likes` (see LikeActions) — reverted
  /// automatically if the write fails, with a snackbar to explain why.
  Future<void> _handleLikeTap(String videoId) async {
    final videos = ref.read(feedProvider).asData?.value.videos ?? const [];
    VideoPost? post;
    for (final v in videos) {
      if (v.id == videoId) {
        post = v;
        break;
      }
    }
    if (post == null) return;

    try {
      await ref.read(likeActionsProvider).setLiked(videoId, !post.isLikedByMe);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _openComments(BuildContext context, String videoId, int commentsCount) {
    // Pause the active video while the sheet is open — mirrors how most
    // short-video apps behave, and avoids audio continuing to play
    // "under" the comments UI.
    _controllerCache.controllerAt(_currentIndex)?.pause();
    _controllerCache.pauseMusic(_currentIndex);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: CommentBottomSheet(
            videoId: videoId,
            initialCount: commentsCount,
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted && !_appInBackground && !_pausedByUser) {
        _controllerCache.controllerAt(_currentIndex)?.play();
      }
    });
  }

  void _notImplementedYet(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openShareSheet(BuildContext context, VideoPost post) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ShareOptionsSheet(post: post),
    );
  }

  Future<void> _handleSaveTap(String videoId) async {
    final post = _findPost(videoId);
    if (post == null) return;
    try {
      await ref.read(saveActionsProvider).setSaved(videoId, !post.isSavedByMe);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _handleRepostTap(String videoId) async {
    final post = _findPost(videoId);
    final myId = ref.read(currentUserIdProvider);
    if (post == null || myId == null) return;
    try {
      await ref
          .read(repostActionsProvider)
          .setReposted(videoId, !post.isRepostedByMe, currentUserId: myId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  VideoPost? _findPost(String videoId) {
    final videos = ref.read(feedProvider).asData?.value.videos ?? const [];
    for (final v in videos) {
      if (v.id == videoId) return v;
    }
    return null;
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
          SizedBox(height: 12),
          Text('No videos yet', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 4),
          Text(
            'Be the first to post something!',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
