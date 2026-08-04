import 'package:edurise/features/auth/data/auth_service.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/edurise_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import 'package:go_router/go_router.dart';
import 'package:edurise/core/theme/app_spacing.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  // ignore: prefer_final_fields
  bool _hidePassword = true;
  // ignore: prefer_final_fields
  bool _hideConfirmPassword = true;

  bool _isLoading = false;
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _authService.registerWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result.isSuccess) {
      context.go('/verify-email');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          EduRiseTextField(
            controller: _nameController,
            label: "Full Name",
            hint: "Enter your full name",
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Please enter your full name.";
              }

              if (value.trim().length < 3) {
                return "Name must be at least 3 characters.";
              }

              return null;
            },
          ),

          const SizedBox(height: 20),

          EduRiseTextField(
            controller: _emailController,
            label: "Email",
            hint: "Enter your email",
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "Please enter your email.";
              }

              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

              if (!emailRegex.hasMatch(value.trim())) {
                return "Please enter a valid email address.";
              }

              return null;
            },
          ),

          const SizedBox(height: 20),

          EduRiseTextField(
            controller: _passwordController,
            label: "Password",
            hint: "Create a password",
            obscureText: _hidePassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please create a password.";
              }

              if (value.length < 6) {
                return "Password must be at least 6 characters.";
              }

              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _hidePassword = !_hidePassword;
                });
              },
            ),
          ),

          const SizedBox(height: 20),

          EduRiseTextField(
            controller: _confirmPasswordController,
            label: "Confirm Password",
            hint: "Confirm your password",
            obscureText: _hideConfirmPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please confirm your password.";
              }

              if (value != _passwordController.text) {
                return "Passwords do not match.";
              }

              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _hideConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _hideConfirmPassword = !_hideConfirmPassword;
                });
              },
            ),
          ),

          const SizedBox(height: 30),

          PrimaryButton(
            text: _isLoading ? "Creating..." : "Create Account",
            onPressed: _isLoading ? null : _register,
          ),

          const SizedBox(height: 24),

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

          const SizedBox(height: 24),

          SecondaryButton(
            text: "Continue with Google",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Google Sign-In coming soon.")),
              );
            },
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Already have an account?"),
              TextButton(
                onPressed: () {
                  context.go('/login');
                },
                child: const Text("Sign In"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
