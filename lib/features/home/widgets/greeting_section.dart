import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Modern, expressive, and premium hero greeting for the EduRise Home screen.
///
/// Designed to feel elevated, Gen-Z friendly, and deeply integrated with EduRise
/// design tokens, dark mode, and responsive layout constraints.
class GreetingSection extends StatelessWidget {
  final String studentName;
  final String? contextualLabel;
  final String? subtitle;
  final Stream<int>? unreadCountStream;

  const GreetingSection({
    super.key,
    required this.studentName,
    this.contextualLabel,
    this.subtitle,
    this.unreadCountStream,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final resolvedContextualLabel = (contextualLabel ?? 'WELCOME BACK').toUpperCase();
    final resolvedSubtitle = subtitle ?? 'Ready to conquer today’s study goals?';
    final cleanName = studentName.replaceAll('👋', '').trim();
    final displayName = cleanName.isNotEmpty ? cleanName : 'Student';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.8),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.cardBackground,
            colors.isDark
                ? colors.cardBackground.withValues(alpha: 0.8)
                : AppColors.primary.withValues(alpha: 0.04),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Greeting Pill & Context Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                        .withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      resolvedContextualLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: colors.isDark
                            ? AppColors.primaryForDark
                            : AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Micro encouragement badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Grade 9–12 Prep',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Expressive Student Name
          Text(
            '$displayName 👋',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingLarge.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 6),

          // Inspiring Educational Subtitle
          Text(
            resolvedSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
