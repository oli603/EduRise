import 'package:flutter/material.dart';

import '../data/question_model.dart';
import 'practice_review_screen.dart';
import 'practice_screen.dart';

class PracticeResultScreen extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final List<Question> mistakes;
  final Map<int, String> selectedAnswers;
  final List<Question> questions;
  final String grade;
  final String subject;
  final String stream;
  final int unitNumber;
  final String unitName;
  final int? examYear;
  final int? questionCount;
  final int percentage;

  const PracticeResultScreen({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.mistakes,
    required this.selectedAnswers,
    required this.questions,
    required this.stream,
    required this.grade,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
    this.examYear,
    this.questionCount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final incorrectAnswers = totalQuestions - correctAnswers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Result'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.emoji_events_rounded, size: 70),
              const SizedBox(height: 16),
              const Text(
                'Practice Complete!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$unitName • $subject • $grade${examYear != null && examYear! > 0 ? ' • $examYear EC' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$correctAnswers / $totalQuestions correct',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ResultStat(
                      title: 'Correct',
                      value: '$correctAnswers',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResultStat(
                      title: 'Incorrect',
                      value: '$incorrectAnswers',
                      icon: Icons.cancel,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons: Review Answers & Practice Again
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PracticeReviewScreen(
                              questions: questions,
                              selectedAnswers: selectedAnswers,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Review All'),
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
                            builder: (_) => PracticeScreen(
                              grade: grade,
                              stream: stream,
                              subject: subject,
                              unitNumber: unitNumber,
                              unitName: unitName,
                              examYear: examYear,
                              questionCount: questionCount ?? totalQuestions,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Practice Again'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              if (mistakes.isNotEmpty) ...[
                const Text(
                  'Review Your Mistakes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...mistakes.map((question) {
                  final questionIndex = questions.indexOf(question);
                  final studentAnswer = selectedAnswers[questionIndex];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question.question,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your answer: ${studentAnswer ?? "Not answered"}',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Correct answer: ${question.correctAnswer}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (question.explanation.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Explanation',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              question.explanation,
                              style: const TextStyle(height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],

              if (mistakes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Perfect! You got every question correct. 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text(
                    'Back to Practice Selection',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _ResultStat({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
