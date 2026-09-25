import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Navigation
import 'package:edurise/core/navigation/app_shell.dart';

// Auth
import 'package:edurise/features/auth/presentation/login_screen.dart';
import 'package:edurise/features/auth/presentation/register_screen.dart';
import 'package:edurise/features/auth/presentation/verify_email_screen.dart';
import 'package:edurise/features/auth/presentation/welcome_screen.dart';
import 'package:edurise/features/auth/presentation/offline_verification_screen.dart';

// Onboarding / Splash
import 'package:edurise/features/onboarding/presentation/onboarding_screen.dart';
import 'package:edurise/features/splash/presentation/splash_screen.dart';

// Profile / Settings / About
import 'package:edurise/features/profile_setup/presentation/profile_setup_screen.dart';
import 'package:edurise/features/profile/presentation/profile_screen.dart';
import 'package:edurise/features/settings/presentation/settings_screen.dart';
import 'package:edurise/features/about/presentation/about_screen.dart';
import 'package:edurise/features/downloads/presentation/downloads_screen.dart';
// Student features
import 'package:edurise/features/home/presentation/home_screen.dart';
import 'package:edurise/features/practice/presentation/practice_screen.dart';
import 'package:edurise/features/practice/presentation/practice_selection_screen.dart';
import 'package:edurise/features/progress/presentation/progress_screen.dart';
import 'package:edurise/features/challenges/presentation/challenges_screen.dart';
import 'package:edurise/features/game/presentation/game_home_screen.dart';
import 'package:edurise/features/game/presentation/game_play_screen.dart';
import 'package:edurise/features/weak_areas/presentation/weak_areas_screen.dart';
import 'package:edurise/features/past_entrance_exams/presentation/past_entrance_exams_screen.dart';
// Books
import 'package:edurise/features/books/presentation/books_screen.dart';
import 'package:edurise/features/books/presentation/admin_book_upload_screen.dart';

// Coach & Predicted Mock
import 'package:edurise/features/coach/presentation/coach_chat_screen.dart';
import 'package:edurise/features/past_entrance_exams/presentation/predicted_mock_exam_screen.dart';

// Study Plan
import 'package:edurise/features/study_plan/presentation/study_plan_screen.dart';
import 'package:edurise/features/study_plan/presentation/add_study_task_screen.dart';
import 'package:edurise/features/study_plan/data/study_task_model.dart';

// Admin
import 'package:edurise/features/admin/presentation/add_question_screen.dart';
import 'package:edurise/features/admin/presentation/create_package_screen.dart';
import 'package:edurise/features/admin/presentation/question_packages_screen.dart';
import 'package:edurise/features/admin/presentation/question_package_details_screen.dart';
import 'package:edurise/features/admin/presentation/assign_questions_screen.dart';
import 'package:edurise/features/admin/presentation/past_exam_upload_screen.dart';
import 'package:edurise/features/admin/presentation/past_exam_question_editor_screen.dart';
import 'package:edurise/features/admin/presentation/import_practice_questions_screen.dart';
import 'package:edurise/features/admin/presentation/import_past_exams_screen.dart';
// Challenges
import 'package:edurise/features/challenges/presentation/add_challenge_screen.dart';
import 'package:edurise/features/past_entrance_exams/presentation/exam_instructions_screen.dart';
import 'package:edurise/features/past_entrance_exams/presentation/exam_screen.dart';
import 'package:edurise/features/past_entrance_exams/presentation/exam_result_screen.dart';
import 'package:edurise/features/past_entrance_exams/presentation/exam_review_screen.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_model.dart';

// Auth / Core
import 'package:firebase_auth/firebase_auth.dart';
import 'package:edurise/core/auth/role_service.dart';

import 'dart:async';
import 'package:edurise/core/auth/session_manager.dart';
import 'package:edurise/core/constants/app_subjects.dart';

