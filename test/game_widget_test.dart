import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/game/data/game_service.dart';
import 'package:edurise/features/game/presentation/game_home_screen.dart';
import 'package:edurise/features/game/presentation/game_play_screen.dart';
import 'package:edurise/features/practice/data/local/question_store.dart';
import 'package:edurise/features/practice/data/question_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineStorageService storage;
  late QuestionStore questionStore;
  late GameService gameService;

  setUp(() async {
    storage = OfflineStorageService();
    await storage.clearLocalDataForTesting();
    await storage.init();
    questionStore = QuestionStore();
    await questionStore.init();
    gameService = GameService(storageService: storage);
  });

  tearDown(() async {
    await storage.clearLocalDataForTesting();
  });

  List<Question> generateMockQuestions({
    required String subject,
    required String stream,
    required int count,
  }) {
    return List.generate(count, (index) {
      final qId = 'q_${subject.toLowerCase()}_${stream}_${index + 1}';
      return Question(
        id: qId,
        grade: 'Grade 12',
        stream: stream,
        subject: subject,
        unitNumber: 1,
        unitName: 'Unit 1',
        questionNumber: index + 1,
        question: 'Sample Question #${index + 1} for $subject',
        options: const ['Option Alpha', 'Option Beta', 'Option Gamma', 'Option Delta'],
        correctAnswer: 'Option Alpha',
        explanation: 'Detailed explanation for $qId',
        examYear: 2017,
        examType: 'National',
        status: 'published',
      );
    });
  }

  group('GameHomeScreen Widget Tests', () {
    testWidgets('Renders Hero Banner with total stars and stream label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameHomeScreen(
            gameService: gameService,
            storageService: storage,
          ),
        ),
      );

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      expect(find.text('EduRise Game'), findsWidgets);
      expect(find.textContaining('Natural Science'), findsOneWidget);
      expect(find.textContaining('Stars'), findsWidgets);
    });

    testWidgets('Displays empty state when subject has < 5 downloaded questions', (tester) async {
      // Save only 2 questions for Mathematics (default selected subject)
      final questions = generateMockQuestions(subject: 'Mathematics', stream: 'natural', count: 2);
      await tester.runAsync(() async {
        await questionStore.saveQuestions(questions);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: GameHomeScreen(
            gameService: gameService,
            storageService: storage,
          ),
        ),
      );

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // Ensure insufficient questions banner / empty state is shown
      expect(find.textContaining('Download Practice Content for Mathematics'), findsOneWidget);
      expect(find.text('Go to Practice Downloads'), findsOneWidget);
    });

    testWidgets('Displays level cards grid when subject has >= 5 questions', (tester) async {
      final questions = generateMockQuestions(subject: 'Mathematics', stream: 'natural', count: 10);
      await tester.runAsync(() async {
        await questionStore.saveQuestions(questions);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: GameHomeScreen(
            gameService: gameService,
            storageService: storage,
          ),
        ),
      );

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // Check level 1 card is present and unlocked
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Locked'), findsWidgets);
    });
  });

  group('GamePlayScreen Widget Tests', () {
    testWidgets('Renders 5 questions flow, shows feedback, and displays result screen with stars', (tester) async {
      final questions = generateMockQuestions(subject: 'Biology', stream: 'natural', count: 10);
      await tester.runAsync(() async {
        await questionStore.saveQuestions(questions);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: GamePlayScreen(
            stream: 'natural',
            subject: 'Biology',
            levelNumber: 1,
            gameService: gameService,
            storageService: storage,
          ),
        ),
      );

      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.text('Question 1 of 5').evaluate().isNotEmpty) break;
      }

      // Verify question 1 is displayed
      expect(find.text('Question 1 of 5'), findsOneWidget);
      expect(find.text('Option Alpha'), findsOneWidget);
      expect(find.text('Option Beta'), findsOneWidget);

      // Verify NO explanation or Coach is visible
      expect(find.textContaining('Explanation'), findsNothing);
      expect(find.textContaining('Coach'), findsNothing);

      // Answer 5 questions (all correctly with Option Alpha)
      for (int i = 0; i < 5; i++) {
        expect(find.text('Option Alpha'), findsOneWidget);
        await tester.tap(find.text('Option Alpha'));
        await tester.pump();

        // Brief feedback is shown
        expect(find.text('✓ Correct!'), findsOneWidget);

        // Wait until CTA button is enabled after submitAnswer async I/O
        for (int k = 0; k < 30; k++) {
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
          final buttonFinder = find.byType(FilledButton);
          if (buttonFinder.evaluate().isNotEmpty) {
            final button = tester.widget<FilledButton>(buttonFinder.first);
            if (button.onPressed != null) {
              break;
            }
          }
        }

        final buttonFinder = find.byType(FilledButton);
        if (buttonFinder.evaluate().isNotEmpty) {
          await tester.tap(buttonFinder.first);
          await tester.pump();
        }

        for (int k = 0; k < 50; k++) {
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
          if (i < 4 && find.text('Question ${i + 2} of 5').evaluate().isNotEmpty) {
            break;
          }
          if (i == 4 && find.text('Level Passed! 🎉').evaluate().isNotEmpty) {
            break;
          }
        }
      }

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Result screen should be visible with Stars and Score 5/5
      expect(find.text('Level Passed! 🎉'), findsOneWidget);
      expect(find.text('Score: 5 / 5'), findsOneWidget);
      expect(find.text('Play Level 2 ➔'), findsOneWidget);
      expect(find.text('Replay Level for ⭐⭐⭐'), findsOneWidget);
      expect(find.text('Back to Level Map'), findsOneWidget);

      // Academic purity check: Practice results must remain empty
      final practiceResults = await storage.getLocalPracticeResults();
      expect(practiceResults, isEmpty);
    });

    testWidgets('Failing level (score < 3) shows Level Incomplete and Try Again', (tester) async {
      final questions = generateMockQuestions(subject: 'Physics', stream: 'natural', count: 10);
      await tester.runAsync(() async {
        await questionStore.saveQuestions(questions);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: GamePlayScreen(
            stream: 'natural',
            subject: 'Physics',
            levelNumber: 1,
            gameService: gameService,
            storageService: storage,
          ),
        ),
      );

      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.text('Option Beta').evaluate().isNotEmpty) break;
      }

      // Answer all 5 questions incorrectly with Option Beta
      for (int i = 0; i < 5; i++) {
        expect(find.text('Option Beta'), findsOneWidget);
        await tester.tap(find.text('Option Beta'));
        await tester.pump();

        expect(find.text('✕ Wrong!'), findsOneWidget);

        // Wait until CTA button is enabled after submitAnswer async I/O
        for (int k = 0; k < 30; k++) {
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
          final buttonFinder = find.byType(FilledButton);
          if (buttonFinder.evaluate().isNotEmpty) {
            final button = tester.widget<FilledButton>(buttonFinder.first);
            if (button.onPressed != null) {
              break;
            }
          }
        }

        final buttonFinder = find.byType(FilledButton);
        if (buttonFinder.evaluate().isNotEmpty) {
          await tester.tap(buttonFinder.first);
          await tester.pump();
        }

        for (int k = 0; k < 30; k++) {
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
          if (i < 4 && find.text('Question ${i + 2} of 5').evaluate().isNotEmpty) {
            break;
          }
          if (i == 4 && find.text('Level Incomplete').evaluate().isNotEmpty) {
            break;
          }
        }
      }

      // Result screen should show Level Incomplete
      expect(find.text('Level Incomplete'), findsOneWidget);
      expect(find.text('Score: 0 / 5'), findsOneWidget);
      expect(find.text('Retry Level (Fresh Questions)'), findsOneWidget);
      expect(find.text('Back to Level Map'), findsOneWidget);
    });
  });
}

