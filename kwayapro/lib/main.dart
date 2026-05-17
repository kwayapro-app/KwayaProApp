import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/firebase/firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/state_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    const ProviderScope(
      observers: [
        StateLogger(),
      ],
      child: KwayaProApp(),
    ),
  );
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
