import 'package:cloud_firestore/cloud_firestore.dart';

import '../../payment/data/models/payment_submission.dart';
import 'admin_service.dart';
import 'audit_service.dart';

class StudentSummary {
  final String uid;
  final String name;
  final String email;
  final String grade;
  final String stream;
  final bool isPaid;
  final String accessStatus;
  final DateTime? createdAt;

  const StudentSummary({
    required this.uid,
    required this.name,
    required this.email,
    required this.grade,
    required this.stream,
    required this.isPaid,
    required this.accessStatus,
    this.createdAt,
  });

  factory StudentSummary.fromMap(String id, Map<String, dynamic> data) {
    return StudentSummary(
      uid: id,
      name: data['name'] as String? ?? 'Student',
      email: data['email'] as String? ?? '',
      grade: data['grade'] as String? ?? '',
      stream: data['stream'] as String? ?? '',
      isPaid: data['isPaid'] as bool? ?? false,
      accessStatus: data['accessStatus'] as String? ?? 'locked',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AdminStudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _studentsCollection =>
      _firestore.collection('students');

  // ============================================================
  // GET STUDENTS (WITH SEARCH & FILTERS & LIMITS)
  // ============================================================

  Future<List<StudentSummary>> getStudents({
    String? searchQuery,
    String? gradeFilter,
    String? statusFilter,
    int limit = 50,
  }) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) {
      throw Exception('Unauthorized access.');
    }

    Query<Map<String, dynamic>> query = _studentsCollection;

    if (gradeFilter != null && gradeFilter.isNotEmpty && gradeFilter != 'all') {
      query = query.where('grade', isEqualTo: gradeFilter);
    }

    final snapshot = await query.limit(limit).get();

    var list = snapshot.docs
        .map((doc) => StudentSummary.fromMap(doc.id, doc.data()))
        .toList();

    // Filter by payment status if specified
    if (statusFilter != null && statusFilter != 'all') {
      if (statusFilter == 'paid') {
        list = list.where((s) => s.isPaid || s.accessStatus == 'active').toList();
      } else if (statusFilter == 'unpaid') {
        list = list.where((s) => !s.isPaid && s.accessStatus != 'active').toList();
      }
    }

    // Filter by search query (name or email)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) || s.email.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  // ============================================================
  // GET COMPREHENSIVE STUDENT DETAILS
  // ============================================================

  Future<Map<String, dynamic>> getStudentDetails(String uid) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    // 1. Profile
    final doc = await _studentsCollection.doc(uid).get();
    final studentData = doc.data() ?? {};

    // 2. Practice results
    final practiceSnap = await _firestore
        .collection('practice_results')
        .where('userId', isEqualTo: uid)
        .limit(20)
        .get();

    int totalPracticeQuestions = 0;
    int totalPracticeCorrect = 0;
    for (final p in practiceSnap.docs) {
      final data = p.data();
      totalPracticeQuestions += (data['totalQuestions'] as int? ?? 0);
      totalPracticeCorrect += (data['correctAnswers'] as int? ?? 0);
    }

    // 3. Study tasks
    final tasksSnap = await _firestore
        .collection('study_tasks')
        .where('userId', isEqualTo: uid)
        .limit(30)
        .get();

    final totalTasks = tasksSnap.docs.length;
    final completedTasks =
        tasksSnap.docs.where((t) => t.data()['isCompleted'] == true).length;

    // 4. Payment submissions
    final paymentsSnap = await _firestore
        .collection('payment_submissions')
        .where('studentId', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .limit(10)
        .get();

    final payments = paymentsSnap.docs
        .map((p) => PaymentSubmission.fromMap(p.id, p.data()))
        .toList();

    return {
      'profile': StudentSummary.fromMap(uid, studentData),
      'practice': {
        'sessionsCount': practiceSnap.docs.length,
        'totalQuestions': totalPracticeQuestions,
        'totalCorrect': totalPracticeCorrect,
        'accuracy': totalPracticeQuestions > 0
            ? ((totalPracticeCorrect / totalPracticeQuestions) * 100).round()
            : 0,
        'recentSessions': practiceSnap.docs.map((d) => d.data()).toList(),
      },
      'studyPlan': {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
      },
      'payments': payments,
    };
  }

  // ============================================================
  // TOGGLE STUDENT PAID ACCESS
  // ============================================================

  Future<void> toggleStudentPaidAccess(String uid, bool isPaid) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    await _studentsCollection.doc(uid).set({
      'isPaid': isPaid,
      'accessStatus': isPaid ? 'active' : 'locked',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AuditService.logAction(
      action: isPaid ? 'student_access_granted' : 'student_access_revoked',
      targetType: 'student',
      targetId: uid,
      metadata: {'isPaid': isPaid},
    );
  }
}
