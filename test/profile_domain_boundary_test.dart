import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/profile/data/profile_service.dart';

void main() {
  late OfflineStorageService storage;
  late ProfileService profileService;

  setUp(() async {
    storage = OfflineStorageService();
    await storage.clearLocalDataForTesting();
    await storage.init(forceReload: true);
    profileService = ProfileService(storage: storage);
  });

  tearDown(() async {
    await storage.clearLocalDataForTesting();
  });

  group('Step 0.6 — Profile Domain Boundary Tests', () {
    test('TEST 1: getCachedProfile returns null when no cache exists', () async {
      final result = await profileService.getCachedProfile(uid: 'unknown_uid_999');
      expect(result, isNull);
    });

    test('TEST 2: getCachedProfile returns cached student profile correctly', () async {
      final record = StudentProfileRecord(
        uid: 'student_boundary_1',
        name: 'Kenenisa Bekele',
        email: 'kenenisa@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        createdAt: DateTime.now(),
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(record);

      final loaded = await profileService.getCachedProfile(uid: 'student_boundary_1');
      expect(loaded, isNotNull);
      expect(loaded!.uid, 'student_boundary_1');
      expect(loaded.name, 'Kenenisa Bekele');
      expect(loaded.email, 'kenenisa@example.com');
      expect(loaded.grade, 'Grade 12');
      expect(loaded.stream, 'natural');
      expect(loaded.isPaid, isTrue);
      expect(loaded.accessStatus, 'active');
    });

    test('TEST 3: getProfile without forceRefresh serves valid cache immediately (offline-safe)', () async {
      final record = StudentProfileRecord(
        uid: 'student_offline_safe',
        name: 'Tirunesh Dibaba',
        email: 'tirunesh@example.com',
        grade: 'Grade 11',
        stream: 'social',
        isPaid: false,
        accessStatus: 'locked',
        createdAt: DateTime.now(),
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(record);

      // Call getProfile without network connection / Firestore
      final loaded = await profileService.getProfile(uid: 'student_offline_safe');
      expect(loaded, isNotNull);
      expect(loaded!.uid, 'student_offline_safe');
      expect(loaded.name, 'Tirunesh Dibaba');
      expect(loaded.grade, 'Grade 11');
      expect(loaded.stream, 'social');
    });

    test('TEST 4: profileExists returns true when valid local cache exists', () async {
      final record = StudentProfileRecord(
        uid: 'student_exists_cache',
        name: 'Sileshi Sihine',
        email: 'sileshi@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(record);

      final exists = await profileService.profileExists(uid: 'student_exists_cache');
      expect(exists, isTrue);
    });

    test('TEST 5: profileExists returns false for unauthenticated or non-existent student', () async {
      final exists = await profileService.profileExists(uid: 'non_existent_uid_000');
      expect(exists, isFalse);
    });

    test('TEST 6: UID isolation in profile cache', () async {
      final profileA = StudentProfileRecord(
        uid: 'student_user_A',
        name: 'Student A',
        email: 'a@example.com',
        grade: 'Grade 10',
        stream: 'natural',
        cachedAt: DateTime.now(),
      );
      final profileB = StudentProfileRecord(
        uid: 'student_user_B',
        name: 'Student B',
        email: 'b@example.com',
        grade: 'Grade 12',
        stream: 'social',
        cachedAt: DateTime.now(),
      );

      await storage.saveStudentProfile(profileA);
      await storage.saveStudentProfile(profileB);

      final loadedA = await profileService.getCachedProfile(uid: 'student_user_A');
      final loadedB = await profileService.getCachedProfile(uid: 'student_user_B');

      expect(loadedA?.name, 'Student A');
      expect(loadedA?.stream, 'natural');
      expect(loadedB?.name, 'Student B');
      expect(loadedB?.stream, 'social');
    });

    test('TEST 7: getProfileData backward compatible adapter returns mapped data', () async {
      final record = StudentProfileRecord(
        uid: 'student_adapter_test',
        name: 'Meseret Defar',
        email: 'meseret@example.com',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        cachedAt: DateTime.now(),
      );
      await storage.saveStudentProfile(record);

      final map = await profileService.getProfileData(uid: 'student_adapter_test');
      expect(map, isNotNull);
      expect(map!['name'], 'Meseret Defar');
      expect(map['email'], 'meseret@example.com');
      expect(map['grade'], 'Grade 12');
      expect(map['stream'], 'natural');
      expect(map['isPaid'], isTrue);
      expect(map['accessStatus'], 'active');
    });

    test('TEST 8: StudentProfileRecord copyWith maintains immutable fields when updated', () {
      final original = StudentProfileRecord(
        uid: 'immutable_test_uid',
        name: 'Almaz Ayana',
        email: 'almaz@example.com',
        grade: 'Grade 11',
        stream: 'natural',
        isPaid: false,
        accessStatus: 'locked',
        createdAt: DateTime(2026, 1, 1),
        cachedAt: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(
        name: 'Almaz Ayana Updated',
        grade: 'Grade 12',
      );

      expect(updated.uid, 'immutable_test_uid');
      expect(updated.name, 'Almaz Ayana Updated');
      expect(updated.grade, 'Grade 12');
      expect(updated.stream, 'natural'); // stream unchanged
      expect(updated.email, 'almaz@example.com');
      expect(updated.isPaid, isFalse);
    });
  });
}
