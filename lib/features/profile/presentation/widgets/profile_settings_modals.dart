import 'package:flutter/material.dart';

import '../../../../core/constants/app_grades.dart';
import '../../../../core/constants/app_subjects.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/profile_service.dart';

class ProfileSettingsModals {
  ProfileSettingsModals._();

  static String _sanitizeError(dynamic error) {
    final str = error.toString();
    if (str.contains('network-request-failed') ||
        str.contains('unavailable') ||
        str.contains('deadline-exceeded') ||
        str.contains('TimeoutException')) {
      return 'Connection timed out. Please check your internet connection.';
    }
    if (str.contains('permission-denied')) {
      return 'Permission denied. Please verify your sign-in session.';
    }
    if (str.contains('cannot change your stream')) {
      return 'Stream is locked and cannot be changed.';
    }
    return 'Unable to update information. Please try again.';
  }

  // ============================================================
  // EDIT PERSONAL INFORMATION DIALOG
  // ============================================================

  static Future<void> showEditProfileDialog(
    BuildContext context, {
    required String currentName,
    required String currentStream,
  }) async {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    bool isSaving = false;
    final profileService = ProfileService();
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.editProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.fullName,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Please enter your name.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: currentStream.toLowerCase().contains('social')
                          ? l10n.socialScience
                          : l10n.naturalScience,
                      decoration: InputDecoration(
                        labelText: l10n.stream,
                        prefixIcon: const Icon(Icons.school_outlined),
                        suffixIcon: const Tooltip(
                          message: 'Stream is locked and cannot be changed.',
                          child: Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                        ),
                        helperText: 'Stream cannot be changed after selection.',
                      ),
                      enabled: false,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          try {
                            await profileService.updatePersonalInfo(
                              name: nameController.text.trim(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Personal information updated successfully.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (dialogContext.mounted) {
                              final msg = _sanitizeError(e);
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(msg), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CHANGE GRADE DIALOG
  // ============================================================

  static Future<void> showSelectGradeDialog(
    BuildContext context, {
    required String currentGrade,
  }) async {
    final grades = EduRiseGrades.all;
    String selectedGrade = currentGrade.isNotEmpty ? currentGrade : EduRiseGrades.grade12;
    bool isSaving = false;
    final profileService = ProfileService();
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.selectGrade, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: grades.map((g) {
                  return RadioListTile<String>(
                    title: Text(g),
                    value: g,
                    groupValue: selectedGrade,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedGrade = val);
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            await profileService.updateGrade(grade: selectedGrade);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Grade updated successfully.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (dialogContext.mounted) {
                              final msg = _sanitizeError(e);
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(msg), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // VIEW SUBJECTS SHEET
  // ============================================================

  static void showSubjectsSheet(
    BuildContext context, {
    required String grade,
    required String stream,
  }) {
    final l10n = AppLocalizations.of(context);
    final subjects = EduRiseSubjects.getProfileSubjects(stream: stream, grade: grade);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${l10n.subjects} • $grade',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Stream: $stream',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: subjects.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = subjects[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.book_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(l10n.close),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  // ============================================================
  // NOTIFICATION SETTINGS SHEET
  // ============================================================

  static void showNotificationSettingsSheet(BuildContext context) {
    final settings = AppSettingsController.instance;
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.notifications,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.pushNotifications, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Receive alerts on exams and updates'),
                      value: settings.pushNotifications,
                      onChanged: (val) => settings.updateNotificationPreferences(push: val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.announcements, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Platform-wide announcements from EduRise team'),
                      value: settings.announcements,
                      onChanged: (val) => settings.updateNotificationPreferences(announcements: val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.paymentAlerts, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Verification status and receipt notifications'),
                      value: settings.paymentAlerts,
                      onChanged: (val) => settings.updateNotificationPreferences(paymentAlerts: val),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(l10n.done(context)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // APPEARANCE DIALOG
  // ============================================================

  static Future<void> showAppearanceDialog(BuildContext context) async {
    final settings = AppSettingsController.instance;
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            final currentMode = settings.themeMode;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = isDark ? AppColors.primaryForDark : AppColors.primary;
            final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
            final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
            final subtitleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

            Widget buildThemeOption({
              required ThemeMode mode,
              required String title,
              required String subtitle,
              required IconData icon,
            }) {
              final isSelected = currentMode == mode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: isSelected
                      ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.08)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      settings.setThemeMode(mode);
                      Navigator.pop(dialogContext);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.15)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: isSelected ? primaryColor : subtitleColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 22,
                            color: isSelected ? primaryColor : subtitleColor.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.palette_outlined, size: 22, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.appearance,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildThemeOption(
                    mode: ThemeMode.system,
                    title: l10n.themeSystem,
                    subtitle: 'Match device system settings',
                    icon: Icons.brightness_auto_rounded,
                  ),
                  buildThemeOption(
                    mode: ThemeMode.light,
                    title: l10n.themeLight,
                    subtitle: 'Crisp, bright daylight interface',
                    icon: Icons.light_mode_rounded,
                  ),
                  buildThemeOption(
                    mode: ThemeMode.dark,
                    title: l10n.themeDark,
                    subtitle: 'Deep, calm slate for low light',
                    icon: Icons.dark_mode_rounded,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(l10n.close, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // LANGUAGE DIALOG (ENGLISH, AMHARIC, AFAAN OROMOO)
  // ============================================================

  static Future<void> showLanguageDialog(BuildContext context) async {
    final settings = AppSettingsController.instance;
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            return AlertDialog(
              title: Text(l10n.language, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: AppLanguage.values.map((lang) {
                  return RadioListTile<AppLanguage>(
                    title: Text(lang.nativeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(lang.englishName),
                    value: lang,
                    groupValue: settings.currentLanguage,
                    onChanged: (selected) {
                      if (selected != null) {
                        settings.setLanguage(selected);
                        Navigator.pop(dialogContext);
                      }
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

extension on AppLocalizations {
  String done(BuildContext context) => translate('close');
}
