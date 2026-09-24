import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/constants/app_grades.dart';
import 'package:edurise/core/constants/app_subjects.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/profile/data/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EduRiseGrades Canonical Constants & Helpers', () {
    test('canonicalize normalizes various grade inputs correctly', () {
      expect(EduRiseGrades.canonicalize('Grade 9'), equals('Grade 9'));
      expect(EduRiseGrades.canonicalize('9'), equals('Grade 9'));
      expect(EduRiseGrades.canonicalize('grade 9'), equals('Grade 9'));
      expect(EduRiseGrades.canonicalize('Grade 10'), equals('Grade 10'));
      expect(EduRiseGrades.canonicalize('10'), equals('Grade 10'));
      expect(EduRiseGrades.canonicalize('Grade 11'), equals('Grade 11'));
      expect(EduRiseGrades.canonicalize('11'), equals('Grade 11'));
      expect(EduRiseGrades.canonicalize('Grade 12'), equals('Grade 12'));
      expect(EduRiseGrades.canonicalize('12'), equals('Grade 12'));
      expect(EduRiseGrades.canonicalize(null), equals('Grade 12'));
      expect(EduRiseGrades.canonicalize(''), equals('Grade 12'));
    });

    test('isValid correctly identifies valid and invalid grade values', () {
      expect(EduRiseGrades.isValid('Grade 9'), isTrue);
      expect(EduRiseGrades.isValid('Grade 10'), isTrue);
      expect(EduRiseGrades.isValid('Grade 11'), isTrue);
      expect(EduRiseGrades.isValid('Grade 12'), isTrue);
      expect(EduRiseGrades.isValid(null), isFalse);
      expect(EduRiseGrades.isValid('Grade 8'), isFalse);
    });

    test('all contains all four secondary curriculum grades in order', () {
      expect(EduRiseGrades.all, equals(['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12']));
    });
  });

  group('EduRiseSubjects Stream Canonicalization & Helpers', () {
    test('canonicalizeStream maps variations of Natural and Social streams', () {
      expect(EduRiseSubjects.canonicalizeStream('Natural Science'), equals('natural'));
      expect(EduRiseSubjects.canonicalizeStream('Natural'), equals('natural'));
      expect(EduRiseSubjects.canonicalizeStream('natural'), equals('natural'));
      expect(EduRiseSubjects.canonicalizeStream('Social Science'), equals('social'));
      expect(EduRiseSubjects.canonicalizeStream('Social'), equals('social'));
      expect(EduRiseSubjects.canonicalizeStream('social'), equals('social'));
      expect(EduRiseSubjects.canonicalizeStream(null), equals('natural'));
      expect(EduRiseSubjects.canonicalizeStream(''), equals('natural'));
    });

    test('displayStream maps canonical streams to student-friendly names', () {
      expect(EduRiseSubjects.displayStream('natural'), equals('Natural Science'));
      expect(EduRiseSubjects.displayStream('Natural Science'), equals('Natural Science'));
      expect(EduRiseSubjects.displayStream('social'), equals('Social Science'));
      expect(EduRiseSubjects.displayStream('Social Science'), equals('Social Science'));
    });

    test('isSocialStream accurately distinguishes streams', () {
      expect(EduRiseSubjects.isSocialStream('Social Science'), isTrue);
      expect(EduRiseSubjects.isSocialStream('social'), isTrue);
      expect(EduRiseSubjects.isSocialStream('Natural Science'), isFalse);
      expect(EduRiseSubjects.isSocialStream('natural'), isFalse);
      expect(EduRiseSubjects.isSocialStream(null), isFalse);
    });
  });

  group('Student Profile Persistence & Cache Synchronization', () {
    late OfflineStorageService storageService;

    setUp(() async {
      storageService = OfflineStorageService();
      await storageService.clearLocalDataForTesting();
      await storageService.init(forceReload: true);
    });

    tearDown(() async {
      await storageService.clearLocalDataForTesting();
    });

    test('Saving and retrieving StudentProfileRecord preserves all fields', () async {
      final now = DateTime.now();
      final record = StudentProfileRecord(
        uid: 'student_123',
        name: 'Abebe Bikila',
        email: 'abebe@edurise.edu',
        grade: 'Grade 12',
        stream: 'natural',
        isPaid: true,
        accessStatus: 'active',
        createdAt: now,
        cachedAt: now,
      );

      await storageService.saveStudentProfile(record);

      final retrieved = await storageService.getStudentProfile('student_123');
      expect(retrieved, isNotNull);
      expect(retrieved!.uid, equals('student_123'));
      expect(retrieved.name, equals('Abebe Bikila'));
      expect(retrieved.email, equals('abebe@edurise.edu'));
      expect(retrieved.grade, equals('Grade 12'));
      expect(retrieved.stream, equals('natural'));
      expect(retrieved.isPaid, isTrue);
      expect(retrieved.accessStatus, equals('active'));
    });

    test('Account A and Account B profile isolation in ProfileStore', () async {
      final now = DateTime.now();
      final profileA = StudentProfileRecord(
        uid: 'user_a_uid',
        name: 'Student A',
        email: 'student_a@edurise.edu',
        grade: 'Grade 11',
        stream: 'natural',
        cachedAt: now,
      );

      final profileB = StudentProfileRecord(
        uid: 'user_b_uid',
        name: 'Student B',
        email: 'student_b@edurise.edu',
        grade: 'Grade 12',
        stream: 'social',
        cachedAt: now,
      );

      await storageService.saveStudentProfile(profileA);
      await storageService.saveStudentProfile(profileB);

      // Verify A's profile
      final retrievedA = await storageService.getStudentProfile('user_a_uid');
      expect(retrievedA, isNotNull);
      expect(retrievedA!.uid, equals('user_a_uid'));
      expect(retrievedA.name, equals('Student A'));
      expect(retrievedA.stream, equals('natural'));

      // Verify B's profile
      final retrievedB = await storageService.getStudentProfile('user_b_uid');
      expect(retrievedB, isNotNull);
      expect(retrievedB!.uid, equals('user_b_uid'));
      expect(retrievedB.name, equals('Student B'));
      expect(retrievedB.stream, equals('social'));

      // Verify querying non-existent or wrong UID returns null
      final retrievedNone = await storageService.getStudentProfile('user_c_uid');
      expect(retrievedNone, isNull);
    });

    test('Updating profile grade updates cached StudentProfileRecord', () async {
      final now = DateTime.now();
      final record = StudentProfileRecord(
        uid: 'student_456',
        name: 'Derartu Tulu',
        grade: 'Grade 11',
        stream: 'natural',
        cachedAt: now,
      );

      await storageService.saveStudentProfile(record);

      final updated = record.copyWith(
        grade: EduRiseGrades.canonicalize('Grade 12'),
        updatedAt: DateTime.now(),
      );
      await storageService.saveStudentProfile(updated);

      final retrieved = await storageService.getStudentProfile('student_456');
      expect(retrieved, isNotNull);
      expect(retrieved!.grade, equals('Grade 12'));
      expect(retrieved.name, equals('Derartu Tulu'));
      expect(retrieved.stream, equals('natural'));
    });

    test('ProfileService with offline storage returns cached profile immediately', () async {
      final profile = StudentProfileRecord(
        uid: 'offline_student_01',
        name: 'Haile Gebrselassie',
        grade: 'Grade 12',
        stream: 'natural',
        cachedAt: DateTime.now(),
      );
      await storageService.saveStudentProfile(profile);

      final profileService = ProfileService(storage: storageService);
      final result = await profileService.getProfile(uid: 'offline_student_01');

      expect(result, isNotNull);
      expect(result!.uid, equals('offline_student_01'));
      expect(result.name, equals('Haile Gebrselassie'));
      expect(result.grade, equals('Grade 12'));
    });
  });
}
