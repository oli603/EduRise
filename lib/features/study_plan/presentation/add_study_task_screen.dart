import 'package:edurise/core/theme/app_colors.dart';
import 'package:edurise/core/theme/app_radius.dart';
import 'package:edurise/core/theme/app_spacing.dart';
import 'package:edurise/core/theme/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/study_plan_service.dart';
import '../data/study_task_model.dart';

class AddStudyTaskScreen extends StatefulWidget {
  const AddStudyTaskScreen({super.key});

  @override
  State<AddStudyTaskScreen> createState() => _AddStudyTaskScreenState();
}

class _AddStudyTaskScreenState extends State<AddStudyTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  final StudyPlanService _studyPlanService = StudyPlanService();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _unitNumberController = TextEditingController();

  final TextEditingController _unitNameController = TextEditingController();

  final TextEditingController _targetCountController = TextEditingController();

  String _grade = 'Grade 12';
  String _subject = 'Mathematics';
  String _taskType = 'practice';

  DateTime _scheduledDate = DateTime.now();

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _unitNumberController.dispose();
    _unitNameController.dispose();
    _targetCountController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATE
  // ---------------------------------------------------------------------------

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _scheduledDate = selectedDate;
    });
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _saveTask() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first.')));

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final task = StudyTask(
        id: '',
        userId: user.uid,
        title: _titleController.text.trim(),
        grade: _grade,
        subject: _subject,
        unitNumber: _unitNumberController.text.trim().isEmpty
            ? null
            : int.tryParse(_unitNumberController.text.trim()),
        unitName: _unitNameController.text.trim().isEmpty
            ? null
            : _unitNameController.text.trim(),
        taskType: _taskType,
        targetCount: _targetCountController.text.trim().isEmpty
            ? null
            : int.tryParse(_targetCountController.text.trim()),
        scheduledDate: _scheduledDate,
        isCompleted: false,
        createdAt: null,
      );

      await _studyPlanService.addTask(task);

      if (!mounted) return;

      context.pop(true);
    } catch (e) {
      debugPrint('ADD STUDY TASK ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the study task. Please try again.'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Create Study Task',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            _buildHeader(),

            const SizedBox(height: AppSpacing.xl),

            _buildSectionTitle(
              'What do you want to study?',
              Icons.edit_note_rounded,
            ),

            const SizedBox(height: AppSpacing.md),

            _buildTitleField(),

            const SizedBox(height: AppSpacing.xl),

            _buildSectionTitle('Study information', Icons.school_rounded),

            const SizedBox(height: AppSpacing.md),

            _buildGradeDropdown(),

            const SizedBox(height: AppSpacing.md),

            _buildSubjectDropdown(),

            const SizedBox(height: AppSpacing.md),

            _buildUnitNumberField(),

            const SizedBox(height: AppSpacing.md),

            _buildUnitNameField(),

            const SizedBox(height: AppSpacing.xl),

            _buildSectionTitle(
              'How will you study?',
              Icons.auto_awesome_rounded,
            ),

            const SizedBox(height: AppSpacing.md),

            _buildTaskTypeSelector(),

            if (_showTargetCount) ...[
              const SizedBox(height: AppSpacing.md),
              _buildTargetCountField(),
            ],

            const SizedBox(height: AppSpacing.xl),

            _buildSectionTitle(
              'When will you study?',
              Icons.calendar_month_rounded,
            ),

            const SizedBox(height: AppSpacing.md),

            _buildDateSelector(),

            const SizedBox(height: AppSpacing.xl),

            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.add_task_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build your study plan',
                  style: AppTextStyles.heading2.copyWith(fontSize: 18),
                ),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  'Create a clear task and stay consistent.',
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION TITLE
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),

        const SizedBox(width: AppSpacing.sm),

        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TITLE
  // ---------------------------------------------------------------------------

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Task title',
        hintText: 'Example: Practice Mathematics questions',
        prefixIcon: Icon(Icons.title_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a task title.';
        }

        if (value.trim().length < 3) {
          return 'Task title is too short.';
        }

        return null;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // GRADE
  // ---------------------------------------------------------------------------

  Widget _buildGradeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _grade,
      decoration: const InputDecoration(
        labelText: 'Grade',
        prefixIcon: Icon(Icons.school_outlined),
      ),
      items: const [
        DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
        DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10')),
        DropdownMenuItem(value: 'Grade 11', child: Text('Grade 11')),
        DropdownMenuItem(value: 'Grade 12', child: Text('Grade 12')),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _grade = value;
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SUBJECT
  // ---------------------------------------------------------------------------

  Widget _buildSubjectDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _subject,
      decoration: const InputDecoration(
        labelText: 'Subject',
        prefixIcon: Icon(Icons.menu_book_outlined),
      ),
      items: const [
        DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
        DropdownMenuItem(value: 'Physics', child: Text('Physics')),
        DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry')),
        DropdownMenuItem(value: 'Biology', child: Text('Biology')),
        DropdownMenuItem(value: 'English', child: Text('English')),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _subject = value;
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UNIT NUMBER
  // ---------------------------------------------------------------------------

  Widget _buildUnitNumberField() {
    return TextFormField(
      controller: _unitNumberController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Unit number',
        hintText: 'Example: 1',
        prefixIcon: Icon(Icons.format_list_numbered_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }

        final number = int.tryParse(value.trim());

        if (number == null || number <= 0) {
          return 'Enter a valid unit number.';
        }

        return null;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UNIT NAME
  // ---------------------------------------------------------------------------

  Widget _buildUnitNameField() {
    return TextFormField(
      controller: _unitNameController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Unit name',
        hintText: 'Example: Algebra',
        prefixIcon: Icon(Icons.bookmark_outline_rounded),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TASK TYPE
  // ---------------------------------------------------------------------------

  Widget _buildTaskTypeSelector() {
    return Column(
      children: [
        _buildTaskTypeOption(
          value: 'practice',
          title: 'Practice',
          subtitle: 'Solve questions',
          icon: Icons.edit_note_rounded,
        ),

        const SizedBox(height: AppSpacing.sm),

        _buildTaskTypeOption(
          value: 'reading',
          title: 'Reading',
          subtitle: 'Read and understand',
          icon: Icons.menu_book_rounded,
        ),

        const SizedBox(height: AppSpacing.sm),

        _buildTaskTypeOption(
          value: 'review',
          title: 'Review',
          subtitle: 'Review what you learned',
          icon: Icons.refresh_rounded,
        ),

        const SizedBox(height: AppSpacing.sm),

        _buildTaskTypeOption(
          value: 'challenge',
          title: 'Challenge',
          subtitle: 'Push yourself further',
          icon: Icons.emoji_events_outlined,
        ),
      ],
    );
  }

  Widget _buildTaskTypeOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _taskType == value;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () {
        setState(() {
          _taskType = value;

          if (!_showTargetCount) {
            _targetCountController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              // ignore: deprecated_member_use
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    // ignore: deprecated_member_use
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.white : AppColors.primary,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: AppColors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TARGET COUNT
  // ---------------------------------------------------------------------------

  bool get _showTargetCount {
    return _taskType == 'practice' || _taskType == 'challenge';
  }

  Widget _buildTargetCountField() {
    return TextFormField(
      controller: _targetCountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Target count',
        hintText: _taskType == 'practice'
            ? 'Example: 20 questions'
            : 'Example: 10 questions',
        prefixIcon: const Icon(Icons.track_changes_rounded),
        suffixText: 'questions',
      ),
      validator: (value) {
        if (!_showTargetCount) {
          return null;
        }

        if (value == null || value.trim().isEmpty) {
          return 'Enter your target.';
        }

        final number = int.tryParse(value.trim());

        if (number == null || number <= 0) {
          return 'Enter a valid target.';
        }

        return null;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DATE
  // ---------------------------------------------------------------------------

  Widget _buildDateSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scheduled date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    _formatDate(_scheduledDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveTask,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              )
            : const Icon(Icons.check_rounded),
        label: Text(_isSaving ? 'Creating task...' : 'Create Study Task'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DATE FORMAT
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${weekdays[date.weekday - 1]}, '
        '${months[date.month - 1]} ${date.day}, '
        '${date.year}';
  }
}
