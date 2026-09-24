import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_subjects.dart';
import '../../practice/data/local/question_store.dart';
import '../../practice/data/question_model.dart';
import 'local/game_store.dart';
import 'models/game_models.dart';

/// Exception thrown when the local practice question pool has fewer than 5 valid questions.
class InsufficientQuestionsException implements Exception {
  final String message;
  final int availableCount;
  final int requiredCount;

  const InsufficientQuestionsException({
    required this.message,
    required this.availableCount,
    this.requiredCount = 5,
  });

  @override
  String toString() => message;
}

/// Result summary returned after completing a 5-question level.
class GameLevelCompletionResult {
  final String subject;
  final String stream;
  final int levelNumber;
  final int score; // 0 to 5
  final int stars; // 0 to 3
  final bool isPassed;
  final bool unlockedNextLevel;
  final int bestStars;
  final int bestScore;

  const GameLevelCompletionResult({
    required this.subject,
    required this.stream,
    required this.levelNumber,
    required this.score,
    required this.stars,
    required this.isPassed,
    required this.unlockedNextLevel,
    required this.bestStars,
    required this.bestScore,
  });

  GameLevelRecord get levelRecord => GameLevelRecord(
        levelNumber: levelNumber,
        isUnlocked: true,
        isPassed: isPassed,
        bestScore: bestScore,
        bestStars: bestStars,
      );
}

/// Core Game Service managing offline level generation, progression, star calculations,
/// and deterministic 5-question session management.
class GameService {
  static final GameService _instance = GameService._internal();
  factory GameService({
    GameStore? gameStore,
    QuestionStore? questionStore,
    dynamic storageService,
  }) {
    if (gameStore != null || questionStore != null) {
      return GameService._withStores(
        gameStore ?? GameStore(),
        questionStore ?? QuestionStore(),
      );
    }
    return _instance;
  }
  GameService._internal()
      : _gameStore = GameStore(),
        _questionStore = QuestionStore();
  GameService._withStores(this._gameStore, this._questionStore);

  final GameStore _gameStore;
  final QuestionStore _questionStore;

  String get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // SUBJECTS & LOCAL POOL INSPECTION
  // ============================================================

  /// Returns canonical subjects available for the student's authoritative stream.
  List<String> getAvailableSubjectsForStream(String stream) {
    final canonicalStream = stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';
    return EduRiseSubjects.getPracticeSubjects(stream: canonicalStream);
  }

  /// Returns the number of valid published practice questions downloaded locally for a subject.
  Future<int> getSubjectQuestionCount({
    required String stream,
    required String subject,
  }) async {
    final canonicalSubject = EduRiseSubjects.canonicalize(subject);
    final questions = await _questionStore.getOfflineQuestionsForSubject(
      stream: stream,
      subject: canonicalSubject,
    );
    return questions.where(_isValidQuestion).length;
  }

  /// Retrieves the stored game progress for a given stream and subject.
  Future<GameProgressSummary> getGameProgress({
    String? userId,
    required String stream,
    required String subject,
  }) async {
    final canonicalSubject = EduRiseSubjects.canonicalize(subject);
    final canonicalStream = stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';
    final effectiveUid = userId ?? _currentUserId;
    return _gameStore.getGameProgress(
      userId: effectiveUid,
      stream: canonicalStream,
      subject: canonicalSubject,
    );
  }

  /// Calculates total stars accumulated across all subjects in a given stream.
  Future<int> getTotalStarsForStream(String stream, {String? userId}) async {
    final subjects = getAvailableSubjectsForStream(stream);
    int total = 0;
    for (final subject in subjects) {
      final progress = await getGameProgress(
        userId: userId,
        stream: stream,
        subject: subject,
      );
      total += progress.totalStars;
    }
    return total;
  }

  // ============================================================
  // STAR CALCULATION & SCORING RULES
  //
  // 0 correct -> FAIL (0 stars)
  // 1 correct -> FAIL (0 stars)
  // 2 correct -> FAIL (0 stars)
  // 3 correct -> PASS + 1 Star (⭐)
  // 4 correct -> PASS + 2 Stars (⭐⭐)
  // 5 correct -> PASS + 3 Stars (⭐⭐⭐)
  // Max stars = 3
  // ============================================================

  int calculateStars(int score) {
    if (score >= 5) return 3;
    if (score == 4) return 2;
    if (score == 3) return 1;
    return 0;
  }

  bool isLevelPassed(int score) => score >= 3;

