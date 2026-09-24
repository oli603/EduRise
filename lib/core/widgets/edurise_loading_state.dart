import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A calm, non-jarring loading state component for EduRise.
///
/// Combines a branded spinner with an optional contextual message.
class EduRiseLoadingState extends StatelessWidget {
  final String? message;
  final double size;
  final EdgeInsetsGeometry padding;

  const EduRiseLoadingState({
    super.key,
    this.message,
    this.size = 36,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryForDark : AppColors.primary;
    final messageColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: messageColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
