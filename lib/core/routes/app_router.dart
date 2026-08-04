import "package:go_router/go_router.dart";
import 'package:edurise/features/auth/presentation/login_screen.dart';
import 'package:edurise/features/home/presentation/home_screen.dart';
import 'package:edurise/features/onboarding/presentation/onboarding_screen.dart';
import 'package:edurise/features/splash/presentation/splash_screen.dart';
import 'package:edurise/features/auth/presentation/welcome_screen.dart';
import 'package:edurise/features/auth/presentation/verify_email_screen.dart';
import 'package:edurise/features/auth/presentation/register_screen.dart';

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
    ],
  );
}
