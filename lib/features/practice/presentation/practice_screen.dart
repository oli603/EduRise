import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:edurise/core/auth/access_service.dart';
import 'package:edurise/core/widgets/access_locked_dialog.dart';
import 'package:edurise/features/practice/data/question_model.dart';
import 'package:edurise/features/practice/data/question_service.dart';
import 'package:edurise/features/practice/data/practice_service.dart';
import '../../challenges/data/challenge_service.dart';

import 'practice_result_screen.dart';

class PracticeScreen extends StatefulWidget {
  final String grade;
  final String stream;
  final String subject;
  final int unitNumber;
  final String unitName;
  final int? examYear;
  final int questionCount;

  const PracticeScreen({
    super.key,
    required this.grade,
    required this.stream,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
    this.examYear,
    required this.questionCount,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final QuestionService _questionService = QuestionService();
  final PracticeService _practiceService = PracticeService();

  List<Question> _questions = [];

  int _currentIndex = 0;
  int _correctAnswers = 0;

  final Map<int, String> _selectedAnswers = {};

  final List<Question> _mistakes = [];

  bool _answered = false;
  bool _isLoading = true;
  bool _isCompletingPractice = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // ============================================================
  // LOAD QUESTIONS
  // ============================================================

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _questions = [];
      _currentIndex = 0;
      _correctAnswers = 0;
      _selectedAnswers.clear();
      _mistakes.clear();
      _answered = false;
      _isCompletingPractice = false;
    });

