import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/upload_provider.dart';

/// Preview + trim step. Trimming here sets `trimStart`/`trimEnd`
/// metadata on the draft (see UploadDraft's doc comment for why the
/// file itself isn't re-encoded client-side in this phase) — the
/// preview still plays the full file so the user can find their points.
///
/// If a background track was chosen in the Music step, it plays here
/// *alongside* the video (music audible, video in lead) so the composer
/// hears the combination before publishing — both players start/stop
/// together and the music loops for the clip's length.
class PreviewTrimStep extends ConsumerStatefulWidget {
  const PreviewTrimStep({super.key});

  @override
  ConsumerState<PreviewTrimStep> createState() => _PreviewTrimStepState();
}

class _PreviewTrimStepState extends ConsumerState<PreviewTrimStep> {
  VideoPlayerController? _controller;
  VideoPlayerController? _musicController;
  bool _initError = false;
  bool _musicInitError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final file = ref.read(uploadDraftProvider).videoFile;
    final musicUrl = ref.read(uploadDraftProvider).musicTrack?.previewUrl;
    if (file == null) return;

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _initError = true);
    }

    // Background music alongside the video, if one was selected. Kept
    // fully independent of video success so a broken audio stream can
    // never block the actual video preview from loading.
    if (musicUrl != null) {
      try {
        final musicController = VideoPlayerController.networkUrl(
          Uri.parse(musicUrl),
        );
        await musicController.initialize();
        await musicController.setLooping(true);
        await musicController.setVolume(0.9);
        await musicController.play();
        if (mounted) setState(() => _musicController = musicController);
      } catch (_) {
        if (mounted) setState(() => _musicInitError = true);
      }
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final playing = controller.value.isPlaying;
    playing ? controller.pause() : controller.play();
    // Keep background music in lock-step with the video transport.
    final music = _musicController;
    if (music != null && music.value.isInitialized) {
      playing ? music.pause() : music.play();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _musicController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: context.colors.error,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not preview this video',
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final duration = controller.value.duration;
    final draft = ref.watch(uploadDraftProvider);
    final trimEnd = draft.trimEnd ?? duration;
    final hasMusic = _musicController != null;
    final musicError = draft.hasMusic && _musicInitError;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),
                    if (!controller.value.isPlaying)
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 64,
                        color: Colors.white70,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasMusic || musicError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  musicError
                      ? Icons.music_off_rounded
                      : Icons.music_note_rounded,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  musicError
                      ? 'Music preview unavailable'
                      : 'Playing "${draft.musicTrack?.title}"',
                  style: context.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Text('Trim (optional)', style: context.textTheme.labelSmall),
              RangeSlider(
                values: RangeValues(
                  draft.trimStart.inMilliseconds.toDouble(),
                  trimEnd.inMilliseconds
                      .toDouble()
                      .clamp(0, duration.inMilliseconds.toDouble())
                      .toDouble(),
                ),
                min: 0,
                max: duration.inMilliseconds
                    .toDouble()
                    .clamp(1, double.infinity)
                    .toDouble(),
                activeColor: AppColors.accent,
                inactiveColor: AppColors.primary.withValues(alpha: 0.3),
                onChanged: (values) {
                  ref.read(uploadDraftProvider.notifier).update(
                        (d) => d.copyWith(
                          trimStart: Duration(
                            milliseconds: values.start.round(),
                          ),
                          trimEnd: Duration(milliseconds: values.end.round()),
                        ),
                      );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}