  // ============================================================
  // LEVEL SESSION MANAGEMENT & DETERMINISTIC 5-QUESTION SELECTION
  //
  // Selection Algorithm:
  // 1. Fetch all published local practice questions for the subject.
  // 2. Filter out questions with invalid options or missing answers.
  // 3. If available < 5, throw InsufficientQuestionsException.
  // 4. Inspect recent question history to minimize repetition.
  // 5. Select exactly 5 unique questions deterministically for the active level.
  // 6. Persist ActiveGameLevelState locally so progress is preserved across app kills.
  // ============================================================

  Future<(ActiveGameLevelState, List<Question>)> startLevel({
    String? userId,
    required String stream,
    required String subject,
    required int levelNumber,
    bool forceNew = false,
  }) async {
    final canonicalSubject = EduRiseSubjects.canonicalize(subject);
    final canonicalStream = stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';
    final effectiveUid = userId ?? _currentUserId;

    // 1. Check if there's an active in-progress level session for this user
    if (!forceNew) {
      final active = await _gameStore.getActiveGameLevel(userId: effectiveUid);
      if (active != null &&
          active.subject.toLowerCase() == canonicalSubject.toLowerCase() &&
          active.levelNumber == levelNumber &&
          !active.isCompleted &&
          active.questionIds.length == 5) {
        // Load the stored 5 questions
        final questions = await _questionStore.getOfflineQuestionsForSubject(
          stream: canonicalStream,
          subject: canonicalSubject,
        );
        final questionMap = {for (var q in questions) q.id: q};
        final List<Question> levelQuestions = [];
        for (final qId in active.questionIds) {
          if (questionMap.containsKey(qId)) {
            levelQuestions.add(questionMap[qId]!);
          }
        }
        if (levelQuestions.length == 5) {
          return (active, levelQuestions);
        }
      }
    }

    // 2. Load available questions from local Practice question pool
    final allQuestions = await _questionStore.getOfflineQuestionsForSubject(
      stream: canonicalStream,
      subject: canonicalSubject,
    );

    final validQuestions = allQuestions.where(_isValidQuestion).toList();

    if (validQuestions.length < 5) {
      throw InsufficientQuestionsException(
        message: 'Not enough downloaded questions for $canonicalSubject. '
            'Download more Practice content first.',
        availableCount: validQuestions.length,
        requiredCount: 5,
      );
    }

    // 3. Load progression summary to get recent question history
    final progress = await _gameStore.getGameProgress(
      userId: effectiveUid,
      stream: canonicalStream,
      subject: canonicalSubject,
    );

    final recentIds = progress.recentQuestionHistory.toSet();

    // Separate candidate questions into fresh (not recently used) vs reused
    final freshPool = validQuestions.where((q) => !recentIds.contains(q.id)).toList();
    final List<Question> selectedQuestions = [];

    final random = Random();

    // If fresh pool has at least 5 questions, pick from fresh pool
    if (freshPool.length >= 5) {
      freshPool.shuffle(random);
      selectedQuestions.addAll(freshPool.take(5));
    } else {
      // Use all available fresh questions first, then fill from remaining pool without duplicates
      selectedQuestions.addAll(freshPool);
      final remainingPool = validQuestions.where((q) => !selectedQuestions.contains(q)).toList();
      remainingPool.shuffle(random);
      final needed = 5 - selectedQuestions.length;
      selectedQuestions.addAll(remainingPool.take(needed));
    }

    // Ensure strictly 5 unique questions
    final uniqueSelected = <String, Question>{};
    for (final q in selectedQuestions) {
      uniqueSelected[q.id] = q;
    }

    if (uniqueSelected.length < 5) {
      for (final q in validQuestions) {
        if (!uniqueSelected.containsKey(q.id)) {
          uniqueSelected[q.id] = q;
        }
        if (uniqueSelected.length == 5) break;
      }
    }

    final final5Questions = uniqueSelected.values.take(5).toList();

    final activeState = ActiveGameLevelState(
      subject: canonicalSubject,
      stream: canonicalStream,
      levelNumber: levelNumber,
      questionIds: final5Questions.map((q) => q.id).toList(),
      currentIndex: 0,
      answers: const {},
      score: 0,
      isCompleted: false,
      startedAt: DateTime.now(),
    );

    await _gameStore.saveActiveGameLevel(activeState, userId: effectiveUid);

    return (activeState, final5Questions);
  }

