import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/edurise_text_field.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../../../core/widgets/primary_button.dart';
import 'package:edurise/features/auth/data/auth_service.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key, this.stream = ''});

  final String stream;

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

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _navigateToDestination(String destination) {
    if (destination == '/profile-setup' && widget.stream.isNotEmpty) {
      context.go('/profile-setup?stream=${Uri.encodeComponent(widget.stream)}');
    } else {
      context.go(destination);
    }
  }

  Future<void> _googleSignIn() async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    try {
      final destination = await RoleService.resolvePostAuthRoute(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _navigateToDestination(destination);
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

  Future<void> _register() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _authService.registerWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      final streamQuery = widget.stream.isNotEmpty
          ? '?stream=${Uri.encodeComponent(widget.stream)}'
          : '';
      context.go('/verify-email$streamQuery');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EduRiseTextField(
            controller: _nameController,
            label: "Full Name",
            hint: "Enter your full name",
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            enabled: !_isLoading,
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

          const SizedBox(height: 12),

          EduRiseTextField(
            controller: _emailController,
            label: "Email",
            hint: "Enter your email",
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            enabled: !_isLoading,
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

          const SizedBox(height: 12),

          EduRiseTextField(
            controller: _passwordController,
            label: "Password",
            hint: "Create a password",
            helperText: "Must be at least 6 characters",
            obscureText: _hidePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            enabled: !_isLoading,
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

          const SizedBox(height: 12),

          EduRiseTextField(
            controller: _confirmPasswordController,
            label: "Confirm Password",
            hint: "Confirm your password",
            obscureText: _hideConfirmPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _register(),
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

          const SizedBox(height: 16),

          PrimaryButton(
            text: _isLoading ? "Creating..." : "Create Account",
            onPressed: _isLoading ? null : _register,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  "OR",
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 12),

          GoogleSignInButton(
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _googleSignIn,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account?",
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        final streamQuery = widget.stream.isNotEmpty
                            ? '?stream=${Uri.encodeComponent(widget.stream)}'
                            : '';
                        context.go('/login$streamQuery');
                      },
                child: const Text("Sign In", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
