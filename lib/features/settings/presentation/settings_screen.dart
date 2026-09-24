import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../about/presentation/about_screen.dart';
import '../../profile/presentation/widgets/profile_settings_modals.dart';
import 'widgets/report_bug_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.settings,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // =====================================================
              // ACCOUNT
              // =====================================================
              Text(
                l10n.account,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(l10n.profile),
                  subtitle: const Text('View and manage your student profile'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/profile'),
                ),
              ),
              const SizedBox(height: 24),

              // =====================================================
              // PREFERENCES (SHARED WITH PROFILE)
              // =====================================================
              Text(
                l10n.preferences,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 24),

              // =====================================================
              // SUPPORT
              // =====================================================
              Text(
                l10n.support,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.help_outline_rounded),
                      title: Text(l10n.helpSupport),
                      subtitle: const Text('Get assistance from the EduRise support team'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSupportModal(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      title: Text(l10n.reportProblem),
                      subtitle: const Text('Let us know if you encounter any issue'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showReportProblemModal(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // =====================================================
              // ABOUT
              // =====================================================
              Text(
                l10n.about,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: Text(l10n.aboutEduRise),
                      subtitle: const Text('Platform mission, offerings, and goals'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/about'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(l10n.privacyPolicy),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showLegalModal(
                        context,
                        title: l10n.privacyPolicy,
                        content:
                            'EduRise respects your privacy. We store and protect your personal information, learning progress, and payment verification records exclusively to provide and improve your educational experience on our platform.\n\nFor questions about your data, contact privacy@edurise.et.',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(l10n.termsService),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showLegalModal(
                        context,
                        title: l10n.termsService,
                        content:
                            'By using EduRise, you agree to access educational materials solely for personal academic learning and examination preparation. Sharing or redistributing premium questions and book materials outside the platform is prohibited.\n\nOfficial terms of service are governed under the laws of Ethiopia.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // App Version
              Center(
                child: Text(
                  '${l10n.version} ${AboutEduRiseScreen.appVersion}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  static void _showSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('EduRise Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Our support team is available to assist you with payments, account access, and learning inquiries.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                child: Column(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.email_outlined, color: AppColors.primary),
                      title: Text('Email Support'),
                      subtitle: Text('support@edurise.et'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.send_rounded, color: AppColors.primary),
                      title: Text('Telegram Support Channel'),
                      subtitle: Text('@EduRiseSupport'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showReportProblemModal(BuildContext context) {
    ReportBugDialog.show(context);
  }

  static void _showLegalModal(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
