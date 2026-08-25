import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use Clipzo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !mounted) return;

    setState(() => _isSigningOut = true);
    await ref.read(authNotifierProvider.notifier).signOut();
    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    if (authState.hasError) {
      context.showSnack('Unable to log out. Please try again.', isError: true);
      setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Account settings',
                subtitle: 'Manage your profile and account details',
                onTap: () => context.push(RouteNames.editProfile),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Legal',
            children: [
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                onTap: () => context.push(RouteNames.terms),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => context.push(RouteNames.privacyPolicy),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Session',
            children: [
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: _isSigningOut ? 'Logging out…' : 'Log out',
                iconColor: colors.error,
                textColor: colors.error,
                showChevron: false,
                trailing: _isSigningOut
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.error,
                        ),
                      )
                    : null,
                onTap: _isSigningOut ? null : _confirmSignOut,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.textColor,
    this.trailing,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? colors.primary),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (showChevron
              ? Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                )
              : null),
      onTap: onTap,
    );
  }
}
