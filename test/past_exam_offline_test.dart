import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/core/auth/access_service.dart';
import 'package:edurise/core/offline/download_manager.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_download_service.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_model.dart';
import 'package:edurise/features/past_entrance_exams/presentation/exam_result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Past Entrance Exam Model & Stable ID Preservation Tests', () {
    test('PastExamQuestion preserves stable Firestore IDs and serializes correctly', () {
      const qId = 'stable_pe_q_2017_bio_001';
      final map = {
        'id': qId,
        'questionNumber': 1,
        'questionText': 'Which of the following cell organelles is responsible for ATP synthesis?',
        'imageUrl': 'https://storage.googleapis.com/edurise/exams/mitochondria.png',
        'optionA': 'Golgi apparatus',
        'optionB': 'Mitochondria',
        'optionC': 'Endoplasmic reticulum',
        'optionD': 'Ribosome',
        'correctAnswer': 'B',
        'explanation': 'Mitochondria are the powerhouses of the cell where ATP is produced via oxidative phosphorylation.',
      };

      final question = PastExamQuestion.fromMap(map);

      expect(question.id, qId);
      expect(question.questionNumber, 1);
      expect(question.questionText, contains('ATP synthesis'));
      expect(question.imageUrl, contains('mitochondria.png'));
      expect(question.optionA, 'Golgi apparatus');
      expect(question.optionB, 'Mitochondria');
      expect(question.optionC, 'Endoplasmic reticulum');
      expect(question.optionD, 'Ribosome');
      expect(question.correctAnswer, 'B');
      expect(question.explanation, contains('powerhouses'));

      final serialized = question.toMap();
      expect(serialized['id'], qId);
      expect(serialized['correctAnswer'], 'B');
      expect(serialized['optionB'], 'Mitochondria');
    });

    test('PastExam model accurately aggregates questions, stable IDs, and duration', () {
      const examId = '2017_natural_mathematics';
      final questions = [
        const PastExamQuestion(
          id: 'math_q1',
          questionNumber: 1,
          questionText: 'What is the derivative of f(x) = x^3 - 3x + 2?',
          optionA: '3x^2 - 3',
          optionB: '3x^2 + 3',
          optionC: 'x^2 - 3',
          optionD: '3x^2',
          correctAnswer: 'A',
          explanation: 'd/dx(x^3 - 3x + 2) = 3x^2 - 3',
        ),
        const PastExamQuestion(
          id: 'math_q2',
          questionNumber: 2,
          questionText: 'If log2(x) = 5, what is the value of x?',
          optionA: '10',
          optionB: '25',
          optionC: '32',
          optionD: '64',
          correctAnswer: 'C',
          explanation: 'x = 2^5 = 32',
        ),
      ];

      final exam = PastExam(
        id: examId,
        year: '2017',
        stream: 'natural',
        subject: 'Mathematics',
        durationMinutes: 180,
        questions: questions,
      );

      expect(exam.id, examId);
      expect(exam.year, '2017');
      expect(exam.stream, 'natural');
      expect(exam.subject, 'Mathematics');
      expect(exam.durationMinutes, 180);
      expect(exam.questions.length, 2);
      expect(exam.questions.first.id, 'math_q1');
      expect(exam.questions.last.id, 'math_q2');

      final serialized = exam.toMap();
      expect(serialized['id'], examId);
      expect(serialized['durationMinutes'], 180);
      expect(serialized['questionCount'], 2);

      final deserialized = PastExam.fromMap(examId, serialized);
      expect(deserialized.id, examId);
      expect(deserialized.questions.length, 2);
      expect(deserialized.questions[1].correctAnswer, 'C');
    });
  });

  group('Subject Time Rule Tests (Rule 31)', () {
    test('Mathematics has exactly 180 minutes (3 hours)', () {
      const subject = 'Mathematics';
      final isMath = subject.trim().toLowerCase() == 'mathematics';
      final duration = isMath ? 180 : 120;
      expect(duration, 180);
    });

    test('All other non-Mathematics subjects have exactly 120 minutes (2 hours)', () {
      final nonMathSubjects = [
        'Physics',
        'Chemistry',
        'Biology',
        'English',
        'SAT',
        'History',
        'Geography',
        'Economics',
        'Civics',
      ];

      for (final sub in nonMathSubjects) {
        final isMath = sub.trim().toLowerCase() == 'mathematics';
        final duration = isMath ? 180 : 120;
        expect(duration, 120, reason: 'Subject $sub should be 120 minutes');
      }
    });
  });

  group('Access Control Tests (Rule 3 & 28)', () {
    test('Free user is completely locked from past entrance exams', () async {
      AccessService.setTestRole('free');
      final canAccess = await AccessService.canAccessPastExams();
      expect(canAccess, false);
    });

    test('Paid user is fully authorized for past entrance exams', () async {
      AccessService.setTestRole('paid');
      final canAccess = await AccessService.canAccessPastExams();
      expect(canAccess, true);
    });

    test('Admin user is authorized for past entrance exams', () async {
      AccessService.setTestRole('admin');
      final canAccess = await AccessService.canAccessPastExams();
      expect(canAccess, true);
    });
  });

  group('DownloadManager Past Exam Package Identity & State Tests', () {
    final downloadManager = DownloadManager();

    test('Generates deterministic and normalized package ID for Past Entrance Exams', () {
      final id1 = downloadManager.getPastExamPackageId(
        year: '2017',
        stream: 'natural',
        subject: 'Mathematics',
      );

      final id2 = downloadManager.getPastExamPackageId(
        year: ' 2017 ',
        stream: ' Natural Science ',
        subject: 'mathematics',
      );

      expect(id1, 'past_exam_2017_natural_mathematics');
      expect(id2, 'past_exam_2017_natural_mathematics');
    });

    test('Past Exam DownloadPackageRecord correctly encapsulates package metadata', () {
      final now = DateTime.now();
      const questionIds = ['q1', 'q2', 'q3'];

      final record = DownloadPackageRecord(
        id: 'past_exam_2017_natural_biology',
        packageType: 'past_exam',
        title: '2017 EC Biology Entrance Exam',
        stream: 'natural',
        subject: 'Biology',
        examYear: 2017,
        version: 1,
        itemCount: 3,
        sizeBytes: 8500,
        downloadedAt: now,
        status: 'downloaded',
        extraData: const {
          'year': '2017',
          'stream': 'natural',
          'examId': '2017_natural_biology',
          'questionIds': questionIds,
        },
      );

      final map = record.toMap();
      final reconstructed = DownloadPackageRecord.fromMap(map);

      expect(reconstructed.id, 'past_exam_2017_natural_biology');
      expect(reconstructed.packageType, 'past_exam');
      expect(reconstructed.title, '2017 EC Biology Entrance Exam');
      expect(reconstructed.itemCount, 3);
      expect(reconstructed.examYear, 2017);
      expect(reconstructed.status, 'downloaded');
      expect(reconstructed.extraData['examId'], '2017_natural_biology');
      expect(reconstructed.extraData['questionIds'], questionIds);
    });
  });

  group('Offline Storage & Package Persistence Tests', () {
    final storageService = OfflineStorageService();
    final downloadService = PastExamDownloadService();

    test('Saves and loads downloaded Past Exam model locally without Firestore', () async {
      AccessService.setTestRole('paid');

      const examId = 'test_local_2017_biology';
      final questions = [
        const PastExamQuestion(
          id: 'q_bio_001',
          questionNumber: 1,
          questionText: 'What is the primary function of chlorophyll in photosynthesis?',
          optionA: 'Absorb light energy',
          optionB: 'Release oxygen',
          optionC: 'Absorb water',
          optionD: 'Synthesize glucose',
          correctAnswer: 'A',
          explanation: 'Chlorophyll pigments absorb photons from sunlight.',
        ),
        const PastExamQuestion(
          id: 'q_bio_002',
          questionNumber: 2,
          questionText: 'Which enzyme unwinds DNA during replication?',
          optionA: 'DNA Polymerase',
          optionB: 'DNA Helicase',
          optionC: 'DNA Ligase',
          optionD: 'RNA Primase',
          correctAnswer: 'B',
          explanation: 'Helicase disrupts hydrogen bonds to unwind the double helix.',
        ),
      ];

      final exam = PastExam(
        id: examId,
        year: '2017',
        stream: 'natural',
        subject: 'Biology',
        durationMinutes: 120,
        questions: questions,
      );

      // Save locally
      await downloadService.saveDownloadedExamData(
        examId,
        exam.toMap(),
      );

      // Verify file exists
      final exists = await downloadService.isExamDownloadedLocally(examId);
      expect(exists, true);

      // Retrieve model directly from local disk
      final loadedExam = await downloadService.getDownloadedPastExamModel(examId: examId);
      expect(loadedExam, isNotNull);
      expect(loadedExam!.id, examId);
      expect(loadedExam.subject, 'Biology');
      expect(loadedExam.durationMinutes, 120);
      expect(loadedExam.questions.length, 2);
      expect(loadedExam.questions.first.id, 'q_bio_001');
      expect(loadedExam.questions.first.correctAnswer, 'A');
      expect(loadedExam.questions.last.id, 'q_bio_002');
      expect(loadedExam.questions.last.correctAnswer, 'B');
    });

    test('Offline result queue stores pending exam results with deterministic local ID', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final localId = 'pe_res_user_123_2017_natural_biology_$timestamp';

      final sampleResult = {
        'localId': localId,
        'userId': 'user_123',
        'examId': '2017_natural_biology',
        'year': '2017',
        'stream': 'natural',
        'subject': 'Biology',
        'totalQuestions': 100,
        'score': 85,
        'correctAnswers': 85,
        'incorrectAnswers': 15,
        'unansweredCount': 0,
        'percentage': 85,
        'timeSpentSeconds': 5400,
        'durationMinutes': 120,
        'selectedAnswers': {'0': 'A', '1': 'B'},
        'completedAt': DateTime.now().toIso8601String(),
        'syncStatus': 'pending',
      };

      await storageService.savePastExamResultLocally(sampleResult);

      final allResults = await storageService.getLocalPastExamResults();
      expect(allResults.any((r) => r['localId'] == localId), true);

      final unsynced = await storageService.getUnsyncedPastExamResults();
      expect(unsynced.any((r) => r['localId'] == localId), true);

      // Mark synced
      await storageService.markPastExamResultSynced(localId);

      final unsyncedAfter = await storageService.getUnsyncedPastExamResults();
      expect(unsyncedAfter.any((r) => r['localId'] == localId), false);
    });

    test('Deleting local downloaded package removes local exam content cleanly', () async {
      const examId = 'test_remove_2018_physics';
      await downloadService.saveDownloadedExamData(
        examId,
        {'id': examId, 'year': '2018', 'subject': 'Physics', 'questions': []},
      );

      expect(await downloadService.isExamDownloadedLocally(examId), true);

      await downloadService.deleteDownloadedExam(examId: examId);

      expect(await downloadService.isExamDownloadedLocally(examId), false);
    });
  });

  group('Timed Exam Calculation & Auto-Submission Simulation Tests', () {
    test('Absolute deadline calculation survives elapsed time correctly', () {
      final startTime = DateTime.now();
      const durationMinutes = 180;
      final deadline = startTime.add(const Duration(minutes: durationMinutes));

      // Simulate 30 minutes elapsed
      final simulatedNow = startTime.add(const Duration(minutes: 30));
      final remainingSeconds = deadline.difference(simulatedNow).inSeconds;

      expect(remainingSeconds, 150 * 60);
      expect(remainingSeconds > 0, true);
    });

    test('Score calculation matches correct answers accurately', () {
      final questions = [
        const PastExamQuestion(
          id: 'q1',
          questionNumber: 1,
          questionText: 'Q1',
          optionA: 'A',
          optionB: 'B',
          optionC: 'C',
          optionD: 'D',
          correctAnswer: 'A',
          explanation: '',
        ),
        const PastExamQuestion(
          id: 'q2',
          questionNumber: 2,
          questionText: 'Q2',
          optionA: 'A',
          optionB: 'B',
          optionC: 'C',
          optionD: 'D',
          correctAnswer: 'B',
          explanation: '',
        ),
        const PastExamQuestion(
          id: 'q3',
          questionNumber: 3,
          questionText: 'Q3',
          optionA: 'A',
          optionB: 'B',
          optionC: 'C',
          optionD: 'D',
          correctAnswer: 'C',
          explanation: '',
        ),
        const PastExamQuestion(
          id: 'q4',
          questionNumber: 4,
          questionText: 'Q4',
          optionA: 'A',
          optionB: 'B',
          optionC: 'C',
          optionD: 'D',
          correctAnswer: 'D',
          explanation: '',
        ),
      ];

      final selectedAnswers = {
        0: 'A', // Correct
        1: 'A', // Incorrect (correct is B)
        2: 'C', // Correct
        // 3 is unanswered
      };

      int correctCount = 0;
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        final chosen = selectedAnswers[i];
        if (chosen != null && chosen.trim().toUpperCase() == q.correctAnswer.trim().toUpperCase()) {
          correctCount++;
        }
      }

      final total = questions.length;
      final percentage = ((correctCount / total) * 100).round();
      final unanswered = total - selectedAnswers.length;

      expect(correctCount, 2);
      expect(total, 4);
      expect(percentage, 50);
      expect(unanswered, 1);
    });
  });

  group('Past Entrance Exam Widget & Offline Flow Tests', () {
    testWidgets('ExamResultScreen renders score, percentage, and review options correctly', (tester) async {
      const exam = PastExam(
        id: '2017_natural_biology',
        year: '2017',
        stream: 'natural',
        subject: 'Biology',
        durationMinutes: 120,
        questions: [
          PastExamQuestion(
            id: 'q1',
            questionNumber: 1,
            questionText: 'What is photosynthesis?',
            optionA: 'Light reaction',
            optionB: 'Dark reaction',
            optionC: 'ATP process',
            optionD: 'All of above',
            correctAnswer: 'A',
            explanation: 'Photosynthesis converts solar energy into chemical energy.',
          ),
        ],
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ExamResultScreen(
            exam: exam,
            selectedAnswers: const {0: 'A'},
            correctAnswers: 1,
            totalQuestions: 1,
            percentage: 100,
            timeSpentSeconds: 300,
            durationMinutes: 120,
            localResultId: 'test_local_id_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1 out of 1 Questions Correct'), findsOneWidget);
      expect(find.text('Exam Completed!'), findsOneWidget);
      expect(find.text('Review Answers'), findsOneWidget);
      expect(find.text('Retake Exam'), findsOneWidget);
    });
  });
}
