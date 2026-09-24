import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/coach/data/coach_service.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_model.dart';
import 'package:edurise/features/past_entrance_exams/data/past_exam_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OfflineStorageService.instance.initialize();
  });

  group('EduRise Coach Subsystem - Architecture & Integration Tests', () {
    test('1. OfflineStorageService caches and retrieves coach content locally', () async {
      final storage = OfflineStorageService.instance;

      final testExplanation = {
        'question_id': 'q_test_123',
        'why_correct': 'Option B is mathematically sound based on calculus integration rules.',
        'options_breakdown': {
          'A': 'Derivative was taken instead of integral.',
          'B': 'Correctly computed antiderivative with constant of integration.',
          'C': 'Sign error in power rule.',
          'D': 'Constant of integration was omitted.',
        },
        'key_takeaway': 'Always remember + C for indefinite integrals.',
        'cached': true,
      };

      await storage.saveCoachContentLocally(
        feature: 'explain_more',
        contentId: 'q_test_123',
        content: testExplanation,
      );

      final retrieved = storage.getLocalCoachContent(
        feature: 'explain_more',
        contentId: 'q_test_123',
      );

      expect(retrieved, isNotNull);
      expect(retrieved!['question_id'], equals('q_test_123'));
      expect(retrieved['why_correct'], contains('calculus integration rules'));
      expect(retrieved['cached'], isTrue);
    });

    test('2. Textbook tools caching: Summary, Flashcards, AI Notes, Understand, Quiz', () async {
      final storage = OfflineStorageService.instance;

      // 2a. Summary caching
      await storage.saveCoachContentLocally(
        feature: 'book_summary',
        contentId: 'math_g12_unit_1_summary',
        content: {
          'overview': 'Unit 1 covers Sequences and Series in depth.',
          'key_concepts': ['Arithmetic Progression', 'Geometric Progression'],
        },
      );
      final summary = storage.getLocalCoachContent(
        feature: 'book_summary',
        contentId: 'math_g12_unit_1_summary',
      );
      expect(summary, isNotNull);
      expect(summary!['overview'], contains('Sequences and Series'));

      // 2b. Flashcards caching
      await storage.saveCoachContentLocally(
        feature: 'book_flashcards',
        contentId: 'bio_g12_unit_2_flashcards',
        content: {
          'flashcards': [
            {'front': 'What is ATP?', 'back': 'Adenosine Triphosphate, energy currency of cell.'}
          ]
        },
      );
      final flashcards = storage.getLocalCoachContent(
        feature: 'book_flashcards',
        contentId: 'bio_g12_unit_2_flashcards',
      );
      expect(flashcards, isNotNull);
      expect((flashcards!['flashcards'] as List).length, equals(1));

      // 2c. 7-Question Unit Quiz caching
      await storage.saveCoachContentLocally(
        feature: 'book_quiz',
        contentId: 'phy_g12_unit_3_quiz',
        content: {
          'questions': List.generate(
            7,
            (i) => {
              'question_number': i + 1,
              'question_text': 'Physics test question ${i + 1}',
              'options': {'A': 'Opt A', 'B': 'Opt B', 'C': 'Opt C', 'D': 'Opt D'},
              'correct_answer': 'A',
              'explanation': 'Explanation $i',
            },
          ),
        },
      );
      final quiz = storage.getLocalCoachContent(
        feature: 'book_quiz',
        contentId: 'phy_g12_unit_3_quiz',
      );
      expect(quiz, isNotNull);
      final qList = quiz!['questions'] as List;
      expect(qList.length, equals(7)); // STRICT 7 questions requirement
    });

    test('3. Predicted Mock Exam injection & offline lookup', () async {
      final pastService = PastExamService();

      final mockExam = PastExam(
        id: 'predicted_mock_Physics_natural',
        year: '2018 Predicted',
        subject: 'Physics',
        stream: 'natural',
        durationMinutes: 120,
        questions: [
          PastExamQuestion(
            id: 'mock_q1',
            questionNumber: 1,
            questionText: 'Which of the following describes Gauss’s Law in electrostatics?',
            optionA: 'Flux is proportional to enclosed charge',
            optionB: 'Voltage equals current times resistance',
            optionC: 'Force equals mass times acceleration',
            optionD: 'Energy cannot be created or destroyed',
            correctAnswer: 'Flux is proportional to enclosed charge',
            explanation: 'Gauss Law states electric flux through a closed surface is Q_enc / epsilon_0.',
          ),
        ],
      );

      pastService.injectMockExam(mockExam);

      final retrieved = await pastService.getPastExam('predicted_mock_Physics_natural');
      expect(retrieved, isNotNull);
      expect(retrieved!.subject, equals('Physics'));
      expect(retrieved.year, equals('2018 Predicted'));
      expect(retrieved.questions.first.questionText, contains('Gauss'));
    });

    test('4. CoachService explains question using local cached content when offline', () async {
      final storage = OfflineStorageService.instance;
      final coachService = CoachService.instance;

      await storage.saveCoachContentLocally(
        feature: 'explain_more',
        contentId: 'q_offline_456',
        content: {
          'question_id': 'q_offline_456',
          'core_concept': 'Conservation of Linear Momentum',
          'why_correct': 'Total initial momentum equals total final momentum in an isolated system.',
          'options_breakdown': {
            'A': 'Incorrectly adds velocity vectors as scalars.',
            'B': 'Correctly applies vector conservation of momentum.',
            'C': 'Assumes kinetic energy is conserved in inelastic collision.',
            'D': 'Wrong units.',
          },
          'common_trap': 'Do not confuse momentum conservation with kinetic energy conservation.',
          'key_takeaway': 'Momentum is always conserved in isolated collisions.',
          'cached': true,
        },
      );

      final res = await coachService.explainQuestion(
        questionId: 'q_offline_456',
        questionText: 'Two gliders collide on an air track...',
        options: {'A': '1.2 m/s', 'B': '2.4 m/s', 'C': '3.6 m/s', 'D': '4.8 m/s'},
        correctAnswer: 'B',
      );

      expect(res['core_concept'], equals('Conservation of Linear Momentum'));
      expect(res['why_correct'], contains('Total initial momentum equals total final momentum'));
      expect(res['cached'], isTrue);
    });
  });
}
