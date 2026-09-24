import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/profile/data/profile_service.dart';
import '../auth/role_service.dart';
import '../offline/offline_storage_service.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../widgets/edurise_logo.dart';
import 'app_navigation.dart';

/// The central shell scaffold for the EduRise student experience.
///
/// Houses the unified top AppBar, responsive bottom navigation bar,
/// and the comprehensive slide-out AppDrawer while strictly maintaining
/// [StatefulNavigationShell] branch state and back-button lifecycle.
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ============================================================
  // BOTTOM NAVIGATION HANDLER
  // ============================================================

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  // ============================================================
  // APP BAR TITLE & ACTIONS
  // ============================================================

  Widget _buildAppBarTitle(BuildContext context, int currentIndex) {
    final colors = context.eduColors;

    switch (currentIndex) {
      case 0:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EduRiseLogo(size: 26, showLabel: false),
            const SizedBox(width: 8),
            Text(
              'EduRise',
              style: AppTextStyles.headingSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );
      case 1:
        return Text(
          'Practice',
          style: AppTextStyles.headingSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        );
      case 2:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_esports_rounded,
              color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'EduRise Game',
              style: AppTextStyles.headingSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      case 3:
        return Text(
          'Your Progress',
          style: AppTextStyles.headingSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        );
      case 4:
        return Text(
          'Profile',
          style: AppTextStyles.headingSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        );
      default:
        return Text(
          'EduRise',
          style: AppTextStyles.headingSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        );
    }
  }

  List<Widget>? _buildAppBarActions(BuildContext context, int currentIndex) {
    final colors = context.eduColors;
    final iconColor = colors.textSecondary;

    switch (currentIndex) {
      case 0:
        return null;
      case 1:
        return [
          IconButton(
            icon: Icon(Icons.download_rounded, color: iconColor),
            tooltip: 'Downloads',
            onPressed: () => context.push('/downloads'),
          ),
        ];
      case 2:
        return [
          IconButton(
            icon: Icon(Icons.history_edu_rounded, color: iconColor),
            tooltip: 'Past Exams',
            onPressed: () => context.push('/past-entrance-exams'),
          ),
        ];
      case 3:
        return [
          IconButton(
            icon: Icon(Icons.analytics_outlined, color: iconColor),
            tooltip: 'Weak Areas',
            onPressed: () => context.push('/weak-areas'),
          ),
        ];
      case 4:
        return [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: iconColor),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ];
      default:
        return null;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final colors = context.eduColors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. Close drawer if open
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        // 2. Switch back to Home (Tab 0) if on any secondary tab
        if (currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        // 3. On Home with closed drawer, allow minimizing/exiting app
        SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        // ========================================================
        // UNIFIED MODERN APP BAR
        // ========================================================
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          backgroundColor: colors.scaffoldBackground,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: colors.textPrimary),
          title: _buildAppBarTitle(context, currentIndex),
          actions: _buildAppBarActions(context, currentIndex),
        ),

        // ========================================================
        // CURRENT STUDENT SCREEN (INDEXED STACK)
        // ========================================================
        body: widget.navigationShell,

        // ========================================================
        // DEDICATED APP DRAWER
        // ========================================================
        drawer: const AppDrawer(),

        // ========================================================
        // ENHANCED BOTTOM NAVIGATION BAR
        // ========================================================
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.border.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 68,
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: colors.isDark
                  ? AppColors.primaryForDark.withValues(alpha: 0.22)
                  : AppColors.primary.withValues(alpha: 0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTextStyles.labelSmall.copyWith(
                    color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  );
                }
                return AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return IconThemeData(
                    color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                    size: 24,
                  );
                }
                return IconThemeData(
                  color: colors.textSecondary,
                  size: 24,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: _onDestinationSelected,
              animationDuration: AppMotion.normal,
              destinations: AppNavigation.destinations.map((destination) {
                return NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                  tooltip: destination.label,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// DEDICATED APP DRAWER
// ================================================================

class AppDrawer extends StatefulWidget {
  final ProfileService? profileService;

  const AppDrawer({super.key, this.profileService});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late final ProfileService _profileService;
  late final Future<StudentProfileRecord?> _profileFuture;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
    _profileFuture = _profileService.getProfile();
  }

  void _navigateSafely(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.push(route);
  }

  Future<void> _handleSignOut(BuildContext context) async {
    if (_isSigningOut) return;
    setState(() {
      _isSigningOut = true;
    });

    try {
      Navigator.of(context).pop();
      await AuthService().signOut();
      AppRouter.router.go('/login');
    } catch (e) {
      debugPrint('Error during sign out: $e');
      AppRouter.router.go('/login');
    }
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? targetRoute,
    Color? iconColor,
    Widget? trailing,
  }) {
    final colors = context.eduColors;
    final currentRoute = () {
      try {
        return GoRouterState.of(context).uri.path;
      } catch (_) {
        return '';
      }
    }();
    final isSelected = targetRoute != null && currentRoute == targetRoute;

    final resolvedIconColor = isSelected
        ? (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
        : (iconColor ?? (colors.isDark ? AppColors.textPrimaryDark : AppColors.textPrimary));

    final itemBgColor = isSelected
        ? (colors.isDark
            ? AppColors.primaryForDark.withValues(alpha: 0.16)
            : AppColors.primary.withValues(alpha: 0.10))
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: itemBgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: isSelected
                ? BorderSide(
                    color: (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                        .withValues(alpha: 0.3),
                    width: 1,
                  )
                : BorderSide.none,
          ),
          leading: Icon(
            icon,
            size: 22,
            color: resolvedIconColor,
          ),
          title: Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected
                  ? (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                  : colors.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          trailing: trailing ??
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isSelected
                    ? (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                    : colors.textSecondary.withValues(alpha: 0.35),
              ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.eduColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.textSecondary.withValues(alpha: 0.85),
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

    return Drawer(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ==================================================
            // 1. MODERN BRANDED HEADER
            // ==================================================
            _buildDrawerHeader(context),

            const SizedBox(height: 8),

            // ==================================================
            // 2. ADMIN ACCESS (AUTHORIZED ADMIN / FOUNDER ONLY)
            // ==================================================
            if (RoleService.isAuthorizedAdmin) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Material(
                  color: Colors.indigo.withValues(alpha: colors.isDark ? 0.2 : 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(
                      color: Colors.indigo.withValues(alpha: colors.isDark ? 0.4 : 0.2),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.indigo,
                      size: 24,
                    ),
                    title: const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.indigo,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade300),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                    onTap: () => _navigateSafely(context, '/admin'),
                  ),
                ),
              ),
              Divider(color: colors.border.withValues(alpha: 0.6), height: 16),
            ],

            // ==================================================
            // 3. LEARNING
            // ==================================================
            _buildSectionHeader(context, 'LEARNING'),

            _buildDrawerItem(
              context: context,
              icon: Icons.menu_book_rounded,
              title: 'Books',
              targetRoute: '/books',
              onTap: () => _navigateSafely(context, '/books'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.history_edu_rounded,
              title: 'Past Entrance Exams',
              targetRoute: '/past-entrance-exams',
              onTap: () => _navigateSafely(context, '/past-entrance-exams'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.psychology_rounded,
              title: 'Predicted Mock Exam',
              targetRoute: '/predicted-mock-exam',
              onTap: () => _navigateSafely(context, '/predicted-mock-exam'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.emoji_events_rounded,
              title: 'Challenges',
              targetRoute: '/challenges',
              onTap: () => _navigateSafely(context, '/challenges'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.calendar_month_rounded,
              title: 'Study Plan',
              targetRoute: '/study-plan',
              onTap: () => _navigateSafely(context, '/study-plan'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.analytics_rounded,
              title: 'Weak Areas',
              targetRoute: '/weak-areas',
              onTap: () => _navigateSafely(context, '/weak-areas'),
            ),

            Divider(color: colors.border.withValues(alpha: 0.6), height: 20),

            // ==================================================
            // 4. TOOLS
            // ==================================================
            _buildSectionHeader(context, 'TOOLS'),

            _buildDrawerItem(
              context: context,
              icon: Icons.auto_awesome_rounded,
              iconColor: Colors.purple,
              title: 'EduRise Coach',
              targetRoute: '/coach',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: colors.isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.purple,
                  ),
                ),
              ),
              onTap: () => _navigateSafely(context, '/coach'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.download_rounded,
              title: 'Downloads',
              targetRoute: '/downloads',
              onTap: () => _navigateSafely(context, '/downloads'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.notifications_rounded,
              title: 'Notifications',
              targetRoute: '/notifications',
              onTap: () => _navigateSafely(context, '/notifications'),
            ),

            Divider(color: colors.border.withValues(alpha: 0.6), height: 20),

            // ==================================================
            // 5. ACCOUNT
            // ==================================================
            _buildSectionHeader(context, 'ACCOUNT'),

            _buildDrawerItem(
              context: context,
              icon: Icons.receipt_long_rounded,
              title: 'Subscription / Payment',
              targetRoute: '/payment/submit',
              onTap: () => _navigateSafely(context, '/payment/submit'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.settings_rounded,
              title: 'Settings',
              targetRoute: '/settings',
              onTap: () => _navigateSafely(context, '/settings'),
            ),

            _buildDrawerItem(
              context: context,
              icon: Icons.info_outline_rounded,
              title: 'About EduRise',
              targetRoute: '/about',
              onTap: () => _navigateSafely(context, '/about'),
            ),

            Divider(color: colors.border.withValues(alpha: 0.6), height: 20),

            // ==================================================
            // 6. SIGN OUT
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  leading: _isSigningOut
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                  title: Text(
                    _isSigningOut ? 'Signing out...' : 'Sign Out',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: _isSigningOut ? null : () => _handleSignOut(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EduRiseLogo.small(
                      showLabel: true,
                      labelColor: colors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rise Beyond Limits • v1.0.0',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: colors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DRAWER HEADER
  // ============================================================

  Widget _buildDrawerHeader(BuildContext context) {
    final colors = context.eduColors;

    return FutureBuilder<StudentProfileRecord?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;

        final displayName = (profile?.name.trim().isNotEmpty == true)
            ? profile!.name.trim()
            : 'EduRise Student';

        final email = (profile?.email?.isNotEmpty == true)
            ? profile!.email!
            : 'student@edurise.edu';

        final grade = (profile?.grade.isNotEmpty == true)
            ? profile!.grade
            : 'Grade 12';

        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 16,
            20,
            16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.isDark
                  ? [
                      const Color(0xFF1E293B),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        displayName.trim().isNotEmpty
                            ? displayName.trim()[0].toUpperCase()
                            : 'E',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      grade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
