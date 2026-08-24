import 'package:flutter/material.dart';

import '../data/progress_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ProgressService _progressService = ProgressService();

  bool _isLoading = true;
  String? _errorMessage;

  int _totalQuestions = 0;
  int _correctAnswers = 0;
  int _incorrectAnswers = 0;
  int _accuracy = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _progressService.getUserResults();

      final total = results.length;

      final correct = results.where((result) {
        return result['isCorrect'] == true;
      }).length;

      final incorrect = results.where((result) {
        return result['isCorrect'] == false;
      }).length;

      final accuracy = total == 0 ? 0 : ((correct / total) * 100).round();

      if (!mounted) return;

      setState(() {
        _totalQuestions = total;
        _correctAnswers = correct;
        _incorrectAnswers = incorrect;
        _accuracy = accuracy;
        _isLoading = false;
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _buildProgressContent(),
    );
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
    return RefreshIndicator(
      onRefresh: _loadProgress,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your Progress',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            'Keep practicing and track your improvement.',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 24),

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

          const Text(
            'Practice Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Column(
        children: [
          const Text(
            'Overall Accuracy',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),

          const SizedBox(height: 10),

          Text(
            '$_accuracy%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _getProgressMessage(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),

          const SizedBox(height: 12),

          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_totalQuestions == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.insights_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Complete some practice questions to start building your progress.',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questions Performance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _accuracy / 100,
              minHeight: 10,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'You answered $_correctAnswers out of '
            '$_totalQuestions questions correctly.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 50),
          SizedBox(height: 12),
          Text(
            'Your progress will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Start practicing to see your performance.',
            textAlign: TextAlign.center,
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
