// This smoke test verifies the OnboardingScreen renders standalone
// without needing Firebase initialization.
// Full integration tests with Firebase require a real device / emulator.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kwayapro/features/auth/presentation/onboarding_screen.dart';
import 'package:kwayapro/features/auth/data/auth_repository.dart';
import 'package:kwayapro/features/auth/domain/auth_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  testWidgets('OnboardingScreen smoke test: splash renders Get Started', (tester) async {
    final mockAuth = MockAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('KwayaPro'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
