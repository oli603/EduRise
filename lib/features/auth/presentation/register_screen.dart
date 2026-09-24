import 'package:flutter/material.dart';
import 'package:edurise/core/widgets/auth_layout.dart';
import 'package:edurise/features/auth/presentation/widgets/register_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, this.stream = ''});

  final String stream;

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: "Create Your Account",
      subtitle: "Start your journey toward your dream university with EduRise.",
      child: RegisterForm(stream: stream),
    );
  }
}
