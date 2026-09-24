import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/question_model.dart';

class PracticeReviewScreen extends StatelessWidget {
  final List<Question> questions;
  final Map<int, String> selectedAnswers;

  const PracticeReviewScreen({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Review Answers'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            itemCount: questions.length,
            // ignore: unnecessary_underscores
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final question = questions[index];
              final selectedAnswer = selectedAnswers[index];
              final isCorrect = selectedAnswer == question.correctAnswer;

              return _ReviewQuestionCard(
                questionNumber: index + 1,
                question: question,
                selectedAnswer: selectedAnswer,
                isCorrect: isCorrect,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final int questionNumber;
  final Question question;
  final String? selectedAnswer;
  final bool isCorrect;

  const _ReviewQuestionCard({
    required this.questionNumber,
    required this.question,
    required this.selectedAnswer,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final isDark = colors.isDark;
    final statusColor = isCorrect ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withValues(alpha: isDark ? 0.4 : 0.25)
              : AppColors.error.withValues(alpha: isDark ? 0.4 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$questionNumber',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: statusColor,
                size: 20,
              ),

              const SizedBox(width: 6),

              Text(
                isCorrect ? 'Correct' : 'Incorrect',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            question.question,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          _AnswerRow(
            label: 'Your answer',
            answer: selectedAnswer ?? 'Not answered',
            color: isCorrect
                ? (isDark ? const Color(0xFF86EFAC) : AppColors.success)
                : (isDark ? const Color(0xFFFCA5A5) : AppColors.error),
            icon: isCorrect ? Icons.check_rounded : Icons.close_rounded,
          ),

          const SizedBox(height: 10),

          _AnswerRow(
            label: 'Correct answer',
            answer: question.correctAnswer,
            color: isDark ? const Color(0xFF86EFAC) : AppColors.success,
            icon: Icons.check_circle_outline_rounded,
          ),

          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 18),
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
                      height: 1.45,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String answer;
  final Color color;
  final IconData? icon;

  const _AnswerRow({
    required this.label,
    required this.answer,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            answer,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
