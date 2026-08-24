class PastExamQuestion {
  final int questionNumber;
  final String questionText;
  final String? imageUrl;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;
  final String explanation;

  const PastExamQuestion({
    required this.questionNumber,
    required this.questionText,
    this.imageUrl,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionNumber': questionNumber,
      'questionText': questionText,
      'imageUrl': imageUrl,
      'optionA': optionA,
      'optionB': optionB,
      'optionC': optionC,
      'optionD': optionD,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }

  factory PastExamQuestion.fromMap(Map<String, dynamic> map) {
    return PastExamQuestion(
      questionNumber: map['questionNumber'] ?? 0,
      questionText: map['questionText'] ?? '',
      imageUrl: map['imageUrl'],
      optionA: map['optionA'] ?? '',
      optionB: map['optionB'] ?? '',
      optionC: map['optionC'] ?? '',
      optionD: map['optionD'] ?? '',
      correctAnswer: map['correctAnswer'] ?? '',
      explanation: map['explanation'] ?? '',
    );
  }
}

class PastExam {
  final String id;
  final String year;
  final String stream;
  final String? round;
  final String subject;
  final int durationMinutes;
  final List<PastExamQuestion> questions;

  const PastExam({
    required this.id,
    required this.year,
    required this.stream,
    this.round,
    required this.subject,
    required this.durationMinutes,
    required this.questions,
  });

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'stream': stream,
      'round': round,
      'subject': subject,
      'durationMinutes': durationMinutes,
      'questionCount': questions.length,
      'questions': questions.map((question) => question.toMap()).toList(),
    };
  }

  factory PastExam.fromMap(String id, Map<String, dynamic> map) {
    final questionData = map['questions'] as List<dynamic>? ?? [];

    return PastExam(
      id: id,
      year: map['year'] ?? '',
      stream: map['stream'] ?? '',
      round: map['round'],
      subject: map['subject'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 0,
      questions: questionData
          .map(
            (question) =>
                PastExamQuestion.fromMap(Map<String, dynamic>.from(question)),
          )
          .toList(),
    );
  }
}
