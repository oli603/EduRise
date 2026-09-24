import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_service.dart';

/// Screen displayed when an authenticated student launches the application offline
/// on a device where their student profile has not been cached yet.
class OfflineVerificationScreen extends StatefulWidget {
  const OfflineVerificationScreen({super.key});

  @override
  State<OfflineVerificationScreen> createState() =>
      _OfflineVerificationScreenState();
}

class _OfflineVerificationScreenState extends State<OfflineVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);

    try {
      final result =
          await RoleService.resolvePostAuthRouteResult(forceRefresh: true);
      if (!mounted) return;

      if (result.status == PostAuthRouteStatus.existingStudent) {
        context.go('/home');
      } else if (result.status == PostAuthRouteStatus.needsProfileSetup) {
        context.go('/profile-setup');
      } else if (result.status == PostAuthRouteStatus.authorizedAdmin) {
        context.go('/admin');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Still offline. Please connect to the internet and try again.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to verify connection. Please check your internet and try again.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        context.go('/onboarding');
      }
    } catch (_) {
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'Student';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Offline Icon Badge
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Title
                const Text(
                  'Profile Verification Required',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Signed in account indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_circle_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          userEmail,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Message Body
                Text(
                  "You're signed in, but this device hasn't cached your student profile yet.\n\nConnect to the internet once to verify your profile and continue.",
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Retry Button
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: _isRetrying ? 'Checking Connection...' : 'Retry Verification',
                    onPressed: _isRetrying ? null : _handleRetry,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Sign Out Button
                TextButton(
                  onPressed: _isRetrying ? null : _handleSignOut,
                  child: const Text(
                    'Sign Out / Switch Account',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
