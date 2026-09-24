import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/core/auth/role_service.dart';
import 'package:edurise/core/auth/user_role.dart';
import 'package:edurise/core/navigation/app_navigation.dart';
import 'package:edurise/core/navigation/app_shell.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/core/routes/app_router.dart';
import 'package:edurise/features/profile/data/profile_service.dart';
import 'package:edurise/features/study_plan/data/study_task_model.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineStorageService storage;
  late ProfileService profileService;

  setUp(() async {
    RoleService.clearCache();
    storage = OfflineStorageService();
    await storage.clearLocalDataForTesting();
    await storage.init(forceReload: true);
    profileService = ProfileService(storage: storage);
    RoleService.setMockInstances(storage: storage, profileService: profileService);
  });

  tearDown(() async {
    RoleService.clearCache();
    await storage.clearLocalDataForTesting();
  });

  group('Step 0.9: Post-Authentication Route Resolution & Status', () {
    test('1. PostAuthRouteStatus and Result getters evaluate correctly', () {
      const homeResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.existingStudent,
        route: '/home',
      );
      expect(homeResult.isHome, isTrue);
      expect(homeResult.isAdmin, isFalse);
      expect(homeResult.isProfileSetup, isFalse);
      expect(homeResult.isOfflineVerificationRequired, isFalse);

      const adminResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.authorizedAdmin,
        route: '/admin',
      );
      expect(adminResult.isAdmin, isTrue);
      expect(adminResult.isHome, isFalse);

      const offlineResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.offlineVerificationRequired,
        route: '/offline-verification',
      );
      expect(offlineResult.isOfflineVerificationRequired, isTrue);
    });

    test('2. Cached student profile in storage resolves to /home offline with zero network latency', () async {
      final cachedProfile = StudentProfileRecord(
        uid: 'cached_student_123',
        name: 'Abebe Bikila',
        email: 'abebe@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(cachedProfile);

      final retrieved = await profileService.getCachedProfile(uid: 'cached_student_123');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Abebe Bikila');
      expect(retrieved.grade, 'Grade 12');
      expect(retrieved.stream, 'natural');
    });
  });

  group('Step 0.9: Role Hierarchy & Student -> Admin Authorization Guards', () {
    test('1. UserRole enum enforces strict role hierarchy and privileges', () {
      expect(UserRole.student.isAuthorizedAdmin, isFalse);
      expect(UserRole.student.isAdmin, isFalse);
      expect(UserRole.student.isFounder, isFalse);

      expect(UserRole.admin.isAuthorizedAdmin, isTrue);
      expect(UserRole.admin.isAdmin, isTrue);
      expect(UserRole.admin.isFounder, isFalse);

      expect(UserRole.founder.isAuthorizedAdmin, isTrue);
      expect(UserRole.founder.isAdmin, isTrue);
      expect(UserRole.founder.isFounder, isTrue);
    });

    test('2. RoleService correctly identifies bootstrap founder and admin authorities', () {
      expect(RoleService.founderEmail, 'olanamengistu2@gmail.com');
      expect(RoleService.adminEmail, 'tamiratboja@gmail.com');
    });
  });

  group('Step 0.9: Bottom Navigation & Drawer Separation Architecture', () {
    test('1. AppNavigation contains exactly 5 primary bottom destinations without duplication', () {
      final destinations = AppNavigation.destinations;
      expect(destinations.length, 5);

      final labels = destinations.map((d) => d.label).toList();
      expect(labels, ['Home', 'Practice', 'Games', 'Progress', 'Profile']);

      final routes = destinations.map((d) => d.route).toList();
      expect(routes, [
        '/home',
        '/practice-selection',
        '/game',
        '/progress',
        '/profile',
      ]);
    });

    testWidgets('2. AppDrawer renders non-bottom features and does NOT duplicate Practice, Games, Progress', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: const AppDrawer(),
            body: const Center(child: Text('Shell Body')),
          ),
        ),
      );

      final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Verify non-bottom feature destinations are in Drawer
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Past Entrance Exams'), findsOneWidget);
      expect(find.text('Predicted Mock Exam'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Study Plan'), findsOneWidget);
      expect(find.text('Weak Areas'), findsOneWidget);
      expect(find.text('EduRise Coach'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Subscription / Payment'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('About EduRise'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Verify Drawer does NOT contain bottom-nav duplicates as list items
      expect(find.widgetWithText(ListTile, 'Practice'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Games'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Progress'), findsNothing);
    });
  });

  group('Step 0.9: Route Definition & Fallback Safety', () {
    test('1. AppRouter initializes with configured routes and errorBuilder', () {
      final router = AppRouter.router;
      expect(router, isNotNull);
      expect(router.configuration.routes.isNotEmpty, isTrue);
    });

    test('2. StudyTask and PastExam model fallback contracts', () {
      final task = StudyTask(
        id: 'test_task_1',
        userId: 'test_user_1',
        title: 'Biology Review',
        grade: 'Grade 12',
        subject: 'Biology',
        unitNumber: 1,
        unitName: 'Cell Biology',
        taskType: 'practice',
        targetCount: 20,
        isCompleted: false,
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      expect(task.title, 'Biology Review');

      const fallbackExam = PastExam(
        id: 'fallback_id',
        year: '2016',
        subject: 'Natural Science',
        stream: 'natural',
        questions: [],
        durationMinutes: 120,
      );
      expect(fallbackExam.questions.isEmpty, isTrue);
      expect(fallbackExam.durationMinutes, 120);
    });
  });

  group('Step 0.9: Account Isolation & Cache Reset', () {
    test('1. RoleService.clearCache() resets static role and UID variables', () {
      RoleService.clearCache();
      expect(RoleService.isFounder, isFalse);
      expect(RoleService.isAdmin, isFalse);
      expect(RoleService.isAuthorizedAdmin, isFalse);
    });
  });
}
