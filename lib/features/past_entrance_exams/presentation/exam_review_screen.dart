import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../coach/presentation/widgets/explain_more_sheet.dart';
import '../../coach/presentation/widgets/report_question_dialog.dart';
import '../data/past_exam_model.dart';

class ExamReviewScreen extends StatelessWidget {
  final PastExam exam;
  final Map<int, String> selectedAnswers;

  const ExamReviewScreen({
    super.key,
    required this.exam,
    required this.selectedAnswers,
  });

  String _getOptionText(PastExamQuestion question, String? optionKey) {
    if (optionKey == null || optionKey.isEmpty) return 'No answer selected';
    switch (optionKey.toUpperCase()) {
      case 'A':
        return '(A) ${question.optionA}';
      case 'B':
        return '(B) ${question.optionB}';
      case 'C':
        return '(C) ${question.optionC}';
      case 'D':
        return '(D) ${question.optionD}';
      default:
        return optionKey;
    }
  }

  void _safeBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/past-entrance-exams');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _safeBack(context);
      },
      child: Scaffold(
        backgroundColor: colors.scaffoldBackground,
        appBar: AppBar(
          title: Text('Review: ${exam.year} EC ${exam.subject}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () => _safeBack(context),
          ),
        ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: exam.questions.length,
        separatorBuilder: (context, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final question = exam.questions[index];
          final selected = selectedAnswers[index];
          final isAnswered = selected != null;
          final isCorrect = isAnswered &&
              selected.trim().toUpperCase() == question.correctAnswer.trim().toUpperCase();

          Color statusColor;
          String statusText;
          IconData statusIcon;

          if (!isAnswered) {
            statusColor = AppColors.warning;
            statusText = 'Unanswered';
            statusIcon = Icons.help_outline_rounded;
          } else if (isCorrect) {
            statusColor = AppColors.success;
            statusText = 'Correct';
            statusIcon = Icons.check_circle_outline_rounded;
          } else {
            statusColor = AppColors.error;
            statusText = 'Incorrect';
            statusIcon = Icons.cancel_outlined;
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Question number & Result chip
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Question Text
                Text(
                  question.questionText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: colors.textPrimary,
                  ),
                ),

                if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      question.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Student Answer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Answer:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getOptionText(question, selected),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Correct Answer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Correct Answer:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getOptionText(question, question.correctAnswer),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),

                if (question.explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 16, color: colors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Explanation',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          question.explanation,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // AI Coach Breakdown & Report
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
                        ),
                        onPressed: () {
                          final opts = {
                            'A': question.optionA,
                            'B': question.optionB,
                            'C': question.optionC,
                            'D': question.optionD,
                          };
                          ExplainMoreSheet.show(
                            context,
                            questionId: question.id ?? 'exam_q_${index + 1}',
                            questionText: question.questionText,
                            options: opts,
                            correctAnswer: question.correctAnswer,
                            subject: exam.subject,
                            examYear: exam.year,
                          );
                        },
                        icon: Icon(Icons.auto_awesome_rounded, size: 16, color: colors.primary),
                        label: Text(
                          'Explain More',
                          style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Report question issue',
                      icon: Icon(Icons.flag_outlined, size: 18, color: colors.textMuted),
                      onPressed: () {
                        ReportQuestionDialog.show(
                          context,
                          questionId: question.id ?? 'exam_q_${index + 1}',
                          questionType: 'past_exam',
                          subject: exam.subject,
                          unitOrYear: '${exam.year} EC',
                          correctAnswer: question.correctAnswer,
                          studentAnswer: selected,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
}
