// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/feed/presentation/screens/home_feed_screen.dart';
import '../../features/follows/presentation/screens/followers_screen.dart';
import '../../features/follows/presentation/screens/following_screen.dart';
import '../../features/friends/presentation/screens/friend_requests_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reposts/presentation/screens/reposted_videos_screen.dart';
import '../../features/saved_videos/presentation/screens/saved_videos_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/legal_document_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/upload/presentation/screens/create_video_screen.dart';
import 'main_shell.dart';
import 'route_names.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier<int>(0);

  // Notify GoRouter to re-evaluate redirects whenever auth state updates
  ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (_, __) {
    refreshListenable.value++;
  });

  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loggingIn = _isAuthRoute(state.matchedLocation);
      final onSplash = state.matchedLocation == RouteNames.splash;

      // Still resolving session or initial auth load -> stay on Splash
      if (authState.isLoading && !authState.hasValue) {
        return onSplash ? null : RouteNames.splash;
      }

      final status = authState.asData?.value.status;

      switch (status) {
        case null:
          return onSplash ? null : RouteNames.splash;
        case AuthStatus.unauthenticated:
          return loggingIn ? null : RouteNames.login;
        case AuthStatus.needsProfileCompletion:
        case AuthStatus.authenticated:
          final onAuthOrSplash =
              loggingIn ||
              onSplash ||
              state.matchedLocation == RouteNames.completeProfile;
          return onAuthOrSplash ? RouteNames.home : null;
      }
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.completeProfile,
        builder: (context, state) => const CompleteProfileScreen(),
      ),

      // ---------- Bottom-nav shell ----------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                builder: (context, state) => const HomeFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) => const CreateVideoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.notifications,
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---------- Top-level pushes ----------
      GoRoute(
        path: RouteNames.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.userProfile,
        builder: (context, state) =>
            ProfileScreen(userId: state.pathParameters['userId']),
      ),
      GoRoute(
        path: RouteNames.followers,
        builder: (context, state) =>
            FollowersScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: RouteNames.following,
        builder: (context, state) =>
            FollowingScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: RouteNames.friends,
        builder: (context, state) =>
            FriendsScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: RouteNames.friendRequests,
        builder: (context, state) => const FriendRequestsScreen(),
      ),
      GoRoute(
        path: RouteNames.savedVideos,
        builder: (context, state) => const SavedVideosScreen(),
      ),
      GoRoute(
        path: RouteNames.repostedVideos,
        builder: (context, state) =>
            RepostedVideosScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.terms,
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.privacy),
      ),
    ],
  );
});

bool _isAuthRoute(String location) {
  return location == RouteNames.login ||
      location == RouteNames.signup ||
      location == RouteNames.forgotPassword;
}
