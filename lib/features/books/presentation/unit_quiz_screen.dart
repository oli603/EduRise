import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../coach/data/coach_service.dart';
import '../data/book_model.dart';
import '../data/book_text_service.dart';

class UnitQuizScreen extends StatefulWidget {
  final BookUnit unit;

  const UnitQuizScreen({super.key, required this.unit});

  @override
  State<UnitQuizScreen> createState() => _UnitQuizScreenState();
}

class _UnitQuizScreenState extends State<UnitQuizScreen> {
  final CoachService _coachService = CoachService.instance;
  final BookTextService _textService = BookTextService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _questions = [];

  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {};
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentIndex = 0;
      _selectedAnswers.clear();
      _isSubmitted = false;
    });

    try {
      final textResult = await _textService.getUnitText(widget.unit);
      final contextWindow = textResult.hasUsableText
          ? _textService.prepareContextWindow(textResult.text)
          : null;

      final res = await _coachService.getUnitQuiz(
        bookId: widget.unit.id,
        unitId: 'unit_${widget.unit.unitNumber}',
        unitTitle: widget.unit.unitName,
        subject: widget.unit.subject,
        grade: widget.unit.grade,
        unitNumber: widget.unit.unitNumber,
        unitContent: contextWindow,
        forceRefresh: forceRefresh,
      );

      final qList = (res['questions'] as List<dynamic>?) ?? [];
      final parsed = <Map<String, dynamic>>[];

      for (final rawQ in qList) {
        if (rawQ is! Map) continue;
        final qMap = Map<String, dynamic>.from(rawQ);

        final qText = (qMap['question_text'] ?? qMap['question'] ?? '').toString();
        final rawOpts = qMap['options'];
        final Map<String, String> opts = {};

        if (rawOpts is Map) {
          rawOpts.forEach((k, v) => opts[k.toString().toUpperCase()] = v.toString());
        } else if (rawOpts is List) {
          final letters = ['A', 'B', 'C', 'D'];
          for (int i = 0; i < rawOpts.length && i < 4; i++) {
            opts[letters[i]] = rawOpts[i].toString();
          }
        }
        for (final l in ['A', 'B', 'C', 'D']) {
          opts.putIfAbsent(l, () => 'Option $l');
        }

        String corrLetter = (qMap['correct_answer'] ?? 'A').toString().trim().toUpperCase();
        if (!opts.containsKey(corrLetter)) {
          for (final entry in opts.entries) {
            if (entry.value.trim().toLowerCase() == corrLetter.toLowerCase()) {
              corrLetter = entry.key;
              break;
            }
          }
        }
        if (!opts.containsKey(corrLetter)) {
          corrLetter = 'A';
        }

        qMap['question_text'] = qText;
        qMap['options'] = opts;
        qMap['correct_answer'] = corrLetter;
        qMap['explanation'] = (qMap['explanation'] ?? '').toString();
        parsed.add(qMap);
      }

      if (mounted) {
        setState(() {
          _questions = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _selectAnswer(String optionKey) {
    if (_isSubmitted) return;
    setState(() {
      _selectedAnswers[_currentIndex] = optionKey;
    });
  }

  void _submitQuiz() {
    setState(() {
      _isSubmitted = true;
    });
    // NOTE: Strictly local in-memory scoring.
    // Score is NEVER saved to Progress, Weak Areas, Challenges, or Study Plan.
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final correct = (q['correct_answer'] ?? '').toString().trim().toUpperCase();
      final selected = (_selectedAnswers[i] ?? '').trim().toUpperCase();
      if (selected.isNotEmpty && selected == correct) {
        score++;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;

    return Scaffold(
      backgroundColor: context.eduColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Unit ${unit.unitNumber} Quiz (7 Questions)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'New Quiz',
            onPressed: () => _loadQuiz(forceRefresh: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Generating Unit 7-Question Quiz...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.eduColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Grounding questions strictly in Ethiopian curriculum standards',
              style: TextStyle(color: context.eduColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadQuiz(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Center(child: Text('No quiz questions available.'));
    }

    if (_isSubmitted) {
      return _buildResultView();
    }

    return _buildQuizQuestionView();
  }

  Widget _buildQuizQuestionView() {
    final q = _questions[_currentIndex];
    final questionText = q['question_text'] as String? ?? '';
    final options = Map<String, dynamic>.from(q['options'] as Map? ?? {});
    final selectedKey = _selectedAnswers[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Progress Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: context.eduColors.textPrimary,
                ),
              ),
              Text(
                'Self-Assessment Quiz',
                style: TextStyle(fontSize: 12, color: context.eduColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 20),

          // Question Card
          Expanded(
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.eduColors.cardBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.eduColors.border),
                  ),
                  child: Text(
                    questionText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: context.eduColors.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Options
                ...options.entries.map((entry) {
                  final key = entry.key.toUpperCase();
                  final val = entry.value.toString();
                  final isSelected = selectedKey == key;
                  final colors = context.eduColors;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectAnswer(key),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary.withValues(alpha: 0.12) : colors.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? colors.primary : colors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? colors.primary : colors.surfaceSubtle,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isSelected ? Colors.white : colors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  val,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? colors.primary : colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Bottom Bar
          Row(
            children: [
              if (_currentIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentIndex--),
                    child: const Text('Previous'),
                  ),
                ),
              if (_currentIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _currentIndex == _questions.length - 1
                    ? FilledButton.icon(
                        onPressed: _selectedAnswers.length == _questions.length
                            ? _submitQuiz
                            : () {
                                _submitQuiz();
                              },
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Finish Quiz'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.success,
                        ),
                      )
                    : FilledButton(
                        onPressed: () => setState(() => _currentIndex++),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Next Question'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final score = _calculateScore();
    final total = _questions.length;
    final percentage = ((score / total) * 100).round();

    Color resultColor;
    String feedback;
    IconData icon;

    if (score == 7) {
      resultColor = AppColors.success;
      feedback = 'Outstanding mastery of Unit ${widget.unit.unitNumber}!';
      icon = Icons.emoji_events_rounded;
    } else if (score >= 5) {
      resultColor = Colors.teal;
      feedback = 'Great job! You have a solid grasp of this unit.';
      icon = Icons.thumb_up_rounded;
    } else if (score >= 3) {
      resultColor = Colors.amber.shade800;
      feedback = 'Good attempt. Review the unit AI notes to strengthen weaker spots.';
      icon = Icons.menu_book_rounded;
    } else {
      resultColor = AppColors.error;
      feedback = 'We recommend reading the Unit Summary and using flashcards before retesting.';
      icon = Icons.psychology_rounded;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Score Header Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: resultColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: resultColor.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, size: 54, color: resultColor),
              const SizedBox(height: 12),
              Text(
                'Your Score: $score / $total ($percentage%)',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: resultColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                feedback,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: resultColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.eduColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Practice Quiz • Score is not saved in your overall statistics',
                  style: TextStyle(fontSize: 11, color: context.eduColors.textSecondary),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Question Review & Explanations',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.eduColors.textPrimary),
        ),
        const SizedBox(height: 12),

        ..._questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          final selected = (_selectedAnswers[idx] ?? '').toUpperCase();
          final correct = (q['correct_answer'] ?? '').toString().toUpperCase();
          final isCorrect = selected.isNotEmpty && selected == correct;
          final explanation = q['explanation'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.eduColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrect ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isCorrect ? AppColors.success : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Question ${idx + 1}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.eduColors.textPrimary),
                    ),
                    const Spacer(),
                    Text(
                      'Selected: ${selected.isEmpty ? "None" : selected} | Correct: $correct',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q['question_text'] ?? '',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.eduColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.eduColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.eduColors.border),
                  ),
                  child: Text(
                    'Explanation: $explanation',
                    style: TextStyle(fontSize: 13, height: 1.4, color: context.eduColors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: () => _loadQuiz(forceRefresh: true),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Another 7-Question Quiz'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }
}
