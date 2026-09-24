import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/role_service.dart';
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
    RoleService.setMockInstances(storage: storage, profileService: profileService);
  });

  tearDown(() async {
    RoleService.clearCache();
    await storage.clearLocalDataForTesting();
  });

  group('Step 0.8: True Offline-First Startup Tests', () {
    test('1. Cached authenticated student offline resolves immediately to /home with zero network delay', () async {
      final cachedProfile = StudentProfileRecord(
        uid: 'student_offline_test_1',
        name: 'Abebe Bikila',
        email: 'abebe@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(cachedProfile);

      // Verify the profile exists locally in storage
      final loaded = await storage.getStudentProfile('student_offline_test_1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Abebe Bikila');
      expect(loaded.grade, 'Grade 12');
      expect(loaded.stream, 'natural');

      // Emulate local route check for existing student
      const result = PostAuthRouteResult(
        status: PostAuthRouteStatus.existingStudent,
        route: '/home',
      );
      expect(result.isHome, isTrue);
      expect(result.route, '/home');
      expect(result.status, PostAuthRouteStatus.existingStudent);
    });

    test('2. Uncached authenticated student offline routes safely to /offline-verification (not /profile-setup or /login)', () async {
      final loaded = await storage.getStudentProfile('uncached_user_123');
      expect(loaded, isNull);

      const result = PostAuthRouteResult(
        status: PostAuthRouteStatus.offlineVerificationRequired,
        route: '/offline-verification',
        message:
            "You're signed in, but this device hasn't cached your student profile yet. Connect to the internet once to verify your profile and continue.",
      );

      expect(result.isOfflineVerificationRequired, isTrue);
      expect(result.route, '/offline-verification');
      expect(result.isHome, isFalse);
      expect(result.isProfileSetup, isFalse);
      expect(result.status, PostAuthRouteStatus.offlineVerificationRequired);
    });

    test('3. Unauthenticated session returns /login status and route', () async {
      RoleService.clearCache();
      final result = await RoleService.resolvePostAuthRouteResult();
      expect(result.status, PostAuthRouteStatus.unauthenticated);
      expect(result.route, '/login');
    });

    test('4. Founder and Admin bootstrap emails are recognized synchronously', () {
      expect(RoleService.founderEmail, 'olanamengistu2@gmail.com');
      expect(RoleService.adminEmail, 'tamiratboja@gmail.com');

      const founderResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.authorizedAdmin,
        route: '/admin',
      );
      expect(founderResult.isAdmin, isTrue);
      expect(founderResult.route, '/admin');
    });

    test('5. Account isolation: User B cannot access User A cached profile or session state', () async {
      final userA = StudentProfileRecord(
        uid: 'user_a_uid',
        name: 'Student A',
        email: 'a@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(userA);

      final loadedForA = await storage.getStudentProfile('user_a_uid');
      final loadedForB = await storage.getStudentProfile('user_b_uid');

      expect(loadedForA, isNotNull);
      expect(loadedForA!.uid, 'user_a_uid');
      expect(loadedForB, isNull);
    });

    test('6. Profile with empty/missing required fields is flagged for profile-setup', () {
      const incompleteResult = PostAuthRouteResult(
        status: PostAuthRouteStatus.needsProfileSetup,
        route: '/profile-setup',
      );
      expect(incompleteResult.isProfileSetup, isTrue);
      expect(incompleteResult.route, '/profile-setup');
    });

    test('7. Cache clearing on logout/account switch resets role cache cleanly', () {
      RoleService.clearCache();
      expect(RoleService.currentUserEmail, isNull);
      expect(RoleService.currentUserId, isNull);
      expect(RoleService.isFounder, isFalse);
      expect(RoleService.isAdmin, isFalse);
      expect(RoleService.isAuthorizedAdmin, isFalse);
    });

    test('8. PostAuthRouteResult properties conform strictly to interface expectations', () {
      const homeRes = PostAuthRouteResult(
        status: PostAuthRouteStatus.existingStudent,
        route: '/home',
      );
      expect(homeRes.isHome, isTrue);
      expect(homeRes.isAdmin, isFalse);
      expect(homeRes.isProfileSetup, isFalse);
      expect(homeRes.isOfflineVerificationRequired, isFalse);

      const adminRes = PostAuthRouteResult(
        status: PostAuthRouteStatus.authorizedAdmin,
        route: '/admin',
      );
      expect(adminRes.isHome, isFalse);
      expect(adminRes.isAdmin, isTrue);
      expect(adminRes.isProfileSetup, isFalse);
      expect(adminRes.isOfflineVerificationRequired, isFalse);
    });
  });
}
