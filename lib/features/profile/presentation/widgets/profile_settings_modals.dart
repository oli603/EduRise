import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile_setup/data/profile_service.dart';

class ProfileSettingsModals {
  ProfileSettingsModals._();

  // ============================================================
  // EDIT PERSONAL INFORMATION DIALOG
  // ============================================================

  static Future<void> showEditProfileDialog(
    BuildContext context, {
    required String currentName,
    required String currentStream,
  }) async {
    final nameController = TextEditingController(text: currentName);
    String selectedStream = currentStream.isNotEmpty ? currentStream : 'Natural Science';
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
                    DropdownButtonFormField<String>(
                      initialValue: selectedStream,
                      decoration: InputDecoration(
                        labelText: l10n.stream,
                        prefixIcon: const Icon(Icons.school_outlined),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Natural Science',
                          child: Text(l10n.naturalScience),
                        ),
                        DropdownMenuItem(
                          value: 'Social Science',
                          child: Text(l10n.socialScience),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedStream = val);
                        }
                      },
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
                              stream: selectedStream,
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
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
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
    const grades = ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];
    String selectedGrade = currentGrade.isNotEmpty ? currentGrade : 'Grade 12';
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
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
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
    List<String> subjects;

    final isHigherGrade = grade.contains('11') || grade.contains('12');
    if (isHigherGrade) {
      if (stream.toLowerCase().contains('social')) {
        subjects = const [
          'Mathematics',
          'Economics',
          'Geography',
          'History',
          'English',
          'Civics & Ethical Education',
        ];
      } else {
        subjects = const [
          'Mathematics',
          'Physics',
          'Chemistry',
          'Biology',
          'English',
          'Civics & Ethical Education',
        ];
      }
    } else {
      subjects = const [
        'Mathematics',
        'Physics',
        'Chemistry',
        'Biology',
        'English',
        'Geography',
        'History',
        'Civics',
        'Economics',
      ];
    }

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
            return AlertDialog(
              title: Text(l10n.appearance, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeSystem),
                    subtitle: const Text('Match device settings'),
                    value: ThemeMode.system,
                    groupValue: settings.themeMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        settings.setThemeMode(mode);
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeLight),
                    subtitle: const Text('Clean white background'),
                    value: ThemeMode.light,
                    groupValue: settings.themeMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        settings.setThemeMode(mode);
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeDark),
                    subtitle: const Text('Easy on the eyes in low light'),
                    value: ThemeMode.dark,
                    groupValue: settings.themeMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        settings.setThemeMode(mode);
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                ],
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
