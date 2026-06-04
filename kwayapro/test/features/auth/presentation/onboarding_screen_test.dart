import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kwayapro/features/auth/presentation/onboarding_screen.dart';
import 'package:kwayapro/features/auth/data/auth_repository.dart';
import 'package:kwayapro/features/auth/domain/auth_providers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;

  setUpAll(() {
    registerFallbackValue(
      PhoneAuthProvider.credential(verificationId: 'v', smsCode: '123456'),
    );
  });

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
      ],
      child: const MaterialApp(home: OnboardingScreen()),
    );
  }

  testWidgets(
    'Submitting phone number calls AuthRepository.verifyPhone and navigates to OTP step',
    (tester) async {
      // Mock verifyPhone to immediately trigger onCodeSent
      when(() => mockAuthRepository.verifyPhone(
            phoneNumber: any(named: 'phoneNumber'),
            onVerificationCompleted: any(named: 'onVerificationCompleted'),
            onVerificationFailed: any(named: 'onVerificationFailed'),
            onCodeSent: any(named: 'onCodeSent'),
            onCodeAutoRetrievalTimeout: any(named: 'onCodeAutoRetrievalTimeout'),
            resendToken: any(named: 'resendToken'),
          )).thenAnswer((invocation) async {
        final onCodeSent = invocation.namedArguments[#onCodeSent]
            as void Function(String, int?);
        onCodeSent('verification_id_123', null);
      });

      await tester.pumpWidget(createWidgetUnderTest());

      // Splash step
      expect(find.byKey(const ValueKey('splash')), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Phone step
      expect(find.byKey(const ValueKey('phone')), findsOneWidget);

      // Invalid phone → snackbar
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid 9-digit phone number'), findsOneWidget);

      // Valid phone → advances to OTP
      await tester.enterText(find.byType(TextFormField), '772123456');
      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();

      verify(() => mockAuthRepository.verifyPhone(
            phoneNumber: '0772123456',
            onVerificationCompleted: any(named: 'onVerificationCompleted'),
            onVerificationFailed: any(named: 'onVerificationFailed'),
            onCodeSent: any(named: 'onCodeSent'),
            onCodeAutoRetrievalTimeout: any(named: 'onCodeAutoRetrievalTimeout'),
            resendToken: any(named: 'resendToken'),
          )).called(1);

      expect(find.byKey(const ValueKey('otp')), findsOneWidget);
      expect(find.text('Verify code'), findsOneWidget);
      // Resend button present
      expect(find.text('Resend code'), findsOneWidget);
    },
  );
}
