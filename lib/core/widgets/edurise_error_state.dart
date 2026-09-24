import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'edurise_button.dart';

/// A respectful, clear error state component for EduRise.
///
/// Explains the error in friendly student terms and provides an explicit
/// retry action.
class EduRiseErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final EdgeInsetsGeometry padding;

  const EduRiseErrorState({
    super.key,
    this.title = 'Unable to Load Content',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = Icons.error_outline_rounded,
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
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.errorContainerDark.withValues(alpha: 0.5)
                    : AppColors.errorContainerLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
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
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              EduRiseButton.outlined(
                text: retryLabel,
                onPressed: onRetry,
                leadingIcon: const Icon(Icons.refresh_rounded, size: 18),
                width: 180,
                height: 48,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
