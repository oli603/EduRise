import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/profile/data/profile_service.dart';

void main() {
  late OfflineStorageService storage;

  setUp(() async {
    storage = OfflineStorageService();
    await storage.clearLocalDataForTesting();
    await storage.init(forceReload: true);
  });

  tearDown(() async {
    await storage.clearLocalDataForTesting();
  });

  group('StudentProfileRecord Model Tests', () {
    test('TEST 8: Real existing fields survive serialization and deserialization', () {
      final now = DateTime.now();
      final createdAt = now.subtract(const Duration(days: 30));
      final updatedAt = now.subtract(const Duration(days: 2));
      final paidAt = now.subtract(const Duration(days: 5));

      final original = StudentProfileRecord(
        uid: 'user_real_123',
        name: 'Abebe Bikila',
        email: 'abebe@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        createdAt: createdAt,
        updatedAt: updatedAt,
        paidAt: paidAt,
        activePaymentId: 'pay_sub_999',
        activeDeviceId: 'device_xyz_888',
        cachedAt: now,
      );

      final map = original.toMap();
      final fromMap = StudentProfileRecord.fromMap(map);

      expect(fromMap.uid, 'user_real_123');
      expect(fromMap.name, 'Abebe Bikila');
      expect(fromMap.email, 'abebe@example.com');
      expect(fromMap.grade, 'Grade 12');
      expect(fromMap.stream, 'natural');
      expect(fromMap.isPaid, true);
      expect(fromMap.accessStatus, 'active');
      expect(fromMap.activePaymentId, 'pay_sub_999');
      expect(fromMap.activeDeviceId, 'device_xyz_888');
      expect(fromMap.createdAt?.toIso8601String(), createdAt.toIso8601String());
      expect(fromMap.updatedAt?.toIso8601String(), updatedAt.toIso8601String());
      expect(fromMap.paidAt?.toIso8601String(), paidAt.toIso8601String());
      expect(fromMap.cachedAt.toIso8601String(), now.toIso8601String());
    });

    test('StudentProfileRecord.fromFirestore parses Firestore types correctly', () {
      final now = DateTime.now();
      final firestoreMap = {
        'name': ' Chala Bulto ',
        'email': 'chala@example.com',
        'grade': '12',
        'stream': 'Social Science',
        'isPaid': true,
        'accessStatus': 'active',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'paidAt': Timestamp.fromDate(now),
        'activePaymentId': 'pay_123',
        'activeDeviceId': 'device_abc',
      };

      final record = StudentProfileRecord.fromFirestore('student_uid_777', firestoreMap);

      expect(record.uid, 'student_uid_777');
      expect(record.name, 'Chala Bulto');
      expect(record.email, 'chala@example.com');
      expect(record.grade, '12');
      expect(record.stream, 'Social Science');
      expect(record.isPaid, true);
      expect(record.accessStatus, 'active');
      expect(record.activePaymentId, 'pay_123');
      expect(record.activeDeviceId, 'device_abc');
    });

    test('copyWith works correctly', () {
      final original = StudentProfileRecord(
        uid: 'user_orig',
        name: 'Original Name',
        email: 'orig@example.com',
        grade: 'Grade 11',
        stream: 'natural',
        cachedAt: DateTime.now(),
      );

      final updated = original.copyWith(
        name: 'Updated Name',
        grade: 'Grade 12',
        isPaid: true,
        accessStatus: 'active',
      );

      expect(updated.uid, 'user_orig');
      expect(updated.name, 'Updated Name');
      expect(updated.grade, 'Grade 12');
      expect(updated.isPaid, true);
      expect(updated.accessStatus, 'active');
      expect(updated.email, 'orig@example.com');
      expect(updated.stream, 'natural');
    });
  });

  group('Offline Storage Profile Persistence Tests', () {
    test('TEST 1: Save and load profile matching values', () async {
      final profile = StudentProfileRecord(
        uid: 'student_test_1',
        name: 'Tigist Assefa',
        email: 'tigist@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: false,
        accessStatus: 'locked',
        cachedAt: DateTime.now(),
      );

      await storage.saveStudentProfile(profile);

      final loaded = await storage.getStudentProfile('student_test_1');
      expect(loaded, isNotNull);
      expect(loaded!.uid, 'student_test_1');
      expect(loaded.name, 'Tigist Assefa');
      expect(loaded.email, 'tigist@example.com');
      expect(loaded.grade, 'Grade 12');
      expect(loaded.stream, 'natural');
      expect(loaded.isPaid, false);
      expect(loaded.accessStatus, 'locked');
    });

    test('TEST 2: Missing profile returns null safely', () async {
      final loaded = await storage.getStudentProfile('non_existent_uid');
      expect(loaded, isNull);

      final emptyLoaded = await storage.getStudentProfile('');
      expect(emptyLoaded, isNull);
    });

    test('TEST 3: Restart persistence (recreate/reinitialize storage)', () async {
      final profile = StudentProfileRecord(
        uid: 'student_persist_1',
        name: 'Kenenisa Bekele',
        email: 'kenenisa@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );

      await storage.saveStudentProfile(profile);

      // Simulate app restart by forcing reload
      final restartedStorage = OfflineStorageService();
      await restartedStorage.init(forceReload: true);

      final loaded = await restartedStorage.getStudentProfile('student_persist_1');
      expect(loaded, isNotNull);
      expect(loaded!.uid, 'student_persist_1');
      expect(loaded.name, 'Kenenisa Bekele');
      expect(loaded.isPaid, true);
      expect(loaded.accessStatus, 'active');
    });

    test('TEST 4: Account isolation (User A vs User B)', () async {
      final profileA = StudentProfileRecord(
        uid: 'user_A',
        name: 'User Alpha',
        email: 'alpha@example.com',
        grade: 'Grade 11',
        stream: 'social',
        isPaid: false,
        accessStatus: 'locked',
        cachedAt: DateTime.now(),
      );

      final profileB = StudentProfileRecord(
        uid: 'user_B',
        name: 'User Beta',
        email: 'beta@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );

      await storage.saveStudentProfile(profileA);
      await storage.saveStudentProfile(profileB);

      final loadedA = await storage.getStudentProfile('user_A');
      final loadedB = await storage.getStudentProfile('user_B');

      expect(loadedA, isNotNull);
      expect(loadedA!.name, 'User Alpha');
      expect(loadedA.uid, 'user_A');
      expect(loadedA.isPaid, false);

      expect(loadedB, isNotNull);
      expect(loadedB!.name, 'User Beta');
      expect(loadedB.uid, 'user_B');
      expect(loadedB.isPaid, true);
    });

    test('TEST 5: Wrong UID protection', () async {
      final profile = StudentProfileRecord(
        uid: 'user_correct_uid',
        name: 'Target User',
        email: 'target@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        cachedAt: DateTime.now(),
      );

      await storage.saveStudentProfile(profile);

      // Requesting a different UID should never return another user's profile
      final loaded = await storage.getStudentProfile('user_wrong_uid');
      expect(loaded, isNull);
    });

    test('TEST 6: Corrupt JSON fails safely without crash', () async {
      final dir = await storage.storageDirectory;
      final file = File('${dir.path}/student_profiles.json');
      await file.writeAsString('{{{ INVALID MALFORMED JSON %%%');

      // Reinitialize storage with corrupt file
      await storage.init(forceReload: true);

      final loaded = await storage.getStudentProfile('any_uid');
      expect(loaded, isNull);
    });

    test('TEST 7: Profile update preserves latest values', () async {
      final initialProfile = StudentProfileRecord(
        uid: 'student_update_1',
        name: 'Old Name',
        email: 'old@example.com',
        grade: 'Grade 11',
        stream: 'natural',
        isPaid: false,
        accessStatus: 'locked',
        cachedAt: DateTime.now(),
      );

      await storage.saveStudentProfile(initialProfile);

      final updatedProfile = initialProfile.copyWith(
        name: 'New Name',
        grade: 'Grade 12',
        isPaid: true,
        accessStatus: 'active',
        updatedAt: DateTime.now(),
      );

      await storage.saveStudentProfile(updatedProfile);

      // Verify immediate memory and disk persistence
      final loaded = await storage.getStudentProfile('student_update_1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'New Name');
      expect(loaded.grade, 'Grade 12');
      expect(loaded.isPaid, true);
      expect(loaded.accessStatus, 'active');

      // Verify persistence across reload
      await storage.init(forceReload: true);
      final reloaded = await storage.getStudentProfile('student_update_1');
      expect(reloaded, isNotNull);
      expect(reloaded!.name, 'New Name');
      expect(reloaded.grade, 'Grade 12');
      expect(reloaded.isPaid, true);
    });

    test('TEST 9: Asynchronous storage APIs operate properly', () async {
      final profile = StudentProfileRecord(
        uid: 'async_student',
        name: 'Async Student',
        email: 'async@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        cachedAt: DateTime.now(),
      );

      // Perform async save and get
      final saveFuture = storage.saveStudentProfile(profile);
      expect(saveFuture, isA<Future<void>>());
      await saveFuture;

      final getFuture = storage.getStudentProfile('async_student');
      expect(getFuture, isA<Future<StudentProfileRecord?>>());
      final result = await getFuture;
      expect(result, isNotNull);
      expect(result!.uid, 'async_student');

      // Remove profile
      await storage.removeStudentProfile('async_student');
      final removed = await storage.getStudentProfile('async_student');
      expect(removed, isNull);
    });
  });

  group('ProfileService Caching Boundary Tests', () {
    test('getCachedProfile returns local cache by explicit UID', () async {
      final profileService = ProfileService(storage: storage);

      final cached = StudentProfileRecord(
        uid: 'cached_student_99',
        name: 'Cached Student',
        email: 'cached@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );

      await storage.saveStudentProfile(cached);

      final result = await profileService.getCachedProfile(uid: 'cached_student_99');
      expect(result, isNotNull);
      expect(result!.name, 'Cached Student');
      expect(result.uid, 'cached_student_99');
      expect(result.isPaid, true);

      // Missing UID returns null safely
      final nonExistent = await profileService.getCachedProfile(uid: 'unknown_uid');
      expect(nonExistent, isNull);
    });
  });
}
