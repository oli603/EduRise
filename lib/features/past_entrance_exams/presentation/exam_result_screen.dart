import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/past_exam_model.dart';
import 'exam_review_screen.dart';
import 'exam_screen.dart';

class ExamResultScreen extends StatefulWidget {
  final PastExam exam;
  final Map<int, String> selectedAnswers;
  final int correctAnswers;
  final int totalQuestions;
  final int percentage;
  final int timeSpentSeconds;
  final int durationMinutes;
  final bool isAutoSubmitted;
  final String? localResultId;

  const ExamResultScreen({
    super.key,
    required this.exam,
    required this.selectedAnswers,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
    required this.timeSpentSeconds,
    required this.durationMinutes,
    this.isAutoSubmitted = false,
    this.localResultId,
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  bool _isSyncing = false;
  bool _isSynced = false;

  @override
  void initState() {
    super.initState();
    _checkInitialSync();
  }

  Future<void> _checkInitialSync() async {
    final isOnline = ConnectivityService().isOnline;
    if (isOnline) {
      _triggerSync();
    }
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await SyncService().syncAll();
      if (mounted) {
        setState(() {
          _isSynced = true;
          _isSyncing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  String _formatTimeSpent(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remMins = mins % 60;
      return '${hours}h ${remMins}m ${secs}s';
    }
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final incorrectAnswers = widget.totalQuestions - widget.correctAnswers;
    final unansweredCount = widget.totalQuestions - widget.selectedAnswers.length;

    final isPassed = widget.percentage >= 50;

    void returnToPastExams() {
      if (context.canPop()) {
        context.pop();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/past-entrance-exams');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        returnToPastExams();
      },
      child: Scaffold(
        backgroundColor: colors.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Exam Result'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to Past Entrance Exams',
            onPressed: returnToPastExams,
          ),
        ),
        body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.isAutoSubmitted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.timer_off_outlined, color: AppColors.warning, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Exam was submitted automatically because time expired.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Trophy / Medal Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isPassed
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                    size: 48,
                    color: isPassed ? AppColors.success : AppColors.error,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                isPassed ? 'Exam Completed!' : 'Keep Practicing!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '${widget.exam.year} EC ${widget.exam.subject} (${widget.exam.stream.toUpperCase()})',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),

              const SizedBox(height: 20),

              // Score Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.isDark
                          ? Colors.black.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${widget.percentage}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: isPassed ? AppColors.success : colors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.correctAnswers} out of ${widget.totalQuestions} Questions Correct',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Time spent and sync status row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Time Spent',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimeSpent(widget.timeSpentSeconds),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 30, color: AppColors.border),
                        Column(
                          children: [
                            const Text(
                              'Cloud Sync',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isSynced ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                                  size: 15,
                                  color: _isSynced ? AppColors.success : AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isSynced ? 'Synced' : 'Saved Offline',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _isSynced ? AppColors.success : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Breakdown Stat Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      title: 'Correct',
                      value: '${widget.correctAnswers}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatItem(
                      title: 'Incorrect',
                      value: '$incorrectAnswers',
                      icon: Icons.cancel_outlined,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatItem(
                      title: 'Unanswered',
                      value: '$unansweredCount',
                      icon: Icons.help_outline,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExamReviewScreen(
                              exam: widget.exam,
                              selectedAnswers: widget.selectedAnswers,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Review Answers'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ExamScreen(
                              year: widget.exam.year,
                              stream: widget.exam.stream,
                              subject: widget.exam.subject,
                              durationMinutes: widget.durationMinutes,
                              examId: widget.exam.id,
                              exam: widget.exam,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Retake Exam'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: returnToPastExams,
                  icon: const Icon(Icons.history_edu_rounded),
                  label: const Text('Back to Past Entrance Exams'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colors = context.eduColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
