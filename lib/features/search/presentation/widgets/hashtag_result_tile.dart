import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../domain/entities/hashtag_result.dart';

class HashtagResultTile extends StatelessWidget {
  const HashtagResultTile({
    super.key,
    required this.hashtag,
    required this.onTap,
  });

  final HashtagResult hashtag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: context.colors.surfaceContainerHighest,
        child: const Icon(Icons.tag_rounded),
      ),
      title: Text('#${hashtag.tag}'),
      subtitle: Text('${hashtag.usageCount} videos'),
    );
  }
}
