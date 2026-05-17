import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kwayapro/main.dart';
import 'package:kwayapro/core/utils/state_logger.dart';

void main() {
  testWidgets('App compiles and shows onboarding router', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        observers: [
          StateLogger(),
        ],
        child: KwayaProApp(),
      ),
    );

    // Initial load takes time for GoRouter to resolve
    await tester.pumpAndSettle();

    // Verify that the Onboarding Screen is found (by type or text)
    expect(find.text('Onboarding Screen'), findsOneWidget);
  });
}
