import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/offline/offline_storage_service.dart';
import 'package:edurise/features/game/data/game_service.dart';
import 'package:edurise/features/game/data/local/game_store.dart';
import 'package:edurise/features/game/data/models/game_models.dart';
import 'package:edurise/features/practice/data/local/question_store.dart';
import 'package:edurise/features/practice/data/question_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineStorageService storage;
  late QuestionStore questionStore;
  late GameStore gameStore;
  late GameService gameService;

  setUp(() async {
    storage = OfflineStorageService();
    await storage.init();
    await storage.clearLocalDataForTesting();

    final testDir = Directory('${Directory.systemTemp.path}/edurise_offline_test');
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
    testDir.createSync(recursive: true);
    await storage.init();
    questionStore = QuestionStore();
    await questionStore.init();
    gameStore = GameStore();
    await gameStore.init();

    gameService = GameService(gameStore: gameStore, questionStore: questionStore);
  });

  tearDown(() async {
    await storage.clearLocalDataForTesting();
    gameStore.clearMemoryCache();
    questionStore.clearMemoryCache();
    final testDir = Directory('${Directory.systemTemp.path}/edurise_offline_test');
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  List<Question> generateMockQuestions({
    required String subject,
    required String stream,
    required int count,
    String grade = 'Grade 12',
    int unit = 1,
  }) {
    return List.generate(count, (index) {
      final qId = 'q_${subject.toLowerCase()}_${stream}_${index + 1}';
      return Question(
        id: qId,
        grade: grade,
        stream: stream,
        subject: subject,
        unitNumber: unit,
        unitName: 'Unit $unit',
        questionNumber: index + 1,
        question: 'What is question #${index + 1} in $subject ($stream)?',
        options: const ['Option A', 'Option B', 'Option C', 'Option D'],
        correctAnswer: 'Option A',
        explanation: 'Detailed explanation for $qId',
        examYear: 2017,
        examType: 'National',
        status: 'published',
      );
    });
  }

  group('1. Game Models & Serialization', () {
    test('GameLevelRecord serialization and copyWith', () {
      final now = DateTime.now();
      final record = GameLevelRecord(
        levelNumber: 1,
        isUnlocked: true,
        isPassed: true,
        bestScore: 4,
        bestStars: 2,
        attemptsCount: 3,
        lastPlayedAt: now,
        lastQuestionIds: const ['q1', 'q2', 'q3', 'q4', 'q5'],
      );

      final map = record.toMap();
      final fromMap = GameLevelRecord.fromMap(map);

      expect(fromMap.levelNumber, 1);
      expect(fromMap.isUnlocked, isTrue);
      expect(fromMap.isPassed, isTrue);
      expect(fromMap.bestScore, 4);
      expect(fromMap.bestStars, 2);
      expect(fromMap.attemptsCount, 3);
      expect(fromMap.lastQuestionIds, ['q1', 'q2', 'q3', 'q4', 'q5']);

      final updated = record.copyWith(bestScore: 5, bestStars: 3);
      expect(updated.bestScore, 5);
      expect(updated.bestStars, 3);
      expect(updated.attemptsCount, 3);
    });

    test('ActiveGameLevelState serialization and round-trip', () {
      final now = DateTime.now();
      final state = ActiveGameLevelState(
        subject: 'Biology',
        stream: 'natural',
        levelNumber: 2,
        questionIds: const ['q1', 'q2', 'q3', 'q4', 'q5'],
        currentIndex: 2,
        answers: const {0: 'Option A', 1: 'Option B'},
        score: 1,
        isCompleted: false,
        startedAt: now,
      );

      final map = state.toMap();
      final restored = ActiveGameLevelState.fromMap(map);

      expect(restored.subject, 'Biology');
      expect(restored.stream, 'natural');
      expect(restored.levelNumber, 2);
      expect(restored.questionIds, ['q1', 'q2', 'q3', 'q4', 'q5']);
      expect(restored.currentIndex, 2);
      expect(restored.answers[0], 'Option A');
      expect(restored.answers[1], 'Option B');
      expect(restored.score, 1);
      expect(restored.isCompleted, isFalse);
    });

    test('GameProgressSummary serialization and star calculations', () {
      final summary = GameProgressSummary(
        subject: 'Biology',
        stream: 'natural',
        levels: {
          1: const GameLevelRecord(levelNumber: 1, isUnlocked: true, isPassed: true, bestScore: 5, bestStars: 3),
          2: const GameLevelRecord(levelNumber: 2, isUnlocked: true, isPassed: true, bestScore: 3, bestStars: 1),
          3: const GameLevelRecord(levelNumber: 3, isUnlocked: true, isPassed: false, bestScore: 2, bestStars: 0),
          4: const GameLevelRecord(levelNumber: 4, isUnlocked: false, isPassed: false, bestScore: 0, bestStars: 0),
        },
        recentQuestionHistory: const ['q1', 'q2', 'q3', 'q4', 'q5'],
      );

      expect(summary.totalStars, 4);
      expect(summary.passedLevelsCount, 2);
      expect(summary.highestUnlockedLevel, 3);

      final map = summary.toMap();
      final restored = GameProgressSummary.fromMap(map);

      expect(restored.subject, 'Biology');
      expect(restored.stream, 'natural');
      expect(restored.totalStars, 4);
      expect(restored.levels.length, 4);
      expect(restored.levels[1]?.bestStars, 3);
      expect(restored.levels[2]?.bestStars, 1);
      expect(restored.levels[3]?.bestStars, 0);
      expect(restored.levels[4]?.isUnlocked, isFalse);
    });
  });

  group('2. Scoring and Stars Thresholds', () {
    test('0, 1, 2 correct answers yield 0 Stars and FAIL', () {
      expect(gameService.calculateStars(0), 0);
      expect(gameService.isLevelPassed(0), isFalse);

      expect(gameService.calculateStars(1), 0);
      expect(gameService.isLevelPassed(1), isFalse);

      expect(gameService.calculateStars(2), 0);
      expect(gameService.isLevelPassed(2), isFalse);
    });

    test('3 correct answers yields 1 Star and PASS', () {
      expect(gameService.calculateStars(3), 1);
      expect(gameService.isLevelPassed(3), isTrue);
    });

    test('4 correct answers yields 2 Stars and PASS', () {
      expect(gameService.calculateStars(4), 2);
      expect(gameService.isLevelPassed(4), isTrue);
    });

    test('5 correct answers yields 3 Stars and PASS', () {
      expect(gameService.calculateStars(5), 3);
      expect(gameService.isLevelPassed(5), isTrue);
    });

    test('Maximum stars is strictly 3', () {
      expect(gameService.calculateStars(5), 3);
      expect(gameService.calculateStars(6), 3);
      expect(gameService.calculateStars(10), 3);
    });
  });

  group('3. Stream Subjects and Question Pool Validation', () {
    test('Natural stream subjects contain Biology, Chemistry, Physics, Natural Mathematics', () {
      final subjects = gameService.getAvailableSubjectsForStream('natural');
      expect(subjects, contains('Biology'));
      expect(subjects, contains('Chemistry'));
      expect(subjects, contains('Physics'));
      expect(subjects, contains('Mathematics'));
      expect(subjects, contains('English'));
      expect(subjects, isNot(contains('Economics')));
      expect(subjects, isNot(contains('Geography')));
    });

    test('Social stream subjects contain Geography, History, Economics, Social Mathematics', () {
      final subjects = gameService.getAvailableSubjectsForStream('social');
      expect(subjects, contains('Geography'));
      expect(subjects, contains('History'));
      expect(subjects, contains('Economics'));
      expect(subjects, contains('Mathematics'));
      expect(subjects, contains('English'));
      expect(subjects, isNot(contains('Biology')));
      expect(subjects, isNot(contains('Physics')));
    });

    test('InsufficientQuestionsException thrown when fewer than 5 questions exist', () async {
      // Save only 3 questions
      final questions = generateMockQuestions(subject: 'Biology', stream: 'natural', count: 3);
      await questionStore.saveQuestions(questions);

      expect(
        () => gameService.startOrResumeLevel(stream: 'natural', subject: 'Biology', levelNumber: 1),
        throwsA(isA<InsufficientQuestionsException>()),
      );
    });
  });

  group('4. Level Generation & Question Integrity', () {
    test('Generates EXACTLY 5 questions per level with no duplicates within level', () async {
      final questions = generateMockQuestions(subject: 'Physics', stream: 'natural', count: 20);
      await questionStore.saveQuestions(questions);

      final (activeState, levelQuestions) = await gameService.startOrResumeLevel(
        stream: 'natural',
        subject: 'Physics',
        levelNumber: 1,
      );

      expect(activeState.questionIds.length, 5);
      expect(levelQuestions.length, 5);
      final uniqueIds = activeState.questionIds.toSet();
      expect(uniqueIds.length, 5, reason: 'Level must contain 5 unique question IDs without internal duplicates');
    });

    test('Avoids immediate question repetition between consecutive levels when pool >= 10', () async {
      final questions = generateMockQuestions(subject: 'Chemistry', stream: 'natural', count: 15);
      await questionStore.saveQuestions(questions);

      // Start Level 1
      var (l1State, _) = await gameService.startOrResumeLevel(
        stream: 'natural',
        subject: 'Chemistry',
        levelNumber: 1,
      );
      final l1Ids = List<String>.from(l1State.questionIds);

      // Simulate completing Level 1 with 5/5
      for (int i = 0; i < 5; i++) {
        l1State = await gameService.submitAnswer(
          state: l1State,
          questionIndex: i,
          selectedAnswer: 'Option A',
          isCorrect: true,
        );
      }
      await gameService.completeLevel(state: l1State);

      // Start Level 2
      final (l2State, _) = await gameService.startOrResumeLevel(
        stream: 'natural',
        subject: 'Chemistry',
        levelNumber: 2,
      );
      final l2Ids = l2State.questionIds;

      expect(l2Ids.length, 5);
      // Because pool is 15 >= 10, Level 2 should prioritize remaining 10 questions and have 0 intersection with Level 1
      final overlap = l1Ids.toSet().intersection(l2Ids.toSet());
      expect(overlap.isEmpty, isTrue, reason: 'Level 2 should not immediately repeat Level 1 questions when pool is >= 10');
    });
  });

  group('5. Level Progression and Unlocking Rules', () {
    test('Failing a level (score < 3) leaves next level locked', () async {
      final questions = generateMockQuestions(subject: 'Biology', stream: 'natural', count: 15);
      await questionStore.saveQuestions(questions);

      var (state, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Biology', levelNumber: 1);

      // Answer 2 correctly and 3 incorrectly -> score = 2
      state = await gameService.submitAnswer(state: state, questionIndex: 0, selectedAnswer: 'Option A', isCorrect: true);
      state = await gameService.submitAnswer(state: state, questionIndex: 1, selectedAnswer: 'Option A', isCorrect: true);
      state = await gameService.submitAnswer(state: state, questionIndex: 2, selectedAnswer: 'Option B', isCorrect: false);
      state = await gameService.submitAnswer(state: state, questionIndex: 3, selectedAnswer: 'Option B', isCorrect: false);
      state = await gameService.submitAnswer(state: state, questionIndex: 4, selectedAnswer: 'Option B', isCorrect: false);

      final result = await gameService.completeLevel(state: state);

      expect(result.levelRecord.isPassed, isFalse);
      expect(result.levelRecord.bestStars, 0);
      expect(result.levelRecord.bestScore, 2);
      expect(result.unlockedNextLevel, isFalse);

      final summary = await gameService.getGameProgress(stream: 'natural', subject: 'Biology');
      expect(summary.levels[1]?.isPassed, isFalse);
      expect(summary.levels[1]?.bestStars, 0);
      expect(summary.levels[2]?.isUnlocked ?? false, isFalse, reason: 'Level 2 must remain locked after Level 1 FAIL');
    });

    test('Passing Level 1 with 3/5 unlocks Level 2 and awards 1 Star', () async {
      final questions = generateMockQuestions(subject: 'Biology', stream: 'natural', count: 15);
      await questionStore.saveQuestions(questions);

      var (state, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Biology', levelNumber: 1);

      // Answer 3 correctly and 2 incorrectly -> score = 3
      state = await gameService.submitAnswer(state: state, questionIndex: 0, selectedAnswer: 'Option A', isCorrect: true);
      state = await gameService.submitAnswer(state: state, questionIndex: 1, selectedAnswer: 'Option A', isCorrect: true);
      state = await gameService.submitAnswer(state: state, questionIndex: 2, selectedAnswer: 'Option A', isCorrect: true);
      state = await gameService.submitAnswer(state: state, questionIndex: 3, selectedAnswer: 'Option B', isCorrect: false);
      state = await gameService.submitAnswer(state: state, questionIndex: 4, selectedAnswer: 'Option B', isCorrect: false);

      final result = await gameService.completeLevel(state: state);

      expect(result.levelRecord.isPassed, isTrue);
      expect(result.levelRecord.bestStars, 1);
      expect(result.levelRecord.bestScore, 3);
      expect(result.unlockedNextLevel, isTrue);

      final summary = await gameService.getGameProgress(stream: 'natural', subject: 'Biology');
      expect(summary.levels[1]?.isPassed, isTrue);
      expect(summary.levels[1]?.bestStars, 1);
      expect(summary.levels[2]?.isUnlocked, isTrue, reason: 'Level 2 must unlock after Level 1 PASS');
      expect(summary.totalStars, 1);
    });

    test('Passing Level 2 with 5/5 unlocks Level 3 and awards 3 Stars', () async {
      final questions = generateMockQuestions(subject: 'Biology', stream: 'natural', count: 15);
      await questionStore.saveQuestions(questions);

      // Unlock Level 2 by passing Level 1
      var (l1State, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Biology', levelNumber: 1);
      for (int i = 0; i < 3; i++) {
        l1State = await gameService.submitAnswer(state: l1State, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      for (int i = 3; i < 5; i++) {
        l1State = await gameService.submitAnswer(state: l1State, questionIndex: i, selectedAnswer: 'Option B', isCorrect: false);
      }
      await gameService.completeLevel(state: l1State);

      // Now play Level 2 and score 5/5
      var (l2State, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Biology', levelNumber: 2);
      for (int i = 0; i < 5; i++) {
        l2State = await gameService.submitAnswer(state: l2State, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      final l2Result = await gameService.completeLevel(state: l2State);

      expect(l2Result.levelRecord.isPassed, isTrue);
      expect(l2Result.levelRecord.bestStars, 3);
      expect(l2Result.levelRecord.bestScore, 5);
      expect(l2Result.unlockedNextLevel, isTrue);

      final summary = await gameService.getGameProgress(stream: 'natural', subject: 'Biology');
      expect(summary.levels[2]?.bestStars, 3);
      expect(summary.levels[3]?.isUnlocked, isTrue, reason: 'Level 3 must unlock after Level 2 PASS');
      expect(summary.totalStars, 4); // 1 from L1 + 3 from L2
    });
  });

  group('6. Retry and Star Improvement Logic', () {
    test('Replaying a passed level with higher score updates bestStars and bestScore', () async {
      final questions = generateMockQuestions(subject: 'Mathematics', stream: 'natural', count: 10);
      await questionStore.saveQuestions(questions);

      // First attempt: 3/5 -> 1 Star
      var (attempt1State, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Mathematics', levelNumber: 1);
      for (int i = 0; i < 3; i++) {
        attempt1State = await gameService.submitAnswer(state: attempt1State, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      for (int i = 3; i < 5; i++) {
        attempt1State = await gameService.submitAnswer(state: attempt1State, questionIndex: i, selectedAnswer: 'Option B', isCorrect: false);
      }
      await gameService.completeLevel(state: attempt1State);

      var summary = await gameService.getGameProgress(stream: 'natural', subject: 'Mathematics');
      expect(summary.levels[1]?.bestStars, 1);
      expect(summary.levels[1]?.bestScore, 3);
      expect(summary.levels[1]?.attemptsCount, 1);

      // Second attempt: 5/5 -> 3 Stars (Improved)
      var (attempt2State, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Mathematics', levelNumber: 1, forceNew: true);
      for (int i = 0; i < 5; i++) {
        attempt2State = await gameService.submitAnswer(state: attempt2State, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      await gameService.completeLevel(state: attempt2State);

      summary = await gameService.getGameProgress(stream: 'natural', subject: 'Mathematics');
      expect(summary.levels[1]?.bestStars, 3, reason: 'Stars must improve from 1 to 3');
      expect(summary.levels[1]?.bestScore, 5, reason: 'Best score must update from 3 to 5');
      expect(summary.levels[1]?.attemptsCount, 2);
    });

    test('Replaying a passed level with lower score NEVER downgrades bestStars or bestScore', () async {
      final questions = generateMockQuestions(subject: 'Mathematics', stream: 'natural', count: 10);
      await questionStore.saveQuestions(questions);

      // First attempt: 5/5 -> 3 Stars
      var (attempt1State, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Mathematics', levelNumber: 1);
      for (int i = 0; i < 5; i++) {
        attempt1State = await gameService.submitAnswer(state: attempt1State, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      await gameService.completeLevel(state: attempt1State);

      var summary = await gameService.getGameProgress(stream: 'natural', subject: 'Mathematics');
      expect(summary.levels[1]?.bestStars, 3);
      expect(summary.levels[1]?.bestScore, 5);

      // Second attempt: 1/5 -> 0 Stars (Failed replay)
      var (attempt2State, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Mathematics', levelNumber: 1, forceNew: true);
      attempt2State = await gameService.submitAnswer(state: attempt2State, questionIndex: 0, selectedAnswer: 'Option A', isCorrect: true);
      for (int i = 1; i < 5; i++) {
        attempt2State = await gameService.submitAnswer(state: attempt2State, questionIndex: i, selectedAnswer: 'Option B', isCorrect: false);
      }
      await gameService.completeLevel(state: attempt2State);

      summary = await gameService.getGameProgress(stream: 'natural', subject: 'Mathematics');
      expect(summary.levels[1]?.bestStars, 3, reason: 'Stars must NEVER downgrade on a lower replay');
      expect(summary.levels[1]?.bestScore, 5, reason: 'Best score must NEVER downgrade on a lower replay');
      expect(summary.levels[1]?.isPassed, isTrue, reason: 'Passed status must remain true');
      expect(summary.levels[1]?.attemptsCount, 2);
    });
  });

  group('7. Active Level Session Persistence and Resume', () {
    test('Mid-level state is preserved and restored identically', () async {
      final questions = generateMockQuestions(subject: 'Physics', stream: 'natural', count: 10);
      await questionStore.saveQuestions(questions);

      // Start level
      var (initialState, _) = await gameService.startOrResumeLevel(
        stream: 'natural',
        subject: 'Physics',
        levelNumber: 1,
      );
      final qIds = initialState.questionIds;

      // Submit 2 answers
      initialState = await gameService.submitAnswer(state: initialState, questionIndex: 0, selectedAnswer: 'Option A', isCorrect: true);
      initialState = await gameService.submitAnswer(state: initialState, questionIndex: 1, selectedAnswer: 'Option A', isCorrect: true);

      // Simulate app restart / re-loading GameService
      final newGameService = GameService(storageService: storage);
      final (resumedState, _) = await newGameService.startOrResumeLevel(
        stream: 'natural',
        subject: 'Physics',
        levelNumber: 1,
      );

      expect(resumedState.questionIds, qIds, reason: 'Questions must be identical upon resume');
      expect(resumedState.currentIndex, 2, reason: 'Current index should be 2 after answering 2 questions');
      expect(resumedState.score, 2, reason: 'Score should be preserved across session resume');
      expect(resumedState.answers[0], 'Option A');
      expect(resumedState.answers[1], 'Option A');
    });

    test('Active level is cleared upon completion', () async {
      final questions = generateMockQuestions(subject: 'Physics', stream: 'natural', count: 10);
      await questionStore.saveQuestions(questions);

      var (state, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Physics', levelNumber: 1);
      for (int i = 0; i < 5; i++) {
        state = await gameService.submitAnswer(state: state, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      await gameService.completeLevel(state: state);

      final active = await gameStore.getActiveGameLevel();
      expect(active, isNull, reason: 'Active level must be cleared from storage when level finishes');
    });
  });

  group('8. Academic Purity & Zero Practice Pollution', () {
    test('Game play does NOT touch practice_results or academic statistics', () async {
      final questions = generateMockQuestions(subject: 'Biology', stream: 'natural', count: 10);
      await questionStore.saveQuestions(questions);

      // Play through a complete Game level
      var (state, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Biology', levelNumber: 1);
      for (int i = 0; i < 5; i++) {
        state = await gameService.submitAnswer(state: state, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      await gameService.completeLevel(state: state);

      // Verify that practice results storage is completely empty
      final practiceResults = await storage.getLocalPracticeResults();
      expect(practiceResults, isEmpty, reason: 'Game answers MUST NOT be saved into practice_results.json');

      // Verify that offline questions pool is unchanged
      final storedQuestions = await questionStore.getOfflineQuestionsForSubject(stream: 'natural', subject: 'Biology');
      expect(storedQuestions.length, 10);
    });

    test('Game total stars calculates accurately across multiple subjects', () async {
      final bioQuestions = generateMockQuestions(subject: 'Biology', stream: 'natural', count: 10);
      final chemQuestions = generateMockQuestions(subject: 'Chemistry', stream: 'natural', count: 10);
      await questionStore.saveQuestions(bioQuestions);
      await questionStore.saveQuestions(chemQuestions);

      // Play Biology Level 1 -> 3 stars
      var (bioState, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Biology', levelNumber: 1);
      for (int i = 0; i < 5; i++) {
        bioState = await gameService.submitAnswer(state: bioState, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      await gameService.completeLevel(state: bioState);

      // Play Chemistry Level 1 -> 2 stars
      var (chemState, _) = await gameService.startOrResumeLevel(stream: 'natural', subject: 'Chemistry', levelNumber: 1);
      for (int i = 0; i < 4; i++) {
        chemState = await gameService.submitAnswer(state: chemState, questionIndex: i, selectedAnswer: 'Option A', isCorrect: true);
      }
      chemState = await gameService.submitAnswer(state: chemState, questionIndex: 4, selectedAnswer: 'Option B', isCorrect: false);
      await gameService.completeLevel(state: chemState);

      final totalStars = await gameService.getTotalStarsForStream('natural');
      expect(totalStars, 5, reason: 'Total stream stars must be 3 (Bio) + 2 (Chem) = 5');
    });
  });
}
