import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';

/// A theme-aware, modern card container for the EduRise design system.
///
/// Automatically adapts surface color, border, and elevation between
/// Light and Dark themes, supporting optional ink taps and accent borders.
class EduRiseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final bool hasElevation;
  final Color? accentColor;
  final double accentWidth;

  const EduRiseCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.hasElevation = false,
    this.accentColor,
    this.accentWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedRadius = borderRadius ?? BorderRadius.circular(AppRadius.lg);

    final resolvedBg = backgroundColor ??
        (isDark ? AppColors.surfaceDark : Colors.white);

    final resolvedBorder = borderColor ??
        (isDark ? AppColors.borderDark : AppColors.border);

    final resolvedShadow = hasElevation
        ? (isDark ? AppElevation.cardDark : AppElevation.card)
        : AppElevation.none;

    Widget cardContent = padding == EdgeInsets.zero
        ? child
        : Padding(padding: padding, child: child);

    if (accentColor != null) {
      cardContent = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: accentWidth,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.only(
                topLeft: resolvedRadius.topLeft,
                bottomLeft: resolvedRadius.bottomLeft,
              ),
            ),
          ),
          Expanded(child: cardContent),
        ],
      );
    }

    final cardWidget = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: resolvedRadius,
        border: Border.all(color: resolvedBorder, width: borderWidth),
        boxShadow: resolvedShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: resolvedRadius,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: resolvedRadius,
                child: cardContent,
              )
            : cardContent,
      ),
    );

    return cardWidget;
  }
}
