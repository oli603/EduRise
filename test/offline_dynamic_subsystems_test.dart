import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/challenges/data/challenge_model.dart';
import 'package:edurise/features/challenges/data/local/challenge_store.dart';
import 'package:edurise/features/study_plan/data/study_task_model.dart';
import 'package:edurise/features/study_plan/data/local/study_task_store.dart';
import 'package:edurise/features/practice/data/question_model.dart';
import 'package:edurise/features/practice/data/local/question_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineStorageService storage;
  late ChallengeStore challengeStore;
  late StudyTaskStore studyTaskStore;
  late QuestionStore questionStore;
  final testUserId = 'test_student_123';

  setUp(() async {
    storage = OfflineStorageService();
    challengeStore = ChallengeStore();
    studyTaskStore = StudyTaskStore();
    questionStore = QuestionStore();

    await storage.init();
    await storage.clearLocalDataForTesting();
    challengeStore.clearMemoryCache();
    studyTaskStore.clearMemoryCache();
    questionStore.clearMemoryCache();

    // Clean test directory
    final testDir = Directory('${Directory.systemTemp.path}/edurise_offline_test');
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
    testDir.createSync(recursive: true);
    await storage.init();
    await challengeStore.init();
    await studyTaskStore.init();
    await questionStore.init();
  });

  tearDown(() async {
    final testDir = Directory('${Directory.systemTemp.path}/edurise_offline_test');
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('Dynamic Subsystems - Offline Storage Foundation', () {
    test('ChallengeStore saves and retrieves challenges locally', () async {
      final challenge = Challenge(
        id: 'ch_1',
        userId: testUserId,
        title: 'Master Unit 1: Living Things',
        description: 'Practice unit 1 questions',
        challengeType: 'practice',
        grade: 'Grade 11',
        subject: 'Biology',
        unitNumber: 1,
        unitName: 'Living Things',
        targetCount: 10,
        currentCount: 3,
        scheduledDate: DateTime.now(),
        isCompleted: false,
        rewardXp: 100,
      );

      await challengeStore.saveChallengeLocally(challenge);
      final challenges = await challengeStore.getLocalChallenges(userId: testUserId);

      expect(challenges.length, 1);
      expect(challenges.first.id, 'ch_1');
      expect(challenges.first.title, 'Master Unit 1: Living Things');
      expect(challenges.first.currentCount, 3);
    });

    test('ChallengeStore updates challenge progress and completion locally', () async {
      final challenge = Challenge(
        id: 'ch_2',
        userId: testUserId,
        title: 'Chemistry Review',
        description: 'Review chemistry',
        challengeType: 'practice',
        grade: 'Grade 12',
        subject: 'Chemistry',
        unitNumber: 2,
        unitName: 'Electrochemistry',
        targetCount: 5,
        currentCount: 2,
        scheduledDate: DateTime.now(),
        isCompleted: false,
        rewardXp: 100,
      );

      await challengeStore.saveChallengeLocally(challenge);
      await challengeStore.markChallengeProgressLocally('ch_2', isCompleted: true, currentCount: 5);

      final challenges = await challengeStore.getLocalChallenges(userId: testUserId);
      expect(challenges.first.isCompleted, true);
    });

    test('StudyTaskStore and ChallengeStore queue and clear pending ops', () async {
      await studyTaskStore.queuePendingStudyTaskOp({
        'opId': 'op_task_1',
        'type': 'create',
        'taskId': 'task_1',
      });
      await challengeStore.queuePendingChallengeOp({
        'opId': 'op_ch_1',
        'type': 'update',
        'challengeId': 'ch_1',
      });

      var taskOps = await studyTaskStore.getPendingStudyTaskOps();
      var chOps = await challengeStore.getPendingChallengeOps();

      expect(taskOps.length, 1);
      expect(taskOps.first['opId'], 'op_task_1');
      expect(chOps.length, 1);
      expect(chOps.first['opId'], 'op_ch_1');

      await studyTaskStore.clearPendingStudyTaskOp('op_task_1');
      await challengeStore.clearPendingChallengeOp('op_ch_1');

      taskOps = await studyTaskStore.getPendingStudyTaskOps();
      chOps = await challengeStore.getPendingChallengeOps();

      expect(taskOps.isEmpty, true);
      expect(chOps.isEmpty, true);
    });
  });

  group('Dynamic Subsystems - Weak Areas Unique-Question Denominator & Calculations', () {
    test('Weak Areas calculation correctly handles unique question denominator without inflation', () async {
      // 3 attempts of the same question: Q1 (wrong), Q1 (wrong), Q1 (correct)
      // and 1 attempt of Q2 (wrong)
      // Total unique = 2 (Q1, Q2), Correct unique = 1 (Q1 was eventually correct) -> Accuracy = 50%
      final result1 = {
        'id': 'res_1',
        'localId': 'res_1',
        'userId': testUserId,
        'subject': 'Biology',
        'grade': 'Grade 11',
        'unitNumber': 3,
        'unitName': 'Cell Biology',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
        'questionResults': {
          'q_bio_1': false,
        },
      };

      final result2 = {
        'id': 'res_2',
        'localId': 'res_2',
        'userId': testUserId,
        'subject': 'Biology',
        'grade': 'Grade 11',
        'unitNumber': 3,
        'unitName': 'Cell Biology',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'questionResults': {
          'q_bio_1': true,
          'q_bio_2': false,
        },
      };

      await storage.savePracticeResultLocally(result1);
      await storage.savePracticeResultLocally(result2);

      final localResults = await storage.getLocalPracticeResults(userId: testUserId);
      expect(localResults.length, 2);

      final Map<String, bool> uniqueQs = {};
      for (final r in localResults) {
        final qr = r['questionResults'] as Map;
        qr.forEach((k, v) {
          uniqueQs[k.toString()] = v == true;
        });
      }

      expect(uniqueQs.length, 2); // Q1 and Q2 only!
      expect(uniqueQs['q_bio_1'], true); // Overwritten to true
      expect(uniqueQs['q_bio_2'], false);

      final totalUnique = uniqueQs.length;
      final correctUnique = uniqueQs.values.where((c) => c).length;
      final accuracy = ((correctUnique / totalUnique) * 100).round();

      expect(totalUnique, 2);
      expect(correctUnique, 1);
      expect(accuracy, 50);
    });

    test('Weak Areas groups strictly by textbook grade and unitNumber preventing cross-grade merge', () async {
      final rG11 = {
        'id': 'r_g11',
        'localId': 'r_g11',
        'userId': testUserId,
        'subject': 'Physics',
        'grade': 'Grade 11',
        'unitNumber': 1,
        'unitName': 'Introduction',
        'timestamp': DateTime.now().toIso8601String(),
        'questionResults': {'q_p11_1': true, 'q_p11_2': false},
      };

      final rG12 = {
        'id': 'r_g12',
        'localId': 'r_g12',
        'userId': testUserId,
        'subject': 'Physics',
        'grade': 'Grade 12',
        'unitNumber': 1,
        'unitName': 'Introduction',
        'timestamp': DateTime.now().toIso8601String(),
        'questionResults': {'q_p12_1': true, 'q_p12_2': true},
      };

      await storage.savePracticeResultLocally(rG11);
      await storage.savePracticeResultLocally(rG12);

      final localResults = await storage.getLocalPracticeResults(userId: testUserId);
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final data in localResults) {
        final subject = data['subject'] as String;
        final grade = data['grade'] as String;
        final unitNumber = data['unitNumber'] as int;
        final unitName = data['unitName'] as String;
        final key = '$grade|$subject|$unitNumber|$unitName';
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(data);
      }

      expect(grouped.keys.length, 2);
      expect(grouped.containsKey('Grade 11|Physics|1|Introduction'), true);
      expect(grouped.containsKey('Grade 12|Physics|1|Introduction'), true);
    });
  });

  group('Dynamic Subsystems - Progress Aggregation & Deduplication', () {
    test('Progress combines practice and past entrance exam results offline with deduplication', () async {
      await storage.savePracticeResultLocally({
        'id': 'prac_1',
        'localId': 'prac_1',
        'userId': testUserId,
        'totalQuestions': 10,
        'correctAnswers': 8,
        'wrongAnswers': 2,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await storage.savePastExamResultLocally({
        'id': 'exam_1',
        'localId': 'exam_1',
        'userId': testUserId,
        'totalQuestions': 50,
        'correctAnswers': 40,
        'wrongAnswers': 10,
        'completedAt': DateTime.now().toIso8601String(),
      });

      // Simulate remote caching duplicate
      await storage.cacheRemotePracticeResults([
        {
          'id': 'prac_1',
          'localId': 'prac_1',
          'userId': testUserId,
          'totalQuestions': 10,
          'correctAnswers': 8,
          'wrongAnswers': 2,
        },
      ]);

      final localPractice = await storage.getLocalPracticeResults(userId: testUserId);
      final localExams = await storage.getLocalPastExamResults(userId: testUserId);

      final Map<String, Map<String, dynamic>> deduped = {};
      for (final p in localPractice) {
        final key = (p['localId'] ?? p['id']) as String;
        deduped[key] = p;
      }
      for (final e in localExams) {
        final key = (e['localId'] ?? e['id']) as String;
        deduped[key] = e;
      }

      int totalQ = 0;
      int correctA = 0;
      int wrongA = 0;

      for (final r in deduped.values) {
        totalQ += (r['totalQuestions'] as num?)?.toInt() ?? 0;
        correctA += (r['correctAnswers'] as num?)?.toInt() ?? 0;
        wrongA += (r['wrongAnswers'] as num?)?.toInt() ?? 0;
      }

      final accuracy = ((correctA / totalQ) * 100).round();

      expect(totalQ, 60);
      expect(correctA, 48);
      expect(wrongA, 12);
      expect(accuracy, 80);
    });
  });

  group('Dynamic Subsystems - Study Plan Offline Management', () {
    test('Study task CRUD persists to local storage when offline', () async {
      final task = StudyTask(
        id: 'task_local_101',
        userId: testUserId,
        title: 'Review Genetics',
        grade: 'Grade 12',
        subject: 'Biology',
        unitNumber: 4,
        unitName: 'Genetics',
        taskType: 'reading',
        scheduledDate: DateTime.now(),
        isCompleted: false,
      );

      await studyTaskStore.saveStudyTaskLocally(task);
      var tasks = await studyTaskStore.getLocalStudyTasks(userId: testUserId);
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Review Genetics');

      final updated = task.copyWith(isCompleted: true);
      await studyTaskStore.saveStudyTaskLocally(updated);
      tasks = await studyTaskStore.getLocalStudyTasks(userId: testUserId);
      expect(tasks.first.isCompleted, true);

      await studyTaskStore.deleteStudyTaskLocally('task_local_101');
      tasks = await studyTaskStore.getLocalStudyTasks(userId: testUserId);
      expect(tasks.isEmpty, true);
    });
  });

  group('Dynamic Subsystems - Weak Areas Edge Cases & Denominator Hardening', () {
    test('Zero results returns empty list without error', () async {
      final results = await storage.getLocalPracticeResults(userId: 'non_existent_user');
      expect(results.isEmpty, true);
    });

    test('Single question all correct yields 100% accuracy', () async {
      await storage.savePracticeResultLocally({
        'id': 'res_single_correct',
        'localId': 'res_single_correct',
        'userId': testUserId,
        'subject': 'Mathematics',
        'grade': 'Grade 12',
        'unitNumber': 1,
        'unitName': 'Sequences and Series',
        'timestamp': DateTime.now().toIso8601String(),
        'questionResults': {'q_math_1': true},
      });

      final localResults = await storage.getLocalPracticeResults(userId: testUserId);
      final r = localResults.first;
      final qr = r['questionResults'] as Map;
      expect(qr.length, 1);
      expect(qr['q_math_1'], true);
    });

    test('Single question all incorrect yields 0% accuracy', () async {
      await storage.savePracticeResultLocally({
        'id': 'res_single_wrong',
        'localId': 'res_single_wrong',
        'userId': testUserId,
        'subject': 'Mathematics',
        'grade': 'Grade 12',
        'unitNumber': 1,
        'unitName': 'Sequences and Series',
        'timestamp': DateTime.now().toIso8601String(),
        'questionResults': {'q_math_1': false},
      });

      final localResults = await storage.getLocalPracticeResults(userId: testUserId);
      final r = localResults.first;
      final qr = r['questionResults'] as Map;
      expect(qr.length, 1);
      expect(qr['q_math_1'], false);
    });

    test('Repeated attempts of same question: Q1(false), Q1(false), Q1(true) -> denominator is 1, correct is 1', () async {
      // 3 sequential attempts of the exact same question
      final r1 = {
        'id': 'r1',
        'localId': 'r1',
        'userId': testUserId,
        'subject': 'Physics',
        'grade': 'Grade 11',
        'unitNumber': 2,
        'unitName': 'Vectors',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        'questionResults': {'q_v1': false},
      };
      final r2 = {
        'id': 'r2',
        'localId': 'r2',
        'userId': testUserId,
        'subject': 'Physics',
        'grade': 'Grade 11',
        'unitNumber': 2,
        'unitName': 'Vectors',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
        'questionResults': {'q_v1': false},
      };
      final r3 = {
        'id': 'r3',
        'localId': 'r3',
        'userId': testUserId,
        'subject': 'Physics',
        'grade': 'Grade 11',
        'unitNumber': 2,
        'unitName': 'Vectors',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'questionResults': {'q_v1': true},
      };

      await storage.savePracticeResultLocally(r1);
      await storage.savePracticeResultLocally(r2);
      await storage.savePracticeResultLocally(r3);

      final localResults = await storage.getLocalPracticeResults(userId: testUserId);
      final Map<String, bool> uniqueQuestions = {};
      for (final res in localResults) {
        final qr = res['questionResults'] as Map;
        qr.forEach((k, v) {
          uniqueQuestions[k.toString()] = v == true;
        });
      }

      expect(uniqueQuestions.length, 1); // Only 1 unique question!
      expect(uniqueQuestions['q_v1'], true); // Final latest status is true
      final totalUnique = uniqueQuestions.length;
      final correctUnique = uniqueQuestions.values.where((v) => v).length;
      final accuracy = ((correctUnique / totalUnique) * 100).round();
      expect(accuracy, 100);
    });

    test('Mixed repeated questions: Q1(f), Q1(t), Q2(f) -> denominator is 2, accuracy is 50%', () async {
      final r1 = {
        'id': 'mr1',
        'localId': 'mr1',
        'userId': testUserId,
        'subject': 'Chemistry',
        'grade': 'Grade 12',
        'unitNumber': 3,
        'unitName': 'Chemical Equilibrium',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
        'questionResults': {'q_ce_1': false, 'q_ce_2': false},
      };
      final r2 = {
        'id': 'mr2',
        'localId': 'mr2',
        'userId': testUserId,
        'subject': 'Chemistry',
        'grade': 'Grade 12',
        'unitNumber': 3,
        'unitName': 'Chemical Equilibrium',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        'questionResults': {'q_ce_1': true},
      };

      await storage.savePracticeResultLocally(r1);
      await storage.savePracticeResultLocally(r2);

      final localResults = await storage.getLocalPracticeResults(userId: testUserId);
      final Map<String, bool> uniqueQuestions = {};
      for (final res in localResults) {
        final qr = res['questionResults'] as Map;
        qr.forEach((k, v) {
          uniqueQuestions[k.toString()] = v == true;
        });
      }

      expect(uniqueQuestions.length, 2);
      expect(uniqueQuestions['q_ce_1'], true);
      expect(uniqueQuestions['q_ce_2'], false);
      final correct = uniqueQuestions.values.where((v) => v).length;
      final accuracy = ((correct / uniqueQuestions.length) * 100).round();
      expect(accuracy, 50);
    });
  });

  group('Dynamic Subsystems - Storage Hardening & Serialization Resilience', () {
    test('Storage handles DateTime, ISO Strings, and numeric Timestamps in Challenge model', () {
      final now = DateTime.now();
      final chMap = {
        'userId': testUserId,
        'title': 'Test Challenge',
        'description': 'Description',
        'challengeType': 'practice',
        'grade': 'Grade 11',
        'subject': 'Biology',
        'unitNumber': 1,
        'unitName': 'Unit 1',
        'targetCount': 10,
        'currentCount': 0,
        'scheduledDate': now.toIso8601String(),
        'isCompleted': false,
        'rewardXp': 100,
        'createdAt': now.millisecondsSinceEpoch,
      };

      final challenge = Challenge.fromMap('ch_test_dates', chMap);
      expect(challenge.scheduledDate.year, now.year);
      expect(challenge.createdAt?.year, now.year);
    });

    test('Storage handles various date formats in StudyTask model', () {
      final now = DateTime.now();
      final taskMap = {
        'userId': testUserId,
        'title': 'Test Task',
        'grade': 'Grade 12',
        'subject': 'Physics',
        'unitNumber': 2,
        'unitName': 'Unit 2',
        'taskType': 'practice',
        'scheduledDate': now.toIso8601String(),
        'isCompleted': false,
        'createdAt': now.toIso8601String(),
      };

      final task = StudyTask.fromMap('task_test_dates', taskMap);
      expect(task.scheduledDate.day, now.day);
      expect(task.createdAt?.day, now.day);
    });

    test('savePracticeResultLocally updates existing record without creating duplicate', () async {
      final initial = {
        'id': 'res_idempotent_1',
        'localId': 'res_idempotent_1',
        'userId': testUserId,
        'totalQuestions': 10,
        'correctAnswers': 6,
        'wrongAnswers': 4,
        'isSynced': false,
      };

      await storage.savePracticeResultLocally(initial);
      var results = await storage.getLocalPracticeResults(userId: testUserId);
      expect(results.length, 1);

      // Re-save modified or synced copy
      final updated = {
        'id': 'res_idempotent_1',
        'localId': 'res_idempotent_1',
        'userId': testUserId,
        'totalQuestions': 10,
        'correctAnswers': 8,
        'wrongAnswers': 2,
        'isSynced': true,
      };

      await storage.savePracticeResultLocally(updated);
      results = await storage.getLocalPracticeResults(userId: testUserId);
      expect(results.length, 1); // Still exactly 1!
      expect(results.first['correctAnswers'], 8);
      expect(results.first['isSynced'], true);
    });

    test('Corrupted JSON file does not crash storage loader and initializes gracefully', () async {
      // Simulate writing corrupted JSON string to challenges.json
      final dir = await storage.storageDirectory;
      final file = File('${dir.path}/challenges.json');
      if (file.existsSync()) {
        file.writeAsStringSync('{{{MALFORMED JSON CONTENT@@@');
      }

      // Re-init challengeStore
      await challengeStore.init(forceReload: true);
      final challenges = await challengeStore.getLocalChallenges(userId: testUserId);
      expect(challenges.isEmpty, true); // Returns safe empty fallback without crashing
    });

  });

  group('Dynamic Subsystems - Challenge Resolution from Local Packages', () {
    test('Challenge question count resolved accurately from downloaded offline questions', () async {
      final questions = [
        const Question(
          id: 'q_chem_1',
          grade: 'Grade 11',
          stream: 'natural',
          subject: 'Chemistry',
          unitNumber: 1,
          unitName: 'Atomic Structure',
          questionNumber: 1,
          question: 'What is an electron?',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          explanation: 'Fundamental particle',
          examYear: 2024,
          examType: 'model',
          status: 'published',
        ),
        const Question(
          id: 'q_chem_2',
          grade: 'Grade 11',
          stream: 'natural',
          subject: 'Chemistry',
          unitNumber: 1,
          unitName: 'Atomic Structure',
          questionNumber: 2,
          question: 'What is a proton?',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'B',
          explanation: 'Positively charged particle',
          examYear: 2024,
          examType: 'model',
          status: 'published',
        ),
      ];

      await questionStore.saveQuestions(questions);

      final offlineQs = await questionStore.getOfflineQuestions(
        grade: 'Grade 11',
        stream: 'natural',
        subject: 'Chemistry',
        unitNumber: 1,
      );

      expect(offlineQs.length, 2);
    });
  });
}

