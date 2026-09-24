import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/edurise_logo.dart';
import '../../../core/widgets/google_sign_in_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../data/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.stream = ''});

  final String stream;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final result = await _authService.signInWithGoogle();

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    try {
      final destination =
          await RoleService.resolvePostAuthRoute(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (destination == '/profile-setup' && widget.stream.isNotEmpty) {
        context.go('/profile-setup?stream=${Uri.encodeComponent(widget.stream)}');
      } else {
        context.go(destination);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to complete sign in. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final streamQuery =
        widget.stream.isNotEmpty ? '?stream=${Uri.encodeComponent(widget.stream)}' : '';

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              const EduRiseLogo(
                size: 80,
                showLabel: true,
              ),

              const SizedBox(height: AppSpacing.lg),

              Text(
                "Welcome Back 👋",
                style: AppTextStyles.headingLarge.copyWith(
                  color: colors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Every question you solve\nbrings you one step closer\nto your dream university.",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),

              const Spacer(),

              GoogleSignInButton(
                isLoading: _isLoading,
                onPressed: _handleGoogleSignIn,
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                "OR",
                style: AppTextStyles.labelMedium.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              SecondaryButton(
                text: "Continue with Email",
                onPressed: _isLoading
                    ? null
                    : () {
                        context.go('/login$streamQuery');
                      },
              ),

              const SizedBox(height: AppSpacing.xl),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            context.go('/register$streamQuery');
                          },
                    child: const Text("Create Account"),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
