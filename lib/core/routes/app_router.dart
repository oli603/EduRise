import 'package:go_router/go_router.dart';

// Navigation
import 'package:edurise/core/navigation/app_shell.dart';

// Auth
import 'package:edurise/features/auth/presentation/login_screen.dart';
import 'package:edurise/features/auth/presentation/register_screen.dart';
import 'package:edurise/features/auth/presentation/verify_email_screen.dart';
import 'package:edurise/features/auth/presentation/welcome_screen.dart';

// Onboarding / Splash
import 'package:edurise/features/onboarding/presentation/onboarding_screen.dart';
import 'package:edurise/features/splash/presentation/splash_screen.dart';

// Profile
import 'package:edurise/features/profile_setup/presentation/profile_setup_screen.dart';
import 'package:edurise/features/profile/presentation/profile_screen.dart';
// Student features
import 'package:edurise/features/home/presentation/home_screen.dart';
import 'package:edurise/features/practice/presentation/practice_screen.dart';
import 'package:edurise/features/practice/presentation/practice_selection_screen.dart';
import 'package:edurise/features/progress/presentation/progress_screen.dart';
import 'package:edurise/features/challenges/presentation/challenges_screen.dart';
import 'package:edurise/features/weak_areas/presentation/weak_areas_screen.dart';
import 'package:edurise/features/past_entrance_exams/presentation/past_entrance_exams_screen.dart';
// Books
import 'package:edurise/features/books/presentation/books_screen.dart';
import 'package:edurise/features/books/presentation/admin_book_upload_screen.dart';

// Study Plan
import 'package:edurise/features/study_plan/presentation/study_plan_screen.dart';
import 'package:edurise/features/study_plan/presentation/add_study_task_screen.dart';

