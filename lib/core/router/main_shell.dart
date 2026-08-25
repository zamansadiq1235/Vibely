import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/providers/notifications_provider.dart';

/// Wraps the 5 bottom-nav destinations (spec §6) using go_router's
/// StatefulShellRoute so each tab keeps its own navigation stack and
/// scroll/scroll-position state when switching away and back — notably
/// important for Home, where losing the feed's scroll position on every
/// tab switch would be a jarring regression.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _labels = ['Home', 'Search', 'Create', 'Alerts', 'Profile'];
  static const _icons = [
    Icons.home_rounded,
    Icons.search_rounded,
    Icons.add_box_rounded, // unused directly — Create gets a custom tile
    Icons.notifications_rounded,
    Icons.person_rounded,
  ];
  static const _outlineIcons = [
    Icons.home_outlined,
    Icons.search_outlined,
    Icons.add_box_outlined,
    Icons.notifications_outlined,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentIndex = navigationShell.currentIndex;
    // Watching here (rather than only inside NotificationsScreen) is what
    // keeps a live unread badge on the tab even while the user is off on
    // Home/Search/etc — the Realtime subscription set up inside
    // notificationsProvider starts as soon as this is first read.
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        color: theme.bottomNavigationBarTheme.backgroundColor,
        child: SizedBox(
          height: 50,
          child: Row(
            children: List.generate(_labels.length, (index) {
              // Create (index 2) is visually prominent per spec §6
              // rather than a plain nav icon.
              if (index == 2) {
                return Expanded(child: _CreateTab(onTap: () => _onTap(index)));
              }
              final selected = index == currentIndex;
              return Expanded(
                child: _NavTab(
                  icon: selected ? _icons[index] : _outlineIcons[index],
                  label: _labels[index],
                  selected: selected,
                  badgeCount: index == 3 ? unreadCount : 0,
                  onTap: () => _onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the already-active tab pops it back to its root, matching
      // standard bottom-nav behavior (e.g. re-tapping Home scrolls/pops
      // to the top of the feed instead of doing nothing).
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.bottomNavigationBarTheme.selectedItemColor
        : theme.bottomNavigationBarTheme.unselectedItemColor;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 24),
              if (badgeCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

class _CreateTab extends StatelessWidget {
  const _CreateTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.secondary],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
