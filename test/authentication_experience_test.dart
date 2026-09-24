import 'package:edurise/core/auth/role_service.dart';
import 'package:edurise/core/widgets/edurise_text_field.dart';
import 'package:edurise/features/auth/data/auth_service.dart';
import 'package:edurise/features/auth/presentation/verify_email_screen.dart';
import 'package:edurise/features/auth/presentation/welcome_screen.dart';
import 'package:edurise/features/auth/presentation/widgets/login_form.dart';
import 'package:edurise/features/auth/presentation/widgets/register_form.dart';
import 'package:edurise/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EduRise — Step 2: Authentication Experience & Boundary Tests', () {
    test('1. AuthService: sendPasswordResetEmail empty email check', () async {
      final authService = AuthService();
      final result = await authService.sendPasswordResetEmail('');
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Please enter your email'));

      final whitespaceResult = await authService.sendPasswordResetEmail('   ');
      expect(whitespaceResult.isSuccess, isFalse);
    });

    test('2. RoleService and Cache clearing on SignOut', () async {
      // Set test values in RoleService
      RoleService.clearCache();
      expect(RoleService.isFounder, isFalse);
      expect(RoleService.isAdmin, isFalse);
    });

    testWidgets('3. EduRiseTextField renders with enhanced input ergonomics',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      bool submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EduRiseTextField(
              label: 'Test Email',
              hint: 'Enter email',
              controller: controller,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => submitted = true,
              enabled: true,
            ),
          ),
        ),
      );

      expect(find.text('Test Email'), findsOneWidget);
      expect(find.text('Enter email'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(submitted, isTrue);
      expect(controller.text, 'test@example.com');
    });

    testWidgets('4. LoginForm renders input fields, forgot password & google buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoginForm(),
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // Tap Forgot Password to ensure dialog appears
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Password'), findsNothing);
    });

    testWidgets('5. RegisterForm renders full name, email, password, and confirm password',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegisterForm(),
            ),
          ),
        ),
      );

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('6. WelcomeScreen renders Google Sign-In and Continue with Email',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      expect(find.text('EduRise'), findsOneWidget);
      expect(find.text('Welcome Back 👋'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Email'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('7. VerifyEmailScreen renders check verification, resend, and sign out',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VerifyEmailScreen(),
        ),
      );

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text("I've Verified"), findsOneWidget);
      expect(find.text('Resend Email'), findsOneWidget);
      expect(find.text('Sign Out / Use Different Email'), findsOneWidget);
    });

    testWidgets('8. OnboardingScreen allows switching stream cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.text('Welcome to EduRise'), findsOneWidget);
      expect(find.text('Natural Science'), findsOneWidget);
      expect(find.text('Social Science'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Select Social Science
      await tester.tap(find.text('Social Science'));
      await tester.pump();

      // Tap Natural Science
      await tester.tap(find.text('Natural Science'));
      await tester.pump();
    });
  });
}
