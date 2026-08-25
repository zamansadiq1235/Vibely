import '../entities/app_profile.dart';

/// Domain-layer contract. Presentation code (providers/screens) depends
/// on this interface, never on supabase_flutter types directly — keeps
/// the auth backend swappable and the notifiers unit-testable with a
/// fake implementation.
abstract class AuthRepository {
  /// Null when signed out.
  String? get currentUserId;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String fullName,
  });

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> signInWithFacebook();

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> resendEmailVerification(String email);

  Future<AppProfile?> fetchCurrentProfile();

  Future<void> completeProfile({
    required String fullName,
    required String bio,
    String? avatarPath,
  });
}
