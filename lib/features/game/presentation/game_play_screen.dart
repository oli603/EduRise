import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/offline_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../practice/data/question_model.dart';
import '../data/game_service.dart';
import '../data/models/game_models.dart';

class GamePlayScreen extends StatefulWidget {
  final String subject;
  final String stream;
  final int levelNumber;
  final GameService? gameService;
  final OfflineStorageService? storageService;

  const GamePlayScreen({
    super.key,
    required this.subject,
    required this.stream,
    required this.levelNumber,
    this.gameService,
    this.storageService,
  });

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  late final GameService _gameService;
  late final OfflineStorageService _storage;

  ActiveGameLevelState? _activeState;
  List<Question> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedOption;
  bool? _isAnswerCorrect;
  bool _isAnswerLocked = false;
  bool _isSubmitting = false;
  Timer? _autoAdvanceTimer;

  GameLevelCompletionResult? _completionResult;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageService ?? OfflineStorageService.instance;
    _gameService = widget.gameService ?? GameService(storageService: _storage);

    _startLevelSession();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLevelSession({bool forceNew = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedOption = null;
      _isAnswerCorrect = null;
      _isAnswerLocked = false;
      _isSubmitting = false;
      _completionResult = null;
    });

    try {
      final (state, questions) = await _gameService.startOrResumeLevel(
        stream: widget.stream,
        subject: widget.subject,
        levelNumber: widget.levelNumber,
        forceNew: forceNew,
      );

      if (!mounted) return;

      setState(() {
        _activeState = state;
        _questions = questions;
        _isLoading = false;

        // If resuming a question that was already answered
        final currentIndex = state.currentIndex;
        if (state.answers.containsKey(currentIndex)) {
          _selectedOption = state.answers[currentIndex];
          _isAnswerLocked = true;
          if (currentIndex < questions.length) {
            _isAnswerCorrect = _checkIsCorrect(
              questions[currentIndex],
              _selectedOption!,
            );
          }
        }
      });

      // If already completed on start
      if (state.isCompleted) {
        _finishLevel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  bool _checkIsCorrect(Question question, String chosenOption) {
    final cleanCorrect = question.correctAnswer.trim().toLowerCase();
    final cleanChosen = chosenOption.trim().toLowerCase();

    // Direct text equality
    if (cleanChosen == cleanCorrect) return true;

    // Check letter options (e.g. 'A', 'B', 'C', 'D')
    final optionIndex = question.options.indexOf(chosenOption);
    if (optionIndex >= 0) {
      final letter = String.fromCharCode(65 + optionIndex).toLowerCase();
      if (letter == cleanCorrect) return true;
    }

    return false;
  }

  Future<void> _handleOptionSelected(String option) async {
    if (_isAnswerLocked || _isSubmitting || _activeState == null || _questions.isEmpty) return;

    final currentIndex = _activeState!.currentIndex;
    if (currentIndex >= _questions.length) return;

    final currentQuestion = _questions[currentIndex];
    final isCorrect = _checkIsCorrect(currentQuestion, option);

    setState(() {
      _selectedOption = option;
      _isAnswerCorrect = isCorrect;
      _isAnswerLocked = true;
      _isSubmitting = true;
    });

    final updatedState = await _gameService.submitAnswer(
      state: _activeState!,
      questionIndex: currentIndex,
      selectedAnswer: option,
      isCorrect: isCorrect,
    );

    if (!mounted) return;

    setState(() {
      _activeState = updatedState;
      _isSubmitting = false;
    });

    // Auto advance to next question after 850ms for snappy gameplay
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) {
        _goToNextQuestionOrFinish();
      }
    });
  }

  Future<void> _goToNextQuestionOrFinish() async {
    _autoAdvanceTimer?.cancel();

    if (_activeState == null || _isSubmitting) return;

    if (_activeState!.isCompleted || _activeState!.currentIndex >= 5) {
      await _finishLevel();
    } else {
      setState(() {
        _selectedOption = null;
        _isAnswerCorrect = null;
        _isAnswerLocked = false;
      });
    }
  }

  Future<void> _finishLevel() async {
    if (_activeState == null) return;

    final result = await _gameService.completeLevel(state: _activeState!);
    if (mounted) {
      setState(() {
        _completionResult = result;
      });
    }
  }

  void _retryLevel() {
    _startLevelSession(forceNew: true);
  }

  void _nextLevel() {
    if (_completionResult == null) return;
    final nextLevel = _completionResult!.levelNumber + 1;
    context.pushReplacement(
      '/game/play?subject=${Uri.encodeComponent(widget.subject)}&stream=${Uri.encodeComponent(widget.stream)}&level=$nextLevel',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.eduColors.scaffoldBackground,
        appBar: AppBar(title: Text('Level ${widget.levelNumber}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: context.eduColors.scaffoldBackground,
        appBar: AppBar(title: Text('Level ${widget.levelNumber}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 52, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.eduColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Go to Practice Downloads'),
                  onPressed: () => context.go('/practice'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_completionResult != null) {
      return _buildResultScreen(_completionResult!);
    }

    final currentIndex = _activeState?.currentIndex.clamp(0, 4) ?? 0;
    final currentQuestion = _questions.isNotEmpty && currentIndex < _questions.length
        ? _questions[currentIndex]
        : null;

    if (currentQuestion == null) {
      return Scaffold(
        backgroundColor: context.eduColors.scaffoldBackground,
        appBar: AppBar(title: Text('Level ${widget.levelNumber}')),
        body: Center(
          child: Text(
            'Loading question...',
            style: TextStyle(color: context.eduColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.eduColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Exit Level',
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${widget.subject} • Level ${widget.levelNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentIndex + 1} / 5',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (currentIndex + (_isAnswerLocked ? 1 : 0)) / 5.0,
              backgroundColor: context.eduColors.border,
              color: AppColors.primary,
              minHeight: 5,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Card
                    _buildQuestionCard(currentQuestion, currentIndex),

                    const SizedBox(height: AppSpacing.lg),

                    // Options list
                    ...currentQuestion.options.map((opt) => _buildOptionCard(opt)),

                    const SizedBox(height: AppSpacing.md),

                    // Visual Feedback Banner (Short ✓ Correct / ✕ Wrong)
                    if (_isAnswerLocked && _isAnswerCorrect != null)
                      _buildFeedbackBanner(_isAnswerCorrect!),
                  ],
                ),
              ),
            ),

            // Bottom Continue CTA if answered
            if (_isAnswerLocked)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _goToNextQuestionOrFinish,
                    child: Text(
                      currentIndex >= 4 ? 'See Level Results 🏆' : 'Next Question ➔',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.eduColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.eduColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Question ${index + 1} of 5',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.eduColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String option) {
    final isSelected = _selectedOption == option;
    final isLocked = _isAnswerLocked;

    Color borderColor = context.eduColors.border;
    Color bgColor = context.eduColors.cardBackground;
    Color textColor = context.eduColors.textPrimary;
    Widget? trailingIcon;

    if (isLocked) {
      if (isSelected) {
        if (_isAnswerCorrect == true) {
          borderColor = AppColors.success;
          bgColor = AppColors.success.withValues(alpha: 0.1);
          textColor = AppColors.success;
          trailingIcon = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22);
        } else {
          borderColor = AppColors.error;
          bgColor = AppColors.error.withValues(alpha: 0.1);
          textColor = AppColors.error;
          trailingIcon = const Icon(Icons.cancel_rounded, color: AppColors.error, size: 22);
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: isLocked ? null : () => _handleOptionSelected(option),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                    height: 1.3,
                  ),
                ),
              ),
              ?trailingIcon,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner(bool isCorrect) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.highlight_off_rounded,
            color: isCorrect ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isCorrect ? '✓ Correct!' : '✕ Wrong!',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isCorrect ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen(GameLevelCompletionResult result) {
    final passed = result.isPassed;
    final score = result.score;
    final stars = result.stars;
    final colors = context.eduColors;
    final isDark = colors.isDark;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Level ${result.levelNumber} Result'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Celebration or Retry icon
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: passed
                          ? (isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.shade50)
                          : AppColors.error.withValues(alpha: isDark ? 0.2 : 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      passed ? Icons.emoji_events_rounded : Icons.replay_rounded,
                      size: 42,
                      color: passed ? Colors.amber : AppColors.error,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    passed ? 'Level Passed! 🎉' : 'Level Incomplete',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    passed
                        ? 'Great job! You scored $score out of 5 and earned $stars star${stars == 1 ? '' : 's'}.'
                        : 'You scored $score out of 5. You need at least 3 correct answers to pass.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Hero Result Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Stars Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final isEarned = index < stars;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                isEarned ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 40,
                                color: isEarned ? Colors.amber : colors.border,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Score: $score / 5',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(score / 5 * 100).toInt()}% Accuracy',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: passed ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Action Buttons
                  if (passed) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: Text('Play Level ${result.levelNumber + 1} ➔'),
                        onPressed: _nextLevel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.replay_rounded, size: 20),
                        label: const Text('Replay Level for ⭐⭐⭐'),
                        onPressed: _retryLevel,
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 20),
                        label: const Text('Retry Level (Fresh Questions)'),
                        onPressed: _retryLevel,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 48,
                    child: TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Back to Level Map'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
