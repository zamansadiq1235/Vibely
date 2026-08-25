import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------- Video feed item state ----------

class VideoFeedItemState {
  const VideoFeedItemState({this.showHeartPop = false});

  final bool showHeartPop;

  VideoFeedItemState copyWith({bool? showHeartPop}) {
    return VideoFeedItemState(showHeartPop: showHeartPop ?? this.showHeartPop);
  }
}

// ---------- Video feed item notifier ----------

class VideoFeedItemNotifier extends AsyncNotifier<VideoFeedItemState> {
  VideoFeedItemNotifier(this._postId);

  // Ignore unused field lint if _postId isn't referenced inside methods
  // ignore: unused_field
  final String _postId;

  @override
  FutureOr<VideoFeedItemState> build() {
    return const VideoFeedItemState();
  }

  void showHeartAnimation() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(showHeartPop: true));
  }

  void hideHeartAnimation() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(showHeartPop: false));
  }
}

final videoFeedItemProvider = AsyncNotifierProvider.family
    .autoDispose<VideoFeedItemNotifier, VideoFeedItemState, String>(
      VideoFeedItemNotifier.new,
    );
