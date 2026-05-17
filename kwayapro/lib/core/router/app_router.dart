import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/choir/presentation/home_screen.dart';
import '../../features/choir/presentation/members_screen.dart';
import '../../features/choir/presentation/member_detail_screen.dart';
import '../../features/songs/presentation/library_screen.dart';
import '../../features/rehearsal/presentation/rehearsals_screen.dart';
import '../../features/rehearsal/presentation/guest_director_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/studio/presentation/studio_screen.dart';
import '../../features/subscription/presentation/billing_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/planner/presentation/planner_screen.dart';
import 'navigation_shell_screen.dart';

// Dummy provider for auth state (returns false by default to show onboarding)
final authStateProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(authStateProvider);

  // Shell transition helper for shared axis
  CustomTransitionPage<T> buildSharedAxisPage<T>({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        );
      },
    );
  }

  return GoRouter(
    initialLocation: '/onboarding',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final isGoingToJoin = state.matchedLocation.startsWith('/join');
      final isGoingToRehearsalInvite = state.matchedLocation.startsWith('/rehearsal-invite');

      // Allow public onboarding or invite deep links bypass auth redirect
      if (isGoingToJoin || isGoingToRehearsalInvite) {
        return null;
      }

      if (!isAuthenticated && !isGoingToOnboarding) {
        return '/onboarding';
      }

      if (isAuthenticated && isGoingToOnboarding) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Public Onboarding route
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Immersive/Deep-link screens without shell navigation
      GoRoute(
        path: '/studio',
        builder: (context, state) => const StudioScreen(),
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/attendance/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return AttendanceScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/planner',
        builder: (context, state) => const PlannerScreen(),
      ),
      GoRoute(
        path: '/members',
        builder: (context, state) => const MembersScreen(),
        routes: [
          GoRoute(
            path: ':userId',
            builder: (context, state) {
              final userId = state.pathParameters['userId'] ?? '';
              return MemberDetailScreen(userId: userId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/guest-director/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return GuestDirectorScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/join/:inviteCode',
        builder: (context, state) {
          final inviteCode = state.pathParameters['inviteCode'] ?? '';
          return Scaffold(
            body: Center(child: Text('Auto-join flow for Choir: $inviteCode')),
          );
        },
      ),
      GoRoute(
        path: '/rehearsal-invite/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return Scaffold(
            body: Center(child: Text('Guest Rehearsal Access via Invite token: $token')),
          );
        },
      ),

      // Bottom Tab Shell Routes
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => buildSharedAxisPage(
                  state: state,
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/library',
                pageBuilder: (context, state) => buildSharedAxisPage(
                  state: state,
                  child: const LibraryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/rehearsals',
                pageBuilder: (context, state) => buildSharedAxisPage(
                  state: state,
                  child: const RehearsalsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/chat',
                pageBuilder: (context, state) => buildSharedAxisPage(
                  state: state,
                  child: const ChatScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
