import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/firebase/firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/state_logger.dart';
import 'core/firebase/fcm_handler.dart';
import 'shared/providers/shared_prefs_provider.dart';
import 'shared/services/audio_cache_service.dart';
import 'features/auth/data/auth_repository.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await handleFCMBackgroundMessage(message);
}

// Phase 5 Fix 6: the init sequence previously ran entirely sequentially and
// synchronously before runApp() — Hive.initFlutter(), Firebase.initializeApp(),
// SharedPreferences.getInstance(), AudioCacheService().init(), and (worst)
// an awaited initFCM() that shows a native OS permission prompt on iOS,
// stalling first frame indefinitely until the user responds. See
// PRODUCTION_READINESS_AUDIT.md §5 and PHASE_5_REPORT.md.
//
// Fixed by: only awaiting what the FIRST FRAME actually needs before
// runApp() (Firebase — almost everything reads FirebaseAuth/Firestore
// immediately — and SharedPreferences, which sharedPrefsProvider's override
// needs synchronously), running those two in parallel since they're
// independent, and deferring everything else (FCM permission request, the
// Hive-backed audio cache, FCM token registration) to fire-and-forget after
// runApp(). The one exception is FirebaseMessaging.onBackgroundMessage
// registration, which Firebase's own docs require to happen before
// runApp() to reliably catch background messages — that stays pre-runApp,
// but it's synchronous (no await, no user-facing prompt) so it doesn't
// block anything.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase and SharedPreferences are independent of each other — run
  // them concurrently rather than one-after-another.
  final prefsFuture = SharedPreferences.getInstance();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Phase 7: was CACHE_SIZE_UNLIMITED (flagged HYGIENE in
    // PRODUCTION_READINESS_AUDIT.md §4) — bounded to a fixed ceiling so
    // long-lived installs don't accumulate unbounded local Firestore cache.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024,
    );
    AppLogger.info('Firebase initialized successfully.');
  } catch (e, stackTrace) {
    AppLogger.error(
      'Failed to initialize Firebase. Using local placeholder modes.',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Must be registered before runApp() per Firebase's own guidance, but is
  // synchronous and shows no UI, so it costs nothing here.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final prefs = await prefsFuture;

  AppLogger.info('Starting KwayaPro App...');

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      observers: const [
        StateLogger(),
      ],
      child: const KwayaProApp(),
    ),
  );

  // Everything below is deferred until after first frame — none of it is
  // needed to render the app's initial UI.
  unawaited(_runDeferredStartupTasks());
}

Future<void> _runDeferredStartupTasks() async {
  // Hive/AudioCacheService: confirmed unused elsewhere in the app today
  // (nothing calls getCachedPath/cacheAudio — see PHASE_2B_REPORT.md /
  // PRODUCTION_READINESS_AUDIT.md), so this previously cost cold-start time
  // for zero benefit. Deferred entirely rather than removed, in case a
  // future feature wires it up.
  try {
    await Hive.initFlutter();
    await AudioCacheService().init();
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize audio cache', error: e, stackTrace: stackTrace);
  }

  // initFCM() calls messaging.requestPermission(), which shows a native OS
  // permission prompt on iOS — this must never block first frame.
  try {
    await initFCM();
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize FCM', error: e, stackTrace: stackTrace);
  }

  // FCM Token management
  try {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    final authRepo = AuthRepository();

    if (token != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await authRepo.updateFCMToken(user.uid, token);
      }
    }

    messaging.onTokenRefresh.listen((newToken) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        authRepo.updateFCMToken(user.uid, newToken);
      }
    });

    FirebaseMessaging.onMessage.listen(handleFCMForegroundMessage);
  } catch (e) {
    AppLogger.error('Failed to initialize FCM', error: e);
  }
}

class KwayaProApp extends ConsumerWidget {
  const KwayaProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'KwayaPro',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
