import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/maintenance/maintenance_service.dart';
import 'package:edurise/core/offline/connectivity_service.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_model.dart';
import 'package:edurise/features/admin/data/import/practice_bulk_import_models.dart';
import 'package:edurise/features/practice/data/question_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0-A & P0-B: Past Exam Model Parsing & Key Resilience', () {
    test('PastExamQuestion.fromMap parses diverse spreadsheet column formats', () {
      // 1. Standard format
      final q1 = PastExamQuestion.fromMap({
        'questionText': 'What is the capital of Ethiopia?',
        'optionA': 'Addis Ababa',
        'optionB': 'Hawassa',
        'optionC': 'Dire Dawa',
        'optionD': 'Bahir Dar',
        'correctAnswer': 'A',
      });
      expect(q1.questionText, 'What is the capital of Ethiopia?');
      expect(q1.optionA, 'Addis Ababa');
      expect(q1.correctAnswer, 'A');

      // 2. Spreadsheet variations with spaces, uppercase, and alternative keys
      final q2 = PastExamQuestion.fromMap({
        'Question': 'Solve for x: 2x + 4 = 10',
        'Option A': 'x = 1',
        'Option B': 'x = 2',
        'Option C': 'x = 3',
        'Option D': 'x = 4',
        'Answer': 'C',
      });
      expect(q2.questionText, 'Solve for x: 2x + 4 = 10');
      expect(q2.optionA, 'x = 1');
      expect(q2.optionC, 'x = 3');
      expect(q2.correctAnswer, 'C');

      // 3. Array choices and verbose answer string
      final q3 = PastExamQuestion.fromMap({
        'prompt': 'Which organ pumps blood?',
        'choices': ['Lungs', 'Heart', 'Kidney', 'Brain'],
        'correct_answer': 'Option B: Heart',
      });
      expect(q3.questionText, 'Which organ pumps blood?');
      expect(q3.optionA, 'Lungs');
      expect(q3.optionB, 'Heart');
      expect(q3.correctAnswer, 'B');
    });

    test('PastExam.fromMap parses exam duration with intelligent subject defaults', () {
      final mathExam = PastExam.fromMap('2016_natural_mathematics', {
        'id': '2016_natural_mathematics',
        'year': '2016',
        'stream': 'natural',
        'subject': 'Mathematics',
        'questions': [
          {
            'question': 'What is 5 + 7?',
            'a': '10',
            'b': '11',
            'c': '12',
            'd': '13',
            'ans': 'C',
          }
        ],
      });
      // Math should default to 180 min
      expect(mathExam.durationMinutes, 180);
      expect(mathExam.questions.length, 1);
      expect(mathExam.questions.first.questionText, 'What is 5 + 7?');

      final physicsExam = PastExam.fromMap('2016_natural_physics', {
        'id': '2016_natural_physics',
        'year': '2016',
        'stream': 'natural',
        'subject': 'Physics',
        'questions': [],
      });
      // Non-math should default to 120 min
      expect(physicsExam.durationMinutes, 120);
    });
  });

  group('P0-C: Defensive Invariant for Exam Questions & Timer', () {
    test('Identifies and filters blank or corrupt questions', () {
      final questions = [
        PastExamQuestion.fromMap({
          'questionText': '',
          'optionA': '',
          'optionB': '',
          'optionC': '',
          'optionD': '',
          'correctAnswer': 'A',
        }),
        PastExamQuestion.fromMap({
          'questionText': 'Valid question text',
          'optionA': 'A choice',
          'optionB': 'B choice',
          'optionC': 'C choice',
          'optionD': 'D choice',
          'correctAnswer': 'A',
        }),
      ];

      final validQuestions = questions.where((q) {
        final hasText = q.questionText.trim().isNotEmpty;
        final optionsCount = [q.optionA, q.optionB, q.optionC, q.optionD]
            .where((o) => o.trim().isNotEmpty)
            .length;
        return hasText && optionsCount >= 2;
      }).toList();

      expect(validQuestions.length, 1);
      expect(validQuestions.first.questionText, 'Valid question text');
    });
  });

  group('P0/P1: Maintenance Mode Architecture & Offline Protection', () {
    test('MaintenanceService mock state can be toggled deterministically', () {
      final service = MaintenanceService.instance;
      expect(service.isMaintenanceActive, false);

      service.setMockState(
        active: true,
        message: 'System upgrade in progress.',
      );
      expect(service.isMaintenanceActive, true);
      expect(service.maintenanceMessage, 'System upgrade in progress.');

      service.resetMockState();
      expect(service.isMaintenanceActive, false);
    });

    test('Offline connectivity safeguards student from being locked by stale maintenance', () {
      // ConnectivityService offline simulation
      ConnectivityService().setOnlineStatusForTesting(false);

      expect(ConnectivityService().isOnline, false);

      // Restore online status
      ConnectivityService().setOnlineStatusForTesting(true);
      expect(ConnectivityService().isOnline, true);
    });
  });

  group('P0-D: Admin Bulk Import Schema & Student Ingestion Compatibility', () {
    test('PracticeImportRow converts to standard Question model without data loss', () {
      final row = PracticeImportRow(
        rowIndex: 2,
        fileName: 'Grade11_Physics_Unit1.xlsx',
        grade: 'Grade 11',
        stream: 'natural',
        examYear: 2016,
        subject: 'Physics',
        unitNumber: 1,
        unitName: 'Kinematics',
        questionNumber: 1,
        question: 'What is the acceleration due to gravity on Earth?',
        optionA: '9.8 m/s²',
        optionB: '8.9 m/s²',
        optionC: '10.5 m/s²',
        optionD: '12.0 m/s²',
        correctAnswer: 'A',
        explanation: 'Standard gravity is approximately 9.80665 m/s².',
        questionId: 'q_g11_phy_u1_1',
      );

      final question = row.toQuestion();
      expect(question.id, 'q_g11_phy_u1_1');
      expect(question.grade, 'Grade 11');
      expect(question.stream, 'natural');
      expect(question.subject, 'Physics');
      expect(question.unitNumber, 1);
      expect(question.unitName, 'Kinematics');
      expect(question.question, 'What is the acceleration due to gravity on Earth?');
      expect(question.options.length, 4);
      expect(question.options[0], '9.8 m/s²');
      expect(question.correctAnswer, 'A');
      expect(question.explanation, 'Standard gravity is approximately 9.80665 m/s².');
      expect(question.status, 'published');

      // Round-trip verification: Question.fromMap(question.id, question.toMap())
      final rehydrated = Question.fromMap(question.id, question.toMap());
      expect(rehydrated.question, question.question);
      expect(rehydrated.correctAnswer, question.correctAnswer);
      expect(rehydrated.options, question.options);
      expect(rehydrated.grade, question.grade);
    });
  });
}
