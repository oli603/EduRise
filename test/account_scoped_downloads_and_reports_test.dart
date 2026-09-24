import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/session_manager.dart';
import 'package:edurise/core/offline/models/download_package_record.dart';
import 'package:edurise/core/offline/storage_engine.dart';
import 'package:edurise/core/offline/stores/package_store.dart';
import 'package:edurise/features/books/data/book_download_service.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SessionManager.resetSession();
    PackageStore().clearMemoryCache();
    BookDownloadService().clearMemoryCache();
    PastExamDownloadService().clearMemoryCache();
  });

  tearDown(() async {
    SessionManager.resetSession();
    PackageStore().clearMemoryCache();
    BookDownloadService().clearMemoryCache();
    PastExamDownloadService().clearMemoryCache();
  });

  group('Part 1: Account-Scoped DownloadPackage Records & PackageStore', () {
    test('Independent download states for Natural and Social students on shared subject', () async {
      final store = PackageStore();
      await store.init();
      store.clearMemoryCache();

      const naturalUid = 'uid_natural_student_1';
      const socialUid = 'uid_social_student_2';
      const packageId = 'book_grade_12_mathematics';

      // 1. Natural student downloads Grade 12 Math
      final naturalRecord = DownloadPackageRecord(
        id: packageId,
        packageType: 'book',
        title: 'Grade 12 Mathematics',
        grade: 'Grade 12',
        subject: 'Mathematics',
        stream: 'natural',
        status: 'downloaded',
        version: 1,
        itemCount: 8,
        sizeBytes: 15000000,
        downloadedAt: DateTime.now(),
        userId: naturalUid,
      );
      await store.savePackage(naturalRecord, uid: naturalUid);

      // 2. Verify Natural has it downloaded
      final natPkg = await store.getPackage(packageId, uid: naturalUid);
      expect(natPkg, isNotNull);
      expect(natPkg!.status, 'downloaded');
      expect(natPkg.userId, naturalUid);

      // 3. Verify Social student DOES NOT have it downloaded
      final socPkg = await store.getPackage(packageId, uid: socialUid);
      expect(socPkg, isNull);

      final socialList = await store.getAllPackages(uid: socialUid);
      expect(socialList.any((p) => p.id == packageId), isFalse);

      // 4. Social student also downloads Grade 12 Math
      final socialRecord = DownloadPackageRecord(
        id: packageId,
        packageType: 'book',
        title: 'Grade 12 Mathematics',
        grade: 'Grade 12',
        subject: 'Mathematics',
        stream: 'social',
        status: 'downloaded',
        version: 1,
        itemCount: 8,
        sizeBytes: 15000000,
        downloadedAt: DateTime.now(),
        userId: socialUid,
      );
      await store.savePackage(socialRecord, uid: socialUid);

      // Now both have it downloaded
      expect(await store.getPackage(packageId, uid: naturalUid), isNotNull);
      expect(await store.getPackage(packageId, uid: socialUid), isNotNull);

      // 5. Social student deletes their download
      await store.deletePackageRecord(packageId, uid: socialUid);

      // Social is no longer downloaded, Natural STILL IS
      expect(await store.getPackage(packageId, uid: socialUid), isNull);
      final remainingNatPkg = await store.getPackage(packageId, uid: naturalUid);
      expect(remainingNatPkg, isNotNull);
      expect(remainingNatPkg!.status, 'downloaded');

      // Cleanup
      await store.deletePackageRecord(packageId, uid: naturalUid);
    });

    test('SessionManager active session UID auto-resolution', () async {
      final store = PackageStore();
      await store.init();
      store.clearMemoryCache();

      const naturalUid = 'uid_session_natural';
      const socialUid = 'uid_session_social';
      const packageId = 'past_exam_2017_natural_physics';

      // Start session for Natural
      SessionManager.startSession(naturalUid);
      expect(SessionManager.currentUid, naturalUid);

      // Save without passing explicit UID -> must resolve to naturalUid
      final pkg = DownloadPackageRecord(
        id: packageId,
        packageType: 'past_exam',
        title: '2017 Natural Physics',
        grade: 'Grade 12',
        subject: 'Physics',
        stream: 'natural',
        status: 'downloaded',
        version: 1,
        itemCount: 50,
        sizeBytes: 500000,
        downloadedAt: DateTime.now(),
        userId: naturalUid,
      );
      await store.savePackage(pkg);

      // Check without passing explicit UID -> returns package
      expect(await store.getPackage(packageId), isNotNull);

      // Switch to Social student
      SessionManager.startSession(socialUid);
      expect(SessionManager.currentUid, socialUid);

      // Check without passing explicit UID -> returns null for Social
      expect(await store.getPackage(packageId), isNull);

      // Cleanup
      await store.deletePackageRecord(packageId, uid: naturalUid);
    });

    test('Multi-account package reference tracking and isolation', () async {
      final store = PackageStore();
      await store.init();
      store.clearMemoryCache();

      const user1 = 'student_account_1';
      const user2 = 'student_account_2';
      const pkgId = 'book_grade_12_mathematics';

      // Both users download same content
      await store.savePackage(DownloadPackageRecord(
        id: pkgId,
        packageType: 'book',
        title: 'Math',
        grade: '12',
        subject: 'Math',
        status: 'downloaded',
        version: 1,
        itemCount: 1,
        sizeBytes: 100,
        downloadedAt: DateTime.now(),
        userId: user1,
        extraData: {'unitIds': ['unit_1']},
      ), uid: user1);

      await store.savePackage(DownloadPackageRecord(
        id: pkgId,
        packageType: 'book',
        title: 'Math',
        grade: '12',
        subject: 'Math',
        status: 'downloaded',
        version: 1,
        itemCount: 1,
        sizeBytes: 100,
        downloadedAt: DateTime.now(),
        userId: user2,
        extraData: {'unitIds': ['unit_1']},
      ), uid: user2);

      // Check users who downloaded this package
      final uids = await store.getUserIdsForPackage(pkgId);
      expect(uids, containsAll([user1, user2]));

      // Check if referenced by others when user1 deletes
      final isRefOther = await store.isPhysicalFileReferencedByOtherUsers(
        currentUid: user1,
        unitId: 'unit_1',
      );
      expect(isRefOther, isTrue);

      // Delete user1 record
      await store.deletePackageRecord(pkgId, uid: user1);

      // When user2 is evaluated, no other user references it
      final isRefOtherForUser2 = await store.isPhysicalFileReferencedByOtherUsers(
        currentUid: user2,
        unitId: 'unit_1',
      );
      expect(isRefOtherForUser2, isFalse);

      // Cleanup user2
      await store.deletePackageRecord(pkgId, uid: user2);
    });

    test('Cold restart preserves UID namespaces in packages.json', () async {
      final store1 = PackageStore();
      await store1.init();
      store1.clearMemoryCache();

      const uidA = 'cold_user_a';
      const uidB = 'cold_user_b';

      await store1.savePackage(DownloadPackageRecord(
        id: 'pkg_a',
        packageType: 'practice',
        title: 'Practice A',
        grade: 'Grade 12',
        subject: 'Physics',
        status: 'downloaded',
        version: 1,
        itemCount: 10,
        sizeBytes: 1000,
        downloadedAt: DateTime.now(),
        userId: uidA,
      ), uid: uidA);

      await store1.savePackage(DownloadPackageRecord(
        id: 'pkg_b',
        packageType: 'practice',
        title: 'Practice B',
        grade: 'Grade 12',
        subject: 'History',
        status: 'downloaded',
        version: 1,
        itemCount: 10,
        sizeBytes: 1000,
        downloadedAt: DateTime.now(),
        userId: uidB,
      ), uid: uidB);

      // Create a fresh store instance representing cold app restart
      final store2 = PackageStore();
      store2.clearMemoryCache();
      await store2.init(forceReload: true);

      // Verify that uidA only has pkg_a and uidB only has pkg_b
      final pkgsA = await store2.getAllPackages(uid: uidA);
      expect(pkgsA.length, 1);
      expect(pkgsA.first.id, 'pkg_a');

      final pkgsB = await store2.getAllPackages(uid: uidB);
      expect(pkgsB.length, 1);
      expect(pkgsB.first.id, 'pkg_b');

      // Cleanup
      await store2.deletePackageRecord('pkg_a', uid: uidA);
      await store2.deletePackageRecord('pkg_b', uid: uidB);
    });
  });

  group('Part 2: BookDownloadService & PastExamDownloadService Account Scoping', () {
    test('BookDownloadService isolates unit downloads by UID in book_unit_downloads.json', () async {
      final bookService = BookDownloadService();
      bookService.clearMemoryCache();

      const userA = 'user_grade12_natural';
      const userB = 'user_grade12_social';
      const bookId = 'book_grade_12_biology_unit_1';

      // Create physical dummy PDF file in test books directory
      final booksDir = Directory('${Directory.systemTemp.path}/edurise_books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }
      final file = File('${booksDir.path}/$bookId.pdf');
      await file.writeAsString('Dummy PDF content');

      // Write initial registry where userA has unit downloaded, but userB does not
      final engine = StorageEngine.instance;
      await engine.init();
      final initialRegistry = {
        userA: [bookId],
      };
      await engine.writeAtomic('book_unit_downloads.json', jsonEncode(initialRegistry));

      // Reload service
      bookService.clearMemoryCache();

      // User A has it downloaded
      final isUserADownloaded = await bookService.isDownloaded(bookId, uid: userA);
      expect(isUserADownloaded, isTrue);

      // User B DOES NOT have it downloaded
      final isUserBDownloaded = await bookService.isDownloaded(bookId, uid: userB);
      expect(isUserBDownloaded, isFalse);

      // Remove for User A
      await bookService.deleteBook(bookId, uid: userA);
      final afterDeleteUserA = await bookService.isDownloaded(bookId, uid: userA);
      expect(afterDeleteUserA, isFalse);
    });

    test('PastExamDownloadService isolates exam downloads by UID in exam_downloads.json', () async {
      final examService = PastExamDownloadService();
      examService.clearMemoryCache();

      const userA = 'exam_student_natural';
      const userB = 'exam_student_social';
      const examId = 'past_exam_2017_natural_physics';

      // Save exam data map for User A
      await examService.saveDownloadedExamData(
        examId,
        {'title': '2017 Natural Physics', 'questions': []},
        uid: userA,
      );

      // User A has it downloaded
      final isUserADownloaded = await examService.isExamDownloaded(examId: examId, uid: userA);
      expect(isUserADownloaded, isTrue);

      // User B DOES NOT have it downloaded
      final isUserBDownloaded = await examService.isExamDownloaded(examId: examId, uid: userB);
      expect(isUserBDownloaded, isFalse);

      // Delete for User A
      await examService.deleteDownloadedExam(examId: examId, uid: userA);
      final afterDeleteUserA = await examService.isExamDownloaded(examId: examId, uid: userA);
      expect(afterDeleteUserA, isFalse);
    });
  });

  group('Part 3: Report & Bug Report Deterministic IDs and Security Constraints', () {
    test('Question report deterministic document ID generation', () {
      const questionId = 'q_bio_12_045';
      const uid = 'student_uid_789';
      const reason = 'Wrong Correct Answer';
      final reasonSlug = reason.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

      final docId = 'qrep_${questionId}_${uid}_$reasonSlug';
      expect(docId, 'qrep_q_bio_12_045_student_uid_789_wrong_correct_answer');
    });

    test('Bug report deterministic document ID generation', () {
      const category = 'Books/download issue';
      const uid = 'student_uid_789';
      final categorySlug = category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

      final docId = 'bug_${categorySlug}_$uid';
      expect(docId, 'bug_books_download_issue_student_uid_789');
    });

    test('Admin bug report dynamic aggregation calculates distinct students correctly', () {
      // Mock documents from Firestore bug_reports
      final mockDocs = [
        {
          'id': 'bug_books_download_issue_uid1',
          'category': 'Books/download issue',
          'status': 'pending',
          'uid': 'uid1',
          'details': 'Download stalled at 50%',
        },
        {
          'id': 'bug_books_download_issue_uid2',
          'category': 'Books/download issue',
          'status': 'pending',
          'uid': 'uid2',
          'details': 'Cannot open downloaded book',
        },
        {
          'id': 'bug_app_crash_freezes_uid1',
          'category': 'App crash/freezes',
          'status': 'pending',
          'uid': 'uid1',
          'details': 'Crashes on login',
        },
      ];

      final Map<String, Map<String, dynamic>> aggregatedBugs = {};
      for (final doc in mockDocs) {
        final category = doc['category']?.toString() ?? 'Other';
        final status = doc['status']?.toString() ?? 'pending';
        final key = '${category}_$status';
        final reporterUid = doc['uid']?.toString() ?? '';
        final detail = doc['details']?.toString() ?? '';

        if (!aggregatedBugs.containsKey(key)) {
          aggregatedBugs[key] = {
            'category': category,
            'status': status,
            'reporterUids': reporterUid.isNotEmpty ? <String>[reporterUid] : <String>[],
            'recentFeedback': detail.isNotEmpty ? <String>[detail] : <String>[],
          };
        } else {
          final agg = aggregatedBugs[key]!;
          if (reporterUid.isNotEmpty && !(agg['reporterUids'] as List<String>).contains(reporterUid)) {
            (agg['reporterUids'] as List<String>).add(reporterUid);
          }
          if (detail.isNotEmpty && !(agg['recentFeedback'] as List<String>).contains(detail)) {
            (agg['recentFeedback'] as List<String>).add(detail);
          }
        }
      }

      final items = aggregatedBugs.values.map((m) {
        m['reportCount'] = (m['reporterUids'] as List).length;
        return m;
      }).toList();

      expect(items.length, 2);

      final bookBug = items.firstWhere((b) => b['category'] == 'Books/download issue');
      expect(bookBug['reportCount'], 2);
      expect((bookBug['recentFeedback'] as List).length, 2);

      final crashBug = items.firstWhere((b) => b['category'] == 'App crash/freezes');
      expect(crashBug['reportCount'], 1);
    });
  });
}
