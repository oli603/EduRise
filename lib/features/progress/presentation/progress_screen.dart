import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/progress_service.dart';

class ProgressScreen extends StatefulWidget {
  final ProgressService? progressService;

  const ProgressScreen({super.key, this.progressService});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final ProgressService _progressService;
  StreamSubscription<List<Map<String, dynamic>>>? _resultsSubscription;

  bool _isLoading = true;
  String? _errorMessage;

  int _totalQuestions = 0;
  int _correctAnswers = 0;
  int _incorrectAnswers = 0;
  int _accuracy = 0;

  @override
  void initState() {
    super.initState();
    _progressService = widget.progressService ?? ProgressService();
    _subscribeToProgress();
  }

  @override
  void dispose() {
    _resultsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToProgress() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _resultsSubscription = _progressService.getUserResultsStream().listen(
      (results) {
        _applyResults(results);
      },
      onError: (e) {
        debugPrint('PROGRESS STREAM ERROR: $e');
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Unable to load your progress.\n\n$e';
          _isLoading = false;
        });
      },
    );
  }

  void _applyResults(List<Map<String, dynamic>> results) {
    int totalQuestions = 0;
    int correctAnswers = 0;
    int wrongAnswers = 0;

    for (final result in results) {
      final tQ = (result['totalQuestions'] as num?)?.toInt() ?? 0;
      final cA = (result['correctAnswers'] as num?)?.toInt() ?? 0;
      final wA = (result['wrongAnswers'] as num?)?.toInt() ??
          (tQ >= cA ? (tQ - cA) : 0);

      totalQuestions += tQ;
      correctAnswers += cA;
      wrongAnswers += wA;
    }

    final accuracy = totalQuestions == 0
        ? 0
        : ((correctAnswers / totalQuestions) * 100).round();

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

    // Required debug logs from Part 9
    debugPrint('=== PROGRESS CALCULATION ===');
    debugPrint('User ID: $userId');
    debugPrint('Total practice sessions: ${results.length}');
    debugPrint('Sum total questions: $totalQuestions');
    debugPrint('Sum correct answers: $correctAnswers');
    debugPrint('Sum wrong answers: $wrongAnswers');
    debugPrint('Overall accuracy: $accuracy%');
    debugPrint('============================');


    if (!mounted) return;

    setState(() {
      _totalQuestions = totalQuestions;
      _correctAnswers = correctAnswers;
      _incorrectAnswers = wrongAnswers;
      _accuracy = accuracy;
      _isLoading = false;
    });
  }

  Future<void> _loadProgress() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _progressService.getUserResults();
      _applyResults(results);
    } catch (e) {
      debugPrint('PROGRESS ERROR: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to load your progress.\n\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    return _buildProgressContent();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadProgress,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressContent() {
    final colors = context.eduColors;

    return RefreshIndicator(
      onRefresh: _loadProgress,
      color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Keep practicing and track your improvement.',
            style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: 20),

          _buildAccuracyCard(),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Questions',
                  value: '$_totalQuestions',
                  icon: Icons.quiz_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Correct',
                  value: '$_correctAnswers',
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Incorrect',
                  value: '$_incorrectAnswers',
                  icon: Icons.cancel_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Accuracy',
                  value: '$_accuracy%',
                  icon: Icons.track_changes_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Text(
            'Practice Summary',
            style: AppTextStyles.headingMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _buildSummaryCard(),

          const SizedBox(height: 24),

          if (_totalQuestions == 0) _buildEmptyState(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAccuracyCard() {
    final colors = context.eduColors;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1D4ED8), const Color(0xFF2563EB)],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Overall Accuracy',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$_accuracy%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getProgressMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final colors = context.eduColors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 26,
            color: colors.isDark ? AppColors.primaryForDark : AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final colors = context.eduColors;

    if (_totalQuestions == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_outlined, color: colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Complete some practice questions to start building your progress.',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Questions Performance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _accuracy / 100,
              minHeight: 10,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                colors.isDark ? AppColors.primaryForDark : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You answered $_correctAnswers out of '
            '$_totalQuestions questions correctly.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.eduColors;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 50, color: colors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Your progress will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start practicing to see your performance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _getProgressMessage() {
    if (_totalQuestions == 0) {
      return 'Start practicing to build your progress.';
    }

    if (_accuracy >= 90) {
      return 'Excellent work! Keep it up.';
    }

    if (_accuracy >= 75) {
      return 'Great progress! Keep improving.';
    }

    if (_accuracy >= 50) {
      return 'Good start. More practice will help.';
    }

    return 'Keep practicing. You can improve!';
  }
}
