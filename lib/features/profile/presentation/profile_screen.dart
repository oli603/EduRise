import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/data/admin_service.dart';
import '../../profile_setup/data/profile_service.dart';
import 'widgets/profile_settings_modals.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = ProfileService();
    final profileStream = profileService.getProfileStream();
    final settings = AppSettingsController.instance;
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.profile,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: profileStream,
            builder: (context, snapshot) {
              final studentData = snapshot.data?.data() ?? {};
              final user = FirebaseAuth.instance.currentUser;

              final name = (studentData['name'] as String?)?.trim().isNotEmpty == true
                  ? studentData['name'] as String
                  : (user?.displayName ?? 'EduRise Student');

              final email = (studentData['email'] as String?) ?? user?.email ?? '';
              final grade = (studentData['grade'] as String?) ?? 'Grade 12';
              final stream = (studentData['stream'] as String?) ?? 'Natural Science';
              final isPaid = studentData['isPaid'] == true || studentData['accessStatus'] == 'active';

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // =====================================================
                  // PROFILE HEADER
                  // =====================================================
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email.isNotEmpty ? email : '$grade • $stream',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // =====================================================
                  // ADMIN DASHBOARD SHORTCUT (IF AUTHORIZED)
                  // =====================================================
                  if (AdminService.isAuthorizedAdmin) ...[
                    Card(
                      color: Colors.indigo.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.indigo.shade200),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.indigo),
                        title: const Text(
                          'Admin Dashboard',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                        subtitle: const Text('Access administrative operations & verification'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.indigo),
                        onTap: () => context.push('/admin'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // =====================================================
                  // ACCOUNT
                  // =====================================================
                  Text(
                    l10n.account,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline_rounded),
                          title: Text(l10n.personalInfo),
                          subtitle: Text(l10n.managePersonalInfo),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ProfileSettingsModals.showEditProfileDialog(
                              context,
                              currentName: name,
                              currentStream: stream,
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(l10n.subscriptionPayment),
                          subtitle: Text(
                            isPaid
                                ? '${l10n.statusActive} • Tap to view'
                                : l10n.subscriptionPaymentSub,
                            style: TextStyle(
                              color: isPaid ? AppColors.success : null,
                              fontWeight: isPaid ? FontWeight.w600 : null,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPaid ? 'PAID' : 'FREE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? AppColors.success : Colors.orange.shade800,
                              ),
                            ),
                          ),
                          onTap: () => context.push('/payment/submit'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =====================================================
                  // LEARNING
                  // =====================================================
                  Text(
                    l10n.learning,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.school_outlined),
                          title: Text(l10n.grade),
                          subtitle: Text('$grade (Tap to change)'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ProfileSettingsModals.showSelectGradeDialog(
                              context,
                              currentGrade: grade,
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(l10n.subjects),
                          subtitle: Text('$stream subjects'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ProfileSettingsModals.showSubjectsSheet(
                              context,
                              grade: grade,
                              stream: stream,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =====================================================
                  // PREFERENCES
                  // =====================================================
                  Text(
                    l10n.preferences,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: Text(l10n.notifications),
                          subtitle: Text(
                            settings.pushNotifications ? 'Enabled' : 'Disabled',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ProfileSettingsModals.showNotificationSettingsSheet(context);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: Text(l10n.appearance),
                          subtitle: Text(
                            settings.themeMode == ThemeMode.light
                                ? l10n.themeLight
                                : (settings.themeMode == ThemeMode.dark
                                    ? l10n.themeDark
                                    : l10n.themeSystem),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ProfileSettingsModals.showAppearanceDialog(context);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.language_outlined),
                          title: Text(l10n.language),
                          subtitle: Text(
                            settings.currentLanguage.nativeName,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ProfileSettingsModals.showLanguageDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // =====================================================
                  // SIGN OUT
                  // =====================================================
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        AdminService.clearCache();
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(l10n.signOut),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
