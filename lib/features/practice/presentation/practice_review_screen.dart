import 'package:flutter/material.dart';

import '../data/question_model.dart';

class PracticeReviewScreen extends StatelessWidget {
  final List<Question> questions;
  final Map<int, String> selectedAnswers;

  const PracticeReviewScreen({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Answers')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: questions.length,
        // ignore: unnecessary_underscores
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final question = questions[index];

          final selectedAnswer = selectedAnswers[index];

          final isCorrect = selectedAnswer == question.correctAnswer;

          return _ReviewQuestionCard(
            questionNumber: index + 1,
            question: question,
            selectedAnswer: selectedAnswer,
            isCorrect: isCorrect,
          );
        },
      ),
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final int questionNumber;
  final Question question;
  final String? selectedAnswer;
  final bool isCorrect;

  const _ReviewQuestionCard({
    required this.questionNumber,
    required this.question,
    required this.selectedAnswer,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isCorrect ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // ignore: deprecated_member_use
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: statusColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$questionNumber',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: statusColor,
              ),

              const SizedBox(width: 6),

              Text(
                isCorrect ? 'Correct' : 'Incorrect',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            question.question,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 18),

          _AnswerRow(
            label: 'Your answer',
            answer: selectedAnswer ?? 'Not answered',
            color: isCorrect ? Colors.green : Colors.red,
          ),

          const SizedBox(height: 10),

          _AnswerRow(
            label: 'Correct answer',
            answer: question.correctAnswer,
            color: Colors.green,
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explanation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  question.explanation.isEmpty
                      ? 'No explanation available.'
                      : question.explanation,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String answer;
  final Color color;

  const _AnswerRow({
    required this.label,
    required this.answer,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),

        Expanded(
          child: Text(
            answer,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
