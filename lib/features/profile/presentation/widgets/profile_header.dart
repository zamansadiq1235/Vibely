import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../auth/domain/entities/app_profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile, this.avatarUrl});

  final AppProfile profile;

  /// Resolved public URL for profile.avatarPath — resolving storage
  /// paths to URLs is left to the caller so this widget stays a pure
  /// display component.
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: context.colors.surfaceContainerHighest,
          backgroundImage: avatarUrl != null
              ? CachedNetworkImageProvider(avatarUrl!)
              : null,
          child: avatarUrl == null
              ? Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: context.colors.onSurfaceVariant,
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          profile.fullName.isNotEmpty
              ? profile.fullName
              : '@${profile.username}',
          style: context.textTheme.headlineMedium,
        ),
        const SizedBox(height: 2),
        Text('@${profile.username}', style: context.textTheme.labelSmall),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              profile.bio,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}
