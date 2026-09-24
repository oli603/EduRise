import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

enum EduRiseButtonVariant {
  primary,
  secondary,
  tonal,
  danger,
}

/// A modern, accessible, and high-performance button component for EduRise.
///
/// Supports loading states, leading/trailing icons, multiple visual variants,
/// and subtle tactile haptic feedback.
class EduRiseButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final EduRiseButtonVariant variant;
  final bool isLoading;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final TextStyle? textStyle;
  final bool enableHaptics;

  const EduRiseButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = EduRiseButtonVariant.primary,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.height = 52,
    this.borderRadius,
    this.textStyle,
    this.enableHaptics = true,
  });

  /// Factory for a primary filled button.
  factory EduRiseButton.primary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? leadingIcon,
    Widget? trailingIcon,
    double? width,
    double height = 52,
  }) {
    return EduRiseButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: EduRiseButtonVariant.primary,
      isLoading: isLoading,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      width: width,
      height: height,
    );
  }

  /// Factory for an outlined secondary button.
  factory EduRiseButton.outlined({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? leadingIcon,
    Widget? trailingIcon,
    double? width,
    double height = 52,
  }) {
    return EduRiseButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: EduRiseButtonVariant.secondary,
      isLoading: isLoading,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      width: width,
      height: height,
    );
  }

  /// Factory for a tonal/soft background button.
  factory EduRiseButton.tonal({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? leadingIcon,
    Widget? trailingIcon,
    double? width,
    double height = 52,
  }) {
    return EduRiseButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: EduRiseButtonVariant.tonal,
      isLoading: isLoading,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      width: width,
      height: height,
    );
  }

  /// Factory for a destructive action button.
  factory EduRiseButton.danger({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Widget? leadingIcon,
    Widget? trailingIcon,
    double? width,
    double height = 52,
  }) {
    return EduRiseButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: EduRiseButtonVariant.danger,
      isLoading: isLoading,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      width: width,
      height: height,
    );
  }

  void _handleTap() {
    if (isLoading || onPressed == null) return;
    if (enableHaptics) {
      HapticFeedback.lightImpact();
    }
    onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null && !isLoading;
    final resolvedRadius = borderRadius ?? BorderRadius.circular(AppRadius.md);

    // Visual configurations based on variant & theme
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case EduRiseButtonVariant.primary:
        backgroundColor = isDark ? AppColors.primaryForDark : AppColors.primary;
        foregroundColor = Colors.white;
        borderSide = null;
        break;

      case EduRiseButtonVariant.secondary:
        backgroundColor = Colors.transparent;
        foregroundColor = isDark ? AppColors.primaryForDark : AppColors.primary;
        borderSide = BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1.5,
        );
        break;

      case EduRiseButtonVariant.tonal:
        backgroundColor = isDark
            ? AppColors.primaryForDark.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.1);
        foregroundColor = isDark ? AppColors.primaryForDark : AppColors.primary;
        borderSide = null;
        break;

      case EduRiseButtonVariant.danger:
        backgroundColor = isDark ? AppColors.errorContainerDark : AppColors.error;
        foregroundColor = Colors.white;
        borderSide = null;
        break;
    }

    if (!isEnabled) {
      backgroundColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      foregroundColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      borderSide = null;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leadingIcon != null) ...[
            leadingIcon!,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              style: (textStyle ?? AppTextStyles.labelLarge).copyWith(
                color: foregroundColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            trailingIcon!,
          ],
        ],
      );
    }

    final buttonWidget = Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: resolvedRadius,
        side: borderSide ?? BorderSide.none,
      ),
      child: InkWell(
        onTap: isEnabled ? _handleTap : null,
        borderRadius: resolvedRadius,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: buttonWidget);
    }

    return buttonWidget;
  }
}
