import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/core/auth/role_service.dart';
import 'package:edurise/core/auth/session_manager.dart';
import 'package:edurise/core/auth/user_role.dart';
import 'package:edurise/core/navigation/app_navigation.dart';
import 'package:edurise/core/navigation/app_shell.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/core/theme/app_theme.dart';
import 'package:edurise/features/home/presentation/home_screen.dart';
import 'package:edurise/features/home/widgets/greeting_section.dart';
import 'package:edurise/features/home/widgets/hero_action_card.dart';
import 'package:edurise/features/home/widgets/learning_progress_section.dart';
import 'package:edurise/features/home/widgets/quick_access_section.dart';
import 'package:edurise/features/home/widgets/today_challenge_section.dart';
import 'package:edurise/features/home/widgets/today_plan_section.dart';
import 'package:edurise/features/profile/data/profile_service.dart';

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

  // ============================================================
  // GROUP 1: BOTTOM NAVIGATION ARCHITECTURE & DESTINATIONS
  // ============================================================
  group('Phase 1: Bottom Navigation Architecture', () {
    test('1. Exactly 5 primary bottom-navigation destinations with distinct routes and icons', () {
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

      expect(routes.toSet().length, 5);
      expect(destinations.map((d) => d.icon).toSet().length, 5);
      expect(destinations.map((d) => d.selectedIcon).toSet().length, 5);
    });
  });

  // ============================================================
  // GROUP 2: APP SHELL & DRAWER INTEGRATION
  // ============================================================
  group('Phase 1: App Shell & Modern Drawer', () {
    testWidgets('1. AppDrawer renders all secondary features and excludes bottom-nav items', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      RoleService.setRoleForTesting(UserRole.student);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            drawer: AppDrawer(profileService: profileService),
            body: const Center(child: Text('Shell Body')),
          ),
        ),
      );

      final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Verify secondary features in Drawer
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

      // Verify Drawer does NOT duplicate bottom-nav items as list items
      expect(find.widgetWithText(ListTile, 'Practice'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Games'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Progress'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Profile'), findsNothing);

      // Verify Normal student cannot see Admin Dashboard
      expect(find.text('Admin Dashboard'), findsNothing);
      expect(find.text('ADMIN'), findsNothing);
    });

    testWidgets('2. Authorized Admin sees Admin Dashboard in Drawer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      RoleService.setRoleForTesting(UserRole.admin);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            drawer: AppDrawer(profileService: profileService),
            body: const Center(child: Text('Shell Body')),
          ),
        ),
      );

      final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
    });

    testWidgets('3. Dynamic Drawer Header displays student profile data from local cache offline', (tester) async {
      RoleService.setRoleForTesting(UserRole.student);
      SessionManager.startSession('student_phase1_drawer');
      final cachedRecord = StudentProfileRecord(
        uid: 'student_phase1_drawer',
        name: 'Abebe Bikila',
        email: 'abebe@edurise.edu',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );

      await tester.runAsync(() async {
        await storage.saveStudentProfile(cachedRecord);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            drawer: AppDrawer(profileService: profileService),
            body: const Center(child: Text('Shell Body')),
          ),
        ),
      );

      final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Abebe Bikila'), findsOneWidget);
      expect(find.text('Grade 12'), findsOneWidget);
      expect(find.text('abebe@edurise.edu'), findsOneWidget);
    });
  });

  // ============================================================
  // GROUP 3: HOME SCREEN STATES & COMPONENTS
  // ============================================================
  group('Phase 1: Home Screen Experience & Personalization', () {
    testWidgets('1. HomeScreen renders Empty/Onboarding state when profile is null', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      RoleService.setRoleForTesting(UserRole.student);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(profileService: profileService),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Welcome to EduRise!'), findsOneWidget);
      expect(find.text('Complete Profile Setup'), findsOneWidget);
    });

    testWidgets('2. HomeScreen renders loaded student dashboard with all core sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      RoleService.setRoleForTesting(UserRole.student);
      SessionManager.startSession('student_phase1_loaded');
      final profile = StudentProfileRecord(
        uid: 'student_phase1_loaded',
        name: 'Sara Tesfaye',
        email: 'sara@edurise.edu',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );

      await tester.runAsync(() async {
        await storage.saveStudentProfile(profile);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(profileService: profileService),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Personalized Greeting with student name and refined header
      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.textContaining('Sara Tesfaye'), findsOneWidget);
      expect(find.text('Ready to continue learning?'), findsOneWidget);
      expect(find.byType(GreetingSection), findsOneWidget);

      // 2. Primary Hero Action Card
      expect(find.text('What should you learn today?'), findsOneWidget);
      expect(find.text('Continue Practice'), findsOneWidget);
      expect(find.byType(HeroActionCard), findsOneWidget);

      // 3. Learning Progress Section
      expect(find.text('Learning Progress'), findsOneWidget);
      expect(find.byType(LearningProgressSection), findsOneWidget);

      // 4. Today's Plan Section
      expect(find.text("Today's Plan"), findsOneWidget);
      expect(find.byType(TodayPlanSection), findsOneWidget);

      // 5. Today's Challenge Section
      expect(find.text("Today's Challenge"), findsOneWidget);
      expect(find.byType(TodayChallengeSection), findsOneWidget);

      // 6. Quick Access Grid
      expect(find.text('Quick Access'), findsOneWidget);
      expect(find.text('Challenges'), findsWidgets);
      expect(find.text('Past Entrance Exams'), findsOneWidget);
      expect(find.text('Predicted Mock Exam'), findsOneWidget);
      expect(find.text('Weak Areas'), findsOneWidget);
      expect(find.text('Study Plan'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
      expect(find.byType(QuickAccessSection), findsOneWidget);
    });

    testWidgets('3. HomeScreen adapts properly between Light and Dark themes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      RoleService.setRoleForTesting(UserRole.student);
      SessionManager.startSession('student_theme_test');
      final profile = StudentProfileRecord(
        uid: 'student_theme_test',
        name: 'Dawit Yohannes',
        email: 'dawit@edurise.edu',
        grade: 'Grade 11',
        stream: 'social',
        isPaid: false,
        accessStatus: 'locked',
        cachedAt: DateTime.now(),
      );

      await tester.runAsync(() async {
        await storage.saveStudentProfile(profile);
      });

      // Render Dark Theme
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: HomeScreen(profileService: profileService),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.textContaining('Dawit Yohannes'), findsOneWidget);
      expect(find.text('What should you learn today?'), findsOneWidget);
      expect(find.text('Quick Access'), findsOneWidget);
    });
  });
}
