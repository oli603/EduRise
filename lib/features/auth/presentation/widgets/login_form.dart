import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/edurise_text_field.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/auth/role_service.dart';
import 'package:edurise/features/auth/data/auth_service.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.stream = ''});

  final String stream;

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

  Future<void> _login() async {
    if (_isLoading) return;

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

    if (!mounted) return;

    // 4. Resolve role and navigate
    if (result.isSuccess) {
      final destination = await RoleService.resolvePostAuthRoute(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _navigateToDestination(destination);
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    final resetFormKey = GlobalKey<FormState>();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: resetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your registered email address to receive a password reset link.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    EduRiseTextField(
                      label: 'Email',
                      hint: 'Enter your email',
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      enabled: !isResetting,
                      prefixIcon: const Icon(AppIcons.email),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email.';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isResetting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isResetting
                      ? null
                      : () async {
                          if (!resetFormKey.currentState!.validate()) return;
                          setDialogState(() => isResetting = true);

                          final result = await _authService.sendPasswordResetEmail(
                            resetEmailController.text.trim(),
                          );

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                  child: isResetting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EduRiseTextField(
            label: "Email",
            hint: "Enter your email",
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            enabled: !_isLoading,
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

          const SizedBox(height: 12),

          EduRiseTextField(
            label: "Password",
            hint: "Enter your password",
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            enabled: !_isLoading,
            prefixIcon: const Icon(AppIcons.lock),
            onFieldSubmitted: (_) => _login(),
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _isLoading ? null : _showForgotPasswordDialog,
              child: const Text("Forgot Password?", style: TextStyle(fontSize: 12)),
            ),
          ),

          const SizedBox(height: 12),

          PrimaryButton(
            text: _isLoading ? "Signing In..." : "Continue",
            onPressed: _isLoading ? null : _login,
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
                    fontWeight: FontWeight.w600,
                    color: context.eduColors.textMuted,
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
              const Text("Don't have an account?", style: TextStyle(fontSize: 13)),
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
                        context.go('/register$streamQuery');
                      },
                child: const Text("Create Account", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
