// ignore_for_file: use_null_aware_elements

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';

/// Talks to Supabase Auth + the `profiles` table directly. Every method
/// catches Supabase's own exception types and rethrows a single
/// AppException so the repository/notifier layers never need to know
/// about AuthException / PostgrestException.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  // Must match a URL scheme registered for deep linking on both platforms
  // (see README "OAuth setup" section added in this phase).
  static const _oauthRedirect = 'io.vibely.app://login-callback/';

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    try {
      // Uniqueness is enforced by the `profiles.username` UNIQUE
      // constraint (migration 0001) + the handle_new_user trigger
      // (migration 0002), which reads these values from user metadata.
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'full_name': fullName},
      );
      if (response.user == null) {
        throw AppException.unknown(
          'Could not create your account. Please try again.',
        );
      }
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e), code: e.code);
    } catch (_) {
      throw AppException.network();
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null || response.user == null) {
        throw AppException.unknown(
          'Could not start a session. Please verify your email and try again.',
        );
      }
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e), code: e.code);
    } catch (_) {
      throw AppException.network();
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (_) {
      throw AppException.unknown('Google sign-in failed. Please try again.');
    }
  }

  Future<void> signInWithFacebook() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: _oauthRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (_) {
      throw AppException.unknown('Facebook sign-in failed. Please try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      throw AppException.unknown('Sign out failed. Please try again.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e), code: e.code);
    } catch (_) {
      throw AppException.network();
    }
  }

  Future<void> resendEmailVerification(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e), code: e.code);
    } catch (_) {
      throw AppException.network();
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentProfileRow() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      return await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
    } on PostgrestException catch (_) {
      throw AppException.unknown('Could not load your profile.');
    } catch (_) {
      throw AppException.network();
    }
  }

  Future<void> completeProfile({
    required String fullName,
    required String bio,
    String? avatarPath,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw AppException.unauthorized();
    try {
      await _client
          .from('profiles')
          .update({
            'full_name': fullName,
            'bio': bio,
            if (avatarPath != null) 'avatar_path': avatarPath,
          })
          .eq('id', uid);
    } on PostgrestException catch (_) {
      throw AppException.unknown('Could not update your profile.');
    } catch (_) {
      throw AppException.network();
    }
  }

  String _mapAuthError(AuthException e) {
    // Supabase's raw messages are fine for most cases, but a couple of
    // common ones read better reworded for end users.
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    return e.message;
  }
}
