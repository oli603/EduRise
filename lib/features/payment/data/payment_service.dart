import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../notifications/data/notification_service.dart';
import 'models/payment_submission.dart';

class PaymentService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final FirebaseStorage? _customStorage;
  final NotificationService? _customNotificationService;

  PaymentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    NotificationService? notificationService,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _customStorage = storage,
        _customNotificationService = notificationService;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseStorage get _storage =>
      _customStorage ?? FirebaseStorage.instance;
  NotificationService get _notificationService =>
      _customNotificationService ?? NotificationService();

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

    // 0. Idempotency protection against rapid duplicate taps
    final cleanRef = transactionReference.trim();
    if (cleanRef.isNotEmpty) {
      try {
        final existingPending = await _submissionsCollection
            .where('studentId', isEqualTo: user.uid)
            .where('transactionReference', isEqualTo: cleanRef)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 3));

        if (existingPending.docs.isNotEmpty) {
          debugPrint('PaymentService: Duplicate submission prevented for ref $cleanRef');
          return existingPending.docs.first.id;
        }
      } catch (_) {}
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

    // 4. Send idempotent admin alert notification
    await _notificationService.sendAdminNotificationOnce(
      idempotencyKey: 'payment_${docRef.id}',
      title: 'New Payment Submission',
      body: '$studentName has submitted a payment of $amount ETB via $paymentMethod.',
      type: 'payment_submitted',
      metadata: {'submissionId': docRef.id, 'studentId': user.uid},
    );

    return docRef.id;
  }

  // ============================================================
  // STUDENT: GET MY LATEST SUBMISSION (INDEX-RESILIENT)
  // ============================================================

  Future<PaymentSubmission?> getMyLatestSubmission() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _submissionsCollection
          .where('studentId', isEqualTo: user.uid)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final submissions = snapshot.docs
          .map((doc) => PaymentSubmission.fromMap(doc.id, doc.data()))
          .toList();

      submissions.sort((a, b) {
        final aTime = a.submittedAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.submittedAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      return submissions.first;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // STUDENT: GET SUBMISSION HISTORY (INDEX-RESILIENT)
  // ============================================================

  Future<List<PaymentSubmission>> getMySubmissions() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _submissionsCollection
          .where('studentId', isEqualTo: user.uid)
          .get();

      final submissions = snapshot.docs
          .map((doc) => PaymentSubmission.fromMap(doc.id, doc.data()))
          .toList();

      submissions.sort((a, b) {
        final aTime = a.submittedAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.submittedAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      return submissions;
    } catch (e) {
      return [];
    }
  }
}
