import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'edurise_button.dart';

/// A friendly, actionable empty state component for EduRise.
///
/// Ensures students understand why a section is empty and what
/// action they can take next.
class EduRiseEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customIllustration;
  final EdgeInsetsGeometry padding;

  const EduRiseEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.customIllustration,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final messageColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (customIllustration != null)
              customIllustration!
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryForDark.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: isDark ? AppColors.primaryForDark : AppColors.primary,
                ),
              ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium.copyWith(color: titleColor),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: messageColor),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              EduRiseButton.primary(
                text: actionLabel!,
                onPressed: onAction,
                width: 200,
                height: 48,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
