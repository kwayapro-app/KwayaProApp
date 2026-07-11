import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kwayapro/core/router/app_router.dart';
import 'package:kwayapro/features/auth/domain/auth_providers.dart';
import 'package:kwayapro/features/auth/domain/models/app_user.dart';
import 'package:kwayapro/features/choir/domain/choir_providers.dart';

// Phase 5 Fix 1: previously routerProvider was a plain Provider<GoRouter>
// that `ref.watch`ed authStateProvider/userChoirsProvider/currentUserProvider
// directly, so Riverpod discarded and rebuilt the ENTIRE GoRouter instance
// on every single emission from any of those three streams — not just
// sign-in/out. Since StatefulShellRoute's tab state (scroll position,
// nested navigator stacks) lives inside the GoRouter/Navigator tree,
// discarding the router discarded that state too.
//
// A full widget-level "navigate deep into a tab, trigger an emission,
// confirm scroll position survives" integration test would require mocking
// Firebase Auth's User type, Firestore choir/membership reads, and driving
// StatefulShellRoute navigation end-to-end — a much heavier harness for a
// question that has a direct, provable root-cause test: does routerProvider
// still hand back the SAME GoRouter instance after the watched streams
// emit? If it does, by construction the Navigator/StatefulShellRoute tree
// underneath it is never torn down, so tab state cannot be lost this way
// (Flutter only discards subtree state when the widget identity/config
// changes, and routerConfig identity not changing is exactly what prevents
// that). This is the direct, provable test for the fix; the widget-level
// consequence follows from it rather than needing separate re-proof.
void main() {
  test('routerProvider returns the SAME GoRouter instance across auth/choir/user emissions', () async {
    final authController = StreamController<User?>();
    final choirsController = StreamController<List<ChoirWithMembership>>();
    final userController = StreamController<AppUser?>();

    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => authController.stream),
        userChoirsProvider.overrideWith((ref) => choirsController.stream),
        currentUserProvider.overrideWith((ref) => userController.stream),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authController.close);
    addTearDown(choirsController.close);
    addTearDown(userController.close);

    final routerBefore = container.read(routerProvider);
    expect(routerBefore, isA<GoRouter>());

    // Emit on all three streams the old implementation used to `watch`
    // directly — under the old Provider<GoRouter> pattern, each of these
    // would have rebuilt the router from scratch.
    authController.add(null);
    choirsController.add(const []);
    userController.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final routerAfter = container.read(routerProvider);

    expect(
      identical(routerBefore, routerAfter),
      isTrue,
      reason: 'routerProvider must hand back the exact same GoRouter instance — '
          'rebuilding it on every auth/choir stream emission is the bug this fix closes.',
    );
  });

  test('routerProvider still rebuilds if the app is fully torn down and re-created (sanity check)', () async {
    final authController1 = StreamController<User?>();
    final container1 = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => authController1.stream),
        userChoirsProvider.overrideWith((ref) => Stream.value(const [])),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final routerA = container1.read(routerProvider);
    container1.dispose();
    await authController1.close();

    final authController2 = StreamController<User?>();
    final container2 = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => authController2.stream),
        userChoirsProvider.overrideWith((ref) => Stream.value(const [])),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container2.dispose);
    addTearDown(authController2.close);
    final routerB = container2.read(routerProvider);

    // Different containers are genuinely independent app instances — this
    // is not the same class of "unnecessary rebuild" the fix targets.
    expect(identical(routerA, routerB), isFalse);
  });
}