    try {
      final canAccess = await AccessService.canAccessPractice(
        grade: widget.grade,
        examYear: widget.examYear ?? 0,
      );

      if (!canAccess) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Access Locked: Subscription required for ${widget.grade}.';
        });
        AccessLockedDialog.show(
          context,
          featureName: 'Practice Questions (${widget.grade} • ${widget.examYear ?? ''} EC)',
        );
        return;
      }

      final questions = await _questionService.getQuestions(
        grade: widget.grade,
        stream: widget.stream,
        subject: widget.subject,
        unitNumber: widget.unitNumber,
        examYear: widget.examYear,
      );

      // Deduplicate questions by ID
      final seenIds = <String>{};
      final uniqueQuestions = <Question>[];
      for (final q in questions) {
        if (seenIds.add(q.id)) {
          uniqueQuestions.add(q);
        }
      }

      uniqueQuestions.shuffle();

      final selectedQuestions =
          widget.questionCount == 0 || widget.questionCount >= uniqueQuestions.length
          ? uniqueQuestions
          : uniqueQuestions.take(widget.questionCount).toList();

      if (!mounted) return;

      setState(() {
        _questions = selectedQuestions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD QUESTIONS ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load questions.';
      });
    }
  }

  // ============================================================
  // SELECT ANSWER
  // ============================================================

  void _selectAnswer(String answer) {
    if (_answered) {
      return;
    }

    final question = _questions[_currentIndex];

    final isCorrect = answer == question.correctAnswer;

    setState(() {
      _selectedAnswers[_currentIndex] = answer;

      _answered = true;

      if (isCorrect) {
        _correctAnswers++;
      } else {
        _mistakes.add(question);
      }
    });
  }

  // ============================================================
  // NEXT QUESTION
  // ============================================================

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      if (_isCompletingPractice) {
        return;
      }

      _isCompletingPractice = true;

      _showResult();

      return;
    }

    setState(() {
      _currentIndex++;
      _answered = false;
    });
  }

  // ============================================================
  // SHOW RESULT
  // ============================================================
  Future<void> _showResult() async {
    final total = _questions.length;

    final percentage = total == 0
        ? 0
        : ((_correctAnswers / total) * 100).round();

    final wrongAnswers = total - _correctAnswers;

    final actualUnitName = (_questions.isNotEmpty && _questions.first.unitName.trim().isNotEmpty)
        ? _questions.first.unitName.trim()
        : (widget.unitName.trim().isNotEmpty ? widget.unitName.trim() : 'Unit ${widget.unitNumber}');

    // ============================================================
    // SAVE PRACTICE SESSION RESULT
    // ============================================================

    final questionIds = _questions.map((q) => q.id).toList();
    final correctQuestionIds = _questions
        .where((q) => !_mistakes.contains(q))
        .map((q) => q.id)
        .toList();
    final questionResults = _questions.map((q) {
      return {
        'questionId': q.id,
        'isCorrect': !_mistakes.contains(q),
      };
    }).toList();

    try {
      await _practiceService.saveResult(
        grade: widget.grade,
        stream: widget.stream,
        subject: widget.subject,
        unitNumber: widget.unitNumber,
        unitName: actualUnitName,
        examYear: widget.examYear,
        totalQuestions: total,
        correctAnswers: _correctAnswers,
        wrongAnswers: wrongAnswers,
        score: percentage,
        questionIds: questionIds,
        correctQuestionIds: correctQuestionIds,
        questionResults: questionResults,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final challengeService = ChallengeService();
        await challengeService.incrementPracticeChallenge(
          userId: user.uid,
          subject: widget.subject,
          grade: widget.grade,
          unitNumber: widget.unitNumber,
          count: total,
        );
      }
    } catch (e) {
      debugPrint('PRACTICE RESULT SAVE ERROR: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PracticeResultScreen(
          totalQuestions: total,
          correctAnswers: _correctAnswers,
          mistakes: _mistakes,
          selectedAnswers: _selectedAnswers,
          questions: _questions,
          stream: widget.stream,
          grade: widget.grade,
          subject: widget.subject,
          unitNumber: widget.unitNumber,
          unitName: actualUnitName,
          examYear: widget.examYear,
          questionCount: widget.questionCount,
          percentage: percentage,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.unitName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.unitName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // NO QUESTIONS
    // ----------------------------------------------------------

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.unitName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No questions available',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No questions are currently available for ${widget.grade} ${widget.subject} Unit ${widget.unitNumber}${widget.examYear != null && widget.examYear! > 0 ? ' (${widget.examYear} EC)' : ''}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Choose Another Filter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];

    // ----------------------------------------------------------
    // PRACTICE UI
    // ----------------------------------------------------------

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ==================================================
            // STUDY CONTEXT
            // ==================================================
            _buildStudyContext(),

            const SizedBox(height: 24),

            // ==================================================
            // QUESTION PROGRESS
            // ==================================================
            _buildProgress(),

            const SizedBox(height: 28),

            // ==================================================
            // QUESTION
            // ==================================================
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // ANSWER OPTIONS
            // ==================================================
            ...List.generate(question.options.length, (index) {
              final option = question.options[index];

              return _buildAnswerOption(
                option: option,
                index: index,
                correctAnswer: question.correctAnswer,
              );
            }),

            // ==================================================
            // FEEDBACK
            // ==================================================
            if (_answered) ...[
              const SizedBox(height: 20),

              _buildFeedback(question),

              const SizedBox(height: 20),

              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextQuestion,
                  child: Text(
                    _currentIndex == _questions.length - 1
                        ? 'Finish Practice'
                        : 'Next Question',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STUDY CONTEXT
  // ============================================================

  Widget _buildStudyContext() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grade & Exam Year
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.grade,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                    // ignore: deprecated_member_use
                  ).colorScheme.onPrimaryContainer.withOpacity(0.75),
                ),
              ),
              if (widget.examYear != null && widget.examYear! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.examYear} EC',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // Unit number
          Text(
            'Unit ${widget.unitNumber}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
                // ignore: deprecated_member_use
              ).colorScheme.onPrimaryContainer.withOpacity(0.8),
            ),
          ),

          const SizedBox(height: 4),

          // Unit name
          Text(
            widget.unitName,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),

          const SizedBox(height: 8),

          // Subject
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: Theme.of(
                  context,
                  // ignore: deprecated_member_use
                ).colorScheme.onPrimaryContainer.withOpacity(0.75),
              ),

              const SizedBox(width: 6),

              Text(
                widget.subject,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                    // ignore: deprecated_member_use
                  ).colorScheme.onPrimaryContainer.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _buildProgress() {
    final progress = (_currentIndex + 1) / _questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Practice Progress',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),

            Text(
              '${_currentIndex + 1}/${_questions.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),

        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: progress, minHeight: 8),
        ),
      ],
    );
  }

  // ============================================================
  // ANSWER OPTION
  // ============================================================

  Widget _buildAnswerOption({
    required String option,
    required int index,
    required String correctAnswer,
  }) {
    final letter = String.fromCharCode(65 + index);

    final selectedAnswer = _selectedAnswers[_currentIndex];

    final isSelected = selectedAnswer == letter;

    final isCorrect = _answered && letter == correctAnswer;

    final isWrong = _answered && isSelected && letter != correctAnswer;

    Color backgroundColor = Colors.grey.shade100;
    Color borderColor = Colors.grey.shade300;
    Color textColor = Colors.black87;

    if (isCorrect) {
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green;
      textColor = Colors.green.shade800;
    } else if (isWrong) {
      backgroundColor = Colors.red.shade50;
      borderColor = Colors.red;
      textColor = Colors.red.shade800;
    } else if (isSelected) {
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;

      borderColor = Theme.of(context).colorScheme.primary;

      textColor = Theme.of(context).colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _answered ? null : () => _selectAnswer(letter),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),

                if (isCorrect)
                  const Icon(Icons.check_circle, color: Colors.green),

                if (isWrong) const Icon(Icons.cancel, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FEEDBACK + EXPLANATION
  // ============================================================

  Widget _buildFeedback(Question question) {
    final selectedAnswer = _selectedAnswers[_currentIndex];

    final isCorrect = selectedAnswer == question.correctAnswer;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
              ),

              const SizedBox(width: 8),

              Text(
                isCorrect ? 'Correct!' : 'Incorrect',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCorrect
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            ],
          ),

          if (!isCorrect) ...[
            const SizedBox(height: 12),

            Text(
              'Correct answer: ${question.correctAnswer}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],

          const SizedBox(height: 16),

          const Text(
            'Explanation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            question.explanation.isEmpty
                ? 'No explanation has been added yet.'
                : question.explanation,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}
