import 'package:flutter/material.dart';
import 'package:edurise/core/widgets/auth_layout.dart';
import 'package:edurise/features/auth/presentation/widgets/register_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthLayout(
      title: "Create Your Account",
      subtitle: "Start your journey toward your dream university with EduRise.",
      child: RegisterForm(),
    );
  }
}
