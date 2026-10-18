import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/brief/presentation/brief_screen.dart';
import '../../features/copilot/presentation/copilot_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/learn/presentation/glossary_screen.dart';
import '../../features/learn/presentation/term_screen.dart';
import '../../features/market/presentation/asset_screen.dart';
import '../../features/market/presentation/search_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

/// Only for signed-out users; signed-in users are sent home.
const _guestOnly = {'/login', '/register', '/forgot-password'};

/// Reachable signed in or out (opened from email links).
const _emailLinks = {'/verify-email', '/reset-password'};

/// Pure redirect rules, kept separate so they are easy to test.
String? authRedirect(AuthState auth, Uri uri) {
  final path = uri.path;
  if (_emailLinks.contains(path)) return null;

  switch (auth.status) {
    case AuthStatus.unknown:
      return path == '/splash'
          ? null
          : '/splash?from=${Uri.encodeComponent(uri.toString())}';
    case AuthStatus.unauthenticated:
      if (_guestOnly.contains(path)) return null;
      final from = path == '/' || path == '/splash' || auth.signedOutByUser
          ? null
          : uri.toString();
      return from == null
          ? '/login'
          : '/login?from=${Uri.encodeComponent(from)}';
    case AuthStatus.authenticated:
      final onboarded = auth.user!.onboardingCompleted;
      if (!onboarded) return path == '/onboarding' ? null : '/onboarding';
      if (_guestOnly.contains(path) || path == '/splash') {
        final from = uri.queryParameters['from'];
        return from != null && from.startsWith('/') && !from.startsWith('//')
            ? from
            : '/';
      }
      return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => authState.value = next);
  ref.onDispose(authState.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (context, state) => authRedirect(authState.value, state.uri),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        // Nested so /profile opens on top of home and gets a back button.
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'brief',
            builder: (context, state) => const BriefScreen(),
          ),
          GoRoute(
            path: 'copilot',
            builder: (context, state) => CopilotScreen(
              assetId: int.tryParse(state.uri.queryParameters['asset'] ?? ''),
            ),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'alerts',
            builder: (context, state) => const AlertsScreen(),
          ),
          GoRoute(
            path: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: 'learn',
            builder: (context, state) => const GlossaryScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    TermScreen(termId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'assets/:id',
            builder: (context, state) =>
                // A malformed id falls through to the API's friendly "not found".
                AssetScreen(
                  assetId: int.tryParse(state.pathParameters['id']!) ?? 0,
                ),
          ),
        ],
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingScreen(editing: state.uri.queryParameters['edit'] == '1'),
      ),
    ],
  );
});
