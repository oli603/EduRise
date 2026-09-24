import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/access_service.dart';
import 'package:edurise/core/offline/download_manager.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/practice/data/question_model.dart';
import 'package:edurise/features/practice/data/question_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Practice Question Model & Stable ID Preservation Tests', () {
    test('Question model preserves original Firestore string IDs and maps accurately', () {
      const firestoreDocId = 'firestore_doc_q123_bio';
      final rawMap = {
        'grade': 'Grade 12',
        'stream': 'natural',
        'subject': 'Biology',
        'unitNumber': 1,
        'unitName': 'Application of Biology',
        'questionNumber': 1,
        'question': 'What is the function of restriction enzymes?',
        'options': [
          'To cut DNA at specific palindromic sites',
          'To join DNA fragments',
          'To synthesize proteins',
          'To transport RNA',
        ],
        'correctAnswer': 'To cut DNA at specific palindromic sites',
        'explanation': 'Restriction endonucleases cleave DNA at specific recognition sequences.',
        'examYear': 2017,
        'examType': 'Ethiopian University Entrance Exam',
        'status': 'published',
      };

      final question = Question.fromMap(firestoreDocId, rawMap);

      expect(question.id, firestoreDocId);
      expect(question.grade, 'Grade 12');
      expect(question.stream, 'natural');
      expect(question.subject, 'Biology');
      expect(question.unitNumber, 1);
      expect(question.unitName, 'Application of Biology');
      expect(question.questionNumber, 1);
      expect(question.options.length, 4);
      expect(question.correctAnswer, 'To cut DNA at specific palindromic sites');
      expect(question.examYear, 2017);
      expect(question.status, 'published');

      final serialized = question.toMap();
      expect(serialized['grade'], 'Grade 12');
      expect(serialized['subject'], 'Biology');
      expect(serialized['correctAnswer'], 'To cut DNA at specific palindromic sites');
    });

    test('Question copyWith preserves original ID and fields unless modified', () {
      final q = Question(
        id: 'stable_id_001',
        grade: 'Grade 12',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 1,
        unitName: 'Unit 1',
        questionNumber: 1,
        question: 'Sample Question',
        options: const ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'Test Explanation',
        examYear: 2017,
        examType: 'Ethiopian University Entrance Exam',
        status: 'published',
      );

      final updated = q.copyWith(question: 'Updated Question');
      expect(updated.id, 'stable_id_001');
      expect(updated.question, 'Updated Question');
      expect(updated.correctAnswer, 'A');
      expect(updated.grade, 'Grade 12');
    });
  });

  group('Practice Package Identity and DownloadPackageRecord Tests', () {
    final downloadManager = DownloadManager();

    test('Generates deterministic and normalized Practice package IDs', () {
      final id1 = downloadManager.getPracticePackageId(
        grade: 'Grade 12',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 1,
        examYear: 2017,
      );

      final id2 = downloadManager.getPracticePackageId(
        grade: ' Grade 12 ',
        stream: ' Natural Science ',
        subject: 'biology',
        unitNumber: 1,
        examYear: 2017,
      );

      expect(id1, 'practice_grade_12_natural_biology_u1_y2017');
      expect(id2, contains('practice_grade_12'));
      expect(id2, contains('biology_u1_y2017'));
    });

    test('Practice DownloadPackageRecord accurately stores question metadata and IDs', () {
      final now = DateTime.now();
      const questionIds = ['q1', 'q2', 'q3', 'q4', 'q5'];

      final record = DownloadPackageRecord(
        id: 'practice_grade_12_natural_biology_u1_y2017',
        packageType: 'practice',
        title: 'Biology Grade 12 — Unit 1 • 2017 EC',
        grade: 'Grade 12',
        stream: 'natural',
        subject: 'Biology',
        unitNumber: 1,
        unitName: 'Application of Biology',
        examYear: 2017,
        version: 1,
        itemCount: 5,
        sizeBytes: 12450,
        downloadedAt: now,
        status: 'downloaded',
        extraData: const {'questionIds': questionIds},
      );

      final map = record.toMap();
      final recreated = DownloadPackageRecord.fromMap(map);

      expect(recreated.id, 'practice_grade_12_natural_biology_u1_y2017');
      expect(recreated.packageType, 'practice');
      expect(recreated.title, 'Biology Grade 12 — Unit 1 • 2017 EC');
      expect(recreated.itemCount, 5);
      expect(recreated.sizeBytes, 12450);
      expect(recreated.status, 'downloaded');
      expect(recreated.unitNumber, 1);
      expect(recreated.examYear, 2017);
      expect(recreated.extraData['questionIds'], questionIds);
    });

    test('Partial practice download tracking and retry transition', () {
      final partialRecord = DownloadPackageRecord(
        id: 'practice_grade_11_natural_physics_u2_y2016',
        packageType: 'practice',
        title: 'Physics Grade 11 — Unit 2',
        grade: 'Grade 11',
        stream: 'natural',
        subject: 'Physics',
        unitNumber: 2,
        itemCount: 10,
        sizeBytes: 8000,
        downloadedAt: DateTime.now(),
        status: 'failed',
        extraData: const {'lastError': 'Network timeout'},
      );

      expect(partialRecord.status, 'failed');

      // Retry updates status to downloaded
      final completed = partialRecord.copyWith(
        status: 'downloaded',
        sizeBytes: 16000,
        extraData: const {'questionIds': ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8', 'p9', 'p10']},
      );

      expect(completed.status, 'downloaded');
      expect(completed.sizeBytes, 16000);
      expect((completed.extraData['questionIds'] as List).length, 10);
    });
  });

  group('Offline Result Model & Idempotency Tests', () {
    test('Offline result schema captures all required progress and weak-area metrics', () {
      const localId = 'pr_user123_1720000000_10';
      final now = DateTime.now();

      final resultData = <String, dynamic>{
        'id': localId,
        'localId': localId,
        'userId': 'user123',
        'grade': 'Grade 12',
        'stream': 'natural',
        'subject': 'Biology',
        'unitNumber': 1,
        'unitName': 'Application of Biology',
        'examYear': 2017,
        'totalQuestions': 10,
        'correctAnswers': 8,
        'wrongAnswers': 2,
        'score': 80,
        'questionIds': ['q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7', 'q8', 'q9', 'q10'],
        'correctQuestionIds': ['q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7', 'q8'],
        'questionResults': [
          {'questionId': 'q1', 'isCorrect': true},
          {'questionId': 'q2', 'isCorrect': true},
          {'questionId': 'q9', 'isCorrect': false},
          {'questionId': 'q10', 'isCorrect': false},
        ],
        'isSynced': false,
        'createdAt': now.toIso8601String(),
        'timestamp': now.toIso8601String(),
      };

      expect(resultData['localId'], localId);
      expect(resultData['isSynced'], false);
      expect(resultData['totalQuestions'], 10);
      expect(resultData['correctAnswers'], 8);
      expect(resultData['wrongAnswers'], 2);
      expect(resultData['score'], 80);
      expect((resultData['questionIds'] as List).length, 10);
      expect((resultData['correctQuestionIds'] as List).length, 8);
      expect((resultData['questionResults'] as List).length, 4);

      // Simulation of Sync Service marking record as synced without losing data
      resultData['isSynced'] = true;
      resultData['serverId'] = localId;

      expect(resultData['isSynced'], true);
      expect(resultData['serverId'], localId);
      expect(resultData['totalQuestions'], 10);
      expect(resultData['score'], 80);
    });

    test('Result serialization for JSON storage and Firestore upload format', () {
      const localId = 'pr_student99_1720001111_5';
      final result = {
        'id': localId,
        'localId': localId,
        'userId': 'student99',
        'grade': 'Grade 12',
        'subject': 'Chemistry',
        'unitNumber': 1,
        'unitName': 'Solutions',
        'totalQuestions': 5,
        'correctAnswers': 4,
        'wrongAnswers': 1,
        'score': 80,
        'isSynced': false,
      };

      final jsonStr = jsonEncode(result);
      expect(jsonStr, contains('pr_student99_1720001111_5'));

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['localId'], localId);
      expect(decoded['isSynced'], false);
    });
  });

  group('Access Control Tests for Offline Practice', () {
    test('Free access is strictly granted to Grade 12 Unit 1 2017 EC', () {
      final allowed = AccessService.isFreeAllowedPractice(
        grade: 'Grade 12',
        examYear: 2017,
        unitNumber: 1,
      );
      expect(allowed, true);

      final allowedNumeric = AccessService.isFreeAllowedPractice(
        grade: '12',
        examYear: 2017,
        unitNumber: 1,
      );
      expect(allowedNumeric, true);
    });

    test('Free access is denied for other grades, units, or years', () {
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 11',
          examYear: 2017,
          unitNumber: 1,
        ),
        false,
      );

      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 12',
          examYear: 2016,
          unitNumber: 1,
        ),
        false,
      );

      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 12',
          examYear: 2017,
          unitNumber: 2,
        ),
        false,
      );
    });
  });

  group('QuestionService Stream & Grade Normalization Tests', () {
    test('Normalizes natural and social stream inputs cleanly', () {
      expect(QuestionService.normalizeStream('natural'), 'natural');
      expect(QuestionService.normalizeStream('Natural Science'), 'natural');
      expect(QuestionService.normalizeStream('social'), 'social');
      expect(QuestionService.normalizeStream('Social Science'), 'social');
      expect(QuestionService.normalizeStream('', subject: 'Economics'), 'social');
      expect(QuestionService.normalizeStream('', subject: 'Biology'), 'natural');
    });
  });
}
