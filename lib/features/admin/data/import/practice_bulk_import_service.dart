import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_service.dart';
import '../audit_service.dart';
import 'practice_bulk_import_models.dart';
import 'spreadsheet_parser_service.dart';

/// Service responsible for parsing, validating, and importing Practice Question Bank files into Firestore.
class PracticeBulkImportService {
  final FirebaseFirestore? _customFirestore;

  PracticeBulkImportService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _questionsCollection =>
      _firestore.collection('questions');

  // ============================================================
  // PARSE FILE INTO PRACTICE ROWS
  // ============================================================

  List<PracticeImportRow> parseFile(QueuedImportFile file) {
    final rawRows = SpreadsheetParserService.parseSpreadsheet(
      bytes: file.bytes,
      fileName: file.name,
    );

    if (rawRows.isEmpty) {
      file.status = ImportFileStatus.invalid;
      file.errorMessage = 'The spreadsheet is empty.';
      return [];
    }

    // Identify header row
    final headerRow = rawRows.first;
    final columnMap = _buildColumnMap(headerRow);

    // Helper to check for key existence among aliases
    bool hasAnyKey(List<String> keys) => keys.any((k) => columnMap.containsKey(k));

    // Validate essential headers
    final missingEssential = <String>[];
    if (!hasAnyKey(['questiontext', 'question', 'text'])) {
      missingEssential.add('question_text');
    }
    if (!hasAnyKey(['answerletter', 'correctanswer', 'answer', 'ans', 'correct'])) {
      missingEssential.add('answer_letter');
    }

    if (missingEssential.isNotEmpty) {
      file.status = ImportFileStatus.invalid;
      file.errorMessage =
          'Missing essential headers: ${missingEssential.join(', ')}';
      return [];
    }

    final parsedRows = <PracticeImportRow>[];

    for (int r = 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      // Skip empty row
      if (row.every((c) => c.trim().isEmpty)) continue;

      String getVal(List<String> keys) {
        for (final k in keys) {
          final idx = columnMap[k];
          if (idx != null && idx < row.length) {
            final v = row[idx].trim();
            if (v.isNotEmpty) return v;
          }
        }
        return '';
      }

      final errors = <String>[];
      final warnings = <String>[];

      // 1. question_number
      final qNumStr = getVal(['questionnumber', 'qnumber', 'qnum', 'questionno', 'questionnum', 'number']);
      final parsedQNum = int.tryParse(qNumStr.replaceAll(RegExp(r'[^0-9]'), ''));
      if (qNumStr.isNotEmpty && (parsedQNum == null || parsedQNum <= 0)) {
        errors.add('Question number must be a valid positive integer (got: "$qNumStr").');
      }
      final questionNumber = parsedQNum ?? r;

      // 2. stream
      final streamRaw = getVal(['stream']);
      final streamLower = streamRaw.toLowerCase().trim();
      String stream = 'natural';
      if (streamLower.isNotEmpty) {
        if (streamLower == 'natural' || streamLower == 'natural science' || streamLower == 'naturalscience') {
          stream = 'natural';
        } else if (streamLower == 'social' || streamLower == 'social science' || streamLower == 'socialscience') {
          stream = 'social';
        } else {
          errors.add('Stream must be either "natural" or "social" (got: "$streamRaw").');
        }
      }

      // 3. textbook_grade
      final rawGrade = getVal(['textbookgrade', 'grade']);
      final grade = _normalizeGrade(rawGrade);
      if (grade.isEmpty) {
        errors.add('Textbook grade must be 9, 10, 11, or 12 (got: "$rawGrade").');
      }

      // 4. subject
      final subjectRaw = getVal(['subject', 'textbooksubject']);
      final subject = subjectRaw.isNotEmpty ? subjectRaw : '';
      if (subject.isEmpty || subject.toLowerCase() == 'general') {
        errors.add('Subject is required.');
      }

      // 5. unit_number
      final unitNumStr = getVal(['unitnumber', 'unit', 'unitno', 'unitnum']);
      final unitNumber = int.tryParse(unitNumStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (unitNumber <= 0) {
        errors.add('Unit number must be a valid positive integer.');
      }

      // 6. unit_name
      final unitNameRaw = getVal(['unitname', 'unittitle']);
      final unitName = unitNameRaw.isNotEmpty ? unitNameRaw : (unitNumber > 0 ? 'Unit $unitNumber' : '');
      if (unitName.isEmpty) {
        errors.add('Unit name is required.');
      }

      // 7. question_text
      final questionText = getVal(['questiontext', 'question', 'text']);
      if (questionText.isEmpty) {
        errors.add('Question text cannot be empty.');
      }

      // 8, 9, 10, 11. options
      final optionA = getVal(['optiona', 'a', 'choicea']);
      final optionB = getVal(['optionb', 'b', 'choiceb']);
      final optionC = getVal(['optionc', 'c', 'choicec']);
      final optionD = getVal(['optiond', 'd', 'choiced']);
      if (optionA.isEmpty) errors.add('Option A is required.');
      if (optionB.isEmpty) errors.add('Option B is required.');
      if (optionC.isEmpty) errors.add('Option C is required.');
      if (optionD.isEmpty) errors.add('Option D is required.');

      // 12. answer_letter
      final rawAnswer = getVal(['answerletter', 'correctanswer', 'answer', 'ans', 'correct']).toUpperCase().trim();
      if (!['A', 'B', 'C', 'D'].contains(rawAnswer)) {
        errors.add('Answer must be A, B, C, or D (got: "$rawAnswer").');
      }
      final correctAnswer = ['A', 'B', 'C', 'D'].contains(rawAnswer) ? rawAnswer : 'A';

      // 13. explanation
      final explanation = getVal(['explanation', 'solution', 'rationale']);
      if (explanation.isEmpty) {
        errors.add('Explanation is required.');
      }

      // 14. entrance_year_ec
      final yearStr = getVal(['entranceyearec', 'examyear', 'year']);
      final examYear = int.tryParse(yearStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      // 15. exam_type
      final rawExamType = getVal(['examtype', 'type']);
      final examType = rawExamType.isNotEmpty ? rawExamType : 'Practice Question';

      // 16. status
      final pubStatusRaw = getVal(['status', 'publicationstatus']);
      final pubLower = pubStatusRaw.toLowerCase().trim();
      final publicationStatus = (pubLower == 'draft' || pubLower == 'review') ? 'draft' : 'published';

      // Additional optional fields
      final topic = getVal(['topic']);
      final difficulty = getVal(['difficulty']);
      final answerStatus = getVal(['answerstatus']);
      final imgReqStr = getVal(['imagerequired']).toLowerCase();
      final imageRequired = imgReqStr == 'true' || imgReqStr == '1' || imgReqStr == 'yes';
      final imageUrl = getVal(['imageurl', 'image']);

      // Question ID (use provided or generate deterministic identifier)
      final rawId = getVal(['questionid', 'id']);
      final questionId = rawId.isNotEmpty
          ? rawId
          : 'q_${grade.isNotEmpty ? grade.toLowerCase().replaceAll(' ', '') : 'g'}_${stream.isNotEmpty ? stream : 'stream'}_${subject.isNotEmpty ? subject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') : 'sub'}_u${unitNumber}_q$questionNumber';

      if (answerStatus.toLowerCase() == 'rejected') {
        warnings.add('Answer rejected. Will remain in draft mode.');
      }

      if (imageRequired && imageUrl.isEmpty) {
        warnings.add('Image required but URL is missing. Will remain in draft mode.');
      }

      parsedRows.add(
        PracticeImportRow(
          rowIndex: r + 1,
          fileName: file.name,
          questionId: questionId,
          stream: stream,
          examYear: examYear,
          examType: examType,
          subject: subject,
          grade: grade,
          unitNumber: unitNumber,
          unitName: unitName,
          topic: topic.isNotEmpty ? topic : null,
          questionNumber: questionNumber,
          question: questionText,
          optionA: optionA,
          optionB: optionB,
          optionC: optionC,
          optionD: optionD,
          correctAnswer: correctAnswer,
          explanation: explanation,
          difficulty: difficulty.isNotEmpty ? difficulty : null,
          answerStatus: answerStatus.isNotEmpty ? answerStatus : null,
          imageRequired: imageRequired,
          imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
          publicationStatus: publicationStatus,
          validationErrors: errors,
          validationWarnings: warnings,
        ),
      );
    }

    file.practiceRows = parsedRows;
    return parsedRows;
  }

