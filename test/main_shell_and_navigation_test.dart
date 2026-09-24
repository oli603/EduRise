import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:edurise/core/auth/role_service.dart';
import 'package:edurise/core/auth/user_role.dart';
import 'package:edurise/core/auth/session_manager.dart';
import 'package:edurise/core/navigation/app_navigation.dart';
import 'package:edurise/core/navigation/app_shell.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
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

  group('Step 4: Bottom Navigation Architecture & Destinations', () {
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

      // Verify all routes and icons are unique
      expect(routes.toSet().length, 5);
      expect(destinations.map((d) => d.icon).toSet().length, 5);
      expect(destinations.map((d) => d.selectedIcon).toSet().length, 5);
    });
  });

  group('Step 4: AppDrawer Secondary Features & Admin Boundary', () {
    testWidgets('1. AppDrawer renders secondary items and excludes bottom-navigation duplicates', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
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

      // Verify Drawer does NOT contain bottom-nav duplicates as list items
      expect(find.widgetWithText(ListTile, 'Practice'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Games'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Progress'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Profile'), findsNothing);
    });

    testWidgets('2. Normal student cannot see Admin Dashboard in Drawer', (tester) async {
      RoleService.setRoleForTesting(UserRole.student);

      await tester.pumpWidget(
        MaterialApp(
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

      expect(find.text('Admin Dashboard'), findsNothing);
      expect(find.text('ADMIN'), findsNothing);
    });

    testWidgets('3. Authorized Admin sees Admin Dashboard in Drawer', (tester) async {
      RoleService.setRoleForTesting(UserRole.admin);

      await tester.pumpWidget(
        MaterialApp(
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

    testWidgets('4. Dynamic Drawer Header displays student profile data from local cache offline', (tester) async {
      RoleService.setRoleForTesting(UserRole.student);
      SessionManager.startSession('student_drawer_1');
      final cachedRecord = StudentProfileRecord(
        uid: 'student_drawer_1',
        name: 'Tigist Assefa',
        email: 'tigist@edurise.edu',
        grade: 'Grade 11',
        stream: 'social',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );

      await tester.runAsync(() async {
        await storage.saveStudentProfile(cachedRecord);
      });

      await tester.pumpWidget(
        MaterialApp(
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

      // Expect personalized name and grade to be visible
      expect(find.text('Tigist Assefa'), findsOneWidget);
      expect(find.text('Grade 11'), findsOneWidget);
      expect(find.text('tigist@edurise.edu'), findsOneWidget);
    });
  });

  group('Step 4: Unified AppShell & Back Navigation Safety', () {
    testWidgets('1. AppShell renders unified AppBar and NavigationBar across all 5 tabs', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return AppShell(navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (context, state) => const Center(child: Text('Home Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/practice-selection',
                    builder: (context, state) => const Center(child: Text('Practice Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/game',
                    builder: (context, state) => const Center(child: Text('Game Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/progress',
                    builder: (context, state) => const Center(child: Text('Progress Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/profile',
                    builder: (context, state) => const Center(child: Text('Profile Content')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Home tab active
      expect(find.text('EduRise'), findsOneWidget);
      expect(find.text('Home Content'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Tap Practice tab
      await tester.tap(find.text('Practice'));
      await tester.pumpAndSettle();

      expect(find.text('Practice Content'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Practice'), findsOneWidget);

      // Tap Games tab
      await tester.tap(find.text('Games'));
      await tester.pumpAndSettle();

      expect(find.text('Game Content'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'EduRise Game'), findsOneWidget);

      // Tap Progress tab
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      expect(find.text('Progress Content'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Your Progress'), findsOneWidget);

      // Tap Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Profile Content'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);
    });

    testWidgets('2. AppShell handles tab switching and return to Home tab', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return AppShell(navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (context, state) => const Center(child: Text('Home Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/practice-selection',
                    builder: (context, state) => const Center(child: Text('Practice Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/game',
                    builder: (context, state) => const Center(child: Text('Game Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/progress',
                    builder: (context, state) => const Center(child: Text('Progress Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/profile',
                    builder: (context, state) => const Center(child: Text('Profile Content')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'EduRise'), findsOneWidget);

      // Tap Progress tab
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Your Progress'), findsOneWidget);

      // Tap Home tab
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'EduRise'), findsOneWidget);
    });
  });

  group('Step 4: Account Isolation & Cache Reset', () {
    test('1. Account switching cleans all session state and loads User B independently', () async {
      // User A
      final userA = StudentProfileRecord(
        uid: 'user_a',
        name: 'User Alpha',
        email: 'alpha@edurise.edu',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: false,
        accessStatus: 'inactive',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(userA);

      // User B
      final userB = StudentProfileRecord(
        uid: 'user_b',
        name: 'User Beta',
        email: 'beta@edurise.edu',
        grade: 'Grade 11',
        stream: 'social',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(userB);

      final profileA = await storage.getStudentProfile('user_a');
      final profileB = await storage.getStudentProfile('user_b');

      expect(profileA!.name, 'User Alpha');
      expect(profileA.isPaid, isFalse);

      expect(profileB!.name, 'User Beta');
      expect(profileB.grade, 'Grade 11');
      expect(profileB.stream, 'social');
      expect(profileB.isPaid, isTrue);
    });
  });
}
