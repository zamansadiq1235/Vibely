import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/music_track.dart';
import '../providers/upload_provider.dart';

/// Editing-mode Music step. Lets the composer pick a background track
/// from the curated library (or go music-free). Tapping a row previews
/// it in-app; the *selection* is persisted as metadata on the draft and
/// videos row (`music_*` columns) — mixing audio into the file is a
/// later server-side job, same deferral rationale as trim.
class MusicStep extends ConsumerStatefulWidget {
  const MusicStep({super.key});

  @override
  ConsumerState<MusicStep> createState() => _MusicStepState();
}

class _MusicStepState extends ConsumerState<MusicStep> {
  VideoPlayerController? _previewController;
  String? _preloadingTrackId;
  bool _previewFailed = false;
  Timer? _uiSyncTimer;

  @override
  void dispose() {
    _uiSyncTimer?.cancel();
    _previewController?.dispose();
    super.dispose();
  }

  /// Plays/stops the audible preview of [track]. Uses video_player on the
  /// mp3 stream (ExoPlayer/AVPlayer handle audio-only fine) so no extra
  /// dependency is needed for what is an editor convenience.
  Future<void> _togglePreview(MusicTrack track) async {
    final current = _previewController;

    // Tapping the active row stops its preview.
    if (current != null && _preloadingTrackId == track.id) {
      if (current.value.isPlaying) {
        await current.pause();
        return;
      }
      await current.play();
      return;
    }

    await _stopPreview();
    setState(() {
      _preloadingTrackId = track.id;
      _previewFailed = false;
    });
    final url = track.previewUrl;
    if (url == null) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (!mounted || _preloadingTrackId != track.id) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() => _previewController = controller);
      // Keep play/pause icons honest without rebuilding the tree every
      // frame — the only state we render from this controller is volume.
      _uiSyncTimer?.cancel();
      _uiSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_previewController!.value.isInitialized) return;
        if (!_previewController!.value.isPlaying && mounted) setState(() {});
      });
    } catch (_) {
      if (!mounted) return;
      await controller.dispose().catchError((_) {});
      setState(() {
        _previewFailed = true;
        _preloadingTrackId = null;
      });
    }
  }

  Future<void> _stopPreview() async {
    _uiSyncTimer?.cancel();
    final current = _previewController;
    _previewController = null;
    _preloadingTrackId = null;
    if (current != null) {
      try {
        await current.pause();
        await current.dispose();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _pick(String? trackId) {
    ref.read(uploadDraftProvider.notifier).update(
          (d) => d.copyWith(clearMusic: trackId == null, musicTrackId: trackId),
        );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(uploadDraftProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.library_music_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text('Background music', style: context.textTheme.bodyLarge),
              const Spacer(),
              TextButton.icon(
                onPressed:
                    draft.hasMusic ? () { _pick(null); _stopPreview(); } : null,
                icon: const Icon(Icons.music_off_rounded, size: 16),
                label: const Text('None'),
                style: TextButton.styleFrom(
                  foregroundColor: draft.hasMusic
                      ? AppColors.error
                      : context.colors.outline,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
            itemCount: MusicTrack.all.length,
            itemBuilder: (context, index) {
              final track = MusicTrack.all[index];
              final previewTarget = _preloadingTrackId == track.id;
              return _TrackTile(
                track: track,
                isSelected: draft.musicTrackId == track.id,
                isPreviewTarget: previewTarget,
                isPreviewLoading:
                    previewTarget && _previewController == null,
                isPreviewPlaying:
                    previewTarget &&
                        (_previewController?.value.isPlaying ?? false),
                previewFailed: _previewFailed && previewTarget,
                onTap: () => _togglePreview(track),
                onPick: () =>
                    _pick(draft.musicTrackId == track.id ? null : track.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One library row: artwork gradient, title/artist, a play/pause preview
/// button, and a pick (radio) control — selection and auditioning are
/// intentionally independent actions.
class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.isSelected,
    required this.isPreviewTarget,
    required this.isPreviewLoading,
    required this.isPreviewPlaying,
    required this.previewFailed,
    required this.onTap,
    required this.onPick,
  });

  final MusicTrack track;
  final bool isSelected;

  /// True while this row owns the in-flight/attached preview controller —
  /// distinguishes "loaded but paused" from "never started".
  final bool isPreviewTarget;
  final bool isPreviewLoading;
  final bool isPreviewPlaying;
  final bool previewFailed;
  final VoidCallback onTap;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.16)
            : context.colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.white12.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                // Artwork doubles as the pick control.
                GestureDetector(
                  onTap: onPick,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryDark,
                          AppColors.accent,
                          AppColors.secondaryAccent,
                        ],
                      ),
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_rounded
                          : Icons.music_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.artist} · ${track.genre}',
                        style: context.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.circle_rounded,
                      size: 10, color: AppColors.accent),
                const SizedBox(width: 6),
                _buildPreviewButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewButton(BuildContext context) {
    if (previewFailed) {
      return IconButton(
        tooltip: 'Preview unavailable',
        onPressed: onTap,
        icon: Icon(Icons.error_outline_rounded,
            color: AppColors.warning, size: 22),
      );
    }
    if (isPreviewLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    Widget icon;
    Color color = AppColors.accent;
    if (isPreviewTarget) {
      icon = Icon(
        isPreviewPlaying
            ? Icons.pause_circle_rounded
            : Icons.play_circle_rounded,
        size: 34,
      );
    } else {
      icon = const Icon(Icons.play_circle_outline_rounded, size: 34);
      if (context.isDark) {
        color = AppColors.textSecondaryDark;
      }
    }

    return IconButton(
      tooltip: isPreviewPlaying ? 'Stop preview' : 'Play preview',
      onPressed: track.previewUrl == null ? null : onTap,
      icon: IconTheme.merge(
        data: IconThemeData(color: color),
        child: icon,
      ),
    );
  }
}