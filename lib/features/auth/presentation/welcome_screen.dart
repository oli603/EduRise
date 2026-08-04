import 'package:flutter/material.dart';

import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/theme/app_text_styles.dart';
import 'package:edurise/core/theme/app_icons.dart';
import 'package:edurise/core/theme/app_spacing.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              const Icon(AppIcons.school, size: 90),

              const SizedBox(height: AppSpacing.lg),

              const Text("EduRise", style: AppTextStyles.heading1),

              const SizedBox(height: AppSpacing.md),

              const Text("Welcome Back 👋", style: AppTextStyles.heading2),

              const SizedBox(height: 12),

              const Text(
                "Every question you solve\nbrings you one step closer\nto your dream university.",
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),

              const Spacer(),

              PrimaryButton(
                text: "Continue with Google",
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Google Sign-In coming soon."),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),

              const Text("OR"),

              const SizedBox(height: AppSpacing.md),

              SecondaryButton(
                text: "Continue with Email",
                onPressed: () {
                  context.go('/login');
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),

                  TextButton(
                    onPressed: () {
                      context.go('/register');
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
