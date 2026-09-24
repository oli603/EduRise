import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:edurise/core/theme/app_colors.dart';
import 'package:edurise/core/theme/app_radius.dart';
import 'package:edurise/core/theme/app_spacing.dart';
import 'package:edurise/core/theme/app_text_styles.dart';
import 'package:edurise/features/progress/data/progress_service.dart';

/// Real-time learning progress snapshot for the EduRise Home screen.
///
/// Subscribes to [ProgressService.getUserResultsStream] and displays
/// overall accuracy and total questions answered with zero hardcoded values.
class LearningProgressSection extends StatelessWidget {
  final ProgressService? progressService;
  final Stream<List<Map<String, dynamic>>>? resultsStream;

  const LearningProgressSection({
    super.key,
    this.progressService,
    this.resultsStream,
  });

  Stream<List<Map<String, dynamic>>> _resolveStream(ProgressService? service) {
    if (resultsStream != null) return resultsStream!;
    if (service == null) return Stream.value(const []);
    try {
      if (Firebase.apps.isNotEmpty) {
        return service.getUserResultsStream();
      }
    } catch (_) {}
    return Stream.value(const []);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    ProgressService? service = progressService;
    if (service == null && Firebase.apps.isNotEmpty) {
      try {
        service = ProgressService();
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ====================================================
        // SECTION HEADER
        // ====================================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Learning Progress',
              style: AppTextStyles.headingMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/progress'),
              style: TextButton.styleFrom(
                foregroundColor: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Details', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // ====================================================
        // REAL-TIME STATS CARD
        // ====================================================
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _resolveStream(service),
          builder: (context, snapshot) {
            final results = snapshot.data ?? [];

            int totalQuestions = 0;
            int correctAnswers = 0;

            for (final r in results) {
              final tQ = (r['totalQuestions'] as num?)?.toInt() ?? 0;
              final cA = (r['correctAnswers'] as num?)?.toInt() ?? 0;
              totalQuestions += tQ;
              correctAnswers += cA;
            }

            final accuracy = totalQuestions == 0
                ? 0
                : ((correctAnswers / totalQuestions) * 100).round();

            // EMPTY STATE (0 PRACTICE SESSIONS)
            if (totalQuestions == 0) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No practice sessions yet',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Take your first quiz to track accuracy & strengths.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // LOADED STATS
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Accuracy percentage pill
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (accuracy >= 70
                                    ? AppColors.success
                                    : (accuracy >= 40 ? AppColors.warning : AppColors.primary))
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              accuracy >= 70
                                  ? Icons.emoji_events_rounded
                                  : Icons.track_changes_rounded,
                              color: accuracy >= 70
                                  ? AppColors.success
                                  : (accuracy >= 40 ? AppColors.warning : AppColors.primary),
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$accuracy%',
                                style: AppTextStyles.headingMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Overall Accuracy',
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    height: 36,
                    width: 1,
                    color: colors.border.withValues(alpha: 0.7),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),

                  // Questions answered
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalQuestions',
                          style: AppTextStyles.headingMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Questions',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Correct count
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$correctAnswers',
                          style: AppTextStyles.headingMedium.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Correct',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
