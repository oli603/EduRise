import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

enum EduRiseBadgeVariant {
  primary,
  success,
  warning,
  error,
  info,
  ai,
  neutral,
}

/// A compact semantic status badge for EduRise.
///
/// Designed with calibrated contrast for both Light and Dark modes.
class EduRiseBadge extends StatelessWidget {
  final String label;
  final EduRiseBadgeVariant variant;
  final Widget? icon;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  const EduRiseBadge({
    super.key,
    required this.label,
    this.variant = EduRiseBadgeVariant.primary,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.fontSize = 11,
  });

  /// Factory for AI tags (EduRise Coach, AI Unit Tools).
  factory EduRiseBadge.ai({
    Key? key,
    String label = 'AI',
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  }) {
    return EduRiseBadge(
      key: key,
      label: label,
      variant: EduRiseBadgeVariant.ai,
      icon: const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.info),
      padding: padding,
      fontSize: 10,
    );
  }

  /// Factory for Admin tags.
  factory EduRiseBadge.admin({
    Key? key,
    String label = 'ADMIN',
  }) {
    return EduRiseBadge(
      key: key,
      label: label,
      variant: EduRiseBadgeVariant.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      fontSize: 10,
    );
  }

  /// Factory for Free access tags.
  factory EduRiseBadge.free({
    Key? key,
    String label = 'FREE',
  }) {
    return EduRiseBadge(
      key: key,
      label: label,
      variant: EduRiseBadgeVariant.success,
      fontSize: 10,
    );
  }

  /// Factory for Premium access tags.
  factory EduRiseBadge.premium({
    Key? key,
    String label = 'PREMIUM',
  }) {
    return EduRiseBadge(
      key: key,
      label: label,
      variant: EduRiseBadgeVariant.warning,
      fontSize: 10,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case EduRiseBadgeVariant.primary:
        bg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        border = BorderSide(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE));
        break;

      case EduRiseBadgeVariant.success:
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
        border = BorderSide(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0));
        break;

      case EduRiseBadgeVariant.warning:
        bg = isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
        fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
        border = BorderSide(color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A));
        break;

      case EduRiseBadgeVariant.error:
        bg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
        fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
        border = BorderSide(color: isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA));
        break;

      case EduRiseBadgeVariant.info:
      case EduRiseBadgeVariant.ai:
        bg = isDark ? const Color(0xFF4C1D95) : const Color(0xFFF5F3FF);
        fg = isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);
        border = BorderSide(color: isDark ? const Color(0xFF7C3AED) : const Color(0xFFDDD6FE));
        break;

      case EduRiseBadgeVariant.neutral:
        bg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
        border = BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0));
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.fromBorderSide(border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
