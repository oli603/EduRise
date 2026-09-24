import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/offline/offline_storage_service.dart';
import '../../notifications/data/notification_service.dart';
import 'coach_api_client.dart';

class CoachService {
  static final CoachService instance = CoachService._internal();
  CoachService._internal();

  factory CoachService() => instance;

  final CoachApiClient _api = CoachApiClient.instance;
  final OfflineStorageService _storage = OfflineStorageService.instance;

  // =========================================================================
  // 1. PRACTICE & PAST EXAM: EXPLAIN MORE
  // =========================================================================

  Future<Map<String, dynamic>> explainQuestion({
    required String questionId,
    required String questionText,
    required Map<String, String> options,
    required String correctAnswer,
    String? subject,
    String? grade,
    int? unitNumber,
    String? examYear,
    bool forceRefresh = false,
  }) async {
    // 1. Check offline local cache first
    if (!forceRefresh) {
      final cached = _storage.getLocalCoachContent(
        feature: 'explain_more',
        contentId: questionId,
      );
      if (cached != null) {
        return cached;
      }
    }

    // 2. Call backend API
    try {
      final response = await _api.post(
        '/api/questions/explain',
        {
          'question_id': questionId,
          'question_text': questionText,
          'options': options,
          'correct_answer': correctAnswer,
          if (subject != null) 'subject': subject,
          if (grade != null) 'grade': grade,
          if (unitNumber != null) 'unit_number': unitNumber,
          if (examYear != null) 'exam_year': examYear,
        },
      );

      // 3. Save to local offline storage cache
      await _storage.saveCoachContentLocally(
        feature: 'explain_more',
        contentId: questionId,
        content: response,
      );

      return response;
    } catch (e) {
      // If network fails, check if we have any stale cache
      final cached = _storage.getLocalCoachContent(
        feature: 'explain_more',
        contentId: questionId,
      );
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  // =========================================================================
  // 2. TEXTBOOK UNIT TOOLS: SUMMARY, FLASHCARDS, AI NOTES, UNDERSTAND, QUIZ
  // =========================================================================
  // TEXTBOOK EDUCATIONAL AI TOOLS (ACCOUNT-SCOPED & OFFLINE-CAPABLE)
  // =========================================================================

  String _getUnitCacheKey({
    required String feature,
    required String bookId,
    required String unitId,
    String? extra,
  }) {
    String? uid = SessionManager.currentUid;
    if (uid == null || uid.isEmpty) {
      try {
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        uid = null;
      }
    }
    final activeUid = (uid != null && uid.isNotEmpty) ? uid : 'default';
    final base = '${activeUid}_${bookId}_${unitId}_$feature';
    if (extra != null && extra.isNotEmpty) {
      final sanitizedExtra = extra.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      return '${base}_$sanitizedExtra';
    }
    return base;
  }

  int _parseUnitNumber(String unitId, [int? explicitNumber]) {
    if (explicitNumber != null && explicitNumber > 0) return explicitNumber;
    final digits = unitId.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 1;
  }

  Future<Map<String, dynamic>> getUnitSummary({
    required String bookId,
    required String unitId,
    required String unitTitle,
    required String subject,
    required String grade,
    int? unitNumber,
    String? unitContent,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getUnitCacheKey(
      feature: 'summary',
      bookId: bookId,
      unitId: unitId,
    );

    if (!forceRefresh) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_summary',
        contentId: cacheKey,
      );
      if (cached != null) return cached;
    }

    final uNum = _parseUnitNumber(unitId, unitNumber);

    try {
      final response = await _api.post('/api/textbook/summary', {
        'book_id': bookId,
        'unit_id': unitId,
        'unit_number': uNum,
        'unit_name': unitTitle,
        'unit_title': unitTitle,
        'subject': subject,
        'grade': grade,
        'textbook_context': unitContent ?? '',
        if (unitContent != null) 'unit_content': unitContent,
      });

      await _storage.saveCoachContentLocally(
        feature: 'book_summary',
        contentId: cacheKey,
        content: response,
      );

      return response;
    } catch (e) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_summary',
        contentId: cacheKey,
      );
      if (cached != null) return cached;

      final isNetwork = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('offline') ||
          e.toString().toLowerCase().contains('failed host lookup');
      if (isNetwork) {
        throw Exception(
          'Unit Summary is not available offline yet. Please connect to the internet once to generate and save it for offline use.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUnitFlashcards({
    required String bookId,
    required String unitId,
    required String unitTitle,
    required String subject,
    required String grade,
    int? unitNumber,
    String? unitContent,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getUnitCacheKey(
      feature: 'flashcards',
      bookId: bookId,
      unitId: unitId,
    );

    if (!forceRefresh) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_flashcards',
        contentId: cacheKey,
      );
      if (cached != null) return cached;
    }

    final uNum = _parseUnitNumber(unitId, unitNumber);

    try {
      final response = await _api.post('/api/textbook/flashcards', {
        'book_id': bookId,
        'unit_id': unitId,
        'unit_number': uNum,
        'unit_name': unitTitle,
        'unit_title': unitTitle,
        'subject': subject,
        'grade': grade,
        'textbook_context': unitContent ?? '',
        if (unitContent != null) 'unit_content': unitContent,
      });

      await _storage.saveCoachContentLocally(
        feature: 'book_flashcards',
        contentId: cacheKey,
        content: response,
      );

      return response;
    } catch (e) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_flashcards',
        contentId: cacheKey,
      );
      if (cached != null) return cached;

