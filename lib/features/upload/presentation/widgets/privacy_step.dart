import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../domain/entities/upload_draft.dart';
import '../providers/upload_provider.dart';

class PrivacyStep extends ConsumerWidget {
  const PrivacyStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(uploadDraftProvider).privacy;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Who can watch this?', style: context.textTheme.headlineMedium),
          const SizedBox(height: 16),
          for (final option in VideoPrivacy.values)
            _PrivacyTile(
              option: option,
              selected: selected == option,
              onTap: () => ref
                  .read(uploadDraftProvider.notifier)
                  .update((d) => d.copyWith(privacy: option)),
            ),
        ],
      ),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final VideoPrivacy option;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (option) {
    VideoPrivacy.public => Icons.public_rounded,
    VideoPrivacy.friends => Icons.people_alt_rounded,
    VideoPrivacy.private => Icons.lock_rounded,
  };

  String get _subtitle => switch (option) {
    VideoPrivacy.public => 'Anyone on Vibely can watch',
    VideoPrivacy.friends => 'Only your friends can watch',
    VideoPrivacy.private => 'Only you can watch',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: selected
          ? context.colors.primaryContainer
          : context.colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(_icon),
        title: Text(option.label),
        subtitle: Text(_subtitle),
        trailing: selected ? const Icon(Icons.check_circle_rounded) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
