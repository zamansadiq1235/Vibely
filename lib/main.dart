// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads SUPABASE_URL / SUPABASE_ANON_KEY from .env (gitignored).
  // See .env.example for the required keys. Never commit the real .env
  // or the service-role key — the service-role key must never appear
  // in the Flutter app at all.
  await dotenv.load(fileName: '.env');

  if (!SupabaseConstants.isConfigured) {
    // Fail loudly in debug rather than silently hitting an empty URL.
    debugPrint(
      'Vibely: SUPABASE_URL / SUPABASE_ANON_KEY are missing. '
      'Copy .env.example to .env and fill in your project values.',
    );
  }

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  runApp(const ProviderScope(child: VibelyApp()));
}

class VibelyApp extends ConsumerWidget {
  const VibelyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
