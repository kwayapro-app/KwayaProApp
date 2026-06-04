import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Initialize Firebase with visual fallback logging in case configuration isn't completed yet
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase initialized successfully.');
  } catch (e, stackTrace) {
    AppLogger.error(
      'Failed to initialize Firebase. Using local placeholder modes.',
      error: e,
      stackTrace: stackTrace,
    );
  }

  AppLogger.info('Starting KwayaPro App...');

  final prefs = await SharedPreferences.getInstance();

  // Initialize audio cache
  final audioCache = AudioCacheService();
  await audioCache.init();

  await initFCM();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
