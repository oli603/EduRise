import "package:go_router/go_router.dart";
import 'package:edurise/features/auth/presentation/login_screen.dart';
import 'package:edurise/features/home/presentation/home_screen.dart';
import 'package:edurise/features/onboarding/presentation/onboarding_screen.dart';
import 'package:edurise/features/splash/presentation/splash_screen.dart';
import 'package:edurise/features/auth/presentation/welcome_screen.dart';
import 'package:edurise/features/auth/presentation/verify_email_screen.dart';
import 'package:edurise/features/auth/presentation/register_screen.dart';
import 'package:edurise/features/profile_setup/presentation/profile_setup_screen.dart';
import 'package:edurise/features/weak_areas/presentation/weak_areas_screen.dart';
import 'package:edurise/features/practice/presentation/practice_screen.dart';
import 'package:edurise/features/practice/presentation/practice_selection_screen.dart';
import 'package:edurise/features/admin/presentation/add_question_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/weak-areas',
        builder: (context, state) => const WeakAreasScreen(),
      ),
      GoRoute(
        path: '/practice',
        builder: (context, state) {
          final grade = state.uri.queryParameters['grade'] ?? '';

          final subject = state.uri.queryParameters['subject'] ?? '';

          final unitNumber =
              int.tryParse(state.uri.queryParameters['unitNumber'] ?? '') ?? 0;

          final unitName = state.uri.queryParameters['unitName'] ?? '';

          return PracticeScreen(
            grade: grade,
            subject: subject,
            unitNumber: unitNumber,
            unitName: unitName,
          );
        },
      ),
      GoRoute(
        path: '/practice-selection',
        builder: (context, state) => const PracticeSelectionScreen(),
      ),
      GoRoute(
        path: '/admin/add-question',
        builder: (context, state) => const AddQuestionScreen(),
      ),
    ],
  );
}
