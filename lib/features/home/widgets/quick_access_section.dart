import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Modern, responsive Quick Access action grid for the EduRise Home screen.
///
/// Delivers direct 1-tap entry points to key student modules with
/// theme-aware styling, high-contrast typography, and accessible touch targets.
class QuickAccessSection extends StatelessWidget {
  final String? studentGrade;

  const QuickAccessSection({
    super.key,
    this.studentGrade,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final resolvedGrade = studentGrade ?? 'Grade 12';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ====================================================
        // SECTION HEADER
        // ====================================================
        Text(
          'Quick Access',
          style: AppTextStyles.headingMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ====================================================
        // 2-COLUMN RESPONSIVE ACTION GRID
        // ====================================================
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildQuickAccessCard(
              context,
              icon: Icons.emoji_events_rounded,
              iconColor: Colors.amber.shade600,
              title: 'Challenges',
              subtitle: 'Build your streak',
              onTap: () => context.push('/challenges'),
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.history_edu_rounded,
              iconColor: colors.isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              title: 'Past Entrance Exams',
              subtitle: 'National exams',
              onTap: () => context.push('/past-entrance-exams'),
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.psychology_rounded,
              iconColor: colors.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
              title: 'Predicted Mock Exam',
              subtitle: 'Exam Blueprint',
              onTap: () => context.push('/predicted-mock-exam'),
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.track_changes_rounded,
              iconColor: colors.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              title: 'Weak Areas',
              subtitle: 'Find your gaps',
              onTap: () => context.push('/weak-areas'),
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.calendar_month_rounded,
              iconColor: colors.isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              title: 'Study Plan',
              subtitle: 'Plan your study',
              onTap: () => context.push('/study-plan'),
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.menu_book_rounded,
              iconColor: colors.isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
              title: 'Books',
              subtitle: 'Learn by unit',
              onTap: () {
                context.push(
                  '/books?grade=${Uri.encodeComponent(resolvedGrade)}&subject=${Uri.encodeComponent("Mathematics")}',
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.eduColors;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.isDark
                      ? Colors.black.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Intentional branded icon container
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: colors.isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Title and Subtitle with clear hierarchy
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
