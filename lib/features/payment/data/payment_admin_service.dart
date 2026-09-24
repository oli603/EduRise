import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../admin/data/admin_service.dart';
import '../../admin/data/audit_service.dart';
import '../../notifications/data/notification_service.dart';
import 'models/payment_submission.dart';

class PaymentAdminService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final NotificationService? _customNotificationService;

  PaymentAdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _customNotificationService = notificationService;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth =>
      _customAuth ?? FirebaseAuth.instance;
  NotificationService get _notificationService =>
      _customNotificationService ?? NotificationService();

  CollectionReference<Map<String, dynamic>> get _submissionsCollection =>
      _firestore.collection('payment_submissions');

  CollectionReference<Map<String, dynamic>> get _studentsCollection =>
      _firestore.collection('students');

  // ============================================================
  // ADMIN: QUERY SUBMISSIONS (INDEX-RESILIENT)
  // ============================================================

  Future<List<PaymentSubmission>> getSubmissions({
    String? statusFilter,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _submissionsCollection;

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      final snapshot = await query.limit(limit).get();
      final list = snapshot.docs
          .map((doc) => PaymentSubmission.fromMap(doc.id, doc.data()))
          .toList();

      list.sort((a, b) {
        final aTime = a.submittedAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.submittedAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // ADMIN: APPROVE PAYMENT
  // Atomic transaction updating submission, student paid status,
  // notification, and audit log.
  // ============================================================

  Future<void> approvePayment(String submissionId) async {
    final adminUser = _auth.currentUser;
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized || adminUser == null) {
      throw Exception('Unauthorized: Only administrators can approve payments.');
    }

    final role = await AdminService.getCurrentRole();

    String studentId = '';
    String studentEmail = '';
    double amount = 0.0;

    final submissionRef = _submissionsCollection.doc(submissionId);

    // Run atomic transaction
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(submissionRef);
      if (!snapshot.exists) {
        throw Exception('Payment submission not found.');
      }

      final data = snapshot.data()!;
      final currentStatus = data['status'] as String? ?? 'pending';
      if (currentStatus != 'pending') {
        throw Exception('This submission has already been reviewed (status: $currentStatus).');
      }

      studentId = data['studentId'] as String? ?? '';
      studentEmail = data['studentEmail'] as String? ?? '';
      amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

      // Update payment submission
      transaction.update(submissionRef, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUser.uid,
        'reviewerEmail': adminUser.email,
      });

      // Update student document to activate paid access
      if (studentId.isNotEmpty) {
        final studentRef = _studentsCollection.doc(studentId);
        transaction.set(studentRef, {
          'isPaid': true,
          'accessStatus': 'active',
          'paidAt': FieldValue.serverTimestamp(),
          'activePaymentId': submissionId,
        }, SetOptions(merge: true));
      }
    });

    // Send student notification
    if (studentId.isNotEmpty) {
      await _notificationService.sendNotification(
        userId: studentId,
        title: 'Payment Approved 🎉',
        body: 'Your payment has been verified. Your EduRise access is now active.',
        type: 'payment_approved',
        metadata: {'submissionId': submissionId},
      );
    }

    // Record audit log
    await AuditService.logAction(
      action: 'payment_approved',
      targetType: 'payment_submission',
      targetId: submissionId,
      metadata: {
        'studentId': studentId,
        'studentEmail': studentEmail,
        'amount': amount,
        'reviewer': adminUser.email,
        'role': role.value,
      },
    );
  }

  // ============================================================
  // ADMIN: REJECT PAYMENT
  // Atomic transaction updating submission, notifying student,
  // and recording audit log.
  // ============================================================

  Future<void> rejectPayment({
    required String submissionId,
    required String rejectionReason,
  }) async {
    final adminUser = _auth.currentUser;
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized || adminUser == null) {
      throw Exception('Unauthorized: Only administrators can reject payments.');
    }

    final cleanReason = rejectionReason.trim().isEmpty
        ? 'Payment proof could not be verified.'
        : rejectionReason.trim();

    final role = await AdminService.getCurrentRole();

    String studentId = '';

    final submissionRef = _submissionsCollection.doc(submissionId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(submissionRef);
      if (!snapshot.exists) {
        throw Exception('Payment submission not found.');
      }

      final data = snapshot.data()!;
      final currentStatus = data['status'] as String? ?? 'pending';
      if (currentStatus != 'pending') {
        throw Exception('This submission has already been reviewed (status: $currentStatus).');
      }

      studentId = data['studentId'] as String? ?? '';

      transaction.update(submissionRef, {
        'status': 'rejected',
        'rejectionReason': cleanReason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUser.uid,
        'reviewerEmail': adminUser.email,
      });
    });

    // Notify student
    if (studentId.isNotEmpty) {
      await _notificationService.sendNotification(
        userId: studentId,
        title: 'Payment Rejected',
        body: 'Your payment could not be verified: $cleanReason. Please review and resubmit.',
        type: 'payment_rejected',
        metadata: {'submissionId': submissionId, 'reason': cleanReason},
      );
    }

    // Audit log
    await AuditService.logAction(
      action: 'payment_rejected',
      targetType: 'payment_submission',
      targetId: submissionId,
      metadata: {
        'studentId': studentId,
        'reason': cleanReason,
        'reviewer': adminUser.email,
        'role': role.value,
      },
    );
  }
}
