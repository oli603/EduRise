import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../data/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.stream = ''});

  final String stream;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _checkVerification() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });

    try {
      await _authService.reloadUser();
      if (!mounted) return;

      if (_authService.isEmailVerified()) {
        final destination =
            await RoleService.resolvePostAuthRoute(forceRefresh: true);
        if (!mounted) return;
        if (destination == '/profile-setup' && widget.stream.isNotEmpty) {
          context.go('/profile-setup?stream=${Uri.encodeComponent(widget.stream)}');
        } else {
          context.go(destination);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Your email is not verified yet. Please check your inbox and spam folder."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to check verification status. Please try again."),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
    });

    try {
      final result = await _authService.sendVerificationEmail();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to send verification email.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: "Verify Your Email",
      subtitle:
          "We've sent a verification link to your email.\nPlease verify your account before continuing.",
      child: Column(
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 84, color: AppColors.primary),

          const SizedBox(height: AppSpacing.xl),

          PrimaryButton(
            text: _isChecking ? "Checking..." : "I've Verified",
            onPressed: (_isChecking || _isResending) ? null : _checkVerification,
          ),

          const SizedBox(height: AppSpacing.md),

          SecondaryButton(
            text: _isResending ? "Resending..." : "Resend Email",
            onPressed: (_isChecking || _isResending) ? null : _resendEmail,
          ),

          const SizedBox(height: AppSpacing.lg),

          TextButton(
            onPressed: (_isChecking || _isResending) ? null : _handleSignOut,
            child: const Text(
              "Sign Out / Use Different Email",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
