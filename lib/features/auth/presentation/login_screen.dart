import 'package:flutter/material.dart';
import 'package:edurise/core/widgets/auth_layout.dart';
import 'package:edurise/features/auth/presentation/widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthLayout(
      title: "Welcome Back",
      subtitle: "Sign in to continue your EduRise journey.",
      child: LoginForm(),
    );
  }
}
