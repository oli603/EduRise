class Question {
  final String id;

  // ============================================================
  // ACADEMIC INFORMATION
  // ============================================================

  final String grade;
  final String stream;
  final String subject;

  // ============================================================
  // UNIT INFORMATION
  // ============================================================

  final int unitNumber;
  final String unitName;

  // ============================================================
  // QUESTION INFORMATION
  // ============================================================

  final int questionNumber;

  final String question;
  final String? questionImageUrl;

  final List<String> options;

  final String correctAnswer;

  // ============================================================
  // EXPLANATION
  // ============================================================

  final String explanation;
  final String? explanationImageUrl;

  // ============================================================
  // EXAM INFORMATION
  // ============================================================

  final int examYear;
  final String examType;

  // ============================================================
  // STATUS
  // ============================================================

  final String status;

  // ============================================================
  // DATE
  // ============================================================

  final DateTime? createdAt;

  const Question({
    required this.id,
    required this.grade,
    required this.stream,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
    required this.questionNumber,
    required this.question,
    this.questionImageUrl,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.explanationImageUrl,
    required this.examYear,
    required this.examType,
    required this.status,
    this.createdAt,
  });

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 0;
  }

  // ============================================================
  // FIRESTORE → QUESTION
  // ============================================================

  factory Question.fromMap(String id, Map<String, dynamic> data) {
    return Question(
      id: id,

      grade: (data['grade'] ?? data['textbook_grade'] ?? data['textbookGrade']) as String? ?? '',

      stream: data['stream'] as String? ?? '',

      subject: data['subject'] as String? ?? '',

      unitNumber: _parseInt(data['unitNumber'] ?? data['unit_number']),

      unitName: (data['unitName'] ?? data['unit_name']) as String? ?? '',

      questionNumber: _parseInt(data['questionNumber'] ?? data['question_number']),

      question: (data['question'] ?? data['question_text']) as String? ?? '',

      questionImageUrl: (data['questionImageUrl'] ?? data['imageUrl']) as String?,

      options: List<String>.from(data['options'] ?? []),

      correctAnswer: (data['correctAnswer'] ?? data['answer']) as String? ?? '',

      explanation: data['explanation'] as String? ?? '',

      explanationImageUrl: data['explanationImageUrl'] as String?,

      examYear: _parseInt(data['examYear'] ?? data['entrance_year_ec'] ?? data['entranceYearEc'] ?? data['year']),

      examType: (data['examType'] ?? data['exam_type']) as String? ?? '',

      status: data['status'] as String? ?? 'draft',

      createdAt: (data['createdAt'] as dynamic)?.toDate(),
    );
  }

  // ============================================================
  // QUESTION → FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'grade': grade,

      'stream': stream,

      'subject': subject,

      'unitNumber': unitNumber,

      'unitName': unitName,

      'questionNumber': questionNumber,

      'question': question,

      'questionImageUrl': questionImageUrl,

      'options': options,

      'correctAnswer': correctAnswer,

      'explanation': explanation,

      'explanationImageUrl': explanationImageUrl,

      'examYear': examYear,

      'examType': examType,

      'status': status,

      'createdAt': createdAt,
    };
  }
}
