import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../notifications/data/notification_service.dart';
import 'admin_service.dart';
import 'audit_service.dart';
import 'models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();

  CollectionReference<Map<String, dynamic>> get _submissionsCollection =>
      _firestore.collection('payment_submissions');

  CollectionReference<Map<String, dynamic>> get _studentsCollection =>
      _firestore.collection('students');

  // ============================================================
  // STUDENT: SUBMIT PAYMENT PROOF
  // ============================================================

  Future<String> submitPaymentProof({
    required File receiptFile,
    required String packageId,
    required String packageName,
    required double amount,
    required String paymentMethod,
    required String transactionReference,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found. Please sign in first.');
    }

    if (!receiptFile.existsSync()) {
      throw Exception('Receipt file could not be located.');
    }

    // 1. Fetch student info
    final studentDoc = await _studentsCollection.doc(user.uid).get();
    final studentData = studentDoc.data() ?? {};
    final studentName = studentData['name'] as String? ?? 'Student';
    final studentGrade = studentData['grade'] as String? ?? '';
    final studentStream = studentData['stream'] as String? ?? '';

    // 2. Upload receipt to Firebase Storage: payment_proofs/{uid}/{timestamp}.jpg
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileExtension = receiptFile.path.split('.').last;
    final storagePath = 'payment_proofs/${user.uid}/${timestamp}_receipt.$fileExtension';

    final storageRef = _storage.ref().child(storagePath);
    final uploadTask = await storageRef.putFile(
      receiptFile,
      SettableMetadata(contentType: 'image/$fileExtension'),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // 3. Create payment submission document
    final docRef = _submissionsCollection.doc();
    final submission = PaymentSubmission(
      id: docRef.id,
      studentId: user.uid,
      studentName: studentName,
      studentEmail: user.email ?? '',
      studentGrade: studentGrade,
      studentStream: studentStream,
      packageId: packageId,
      packageName: packageName,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionReference: transactionReference.trim(),
      receiptUrl: downloadUrl,
      receiptPath: storagePath,
      status: 'pending',
      submittedAt: DateTime.now(),
    );

    await docRef.set(submission.toMap());

    // 4. Send admin alert notification
    await _notificationService.sendNotification(
      userId: 'admin_alerts',
      title: 'New Payment Submission',
      body: '$studentName has submitted a payment of $amount ETB via $paymentMethod.',
      type: 'admin_alert',
      metadata: {'submissionId': docRef.id, 'studentId': user.uid},
    );

    return docRef.id;
  }

  // ============================================================
  // STUDENT: GET MY LATEST SUBMISSION
  // ============================================================

  Future<PaymentSubmission?> getMyLatestSubmission() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _submissionsCollection
        .where('studentId', isEqualTo: user.uid)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return PaymentSubmission.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
  }

  // ============================================================
  // STUDENT: GET SUBMISSION HISTORY
  // ============================================================

  Future<List<PaymentSubmission>> getMySubmissions() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _submissionsCollection
        .where('studentId', isEqualTo: user.uid)
        .orderBy('submittedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PaymentSubmission.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ============================================================
  // ADMIN: QUERY SUBMISSIONS
  // ============================================================

  Future<List<PaymentSubmission>> getSubmissions({
    String? statusFilter,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query =
        _submissionsCollection.orderBy('submittedAt', descending: true);

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => PaymentSubmission.fromMap(doc.id, doc.data()))
        .toList();
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