// Admin / Payments / Notifications
import 'package:edurise/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:edurise/features/payment/presentation/submit_payment_screen.dart';
import 'package:edurise/features/notifications/presentation/notifications_screen.dart';
import '../maintenance/maintenance_service.dart';
import '../maintenance/maintenance_screen.dart';

/// Centralized Listenable that notifies GoRouter whenever FirebaseAuth state changes,
/// SessionManager invalidates active sessions, or system MaintenanceMode changes.
class AuthListenable extends ChangeNotifier {
  static final AuthListenable instance = AuthListenable._internal();
  StreamSubscription<User?>? _authSubscription;

  AuthListenable._internal() {
    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        notifyListeners();
      });
    } catch (_) {}
    SessionManager.registerResetListener(() {
      notifyListeners();
    });
    MaintenanceService.instance.addListener(() {
      notifyListeners();
    });
  }

  void refresh() {
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    refreshListenable: AuthListenable.instance,
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Page Not Found'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 72,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Route Not Found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  state.error?.message ?? 'The requested page could not be located.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      context.go('/home');
                    } else {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Return to Safety'),
                ),
              ],
            ),
          ),
        ),
      );
    },
    redirect: (context, state) async {
      final path = state.matchedLocation;
      final user = FirebaseAuth.instance.currentUser;

      // 1. Maintenance Mode enforcement
      if (MaintenanceService.instance.isMaintenanceActive) {
        // Allow administrators and founders to access login and admin panels
        final isAuthRoute = path == '/login' || path.startsWith('/admin');
        if (!isAuthRoute && path != '/maintenance') {
          final isAuthorized = await RoleService.isCurrentAuthorizedAdmin();
          if (!isAuthorized) {
            return '/maintenance';
          }
        }
      } else if (path == '/maintenance') {
        // If maintenance is over, redirect back to home (or login)
        return user != null ? '/home' : '/login';
      }

      // 2. Admin route authorization check
      if (path.startsWith('/admin')) {
        if (user == null) {
          return '/login';
        }
        final isAuthorized = await RoleService.isCurrentAuthorizedAdmin();
        if (!isAuthorized) {
          return '/home';
        }
      }
      return null;
    },

    routes: [
      // ==========================================================
      // MAINTENANCE & PUBLIC / AUTHENTICATION ROUTES
      // ==========================================================
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final stream = state.uri.queryParameters['stream'] ?? '';
          return WelcomeScreen(stream: stream);
        },
      ),

      GoRoute(
        path: '/login',
        builder: (context, state) {
          final stream = state.uri.queryParameters['stream'] ?? '';
          return LoginScreen(stream: stream);
        },
      ),

      GoRoute(
        path: '/register',
        builder: (context, state) {
          final stream = state.uri.queryParameters['stream'] ?? '';
          return RegisterScreen(stream: stream);
        },
      ),

      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final stream = state.uri.queryParameters['stream'] ?? '';
          return VerifyEmailScreen(stream: stream);
        },
      ),

      GoRoute(
        path: '/profile-setup',
        builder: (context, state) {
          final stream = state.uri.queryParameters['stream'] ?? '';
          return ProfileSetupScreen(stream: stream);
        },
      ),

      GoRoute(
        path: '/offline-verification',
        builder: (context, state) => const OfflineVerificationScreen(),
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
                  final grade = state.uri.queryParameters['grade'];
                  final stream = state.uri.queryParameters['stream'];
                  return PracticeSelectionScreen(grade: grade, stream: stream);
                },
              ),
            ],
          ),

          // ======================================================
          // TAB 3 — GAMES (EDURISE GAME)
          // ======================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/game',
                builder: (context, state) {
                  return const GameHomeScreen();
                },
              ),
            ],
          ),

          // ======================================================
          // TAB 4 — PROGRESS
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
          final extra = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : const <String, dynamic>{};

          final grade =
              (extra['grade'] as String?) ?? state.uri.queryParameters['grade'] ?? '';
          final stream =
              (extra['stream'] as String?) ?? state.uri.queryParameters['stream'] ?? '';
          final subject =
              (extra['subject'] as String?) ?? state.uri.queryParameters['subject'] ?? '';
          final unitNumber =
              (extra['unitNumber'] as int?) ??
              int.tryParse(state.uri.queryParameters['unitNumber'] ?? '') ??
              0;
          final unitName =
              (extra['unitName'] as String?) ?? state.uri.queryParameters['unitName'] ?? '';
          final examYear =
              (extra['examYear'] as int?) ??
              int.tryParse(state.uri.queryParameters['examYear'] ?? '');
          final questionCount =
              (extra['questionCount'] as int?) ??
              int.tryParse(state.uri.queryParameters['questionCount'] ?? '10') ??
              10;

          return PracticeScreen(
            grade: grade,
            stream: stream,
            subject: subject,
            unitNumber: unitNumber,
            unitName: unitName,
            examYear: examYear,
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
        routes: [
          GoRoute(
            path: 'instructions',
            builder: (context, state) {
              final year = state.uri.queryParameters['year'] ?? '';
              final stream = state.uri.queryParameters['stream'] ?? 'natural';
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
                stream: stream,
                subject: subject,
                round: round,
                questionCount: questionCount,
                examDuration: Duration(minutes: durationMinutes),
              );
            },
          ),
          GoRoute(
            path: 'exam',
            builder: (context, state) {
              final year = state.uri.queryParameters['year'] ?? '';
              final stream = state.uri.queryParameters['stream'] ?? 'natural';
              final subject = state.uri.queryParameters['subject'] ?? '';
              final examId = state.uri.queryParameters['examId'];
              final durationMinutes = int.tryParse(state.uri.queryParameters['durationMinutes'] ?? '');

              return ExamScreen(
                year: year,
                stream: stream,
                subject: subject,
                durationMinutes: durationMinutes,
                examId: examId,
              );
            },
          ),
          GoRoute(
            path: 'result',
            builder: (context, state) {
              final extra = state.extra is Map<String, dynamic>
                  ? state.extra as Map<String, dynamic>
                  : const <String, dynamic>{};
              final exam = extra['exam'] is PastExam
                  ? extra['exam'] as PastExam
                  : const PastExam(
                      id: 'unknown',
                      year: '2016',
                      subject: 'General Exam',
                      stream: 'natural',
                      questions: [],
                      durationMinutes: 120,
                    );
              return ExamResultScreen(
                exam: exam,
                selectedAnswers: (extra['selectedAnswers'] as Map<dynamic, dynamic>?)
                        ?.map((k, v) => MapEntry(k is int ? k : int.parse(k.toString()), v.toString())) ??
                    {},
                correctAnswers: (extra['correctAnswers'] as num?)?.toInt() ?? 0,
                totalQuestions: (extra['totalQuestions'] as num?)?.toInt() ?? 0,
                percentage: (extra['percentage'] as num?)?.toInt() ?? 0,
                timeSpentSeconds: (extra['timeSpentSeconds'] as num?)?.toInt() ?? 0,
                durationMinutes: (extra['durationMinutes'] as num?)?.toInt() ?? 120,
                isAutoSubmitted: extra['isAutoSubmitted'] as bool? ?? false,
                localResultId: extra['localResultId'] as String?,
              );
            },
          ),
          GoRoute(
            path: 'review',
            builder: (context, state) {
              final extra = state.extra is Map<String, dynamic>
                  ? state.extra as Map<String, dynamic>
                  : const <String, dynamic>{};
              final exam = extra['exam'] is PastExam
                  ? extra['exam'] as PastExam
                  : const PastExam(
                      id: 'unknown',
                      year: '2016',
                      subject: 'General Exam',
                      stream: 'natural',
                      questions: [],
                      durationMinutes: 120,
                    );
              final selectedAnswers = (extra['selectedAnswers'] as Map<dynamic, dynamic>?)
                      ?.map((k, v) => MapEntry(k is int ? k : int.parse(k.toString()), v.toString())) ??
                  {};
              return ExamReviewScreen(
                exam: exam,
                selectedAnswers: selectedAnswers,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/predicted-mock-exam',
        builder: (context, state) {
          return const PredictedMockExamScreen();
        },
      ),
      GoRoute(
        path: '/coach',
        builder: (context, state) {
          final subject = state.uri.queryParameters['subject'];
          final grade = state.uri.queryParameters['grade'];
          return CoachChatScreen(
            initialSubject: subject,
            initialGrade: grade,
          );
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
          final task = state.extra is StudyTask ? state.extra as StudyTask : null;
          return AddStudyTaskScreen(initialTask: task);
        },
      ),

      // ----------------------------------------------------------
      // CHALLENGES
      // ----------------------------------------------------------
      GoRoute(
        path: '/challenges',
        builder: (context, state) => const ChallengesScreen(),
      ),

      GoRoute(
        path: '/add-challenge',
        builder: (context, state) {
          return const AddChallengeScreen();
        },
      ),

      // ==========================================================
      // EDURISE GAME PLAY ROUTE
      // ==========================================================
      GoRoute(
        path: '/game/play',
        builder: (context, state) {
          final stream = state.uri.queryParameters['stream'] ?? 'natural';
          final defaultSubject = EduRiseSubjects.isSocialStream(stream) ? 'Economics' : 'Mathematics';
          final subject = state.uri.queryParameters['subject'] ?? defaultSubject;
          final level = int.tryParse(state.uri.queryParameters['level'] ?? '1') ?? 1;

          return GamePlayScreen(
            subject: subject,
            stream: stream,
            levelNumber: level,
          );
        },
      ),

      // ==========================================================
      // DOWNLOADS ROUTE
      // ==========================================================
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),

      // ==========================================================
      // SETTINGS & ABOUT ROUTES
      // ==========================================================
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutEduRiseScreen(),
      ),

      // ==========================================================
      // PAYMENT & NOTIFICATION ROUTES
      // ==========================================================
      GoRoute(
        path: '/payment/submit',
        builder: (context, state) => const SubmitPaymentScreen(),
      ),

      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ==========================================================
      // ADMIN ROUTES
      // ==========================================================
      GoRoute(
        path: '/admin',
        builder: (context, state) => AdminDashboardScreen(
          initialTab: state.uri.queryParameters['tab'],
          initialSubtab: state.uri.queryParameters['subtab'],
        ),
      ),

      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => AdminDashboardScreen(
          initialTab: state.uri.queryParameters['tab'],
          initialSubtab: state.uri.queryParameters['subtab'],
        ),
      ),

      GoRoute(
        path: '/admin/add-question',
        builder: (context, state) {
          return const AddQuestionScreen();
        },
      ),

      GoRoute(
        path: '/admin/questions/import',
        builder: (context, state) {
          return const ImportPracticeQuestionsScreen();
        },
      ),

      GoRoute(
        path: '/admin/past-exams/import',
        builder: (context, state) {
          return const ImportPastExamsScreen();
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
            packageId: state.pathParameters['packageId'] ?? '',
          );
        },
        routes: [
          GoRoute(
            path: 'assign',
            builder: (context, state) {
              return AssignQuestionsScreen(
                packageId: state.pathParameters['packageId'] ?? '',
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
        path: '/admin/past-exams/upload',
        builder: (context, state) {
          return const PastExamUploadScreen();
        },
      ),
      GoRoute(
        path: '/admin/past-exams/questions',
        builder: (context, state) {
          final data = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : const <String, dynamic>{};

          return PastExamQuestionEditorScreen(
            year: (data['year'] as String?) ?? '',
            stream: (data['stream'] as String?) ?? 'natural',
            round: data['round'] as String?,
            subject: (data['subject'] as String?) ?? '',
            duration: (data['duration'] as String?) ?? '120',
          );
        },
      ),
    ],
  );
}
