import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:edurise/core/theme/app_colors.dart';
import 'package:edurise/core/theme/app_radius.dart';
import 'package:edurise/core/theme/app_spacing.dart';
import 'package:edurise/core/theme/app_text_styles.dart';
import 'package:edurise/features/challenges/data/challenge_model.dart';
import 'package:edurise/features/challenges/data/challenge_service.dart';

/// Compact Today's Challenge card on the EduRise Home screen.
///
/// Shows the student's active daily challenge, completion progress bar,
/// and XP reward badge.
class TodayChallengeSection extends StatefulWidget {
  final String userId;
  final ChallengeService? challengeService;

  const TodayChallengeSection({
    super.key,
    required this.userId,
    this.challengeService,
  });

  @override
  State<TodayChallengeSection> createState() => _TodayChallengeSectionState();
}

class _TodayChallengeSectionState extends State<TodayChallengeSection> {
  ChallengeService? _service;
  late Future<List<Challenge>> _challengesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.challengeService != null) {
      _service = widget.challengeService;
    } else if (Firebase.apps.isNotEmpty) {
      try {
        _service = ChallengeService();
      } catch (_) {}
    }
    _loadChallenges();
  }

  void _loadChallenges() {
    if (_service == null) {
      _challengesFuture = Future.value(const []);
      return;
    }
    try {
      _challengesFuture = _service!.getChallengesForDate(
        userId: widget.userId,
        date: DateTime.now(),
      );
    } catch (_) {
      _challengesFuture = Future.value(const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

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
              "Today's Challenge",
              style: AppTextStyles.headingMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/challenges'),
              style: TextButton.styleFrom(
                foregroundColor: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // ====================================================
        // CHALLENGE CARD
        // ====================================================
        FutureBuilder<List<Challenge>>(
          future: _challengesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 70,
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.border),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final challenges = snapshot.data ?? [];

            if (challenges.isEmpty) {
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: colors.isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.amber,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No active challenge today',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Earn XP and build your daily study streak.',
                            style: AppTextStyles.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () => context.push('/challenges'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }

            final challenge = challenges.first;
            final progressFraction = challenge.targetCount > 0
                ? (challenge.currentCount / challenge.targetCount).clamp(0.0, 1.0)
                : 0.0;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.flag_rounded,
                          color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              challenge.subject,
                              style: AppTextStyles.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: colors.isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '+${challenge.rewardXp} XP',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // PROGRESS BAR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${challenge.currentCount} / ${challenge.targetCount}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        challenge.isCompleted ? 'Completed' : 'In progress',
                        style: AppTextStyles.caption.copyWith(
                          color: challenge.isCompleted ? AppColors.success : colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      minHeight: 6,
                      backgroundColor: colors.surfaceSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        challenge.isCompleted
                            ? AppColors.success
                            : (colors.isDark ? AppColors.primaryForDark : AppColors.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/challenges'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        challenge.isCompleted ? 'View Details' : 'Start Challenge',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                        side: BorderSide(
                          color: (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                              .withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
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