      final isNetwork = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('offline') ||
          e.toString().toLowerCase().contains('failed host lookup');
      if (isNetwork) {
        throw Exception(
          'Flashcards are not available offline yet. Please connect to the internet once to generate and save them for offline use.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUnitAiNotes({
    required String bookId,
    required String unitId,
    required String unitTitle,
    required String subject,
    required String grade,
    int? unitNumber,
    String? unitContent,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getUnitCacheKey(
      feature: 'notes',
      bookId: bookId,
      unitId: unitId,
    );

    if (!forceRefresh) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_notes',
        contentId: cacheKey,
      );
      if (cached != null) return cached;
    }

    final uNum = _parseUnitNumber(unitId, unitNumber);

    try {
      final response = await _api.post('/api/textbook/ai-notes', {
        'book_id': bookId,
        'unit_id': unitId,
        'unit_number': uNum,
        'unit_name': unitTitle,
        'unit_title': unitTitle,
        'subject': subject,
        'grade': grade,
        'textbook_context': unitContent ?? '',
        if (unitContent != null) 'unit_content': unitContent,
      });

      await _storage.saveCoachContentLocally(
        feature: 'book_notes',
        contentId: cacheKey,
        content: response,
      );

      return response;
    } catch (e) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_notes',
        contentId: cacheKey,
      );
      if (cached != null) return cached;

      final isNetwork = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('offline') ||
          e.toString().toLowerCase().contains('failed host lookup');
      if (isNetwork) {
        throw Exception(
          'AI Notes are not available offline yet. Please connect to the internet once to generate and save them for offline use.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUnitUnderstand({
    required String bookId,
    required String unitId,
    required String unitTitle,
    required String subject,
    required String grade,
    int? unitNumber,
    String? specificConcept,
    String? unitContent,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getUnitCacheKey(
      feature: 'understand',
      bookId: bookId,
      unitId: unitId,
      extra: specificConcept,
    );

    if (!forceRefresh) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_understand',
        contentId: cacheKey,
      );
      if (cached != null) return cached;
    }

    final uNum = _parseUnitNumber(unitId, unitNumber);

    try {
      final response = await _api.post('/api/textbook/understand-unit', {
        'book_id': bookId,
        'unit_id': unitId,
        'unit_number': uNum,
        'unit_name': unitTitle,
        'unit_title': unitTitle,
        'subject': subject,
        'grade': grade,
        if (specificConcept != null && specificConcept.trim().isNotEmpty)
          'specific_concept': specificConcept.trim(),
        'textbook_context': unitContent ?? '',
        if (unitContent != null) 'unit_content': unitContent,
      });

      await _storage.saveCoachContentLocally(
        feature: 'book_understand',
        contentId: cacheKey,
        content: response,
      );

      return response;
    } catch (e) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_understand',
        contentId: cacheKey,
      );
      if (cached != null) return cached;

      final isNetwork = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('offline') ||
          e.toString().toLowerCase().contains('failed host lookup');
      if (isNetwork) {
        throw Exception(
          'Understand This Unit explanation is not available offline yet. Please connect to the internet once to generate and save it for offline use.',
        );
      }
      rethrow;
    }
  }

  /// Generates exactly 7 questions for unit quiz.
  /// IMPORTANT: Scores are evaluated locally in memory and NEVER persisted.
  Future<Map<String, dynamic>> getUnitQuiz({
    required String bookId,
    required String unitId,
    required String unitTitle,
    required String subject,
    required String grade,
    int? unitNumber,
    String? unitContent,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getUnitCacheKey(
      feature: 'quiz',
      bookId: bookId,
      unitId: unitId,
    );

    if (!forceRefresh) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_quiz',
        contentId: cacheKey,
      );
      if (cached != null) return cached;
    }

    final uNum = _parseUnitNumber(unitId, unitNumber);

    try {
      final response = await _api.post('/api/textbook/quiz', {
        'book_id': bookId,
        'unit_id': unitId,
        'unit_number': uNum,
        'unit_name': unitTitle,
        'unit_title': unitTitle,
        'subject': subject,
        'grade': grade,
        'textbook_context': unitContent ?? '',
        if (unitContent != null) 'unit_content': unitContent,
      });

      await _storage.saveCoachContentLocally(
        feature: 'book_quiz',
        contentId: cacheKey,
        content: response,
      );

      return response;
    } catch (e) {
      final cached = await _storage.getLocalCoachContentAsync(
        feature: 'book_quiz',
        contentId: cacheKey,
      );
      if (cached != null) return cached;

      final isNetwork = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('offline') ||
          e.toString().toLowerCase().contains('failed host lookup');
      if (isNetwork) {
        throw Exception(
          'Unit Quiz is not available offline yet. Please connect to the internet once to generate and save it for offline use.',
        );
      }
      rethrow;
    }
  }

  // =========================================================================
  // 3. PREDICTED MOCK EXAM
  // =========================================================================

  Future<Map<String, dynamic>> getPredictedMockExam({
    required String subject,
    required String stream,
    int questionCount = 50,
    int durationMinutes = 120,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'mock_${subject}_${stream}_$questionCount';
    if (!forceRefresh) {
      final cached = _storage.getLocalCoachContent(
        feature: 'mock_exam',
        contentId: cacheKey,
      );
      if (cached != null) return cached;
    }

    final response = await _api.post('/api/mock-exams/generate', {
      'subject': subject,
      'stream': stream,
      'question_count': questionCount,
      'duration_minutes': durationMinutes,
    });

    await _storage.saveCoachContentLocally(
      feature: 'mock_exam',
      contentId: cacheKey,
      content: response,
    );

    return response;
  }

  // =========================================================================
  // 4. EDU-RISE COACH CHAT
  // =========================================================================

  Future<Map<String, dynamic>> sendCoachChat({
    required String message,
    required List<Map<String, String>> history,
    String? subject,
    String? grade,
  }) async {
    return await _api.post('/api/coach/chat', {
      'message': message,
      'history': history,
      if (subject != null) 'subject': subject,
      if (grade != null) 'grade': grade,
    });
  }

  Future<Map<String, dynamic>> getCoachStatus() async {
    return await _api.get('/api/coach/status');
  }

  // =========================================================================
  // 5. QUESTION REPORTING SYSTEM
  // =========================================================================

  Future<Map<String, dynamic>> reportQuestion({
    required String questionId,
    required String questionType,
    required String reason,
    required String details,
    String? subject,
    String? grade,
    String? unitOrYear,
    String? correctAnswer,
    String? studentAnswer,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final uid = authUser?.uid ?? SessionManager.currentUid;
    if (uid == null || uid.isEmpty) {
      throw Exception('You must be signed in to submit a question report.');
    }

    final reasonSlug = reason.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final docId = 'qrep_${questionId}_${uid}_$reasonSlug';

    bool firestoreSuccess = false;
    Object? firestoreError;

    // 1. Direct authoritative Firestore write (create vs update distinction)
    try {
      final docRef = FirebaseFirestore.instance.collection('question_reports').doc(docId);

      final updateData = <String, dynamic>{
        'lastReportedAt': FieldValue.serverTimestamp(),
        if (details.isNotEmpty) 'details': details,
        if (correctAnswer != null) 'correct_answer': correctAnswer,
        if (studentAnswer != null) 'student_answer': studentAnswer,
      };

      final createData = <String, dynamic>{
        'id': docId,
        'question_id': questionId,
        'question_type': questionType,
        'reason': reason,
        'subject': subject ?? 'General',
        'grade': grade ?? 'Grade 12',
        'unit_or_year': unitOrYear ?? '1',
        if (correctAnswer != null) 'correct_answer': correctAnswer,
        if (studentAnswer != null) 'student_answer': studentAnswer,
        'uid': uid,
        'status': 'pending',
        'lastReportedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        if (details.isNotEmpty) 'details': details,
      };

      try {
        // Attempt update first to preserve admin status, admin_notes, and original createdAt
        await docRef.update(updateData);
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          await docRef.set(createData);
        } else {
          rethrow;
        }
      } catch (err) {
        if (err.toString().contains('not-found') || err.toString().contains('NOT_FOUND')) {
          await docRef.set(createData);
        } else {
          rethrow;
        }
      }

      firestoreSuccess = true;
    } catch (e) {
      firestoreError = e;
    }

    // 2. Also forward to backend FastAPI reporting service if available
    try {
      final res = await _api.post('/api/reports/submit', {
        'question_id': questionId,
        'question_type': questionType,
        'reason': reason,
        'details': details,
        if (subject != null) 'subject': subject,
        if (grade != null) 'grade': grade,
        if (unitOrYear != null) 'unit_or_year': unitOrYear,
        if (correctAnswer != null) 'correct_answer': correctAnswer,
        if (studentAnswer != null) 'student_answer': studentAnswer,
      });

      // Asynchronously trigger admin notification (non-fatal)
      _sendQuestionReportNotification(
        questionId: questionId,
        reason: reason,
        subject: subject,
        uid: uid,
      );

      return res;
    } catch (backendError) {
      if (firestoreSuccess) {
        // Asynchronously trigger admin notification (non-fatal)
        _sendQuestionReportNotification(
          questionId: questionId,
          reason: reason,
          subject: subject,
          uid: uid,
        );
        return {'status': 'success', 'message': 'Report recorded.'};
      }
      throw Exception(
        firestoreError?.toString() ??
            'Failed to submit report. Please check your internet connection.',
      );
    }
  }

  void _sendQuestionReportNotification({
    required String questionId,
    required String reason,
    String? subject,
    required String uid,
  }) {
    try {
      NotificationService().sendStudentAdminAlert(
        title: 'New Question Accuracy Report',
        body: 'Question $questionId (${subject ?? "General"}) reported for "$reason".',
        type: 'admin_alert',
        metadata: {
          'questionId': questionId,
          'reason': reason,
          'subject': subject,
          'uid': uid,
        },
      );
    } catch (e) {
      debugPrint('CoachService: Question report admin alert creation failed (non-fatal): $e');
    }
  }

  // Admin reporting endpoints
  Future<List<dynamic>> getAdminReports({String? status, String? subject}) async {
    // 1. Try FastAPI backend first
    try {
      final params = <String, String>{
        if (status case final s?) 'status': s,
        if (subject case final sub?) 'subject': sub,
      };
      final dynamic res = await _api.get('/api/reports/', queryParams: params);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map && res['items'] is List) {
        items = res['items'] as List;
      }
      if (items.isNotEmpty) return items;
    } catch (_) {}

    // 2. Fallback to Firestore question_reports
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('question_reports');
      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.where('status', isEqualTo: status);
      }
      if (subject != null && subject.isNotEmpty) {
        query = query.where('subject', isEqualTo: subject);
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 5));
      final Map<String, Map<String, dynamic>> aggregatedReports = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final qId = data['question_id']?.toString() ?? doc.id;
        final rReason = data['reason']?.toString() ?? 'Issue';
        final key = '${qId}_$rReason';
        final reporterUid = data['uid']?.toString() ?? '';
        final detail = data['details']?.toString() ?? '';
        final adminNotes = data['admin_notes']?.toString();
        final itemStatus = data['status']?.toString() ?? 'pending';

        if (!aggregatedReports.containsKey(key)) {
          aggregatedReports[key] = {
            'id': doc.id,
            'doc_ids': <String>[doc.id],
            'question_id': qId,
            'question_type': data['question_type'] ?? 'practice',
            'reason': rReason,
            'subject': data['subject'] ?? 'General',
            'grade': data['grade'] ?? 'Grade 12',
            'unit_or_year': data['unit_or_year'] ?? '1',
            'correct_answer': data['correct_answer'],
            'student_answer': data['student_answer'],
            'status': itemStatus,
            'admin_notes': adminNotes,
            'reporterUids': reporterUid.isNotEmpty ? <String>[reporterUid] : <String>[],
            'distinct_students': reporterUid.isNotEmpty ? <String>[reporterUid] : <String>[],
            'recentFeedback': detail.isNotEmpty ? <String>[detail] : <String>[],
            'lastReportedAt': data['lastReportedAt'],
          };
        } else {
          final agg = aggregatedReports[key]!;
          (agg['doc_ids'] as List<String>).add(doc.id);
          if (reporterUid.isNotEmpty && !(agg['reporterUids'] as List<String>).contains(reporterUid)) {
            (agg['reporterUids'] as List<String>).add(reporterUid);
            (agg['distinct_students'] as List<String>).add(reporterUid);
          }
          if (detail.isNotEmpty && !(agg['recentFeedback'] as List<String>).contains(detail)) {
            (agg['recentFeedback'] as List<String>).add(detail);
          }
          if (adminNotes != null && adminNotes.isNotEmpty) {
            agg['admin_notes'] = adminNotes;
          }
        }
      }

      final firestoreItems = aggregatedReports.values.map((item) {
        item['report_count'] = (item['reporterUids'] as List).length;
        return item;
      }).toList();

      firestoreItems.sort((a, b) {
        final countA = (a['report_count'] as num?)?.toInt() ?? 1;
        final countB = (b['report_count'] as num?)?.toInt() ?? 1;
        return countB.compareTo(countA);
      });

      return firestoreItems;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
    List<String>? docIds,
  }) async {
    // Update in Firestore
    try {
      final idsToUpdate = docIds != null && docIds.isNotEmpty ? docIds : [reportId];
      final batch = FirebaseFirestore.instance.batch();
      for (final id in idsToUpdate) {
        final ref = FirebaseFirestore.instance.collection('question_reports').doc(id);
        batch.set(ref, {
          'status': status,
          if (adminNotes != null) 'admin_notes': adminNotes,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {}

    // Also update in FastAPI if available
    try {
      return await _api.patch('/api/reports/$reportId', {
        'status': status,
        if (adminNotes case final notes?) 'admin_notes': notes,
      });
    } catch (_) {
      return {'status': 'success', 'reportId': reportId};
    }
  }
}
