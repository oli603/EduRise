import '../../../past_entrance_exams/data/past_exam_service.dart';
import '../admin_service.dart';
import '../audit_service.dart';
import 'past_exam_bulk_import_models.dart';
import 'practice_bulk_import_models.dart';
import 'spreadsheet_parser_service.dart';

/// Service responsible for parsing, validating, and importing Past Entrance Exam spreadsheets.
class PastExamBulkImportService {
  final PastExamService? _customPastExamService;

  PastExamBulkImportService({PastExamService? pastExamService})
      : _customPastExamService = pastExamService;

  PastExamService get _pastExamService =>
      _customPastExamService ?? PastExamService();

  // ============================================================
  // PARSE FILE INTO EXAM PACKAGES
  // ============================================================

  List<PastExamPackageDraft> parseFile(QueuedImportFile file) {
    final rawRows = SpreadsheetParserService.parseSpreadsheet(
      bytes: file.bytes,
      fileName: file.name,
    );

    if (rawRows.isEmpty) {
      file.status = ImportFileStatus.invalid;
      file.errorMessage = 'The exam spreadsheet is empty.';
      return [];
    }

    final headerRow = rawRows.first;
    final columnMap = _buildColumnMap(headerRow);

    // Validate essential headers
    final missingEssential = <String>[];
    if (!columnMap.containsKey('question') && !columnMap.containsKey('questiontext')) {
      missingEssential.add('question');
    }
    final hasAnswerCol = columnMap.containsKey('answer') ||
        columnMap.containsKey('correctanswer') ||
        columnMap.containsKey('answerletter');
    if (!hasAnswerCol) {
      missingEssential.add('answer_letter');
    }

    if (missingEssential.isNotEmpty) {
      file.status = ImportFileStatus.invalid;
      file.errorMessage =
          'Missing essential headers: ${missingEssential.join(', ')}';
      return [];
    }

    // Attempt filename metadata inference as fallbacks (e.g. "Biology_2013.xlsx")
    final fileInference = _inferMetadataFromFileName(file.name);

    final packageMap = <String, List<PastExamImportRow>>{};
    final packageMetadata = <String, Map<String, dynamic>>{};

    for (int r = 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.every((c) => c.trim().isEmpty)) continue;

      String getVal(String key) {
        final idx = columnMap[key];
        if (idx == null || idx >= row.length) return '';
        return row[idx].trim();
      }

      final yearStr = getVal('entranceyearec').isNotEmpty
          ? getVal('entranceyearec')
          : getVal('year').isNotEmpty
              ? getVal('year')
              : fileInference['year'] ?? '2013';

      final subjectRaw = getVal('subject').isNotEmpty
          ? getVal('subject')
          : fileInference['subject'] ?? 'Biology';

      final streamRaw = getVal('stream').isNotEmpty
          ? getVal('stream')
          : fileInference['stream'] ?? 'Natural Science';

      final roundRaw = getVal('round');
      final round = roundRaw.isNotEmpty ? roundRaw : null;

      final durationStr = getVal('durationminutes').isNotEmpty
          ? getVal('durationminutes')
          : getVal('duration');
      final duration = _parseDurationMinutes(durationStr);

      final qNumStr = getVal('questionnumber').isNotEmpty
          ? getVal('questionnumber')
          : getVal('number');
      final questionNumber = int.tryParse(qNumStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? r;

      final packageIdExplicit = getVal('packageid').isNotEmpty
          ? getVal('packageid')
          : getVal('examid');

      final packageKey = packageIdExplicit.isNotEmpty
          ? packageIdExplicit
          : _buildDefaultExamId(yearStr, streamRaw, subjectRaw, round);

      final questionText = getVal('question').isNotEmpty
          ? getVal('question')
          : getVal('questiontext');
      final optionA = getVal('optiona').isNotEmpty ? getVal('optiona') : getVal('a');
      final optionB = getVal('optionb').isNotEmpty ? getVal('optionb') : getVal('b');
      final optionC = getVal('optionc').isNotEmpty ? getVal('optionc') : getVal('c');
      final optionD = getVal('optiond').isNotEmpty ? getVal('optiond') : getVal('d');

      final answerRaw = getVal('answerletter').isNotEmpty
          ? getVal('answerletter')
          : getVal('correctanswer').isNotEmpty
              ? getVal('correctanswer')
              : getVal('answer');
      final correctAnswer = answerRaw.toUpperCase().trim();

      final explanation = getVal('explanation');
      final imageUrl = getVal('imageurl');
      final imgReqStr = getVal('imagerequired').toLowerCase();
      final imageRequired = imgReqStr == 'true' || imgReqStr == '1' || imgReqStr == 'yes';

      final errors = <String>[];
      final warnings = <String>[];

      if (questionNumber <= 0) errors.add('Question number must be > 0.');
      if (questionText.isEmpty) errors.add('Question text cannot be empty.');
      if (optionA.isEmpty) errors.add('Option A is required.');
      if (optionB.isEmpty) errors.add('Option B is required.');
      if (optionC.isEmpty) errors.add('Option C is required.');
      if (optionD.isEmpty) errors.add('Option D is required.');

      if (!['A', 'B', 'C', 'D'].contains(correctAnswer)) {
        errors.add('Answer must be A, B, C, or D (got: "$answerRaw").');
      }

      if (explanation.isEmpty) {
        errors.add('Explanation is required.');
      }

      if (imageRequired && (imageUrl.isEmpty)) {
        warnings.add('Image required but URL missing.');
      }

      final parsedRow = PastExamImportRow(
        rowIndex: r + 1,
        fileName: file.name,
        packageId: packageKey,
        year: yearStr,
        stream: streamRaw,
        round: round,
        subject: subjectRaw,
        durationMinutes: duration,
        questionNumber: questionNumber,
        questionText: questionText,
        optionA: optionA,
        optionB: optionB,
        optionC: optionC,
        optionD: optionD,
        correctAnswer: correctAnswer,
        explanation: explanation,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
        imageRequired: imageRequired,
        validationErrors: errors,
        validationWarnings: warnings,
      );

      packageMap.putIfAbsent(packageKey, () => []).add(parsedRow);
      packageMetadata[packageKey] = {
        'year': yearStr,
        'stream': streamRaw,
        'round': round,
        'subject': subjectRaw,
        'duration': duration,
      };
    }

    final packages = <PastExamPackageDraft>[];

    for (final entry in packageMap.entries) {
      final key = entry.key;
      final rows = entry.value;
      final meta = packageMetadata[key]!;

      // Check for duplicate question numbers within this package
      final seenNumbers = <int, int>{};
      for (final r in rows) {
        if (seenNumbers.containsKey(r.questionNumber)) {
          r.validationErrors.add(
            'Duplicate question number ${r.questionNumber} in package (row ${seenNumbers[r.questionNumber]} and row ${r.rowIndex}).',
          );
        } else {
          seenNumbers[r.questionNumber] = r.rowIndex;
        }
      }

      packages.add(
        PastExamPackageDraft(
          packageId: key,
          year: meta['year'] as String,
          stream: meta['stream'] as String,
          round: meta['round'] as String?,
          subject: meta['subject'] as String,
          durationMinutes: meta['duration'] as int,
          fileName: file.name,
          rows: rows,
        ),
      );
    }

    return packages;
  }

