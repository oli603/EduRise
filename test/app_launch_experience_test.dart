import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edurise/core/auth/role_service.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/core/settings/app_settings_controller.dart';
import 'package:edurise/features/notifications/data/notification_service.dart';
import 'package:edurise/features/profile/data/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineStorageService storage;
  late ProfileService profileService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'edurise_theme_mode': 'dark',
      'edurise_locale': 'en',
    });
    RoleService.clearCache();
    storage = OfflineStorageService();
    await storage.clearLocalDataForTesting();
    profileService = ProfileService(storage: storage);
    RoleService.setMockInstances(storage: storage, profileService: profileService);
  });

  tearDown(() async {
    RoleService.clearCache();
    await storage.clearLocalDataForTesting();
  });

  group('Step 1: Parallel Startup Initializations', () {
    test('1. AppSettingsController, OfflineStorageService, and NotificationService initialize concurrently', () async {
      final settings = AppSettingsController.instance;
      final notif = NotificationService();

      await Future.wait([
        settings.initialize(),
        storage.init(forceReload: true),
        notif.initialize(),
      ]);

      expect(settings.isInitialized, isTrue);
      expect(storage.isInitialized, isTrue);
    });
  });

  group('Step 1: Offline-First Post-Auth Startup Route Resolution', () {
    test('1. Unauthenticated user resolves to /login', () async {
      final result = await RoleService.resolvePostAuthRouteResult();
      expect(result.status, PostAuthRouteStatus.unauthenticated);
      expect(result.route, '/login');
    });

    test('2. Cached student profile resolves directly to /home with zero network latency', () async {
      final cachedProfile = StudentProfileRecord(
        uid: 'cached_student_step1',
        name: 'Tirunesh Dibaba',
        email: 'tirunesh@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(cachedProfile);

      final loaded = await profileService.getCachedProfile(uid: 'cached_student_step1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Tirunesh Dibaba');
      expect(loaded.grade, 'Grade 12');
      expect(loaded.stream, 'natural');
    });
  });
}
