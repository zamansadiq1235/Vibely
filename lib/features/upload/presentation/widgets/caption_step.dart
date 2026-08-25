import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../providers/upload_provider.dart';

class CaptionStep extends ConsumerStatefulWidget {
  const CaptionStep({super.key});

  @override
  ConsumerState<CaptionStep> createState() => _CaptionStepState();
}

class _CaptionStepState extends ConsumerState<CaptionStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(uploadDraftProvider).caption,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(uploadDraftProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Write a caption', style: context.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Add hashtags with # — they show up as tags below as you type.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Describe your video... #flutter #coding',
              ),
              onChanged: (value) => ref
                  .read(uploadDraftProvider.notifier)
                  .update((d) => d.copyWith(caption: value)),
            ),
            if (draft.hashtags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: draft.hashtags
                    .map(
                      (tag) => Chip(
                        label: Text('#$tag'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
