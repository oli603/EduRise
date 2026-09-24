import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// An interactive selection or filter chip for EduRise.
///
/// Adapts gracefully between light and dark modes with clear
/// visual feedback for selected/unselected states.
class EduRiseChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const EduRiseChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide border;

    if (isSelected) {
      bg = isDark
          ? AppColors.primaryForDark.withValues(alpha: 0.22)
          : AppColors.primary.withValues(alpha: 0.12);
      fg = isDark ? AppColors.primaryForDark : AppColors.primary;
      border = BorderSide(
        color: isDark ? AppColors.primaryForDark : AppColors.primary,
        width: 1.5,
      );
    } else {
      bg = isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtle;
      fg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
      border = BorderSide(
        color: isDark ? AppColors.borderDark : AppColors.border,
        width: 1,
      );
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        side: border,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
