import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Purely a loading/branding screen. The actual "check session -> check
/// profile completeness -> redirect" logic lives in the router's
/// `redirect` callback (core/router/app_router.dart), driven by
/// authNotifierProvider (Phase 3). This screen just needs to render
/// while that resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_fill_rounded,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(AppConstants.appName, style: theme.textTheme.displayLarge),
            const SizedBox(height: 8),
            Text(AppConstants.appTagline, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
