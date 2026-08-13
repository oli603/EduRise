import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/practice_service.dart';
import '../data/question_model.dart';
import '../data/question_service.dart';

class PracticeScreen extends StatefulWidget {
  final String grade;
  final String subject;
  final int unitNumber;
  final String unitName;

  const PracticeScreen({
    super.key,
    required this.grade,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final PracticeService _practiceService = PracticeService();
  final QuestionService _questionService = QuestionService();

  List<Question> _questions = [];

  int _currentQuestion = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _isLoading = true;
  String? _errorMessage;

  Question get _question => _questions[_currentQuestion];

  bool get _isCorrect {
    if (_selectedAnswer == null) {
      return false;
    }

    final selectedLetter = String.fromCharCode(65 + _selectedAnswer!);

    return selectedLetter == _question.correctAnswer;
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _questionService.getQuestions(
        grade: widget.grade,
        subject: widget.subject,
        unitNumber: widget.unitNumber,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD QUESTIONS ERROR: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _selectAnswer(int index) {
    if (_answered) {
      return;
    }

    setState(() {
      _selectedAnswer = index;
    });
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null) {
      return;
    }

    try {
      await _practiceService.saveResult(
        subject: widget.subject,
        topic: widget.unitName,
        question: _question.question,
        selectedAnswer: _selectedAnswer!,
        correctAnswer: _getCorrectAnswerIndex(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _answered = true;
      });
    } catch (e) {
      debugPrint("SAVE RESULT ERROR: $e");

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to submit your answer. Please try again."),
        ),
      );
    }
  }

  void _nextQuestion() {
    if (_currentQuestion >= _questions.length - 1) {
      _showFinishedDialog();
      return;
    }

    setState(() {
      _currentQuestion++;
      _selectedAnswer = null;
      _answered = false;
    });
  }

  void _showFinishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Practice Complete 🎉"),
          content: const Text("You have finished this practice session."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Done"),
            ),
          ],
        );
      },
    );
  }

  Color _getAnswerColor(int index) {
    if (!_answered) {
      if (_selectedAnswer == index) {
        // ignore: deprecated_member_use
        return AppColors.primary.withOpacity(0.10);
      }

      return Colors.white;
    }

    if (index == _getCorrectAnswerIndex()) {
      // ignore: deprecated_member_use
      return Colors.green.withOpacity(0.10);
    }

    if (index == _selectedAnswer && !_isCorrect) {
      // ignore: deprecated_member_use
      return Colors.red.withOpacity(0.10);
    }

    return Colors.white;
  }

  Color _getBorderColor(int index) {
    if (!_answered) {
      if (_selectedAnswer == index) {
        return AppColors.primary;
      }

      return Colors.grey.shade200;
    }

    if (index == _getCorrectAnswerIndex()) {
      return Colors.green;
    }

    if (index == _selectedAnswer && !_isCorrect) {
      return Colors.red;
    }

    return Colors.grey.shade200;
  }

  IconData? _getAnswerIcon(int index) {
    if (!_answered) {
      if (_selectedAnswer == index) {
        return Icons.radio_button_checked_rounded;
      }

      return null;
    }

    if (index == _getCorrectAnswerIndex()) {
      return Icons.check_circle_rounded;
    }

    if (index == _selectedAnswer && !_isCorrect) {
      return Icons.cancel_rounded;
    }

    return null;
  }

  int _getCorrectAnswerIndex() {
    if (_question.correctAnswer.isEmpty) {
      return -1;
    }

    final letter = _question.correctAnswer.trim().toUpperCase();

    if (letter.length != 1) {
      return -1;
    }

    final index = letter.codeUnitAt(0) - 'A'.codeUnitAt(0);

    if (index < 0 || index >= _question.options.length) {
      return -1;
    }

    return index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.subject} Practice")),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 50,
                color: Colors.red,
              ),

              const SizedBox(height: 16),

              const Text(
                "Unable to load questions.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  _loadQuestions();
                },
                child: const Text("Try Again"),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 60,
                color: AppColors.primary,
              ),

              const SizedBox(height: 20),

              const Text(
                "No questions yet.",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                "There are no questions available for "
                "${widget.subject} — Unit ${widget.unitNumber} "
                "(${widget.unitName}) yet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Unit ${widget.unitNumber} — ${widget.unitName}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Question ${_currentQuestion + 1} "
                "of ${_questions.length}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                "${((_currentQuestion + 1) / _questions.length * 100).round()}%",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: (_currentQuestion + 1) / _questions.length,
            minHeight: 7,
            borderRadius: BorderRadius.circular(10),
          ),

          const SizedBox(height: 28),

          Text(
            _question.question,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                ...List.generate(_question.options.length, (index) {
                  return _buildAnswerCard(
                    index: index,
                    text: _question.options[index],
                  );
                }),

                if (_answered) ...[
                  const SizedBox(height: 4),
                  _buildFeedbackCard(),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedAnswer == null
                  ? null
                  : _answered
                  ? _nextQuestion
                  : _submitAnswer,
              child: Text(
                _answered
                    ? _currentQuestion == _questions.length - 1
                          ? "Finish"
                          : "Next Question"
                    : "Submit Answer",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard({required int index, required String text}) {
    final icon = _getAnswerIcon(index);

    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _getAnswerColor(index),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getBorderColor(index),
            width:
                _selectedAnswer == index ||
                    (_answered && index == _getCorrectAnswerIndex())
                ? 2
                : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _selectedAnswer == index
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),

            if (icon != null)
              Icon(
                icon,
                color: index == _getCorrectAnswerIndex()
                    ? Colors.green
                    : Colors.red,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCorrect
            // ignore: deprecated_member_use
            ? Colors.green.withOpacity(0.08)
            // ignore: deprecated_member_use
            : Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCorrect
              // ignore: deprecated_member_use
              ? Colors.green.withOpacity(0.3)
              // ignore: deprecated_member_use
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
            color: _isCorrect ? Colors.green : Colors.red,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCorrect ? "Correct! 🎉" : "Not quite.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isCorrect ? Colors.green : Colors.red,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  _question.explanation,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
