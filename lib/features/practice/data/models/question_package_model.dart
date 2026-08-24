import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionPackage {
  final String packageId;

  final String title;

  final String grade;

  final String stream;

  final String subject;

  final int unitNumber;

  final String unitName;

  final String? examType;

  final int? examYear;

  final int version;

  final int questionCount;

  final String status;

  final DateTime? createdAt;

  const QuestionPackage({
    required this.packageId,
    required this.title,
    required this.grade,
    required this.stream,
    required this.subject,
    required this.unitNumber,
    required this.unitName,
    this.examType,
    this.examYear,
    required this.version,
    required this.questionCount,
    required this.status,
    this.createdAt,
  });

  // ============================================================
  // FIRESTORE → QUESTION PACKAGE
  // ============================================================

  factory QuestionPackage.fromMap(String id, Map<String, dynamic> data) {
    return QuestionPackage(
      packageId: id,

      title: data['title'] as String? ?? '',

      grade: data['grade'] as String? ?? '',

      stream: data['stream'] as String? ?? '',

      subject: data['subject'] as String? ?? '',

      unitNumber: data['unitNumber'] as int? ?? 0,

      unitName: data['unitName'] as String? ?? '',

      examType: data['examType'] as String?,

      examYear: data['examYear'] as int?,

      version: data['version'] as int? ?? 1,

      questionCount: data['questionCount'] as int? ?? 0,

      status: data['status'] as String? ?? 'draft',

      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ============================================================
  // QUESTION PACKAGE → FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'grade': grade,
      'stream': stream,
      'subject': subject,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'examType': examType,
      'examYear': examYear,
      'version': version,
      'questionCount': questionCount,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
