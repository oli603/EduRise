import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class QuickAccessSection extends StatelessWidget {
  const QuickAccessSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Access",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: AppSpacing.md),

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
              icon: Icons.edit_note_rounded,
              title: "Practice",
              subtitle: "Solve questions",
              onTap: () {
                context.push('/practice-selection');
              },
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.track_changes_rounded,
              title: "Weak Areas",
              subtitle: "Find your gaps",
              onTap: () {
                context.push('/weak-areas');
              },
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.calendar_month_rounded,
              title: "Study Plan",
              subtitle: "Plan your study",
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.bar_chart_rounded,
              title: "Progress",
              subtitle: "See your growth",
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.emoji_events_rounded,
              title: "Challenges",
              subtitle: "Build your streak",
            ),

            _buildQuickAccessCard(
              context,
              icon: Icons.auto_awesome_rounded,
              title: "AI Coach",
              subtitle: "Get guidance",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap:
            onTap ??
            () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("$title coming soon.")));
            },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),

              const SizedBox(width: 10),

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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
