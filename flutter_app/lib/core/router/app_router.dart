import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kita_english/core/storage/secure_storage.dart';
import 'package:kita_english/features/auth/presentation/screens/link_account_screen.dart';
import 'package:kita_english/features/day7/presentation/screens/certificate_screen.dart';
import 'package:kita_english/features/day7/presentation/screens/showcase_recording_screen.dart';
import 'package:kita_english/features/onboarding/presentation/screens/character_select_screen.dart';
import 'package:kita_english/features/onboarding/presentation/screens/parent_gate_screen.dart';
import 'package:kita_english/features/onboarding/presentation/screens/placement_test_screen.dart';
import 'package:kita_english/features/progress/presentation/screens/progress_dashboard_screen.dart';
import 'package:kita_english/features/session/presentation/screens/session_complete_screen.dart';
import 'package:kita_english/features/session/presentation/screens/session_home_screen.dart';
import 'package:kita_english/features/session/presentation/widgets/activity_shell.dart';

/// Route path constants.
class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String onboardingParent = '/onboarding/parent';
  static const String onboardingCharacter = '/onboarding/character';
  static const String onboardingPlacement = '/onboarding/placement';
  static const String home = '/home';
  static const String session = '/session/:day';
  static const String sessionComplete = '/session/:day/complete';
  static const String day7Record = '/day7/record';
  static const String day7Certificate = '/day7/certificate';
  static const String progress = '/progress';
  static const String accountLink = '/account/link';
}

/// Provides the configured [GoRouter] instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  final secureStorage = ref.read(secureStorageProvider);

  return GoRouter(
    initialLocation: RoutePaths.onboardingParent,
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final currentPath = state.matchedLocation;

      try {
        final hasKidProfile =
            (await secureStorage.readKidProfileId()) != null;

        // Has kid profile — go to home (skip onboarding)
        if (hasKidProfile) {
          if (currentPath == RoutePaths.splash ||
              currentPath == RoutePaths.onboardingParent ||
              currentPath == RoutePaths.onboardingCharacter ||
              currentPath == RoutePaths.onboardingPlacement ||
              currentPath == RoutePaths.login ||
              currentPath == RoutePaths.signup) {
            return RoutePaths.home;
          }
        }
      } catch (_) {
        // Storage error — stay on current page
      }

      return null;
    },
    routes: [
      // Splash — redirect to onboarding
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const ParentGateScreen(),
      ),

      // Auth
      GoRoute(
        path: RoutePaths.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ParentGateScreen(), // Login disabled — go to onboarding
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: RoutePaths.signup,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ParentGateScreen(), // Signup disabled — go to onboarding
          transitionsBuilder: _slideTransition,
        ),
      ),

      // Onboarding
      GoRoute(
        path: RoutePaths.onboardingParent,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ParentGateScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: RoutePaths.onboardingCharacter,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CharacterSelectScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: RoutePaths.onboardingPlacement,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PlacementTestScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),

      // Main — Challenge Home
      GoRoute(
        path: RoutePaths.home,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SessionHomeScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),

      // Session — shows the activity shell for the day's activities
      GoRoute(
        path: RoutePaths.session,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const ActivityShell(),
            transitionsBuilder: _slideTransition,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.sessionComplete,
        pageBuilder: (context, state) {
          final day = int.tryParse(state.pathParameters['day'] ?? '') ?? 1;
          return CustomTransitionPage(
            key: state.pageKey,
            child: SessionCompleteScreen(dayNumber: day),
            transitionsBuilder: _scaleTransition,
          );
        },
      ),

      // Day 7
      GoRoute(
        path: RoutePaths.day7Record,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ShowcaseRecordingScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: RoutePaths.day7Certificate,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CertificateScreen(),
          transitionsBuilder: _scaleTransition,
        ),
      ),

      // Account link
      GoRoute(
        path: RoutePaths.accountLink,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LinkAccountScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),

      // Progress
      GoRoute(
        path: RoutePaths.progress,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProgressDashboardScreen(),
          transitionsBuilder: _slideTransition,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Ôi! Trang này không tìm thấy.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.home),
              child: const Text('Về trang chính'),
            ),
          ],
        ),
      ),
    ),
  );
});

// --- Transition Helpers ---

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(opacity: animation, child: child);
}

Widget _slideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  );
}

Widget _scaleTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return ScaleTransition(
    scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
    child: FadeTransition(opacity: animation, child: child),
  );
}