  // ============================================================
  // VALIDATE QUEUED FILES & CHECK FIRESTORE DUPLICATES
  // ============================================================

  Future<void> validateAllFiles(List<QueuedImportFile> files) async {
    final allSeenIds = <String, PracticeImportRow>{};

    for (final file in files) {
      file.status = ImportFileStatus.validating;
      final rows = parseFile(file);

      // In-queue duplicate check
      for (final row in rows) {
        if (allSeenIds.containsKey(row.questionId)) {
          row.isDuplicateInQueue = true;
          row.validationErrors.add(
            'Duplicate question ID "${row.questionId}" found in file "${allSeenIds[row.questionId]!.fileName}" at row ${allSeenIds[row.questionId]!.rowIndex}.',
          );
        } else {
          allSeenIds[row.questionId] = row;
        }
      }
    }

    // Check Firestore for duplicate document IDs
    final validRowsToCheck = allSeenIds.values.where((r) => r.validationErrors.isEmpty).toList();

    // Query in batches of 30 (Firestore whereIn limit)
    const chunkSize = 30;
    for (int i = 0; i < validRowsToCheck.length; i += chunkSize) {
      final chunk = validRowsToCheck.sublist(
        i,
        (i + chunkSize > validRowsToCheck.length) ? validRowsToCheck.length : i + chunkSize,
      );
      final ids = chunk.map((r) => r.questionId).toList();

      try {
        final snapshot = await _questionsCollection
            .where(FieldPath.documentId, whereIn: ids)
            .get();

        final existingIds = snapshot.docs.map((d) => d.id).toSet();
        for (final row in chunk) {
          if (existingIds.contains(row.questionId)) {
            row.isDuplicateInFirestore = true;
            row.validationWarnings.add(
              'Question ID "${row.questionId}" already exists in Firestore.',
            );
          }
        }
      } catch (e) {
        // Fallback individual check if whereIn fails or security rules differ
        for (final row in chunk) {
          try {
            final doc = await _questionsCollection.doc(row.questionId).get();
            if (doc.exists) {
              row.isDuplicateInFirestore = true;
              row.validationWarnings.add(
                'Question ID "${row.questionId}" already exists in Firestore.',
              );
            }
          } catch (_) {}
        }
      }
    }

    // Update each file's status
    for (final file in files) {
      if (file.practiceRows.isEmpty) {
        file.status = ImportFileStatus.invalid;
      } else if (file.practiceRows.any((r) => !r.isValid)) {
        file.status = ImportFileStatus.invalid;
      } else if (file.practiceRows.any((r) => r.needsReview)) {
        file.status = ImportFileStatus.needsReview;
      } else {
        file.status = ImportFileStatus.valid;
      }
    }
  }