// Admin
import 'package:edurise/features/admin/presentation/add_question_screen.dart';
import 'package:edurise/features/admin/presentation/create_package_screen.dart';
import 'package:edurise/features/admin/presentation/question_packages_screen.dart';
import 'package:edurise/features/admin/presentation/question_package_details_screen.dart';
import 'package:edurise/features/admin/presentation/assign_questions_screen.dart';
import 'package:edurise/features/admin/presentation/past_exam_upload_screen.dart';
import 'package:edurise/features/admin/presentation/past_exam_question_editor_screen.dart';
// Challenges
import 'package:edurise/features/challenges/presentation/add_challenge_screen.dart';
import 'package:edurise/features/past_entrance_exams/presentation/exam_instructions_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',

    routes: [
      // ==========================================================
      // PUBLIC / AUTHENTICATION ROUTES
      // ==========================================================
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      GoRoute(
        path: '/auth',
        builder: (context, state) => const WelcomeScreen(),
      ),

      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),

      GoRoute(
        path: '/profile-setup',
        builder: (context, state) {
          final stream = state.uri.queryParameters['stream'] ?? '';

          return ProfileSetupScreen(stream: stream);
        },
      ),

      // ==========================================================
      // STUDENT APPLICATION SHELL
      // ==========================================================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },

        branches: [
          // ======================================================
          // TAB 1 — HOME
          // ======================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) {
                  return const HomeScreen();
                },
              ),
            ],
          ),

          // ======================================================
          // TAB 2 — PRACTICE
          // ======================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/practice-selection',
                builder: (context, state) {
                  final grade = state.uri.queryParameters['grade'] ?? '';
                  final stream = state.uri.queryParameters['stream'] ?? '';
                  return PracticeSelectionScreen(grade: grade, stream: stream);
                },
              ),
            ],
          ),

          // ======================================================
          // TAB 3 — PROGRESS
          // ======================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) {
                  return const ProgressScreen();
                },
              ),
            ],
          ),

          // ======================================================
          // TAB 4 — GAMES
          // ======================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/challenges',
                builder: (context, state) {
                  return const ChallengesScreen();
                },
              ),
            ],
          ),

          // ======================================================
          // TAB 5 — PROFILE
          // ======================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) {
                  return const ProfileScreen();
                },
              ),
            ],
          ),
        ],
      ),

      // ==========================================================
      // STUDENT SECONDARY ROUTES
      // ==========================================================

      // ----------------------------------------------------------
      // PRACTICE SESSION
      // ----------------------------------------------------------
      GoRoute(
        path: '/practice',
        builder: (context, state) {
          final grade = state.uri.queryParameters['grade'] ?? '';

          final stream = state.uri.queryParameters['stream'] ?? '';

          final subject = state.uri.queryParameters['subject'] ?? '';

          final unitNumber =
              int.tryParse(state.uri.queryParameters['unitNumber'] ?? '') ?? 0;

          final unitName = state.uri.queryParameters['unitName'] ?? '';

          final questionCount =
              int.tryParse(
                state.uri.queryParameters['questionCount'] ?? '10',
              ) ??
              10;

          return PracticeScreen(
            grade: grade,
            stream: stream,
            subject: subject,
            unitNumber: unitNumber,
            unitName: unitName,
            questionCount: questionCount,
          );
        },
      ),

      // ----------------------------------------------------------
      // WEAK AREAS
      // ----------------------------------------------------------
      GoRoute(
        path: '/weak-areas',
        builder: (context, state) {
          return const WeakAreasScreen();
        },
      ),
      GoRoute(
        path: '/past-entrance-exams',
        builder: (context, state) {
          return const PastEntranceExamsScreen();
        },
      ),

      // ----------------------------------------------------------
      // BOOKS
      // ----------------------------------------------------------
      GoRoute(
        path: '/books',
        builder: (context, state) {
          final grade = state.uri.queryParameters['grade'] ?? '';

          final subject = state.uri.queryParameters['subject'] ?? '';

          return BooksScreen(grade: grade, subject: subject);
        },
      ),

      // ----------------------------------------------------------
      // STUDY PLAN
      // ----------------------------------------------------------
      GoRoute(
        path: '/study-plan',
        builder: (context, state) {
          return const StudyPlanScreen();
        },
      ),

      GoRoute(
        path: '/add-study-task',
        builder: (context, state) {
          return const AddStudyTaskScreen();
        },
      ),

      // ----------------------------------------------------------
      // ADD CHALLENGE
      // ----------------------------------------------------------
      GoRoute(
        path: '/add-challenge',
        builder: (context, state) {
          return const AddChallengeScreen();
        },
      ),

      // ==========================================================
      // ADMIN ROUTES
      // ==========================================================
      GoRoute(
        path: '/admin/add-question',
        builder: (context, state) {
          return const AddQuestionScreen();
        },
      ),

      GoRoute(
        path: '/admin/create-package',
        builder: (context, state) {
          return const CreatePackageScreen();
        },
      ),

      GoRoute(
        path: '/admin/question-packages',
        builder: (context, state) {
          return const QuestionPackagesScreen();
        },
      ),

      GoRoute(
        path: '/admin/question-packages/:packageId',
        builder: (context, state) {
          return QuestionPackageDetailsScreen(
            packageId: state.pathParameters['packageId']!,
          );
        },
        routes: [
          GoRoute(
            path: 'assign',
            builder: (context, state) {
              return AssignQuestionsScreen(
                packageId: state.pathParameters['packageId']!,
              );
            },
          ),
        ],
      ),

      GoRoute(
        path: '/admin/books/upload',
        builder: (context, state) {
          return const AdminBookUploadScreen();
        },
      ),
      GoRoute(
        path: '/past-entrance-exams/instructions',
        builder: (context, state) {
          final year = state.uri.queryParameters['year'] ?? '';
          final subject = state.uri.queryParameters['subject'] ?? '';
          final round = state.uri.queryParameters['round'];

          final questionCount =
              int.tryParse(
                state.uri.queryParameters['questionCount'] ?? '50',
              ) ??
              50;

          final durationMinutes =
              int.tryParse(
                state.uri.queryParameters['durationMinutes'] ?? '180',
              ) ??
              180;

          return ExamInstructionsScreen(
            year: year,
            subject: subject,
            round: round,
            questionCount: questionCount,
            examDuration: Duration(minutes: durationMinutes),
          );
        },
      ),
      GoRoute(
        path: '/admin/past-exams/upload',
        builder: (context, state) {
          return const PastExamUploadScreen();
        },
      ),
      GoRoute(
        path: '/admin/past-exams/questions',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;

          return PastExamQuestionEditorScreen(
            year: data['year'] as String,
            stream: data['stream'] as String,
            round: data['round'] as String?,
            subject: data['subject'] as String,
            duration: data['duration'] as String,
          );
        },
      ),
    ],
  );
}
