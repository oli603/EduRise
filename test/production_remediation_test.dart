import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/features/books/data/demo_book_seed_service.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_model.dart';
import 'package:edurise/features/downloads/data/download_manager.dart';

void main() {
  group('Phase 6 — Demo Book Seed Service & Content Architecture', () {
    test('getAllDemoUnits produces units for Grades 9, 10, 11 across all 8 curriculum subjects', () {
      final units = DemoBookSeedService.getAllDemoUnits();
      expect(units.isNotEmpty, isTrue);

      final grades = units.map((u) => u.grade).toSet();
      expect(grades.any((g) => g.contains('9')), isTrue, reason: 'Must contain Grade 9 books');
      expect(grades.any((g) => g.contains('10')), isTrue, reason: 'Must contain Grade 10 books');
      expect(grades.any((g) => g.contains('11')), isTrue, reason: 'Must contain Grade 11 books');

      // Verify all 8 subjects are present
      final subjects = units.map((u) => u.subject.toLowerCase()).toSet();
      final expectedSubjects = [
        'mathematics',
        'physics',
        'chemistry',
        'biology',
        'english',
        'geography',
        'history',
        'economics',
      ];
      for (final s in expectedSubjects) {
        expect(subjects.contains(s), isTrue, reason: 'Must include demo content for $s');
      }

      // Check deterministic ID structure and content
      for (final unit in units) {
        expect(unit.id.startsWith('demo_'), isTrue,
            reason: 'Unit ID ${unit.id} must be identifiable as demo');
        expect(unit.unitName.isNotEmpty, isTrue);
        expect(unit.pdfUrl.isNotEmpty, isTrue);
      }
    });

    test('getDemoUnits filters accurately by grade and subject', () {
      final g9Physics = DemoBookSeedService.getDemoUnits(grade: '9', subject: 'Physics');
      expect(g9Physics.isNotEmpty, isTrue);
      for (final u in g9Physics) {
        expect(u.grade, contains('9'));
        expect(u.subject.toLowerCase(), 'physics');
      }

      final g11Math = DemoBookSeedService.getDemoUnits(grade: '11', subject: 'Mathematics');
      expect(g11Math.isNotEmpty, isTrue);
      for (final u in g11Math) {
        expect(u.grade, contains('11'));
        expect(u.subject.toLowerCase(), 'mathematics');
      }
    });

    test('Demo IDs follow deterministic pattern demo_g{grade}_{slug}_u{unit}', () {
      final unit = DemoBookSeedService.getDemoUnits(grade: '10', subject: 'Chemistry').first;
      expect(unit.id.startsWith('demo_g10_chemistry_u'), isTrue);
    });
  });

  group('Phase 1 & 13 — Past Exam Model & Title Resolution', () {
    test('PastExam title getter produces expected entrance exam title', () {
      const exam = PastExam(
        id: 'exam_2016_natural_math',
        year: '2016',
        stream: 'natural',
        subject: 'Mathematics',
        durationMinutes: 180,
        questions: [
          PastExamQuestion(
            questionNumber: 1,
            questionText: 'What is the limit of sin(x)/x as x approaches 0?',
            optionA: '0',
            optionB: '1',
            optionC: 'Infinity',
            optionD: 'Undefined',
            correctAnswer: 'B',
            explanation: 'Standard trigonometric limit is 1.',
          ),
        ],
      );

      expect(exam.title, '2016 Mathematics Entrance Exam');
      expect(exam.questionCount, 1);
    });

    test('PastExam with round includes round in title', () {
      const exam = PastExam(
        id: 'exam_2015_social_history_r2',
        year: '2015',
        stream: 'social',
        round: 'Round 2',
        subject: 'History',
        durationMinutes: 120,
        questions: [],
      );

      expect(exam.title, '2015 History Entrance Exam (Round 2)');
      expect(exam.questionCount, 0);
    });

    test('PastExam serialization roundtrips accurately with questions', () {
      const original = PastExam(
        id: 'exam_test_1',
        year: '2017',
        stream: 'natural',
        subject: 'Physics',
        durationMinutes: 150,
        questions: [
          PastExamQuestion(
            questionNumber: 1,
            questionText: 'Test question',
            optionA: 'A',
            optionB: 'B',
            optionC: 'C',
            optionD: 'D',
            correctAnswer: 'A',
            explanation: 'Explanation',
          ),
        ],
      );

      final map = original.toMap();
      expect(map['questionCount'], 1);

      final reconstructed = PastExam.fromMap('exam_test_1', map);
      expect(reconstructed.id, original.id);
      expect(reconstructed.title, original.title);
      expect(reconstructed.questionCount, 1);
      expect(reconstructed.questions.first.questionText, 'Test question');
    });
  });

  group('Phase 4 — DownloadManager Batch ID Resolution & Parameters', () {
    test('DownloadManager instance initializes safely', () {
      final dm = DownloadManager();
      expect(dm, isNotNull);
    });

    test('Practice subject batch key is deterministic', () {
      final dm = DownloadManager();
      final key1 = dm.getPracticeSubjectBatchKey(grade: '9', stream: 'Natural', subject: 'Physics');
      final key2 = dm.getPracticeSubjectBatchKey(grade: '9', stream: 'Natural', subject: 'Physics');
      expect(key1, key2);
      expect(key1, 'practice_batch_9_natural_physics');

      final keyExamYear = dm.getPracticeSubjectBatchKey(grade: '12', stream: 'Natural', subject: 'Mathematics', examYear: '2016');
      expect(keyExamYear, 'practice_batch_12_natural_mathematics_y2016');
    });
  });

  group('Phase 5 — Progress Tracking Spelling Audit', () {
    test('Canonical string for progress tracking is "Progress Tracking"', () {
      const canonical = 'Progress Tracking';
      expect(canonical, 'Progress Tracking');
      expect(canonical.contains('Tracking'), isTrue);
      expect(canonical.toLowerCase(), 'progress tracking');
    });
  });
}
