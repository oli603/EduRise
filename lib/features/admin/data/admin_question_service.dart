import 'package:cloud_firestore/cloud_firestore.dart';

import '../../practice/data/question_model.dart';
import 'admin_service.dart';
import 'audit_service.dart';

class AdminQuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _questionsCollection =>
      _firestore.collection('questions');

  // ============================================================
  // QUERY QUESTIONS WITH FILTERS
  // ============================================================

  Future<List<Question>> getAdminQuestions({
    String? grade,
    String? stream,
    String? subject,
    int? unitNumber,
    String? status,
    String? searchQuery,
    int limit = 100,
  }) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    Query<Map<String, dynamic>> query = _questionsCollection;

    if (grade != null && grade.isNotEmpty && grade != 'all') {
      query = query.where('grade', isEqualTo: grade);
    }

    if (stream != null && stream.isNotEmpty && stream != 'all') {
      query = query.where('stream', isEqualTo: stream);
    }

    if (subject != null && subject.isNotEmpty && subject != 'all') {
      query = query.where('subject', isEqualTo: subject);
    }

    if (unitNumber != null && unitNumber > 0) {
      query = query.where('unitNumber', isEqualTo: unitNumber);
    }

    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.limit(limit).get();

    var list = snapshot.docs
        .map((doc) => Question.fromMap(doc.id, doc.data()))
        .toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((item) => item.question.toLowerCase().contains(q)).toList();
    }

    return list;
  }

  // ============================================================
  // COUNT TOTAL QUESTIONS
  // ============================================================

  Future<int> getTotalQuestionsCount() async {
    final snapshot = await _questionsCollection.count().get();
    return snapshot.count ?? 0;
  }

  // ============================================================
  // DELETE QUESTION
  // ============================================================

  Future<void> deleteQuestion(String questionId) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    final doc = await _questionsCollection.doc(questionId).get();
    final data = doc.data() ?? {};

    await _questionsCollection.doc(questionId).delete();

    await AuditService.logAction(
      action: 'question_deleted',
      targetType: 'question',
      targetId: questionId,
      metadata: {
        'subject': data['subject'],
        'grade': data['grade'],
        'unitNumber': data['unitNumber'],
      },
    );
  }

  // ============================================================
  // UPDATE QUESTION STATUS
  // ============================================================

  Future<void> updateQuestionStatus(String questionId, String status) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    await _questionsCollection.doc(questionId).update({'status': status});

    await AuditService.logAction(
      action: 'question_status_updated',
      targetType: 'question',
      targetId: questionId,
      metadata: {'status': status},
    );
  }

  // ============================================================
  // BULK UPDATE QUESTION STATUS
  // ============================================================

  Future<int> updateMultipleQuestionsStatus(
    List<String> questionIds,
    String status,
  ) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');
    if (questionIds.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final id in questionIds) {
      batch.update(_questionsCollection.doc(id), {'status': status});
    }

    await batch.commit();

    await AuditService.logAction(
      action: 'bulk_question_status_updated',
      targetType: 'question',
      targetId: 'bulk',
      metadata: {
        'status': status,
        'count': questionIds.length,
      },
    );

    return questionIds.length;
  }
}
