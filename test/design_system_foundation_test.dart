import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/theme/app_colors.dart';
import 'package:edurise/core/theme/app_elevation.dart';
import 'package:edurise/core/theme/app_motion.dart';
import 'package:edurise/core/theme/app_radius.dart';
import 'package:edurise/core/theme/app_spacing.dart';
import 'package:edurise/core/theme/app_text_styles.dart';
import 'package:edurise/core/theme/app_theme.dart';
import 'package:edurise/core/widgets/edurise_badge.dart';
import 'package:edurise/core/widgets/edurise_button.dart';
import 'package:edurise/core/widgets/edurise_card.dart';
import 'package:edurise/core/widgets/edurise_chip.dart';
import 'package:edurise/core/widgets/edurise_empty_state.dart';
import 'package:edurise/core/widgets/edurise_error_state.dart';
import 'package:edurise/core/widgets/edurise_loading_state.dart';
import 'package:edurise/core/widgets/edurise_logo.dart';
import 'package:edurise/core/widgets/edurise_section_header.dart';

void main() {
  group('Design System — Color Tokens & Theme Resolution Tests', () {
    test('AppColors brand and backward-compatible constants are preserved', () {
      expect(AppColors.primary, const Color(0xFF2563EB));
      expect(AppColors.background, const Color(0xFFF8FAFC));
      expect(AppColors.surface, Colors.white);
      expect(AppColors.textPrimary, const Color(0xFF0F172A));
      expect(AppColors.textSecondary, const Color(0xFF64748B));
      expect(AppColors.border, const Color(0xFFE2E8F0));
      expect(AppColors.brandBlue, const Color(0xFF0052CC));
      expect(AppColors.brandTeal, const Color(0xFF00B4D8));
    });

    test('EduRiseThemeColors resolves properly between light and dark modes', () {
      final light = EduRiseThemeColors.light;
      expect(light.isDark, isFalse);
      expect(light.scaffoldBackground, AppColors.background);
      expect(light.surface, Colors.white);
      expect(light.textPrimary, AppColors.textPrimary);

      final dark = EduRiseThemeColors.dark;
      expect(dark.isDark, isTrue);
      expect(dark.scaffoldBackground, AppColors.scaffoldDark);
      expect(dark.surface, AppColors.surfaceDark);
      expect(dark.textPrimary, AppColors.textPrimaryDark);
    });

    testWidgets('EduRiseThemeColors.of(context) dynamically resolves based on brightness', (tester) async {
      late EduRiseThemeColors lightDetected;
      late EduRiseThemeColors darkDetected;

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.lightTheme,
            child: Builder(
              builder: (context) {
                lightDetected = context.eduColors;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(lightDetected.isDark, isFalse);
      expect(lightDetected.surface, Colors.white);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.darkTheme,
            child: Builder(
              builder: (context) {
                darkDetected = context.eduColors;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(darkDetected.isDark, isTrue);
      expect(darkDetected.surface, AppColors.surfaceDark);
    });
  });

  group('Design System — Typography, Spacing, Radii, Elevation & Motion Tests', () {
    test('AppTextStyles preserves legacy constants and defines semantic hierarchy', () {
      expect(AppTextStyles.heading1.fontSize, 32);
      expect(AppTextStyles.heading2.fontSize, 24);
      expect(AppTextStyles.body.fontSize, 16);
      expect(AppTextStyles.button.fontSize, 17);

      expect(AppTextStyles.display.fontSize, 32);
      expect(AppTextStyles.headingLarge.fontSize, 24);
      expect(AppTextStyles.headingMedium.fontSize, 20);
      expect(AppTextStyles.headingSmall.fontSize, 17);
      expect(AppTextStyles.cardTitle.fontSize, 16);
      expect(AppTextStyles.bodyLarge.fontSize, 16);
      expect(AppTextStyles.bodyMedium.fontSize, 14);
      expect(AppTextStyles.bodySmall.fontSize, 13);
      expect(AppTextStyles.labelLarge.fontSize, 15);
      expect(AppTextStyles.labelMedium.fontSize, 12);
      expect(AppTextStyles.caption.fontSize, 11);
      expect(AppTextStyles.overline.fontSize, 10);
    });

    test('AppSpacing scale conforms to design system geometric tokens', () {
      expect(AppSpacing.xxs, 2);
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.contentPadding, 20);
      expect(AppSpacing.lg, 24);
      expect(AppSpacing.xl, 32);
      expect(AppSpacing.xxl, 48);
      expect(AppSpacing.xxxl, 64);
    });

    test('AppRadius scale and BorderRadius helpers match specifications', () {
      expect(AppRadius.xs, 4);
      expect(AppRadius.sm, 8);
      expect(AppRadius.md, 12);
      expect(AppRadius.lg, 16);
      expect(AppRadius.xl, 20);
      expect(AppRadius.xxl, 24);
      expect(AppRadius.full, 9999);

      expect(AppRadius.mdRadius, BorderRadius.circular(12));
      expect(AppRadius.lgRadius, BorderRadius.circular(16));
    });

    test('AppElevation and AppMotion tokens are defined', () {
      expect(AppElevation.none, isEmpty);
      expect(AppElevation.card, isNotEmpty);
      expect(AppElevation.dialog, isNotEmpty);

      expect(AppMotion.fast, const Duration(milliseconds: 150));
      expect(AppMotion.normal, const Duration(milliseconds: 250));
      expect(AppMotion.medium, const Duration(milliseconds: 350));
      expect(AppMotion.slow, const Duration(milliseconds: 500));
    });

    test('AppTheme light and dark themes are fully configured Material 3 themes', () {
      expect(AppTheme.lightTheme.useMaterial3, isTrue);
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.background);
      expect(AppTheme.lightTheme.cardTheme.color, Colors.white);

      expect(AppTheme.darkTheme.useMaterial3, isTrue);
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppColors.scaffoldDark);
      expect(AppTheme.darkTheme.cardTheme.color, AppColors.surfaceDark);
    });
  });

  group('Design System — EduRiseLogo Branding Tests', () {
    testWidgets('Renders EduRiseLogo without errors and displays official branding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EduRiseLogo(
                size: 48,
                showLabel: true,
                showTagline: true,
              ),
            ),
          ),
        ),
      );

      // Verify exact authoritative capitalization
      expect(find.text('EduRise'), findsOneWidget);
      expect(find.text('Rise Beyond Limits'), findsOneWidget);
    });

    testWidgets('EduRiseLogo factory constructors build as expected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                EduRiseLogo.small(showLabel: true),
                EduRiseLogo.medium(),
                EduRiseLogo.hero(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('EduRise'), findsNWidgets(3));
      expect(find.text('Rise Beyond Limits'), findsOneWidget);
    });
  });

  group('Design System — Reusable Foundational Components Tests', () {
    testWidgets('EduRiseButton renders primary, loading, and handles taps', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EduRiseButton(
                text: 'Continue Practice',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Continue Practice'), findsOneWidget);
      await tester.tap(find.text('Continue Practice'));
      await tester.pump();
      expect(tapped, isTrue);

      // Verify loading state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EduRiseButton(
                text: 'Submitting',
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('EduRiseCard renders child and handles onTap', (tester) async {
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EduRiseCard(
              onTap: () => cardTapped = true,
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      await tester.pump();
      expect(cardTapped, isTrue);
    });

    testWidgets('EduRiseSectionHeader renders title, subtitle, and action', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EduRiseSectionHeader(
              title: 'Study Units',
              subtitle: 'Select a unit to study',
              actionText: 'See All',
              onActionTap: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Study Units'), findsOneWidget);
      expect(find.text('Select a unit to study'), findsOneWidget);
      expect(find.text('See All'), findsOneWidget);

      await tester.tap(find.text('See All'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });

    testWidgets('EduRiseBadge renders semantic variants correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                EduRiseBadge.ai(),
                EduRiseBadge.admin(),
                EduRiseBadge.free(),
                EduRiseBadge.premium(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('AI'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);
    });

    testWidgets('EduRiseChip toggles selection state', (tester) async {
      bool chipTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EduRiseChip(
              label: 'Grade 12',
              isSelected: true,
              onTap: () => chipTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Grade 12'), findsOneWidget);
      await tester.tap(find.text('Grade 12'));
      await tester.pump();
      expect(chipTapped, isTrue);
    });

    testWidgets('EduRiseEmptyState and EduRiseErrorState render gracefully', (tester) async {
      bool retryTapped = false;
      bool actionTapped = false;

      // Test Error State
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EduRiseErrorState(
              title: 'Connection Issue',
              message: 'Check your internet and try again.',
              onRetry: () => retryTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Connection Issue'), findsOneWidget);
      expect(find.text('Check your internet and try again.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retryTapped, isTrue);

      // Test Empty State
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EduRiseEmptyState(
              icon: Icons.quiz_outlined,
              title: 'No Questions Found',
              message: 'Try selecting a different chapter or subject.',
              actionLabel: 'Browse Subjects',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Questions Found'), findsOneWidget);
      expect(find.text('Try selecting a different chapter or subject.'), findsOneWidget);
      expect(find.text('Browse Subjects'), findsOneWidget);

      await tester.tap(find.text('Browse Subjects'));
      await tester.pump();
      expect(actionTapped, isTrue);

      // Test Loading State
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EduRiseLoadingState(
              message: 'Loading your learning units...',
            ),
          ),
        ),
      );

      expect(find.text('Loading your learning units...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