  // ============================================================
  // IMPORT EXAMS
  // ============================================================

  Future<BulkImportResult> importExams({
    required List<PastExamPackageDraft> packages,
    void Function(int current, int total)? onProgress,
  }) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) {
      throw Exception('Unauthorized access. Only admins may import exams.');
    }

    int importedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;
    final failedDetails = <String>[];
    final skippedDetails = <String>[];
    final importedDetails = <String>[];

    for (int i = 0; i < packages.length; i++) {
      final pkg = packages[i];
      if (!pkg.isPackageValid) {
        failedCount += pkg.rows.length;
        failedDetails.add(
          'Package "${pkg.packageId}" has ${pkg.invalidQuestions} invalid questions.',
        );
        continue;
      }

      try {
        final exam = pkg.toPastExam();
        await _pastExamService.savePastExam(exam);
        importedCount += exam.questions.length;
        importedDetails.add(
          '${pkg.packageId} (${exam.questions.length} questions)',
        );
      } catch (e) {
        failedCount += pkg.rows.length;
        failedDetails.add('Failed to save exam "${pkg.packageId}": $e');
      }

      onProgress?.call(i + 1, packages.length);
    }

    await AuditService.logAction(
      action: 'past_exams_bulk_imported',
      targetType: 'past_exams_collection',
      targetId: 'bulk_import_${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'packages': packages.length,
        'questionsImported': importedCount,
        'failedCount': failedCount,
      },
    );

    return BulkImportResult(
      filesProcessed: packages.map((p) => p.fileName).toSet().length,
      questionsImported: importedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
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

  static String _buildDefaultExamId(
    String year,
    String stream,
    String subject,
    String? round,
  ) {
    final y = year.replaceAll(' ', '_');
    final s = stream.replaceAll(' ', '_');
    final sub = subject.replaceAll(' ', '_');

    if (round != null && round.isNotEmpty) {
      final r = round.replaceAll(' ', '_');
      return '${y}_${s}_${sub}_$r';
    }
    return '${y}_${s}_$sub';
  }

  static int _parseDurationMinutes(String input) {
    final clean = input.toLowerCase().trim();
    if (clean.contains('3 hour') || clean == '180') return 180;
    if (clean.contains('2 hour') || clean == '120') return 120;
    final parsed = int.tryParse(clean.replaceAll(RegExp(r'[^0-9]'), ''));
    return (parsed != null && parsed > 0) ? parsed : 180;
  }

  static Map<String, String> _inferMetadataFromFileName(String fileName) {
    final result = <String, String>{};
    final lower = fileName.toLowerCase();

    // Infer year (e.g. 2013, 2014)
    final yearMatch = RegExp(r'(20[12][0-9])').firstMatch(fileName);
    if (yearMatch != null) {
      result['year'] = yearMatch.group(1)!;
    }

    // Infer subject
    final subjects = [
      'Biology',
      'Chemistry',
      'Physics',
      'Mathematics',
      'English',
      'History',
      'Geography',
      'Economics',
      'SAT',
    ];
    for (final s in subjects) {
      if (lower.contains(s.toLowerCase())) {
        result['subject'] = s;
        break;
      }
    }

    // Infer stream
    if (lower.contains('social')) {
      result['stream'] = 'Social Science';
    } else {
      result['stream'] = 'Natural Science';
    }

    return result;
  }
}
