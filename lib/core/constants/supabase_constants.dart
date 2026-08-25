import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads Supabase connection details from the .env file at runtime.
///
/// Never hardcode the anon key or URL here, and never reference the
/// service-role key from the Flutter app at all — it must only ever
/// live server-side (Edge Functions / your own backend).
class SupabaseConstants {
  SupabaseConstants._();

  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
