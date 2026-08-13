import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../data/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;
  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
    });
    await _authService.reloadUser();
    if (!mounted) return;
    setState(() {
      _isChecking = false;
    });
    if (_authService.isEmailVerified()) {
      context.go('/profile-setup');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your email is not verified yet.")),
      );
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
    });
    final result = await _authService.sendVerificationEmail();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: "Verify Your Email",
      subtitle:
          "We've sent a verification link to your email.\nPlease verify your account before continuing.",
      child: Column(
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 100),

          const SizedBox(height: AppSpacing.xl),

          PrimaryButton(
            text: _isChecking ? "Checking..." : "I've Verified",
            onPressed: _isChecking ? null : _checkVerification,
          ),

          const SizedBox(height: AppSpacing.md),

          SecondaryButton(
            text: _isResending ? "Resending..." : "Resend Email",
            onPressed: _isResending ? null : _resendEmail,
          ),
        ],
      ),
    );
  }
}
