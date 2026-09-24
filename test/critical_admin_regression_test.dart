import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edurise/features/practice/data/question_model.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_model.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_service.dart';

void main() {
  group('P0-2: Question Model & Deserialization Resilience', () {
    test('Question.fromMap parses standard string payload correctly', () {
      final map = {
        'grade': 'Grade 12',
        'stream': 'natural',
        'subject': 'Physics',
        'unitNumber': 1,
        'unitName': 'Mechanics',
        'questionNumber': 1,
        'question': 'What is velocity?',
        'options': ['Speed with direction', 'Scalar distance', 'Mass times acceleration', 'None'],
        'correctAnswer': 'Speed with direction',
        'explanation': 'Velocity is displacement over time.',
        'status': 'published',
      };

      final q = Question.fromMap('q1', map);
      expect(q.id, 'q1');
      expect(q.grade, 'Grade 12');
      expect(q.stream, 'natural');
      expect(q.subject, 'Physics');
      expect(q.unitNumber, 1);
      expect(q.unitName, 'Mechanics');
      expect(q.question, 'What is velocity?');
      expect(q.options.length, 4);
      expect(q.correctAnswer, 'Speed with direction');
      expect(q.status, 'published');
    });

    test('Question.fromMap safely parses raw numbers for grade, unit, and options', () {
      // Spreadsheet / CSV imports often serialize integers or doubles
      final rawData = {
        'grade': 12, // int instead of String!
        'textbook_grade': 12,
        'unitNumber': '3', // String instead of int!
        'questionNumber': '15',
        'unitName': 3, // int instead of String!
        'question': 'Which of the following is true?',
        'options': [1, 2, 3, 4], // int options!
        'correctAnswer': 1, // int answer!
        'explanation': 100, // int explanation!
        'createdAt': 1711280000000, // int timestamp milliseconds!
        'status': 'published',
      };

      // In earlier versions, this threw `type int is not a subtype of type String in type cast`
      final q = Question.fromMap('q_num_cast', rawData);
      expect(q.grade, 'Grade 12');
      expect(q.unitNumber, 3);
      expect(q.questionNumber, 15);
      expect(q.unitName, '3');
      expect(q.options, ['1', '2', '3', '4']);
      expect(q.correctAnswer, '1');
      expect(q.explanation, '100');
      expect(q.createdAt, isNotNull);
    });

    test('Question.fromMap parses string ISO dates and Timestamps safely', () {
      final isoData = {
        'grade': 'Grade 11',
        'question': 'Test?',
        'createdAt': '2026-09-24T12:00:00.000Z',
      };
      final qIso = Question.fromMap('q_iso', isoData);
      expect(qIso.createdAt, isNotNull);
      expect(qIso.createdAt!.year, 2026);

      final tsData = {
        'grade': 'Grade 10',
        'question': 'Test?',
        'createdAt': Timestamp.fromDate(DateTime(2025, 5, 10)),
      };
      final qTs = Question.fromMap('q_ts', tsData);
      expect(qTs.createdAt, isNotNull);
      expect(qTs.createdAt!.year, 2025);
    });

    test('Question.fromMap normalizes raw grade integers (e.g. 9, 10, 11, 12)', () {
      final q9 = Question.fromMap('1', {'grade': 9, 'question': 'Q'});
      final q10 = Question.fromMap('2', {'grade': '10', 'question': 'Q'});
      final q11 = Question.fromMap('3', {'textbook_grade': 11, 'question': 'Q'});
      final q12 = Question.fromMap('4', {'textbookGrade': 'Grade 12', 'question': 'Q'});

      expect(q9.grade, 'Grade 9');
      expect(q10.grade, 'Grade 10');
      expect(q11.grade, 'Grade 11');
      expect(q12.grade, 'Grade 12');
    });
  });

  group('P0-3: Past Entrance Exam ID Resolution & Model Resilience', () {
    test('PastExamQuestion.fromMap parses diverse options and answers', () {
      final raw = {
        'questionNumber': '1',
        'questionText': 'Calculate torque.',
        'optionA': '10 Nm',
        'optionB': '20 Nm',
        'optionC': '30 Nm',
        'optionD': '40 Nm',
        'correctAnswer': 'B',
        'explanation': 'Torque = r x F.',
      };

      final q = PastExamQuestion.fromMap(raw);
      expect(q.questionNumber, 1);
      expect(q.questionText, 'Calculate torque.');
      expect(q.optionA, '10 Nm');
      expect(q.optionB, '20 Nm');
      expect(q.correctAnswer, 'B');
      expect(q.explanation, 'Torque = r x F.');
    });

    test('PastExam.fromMap parses integer duration and questions array', () {
      final examData = {
        'year': 2016, // int!
        'stream': 'natural',
        'subject': 'Physics',
        'durationMinutes': '120', // string!
        'questions': [
          {
            'questionNumber': 1,
            'questionText': 'What is inertia?',
            'optionA': 'Resistance to change',
            'optionB': 'Speed',
            'optionC': 'Force',
            'optionD': 'Work',
            'correctAnswer': 'A',
            'explanation': 'Newton first law.',
          },
        ],
      };

      final exam = PastExam.fromMap('2016_natural_Physics', examData);
      expect(exam.id, '2016_natural_Physics');
      expect(exam.year, '2016');
      expect(exam.durationMinutes, 120);
      expect(exam.questions.length, 1);
      expect(exam.questions.first.correctAnswer, 'A');
    });

    test('PastExamService mock injection handles prefixed and non-prefixed IDs', () async {
      final service = PastExamService();
      final exam = const PastExam(
        id: '2016_natural_Physics',
        year: '2016',
        stream: 'natural',
        subject: 'Physics',
        durationMinutes: 120,
        questions: [
          PastExamQuestion(
            questionNumber: 1,
            questionText: 'Test Question',
            optionA: 'A',
            optionB: 'B',
            optionC: 'C',
            optionD: 'D',
            correctAnswer: 'A',
            explanation: 'None',
          ),
        ],
      );

      service.injectMockExam(exam);

      // Verify exact ID lookup
      final res1 = await service.getPastExam('2016_natural_Physics');
      expect(res1, isNotNull);
      expect(res1!.subject, 'Physics');

      // Verify clean ID lookup when passed package prefix
      final res2 = await service.getPastExam('past_exam_2016_natural_Physics');
      expect(res2, isNotNull);
      expect(res2!.subject, 'Physics');
    });

    test('PastExamService offline fallback provides exams for standard subjects', () async {
      final service = PastExamService();
      final exams = await service.getPastExams(year: '2016', stream: 'natural');
      expect(exams, isNotEmpty);
      final subjects = exams.map((e) => e.subject).toList();
      expect(subjects, contains('Mathematics'));
      expect(subjects, contains('Physics'));
      expect(subjects, contains('Biology'));
      expect(subjects, contains('Chemistry'));
    });
  });
}
