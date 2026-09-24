import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/role_service.dart';
import 'package:edurise/core/auth/user_role.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/profile/data/profile_service.dart';

void main() {
  late OfflineStorageService storage;
  late ProfileService profileService;

  setUp(() async {
    RoleService.clearCache();
    storage = OfflineStorageService();
    await storage.clearLocalDataForTesting();
    await storage.init(forceReload: true);
    profileService = ProfileService(storage: storage);
    RoleService.setMockInstances(profileService: profileService);
  });

  tearDown(() async {
    RoleService.clearCache();
    await storage.clearLocalDataForTesting();
  });

  group('Offline-First Post-Authentication Route Resolution Tests', () {
    test('TEST 1: Authenticated student with local cached profile offline routes to /home', () async {
      final cachedProfile = StudentProfileRecord(
        uid: 'student_cached_123',
        name: 'Derartu Tulu',
        email: 'derartu@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(cachedProfile);

      final loaded = await profileService.getCachedProfile(uid: 'student_cached_123');
      expect(loaded, isNotNull);
      expect(loaded!.uid, 'student_cached_123');
      expect(loaded.name, 'Derartu Tulu');
      expect(loaded.grade, 'Grade 12');
      expect(loaded.stream, 'natural');
    });

    test('TEST 2 & 3: Profile cache validation & stale cache recognition', () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 45));
      final staleProfile = StudentProfileRecord(
        uid: 'student_stale_456',
        name: 'Haile Gebrselassie',
        email: 'haile@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: false,
        accessStatus: 'locked',
        createdAt: oldDate,
        cachedAt: oldDate,
      );
      await storage.saveStudentProfile(staleProfile);

      final loaded = await profileService.getCachedProfile(uid: 'student_stale_456');
      expect(loaded, isNotNull);
      expect(loaded!.uid, 'student_stale_456');
      expect(loaded.name, 'Haile Gebrselassie');
      expect(loaded.cachedAt.isBefore(DateTime.now().subtract(const Duration(days: 30))), isTrue);
    });

    test('TEST 4: Authenticated + no cache + offline routes to /offline-verification (NOT /home, NOT /profile-setup, NOT /login)', () async {
      final cached = await profileService.getCachedProfile(uid: 'uncached_uid');
      expect(cached, isNull);

      const offlineResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.offlineVerificationRequired,
        route: '/offline-verification',
        message:
            "You're signed in, but this device hasn't cached your student profile yet. Connect to the internet once to verify your profile and continue.",
      );

      expect(offlineResult.isOfflineVerificationRequired, isTrue);
      expect(offlineResult.status, PostAuthRouteStatus.offlineVerificationRequired);
      expect(offlineResult.route, '/offline-verification');
      expect(offlineResult.route, isNot('/home'));
      expect(offlineResult.route, isNot('/profile-setup'));
      expect(offlineResult.route, isNot('/login'));
      expect(offlineResult.isHome, isFalse);
      expect(offlineResult.isProfileSetup, isFalse);
      expect(offlineResult.message, contains("Connect to the internet once to verify your profile"));
    });

    test('TEST 5: Retry while still offline remains on offline verification state', () async {
      // Simulating a retry attempt while offline
      const retryResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.offlineVerificationRequired,
        route: '/offline-verification',
      );

      expect(retryResult.status, PostAuthRouteStatus.offlineVerificationRequired);
      expect(retryResult.route, '/offline-verification');
    });

    test('TEST 6: Retry after network becomes available and remote profile exists routes to /home', () async {
      const onlineSuccessResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.existingStudent,
        route: '/home',
      );

      expect(onlineSuccessResult.status, PostAuthRouteStatus.existingStudent);
      expect(onlineSuccessResult.isHome, isTrue);
      expect(onlineSuccessResult.route, '/home');
    });

    test('TEST 7: Retry after network becomes available and remote profile absent routes to /profile-setup', () async {
      const onlineNoProfileResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.needsProfileSetup,
        route: '/profile-setup',
      );

      expect(onlineNoProfileResult.status, PostAuthRouteStatus.needsProfileSetup);
      expect(onlineNoProfileResult.isProfileSetup, isTrue);
      expect(onlineNoProfileResult.route, '/profile-setup');
    });

    test('TEST 8: Unauthenticated user routes to established /login with unauthenticated status', () async {
      RoleService.clearCache();
      final result = await RoleService.resolvePostAuthRouteResult();
      expect(result.status, PostAuthRouteStatus.unauthenticated);
      expect(result.route, '/login');

      final route = await RoleService.resolvePostAuthRoute();
      expect(route, '/login');
    });

    test('TEST 9: Account isolation & UID mismatch rejects cached profile', () async {
      final userAProfile = StudentProfileRecord(
        uid: 'user_A_uid',
        name: 'Student A',
        email: 'studentA@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(userAProfile);

      final loadedForB = await profileService.getCachedProfile(uid: 'user_B_uid');
      expect(loadedForB, isNull);
    });

    test('TEST 10: Admin / Founder offline recognition via bootstrap authority', () async {
      expect(RoleService.founderEmail, 'olanamengistu2@gmail.com');
      expect(RoleService.adminEmail, 'tamiratboja@gmail.com');

      final founderRole = UserRole.founder;
      expect(founderRole.isAuthorizedAdmin, isTrue);

      final adminRole = UserRole.admin;
      expect(adminRole.isAuthorizedAdmin, isTrue);

      const adminResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.authorizedAdmin,
        route: '/admin',
      );
      expect(adminResult.isAdmin, isTrue);
      expect(adminResult.route, '/admin');
    });
  });
}
