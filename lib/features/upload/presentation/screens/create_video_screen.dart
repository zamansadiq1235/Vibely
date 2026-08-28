import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../domain/entities/upload_state.dart';
import '../providers/upload_provider.dart';
import '../widgets/caption_step.dart';
import '../widgets/filter_step.dart';
import '../widgets/music_step.dart';
import '../widgets/preview_trim_step.dart';
import '../widgets/thumbnail_step.dart';
import '../widgets/privacy_step.dart';
import '../widgets/select_video_step.dart';
import '../widgets/upload_progress_overlay.dart';

/// Implements the Create -> Gallery/Camera -> Edit (filters) -> Music ->
/// Preview -> Trim -> Thumbnail -> Caption -> Hashtags -> Privacy ->
/// Upload -> Publish flow (spec §17) as a single wizard with an internal
/// step index, backed by uploadDraftProvider so state survives moving
/// back and forth between steps without extra navigation plumbing.
class CreateVideoScreen extends ConsumerStatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  ConsumerState<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends ConsumerState<CreateVideoScreen> {
  int _step = 0;
  static const _stepCount =
      7; // select, edit/filters, music, preview/trim, thumbnail, caption, privacy

  void _next() {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
    } else {
      _publish();
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _publish() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (connectivity.contains(ConnectivityResult.none)) {
      context.showSnack(
        'No internet connection. Please try again when online.',
        isError: true,
      );
      return;
    }
    ref.read(uploadNotifierProvider.notifier).publish();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadNotifierProvider);
    final draft = ref.watch(uploadDraftProvider);

    if (uploadState is! UploadIdle) {
      return const Scaffold(body: UploadProgressOverlay());
    }

    final canAdvance = switch (_step) {
      0 => draft.videoFile != null,
      _ => true,
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _back,
        ),
        title: Text(_titleFor(_step)),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_step + 1) / _stepCount),
          Expanded(child: _bodyFor(_step)),
        ],
      ),
      bottomNavigationBar: draft.videoFile == null && _step == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: canAdvance ? _next : null,
                  child: Text(_step == _stepCount - 1 ? 'Publish' : 'Next'),
                ),
              ),
            ),
    );
  }

  String _titleFor(int step) => switch (step) {
    0 => 'Create',
    1 => 'Edit filters',
    2 => 'Add music',
    3 => 'Preview',
    4 => 'Thumbnail',
    5 => 'Caption',
    _ => 'Privacy',
  };

  Widget _bodyFor(int step) => switch (step) {
    0 => SelectVideoStep(onSelected: () => setState(() => _step = 1)),
    1 => const FilterStep(),
    2 => const MusicStep(),
    3 => const PreviewTrimStep(),
    4 => const ThumbnailStep(),
    5 => const CaptionStep(),
    _ => const PrivacyStep(),
  };
}
