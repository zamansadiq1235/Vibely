import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../providers/upload_provider.dart';

/// Preview + trim step. Trimming here sets `trimStart`/`trimEnd`
/// metadata on the draft (see UploadDraft's doc comment for why the
/// file itself isn't re-encoded client-side in this phase) — the
/// preview still plays the full file so the user can find their points.
class PreviewTrimStep extends ConsumerStatefulWidget {
  const PreviewTrimStep({super.key});

  @override
  ConsumerState<PreviewTrimStep> createState() => _PreviewTrimStepState();
}

class _PreviewTrimStepState extends ConsumerState<PreviewTrimStep> {
  VideoPlayerController? _controller;
  bool _initError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final file = ref.read(uploadDraftProvider).videoFile;
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
  }

  @override
  void dispose() {
    _controller?.dispose();
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
      return const Center(child: CircularProgressIndicator());
    }

    final duration = controller.value.duration;
    final draft = ref.watch(uploadDraftProvider);
    final trimEnd = draft.trimEnd ?? duration;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: GestureDetector(
                onTap: () => setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                }),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                onChanged: (values) {
                  ref
                      .read(uploadDraftProvider.notifier)
                      .update(
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
