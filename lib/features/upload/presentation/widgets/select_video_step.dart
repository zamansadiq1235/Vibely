import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../providers/upload_provider.dart';

class SelectVideoStep extends ConsumerWidget {
  const SelectVideoStep({super.key, required this.onSelected});

  final VoidCallback onSelected;

  Future<void> _pick(
    WidgetRef ref,
    BuildContext context,
    ImageSource source,
  ) async {
    final picked = await ImagePicker().pickVideo(
      source: source,
      maxDuration: const Duration(
        seconds: AppConstants.maxVideoDurationSeconds,
      ),
    );
    if (picked == null) return;

    final file = File(picked.path);
    final sizeBytes = await file.length();
    // 500 MB matches the `videos` bucket's file_size_limit (migration 0006).
    if (sizeBytes > 500 * 1024 * 1024) {
      if (context.mounted) {
        context.showSnack(
          'That video is too large (max 500 MB).',
          isError: true,
        );
      }
      return;
    }

    ref
        .read(uploadDraftProvider.notifier)
        .update((d) => d.copyWith(videoFile: file));
    onSelected();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_call_rounded,
              size: 72,
              color: context.colors.primary,
            ),
            const SizedBox(height: 16),
            Text('Create a video', style: context.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Choose a video from your gallery or record a new one.',
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _pick(ref, context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pick(ref, context, ImageSource.camera),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Record with Camera'),
            ),
          ],
        ),
      ),
    );
  }
}
