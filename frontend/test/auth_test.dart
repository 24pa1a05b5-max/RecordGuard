import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/login_screen.dart';

void main() {
  group('LoginScreen Firebase Auth Widget Tests', () {
    testWidgets('Renders Sign In, Register, and Reset PIN modes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify title and brand
      expect(find.text('RecordGuard AI'), findsOneWidget);
      expect(find.text('Healthcare Record Contradiction Detector'), findsOneWidget);

      // Verify tabs
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Reset PIN'), findsOneWidget);

      // Default is Sign In
      expect(find.text('Sign In to Workspace'), findsOneWidget);
      expect(find.text('CLINICAL EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);

      // Switch to Register tab
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('FULL CLINICAL NAME'), findsOneWidget);
      expect(find.text('CONFIRM PASSWORD'), findsOneWidget);
      expect(find.text('Create Clinician Account'), findsOneWidget);

      // Switch to Reset PIN tab
      await tester.tap(find.text('Reset PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Send Password Reset Link'), findsOneWidget);
      expect(find.text('CONFIRM PASSWORD'), findsNothing);
    });

    testWidgets('Enforces form validation on empty submissions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Clear email and password
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.enterText(find.byType(TextFormField).last, '');

      // Tap submit
      await tester.tap(find.text('Sign In to Workspace'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });
  });
}
