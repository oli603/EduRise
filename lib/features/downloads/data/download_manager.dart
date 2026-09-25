import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/auth/access_service.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/offline/models/download_package_record.dart';
import '../../../core/offline/stores/package_store.dart';
import '../../books/data/book_download_service.dart';
import '../../books/data/book_service.dart';
import '../../past_entrance_exams/data/past_exam_download_service.dart';
import '../../past_entrance_exams/data/past_exam_service.dart';
import '../../practice/data/local/question_store.dart';
import '../../practice/data/question_model.dart';
import '../../practice/data/question_service.dart';

enum PackageDownloadState {
  notDownloaded,
  downloading,
  downloaded,
  failed,
  updateAvailable,
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal() {
    SessionManager.registerResetListener(_resetActiveStates);
  }

  PackageStore get _packageStore => PackageStore();
  QuestionStore get _questionStore => QuestionStore();
  BookService get _bookService => BookService();
  BookDownloadService get _bookDownloadService => BookDownloadService();
  QuestionService get _questionService => QuestionService();
  PastExamService get _pastExamService => PastExamService();
  PastExamDownloadService get _pastExamDownloadService => PastExamDownloadService();

  // Account-scoped active download states: userId -> (packageId -> progress / state)
  final Map<String, Map<String, double>> _userDownloadProgress = {};
  final Map<String, Map<String, PackageDownloadState>> _userActiveStates = {};

  final StreamController<String> _statusUpdateController =
      StreamController<String>.broadcast();

  Stream<String> get onStatusChanged => _statusUpdateController.stream;

