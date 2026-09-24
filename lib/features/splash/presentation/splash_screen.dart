import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edurise_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    _handleStartup();
  }

  Future<void> _handleStartup() async {
    final user = FirebaseAuth.instance.currentUser;
    String destination = '/onboarding';

    if (user != null) {
      try {
        // Resolve post-auth destination concurrently with the branded splash duration
        final results = await Future.wait([
          RoleService.resolvePostAuthRoute(),
          Future.delayed(const Duration(milliseconds: 1000)),
        ]);
        destination = results.first as String;
      } catch (_) {
        destination = '/onboarding';
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 1000));
      destination = '/onboarding';
    }

    if (mounted) {
      context.go(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize = (constraints.maxWidth * 0.28).clamp(84.0, 108.0);
            return Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EduRiseLogo(
                        size: logoSize,
                        showLabel: false,
                        showTagline: false,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'EduRise',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rise Beyond Limits',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 48,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
