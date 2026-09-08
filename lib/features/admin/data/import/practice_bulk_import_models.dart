import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../practice/data/question_model.dart';

/// Status of a file currently residing in the import queue.
enum ImportFileStatus {
  queued,
  reading,
  ready,
  validating,
  valid,
  needsReview,
  invalid,
  importing,
  imported,
  failed;

  String get label {
    switch (this) {
      case ImportFileStatus.queued:
        return 'Queued';
      case ImportFileStatus.reading:
        return 'Reading';
      case ImportFileStatus.ready:
        return 'Ready';
      case ImportFileStatus.validating:
        return 'Validating';
      case ImportFileStatus.valid:
        return 'Valid';
      case ImportFileStatus.needsReview:
        return 'Needs Review';
      case ImportFileStatus.invalid:
        return 'Invalid';
      case ImportFileStatus.importing:
        return 'Importing';
      case ImportFileStatus.imported:
        return 'Imported';
      case ImportFileStatus.failed:
        return 'Failed';
    }
  }

  Color get color {
    switch (this) {
      case ImportFileStatus.valid:
      case ImportFileStatus.imported:
        return Colors.green;
      case ImportFileStatus.ready:
      case ImportFileStatus.validating:
      case ImportFileStatus.reading:
      case ImportFileStatus.importing:
        return Colors.blue;
      case ImportFileStatus.needsReview:
        return Colors.orange;
      case ImportFileStatus.invalid:
      case ImportFileStatus.failed:
        return Colors.red;
      case ImportFileStatus.queued:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case ImportFileStatus.valid:
      case ImportFileStatus.imported:
        return Icons.check_circle_outline;
      case ImportFileStatus.ready:
        return Icons.file_present_outlined;
      case ImportFileStatus.validating:
      case ImportFileStatus.reading:
      case ImportFileStatus.importing:
        return Icons.sync_rounded;
      case ImportFileStatus.needsReview:
        return Icons.warning_amber_rounded;
      case ImportFileStatus.invalid:
      case ImportFileStatus.failed:
        return Icons.error_outline;
      case ImportFileStatus.queued:
        return Icons.hourglass_empty_rounded;
    }
  }
}

/// A file added by the Admin to the import queue.
class QueuedImportFile {
  final String id;
  final String name;
  final int size;
  final Uint8List bytes;
  ImportFileStatus status;
  String? errorMessage;

  List<PracticeImportRow> practiceRows;

  QueuedImportFile({
    required this.id,
    required this.name,
    required this.size,
    required this.bytes,
    this.status = ImportFileStatus.ready,
    this.errorMessage,
    List<PracticeImportRow>? practiceRows,
  }) : practiceRows = practiceRows ?? [];

  int get validRowsCount => practiceRows.where((r) => r.isValid && !r.needsReview).length;
  int get needsReviewRowsCount => practiceRows.where((r) => r.isValid && r.needsReview).length;
  int get invalidRowsCount => practiceRows.where((r) => !r.isValid).length;
  int get totalQuestionsCount => practiceRows.length;

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// A parsed row for Practice Question Bank import.
class PracticeImportRow {
  final int rowIndex; // 1-based row in spreadsheet
  final String fileName;

  final String questionId;
  final String stream;
  final int examYear;
  final String examType;
  final String subject;
  final String grade;
  final int unitNumber;
  final String unitName;
  final String? topic;

  final int questionNumber;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;
  final String explanation;

  final String? difficulty;
  final String? answerStatus; // e.g. "rejected", "verified", "draft"
  final bool imageRequired;
  final String? imageUrl;
  final String publicationStatus; // "published", "draft", "review"

  final List<String> validationErrors;
  final List<String> validationWarnings;

  bool isDuplicateInQueue;
  bool isDuplicateInFirestore;

  PracticeImportRow({
    required this.rowIndex,
    required this.fileName,
    required this.questionId,
    required this.stream,
    required this.examYear,
    this.examType = 'Practice Question',
    required this.subject,
    required this.grade,
    required this.unitNumber,
    required this.unitName,
    this.topic,
    required this.questionNumber,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    required this.explanation,
    this.difficulty,
    this.answerStatus,
    this.imageRequired = false,
    this.imageUrl,
    this.publicationStatus = 'published',
    List<String>? validationErrors,
    List<String>? validationWarnings,
    this.isDuplicateInQueue = false,
    this.isDuplicateInFirestore = false,
  })  : validationErrors = validationErrors ?? [],
        validationWarnings = validationWarnings ?? [];

  List<String> get options => [optionA, optionB, optionC, optionD];

  bool get isValid => validationErrors.isEmpty && !isDuplicateInQueue;

  bool get needsReview =>
      isValid && (validationWarnings.isNotEmpty || isDuplicateInFirestore || (imageRequired && (imageUrl == null || imageUrl!.isEmpty)));

  /// Computes final published/draft status respecting all safety constraints.
  String get effectiveStatus {
    if (answerStatus?.toLowerCase() == 'rejected') return 'draft';
    final pub = publicationStatus.toLowerCase();
    if (pub == 'draft' || pub == 'review') return 'draft';
    if (imageRequired && (imageUrl == null || imageUrl!.isEmpty)) return 'draft';
    if (!isValid) return 'draft';
    return 'published';
  }

  /// Converts this validated row to the existing EduRise Question model.
  Question toQuestion() {
    return Question(
      id: questionId,
      grade: grade,
      stream: stream,
      subject: subject,
      unitNumber: unitNumber,
      unitName: unitName,
      questionNumber: questionNumber,
      question: question,
      questionImageUrl: imageUrl,
      options: options,
      correctAnswer: correctAnswer,
      explanation: explanation,
      explanationImageUrl: null,
      examYear: examYear,
      examType: examType.isNotEmpty ? examType : 'Practice Question',
      status: effectiveStatus,
      createdAt: null, // Firestore server timestamp applied at write
    );
  }
}

/// Aggregated result of a bulk import operation.
class BulkImportResult {
  final int filesProcessed;
  final int questionsImported;
  final int skippedCount;
  final int failedCount;

  final List<String> skippedDetails;
  final List<String> failedDetails;
  final List<String> importedDetails;

  const BulkImportResult({
    required this.filesProcessed,
    required this.questionsImported,
    required this.skippedCount,
    required this.failedCount,
    this.skippedDetails = const [],
    this.failedDetails = const [],
    this.importedDetails = const [],
  });

  bool get hasWarningsOrErrors => skippedCount > 0 || failedCount > 0;
}
