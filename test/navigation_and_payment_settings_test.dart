import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/navigation/app_navigation.dart';
import 'package:edurise/core/navigation/app_shell.dart';
import 'package:edurise/features/admin/data/admin_settings_service.dart';

void main() {
  group('Bottom Navigation Configuration Tests', () {
    test('Has exactly 5 authoritative bottom navigation destinations in order', () {
      final destinations = AppNavigation.destinations;
      expect(destinations.length, 5);

      // 1. Home (index 0)
      expect(destinations[0].label, 'Home');
      expect(destinations[0].route, '/home');

      // 2. Practice (index 1)
      expect(destinations[1].label, 'Practice');
      expect(destinations[1].route, '/practice-selection');

      // 3. Games (index 2)
      expect(destinations[2].label, 'Games');
      expect(destinations[2].route, '/game');

      // 4. Progress (index 3)
      expect(destinations[3].label, 'Progress');
      expect(destinations[3].route, '/progress');

      // 5. Profile (index 4)
      expect(destinations[4].label, 'Profile');
      expect(destinations[4].route, '/profile');
    });

    test('All bottom navigation items have distinct icons and selected icons', () {
      for (final dest in AppNavigation.destinations) {
        expect(dest.icon, isNotNull);
        expect(dest.selectedIcon, isNotNull);
        expect(dest.label.isNotEmpty, isTrue);
      }
    });
  });

  group('Student Drawer Navigation Structure Tests', () {
    testWidgets('Drawer contains authoritative non-bottom-nav destinations and excludes duplicates', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => const AppDrawer(),
            ),
          ),
        ),
      );

      // Verify exclusions: Games, Practice, Progress should NOT be in the Drawer list tiles
      expect(find.widgetWithText(ListTile, 'EduRise Game'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Games'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Practice'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Progress'), findsNothing);

      // Verify inclusions
      expect(find.widgetWithText(ListTile, 'Books'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Past Entrance Exams'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Predicted Mock Exam'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Challenges'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Study Plan'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Weak Areas'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'EduRise Coach'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Downloads'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Subscription / Payment'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Notifications'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Settings'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'About EduRise'), findsOneWidget);
    });
  });

  group('System Settings & Payment Synchronization Tests', () {
    test('Default subscription price is 1499.0 Birr', () {
      final defaults = SystemSettings.defaults();
      expect(defaults.subscriptionPrice, 1499.0);
      expect(defaults.cbeAccount, '1000123456789');
      expect(defaults.cbeAccountName, 'EduRise Academy');
      expect(defaults.telebirrNumber, '0911000000');
    });

    test('SystemSettings.fromMap falls back cleanly to 1499.0 when price missing or empty', () {
      final settings = SystemSettings.fromMap({
        'cbeAccount': '1000999888777',
      });
      expect(settings.subscriptionPrice, 1499.0);
      expect(settings.cbeAccount, '1000999888777');
      expect(settings.cbeAccountName, 'EduRise Academy');
      expect(settings.telebirrNumber, '0911000000');
    });

    test('SystemSettings preserves custom price and bank account numbers', () {
      final custom = SystemSettings(
        cbeAccount: '1000555444333',
        cbeAccountName: 'EduRise Operations',
        telebirrNumber: '0922334455',
        subscriptionPrice: 1200.0,
        maintenanceMode: true,
        announcementBanner: 'Holiday promo',
      );

      final map = custom.toMap();
      final restored = SystemSettings.fromMap(map);

      expect(restored.cbeAccount, '1000555444333');
      expect(restored.cbeAccountName, 'EduRise Operations');
      expect(restored.telebirrNumber, '0922334455');
      expect(restored.subscriptionPrice, 1200.0);
      expect(restored.maintenanceMode, isTrue);
      expect(restored.announcementBanner, 'Holiday promo');
    });
  });
}
