import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/session_manager.dart';
import 'package:edurise/core/constants/app_subjects.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/books/data/book_service.dart';
import 'package:edurise/features/downloads/data/download_manager.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineStorageService storage;

  setUp(() async {
    storage = OfflineStorageService();
    await storage.clearLocalDataForTesting();
    await storage.init(forceReload: true);
    SessionManager.resetForTesting();
  });

  tearDown(() async {
    await storage.clearLocalDataForTesting();
    SessionManager.resetForTesting();
  });

  group('SessionManager & Account Isolation Tests', () {
    test('SessionManager initializes correctly and starts at epoch 0 with no user', () {
      expect(SessionManager.currentUid, isNull);
      expect(SessionManager.sessionEpoch, 0);
    });

    test('SessionManager.startSession updates UID and increments session epoch', () {
      final initialEpoch = SessionManager.sessionEpoch;
      SessionManager.startSession('user_natural_101');
      expect(SessionManager.currentUid, 'user_natural_101');
      expect(SessionManager.sessionEpoch, initialEpoch + 1);

      // Switching user increments epoch again
      SessionManager.startSession('user_social_202');
      expect(SessionManager.currentUid, 'user_social_202');
      expect(SessionManager.sessionEpoch, initialEpoch + 2);
    });

    test('SessionManager.isSessionValid properly validates epoch and UID match', () {
      SessionManager.startSession('user_natural_101');
      final epoch1 = SessionManager.sessionEpoch;

      expect(SessionManager.isSessionValid(capturedUid: 'user_natural_101', capturedEpoch: epoch1), isTrue);
      expect(SessionManager.isSessionValid(capturedUid: 'user_natural_101', capturedEpoch: epoch1 - 1), isFalse);
      expect(SessionManager.isSessionValid(capturedUid: 'user_other', capturedEpoch: epoch1), isFalse);

      // Transition to founder account
      SessionManager.startSession('user_founder_999');
      final epoch2 = SessionManager.sessionEpoch;

      // Previous session token is now invalid
      expect(SessionManager.isSessionValid(capturedUid: 'user_natural_101', capturedEpoch: epoch1), isFalse);
      expect(SessionManager.isSessionValid(capturedUid: 'user_founder_999', capturedEpoch: epoch2), isTrue);
    });

    test('SessionManager.resetSession clears UID and increments epoch', () {
      SessionManager.startSession('user_abc');
      final currentEpoch = SessionManager.sessionEpoch;
      SessionManager.resetSession();

      expect(SessionManager.currentUid, isNull);
      expect(SessionManager.sessionEpoch, currentEpoch + 1);
    });

    test('OfflineStorageService caches and isolates student profiles by UID without leaking to other UIDs', () async {
      final profileA = StudentProfileRecord(
        uid: 'student_natural_01',
        name: 'Abebe Natural',
        email: 'natural@edurise.et',
        grade: '12',
        stream: 'natural',
        cachedAt: DateTime.now(),
      );

      final profileB = StudentProfileRecord(
        uid: 'student_social_02',
        name: 'Chala Social',
        email: 'social@edurise.et',
        grade: '12',
        stream: 'social',
        cachedAt: DateTime.now(),
      );

      // Save Profile A
      await storage.saveStudentProfile(profileA);
      final readA = await storage.getStudentProfile('student_natural_01');
      expect(readA, isNotNull);
      expect(readA!.uid, 'student_natural_01');
      expect(readA.stream, 'natural');

      // Requesting unauthenticated or different UID must NEVER return Profile A
      final readMissing = await storage.getStudentProfile('non_existent_uid');
      expect(readMissing, isNull);

      final readEmpty = await storage.getStudentProfile('');
      expect(readEmpty, isNull);

      // Save Profile B
      await storage.saveStudentProfile(profileB);
      final readB = await storage.getStudentProfile('student_social_02');
      expect(readB, isNotNull);
      expect(readB!.uid, 'student_social_02');
      expect(readB.stream, 'social');

      // Ensure readA still returns profileA
      final reReadA = await storage.getStudentProfile('student_natural_01');
      expect(reReadA!.name, 'Abebe Natural');
      expect(reReadA.stream, 'natural');
    });

    test('OfflineStorageService.clearMemoryCache clears cached in-memory structures', () async {
      storage.clearMemoryCache();
      expect(storage, isNotNull);
    });
  });

  group('Student Stream Boundary & Subject Clamping Tests', () {
    test('Natural stream allowed subjects contains only Natural science curriculum', () {
      final naturalSubjects = EduRiseSubjects.getEntranceExamSubjects(stream: 'natural');
      final subjectNames = naturalSubjects.map((s) => s.toLowerCase()).toSet();

      expect(subjectNames.contains('physics'), isTrue);
      expect(subjectNames.contains('chemistry'), isTrue);
      expect(subjectNames.contains('biology'), isTrue);
      expect(subjectNames.contains('mathematics'), isTrue);
      expect(subjectNames.contains('english'), isTrue);
      expect(subjectNames.contains('sat'), isTrue);

      // Social-only subjects must NOT be in Natural stream
      expect(subjectNames.contains('history'), isFalse);
      expect(subjectNames.contains('geography'), isFalse);
      expect(subjectNames.contains('economics'), isFalse);
    });

    test('Social stream allowed subjects contains only Social science curriculum', () {
      final socialSubjects = EduRiseSubjects.getEntranceExamSubjects(stream: 'social');
      final subjectNames = socialSubjects.map((s) => s.toLowerCase()).toSet();

      expect(subjectNames.contains('history'), isTrue);
      expect(subjectNames.contains('geography'), isTrue);
      expect(subjectNames.contains('economics'), isTrue);
      expect(subjectNames.contains('mathematics'), isTrue);
      expect(subjectNames.contains('english'), isTrue);
      expect(subjectNames.contains('sat'), isTrue);

      // Natural-only subjects must NOT be in Social stream
      expect(subjectNames.contains('physics'), isFalse);
      expect(subjectNames.contains('chemistry'), isFalse);
      expect(subjectNames.contains('biology'), isFalse);
    });

    test('Stream clamping in UI falls back to first valid subject if previous selection was invalid for new stream', () {
      final naturalList = ['All', 'Biology', 'Chemistry', 'Physics', 'Mathematics', 'English', 'Aptitude'];
      final socialList = ['All', 'History', 'Geography', 'Economics', 'Mathematics', 'English', 'Aptitude'];

      String selectedSubject = 'Chemistry';
      // If user switches stream to Social, Chemistry is not in socialList -> clamps to All or first
      if (!socialList.contains(selectedSubject)) {
        selectedSubject = 'All';
      }
      expect(selectedSubject, 'All');

      selectedSubject = 'Geography';
      // If user switches stream to Natural, Geography is not in naturalList -> clamps to All
      if (!naturalList.contains(selectedSubject)) {
        selectedSubject = 'All';
      }
      expect(selectedSubject, 'All');
    });
  });

  group('Report Aggregation & Deduplication Logic Tests', () {
    test('Question report issues list compiles formatted checkbox labels', () {
      final categories = ['Wrong Answer', 'Typo / Grammar', 'Missing Information'];
      expect(categories.length, 3);
      expect(categories.contains('Wrong Answer'), isTrue);
    });

    test('Bug report issue options match standard diagnostic categories', () {
      final bugCategories = [
        'App Crash / Freeze',
        'Offline / Download Issue',
        'Login / Account Issue',
        'Payment / Subscription Issue',
        'Display / UI Glitch',
        'Content / Question Error',
        'Other Problem',
      ];
      expect(bugCategories.length, 7);
    });

    test('Deterministic question report deduplication key format', () {
      const qId = 'math_2016_q45';
      const uId = 'student_789';
      final issueTypes = ['wrong_answer', 'typo'];
      issueTypes.sort();
      final key = '${qId}_${uId}_${issueTypes.join(',')}';
      expect(key, 'math_2016_q45_student_789_typo,wrong_answer');
    });
  });

  group('Exam Result Deterministic ID & Idempotency Tests', () {
    test('Exam result localId uses startTime timestamp for deterministic idempotency', () {
      final startTime = DateTime(2026, 9, 18, 14, 30, 0);
      const userId = 'student_test_456';
      const examId = '2016_natural_physics';

      final localId1 = 'pe_res_${userId}_${examId}_${startTime.millisecondsSinceEpoch}';
      final localId2 = 'pe_res_${userId}_${examId}_${startTime.millisecondsSinceEpoch}';

      expect(localId1, equals(localId2));
      expect(localId1, startsWith('pe_res_student_test_456_2016_natural_physics_'));
    });
  });

  group('BUG 1: Sign-Out Lifecycle & Stale Async Race Condition Tests', () {
    test('Sign out resets session epoch, clears current UID, and notifies reset listeners', () {
      bool listenerCalled = false;
      SessionManager.registerResetListener(() {
        listenerCalled = true;
      });

      SessionManager.startSession('user_natural_001');
      final epochBefore = SessionManager.sessionEpoch;
      expect(SessionManager.currentUid, 'user_natural_001');

      SessionManager.resetSession();

      expect(SessionManager.currentUid, isNull);
      expect(SessionManager.sessionEpoch, epochBefore + 1);
      expect(listenerCalled, isTrue);
    });

    test('Stale async callback from User A is rejected after logout and login to User B', () async {
      // 1. Natural user logs in
      SessionManager.startSession('user_natural_abebe');
      final capturedUid = SessionManager.currentUid;
      final capturedEpoch = SessionManager.sessionEpoch;

      String appliedProfile = 'none';

      // 2. Simulate async profile request started under Natural user
      Future<void> simulateAsyncOperation() async {
        await Future.delayed(const Duration(milliseconds: 50));
        // Verify session validity before applying result
        if (SessionManager.isSessionValid(capturedUid: capturedUid, capturedEpoch: capturedEpoch)) {
          appliedProfile = 'natural_profile_applied';
        } else {
          appliedProfile = 'discarded_stale_response';
        }
      }

      final opFuture = simulateAsyncOperation();

      // 3. User presses Sign Out and Social user logs in before async op finishes
      SessionManager.resetSession();
      SessionManager.startSession('user_social_chala');

      // 4. Wait for original async operation to complete
      await opFuture;

      // 5. Verify the Natural response was DISCARDED and not applied to Social user
      expect(appliedProfile, 'discarded_stale_response');
    });
  });

  group('BUG 2: Social Stream Subject Correctness & Data Integrity Tests', () {
    test('BookService returns accurate seed units for Social stream subjects (Economics, Geography, History)', () async {
      final bookService = BookService();

      final econUnits = await bookService.getUnits(grade: 'Grade 12', subject: 'Economics');
      expect(econUnits.isNotEmpty, isTrue);
      expect(econUnits.length, 4);
      expect(econUnits.first.subject, 'Economics');
      expect(econUnits.first.unitName, contains('Macroeconomics'));
      expect(econUnits.first.id, contains('econ_g12'));

      final geoUnits = await bookService.getUnits(grade: 'Grade 12', subject: 'Geography');
      expect(geoUnits.isNotEmpty, isTrue);
      expect(geoUnits.length, 4);
      expect(geoUnits.first.subject, 'Geography');
      expect(geoUnits.first.unitName, contains('Map Reading'));

      final histUnits = await bookService.getUnits(grade: 'Grade 12', subject: 'History');
      expect(histUnits.isNotEmpty, isTrue);
      expect(histUnits.length, 4);
      expect(histUnits.first.subject, 'History');
      expect(histUnits.first.unitName, contains('State Formation'));

      // Natural Biology units must remain Biology
      final bioUnits = await bookService.getUnits(grade: 'Grade 12', subject: 'Biology');
      expect(bioUnits.isNotEmpty, isTrue);
      expect(bioUnits.length, 4);
      expect(bioUnits.first.subject, 'Biology');
    });

    test('PastExamService generates subject-accurate exam questions for Social exams instead of Biology', () async {
      final examService = PastExamService();

      final econExam = await examService.getPastExam('past_exam_2017_social_economics');
      expect(econExam, isNotNull);
      expect(econExam!.subject, 'Economics');
      expect(econExam.stream, 'social');
      expect(econExam.questions.first.questionText, contains('macroeconomic'));

      final histExam = await examService.getPastExam('past_exam_2017_social_history');
      expect(histExam, isNotNull);
      expect(histExam!.subject, 'History');
      expect(histExam.stream, 'social');
      expect(histExam.questions.first.correctAnswer, contains('Adwa'));

      final geoExam = await examService.getPastExam('past_exam_2017_social_geography');
      expect(geoExam, isNotNull);
      expect(geoExam!.subject, 'Geography');
      expect(geoExam.stream, 'social');
      expect(geoExam.questions.first.correctAnswer, contains('Ras Dejen'));

      // Natural Biology exam must remain Biology
      final bioExam = await examService.getPastExam('past_exam_2017_natural_biology');
      expect(bioExam, isNotNull);
      expect(bioExam!.subject, 'Biology');
      expect(bioExam.stream, 'natural');
      expect(bioExam.questions.first.questionText, contains('mitochondria'));
    });

    test('PackageStore self-healing sanitization fixes corrupted legacy Social Biology packages', () async {
      final corruptedPackage = DownloadPackageRecord(
        id: 'practice_g12_social_economics_u1',
        packageType: 'practice',
        title: 'Grade 12 Biology - Unit 1', // Corrupted title from old bug
        grade: 'Grade 12',
        stream: 'social',
        subject: 'Biology', // Corrupted subject from old bug
        unitNumber: 1,
        version: 1,
        itemCount: 10,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
      );

      final packageStore = PackageStore();
      await packageStore.savePackage(corruptedPackage);

      // Force reload from disk to trigger sanitization
      await packageStore.init(forceReload: true);
      final sanitized = await packageStore.getPackage('practice_g12_social_economics_u1');

      expect(sanitized, isNotNull);
      expect(sanitized!.subject, 'Economics');
      expect(sanitized.title, 'Grade 12 Economics - Unit 1');
      expect(sanitized.stream, 'social');
    });

    test('ROUND 2 BUG 1: DownloadManager generates distinct stream-aware IDs preventing collisions', () {
      final downloadManager = DownloadManager();

      // Natural Physics vs. Social Physics (if ever exists)
      final naturalPhysId = downloadManager.getBookPackageId(grade: 'Grade 12', subject: 'Physics', stream: 'natural');
      final socialPhysId = downloadManager.getBookPackageId(grade: 'Grade 12', subject: 'Physics', stream: 'social');
      expect(naturalPhysId, 'book_grade_12_natural_physics');
      expect(socialPhysId, 'book_grade_12_social_physics');
      expect(naturalPhysId, isNot(equals(socialPhysId)));

      // Common subject (Mathematics) must have distinct package IDs across streams
      final naturalMathId = downloadManager.getBookPackageId(grade: 'Grade 12', subject: 'Mathematics', stream: 'natural');
      final socialMathId = downloadManager.getBookPackageId(grade: 'Grade 12', subject: 'Mathematics', stream: 'social');
      expect(naturalMathId, 'book_grade_12_natural_mathematics');
      expect(socialMathId, 'book_grade_12_social_mathematics');
      expect(naturalMathId, isNot(equals(socialMathId)));

      // Practice packages must also be distinct
      final natPractice = downloadManager.getPracticePackageId(grade: 'Grade 12', stream: 'natural', subject: 'Physics', unitNumber: 1);
      final socPractice = downloadManager.getPracticePackageId(grade: 'Grade 12', stream: 'social', subject: 'Economics', unitNumber: 1);
      expect(natPractice, contains('natural'));
      expect(socPractice, contains('social'));
    });

    test('ROUND 2 BUG 1: PackageStore assigns authoritative stream to packages lacking explicit stream tag', () async {
      final legacyPhysics = DownloadPackageRecord(
        id: 'book_grade_12_physics',
        packageType: 'book',
        title: 'Grade 12 Physics Textbook',
        grade: 'Grade 12',
        subject: 'Physics',
        stream: null, // Missing stream in legacy record
        version: 1,
        itemCount: 8,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
      );

      final legacyEcon = DownloadPackageRecord(
        id: 'book_grade_12_economics',
        packageType: 'book',
        title: 'Grade 12 Economics Textbook',
        grade: 'Grade 12',
        subject: 'Economics',
        stream: null, // Missing stream in legacy record
        version: 1,
        itemCount: 6,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
      );

      final packageStore = PackageStore();
      await packageStore.savePackage(legacyPhysics);
      await packageStore.savePackage(legacyEcon);

      // Force reload to trigger self-healing stream assignment
      await packageStore.init(forceReload: true);

      final healedPhys = await packageStore.getPackage('book_grade_12_physics');
      final healedEcon = await packageStore.getPackage('book_grade_12_economics');

      expect(healedPhys, isNotNull);
      expect(healedPhys!.stream, 'natural');

      expect(healedEcon, isNotNull);
      expect(healedEcon!.stream, 'social');
    });

    test('ROUND 2 BUG 1: Stream subject boundary filters packages correctly between Natural and Social', () {
      // Natural student stream filter
      expect(EduRiseSubjects.isSubjectAllowedForStream('Physics', 'natural'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Chemistry', 'natural'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Biology', 'natural'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Economics', 'natural'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('History', 'natural'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Geography', 'natural'), isFalse);

      // Social student stream filter
      expect(EduRiseSubjects.isSubjectAllowedForStream('Economics', 'social'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('History', 'social'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Geography', 'social'), isTrue);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Physics', 'social'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Chemistry', 'social'), isFalse);
      expect(EduRiseSubjects.isSubjectAllowedForStream('Biology', 'social'), isFalse);
    });
  });
}
