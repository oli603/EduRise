import 'package:flutter/material.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import 'package:edurise/core/theme/app_spacing.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

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
          PrimaryButton(text: "I've Verified", onPressed: () {}),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(text: "Resend Email", onPressed: () {}),
        ],
      ),
    );
  }
}
