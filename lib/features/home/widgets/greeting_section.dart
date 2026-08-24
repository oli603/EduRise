import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class GreetingSection extends StatelessWidget {
  final String studentName;

  const GreetingSection({super.key, required this.studentName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hey 👋", style: AppTextStyles.body),

              const SizedBox(height: AppSpacing.xs),

              Text(studentName, style: AppTextStyles.heading2),

              const SizedBox(height: AppSpacing.sm),

              const Text("Rise Beyond Limits.", style: AppTextStyles.body),
            ],
          ),
        ),

        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
