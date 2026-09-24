import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/question_model.dart';
import 'practice_review_screen.dart';
import 'practice_screen.dart';

class PracticeResultScreen extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final List<Question> mistakes;
  final Map<int, String> selectedAnswers;
  final List<Question> questions;
  final String grade;
  final String subject;
  final String stream;
  final int unitNumber;
  final String unitName;
  final int? examYear;
  final int? questionCount;
  final int percentage;

  const PracticeResultScreen({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.mistakes,
    required this.selectedAnswers,
    required this.questions,
    required this.stream,
    required this.grade,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
    this.examYear,
    this.questionCount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final isDark = colors.isDark;
    final incorrectAnswers = totalQuestions - correctAnswers;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/practice');
        }
      },
      child: Scaffold(
        backgroundColor: colors.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Practice Result'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/practice');
              }
            },
          ),
        ),
        body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              const SizedBox(height: 8),

              // Achievement Icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: percentage >= 80
                        ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                        : (percentage >= 50
                            ? Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1)
                            : AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    percentage >= 80
                        ? Icons.emoji_events_rounded
                        : (percentage >= 50 ? Icons.thumb_up_rounded : Icons.replay_rounded),
                    size: 38,
                    color: percentage >= 80
                        ? (isDark ? AppColors.primaryLight : AppColors.primary)
                        : (percentage >= 50 ? Colors.amber : AppColors.error),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Practice Complete!',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingLarge.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '$unitName • $subject • $grade${examYear != null && examYear! > 0 ? ' • $examYear EC' : ''}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // Result Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: percentage >= 80
                            ? (isDark ? AppColors.primaryLight : AppColors.primary)
                            : (percentage >= 50
                                ? (isDark ? Colors.amber.shade300 : Colors.amber.shade800)
                                : AppColors.error),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$correctAnswers / $totalQuestions correct',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      percentage >= 90
                          ? 'Exceptional mastery!'
                          : (percentage >= 75
                              ? 'Great progress!'
                              : (percentage >= 50 ? 'Good effort! Keep practicing.' : 'Needs review. Try again!')),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3-Metric Performance Row
              Row(
                children: [
                  Expanded(
                    child: _ResultStat(
                      title: 'Correct',
                      value: '$correctAnswers',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStat(
                      title: 'Incorrect',
                      value: '$incorrectAnswers',
                      icon: Icons.cancel_rounded,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStat(
                      title: 'Total',
                      value: '$totalQuestions',
                      icon: Icons.format_list_numbered_rounded,
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action buttons: Review All & Practice Again
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PracticeReviewScreen(
                              questions: questions,
                              selectedAnswers: selectedAnswers,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.rate_review_outlined, size: 20),
                      label: const Text('Review All'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => PracticeScreen(
                              grade: grade,
                              stream: stream,
                              subject: subject,
                              unitNumber: unitNumber,
                              unitName: unitName,
                              examYear: examYear,
                              questionCount: questionCount ?? totalQuestions,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.replay_rounded, size: 20),
                      label: const Text('Practice Again'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Review Mistakes Section or Perfect Banner
              if (mistakes.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Review Your Mistakes',
                      style: AppTextStyles.headingMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${mistakes.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...mistakes.map((question) {
                  final questionIndex = questions.indexOf(question);
                  final studentAnswer = selectedAnswers[questionIndex];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.question,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
                                  children: [
                                    TextSpan(
                                      text: 'Your answer: ',
                                      style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500),
                                    ),
                                    TextSpan(
                                      text: studentAnswer ?? "Not answered",
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
                                  children: [
                                    TextSpan(
                                      text: 'Correct answer: ',
                                      style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500),
                                    ),
                                    TextSpan(
                                      text: question.correctAnswer,
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF86EFAC) : AppColors.success,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (question.explanation.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Explanation',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  question.explanation,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.textPrimary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],

              if (mistakes.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: isDark ? 0.4 : 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Perfect! You got every question correct.',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: const Text(
                    'Back to Practice Selection',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _ResultStat({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