  // ============================================================
  // IMPORT VALID ROWS INTO FIRESTORE (BATCHED)
  // ============================================================

  Future<BulkImportResult> importQuestions({
    required List<PracticeImportRow> rows,
    required bool skipFirestoreDuplicates,
    void Function(int current, int total)? onProgress,
  }) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) {
      throw Exception('Unauthorized access. Only admins may import questions.');
    }

    final toImport = <PracticeImportRow>[];
    final skippedDetails = <String>[];
    final failedDetails = <String>[];
    final importedDetails = <String>[];

    for (final row in rows) {
      if (!row.isValid) {
        failedDetails.add(
          'Row ${row.rowIndex} (${row.fileName}): ${row.validationErrors.join("; ")}',
        );
        continue;
      }

      if (row.isDuplicateInFirestore && skipFirestoreDuplicates) {
        skippedDetails.add(
          'Row ${row.rowIndex} (${row.fileName}): Skipped duplicate ID "${row.questionId}".',
        );
        continue;
      }

      toImport.add(row);
    }

    const batchLimit = 250; // Well within 500 operation Firestore limit
    int writtenCount = 0;

    for (int i = 0; i < toImport.length; i += batchLimit) {
      final chunk = toImport.sublist(
        i,
        (i + batchLimit > toImport.length) ? toImport.length : i + batchLimit,
      );

      final batch = _firestore.batch();

      for (final row in chunk) {
        final docRef = _questionsCollection.doc(row.questionId);
        final question = row.toQuestion();

        batch.set(
          docRef,
          {
            ...question.toMap(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      writtenCount += chunk.length;
      onProgress?.call(writtenCount, toImport.length);

      for (final row in chunk) {
        importedDetails.add('${row.questionId} (${row.grade} • ${row.subject})');
      }
    }

    // Audit log
    await AuditService.logAction(
      action: 'practice_questions_bulk_imported',
      targetType: 'questions_collection',
      targetId: 'bulk_import_${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'imported': writtenCount,
        'skipped': skippedDetails.length,
        'failed': failedDetails.length,
      },
    );

    return BulkImportResult(
      filesProcessed: rows.map((r) => r.fileName).toSet().length,
      questionsImported: writtenCount,
      skippedCount: skippedDetails.length,
      failedCount: failedDetails.length,
      skippedDetails: skippedDetails,
      failedDetails: failedDetails,
      importedDetails: importedDetails,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static Map<String, int> _buildColumnMap(List<String> headerRow) {
    final map = <String, int>{};
    for (int i = 0; i < headerRow.length; i++) {
      final clean = headerRow[i]
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (clean.isNotEmpty) {
        map[clean] = i;
      }
    }
    return map;
  }

  static String _normalizeGrade(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return '';

    final num = int.tryParse(clean.replaceAll(RegExp(r'[^0-9]'), ''));
    if (num != null && num >= 9 && num <= 12) {
      return 'Grade $num';
    }

    return '';
  }
}
