import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_service.dart';
import '../../../core/offline/models/student_profile_record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/edurise_empty_state.dart';
import '../../../core/widgets/edurise_error_state.dart';
import '../../../core/widgets/edurise_loading_state.dart';
import '../../profile/data/profile_service.dart';
import '../widgets/greeting_section.dart';
import '../widgets/hero_action_card.dart';
import '../widgets/learning_progress_section.dart';
import '../widgets/quick_access_section.dart';
import '../widgets/today_challenge_section.dart';
import '../widgets/today_plan_section.dart';

/// The central Home screen for EduRise students.
///
/// Combines personalized student greeting, learning hero call-to-action,
/// live practice progress, today's study plan tasks, daily challenges,
/// and direct Quick Access navigation with full offline support.
class HomeScreen extends StatefulWidget {
  final ProfileService? profileService;

  const HomeScreen({
    super.key,
    this.profileService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<StudentProfileRecord?> _profileFuture;
  late final ProfileService _profileService;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
    _loadProfile();
  }

  void _loadProfile({bool forceRefresh = false}) {
    _profileFuture = _profileService.getProfile(forceRefresh: forceRefresh);
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _loadProfile(forceRefresh: true);
    });
    await _profileFuture;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<StudentProfileRecord?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          // ==================================================
          // 1. CALM BRANDED LOADING STATE
          // ==================================================
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EduRiseLoadingState(
              message: 'Preparing your learning dashboard...',
            );
          }

          // ==================================================
          // 2. ERROR STATE
          // ==================================================
          if (snapshot.hasError) {
            if (RoleService.isAuthorizedAdmin) {
              return _buildAdminPreview(context);
            }

            return EduRiseErrorState(
              title: 'Unable to Load Profile',
              message:
                  'Please check your network connection or verify your profile setup.',
              retryLabel: 'Retry',
              onRetry: () {
                setState(() {
                  _loadProfile(forceRefresh: true);
                });
              },
            );
          }

          // ==================================================
          // 3. PROFILE NOT FOUND / ONBOARDING REQUIRED
          // ==================================================
          final profile = snapshot.data;
          if (profile == null) {
            if (RoleService.isAuthorizedAdmin) {
              return _buildAdminPreview(context);
            }

            return EduRiseEmptyState(
              icon: Icons.school_outlined,
              title: 'Welcome to EduRise!',
              message:
                  'Complete your grade and stream setup to access tailored practice questions and study plans.',
              actionLabel: 'Complete Profile Setup',
              onAction: () => context.go('/profile-setup'),
            );
          }

          // ==================================================
          // 4. LOADED STUDENT DASHBOARD
          // ==================================================
          final fallbackName = Firebase.apps.isNotEmpty
              ? (FirebaseAuth.instance.currentUser?.displayName ?? 'Student')
              : 'Student';
          final studentName = profile.name.trim().isNotEmpty
              ? profile.name.trim()
              : fallbackName;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.primaryForDark
                : AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. PERSONALIZED GREETING & NOTIFICATIONS
                GreetingSection(studentName: studentName),

                const SizedBox(height: AppSpacing.lg),

                // 2. PRIMARY LEARNING HERO ("WHAT TO LEARN NEXT")
                HeroActionCard(profile: profile),

                const SizedBox(height: AppSpacing.xl),

                // 3. REAL-TIME LEARNING PROGRESS SNAPSHOT
                const LearningProgressSection(),

                const SizedBox(height: AppSpacing.xl),

                // 4. TODAY'S STUDY PLAN PREVIEW
                TodayPlanSection(userId: profile.uid),

                const SizedBox(height: AppSpacing.xl),

                // 5. QUICK ACCESS ACTION GRID
                QuickAccessSection(studentGrade: profile.grade),

                const SizedBox(height: AppSpacing.xl),

                // 6. TODAY'S DAILY CHALLENGE
                TodayChallengeSection(userId: profile.uid),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminPreview(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        GreetingSection(
          studentName: RoleService.isFounder
              ? 'Founder (Admin Preview)'
              : 'Admin (Preview)',
        ),
        const SizedBox(height: AppSpacing.lg),
        const QuickAccessSection(),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
