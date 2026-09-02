import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/video_filter_preset.dart';
import '../../domain/entities/video_animation_preset.dart';
import '../providers/upload_provider.dart';

/// Editing-mode Filter step: live color-graded preview of the selected
/// clip plus a horizontally scrolling preset rail. Choices write
/// `filterPresetId` on the shared upload draft through Riverpod — the
/// publish pipeline persists it (`videos.filter_preset`) and the feed
/// re-applies it at playback via [VideoFilterPreset.byId].
class FilterStep extends ConsumerStatefulWidget {
  const FilterStep({super.key});

  @override
  ConsumerState<FilterStep> createState() => _FilterStepState();
}

class _FilterStepState extends ConsumerState<FilterStep>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initError = false;
  AnimationController? _animController;
  VideoAnimationPreset _animPreset = VideoAnimationPreset.none;

  @override
  void initState() {
    super.initState();
    _init();
    _restartAnimationPreset();
  }

  /// Loads the draft's chosen clip into a looping [VideoPlayerController]
  /// for the live color-graded preview. Surfaces a friendly error state if
  /// the file can't be decoded instead of failing silently.
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
      controller.dispose();
      if (mounted) setState(() => _initError = true);
    }
  }

  /// Drives the live preview animation using the draft's currently chosen
  /// motion preset. Recycled whenever the preset id changes.
  void _restartAnimationPreset() {
    final preset = VideoAnimationPreset.byId(
      ref.read(uploadDraftProvider).animationPresetId,
    ) ??
        VideoAnimationPreset.none;
    if (preset == _animPreset && _animController != null) return;
    _animPreset = preset;
    _animController?.dispose();
    _animController = null;
    if (preset.kind == VideoAnimationKind.none) return;
    final controller = AnimationController(vsync: this, duration: preset.duration);
    _animController = controller;
    controller.repeat();
  }

  /// Selects [preset] (persists the id on the draft and restarts the preview).
  void _pickAnimation(VideoAnimationPreset preset) {
    ref
        .read(uploadDraftProvider.notifier)
        .update((d) => d.copyWith(animationPresetId: preset.id));
    _restartAnimationPreset();
  }

  /// Wraps [child] with the live motion-preset transform at the controller's
  /// current loop position. Returns [child] untouched when no animation is
  /// selected.
  Widget _wrapAnimation({required VideoAnimationPreset preset, required Widget child}) {
    final anim = _animController;
    if (anim == null || preset.kind == VideoAnimationKind.none) return child;
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (context, child) => preset.wrap(child: child!, t: anim.value),
    );
  }

  @override
  void dispose() {
    _animController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(uploadDraftProvider);
    final selected = draft.filterPreset;
    final controller = _controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildPreview(context, controller, selected)),
        const SizedBox(height: 4),
        Text(
          'Filters',
          style: context.textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 108,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: VideoFilterPreset.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _PresetTile(preset: VideoFilterPreset.all[index]),
          ),
                ),
        const SizedBox(height: 4),
        Text('Animations', style: context.textTheme.labelSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: VideoAnimationPreset.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _AnimationTile(preset: VideoAnimationPreset.all[index]),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildPreview(
    BuildContext context,
    VideoPlayerController? controller,
    VideoFilterPreset selected,
  ) {
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
            Text('Could not load this video', style: context.textTheme.bodyMedium),
          ],
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final isNeutral = selected.id == VideoFilterPreset.none.id;

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
                child: _wrapAnimation(
          preset: _animPreset,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            // The chosen matrix paints over the actual frames while the
            // user decides; identical application at feed playback keeps
            // what-you-see == what-viewers-get.
            child: ColorFiltered(
            colorFilter: ColorFilter.matrix(selected.matrix),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isNeutral ? Colors.white38 : AppColors.accent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(selected.icon, size: 13, color: AppColors.accent),
                        const SizedBox(width: 5),
                        Text(
                          selected.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
    );
  }
}

class _AnimationTile extends ConsumerWidget {
  const _AnimationTile({required this.preset});

  final VideoAnimationPreset preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected =
        ref.watch(uploadDraftProvider).animationPresetId == preset.id;
    final labelColor = context.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () {
        final state = context.findAncestorStateOfType<_FilterStepState>();
        state?._pickAnimation(preset);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.white24,
                width: isSelected ? 2.6 : 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.85),
                  AppColors.accent.withValues(alpha: 0.55),
                  AppColors.secondaryAccent.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Icon(preset.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            preset.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends ConsumerWidget {
  const _PresetTile({required this.preset});

  final VideoFilterPreset preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected =
        ref.watch(uploadDraftProvider).filterPresetId == preset.id;
    final labelColor = context.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => ref
          .read(uploadDraftProvider.notifier)
          .update((d) => d.copyWith(filterPresetId: preset.id)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.white24,
                width: isSelected ? 2.6 : 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.85),
                  AppColors.accent.withValues(alpha: 0.55),
                  AppColors.secondaryAccent.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Icon(preset.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            preset.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : labelColor,
            ),
          ),
        ],
      ),
    );
  }
}