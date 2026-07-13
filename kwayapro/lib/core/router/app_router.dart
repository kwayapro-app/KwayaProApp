import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/enums.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/choir/presentation/home_screen.dart';
import '../../features/choir/presentation/members_screen.dart';
import '../../features/auth/domain/auth_providers.dart';
import '../../features/choir/domain/choir_providers.dart';
import '../../features/choir/presentation/member_detail_screen.dart';
import '../../features/choir/presentation/choir_profile_screen.dart';
import '../../features/choir/data/choir_repository.dart';
import '../../features/songs/presentation/library_screen.dart';
import '../../features/rehearsal/presentation/rehearsals_screen.dart';
import '../../features/rehearsal/presentation/guest_director_screen.dart';
import '../../features/rehearsal/data/rehearsal_repository.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/studio/presentation/studio_screen.dart';
import '../../features/subscription/presentation/billing_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/planner/presentation/planner_screen.dart' show PlannerScreen, ProgramEditorScreen;
import 'navigation_shell_screen.dart';

// Phase 5 Fix 1: previously routerProvider was a plain Provider<GoRouter>
// that `ref.watch`ed authStateProvider/userChoirsProvider/currentUserProvider
// directly — meaning Riverpod discarded and rebuilt the ENTIRE GoRouter
// instance (and therefore MaterialApp.router's routerConfig) on every single
// emission from any of those three streams, not just sign-in/out. Since
// StatefulShellRoute's tab state (scroll position, nested navigator stacks)
// lives inside the GoRouter/Navigator tree, discarding the router discards
// that state too — e.g. a Firestore snapshot update to the user doc while
// someone is scrolled deep into a tab would silently reset it.
//
// Fixed per go_router's documented refreshListenable pattern
// (pub.dev/documentation/go_router — GoRouter(refreshListenable: Listenable?)):
// construct GoRouter exactly once, and instead pass a stable ChangeNotifier
// that calls notifyListeners() when the underlying auth/choir state changes.
// go_router re-runs `redirect` on every notifyListeners() call without
// discarding the router or its navigator state.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(userChoirsProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  // Only dependency routerProvider itself watches — the notifier's identity
  // never changes across its lifetime, so this build only ever runs once.
  final refreshNotifier = ref.watch(_routerRefreshProvider);

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
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // redirect is re-invoked on every navigation AND every
      // refreshListenable notification — read the latest provider values
      // fresh each time rather than closing over stale ones.
      final authState = ref.read(authStateProvider);
      final userChoirs = ref.read(userChoirsProvider);
      final currentUser = ref.read(currentUserProvider);

      final isAuth = authState.value != null;
      final isOnboarding = state.uri.path.startsWith('/onboarding');

      final isGoingToJoin = state.uri.path.startsWith('/join');
      final isGoingToRehearsalInvite = state.uri.path.startsWith('/rehearsal-invite');

      if (isGoingToJoin || isGoingToRehearsalInvite) return null;

      if (!isAuth && !isOnboarding) return '/onboarding';

      // Only redirect away from onboarding if the user has explicitly
      // completed step 5 (the onboardingComplete flag is set in Firestore).
      if (isAuth && isOnboarding) {
        final choirs = userChoirs.value;
        final user = currentUser.value;
        // Still loading data — let them stay
        if (choirs == null || user == null) return null;
        // Onboarding complete — send to home
        if (user.onboardingComplete) return '/home';
        // Mid-onboarding — let them finish
        return null;
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
        builder: (context, state) {
          final extra = state.extra;
          StudioContext? ctx;
          if (extra != null && extra is Map) {
            ctx = StudioContext(
              songId: extra['songId'] as String? ?? '',
              songTitle: extra['songTitle'] as String? ?? '',
              sectionId: extra['sectionId'] as String? ?? '',
              sectionTitle: extra['sectionTitle'] as String? ?? '',
              voicePart: VoicePart.values.firstWhere(
                (v) => v.name == (extra['voicePart'] as String? ?? 'A'),
                orElse: () => VoicePart.A,
              ),
            );
          }
          return StudioScreen(context: ctx);
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/choir-profile',
        builder: (context, state) => const ChoirProfileScreen(),
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
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ProgramEditorScreen(),
          ),
          GoRoute(
            path: ':programId',
            builder: (context, state) {
              final programId = state.pathParameters['programId'] ?? '';
              return ProgramEditorScreen(programId: programId);
            },
          ),
        ],
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
          return _JoinChoirScreen(inviteCode: inviteCode);
        },
      ),
      GoRoute(
        path: '/rehearsal-invite/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return _RehearsalInviteScreen(token: token);
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

// ── Deep Link Screens ──────────────────────────────────────────────

class _JoinChoirScreen extends ConsumerStatefulWidget {
  final String inviteCode;
  const _JoinChoirScreen({required this.inviteCode});

  @override
  ConsumerState<_JoinChoirScreen> createState() => _JoinChoirScreenState();
}

class _JoinChoirScreenState extends ConsumerState<_JoinChoirScreen> {
  bool _isJoining = false;
  String? _error;
  String? _choirName;
  String? _churchName;

  @override
  void initState() {
    super.initState();
    _lookupChoir();
  }

  Future<void> _lookupChoir() async {
    final repo = ChoirRepository();
    final choir = await repo.findByInviteCode(widget.inviteCode);
    if (choir != null && mounted) {
      setState(() {
        _choirName = choir.name;
        _churchName = choir.churchName;
      });
    } else if (mounted) {
      setState(() => _error = 'Invalid or expired invite code.');
    }
  }

  Future<void> _joinChoir() async {
    setState(() { _isJoining = true; _error = null; });
    try {
      final authState = ref.read(authStateProvider);
      final user = authState.value;
      if (user == null) {
        if (mounted) context.pushReplacement('/onboarding');
        return;
      }
      final repo = ChoirRepository();
      final choir = await repo.findByInviteCode(widget.inviteCode);
      if (choir == null) throw Exception('Choir not found');
      final membership = await repo.getMembership(choir.choirId, user.uid);
      if (membership != null) {
        ref.read(activeChoirIdProvider.notifier).setChoir(choir.choirId);
        if (mounted) context.pushReplacement('/home');
        return;
      }
      if (mounted) {
        final voicePart = await showModalBottomSheet<VoicePart>(
          context: context,
          builder: (ctx) => _VoicePartPickerSheet(),
        );
        if (voicePart == null) { setState(() => _isJoining = false); return; }
        await repo.joinChoir(choir.choirId, user.uid, voicePart);
        ref.read(activeChoirIdProvider.notifier).setChoir(choir.choirId);
        if (mounted) context.pushReplacement('/home');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to join choir: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Join Choir')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                )
              else if (_choirName == null)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    Icon(Icons.music_note, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Join', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(_choirName!, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    if (_churchName != null) Text(_churchName!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isJoining ? null : _joinChoir,
                      icon: _isJoining ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add),
                      label: Text(_isJoining ? 'Joining...' : 'Join This Choir'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoicePartPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Your Voice Part', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ...VoicePart.values.map((part) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, part),
                  child: Text(part.displayName),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _RehearsalInviteScreen extends ConsumerStatefulWidget {
  final String token;
  const _RehearsalInviteScreen({required this.token});

  @override
  ConsumerState<_RehearsalInviteScreen> createState() => _RehearsalInviteScreenState();
}

class _RehearsalInviteScreenState extends ConsumerState<_RehearsalInviteScreen> {
  bool _isValidating = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  Future<void> _validateToken() async {
    try {
      final authState = ref.read(authStateProvider);
      final user = authState.value;
      if (user == null) {
        if (mounted) context.pushReplacement('/onboarding');
        return;
      }
      // Token validation, expiry enforcement, and the membership grant all
      // now happen server-side in the joinAsGuestDirector Cloud Function —
      // see PHASE_2B_REPORT.md. The client can no longer read
      // rehearsal_sessions by guestToken directly (it isn't a tenant member
      // yet), so this single call replaces the old
      // validateGuestToken + getSessionByToken + addGuestDirector sequence.
      final repo = RehearsalRepository();
      final result = await repo.joinAsGuestDirector(widget.token);
      ref.read(activeChoirIdProvider.notifier).setChoir(result.choirId);
      if (mounted) setState(() { _isValidating = false; });
    } on GuestJoinException catch (e) {
      if (mounted) setState(() { _isValidating = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _isValidating = false; _error = 'Something went wrong. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rehearsal Invite')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isValidating)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Validating your invite link...'),
                  ],
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                )
              else
                Column(
                  children: [
                    const Icon(Icons.check_circle, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    Text('You\'re in!', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('You have guest director access for this rehearsal.'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.pushReplacement('/home/rehearsals'),
                      icon: const Icon(Icons.event),
                      label: const Text('Go to Rehearsals'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
