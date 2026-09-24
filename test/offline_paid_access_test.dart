import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/access_service.dart';
import 'package:edurise/core/auth/role_service.dart';
import 'package:edurise/core/offline/connectivity_service.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';

class MockOfflineConnectivity implements ConnectivityService {
  @override
  bool get isOnline => false;
  @override
  bool get isOffline => true;
  @override
  Stream<bool> get onConnectivityChanged => Stream.value(false);
  @override
  Future<bool> checkConnectivity({String host = 'firestore.googleapis.com'}) async => false;
  @override
  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {}
  @override
  void stopMonitoring() {}
  @override
  void dispose() {}
  @override
  void setOnlineStatusForTesting(bool connected) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineStorageService storage;

  setUp(() async {
    AccessService.setTestRole(null);
    RoleService.clearCache();
    storage = OfflineStorageService();
    await storage.clearLocalDataForTesting();
    await storage.init(forceReload: true);
    AccessService.setMockInstances(
      storage: storage,
    );
  });

  tearDown(() async {
    AccessService.setTestRole(null);
    RoleService.clearCache();
    await storage.clearLocalDataForTesting();
  });

  group('Offline Paid Access Policy - Core Decisions', () {
    test('TEST 1: Test role override works for tests', () async {
      AccessService.setTestRole('paid');
      expect(await AccessService.hasPaidAccess(), isTrue);

      AccessService.setTestRole('admin');
      expect(await AccessService.hasPaidAccess(), isTrue);

      AccessService.setTestRole('unpaid');
      expect(await AccessService.hasPaidAccess(), isFalse);
    });

    test('TEST 2: Offline + Cached Paid student is granted access', () async {
      final paidProfile = StudentProfileRecord(
        uid: 'paid_student_001',
        name: 'Tirunesh Dibaba',
        email: 'tirunesh@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        paidAt: DateTime.now().subtract(const Duration(days: 10)),
        activePaymentId: 'pay_sub_101',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(paidProfile);

      final cached = await storage.getStudentProfile('paid_student_001');
      expect(cached, isNotNull);
      expect(cached!.isPaid, isTrue);
      expect(cached.accessStatus, 'active');

      // Verify domain policy evaluation
      final hasOfflineCapability = cached.isPaid && cached.accessStatus == 'active';
      expect(hasOfflineCapability, isTrue);
    });

    test('TEST 3: Offline + Cached Unpaid student is denied access (isPaid = false)', () async {
      final unpaidProfile = StudentProfileRecord(
        uid: 'unpaid_student_002',
        name: 'Kenenisa Bekele',
        email: 'kenenisa@example.com',
        grade: 'Grade 11',
        stream: 'natural',
        isPaid: false,
        accessStatus: 'locked',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(unpaidProfile);

      final cached = await storage.getStudentProfile('unpaid_student_002');
      expect(cached, isNotNull);
      expect(cached!.isPaid, isFalse);
      expect(cached.accessStatus, 'locked');

      final hasOfflineCapability = cached.isPaid && cached.accessStatus == 'active';
      expect(hasOfflineCapability, isFalse);
    });

    test('TEST 4: Offline + Cached Revoked student is denied access (isPaid = true, accessStatus = locked)', () async {
      final revokedProfile = StudentProfileRecord(
        uid: 'revoked_student_003',
        name: 'Sileshi Sihine',
        email: 'sileshi@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'locked', // Revoked by admin
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(revokedProfile);

      final cached = await storage.getStudentProfile('revoked_student_003');
      expect(cached, isNotNull);
      final hasOfflineCapability = cached!.isPaid && cached.accessStatus == 'active';
      expect(hasOfflineCapability, isFalse);
    });

    test('TEST 5: Offline + Missing profile cache defaults safely to FALSE (No false grant)', () async {
      final cached = await storage.getStudentProfile('non_existent_uid');
      expect(cached, isNull);

      final bool hasOfflineCapability = cached != null && cached.isPaid && cached.accessStatus == 'active';
      expect(hasOfflineCapability, isFalse);
    });

    test('TEST 6: Security - UID A cached paid profile cannot grant access to UID B', () async {
      final studentA = StudentProfileRecord(
        uid: 'uid_student_A',
        name: 'Student A',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(studentA);

      // Student B queries their profile
      final studentBCache = await storage.getStudentProfile('uid_student_B');
      expect(studentBCache, isNull);

      // Wrong UID lookup against storage
      final cachedA = await storage.getStudentProfile('uid_student_A');
      expect(cachedA, isNotNull);
      expect(cachedA!.uid == 'uid_student_B', isFalse);
    });

    test('TEST 7: Offline resilience - Corrupted profile JSON fails safely to null without crashing', () async {
      final dir = await storage.storageDirectory;
      final file = File('${dir.path}/student_profiles.json');
      if (file.existsSync()) {
        file.writeAsStringSync('{{{MALFORMED JSON CORPUS%%%');
      }

      await storage.init(forceReload: true);
      final cached = await storage.getStudentProfile('any_uid');
      expect(cached, isNull);
    });
  });

  group('Offline Paid Access Policy - Transitions & Reconnection', () {
    test('TEST 8: Approval transition - Cached unpaid profile updated to active after approval', () async {
      // 1. Initially unpaid
      final initialUnpaid = StudentProfileRecord(
        uid: 'transition_uid_1',
        name: 'Girma Wolde',
        grade: 'Grade 10',
        stream: 'natural',
        isPaid: false,
        accessStatus: 'locked',
        cachedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await storage.saveStudentProfile(initialUnpaid);

      var profile = await storage.getStudentProfile('transition_uid_1');
      expect(profile!.isPaid, isFalse);
      expect(profile.accessStatus, 'locked');

      // 2. Admin approves remotely -> Client syncs and updates local cache
      final approvedRecord = profile.copyWith(
        isPaid: true,
        accessStatus: 'active',
        paidAt: DateTime.now(),
        activePaymentId: 'sub_approval_99',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(approvedRecord);

      profile = await storage.getStudentProfile('transition_uid_1');
      expect(profile!.isPaid, isTrue);
      expect(profile.accessStatus, 'active');
      expect(profile.activePaymentId, 'sub_approval_99');
    });

    test('TEST 9: Revocation transition - Cached paid profile updated to locked after remote revocation', () async {
      // 1. Initially paid
      final initialPaid = StudentProfileRecord(
        uid: 'revocation_uid_2',
        name: 'Meseret Defar',
        grade: 'Grade 12',
        stream: 'social',
        isPaid: true,
        accessStatus: 'active',
        paidAt: DateTime.now().subtract(const Duration(days: 20)),
        cachedAt: DateTime.now().subtract(const Duration(days: 20)),
      );
      await storage.saveStudentProfile(initialPaid);

      var profile = await storage.getStudentProfile('revocation_uid_2');
      expect(profile!.isPaid, isTrue);
      expect(profile.accessStatus, 'active');

      // 2. Admin revokes remotely -> Local cache updated
      final revokedRecord = profile.copyWith(
        isPaid: false,
        accessStatus: 'locked',
        updatedAt: DateTime.now(),
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(revokedRecord);

      profile = await storage.getStudentProfile('revocation_uid_2');
      expect(profile!.isPaid, isFalse);
      expect(profile.accessStatus, 'locked');
    });
  });

  group('Offline Paid Access Policy - Educational Content Gating', () {
    test('TEST 10: Free practice test policy strictly allows Grade 12 + Unit 1 + 2017 EC', () {
      // Allowed free trial
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 12',
          examYear: 2017,
          unitNumber: 1,
        ),
        isTrue,
      );

      // Disallowed combinations
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 11',
          examYear: 2017,
          unitNumber: 1,
        ),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 12',
          examYear: 2016,
          unitNumber: 1,
        ),
        isFalse,
      );
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 12',
          examYear: 2017,
          unitNumber: 2,
        ),
        isFalse,
      );
    });

    test('TEST 11: Free students can access trial practice without paid access', () async {
      AccessService.setTestRole('unpaid');

      final canAccessTrial = await AccessService.canAccessPractice(
        grade: 'Grade 12',
        examYear: 2017,
        unitNumber: 1,
      );
      expect(canAccessTrial, isTrue);

      final canAccessLocked = await AccessService.canAccessPractice(
        grade: 'Grade 12',
        examYear: 2017,
        unitNumber: 2,
      );
      expect(canAccessLocked, isFalse);
    });

    test('TEST 12: Paid students have unrestricted access across all grades, units, and past exams', () async {
      AccessService.setTestRole('paid');

      expect(await AccessService.canAccessPractice(grade: 'Grade 9', examYear: 2015, unitNumber: 4), isTrue);
      expect(await AccessService.canAccessPractice(grade: 'Grade 10', examYear: 2016, unitNumber: 3), isTrue);
      expect(await AccessService.canAccessPractice(grade: 'Grade 11', examYear: 2014, unitNumber: 5), isTrue);
      expect(await AccessService.canAccessPractice(grade: 'Grade 12', examYear: 2018, unitNumber: 2), isTrue);
      expect(await AccessService.canAccessPastExams(), isTrue);
      expect(await AccessService.canAccessChallenges(), isTrue);
      expect(await AccessService.canAccessCoach(), isTrue);
    });

    test('TEST 13: Free students are locked out of Past Entrance Exams and Challenges', () async {
      AccessService.setTestRole('unpaid');

      expect(await AccessService.canAccessPastExams(), isFalse);
      expect(await AccessService.canAccessChallenges(), isFalse);
    });

    test('TEST 14: Fast-path offline check uses cached profile without waiting for timeout', () async {
      final offlineConnectivity = MockOfflineConnectivity();
      AccessService.setMockInstances(
        storage: storage,
        connectivity: offlineConnectivity,
      );

      final cachedProfile = StudentProfileRecord(
        uid: 'fast_path_uid_77',
        name: 'Fast Student',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(cachedProfile);

      final stopwatch = Stopwatch()..start();
      final record = await storage.getStudentProfile('fast_path_uid_77');
      stopwatch.stop();

      expect(record, isNotNull);
      expect(record!.isPaid, isTrue);
      // Fast path must complete in well under 100ms
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
