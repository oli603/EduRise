import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExamInstructionsScreen extends StatelessWidget {
  final String year;
  final String subject;
  final String? round;
  final int questionCount;
  final Duration examDuration;

  const ExamInstructionsScreen({
    super.key,
    required this.year,
    required this.subject,
    this.round,
    required this.questionCount,
    required this.examDuration,
  });

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours hours $minutes minutes';
    }

    if (hours > 0) {
      return '$hours hours';
    }

    return '$minutes minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Instructions')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exam title
              Text(
                '$year $subject Exam',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              if (round != null)
                Text(
                  round!,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),

              const SizedBox(height: 28),

              // Warning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Before You Start',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    Text(
                      'Once you start the exam, you should complete it without leaving the exam screen.',
                    ),

                    SizedBox(height: 10),

                    Text(
                      'Make sure you have enough time and a stable internet connection before starting.',
                    ),

                    SizedBox(height: 10),

                    Text(
                      'The countdown timer will start immediately when you begin.',
                    ),

                    SizedBox(height: 10),

                    Text(
                      'Your answers will be submitted when you finish the exam or when the time expires.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Exam information
              const Text(
                'Exam Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              _buildInfoCard(
                icon: Icons.timer_outlined,
                title: 'Duration',
                value: _formatDuration(examDuration),
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.quiz_outlined,
                title: 'Questions',
                value: '$questionCount questions',
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.subject_outlined,
                title: 'Subject',
                value: subject,
              ),

              if (round != null) ...[
                const SizedBox(height: 12),

                _buildInfoCard(
                  icon: Icons.layers_outlined,
                  title: 'Round',
                  value: round!,
                ),
              ],

              const SizedBox(height: 36),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // We will connect the real exam screen here
                    // in the next step.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Exam screen will be connected next.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Start Exam',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: () {
                    context.pop();
                  },
                  child: const Text('Go Back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
