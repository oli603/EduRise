class Question {
  final String id;

  final String grade;
  final String subject;

  final int unitNumber;
  final String unitName;

  final int questionNumber;

  final String question;
  final List<String> options;

  final String correctAnswer;
  final String explanation;

  final int examYear;
  final String examType;

  final String status;

  final DateTime? createdAt;

  const Question({
    required this.id,
    required this.grade,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
    required this.questionNumber,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.examYear,
    required this.examType,
    required this.status,
    this.createdAt,
  });

  factory Question.fromMap(String id, Map<String, dynamic> data) {
    return Question(
      id: id,
      grade: data['grade'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      unitNumber: data['unitNumber'] as int? ?? 0,
      unitName: data['unitName'] as String? ?? '',
      questionNumber: data['questionNumber'] as int? ?? 0,
      question: data['question'] as String? ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] as String? ?? '',
      explanation: data['explanation'] as String? ?? '',
      examYear: data['examYear'] as int? ?? 0,
      examType: data['examType'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      createdAt: (data['createdAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'grade': grade,
      'subject': subject,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'questionNumber': questionNumber,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'examYear': examYear,
      'examType': examType,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
