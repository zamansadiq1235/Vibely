import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/upload_provider.dart';

/// Thumbnail step: grab a still from anywhere in the clip (scrub the
/// slider and capture the exact displayed frame) or pick an image from
/// the gallery instead. The chosen image lands on the draft as
/// [UploadDraft.thumbnailFile]; publish uploads it to the thumbnails
/// bucket and links `videos.thumbnail_path`. A thumbnail is optional —
/// without one clients fall back to the video's own preview.
class ThumbnailStep extends ConsumerStatefulWidget {
  const ThumbnailStep({super.key});

  @override
  ConsumerState<ThumbnailStep> createState() => _ThumbnailStepState();
}

class _ThumbnailStepState extends ConsumerState<ThumbnailStep>
    with WidgetsBindingObserver {
  final _captureBoundaryKey = GlobalKey();

  VideoPlayerController? _controller;
  bool _initError = false;
  bool _capturing = false;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  Future<void> _initController() async {
    final file = ref.read(uploadDraftProvider).videoFile;
    if (file == null) return;
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      if (!mounted) {
        await _safeDispose(controller);
        return;
      }
      await controller.setLooping(true);
      await controller.play().catchError((_) {});
      setState(() => _controller = controller);
    } catch (_) {
      // The clip may be unreadable in this container — fail soft; users
      // can still pick a thumbnail from their gallery below.
      await _safeDispose(controller).catchError((_) {});
      if (mounted) setState(() => _initError = true);
    }
  }

  Future<void> _captureFrame() async {
    if (_capturing) return;
    final boundary =
        _captureBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      context.showSnack('Preview not ready yet.', isError: true);
      return;
    }

    setState(() => _capturing = true);
    Uint8List? pngBytes;
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ImageByteFormat.png);
      pngBytes = data?.buffer.asUint8List();
      image.dispose();
    } catch (_) {
      pngBytes = null;
    }

    File? savedFile;
    if (pngBytes != null) {
      try {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/clipzo_thumb_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(pngBytes);
        savedFile = file;
      } catch (_) {
        savedFile = null;
      }
    }

    if (!mounted) return;
    setState(() => _capturing = false);

    if (savedFile == null) {
      context.showSnack(
        "Couldn't capture this frame — try 'From gallery'.",
        isError: true,
      );
      return;
    }
    _applyThumbnail(savedFile);
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 88,
      );
      if (!mounted || picked == null) return;
      _applyThumbnail(File(picked.path));
    } catch (_) {
      if (mounted) context.showSnack("Couldn't open your gallery.", isError: true);
    }
  }

  void _applyThumbnail(File file) {
    ref.read(uploadDraftProvider.notifier).update(
          (d) => d.copyWith(thumbnailFile: file),
        );
    HapticFeedback.lightImpact();
  }

  Future<void> _removeThumbnail() async {
    final old = ref.read(uploadDraftProvider).thumbnailFile;
    ref.read(uploadDraftProvider.notifier).update(
          (d) => d.copyWith(clearThumbnail: true),
        );
    // Best-effort cleanup of a captured temp frame (gallery originals
    // untouched — they're the user's own files).
    if (old != null && old.path.contains('clipzo_thumb_')) {
      try {
        await old.delete();
      } catch (_) {}
    }
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      if (c.value.isPlaying) {
        _userPaused = true;
        await c.pause().catchError((_) {});
      } else {
        _userPaused = false;
        await c.play().catchError((_) {});
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state != AppLifecycleState.resumed) {
      try {
        c?.pause().catchError((_) {});
      } catch (_) {}
    } else if (_controller != null && !_userPaused) {
      try {
        c?.play().catchError((_) {});
      } catch (_) {}
    }
  }

  Future<void> _safeDispose(VideoPlayerController? c) async {
    if (c == null) return;
    try {
      await c.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    _controller = null;
    _safeDispose(c).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError) return _buildPreviewError(context);

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final draft = ref.watch(uploadDraftProvider);
    final thumb = draft.thumbnailFile;
    final durationMs = controller.value.duration.inMilliseconds.toDouble();

    return Column(
      children: [
        Expanded(child: _buildPreview(context, controller, thumb)),
        _buildScrubber(controller, durationMs),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _capturing ? null : _captureFrame,
                icon: _capturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_rounded, size: 18),
                label: Text(_capturing ? 'Capturing…' : 'Capture frame'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.image_rounded, size: 18),
                label: const Text('From gallery'),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  /// Live preview centered on the captured boundary, so exactly what is
  /// on screen is exactly what gets written to the file. Falls back to
  /// the chosen thumbnail image if one is set but the preview can't run.
  Widget _buildPreview(
    BuildContext context,
    VideoPlayerController controller,
    File? thumb,
  ) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return Center(
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: RepaintBoundary(
            key: _captureBoundaryKey,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(controller),
                  if (thumb != null)
                    // Show the chosen thumbnail over the live frame while
                    // capturing & after; a small "live" chip explains it.
                    Positioned.fill(
                      child: Image.file(thumb, fit: BoxFit.cover),
                    ),
                  if (thumb != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Selected',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (thumb != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeThumbnail,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (thumb == null && !controller.value.isPlaying)
                    const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 64,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Scrub anywhere in the clip, then capture that exact moment.
  Widget _buildScrubber(
    VideoPlayerController controller,
    double durationMs,
  ) {
    final positionMs = controller.value.position.inMilliseconds.toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Text('Scrub to a moment, then capture', style: context.textTheme.labelSmall),
          Slider(
            value: positionMs.clamp(0, durationMs).toDouble(),
            max: durationMs.clamp(1, double.infinity).toDouble(),
            activeColor: AppColors.accent,
            inactiveColor: AppColors.primary.withValues(alpha: 0.3),
            onChanged: (value) async {
              try {
                await controller
                    .seekTo(Duration(milliseconds: value.round()))
                    .catchError((_) {});
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: context.colors.error),
            const SizedBox(height: 8),
            Text('Could not preview this video', style: context.textTheme.bodyMedium),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.image_rounded),
              label: const Text('Choose a thumbnail from gallery'),
            ),
          ],
        ),
      ),
    );
  }
}