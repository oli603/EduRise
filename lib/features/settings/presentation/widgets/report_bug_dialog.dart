import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../notifications/data/notification_service.dart';

class ReportBugDialog extends StatefulWidget {
  const ReportBugDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const ReportBugDialog(),
    );
  }

  @override
  State<ReportBugDialog> createState() => _ReportBugDialogState();
}

class _ReportBugDialogState extends State<ReportBugDialog> {
  final TextEditingController _detailsController = TextEditingController();
  final Set<String> _selectedCategories = {'App crash/freezes'};
  bool _isSubmitting = false;

  final List<String> _categories = const [
    'App crash/freezes',
    'Login/account issue',
    'Practice issue',
    'Books/download issue',
    'Exam issue',
    'AI/Coach issue',
    'Notification issue',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one problem category.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? SessionManager.currentUid;
    if (uid == null || uid.isEmpty) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to submit a bug report.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final email = user?.email ?? 'student';
    final details = _detailsController.text.trim();

    try {
      for (final category in _selectedCategories) {
        final categorySlug = category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        final docId = 'bug_${categorySlug}_$uid';
        final docRef = FirebaseFirestore.instance.collection('bug_reports').doc(docId);

        final updateData = <String, dynamic>{
          'lastReportedAt': FieldValue.serverTimestamp(),
          if (details.isNotEmpty) 'details': details,
        };

        final createData = <String, dynamic>{
          'id': docId,
          'category': category,
          'uid': uid,
          'email': email,
          'status': 'pending',
          'lastReportedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          if (details.isNotEmpty) 'details': details,
        };

        try {
          // Attempt update first to preserve admin status, admin_notes, and original createdAt
          await docRef.update(updateData);
        } on FirebaseException catch (fe) {
          if (fe.code == 'not-found') {
            await docRef.set(createData);
          } else {
            rethrow;
          }
        } catch (err) {
          if (err.toString().contains('not-found') || err.toString().contains('NOT_FOUND')) {
            await docRef.set(createData);
          } else {
            rethrow;
          }
        }
      }

      // 1. Report is now successfully persisted - Show success to student immediately!
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your report has been submitted to the EduRise team.'),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // 2. Separately attempt admin notification (failure does NOT invalidate report success)
      try {
        await NotificationService().sendStudentAdminAlert(
          title: 'New Student Bug Report',
          body: 'A bug report was submitted for: ${_selectedCategories.join(", ")} by $email.',
          type: 'bug_report',
          metadata: {'categories': _selectedCategories.toList(), 'details': details, 'uid': uid},
        );
      } catch (notifErr) {
        debugPrint('ReportBugDialog: Admin alert creation failed (non-fatal): $notifErr');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit bug report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    return AlertDialog(
      backgroundColor: colors.dialogBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          const Icon(Icons.bug_report_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Text(
            'Report a Problem',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: colors.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select one or more categories that describe the issue:',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            ..._categories.map((cat) {
              final isChecked = _selectedCategories.contains(cat);
              return CheckboxListTile(
                value: isChecked,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: colors.primary,
                title: Text(cat, style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        setState(() {
                          if (val == true) {
                            _selectedCategories.add(cat);
                          } else {
                            _selectedCategories.remove(cat);
                          }
                        });
                      },
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              enabled: !_isSubmitting,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Describe what happened (optional)...',
                hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                filled: true,
                fillColor: colors.surfaceSubtle,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 14),
          label: Text(_isSubmitting ? 'Submitting...' : 'Submit Report'),
        ),
      ],
    );
  }
}
