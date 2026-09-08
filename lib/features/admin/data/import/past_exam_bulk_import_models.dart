import '../../../past_entrance_exams/data/past_exam_model.dart';

/// A single parsed row from a Past Entrance Exam file.
class PastExamImportRow {
  final int rowIndex; // 1-based row in file
  final String fileName;

  final String packageId;
  final String year;
  final String stream;
  final String? round;
  final String subject;
  final int durationMinutes;

  final int questionNumber;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;
  final String explanation;
  final String? imageUrl;
  final bool imageRequired;

  final List<String> validationErrors;
  final List<String> validationWarnings;

  PastExamImportRow({
    required this.rowIndex,
    required this.fileName,
    required this.packageId,
    required this.year,
    required this.stream,
    this.round,
    required this.subject,
    this.durationMinutes = 180,
    required this.questionNumber,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    required this.explanation,
    this.imageUrl,
    this.imageRequired = false,
    List<String>? validationErrors,
    List<String>? validationWarnings,
  })  : validationErrors = validationErrors ?? [],
        validationWarnings = validationWarnings ?? [];

  bool get isValid => validationErrors.isEmpty;
  bool get needsReview => isValid && (validationWarnings.isNotEmpty || (imageRequired && (imageUrl == null || imageUrl!.isEmpty)));

  PastExamQuestion toPastExamQuestion() {
    return PastExamQuestion(
      questionNumber: questionNumber,
      questionText: questionText,
      imageUrl: imageUrl,
      optionA: optionA,
      optionB: optionB,
      optionC: optionC,
      optionD: optionD,
      correctAnswer: correctAnswer,
      explanation: explanation,
    );
  }
}

/// A parsed Exam Package containing ordered questions.
class PastExamPackageDraft {
  final String packageId;
  final String year;
  final String stream;
  final String? round;
  final String subject;
  final int durationMinutes;
  final String fileName;

  final List<PastExamImportRow> rows;

  PastExamPackageDraft({
    required this.packageId,
    required this.year,
    required this.stream,
    this.round,
    required this.subject,
    this.durationMinutes = 180,
    required this.fileName,
    required this.rows,
  });

  int get totalQuestions => rows.length;
  int get validQuestions => rows.where((r) => r.isValid).length;
  int get invalidQuestions => rows.where((r) => !r.isValid).length;
  int get reviewQuestions => rows.where((r) => r.isValid && r.needsReview).length;

  bool get isPackageValid => invalidQuestions == 0 && rows.isNotEmpty;

  /// Returns questions sorted strictly by questionNumber ascending to guarantee
  /// Q1 -> Q2 -> ... -> Q100 order preservation.
  List<PastExamQuestion> getOrderedQuestions() {
    final sortedRows = List<PastExamImportRow>.from(rows)
      ..sort((a, b) => a.questionNumber.compareTo(b.questionNumber));

    return sortedRows.map((r) => r.toPastExamQuestion()).toList();
  }

  /// Converts package draft to the existing PastExam model.
  PastExam toPastExam() {
    return PastExam(
      id: packageId,
      year: year,
      stream: stream,
      round: round,
      subject: subject,
      durationMinutes: durationMinutes,
      questions: getOrderedQuestions(),
    );
  }
}