  Future<(ActiveGameLevelState, List<Question>)> startOrResumeLevel({
    String? userId,
    required String stream,
    required String subject,
    required int levelNumber,
    bool forceNew = false,
  }) =>
      startLevel(
        userId: userId,
        stream: stream,
        subject: subject,
        levelNumber: levelNumber,
        forceNew: forceNew,
      );

  // ============================================================
  // QUESTION VALIDATION
  // ============================================================

  bool _isValidQuestion(Question q) {
    if (q.id.trim().isEmpty) return false;
    if (q.question.trim().isEmpty) return false;
    if (q.options.length < 2) return false;
    if (q.correctAnswer.trim().isEmpty) return false;
    if (q.status.toLowerCase() == 'draft' || q.status.toLowerCase() == 'archived') {
      return false;
    }
    return true;
  }

  // ============================================================
  // ANSWER SUBMISSION & STATE UPDATE
  // ============================================================

  Future<ActiveGameLevelState> submitAnswer({
    String? userId,
    required ActiveGameLevelState state,
    required int questionIndex,
    required String selectedAnswer,
    required bool isCorrect,
  }) async {
    final effectiveUid = userId ?? _currentUserId;
    final updatedAnswers = Map<int, String>.from(state.answers);
    updatedAnswers[questionIndex] = selectedAnswer;

    final newScore = state.score + (isCorrect ? 1 : 0);
    final nextIndex = questionIndex + 1;
    final isCompleted = nextIndex >= 5;

    final updatedState = state.copyWith(
      currentIndex: nextIndex,
      answers: updatedAnswers,
      score: newScore,
      isCompleted: isCompleted,
    );

    await _gameStore.saveActiveGameLevel(updatedState, userId: effectiveUid);
    return updatedState;
  }

  // ============================================================
  // LEVEL COMPLETION & STAR PROGRESSION
  //
  // Best star is preserved on retry: max(previousStars, newStars)
  // Level N passed -> unlocks Level N + 1
  // ============================================================

  Future<GameLevelCompletionResult> completeLevel({
    String? userId,
    required ActiveGameLevelState state,
  }) async {
    final effectiveUid = userId ?? _currentUserId;
    final score = state.score.clamp(0, 5);
    final stars = calculateStars(score);
    final passed = isLevelPassed(score);

    final progress = await _gameStore.getGameProgress(
      userId: effectiveUid,
      stream: state.stream,
      subject: state.subject,
    );

    final currentLevelRecord = progress.getLevel(state.levelNumber);
    final bestScore = max(currentLevelRecord.bestScore, score);
    final bestStars = max(currentLevelRecord.bestStars, stars);
    final isPassedOverall = currentLevelRecord.isPassed || passed;

    final updatedLevels = Map<int, GameLevelRecord>.from(progress.levels);
    updatedLevels[state.levelNumber] = currentLevelRecord.copyWith(
      isPassed: isPassedOverall,
      bestScore: bestScore,
      bestStars: bestStars,
      attemptsCount: currentLevelRecord.attemptsCount + 1,
      lastPlayedAt: DateTime.now(),
      lastQuestionIds: state.questionIds,
    );

    bool unlockedNextLevel = false;
    if (passed) {
      final nextLevelNum = state.levelNumber + 1;
      final existingNext = updatedLevels[nextLevelNum];
      if (existingNext == null || !existingNext.isUnlocked) {
        updatedLevels[nextLevelNum] = (existingNext ??
                GameLevelRecord(levelNumber: nextLevelNum))
            .copyWith(isUnlocked: true);
        unlockedNextLevel = true;
      }
    }

    // Maintain recent question history (keep last 25 question IDs)
    final updatedHistory = List<String>.from(progress.recentQuestionHistory);
    for (final qId in state.questionIds) {
      updatedHistory.remove(qId);
      updatedHistory.add(qId);
    }
    if (updatedHistory.length > 25) {
      updatedHistory.removeRange(0, updatedHistory.length - 25);
    }

    final updatedSummary = GameProgressSummary(
      subject: state.subject,
      stream: state.stream,
      levels: updatedLevels,
      recentQuestionHistory: updatedHistory,
    );

    await _gameStore.saveGameProgress(updatedSummary, userId: effectiveUid);
    await _gameStore.clearActiveGameLevel(userId: effectiveUid);

    return GameLevelCompletionResult(
      subject: state.subject,
      stream: state.stream,
      levelNumber: state.levelNumber,
      score: score,
      stars: stars,
      isPassed: passed,
      unlockedNextLevel: unlockedNextLevel,
      bestStars: bestStars,
      bestScore: bestScore,
    );
  }
}
