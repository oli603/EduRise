import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:edurise/core/theme/app_colors.dart';
import 'package:edurise/core/theme/app_radius.dart';
import 'package:edurise/core/theme/app_spacing.dart';
import 'package:edurise/core/theme/app_text_styles.dart';
import 'package:edurise/features/study_plan/data/study_plan_service.dart';
import 'package:edurise/features/study_plan/data/study_task_model.dart';

/// Compact Today's Plan section on the EduRise Home screen.
///
/// Fetches today's tasks for the authenticated user and displays completion
/// status with quick navigation to the full Study Plan calendar.
class TodayPlanSection extends StatefulWidget {
  final String userId;
  final StudyPlanService? studyPlanService;

  const TodayPlanSection({
    super.key,
    required this.userId,
    this.studyPlanService,
  });

  @override
  State<TodayPlanSection> createState() => _TodayPlanSectionState();
}

class _TodayPlanSectionState extends State<TodayPlanSection> {
  StudyPlanService? _service;
  late Future<List<StudyTask>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    if (widget.studyPlanService != null) {
      _service = widget.studyPlanService;
    } else if (Firebase.apps.isNotEmpty) {
      try {
        _service = StudyPlanService();
      } catch (_) {}
    }
    _loadTasks();
  }

  void _loadTasks() {
    if (_service == null) {
      _tasksFuture = Future.value(const []);
      return;
    }
    try {
      _tasksFuture = _service!.getTasksForDate(
        userId: widget.userId,
        date: DateTime.now(),
      );
    } catch (_) {
      _tasksFuture = Future.value(const []);
    }
  }

  Future<void> _toggleTask(StudyTask task) async {
    if (_service == null) return;
    final updatedCompleted = !task.isCompleted;
    await _service!.setTaskCompleted(
      taskId: task.id,
      completed: updatedCompleted,
    );
    if (mounted) {
      setState(() {
        _loadTasks();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: BuildContext == dynamic ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // ====================================================
        // SECTION HEADER
        // ====================================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Plan",
              style: AppTextStyles.headingMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/study-plan'),
              style: TextButton.styleFrom(
                foregroundColor: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Calendar', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // ====================================================
        // TASKS LIST OR EMPTY CARD
        // ====================================================
        FutureBuilder<List<StudyTask>>(
          future: _tasksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 70,
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.border),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final tasks = snapshot.data ?? [];

            if (tasks.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (colors.isDark ? AppColors.primaryForDark : AppColors.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No study tasks scheduled for today',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set clear study goals to build a daily learning habit.',
                            style: AppTextStyles.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () => context.push('/study-plan'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Plan', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }

            // Display up to 3 tasks
            final displayTasks = tasks.take(3).toList();

            return Container(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < displayTasks.length; i++) ...[
                    if (i > 0)
                      Divider(color: colors.border.withValues(alpha: 0.6), height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: IconButton(
                        icon: Icon(
                          displayTasks[i].isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: displayTasks[i].isCompleted
                              ? AppColors.success
                              : colors.textSecondary,
                          size: 22,
                        ),
                        onPressed: () => _toggleTask(displayTasks[i]),
                      ),
                      title: Text(
                        displayTasks[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          decoration: displayTasks[i].isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        displayTasks[i].subject,
                        style: AppTextStyles.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: displayTasks[i].isCompleted
                              ? AppColors.success.withValues(alpha: 0.12)
                              : colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          displayTasks[i].isCompleted ? 'Done' : 'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: displayTasks[i].isCompleted
                                ? AppColors.success
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
