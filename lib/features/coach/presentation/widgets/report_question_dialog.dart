import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/coach_service.dart';

class ReportQuestionDialog extends StatefulWidget {
  final String questionId;
  final String questionType; // 'practice' or 'past_exam'
  final String? subject;
  final String? grade;
  final String? unitOrYear;
  final String? correctAnswer;
  final String? studentAnswer;

  const ReportQuestionDialog({
    super.key,
    required this.questionId,
    required this.questionType,
    this.subject,
    this.grade,
    this.unitOrYear,
    this.correctAnswer,
    this.studentAnswer,
  });

  static Future<void> show(
    BuildContext context, {
    required String questionId,
    required String questionType,
    String? subject,
    String? grade,
    String? unitOrYear,
    String? correctAnswer,
    String? studentAnswer,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ReportQuestionDialog(
        questionId: questionId,
        questionType: questionType,
        subject: subject,
        grade: grade,
        unitOrYear: unitOrYear,
        correctAnswer: correctAnswer,
        studentAnswer: studentAnswer,
      ),
    );
  }

  @override
  State<ReportQuestionDialog> createState() => _ReportQuestionDialogState();
}

class _ReportQuestionDialogState extends State<ReportQuestionDialog> {
  final TextEditingController _detailsController = TextEditingController();
  final Set<String> _selectedReasons = {'wrong_answer'};
  bool _isSubmitting = false;

  final List<Map<String, String>> _reasons = const [
    {'key': 'wrong_answer', 'label': 'Wrong answer'},
    {'key': 'wrong_explanation', 'label': 'Wrong explanation'},
    {'key': 'unclear_question', 'label': 'Question unclear'},
    {'key': 'duplicate', 'label': 'Duplicate question'},
    {'key': 'missing_diagram', 'label': 'Missing image/diagram'},
    {'key': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedReasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one problem reason.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      for (final reason in _selectedReasons) {
        await CoachService.instance.reportQuestion(
          questionId: widget.questionId,
          questionType: widget.questionType,
          reason: reason,
          details: _detailsController.text.trim(),
          subject: widget.subject,
          grade: widget.grade,
          unitOrYear: widget.unitOrYear,
          correctAnswer: widget.correctAnswer,
          studentAnswer: widget.studentAnswer,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your report has been submitted to the EduRise team.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
          const Icon(Icons.flag_outlined, color: AppColors.error, size: 22),
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
              'Select one or more issues with this question:',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            ..._reasons.map((r) {
              final isChecked = _selectedReasons.contains(r['key']);
              return CheckboxListTile(
                value: isChecked,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: colors.primary,
                title: Text(r['label']!, style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        setState(() {
                          if (val == true) {
                            _selectedReasons.add(r['key']!);
                          } else {
                            _selectedReasons.remove(r['key']!);
                          }
                        });
                      },
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              enabled: !_isSubmitting,
              maxLines: 2,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Additional details (optional)...',
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
