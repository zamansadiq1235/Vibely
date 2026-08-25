import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the singleton Supabase client through Riverpod so every
/// feature's data source depends on this provider instead of calling
/// `Supabase.instance.client` directly — keeps data sources testable
/// (the provider can be overridden with a mock client in tests).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Streams auth state changes (sign in / sign out / token refresh).
/// Phase 3's authProvider builds on top of this stream.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});
