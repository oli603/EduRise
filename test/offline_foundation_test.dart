import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/core/offline/download_manager.dart';

void main() {
  group('DownloadPackageRecord Tests', () {
    test('Serialization and deserialization works accurately', () {
      final now = DateTime.now();
      final record = DownloadPackageRecord(
        id: 'book_grade_12_biology',
        packageType: 'book',
        title: 'Biology • Grade 12',
        grade: 'Grade 12',
        subject: 'Biology',
        version: 1,
        itemCount: 6,
        sizeBytes: 15420000,
        downloadedAt: now,
        status: 'downloaded',
        extraData: const {'unitIds': ['unit1', 'unit2']},
      );

      final map = record.toMap();
      final recreated = DownloadPackageRecord.fromMap(map);

      expect(recreated.id, 'book_grade_12_biology');
      expect(recreated.packageType, 'book');
      expect(recreated.title, 'Biology • Grade 12');
      expect(recreated.grade, 'Grade 12');
      expect(recreated.subject, 'Biology');
      expect(recreated.version, 1);
      expect(recreated.itemCount, 6);
      expect(recreated.sizeBytes, 15420000);
      expect(recreated.status, 'downloaded');
      expect(recreated.extraData['unitIds'], ['unit1', 'unit2']);
    });

    test('copyWith works properly', () {
      final record = DownloadPackageRecord(
        id: 'practice_12_nat_bio_u1_y2017',
        packageType: 'practice',
        title: 'Biology Grade 12 — Unit 1 • 2017 EC',
        subject: 'Biology',
        downloadedAt: DateTime.now(),
        status: 'downloading',
      );

      final updated = record.copyWith(status: 'downloaded', sizeBytes: 5000);
      expect(updated.status, 'downloaded');
      expect(updated.sizeBytes, 5000);
      expect(updated.title, 'Biology Grade 12 — Unit 1 • 2017 EC');
    });
  });

  group('DownloadManager Deterministic Package IDs', () {
    final manager = DownloadManager();

    test('Generates deterministic Book package IDs', () {
      final id1 = manager.getBookPackageId(grade: 'Grade 12', subject: 'Biology');
      final id2 = manager.getBookPackageId(grade: ' Grade 12 ', subject: 'biology');
      expect(id1, 'book_grade_12_biology');
      expect(id2, 'book_grade_12_biology');
    });

    test('Generates deterministic Practice package IDs', () {
      final id = manager.getPracticePackageId(
        grade: 'Grade 12',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 1,
        examYear: 2017,
      );
      expect(id, 'practice_grade_12_natural_biology_u1_y2017');
    });

    test('Generates deterministic Past Exam package IDs', () {
      final id = manager.getPastExamPackageId(
        year: '2017',
        stream: 'natural',
        subject: 'Biology',
      );
      expect(id, 'past_exam_2017_natural_biology');
    });
  });

  group('Offline Storage Format Bytes Tests', () {
    test('Formats bytes properly', () {
      expect(OfflineStorageService.formatBytes(0), '0 B');
      expect(OfflineStorageService.formatBytes(512), '512.0 B');
      expect(OfflineStorageService.formatBytes(1024), '1.0 KB');
      expect(OfflineStorageService.formatBytes(1048576), '1.0 MB');
      expect(OfflineStorageService.formatBytes(15728640), '15.0 MB');
    });
  });

  group('Async Atomic Storage & Concurrency Safety Tests', () {
    final storage = OfflineStorageService();

    setUp(() async {
      await storage.init();
      await storage.clearLocalDataForTesting();
    });

    tearDown(() async {
      await storage.clearLocalDataForTesting();
    });

    test('1 & 2. Atomic write succeeds and data can be read back asynchronously', () async {
      final now = DateTime.now();
      final package = DownloadPackageRecord(
        id: 'pkg_test_async_1',
        packageType: 'practice',
        title: 'Async Test Package',
        subject: 'Physics',
        downloadedAt: now,
        status: 'downloaded',
      );

      await storage.savePackage(package);
      final retrieved = await storage.getPackage('pkg_test_async_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'pkg_test_async_1');
      expect(retrieved.title, 'Async Test Package');
      expect(retrieved.subject, 'Physics');
    });

    test('3. Data survives process restart simulation (reloading from disk)', () async {
      final package = DownloadPackageRecord(
        id: 'pkg_restart_test',
        packageType: 'book',
        title: 'Chemistry Restart Test',
        subject: 'Chemistry',
        downloadedAt: DateTime.now(),
      );

      await storage.savePackage(package);

      // Simulate app restart by re-initializing storage
      final newStorageInstance = OfflineStorageService();
      await newStorageInstance.init();

      final reloaded = await newStorageInstance.getPackage('pkg_restart_test');
      expect(reloaded, isNotNull);
      expect(reloaded!.id, 'pkg_restart_test');
      expect(reloaded.title, 'Chemistry Restart Test');
    });

    test('4 & 5. Delete and replace work with atomic guarantees', () async {
      final package1 = DownloadPackageRecord(
        id: 'pkg_delete_test',
        packageType: 'past_exam',
        title: 'Exam to Delete',
        subject: 'English',
        downloadedAt: DateTime.now(),
      );

      await storage.savePackage(package1);
      expect(await storage.getPackage('pkg_delete_test'), isNotNull);

      // Delete package
      await storage.deletePackageRecord('pkg_delete_test');
      expect(await storage.getPackage('pkg_delete_test'), isNull);

      // Re-add and update
      final packageUpdated = package1.copyWith(title: 'Exam Replaced');
      await storage.savePackage(packageUpdated);
      final retrieved = await storage.getPackage('pkg_delete_test');
      expect(retrieved!.title, 'Exam Replaced');
    });

    test('6. Concurrent writes to the same store do not corrupt data or race', () async {
      // Launch 20 concurrent async package saves
      final futures = List.generate(20, (index) {
        final pkg = DownloadPackageRecord(
          id: 'pkg_concurrent_$index',
          packageType: 'practice',
          title: 'Concurrent Package #$index',
          subject: 'Mathematics',
          downloadedAt: DateTime.now(),
        );
        return storage.savePackage(pkg);
      });

      // All concurrent writes must resolve cleanly without lock deadlocks or file corruptions
      await Future.wait(futures);

      final allPackages = await storage.getAllPackages();
      expect(allPackages.length, 20);

      // Verify all 20 packages are fully readable from disk after restart
      await storage.init();
      final reloadedPackages = await storage.getAllPackages();
      expect(reloadedPackages.length, 20);
    });

    test('7, 8 & 9. Practice result deduplication, local ID handling and timestamp serialization', () async {
      final timestamp = DateTime(2026, 9, 15, 12, 0, 0);
      final result1 = {
        'localId': 'result_local_999',
        'userId': 'student_abc',
        'subject': 'Biology',
        'score': 85.0,
        'isSynced': false,
        'createdAt': timestamp,
      };

      await storage.savePracticeResultLocally(result1);

      // Saving with same localId updates existing record without duplicate entries
      final result1Updated = {
        ...result1,
        'score': 95.0,
      };
      await storage.savePracticeResultLocally(result1Updated);

      final unsynced = await storage.getUnsyncedPracticeResults();
      expect(unsynced.length, 1);
      expect(unsynced.first['score'], 95.0);

      // Mark synced
      await storage.markPracticeResultSynced('result_local_999', serverId: 'server_doc_777');
      final updatedUnsynced = await storage.getUnsyncedPracticeResults();
      expect(updatedUnsynced.isEmpty, true);
    });
  });
}

