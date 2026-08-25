import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../domain/entities/upload_state.dart';
import '../providers/upload_provider.dart';

class UploadProgressOverlay extends ConsumerWidget {
  const UploadProgressOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadNotifierProvider);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: _buildBody(context, ref, state)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, UploadState state) {
    return switch (state) {
      UploadInProgress(:final progress, :final stage) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 6),
                Text('${(progress * 100).round()}%'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(stage, style: context.textTheme.bodyMedium),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => ref.read(uploadNotifierProvider.notifier).cancel(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      UploadSuccess() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 64,
            color: context.colors.primary,
          ),
          const SizedBox(height: 16),
          Text('Video published!', style: context.textTheme.headlineMedium),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.read(uploadNotifierProvider.notifier).reset();
              context.go(RouteNames.home);
            },
            child: const Text('Done'),
          ),
        ],
      ),
      UploadFailure(:final message) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: context.colors.error,
          ),
          const SizedBox(height: 16),
          Text('Upload failed', style: context.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            message,
            style: context.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () =>
                    ref.read(uploadNotifierProvider.notifier).reset(),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(uploadNotifierProvider.notifier).retry(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
      UploadCancelled() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_outlined, size: 56, color: context.colors.outline),
          const SizedBox(height: 16),
          Text('Upload cancelled', style: context.textTheme.headlineMedium),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.read(uploadNotifierProvider.notifier).reset(),
            child: const Text('Back'),
          ),
        ],
      ),
      UploadIdle() => const SizedBox.shrink(),
    };
  }
}
