import 'package:cloud_firestore/cloud_firestore.dart';

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

  static String _parseString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _parseOptions(dynamic value) {
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').toList();
    }
    return const [];
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  static String _parseGrade(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty) return '';
    final numMatch = RegExp(r'\d+').firstMatch(s);
    if (numMatch != null) {
      final gradeNum = int.tryParse(numMatch.group(0)!);
      if (gradeNum != null && gradeNum >= 7 && gradeNum <= 12) {
        return 'Grade $gradeNum';
      }
    }
    return s;
  }

  // ============================================================
  // FIRESTORE → QUESTION
  // ============================================================

  factory Question.fromMap(String id, Map<String, dynamic> data) {
    return Question(
      id: id,
      grade: _parseGrade(data['grade'] ?? data['textbook_grade'] ?? data['textbookGrade']),
      stream: _parseString(data['stream']),
      subject: _parseString(data['subject'] ?? data['textbook_subject']),
      unitNumber: _parseInt(data['unitNumber'] ?? data['unit_number']),
      unitName: _parseString(data['unitName'] ?? data['unit_name']),
      questionNumber: _parseInt(data['questionNumber'] ?? data['question_number']),
      question: _parseString(data['question'] ?? data['question_text']),
      questionImageUrl: _parseNullableString(data['questionImageUrl'] ?? data['imageUrl']),
      options: _parseOptions(data['options']),
      correctAnswer: _parseString(data['correctAnswer'] ?? data['answer']),
      explanation: _parseString(data['explanation'] ?? data['explanation_text']),
      explanationImageUrl: _parseNullableString(data['explanationImageUrl']),
      examYear: _parseInt(data['examYear'] ?? data['entrance_year_ec'] ?? data['entranceYearEc'] ?? data['year']),
      examType: _parseString(data['examType'] ?? data['exam_type']),
      status: _parseString(data['status'], 'draft'),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  // ============================================================
  // QUESTION → FIRESTORE
  // ============================================================

  Question copyWith({
    String? id,
    String? grade,
    String? stream,
    String? subject,
    int? unitNumber,
    String? unitName,
    int? questionNumber,
    String? question,
    String? questionImageUrl,
    List<String>? options,
    String? correctAnswer,
    String? explanation,
    String? explanationImageUrl,
    int? examYear,
    String? examType,
    String? status,
    DateTime? createdAt,
  }) {
    return Question(
      id: id ?? this.id,
      grade: grade ?? this.grade,
      stream: stream ?? this.stream,
      subject: subject ?? this.subject,
      unitNumber: unitNumber ?? this.unitNumber,
      unitName: unitName ?? this.unitName,
      questionNumber: questionNumber ?? this.questionNumber,
      question: question ?? this.question,
      questionImageUrl: questionImageUrl ?? this.questionImageUrl,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      explanationImageUrl: explanationImageUrl ?? this.explanationImageUrl,
      examYear: examYear ?? this.examYear,
      examType: examType ?? this.examType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

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
