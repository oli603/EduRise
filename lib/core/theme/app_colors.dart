import 'package:flutter/material.dart';

/// Centralized color tokens for the EduRise design system.
///
/// Contains brand colors (matching the official EduRise bird/book logo),
/// semantic status colors, light/dark mode palettes, and dynamic theme resolution.
class AppColors {
  AppColors._();

  // ============================================================
  // BRAND COLORS (Derived from Official EduRise Logo)
  // ============================================================
  /// Core primary sapphire blue (preserves backward compatibility)
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF60A5FA);

  /// Authoritative logo colors
  static const Color brandBlue = Color(0xFF0052CC);
  static const Color brandDarkBlue = Color(0xFF003D99);
  static const Color brandTeal = Color(0xFF00B4D8);
  static const Color brandTealAccent = Color(0xFF06D6A0);

  // ============================================================
  // LIGHT PALETTE (Preserves backward compatibility)
  // ============================================================
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // ============================================================
  // DARK PALETTE
  // ============================================================
  static const Color scaffoldDark = Color(0xFF0B1120);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceSubtleDark = Color(0xFF334155);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);
  static const Color primaryForDark = Color(0xFF3B82F6);

  // ============================================================
  // STATUS & SEMANTIC PALETTE
  // ============================================================
  static const Color success = Color(0xFF10B981);
  static const Color successContainerLight = Color(0xFFECFDF5);
  static const Color successContainerDark = Color(0xFF064E3B);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainerLight = Color(0xFFFFFBEB);
  static const Color warningContainerDark = Color(0xFF78350F);

  static const Color error = Color(0xFFEF4444);
  static const Color errorContainerLight = Color(0xFFFEF2F2);
  static const Color errorContainerDark = Color(0xFF7F1D1D);

  static const Color info = Color(0xFF8B5CF6);
  static const Color infoContainerLight = Color(0xFFF5F3FF);
  static const Color infoContainerDark = Color(0xFF4C1D95);

  // ============================================================
  // NEUTRALS
  // ============================================================
  static const Color white = Colors.white;
  static const Color grey = Colors.grey;
}

/// Dynamic, theme-aware colors resolving based on the active [Brightness].
class EduRiseThemeColors {
  final bool isDark;
  final Color primary;
  final Color scaffoldBackground;
  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color cardBackground;
  final Color dialogBackground;
  final Color bottomSheetBackground;

  const EduRiseThemeColors._({
    required this.isDark,
    required this.primary,
    required this.scaffoldBackground,
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.cardBackground,
    required this.dialogBackground,
    required this.bottomSheetBackground,
  });

  factory EduRiseThemeColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? EduRiseThemeColors.dark : EduRiseThemeColors.light;
  }

  static const EduRiseThemeColors light = EduRiseThemeColors._(
    isDark: false,
    primary: AppColors.primary,
    scaffoldBackground: AppColors.background,
    surface: AppColors.surface,
    surfaceSubtle: AppColors.surfaceSubtle,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    cardBackground: Colors.white,
    dialogBackground: Colors.white,
    bottomSheetBackground: Colors.white,
  );

  static const EduRiseThemeColors dark = EduRiseThemeColors._(
    isDark: true,
    primary: AppColors.primaryForDark,
    scaffoldBackground: AppColors.scaffoldDark,
    surface: AppColors.surfaceDark,
    surfaceSubtle: AppColors.surfaceSubtleDark,
    border: AppColors.borderDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textMuted: AppColors.textMutedDark,
    cardBackground: AppColors.surfaceDark,
    dialogBackground: AppColors.surfaceDark,
    bottomSheetBackground: AppColors.surfaceDark,
  );
}

/// Extension on BuildContext for quick access to theme colors.
extension EduRiseThemeColorsExtension on BuildContext {
  EduRiseThemeColors get eduColors => EduRiseThemeColors.of(this);
}