  String _resolveUid(String? explicitUid) {
    if (explicitUid != null && explicitUid.isNotEmpty) return explicitUid;
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    } catch (_) {}
    final sessionUid = SessionManager.currentUid;
    if (sessionUid != null && sessionUid.isNotEmpty) return sessionUid;
    return 'default_user';
  }

  void _resetActiveStates() {
    _userDownloadProgress.clear();
    _userActiveStates.clear();
  }

  double getProgress(String packageId, {String? uid}) {
    final targetUid = _resolveUid(uid);
    return _userDownloadProgress[targetUid]?[packageId] ?? 0.0;
  }

  PackageDownloadState? getActiveState(String packageId, {String? uid}) {
    final targetUid = _resolveUid(uid);
    return _userActiveStates[targetUid]?[packageId];
  }

  Future<PackageDownloadState> getPackageState(String packageId, {String? uid}) async {
    final targetUid = _resolveUid(uid);
    if (_userActiveStates[targetUid]?.containsKey(packageId) == true) {
      return _userActiveStates[targetUid]![packageId]!;
    }
    final pkg = await _packageStore.getPackage(packageId, uid: targetUid);
    if (pkg == null) {
      return PackageDownloadState.notDownloaded;
    }
    if (pkg.status == 'failed') {
      return PackageDownloadState.failed;
    }
    if (pkg.status == 'updateAvailable') {
      return PackageDownloadState.updateAvailable;
    }
    return PackageDownloadState.downloaded;
  }

  Future<bool> isDownloaded(String packageId, {String? uid}) async {
    final state = await getPackageState(packageId, uid: uid);
    return state == PackageDownloadState.downloaded;
  }

  void _setState(
    String packageId,
    PackageDownloadState state, {
    double progress = 0.0,
    String? uid,
  }) {
    final targetUid = _resolveUid(uid);
    _userActiveStates.putIfAbsent(targetUid, () => {})[packageId] = state;
    _userDownloadProgress.putIfAbsent(targetUid, () => {})[packageId] = progress;
    _statusUpdateController.add(packageId);
  }

  // ============================================================
  // BOOK DOWNLOAD (DOWNLOAD ALL UNITS)
  //
  // One Book = Grade + Subject
  // Package ID represents the academic content identity: book_${grade}_${subject}
  // Ownership is strictly defined by UID + Package ID
  // ============================================================

  String getBookPackageId({
    required String grade,
    required String subject,
    String? stream,
  }) {
    final g = grade.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final s = subject.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final str = stream?.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    if (str != null && str.isNotEmpty) {
      return 'book_${g}_${str}_$s';
    }
    return 'book_${g}_$s';
  }

  Future<void> downloadBookPackage({
    required String grade,
    required String subject,
    String? stream,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final canonicalStream = stream != null && stream.trim().isNotEmpty
        ? (stream.trim().toLowerCase().contains('social') ? 'social' : 'natural')
        : (EduRiseSubjects.isSocialStream(subject) ? 'social' : 'natural');
    final packageId = getBookPackageId(grade: grade, subject: subject, stream: canonicalStream);
    final hasAccess = await AccessService.hasPaidAccess();
    if (!hasAccess) {
      throw Exception('Paid access is required to download this book.');
    }

    final capturedEpoch = SessionManager.sessionEpoch;
    _setState(packageId, PackageDownloadState.downloading, progress: 0.01, uid: targetUid);

    try {
      final units = await _bookService.getUnits(grade: grade, subject: subject);
      if (units.isEmpty) {
        throw Exception('No units found for $grade $subject.');
      }

      int totalBytes = 0;
      final unitIds = <String>[];
      final unitDataList = <Map<String, dynamic>>[];
      int successfulUnits = 0;
      String? lastUnitError;

      for (var i = 0; i < units.length; i++) {
        if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch) &&
            targetUid != 'default_user') {
          debugPrint('DownloadManager: Abandoning book download because session changed.');
          return;
        }

        final unit = units[i];
        unitIds.add(unit.id);
        unitDataList.add({'id': unit.id, ...unit.toMap()});

        final alreadyDownloaded = await _bookDownloadService.isDownloaded(unit.id, uid: targetUid);
        if (alreadyDownloaded) {
          final existingFile = await _bookDownloadService.getLocalBookFile(unit.id);
          if (existingFile != null) {
            totalBytes += await existingFile.length();
          }
          successfulUnits++;
          final progress = (i + 1.0) / units.length;
          _userDownloadProgress.putIfAbsent(targetUid, () => {})[packageId] = progress;
          _statusUpdateController.add(packageId);
          continue;
        }

        if (unit.pdfUrl.trim().isNotEmpty) {
          try {
            final file = await _bookDownloadService.downloadBook(
              bookId: unit.id,
              pdfUrl: unit.pdfUrl,
              uid: targetUid,
              onProgress: (unitProgress) {
                final overall = (i + unitProgress) / units.length;
                _userDownloadProgress.putIfAbsent(targetUid, () => {})[packageId] = overall;
                _statusUpdateController.add(packageId);
              },
            );
            totalBytes += await file.length();
            successfulUnits++;
          } catch (unitError) {
            debugPrint('Failed to download unit ${unit.unitNumber} (${unit.id}): $unitError');
            lastUnitError = unitError.toString();
          }
        }
      }

      if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch) &&
          targetUid != 'default_user') {
        return;
      }

      if (successfulUnits == 0 && units.isNotEmpty) {
        throw Exception(lastUnitError ?? 'All PDF unit downloads failed.');
      }

      final record = DownloadPackageRecord(
        id: packageId,
        userId: targetUid,
        packageType: 'book',
        title: '$grade $subject Textbook',
        grade: grade,
        stream: canonicalStream,
        subject: subject,
        version: 1,
        itemCount: successfulUnits,
        sizeBytes: totalBytes,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
        extraData: {
          'unitIds': unitIds,
          'units': unitDataList,
          'totalUnits': units.length,
          'downloadedUnits': successfulUnits,
        },
      );

      await _packageStore.savePackage(record, uid: targetUid);
      _setState(packageId, PackageDownloadState.downloaded, progress: 1.0, uid: targetUid);
    } catch (e) {
      _setState(packageId, PackageDownloadState.failed, uid: targetUid);
      rethrow;
    }
  }

  Future<void> deleteBookPackage({
    required String grade,
    required String subject,
    String? stream,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final packageId = getBookPackageId(grade: grade, subject: subject, stream: stream);
    final pkg = await _packageStore.getPackage(packageId, uid: targetUid);
    if (pkg != null) {
      final unitIds = (pkg.extraData['unitIds'] as List?)?.cast<String>() ?? [];
      for (final id in unitIds) {
        await _bookDownloadService.deleteBook(id, uid: targetUid);
      }
      await _packageStore.deletePackageRecord(packageId, uid: targetUid);
    }
    _userActiveStates[targetUid]?.remove(packageId);
    _userDownloadProgress[targetUid]?.remove(packageId);
    _statusUpdateController.add(packageId);
  }

  // ============================================================
  // QUESTION PACKAGE DOWNLOAD (PRACTICE)
  // ============================================================

  String getPracticePackageId({
    required String grade,
    required String subject,
    String? stream,
    int? unitNumber,
    dynamic examYear,
  }) {
    final g = grade.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final s = subject.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final str = stream != null && stream.trim().isNotEmpty
        ? (stream.trim().toLowerCase().contains('social') ? 'social' : 'natural')
        : '';
    final u = unitNumber != null && unitNumber > 0 ? '_u$unitNumber' : '';
    final y = examYear != null && examYear.toString().trim().isNotEmpty ? '_y$examYear' : '';

    if (str.isNotEmpty) {
      return 'practice_${g}_${str}_$s$u$y';
    }
    return 'practice_${g}_$s$u$y';
  }

  String getPracticeSubjectBatchKey({
    required String grade,
    required String subject,
    String? stream,
    dynamic examYear,
  }) {
    final g = grade.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final s = subject.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final str = stream != null && stream.trim().isNotEmpty
        ? (stream.trim().toLowerCase().contains('social') ? 'social' : 'natural')
        : 'natural';
    final y = examYear != null && examYear.toString().trim().isNotEmpty ? '_y$examYear' : '';
    return 'practice_batch_${g}_${str}_$s$y';
  }

  Future<void> downloadPracticePackage({
    required String grade,
    required String stream,
    required String subject,
    int? unitNumber,
    String? unitName,
    dynamic examYear,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final packageId = getPracticePackageId(
      grade: grade,
      stream: stream,
      subject: subject,
      unitNumber: unitNumber,
      examYear: examYear,
    );

    final capturedEpoch = SessionManager.sessionEpoch;
    _setState(packageId, PackageDownloadState.downloading, progress: 0.1, uid: targetUid);

    try {
      final parsedYear = examYear is int
          ? examYear
          : (examYear is String ? int.tryParse(examYear) : null);
      final questions = await _questionService.getPublishedQuestions(
        grade: grade,
        stream: stream,
        subject: subject,
        unitNumber: unitNumber ?? 0,
        examYear: parsedYear,
      );

      if (questions.isEmpty) {
        throw Exception('No questions available to download for this package.');
      }

      if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch) &&
          targetUid != 'default_user') {
        return;
      }

      _userDownloadProgress.putIfAbsent(targetUid, () => {})[packageId] = 0.6;
      _statusUpdateController.add(packageId);

      await _questionStore.saveQuestions(questions);

      final title = unitNumber != null && unitNumber > 0
          ? '$grade $subject - Unit $unitNumber'
          : '$grade $subject Practice';

      final record = DownloadPackageRecord(
        id: packageId,
        userId: targetUid,
        packageType: 'practice',
        title: title,
        grade: grade,
        stream: stream,
        subject: subject,
        unitNumber: unitNumber,
        unitName: unitName,
        examYear: parsedYear,
        version: 1,
        itemCount: questions.length,
        sizeBytes: questions.length * 512,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
        extraData: {
          'questionIds': questions.map((q) => q.id).toList(),
        },
      );

      await _packageStore.savePackage(record, uid: targetUid);
      _setState(packageId, PackageDownloadState.downloaded, progress: 1.0, uid: targetUid);
    } catch (e) {
      _setState(packageId, PackageDownloadState.failed, uid: targetUid);
      rethrow;
    }
  }

  Future<void> downloadAllPracticeUnitsForSubject({
    required String grade,
    required String stream,
    required String subject,
    dynamic examYear,
    String? uid,
  }) async {
    return downloadAllUnitsForSubject(
      grade: grade,
      stream: stream,
      subject: subject,
      examYear: examYear,
      uid: uid,
    );
  }

  Future<void> deletePracticePackage({
    required String grade,
    String? stream,
    required String subject,
    int? unitNumber,
    dynamic examYear,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final packageId = getPracticePackageId(
      grade: grade,
      stream: stream,
      subject: subject,
      unitNumber: unitNumber,
      examYear: examYear,
    );
    final pkg = await _packageStore.getPackage(packageId, uid: targetUid);
    if (pkg != null) {
      final qIds = (pkg.extraData['questionIds'] as List?)?.cast<String>() ?? [];
      if (qIds.isNotEmpty) {
        final isReferenced = await _packageStore.isPhysicalFileReferencedByOtherUsers(
          currentUid: targetUid,
          questionIds: qIds,
        );
        if (!isReferenced) {
          await _questionStore.removeQuestionsByIds(qIds);
        }
      }
      await _packageStore.deletePackageRecord(packageId, uid: targetUid);
    }
    _userActiveStates[targetUid]?.remove(packageId);
    _userDownloadProgress[targetUid]?.remove(packageId);
    _statusUpdateController.add(packageId);
  }

  // ============================================================
  // PAST EXAM PACKAGE DOWNLOAD
  // ============================================================

  String getPastExamPackageId({
    String? examId,
    dynamic year,
    String? stream,
    String? subject,
  }) {
    if (examId != null && examId.trim().isNotEmpty) {
      final cleanId = examId.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      return 'past_exam_$cleanId';
    }
    final y = year?.toString().trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_') ?? '';
    final str = (stream ?? '').trim().toLowerCase().contains('social') ? 'social' : 'natural';
    final sub = (subject ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'past_exam_${y}_${str}_$sub';
  }

  String getPastExamYearBatchKey({
    required dynamic year,
    required String stream,
  }) {
    final y = year.toString().trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final str = stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';
    return 'past_exam_batch_${y}_$str';
  }

  Future<void> downloadAllPastExamsForYear({
    required dynamic year,
    required String stream,
    required List<String> subjects,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final batchKey = getPastExamYearBatchKey(year: year, stream: stream);
    _setState(batchKey, PackageDownloadState.downloading, progress: 0.01, uid: targetUid);

    try {
      int completed = 0;
      int successfulDownloads = 0;
      final yearStr = year.toString();
      final canonicalStream = stream.trim().toLowerCase().contains('social') ? 'social' : 'natural';

      for (final subject in subjects) {
        try {
          final cleanSub = subject.trim().toLowerCase().replaceAll(' ', '_');
          final examId = '${yearStr}_${canonicalStream}_$cleanSub';
          await downloadPastExamPackage(
            examId: examId,
            title: '$yearStr $subject Entrance Exam',
            subject: subject,
            examYear: int.tryParse(yearStr) ?? 0,
            stream: canonicalStream,
            uid: targetUid,
          );
          successfulDownloads++;
        } catch (e) {
          debugPrint('Download past exam warning for $subject: $e');
        }
        completed++;
        _userDownloadProgress.putIfAbsent(targetUid, () => {})[batchKey] =
            completed / (subjects.isNotEmpty ? subjects.length : 1);
        _statusUpdateController.add(batchKey);
      }
      if (successfulDownloads == 0 && subjects.isNotEmpty) {
        throw Exception('No entrance exams could be downloaded or saved for $yearStr $stream.');
      }
      _setState(batchKey, PackageDownloadState.downloaded, progress: 1.0, uid: targetUid);
    } catch (e) {
      _setState(batchKey, PackageDownloadState.failed, uid: targetUid);
      rethrow;
    }
  }

  Future<void> downloadPastExamPackage({
    String? examId,
    String? title,
    String? subject,
    int? examYear,
    dynamic year,
    String? stream,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final effectiveYear = (year ?? examYear)?.toString() ?? '';
    final effectiveSubject = subject ?? '';
    final effectiveStream = (stream ?? '').toLowerCase().contains('social') ? 'social' : 'natural';
    final effectiveExamId = (examId != null && examId.trim().isNotEmpty)
        ? examId.trim()
        : '${effectiveYear}_${effectiveStream}_${effectiveSubject.toLowerCase().replaceAll(' ', '_')}';
    final effectiveTitle = title ?? '$effectiveYear $effectiveSubject Entrance Exam';
    final effectiveExamYear = examYear ?? int.tryParse(effectiveYear) ?? 0;

    final packageId = getPastExamPackageId(examId: effectiveExamId);
    final hasAccess = await AccessService.hasPaidAccess();
    if (!hasAccess) {
      throw Exception('Paid access is required to download past entrance exams.');
    }

    final capturedEpoch = SessionManager.sessionEpoch;
    _setState(packageId, PackageDownloadState.downloading, progress: 0.1, uid: targetUid);

    try {
      final exam = await _pastExamService.getPastExam(effectiveExamId);
      if (exam == null) {
        throw Exception('Exam metadata not found.');
      }

      int totalBytes = 0;

      // 1. Download exam locally
      try {
        await _pastExamDownloadService.downloadExam(examId: effectiveExamId, uid: targetUid);
      } catch (e) {
        debugPrint('Past exam download notice: $e');
      }

      if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch) &&
          targetUid != 'default_user') {
        return;
      }

      final downloadedExam =
          await _pastExamDownloadService.getDownloadedPastExamModel(examId: effectiveExamId) ?? exam;
      final questions = downloadedExam.questions;
      if (questions.isNotEmpty) {
        // Guarantee local JSON file is persisted on disk for PastExamDownloadService
        try {
          await _pastExamDownloadService.saveDownloadedExamData(
            effectiveExamId,
            downloadedExam.toMap(),
            uid: targetUid,
          );
        } catch (_) {}

        final practiceQuestions = questions.map((eq) {
          return Question(
            id: eq.id?.isNotEmpty == true ? eq.id! : '${effectiveExamId}_q${eq.questionNumber}',
            subject: effectiveSubject,
            grade: 'Grade 12',
            stream: effectiveStream,
            unitNumber: 0,
            unitName: '$effectiveYear Entrance Exam',
            examYear: effectiveExamYear,
            examType: 'entrance',
            questionNumber: eq.questionNumber,
            question: eq.questionText,
            questionImageUrl: eq.imageUrl,
            options: [eq.optionA, eq.optionB, eq.optionC, eq.optionD],
            correctAnswer: eq.correctAnswer,
            explanation: eq.explanation,
            status: 'published',
          );
        }).toList();
        await _questionStore.saveQuestions(practiceQuestions);
        totalBytes += questions.length * 512;
      }

      final record = DownloadPackageRecord(
        id: packageId,
        userId: targetUid,
        packageType: 'past_exam',
        title: effectiveTitle,
        subject: effectiveSubject,
        stream: effectiveStream,
        examYear: effectiveExamYear,
        version: 1,
        itemCount: questions.length,
        sizeBytes: totalBytes,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
        extraData: {
          'examId': effectiveExamId,
          'questionCount': questions.length,
          'questionIds':
              questions.map((q) => q.id ?? '${effectiveExamId}_q${q.questionNumber}').toList(),
        },
      );

      await _packageStore.savePackage(record, uid: targetUid);
      _setState(packageId, PackageDownloadState.downloaded, progress: 1.0, uid: targetUid);
    } catch (e) {
      _setState(packageId, PackageDownloadState.failed, uid: targetUid);
      rethrow;
    }
  }

  Future<void> removeDownload(String packageId, {String? uid}) async {
    final targetUid = _resolveUid(uid);
    final pkg = await _packageStore.getPackage(packageId, uid: targetUid);
    if (pkg == null) {
      await _packageStore.deletePackageRecord(packageId, uid: targetUid);
      _userActiveStates[targetUid]?.remove(packageId);
      _userDownloadProgress[targetUid]?.remove(packageId);
      _statusUpdateController.add(packageId);
      return;
    }
    if (pkg.packageType == 'book') {
      final g = pkg.grade ?? '';
      final s = pkg.subject;
      if (g.isNotEmpty && s.isNotEmpty) {
        await deleteBookPackage(grade: g, subject: s, stream: pkg.stream, uid: targetUid);
        return;
      }
    } else if (pkg.packageType == 'past_exam') {
      final examId = pkg.extraData['examId'] as String? ?? pkg.id;
      await deletePastExamPackage(examId: examId, uid: targetUid);
      return;
    } else if (pkg.packageType == 'practice') {
      final g = pkg.grade ?? '';
      final s = pkg.subject;
      final u = pkg.unitNumber;
      if (g.isNotEmpty && s.isNotEmpty) {
        await deletePracticePackage(
          grade: g,
          stream: pkg.stream,
          subject: s,
          unitNumber: u,
          examYear: pkg.examYear,
          uid: targetUid,
        );
        return;
      }
    }
    await _packageStore.deletePackageRecord(packageId, uid: targetUid);
    _userActiveStates[targetUid]?.remove(packageId);
    _userDownloadProgress[targetUid]?.remove(packageId);
    _statusUpdateController.add(packageId);
  }

  Future<void> deletePastExamPackage({
    required String examId,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final packageId = getPastExamPackageId(examId: examId);
    final pkg = await _packageStore.getPackage(packageId, uid: targetUid);
    if (pkg != null) {
      await _pastExamDownloadService.deleteDownloadedExam(examId: examId, uid: targetUid);
      final qIds = (pkg.extraData['questionIds'] as List?)?.cast<String>() ?? [];
      if (qIds.isNotEmpty) {
        final isReferenced = await _packageStore.isPhysicalFileReferencedByOtherUsers(
          currentUid: targetUid,
          questionIds: qIds,
        );
        if (!isReferenced) {
          await _questionStore.removeQuestionsByIds(qIds);
        }
      }
      await _packageStore.deletePackageRecord(packageId, uid: targetUid);
    }
    _userActiveStates[targetUid]?.remove(packageId);
    _userDownloadProgress[targetUid]?.remove(packageId);
    _statusUpdateController.add(packageId);
  }

  // ============================================================
  // BATCH SUBJECT DOWNLOAD (ALL UNITS FOR A SUBJECT)
  // ============================================================

  String getSubjectBatchPackageId({
    required String grade,
    required String stream,
    required String subject,
  }) {
    final g = grade.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final str = stream.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final sub = subject.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'batch_subject_${g}_${str}_$sub';
  }

  Future<void> downloadAllUnitsForSubject({
    required String grade,
    required String stream,
    required String subject,
    dynamic examYear,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final batchPackageId = getPracticeSubjectBatchKey(
      grade: grade,
      stream: stream,
      subject: subject,
      examYear: examYear,
    );
    final legacyBatchId = getSubjectBatchPackageId(
      grade: grade,
      stream: stream,
      subject: subject,
    );

    final capturedEpoch = SessionManager.sessionEpoch;
    _setState(batchPackageId, PackageDownloadState.downloading, progress: 0.05, uid: targetUid);
    _setState(legacyBatchId, PackageDownloadState.downloading, progress: 0.05, uid: targetUid);

    try {
      final allQuestions = await _questionService.getPublishedQuestions(
        grade: grade,
        stream: stream,
        subject: subject,
        unitNumber: 0,
      );

      if (allQuestions.isEmpty) {
        throw Exception('No published questions found for $grade $subject.');
      }

      if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch) &&
          targetUid != 'default_user') {
        return;
      }

      _userDownloadProgress.putIfAbsent(targetUid, () => {})[batchPackageId] = 0.5;
      _userDownloadProgress.putIfAbsent(targetUid, () => {})[legacyBatchId] = 0.5;
      _statusUpdateController.add(batchPackageId);
      _statusUpdateController.add(legacyBatchId);

      await _questionStore.saveQuestions(allQuestions);

      final Map<int, List<String>> unitQuestionMap = {};
      final Map<int, String> unitNameMap = {};

      for (final q in allQuestions) {
        if (q.unitNumber > 0) {
          unitQuestionMap.putIfAbsent(q.unitNumber, () => []).add(q.id);
          if (q.unitName.isNotEmpty) {
            unitNameMap[q.unitNumber] = q.unitName;
          }
        }
      }

      for (final entry in unitQuestionMap.entries) {
        final unitNum = entry.key;
        final unitQIds = entry.value;
        final unitPkgId = getPracticePackageId(
          grade: grade,
          stream: stream,
          subject: subject,
          unitNumber: unitNum,
          examYear: examYear,
        );

        final unitRecord = DownloadPackageRecord(
          id: unitPkgId,
          userId: targetUid,
          packageType: 'practice',
          title: '$grade $subject - Unit $unitNum',
          grade: grade,
          stream: stream,
          subject: subject,
          unitNumber: unitNum,
          unitName: unitNameMap[unitNum],
          version: 1,
          itemCount: unitQIds.length,
          sizeBytes: unitQIds.length * 512,
          downloadedAt: DateTime.now(),
          status: 'downloaded',
          extraData: {
            'questionIds': unitQIds,
            'batchPackageId': batchPackageId,
          },
        );

        await _packageStore.savePackage(unitRecord, uid: targetUid);
        _setState(unitPkgId, PackageDownloadState.downloaded, progress: 1.0, uid: targetUid);
      }

      final batchRecord = DownloadPackageRecord(
        id: batchPackageId,
        userId: targetUid,
        packageType: 'practice',
        title: '$grade $subject (All Units)',
        grade: grade,
        stream: stream,
        subject: subject,
        version: 1,
        itemCount: allQuestions.length,
        sizeBytes: allQuestions.length * 512,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
        extraData: {
          'totalUnits': unitQuestionMap.length,
          'unitNumbers': unitQuestionMap.keys.toList(),
          'questionIds': allQuestions.map((q) => q.id).toList(),
        },
      );

      await _packageStore.savePackage(batchRecord, uid: targetUid);
      _setState(batchPackageId, PackageDownloadState.downloaded, progress: 1.0, uid: targetUid);
      _setState(legacyBatchId, PackageDownloadState.downloaded, progress: 1.0, uid: targetUid);
    } catch (e) {
      _setState(batchPackageId, PackageDownloadState.failed, uid: targetUid);
      _setState(legacyBatchId, PackageDownloadState.failed, uid: targetUid);
      rethrow;
    }
  }

  // ============================================================
  // BATCH GRADE DOWNLOAD (ALL SUBJECTS FOR A GRADE & STREAM)
  // ============================================================

  String getGradeBatchPackageId({
    required String grade,
    required String stream,
  }) {
    final g = grade.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final str = stream.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'batch_grade_${g}_$str';
  }

  Future<void> downloadEntireGrade({
    required String grade,
    required String stream,
    required List<String> subjects,
    String? uid,
  }) async {
    final targetUid = _resolveUid(uid);
    final gradeBatchId = getGradeBatchPackageId(grade: grade, stream: stream);
    final capturedEpoch = SessionManager.sessionEpoch;
    _setState(gradeBatchId, PackageDownloadState.downloading, progress: 0.01, uid: targetUid);

    try {
      int completedSubjects = 0;
      final totalSubjects = subjects.length;

      for (final subject in subjects) {
        if (!SessionManager.isSessionValid(capturedUid: targetUid, capturedEpoch: capturedEpoch) &&
            targetUid != 'default_user') {
          return;
        }

        try {
          await downloadAllUnitsForSubject(
            grade: grade,
            stream: stream,
            subject: subject,
            uid: targetUid,
          );
        } catch (e) {
          debugPrint('Batch download warning for $subject: $e');
        }
        completedSubjects++;
        final prog = completedSubjects / (totalSubjects > 0 ? totalSubjects : 1);
        _userDownloadProgress.putIfAbsent(targetUid, () => {})[gradeBatchId] = prog;
        _statusUpdateController.add(gradeBatchId);
      }

      final gradeRecord = DownloadPackageRecord(
        id: gradeBatchId,
        userId: targetUid,
        packageType: 'practice',
        title: '$grade Complete ($stream)',
        grade: grade,
        stream: stream,
        subject: 'All Subjects',
        version: 1,
        itemCount: completedSubjects,
        downloadedAt: DateTime.now(),
        status: 'downloaded',
        extraData: {
          'subjects': subjects,
          'completedCount': completedSubjects,
        },
      );

      await _packageStore.savePackage(gradeRecord, uid: targetUid);
      _setState(gradeBatchId, PackageDownloadState.downloaded, progress: 1.0, uid: targetUid);
    } catch (e) {
      _setState(gradeBatchId, PackageDownloadState.failed, uid: targetUid);
      rethrow;
    }
  }

  // ============================================================
  // CENTRAL STORAGE SIZE & CLEANUP OPERATIONS
  // ============================================================

  Future<int> getTotalDownloadStorageBytes() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return 0;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory().timeout(
        const Duration(milliseconds: 100),
      );
      int totalBytes = 0;

      // 1. Books directory
      final booksDir = Directory('${appDir.path}/edurise_books');
      if (await booksDir.exists()) {
        final entities = await booksDir.list(recursive: true, followLinks: false).toList();
        for (final entity in entities) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      // 2. Past Exams directory
      final examsDir = Directory('${appDir.path}/edurise_past_exams');
      if (await examsDir.exists()) {
        final entities = await examsDir.list(recursive: true, followLinks: false).toList();
        for (final entity in entities) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      // 3. Offline storage database directory
      final offlineDir = Directory('${appDir.path}/edurise_offline');
      if (await offlineDir.exists()) {
        final entities = await offlineDir.list(recursive: true, followLinks: false).toList();
        for (final entity in entities) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      return totalBytes;
    } catch (e) {
      debugPrint('Error calculating total storage bytes: $e');
      return 0;
    }
  }

  Future<void> clearAllDownloadedContent({String? uid}) async {
    try {
      final targetUid = _resolveUid(uid);
      final packages = await _packageStore.getAllPackages(uid: targetUid);
      for (final pkg in packages) {
        await removeDownload(pkg.id, uid: targetUid);
      }
    } catch (e) {
      debugPrint('Error clearing downloaded content: $e');
    }
  }

  void clearMemoryCache() {
    _resetActiveStates();
  }
}
