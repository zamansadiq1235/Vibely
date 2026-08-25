import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../feed/domain/entities/video_post.dart';
import '../providers/share_provider.dart';

class ShareOptionsSheet extends ConsumerWidget {
  const ShareOptionsSheet({super.key, required this.post});

  final VideoPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Share via...'),
            onTap: () async {
              final actions = ref.read(shareActionsProvider);
              Navigator.of(context).pop();
              await actions.shareNatively(post);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Copy link'),
            onTap: () async {
              final actions = ref.read(shareActionsProvider);
              Navigator.of(context).pop();
              await actions.copyLink(post);
              if (context.mounted) context.showSnack('Link copied');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
