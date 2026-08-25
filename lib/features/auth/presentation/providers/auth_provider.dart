// ignore_for_file: unnecessary_underscores

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_profile.dart';
import '../../domain/repositories/auth_repository.dart';

// ---------- Dependency injection ----------

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

// ---------- Auth state ----------

/// The four states the router's redirect logic (Phase 1 §flow diagram)
/// switches on: Splash -> unauthenticated -> Login, or authenticated ->
/// profile incomplete -> Complete Profile, or complete -> Home.
enum AuthStatus { unauthenticated, needsProfileCompletion, authenticated }

class AuthState {
  const AuthState({required this.status, this.profile, this.failure});

  final AuthStatus status;
  final AppProfile? profile;
  final Failure? failure;

  static const loading = AuthState(status: AuthStatus.unauthenticated);
}

/// Watches Supabase's auth stream and, whenever the session changes,
/// re-fetches the profile to determine completeness. Screens should
/// prefer this over reading Supabase.auth directly so profile
/// completeness stays in one place.
class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Re-run whenever Supabase reports a sign-in/sign-out/token refresh.
    ref.listen(authStateChangesProvider, (_, __) {
      ref.invalidateSelf();
    });
    return _resolveState();
  }

  Future<AuthState> _resolveState() async {
    final repo = ref.read(authRepositoryProvider);
    if (repo.currentUserId == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    final profile = await repo.fetchCurrentProfile();
    if (profile == null || !profile.isComplete) {
      return AuthState(
        status: AuthStatus.needsProfileCompletion,
        profile: profile,
      );
    }
    return AuthState(status: AuthStatus.authenticated, profile: profile);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .signUpWithEmail(
            email: email,
            password: password,
            username: username,
            fullName: fullName,
          );
      return _resolveState();
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password);
      return _resolveState();
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      return _resolveState();
    });
  }

  Future<void> signInWithFacebook() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithFacebook();
      return _resolveState();
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return _resolveState();
    });
  }

  Future<void> sendPasswordResetEmail(String email) {
    return ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
  }

  Future<void> resendEmailVerification(String email) {
    return ref.read(authRepositoryProvider).resendEmailVerification(email);
  }

  Future<void> completeProfile({
    required String fullName,
    required String bio,
    String? avatarPath,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .completeProfile(
            fullName: fullName,
            bio: bio,
            avatarPath: avatarPath,
          );
      return _resolveState();
    });
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
