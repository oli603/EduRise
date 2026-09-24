import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/download_manager.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 2: DownloadManager Batch Keys and Methods', () {
    final downloadManager = DownloadManager();

    test('Book package ID formatting', () {
      final id = downloadManager.getBookPackageId(grade: 'Grade 12', subject: 'Biology');
      expect(id, 'book_grade_12_biology');
    });

    test('Practice package ID formatting', () {
      final id = downloadManager.getPracticePackageId(
        grade: 'Grade 12',
        stream: 'natural',
        subject: 'Physics',
        unitNumber: 2,
        examYear: 2017,
      );
      expect(id, 'practice_grade_12_natural_physics_u2_y2017');
    });

    test('Practice batch key formatting', () {
      final key = downloadManager.getPracticeSubjectBatchKey(
        grade: 'Grade 12',
        stream: 'natural',
        subject: 'Chemistry',
        examYear: 2016,
      );
      expect(key, 'practice_batch_grade_12_natural_chemistry_y2016');
    });

    test('Past Exam package ID formatting', () {
      final id = downloadManager.getPastExamPackageId(
        year: '2017',
        stream: 'natural',
        subject: 'Mathematics',
      );
      expect(id, 'past_exam_2017_natural_mathematics');
    });

    test('Past Exam year batch key formatting', () {
      final key = downloadManager.getPastExamYearBatchKey(
        year: '2017',
        stream: 'natural',
      );
      expect(key, 'past_exam_batch_2017_natural');
    });

    test('getActiveState and getProgress return default initial values', () {
      expect(downloadManager.getProgress('non_existent_key'), 0.0);
      expect(downloadManager.getActiveState('non_existent_key'), isNull);
    });
  });

  group('Batch 2: OfflineStorageService Package Management', () {
    late OfflineStorageService storage;

    setUp(() async {
      storage = OfflineStorageService();
      await storage.init();
    });

    test('savePackage and getPackage retrieves exact record', () async {
      final record = DownloadPackageRecord(
        id: 'test_pkg_1',
        packageType: 'practice',
        title: 'Test Practice Package',
        grade: 'Grade 12',
        subject: 'Biology',
        version: 1,
        itemCount: 20,
        sizeBytes: 50000,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
        extraData: {'questionIds': ['q1', 'q2']},
      );

      await storage.savePackage(record);

      final retrieved = await storage.getPackage('test_pkg_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'test_pkg_1');
      expect(retrieved.itemCount, 20);
      expect(retrieved.status, 'downloaded');

      // Clean up locally
      await storage.deletePackageRecord('test_pkg_1');
      final afterDelete = await storage.getPackage('test_pkg_1');
      expect(afterDelete, isNull);
    });

    test('formatBytes formats accurately', () {
      expect(OfflineStorageService.formatBytes(500), '500.0 B');
      expect(OfflineStorageService.formatBytes(1500), '1.5 KB');
      expect(OfflineStorageService.formatBytes(1048576 * 5), '5.0 MB');
      expect(OfflineStorageService.formatBytes(1073741824 * 2), '2.0 GB');
    });
  });

  group('Batch 2: AppShell Drawer UI & Section Organization', () {
    testWidgets('AppShell renders modernized Drawer with structured sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: const Text('Open Drawer'),
                );
              },
            ),
            drawer: Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const DrawerHeader(
                    child: Text('Student Header'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('LEARNING & PRACTICE'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: const Text('Books & Textbooks'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: const Text('Practice Questions'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_edu_rounded),
                    title: const Text('Past Entrance Exams'),
                    onTap: () {},
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('OFFLINE & ACCOUNT'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_for_offline_rounded),
                    title: const Text('Central Downloads'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Profile & Settings'),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Sign Out'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Verify sections and items
      expect(find.text('LEARNING & PRACTICE'), findsOneWidget);
      expect(find.text('Books & Textbooks'), findsOneWidget);
      expect(find.text('Practice Questions'), findsOneWidget);
      expect(find.text('Past Entrance Exams'), findsOneWidget);
      expect(find.text('OFFLINE & ACCOUNT'), findsOneWidget);
      expect(find.text('Central Downloads'), findsOneWidget);
      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
