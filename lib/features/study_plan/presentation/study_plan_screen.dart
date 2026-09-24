import 'package:edurise/core/theme/app_colors.dart';
import 'package:edurise/core/theme/app_radius.dart';
import 'package:edurise/core/theme/app_spacing.dart';
import 'package:edurise/core/theme/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/study_plan_service.dart';
import '../data/study_task_model.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  final StudyPlanService _studyPlanService = StudyPlanService();

  List<StudyTask> _tasks = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTodayTasks();
  }

  // ---------------------------------------------------------------------------
  // LOAD TODAY'S TASKS
  // ---------------------------------------------------------------------------

  Future<void> _loadTodayTasks() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage = 'Please sign in to view your study plan.';
        });

        return;
      }

      final tasks = await _studyPlanService.getTasksForDate(
        userId: user.uid,
        date: DateTime.now(),
      );

      if (!mounted) return;

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('STUDY PLAN ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load your study plan.\nPlease try again.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // COMPLETE / UNCOMPLETE TASK
  // ---------------------------------------------------------------------------

  Future<void> _toggleTask(StudyTask task) async {
    try {
      await _studyPlanService.setTaskCompleted(
        taskId: task.id,
        completed: !task.isCompleted,
      );

      await _loadTodayTasks();
    } catch (e) {
      debugPrint('TOGGLE STUDY TASK ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the task.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE TASK
  // ---------------------------------------------------------------------------

  Future<void> _deleteTask(StudyTask task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text('Are you sure you want to delete "${task.title}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _studyPlanService.deleteTask(task.id);

      await _loadTodayTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Study task deleted.')));
    } catch (e) {
      debugPrint('DELETE STUDY TASK ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the task.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // OPEN ADD TASK SCREEN
  // ---------------------------------------------------------------------------

  Future<void> _openAddTaskScreen() async {
    final result = await context.push<bool>('/add-study-task');

    if (result == true) {
      await _loadTodayTasks();
    }
  }

  Future<void> _openEditTaskScreen(StudyTask task) async {
    final result = await context.push<bool>('/add-study-task', extra: task);

    if (result == true) {
      await _loadTodayTasks();
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,

      appBar: AppBar(
        title: Text(
          'Study Plan',
          style: AppTextStyles.headingMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: _buildBody(),

      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTaskScreen,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        tooltip: 'Add study task',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BODY
  // ---------------------------------------------------------------------------

  Widget _buildBody() {
    final colors = context.eduColors;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_tasks.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadTodayTasks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          100,
        ),
        children: [
          _buildDateHeader(),

          const SizedBox(height: AppSpacing.lg),

          _buildProgressCard(),

          const SizedBox(height: AppSpacing.xl),

          Text(
            "Today's Tasks",
            style: AppTextStyles.headingMedium.copyWith(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          ..._tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildTaskCard(task),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DATE HEADER
  // ---------------------------------------------------------------------------

  Widget _buildDateHeader() {
    final colors = context.eduColors;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatFullDate(now),
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        Text(
          'Your study plan for today',
          style: AppTextStyles.headingLarge.copyWith(
            color: colors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PROGRESS CARD
  // ---------------------------------------------------------------------------

  Widget _buildProgressCard() {
    final total = _tasks.length;

    final completed = _tasks.where((task) => task.isCompleted).length;

    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                  // ignore: deprecated_member_use
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: AppColors.white,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Progress",
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '$completed of $total tasks completed',
                      style: TextStyle(
                        color:
                            // ignore: deprecated_member_use
                            AppColors.white.withOpacity(0.80),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  // ignore: deprecated_member_use
                  AppColors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TASK CARD
  // ---------------------------------------------------------------------------

  Widget _buildTaskCard(StudyTask task) {
    final colors = context.eduColors;
    final taskColor = _taskTypeColor(task.taskType);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: task.isCompleted
              ? AppColors.success.withValues(alpha: 0.35)
              : colors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTaskCheckbox(task),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: task.isCompleted
                                ? colors.textSecondary
                                : colors.textPrimary,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),

                      _buildTaskTypeBadge(task.taskType, taskColor),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: task.isCompleted
                          ? colors.textSecondary
                          : colors.textPrimary,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  _buildTaskDetails(task),

                  if (task.isCompleted) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.xs),

            _buildTaskMenu(task),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TASK CHECKBOX
  // ---------------------------------------------------------------------------

  Widget _buildTaskCheckbox(StudyTask task) {
    final colors = context.eduColors;

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () => _toggleTask(task),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: task.isCompleted ? AppColors.success : Colors.transparent,
          border: Border.all(
            color: task.isCompleted ? AppColors.success : colors.border,
            width: 2,
          ),
        ),
        child: task.isCompleted
            ? const Icon(Icons.check_rounded, size: 18, color: AppColors.white)
            : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TASK DETAILS
  // ---------------------------------------------------------------------------

  Widget _buildTaskDetails(StudyTask task) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        if (task.unitName != null || task.unitNumber != null)
          _buildDetailItem(
            icon: Icons.menu_book_rounded,
            text: _buildUnitText(task),
          ),

        if (task.targetCount != null)
          _buildDetailItem(
            icon: Icons.track_changes_rounded,
            text: '${task.targetCount} target',
          ),

        _buildDetailItem(icon: Icons.school_rounded, text: task.grade),
      ],
    );
  }

  String _buildUnitText(StudyTask task) {
    if (task.unitNumber != null && task.unitName != null) {
      return 'Unit ${task.unitNumber} • ${task.unitName}';
    }

    if (task.unitNumber != null) {
      return 'Unit ${task.unitNumber}';
    }

    return task.unitName!;
  }

  // ---------------------------------------------------------------------------
  // TASK TYPE BADGE
  // ---------------------------------------------------------------------------

  Widget _buildTaskTypeBadge(String taskType, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        _formatTaskType(taskType),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DETAIL ITEM
  // ---------------------------------------------------------------------------

  Widget _buildDetailItem({required IconData icon, required String text}) {
    final colors = context.eduColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),

        const SizedBox(width: 4),

        Text(
          text,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TASK MENU
  // ---------------------------------------------------------------------------

  Widget _buildTaskMenu(StudyTask task) {
    final colors = context.eduColors;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
      tooltip: 'Task options',
      onSelected: (value) {
        if (value == 'edit') {
          _openEditTaskScreen(task);
        } else if (value == 'delete') {
          _deleteTask(task);
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: AppColors.error),
                SizedBox(width: 10),
                Text('Delete'),
              ],
            ),
          ),
        ];
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    final colors = context.eduColors;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadTodayTasks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: 70),

          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: colors.isDark
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_note_rounded,
              size: 44,
              color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Your day is clear',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingLarge.copyWith(
              fontSize: 22,
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'You have no study tasks scheduled for today. '
            'Create one and start making progress.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Center(
            child: ElevatedButton.icon(
              onPressed: _openAddTaskScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Study Task'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR STATE
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() {
    final colors = context.eduColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: AppColors.error,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium.copyWith(
                fontSize: 20,
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            ElevatedButton(
              onPressed: _loadTodayTasks,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _formatFullDate(DateTime date) {
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
        '${months[date.month - 1]} ${date.day}';
  }

  String _formatTaskType(String taskType) {
    switch (taskType.toLowerCase()) {
      case 'practice':
        return 'Practice';

      case 'reading':
        return 'Reading';

      case 'review':
        return 'Review';

      case 'challenge':
        return 'Challenge';

      default:
        return taskType;
    }
  }

  Color _taskTypeColor(String taskType) {
    switch (taskType.toLowerCase()) {
      case 'practice':
        return AppColors.primary;

      case 'reading':
        return const Color(0xFF7C3AED);

      case 'review':
        return AppColors.warning;

      case 'challenge':
        return AppColors.error;

      default:
        return AppColors.textSecondary;
    }
  }
}
