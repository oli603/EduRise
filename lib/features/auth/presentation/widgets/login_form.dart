import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/edurise_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import 'package:edurise/features/auth/data/auth_service.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // 1. Validate the form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Show loading
    setState(() {
      _isLoading = true;
    });

    // 3. Call authentication service
    final result = await _authService.signInWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );

    // 4. Stop loading
    setState(() {
      _isLoading = false;
    });

    // 5. Check authentication result
    if (result.isSuccess) {
      if (!mounted) return;

      context.go('/home');
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          EduRiseTextField(
            label: "Email",
            hint: "Enter your email",
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(AppIcons.email),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Please enter your email.";
              }
              if (!value.contains('@')) {
                return "Please enter a valid email.";
              }
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          EduRiseTextField(
            label: "Password",
            hint: "Enter your password",
            controller: _passwordController,
            obscureText: _obscurePassword,
            prefixIcon: const Icon(AppIcons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter your password.";
              }

              if (value.length < 6) {
                return "Password must be at least 6 characters.";
              }

              return null;
            },
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Password reset will be added soon."),
                  ),
                );
              },
              child: const Text("Forgot Password?"),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          PrimaryButton(
            text: _isLoading ? "Signing In..." : "Continue",
            onPressed: _isLoading ? null : _login,
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("OR"),
              ),
              Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          SecondaryButton(
            text: "Continue with Google",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Google Sign-In will be available soon."),
                ),
              );
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
        ],
      ),
    );
  }
}
