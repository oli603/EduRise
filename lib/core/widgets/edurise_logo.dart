import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum EduRiseLogoSize {
  small(28),
  medium(44),
  large(64),
  hero(88);

  final double dimension;
  const EduRiseLogoSize(this.dimension);
}

/// Official authoritative logo component for EduRise.
///
/// Wraps the official EduRise bird & book asset, preserving its exact proportions,
/// colors, and transparency without distortion.
class EduRiseLogo extends StatelessWidget {
  /// The size of the logo mark (width and height).
  final double size;

  /// Whether to render the official "EduRise" wordmark next to or below the logo.
  final bool showLabel;

  /// Whether to render the official "Rise Beyond Limits" tagline.
  final bool showTagline;

  /// Layout axis when [showLabel] is true.
  final Axis axis;

  /// Optional override for the wordmark text color.
  final Color? labelColor;

  /// Custom asset path override if needed.
  final String assetPath;

  const EduRiseLogo({
    super.key,
    this.size = 48,
    this.showLabel = false,
    this.showTagline = false,
    this.axis = Axis.vertical,
    this.labelColor,
    this.assetPath = 'assets/images/edurise_logo_bird_book_symbol_transparent.png',
  });

  /// Factory for a compact app bar or inline logo.
  factory EduRiseLogo.small({
    Key? key,
    bool showLabel = false,
    Color? labelColor,
    Axis axis = Axis.horizontal,
  }) {
    return EduRiseLogo(
      key: key,
      size: EduRiseLogoSize.small.dimension,
      showLabel: showLabel,
      labelColor: labelColor,
      axis: axis,
    );
  }

  /// Factory for cards, drawers, and form headers.
  factory EduRiseLogo.medium({
    Key? key,
    bool showLabel = true,
    bool showTagline = false,
    Color? labelColor,
    Axis axis = Axis.vertical,
  }) {
    return EduRiseLogo(
      key: key,
      size: EduRiseLogoSize.medium.dimension,
      showLabel: showLabel,
      showTagline: showTagline,
      labelColor: labelColor,
      axis: axis,
    );
  }

  /// Factory for splash, welcome, and major authentication headers.
  factory EduRiseLogo.hero({
    Key? key,
    bool showLabel = true,
    bool showTagline = true,
    Color? labelColor,
  }) {
    return EduRiseLogo(
      key: key,
      size: EduRiseLogoSize.hero.dimension,
      showLabel: showLabel,
      showTagline: showTagline,
      axis: Axis.vertical,
      labelColor: labelColor,
    );
  }

  Widget _buildLogoImage() {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to solid symbol if transparent variant is missing
        return Image.asset(
          'assets/images/edurise_logo_bird_book_symbol.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Neutral development placeholder without inventing a replacement brand mark
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: size * 0.55,
                color: AppColors.primary,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedLabelColor = labelColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    final resolvedTaglineColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    final logoWidget = _buildLogoImage();

    if (!showLabel && !showTagline) {
      return logoWidget;
    }

    final labelWidget = Text(
      'EduRise',
      style: TextStyle(
        fontSize: size >= 64 ? 28 : (size >= 40 ? 20 : 16),
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: resolvedLabelColor,
      ),
    );

    final taglineWidget = showTagline
        ? Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Rise Beyond Limits',
              style: TextStyle(
                fontSize: size >= 64 ? 14 : 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color: resolvedTaglineColor,
              ),
            ),
          )
        : const SizedBox.shrink();

    if (axis == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          logoWidget,
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              if (showTagline) taglineWidget,
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoWidget,
        SizedBox(height: size >= 64 ? 12 : 8),
        labelWidget,
        if (showTagline) taglineWidget,
      ],
    );
  }
}
