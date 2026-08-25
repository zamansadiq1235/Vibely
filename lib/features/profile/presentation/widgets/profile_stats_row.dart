import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.following,
    required this.followers,
    required this.likes,
    required this.friends,
    this.onTapFollowing,
    this.onTapFollowers,
    this.onTapFriends,
  });

  final int following;
  final int followers;
  final int likes;
  final int friends;
  final VoidCallback? onTapFollowing;
  final VoidCallback? onTapFollowers;
  final VoidCallback? onTapFriends;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(label: 'Following', value: following, onTap: onTapFollowing),
        _Stat(label: 'Followers', value: followers, onTap: onTapFollowers),
        _Stat(label: 'Likes', value: likes),
        _Stat(label: 'Friends', value: friends, onTap: onTapFriends),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Text(_formatCount(value), style: context.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(label, style: context.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}
