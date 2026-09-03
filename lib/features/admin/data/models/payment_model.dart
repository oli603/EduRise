import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentSubmission {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentGrade;
  final String studentStream;
  final String packageId;
  final String packageName;
  final double amount;
  final String paymentMethod;
  final String transactionReference;
  final String receiptUrl;
  final String receiptPath;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewerEmail;

  const PaymentSubmission({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentGrade,
    required this.studentStream,
    required this.packageId,
    required this.packageName,
    required this.amount,
    required this.paymentMethod,
    required this.transactionReference,
    required this.receiptUrl,
    required this.receiptPath,
    required this.status,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewerEmail,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory PaymentSubmission.fromMap(String id, Map<String, dynamic> data) {
    return PaymentSubmission(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? 'Student',
      studentEmail: data['studentEmail'] as String? ?? '',
      studentGrade: data['studentGrade'] as String? ?? '',
      studentStream: data['studentStream'] as String? ?? '',
      packageId: data['packageId'] as String? ?? 'standard',
      packageName: data['packageName'] as String? ?? 'EduRise All-Access Pass',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'CBE',
      transactionReference: data['transactionReference'] as String? ?? '',
      receiptUrl: data['receiptUrl'] as String? ?? '',
      receiptPath: data['receiptPath'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      rejectionReason: data['rejectionReason'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      reviewerEmail: data['reviewerEmail'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'studentGrade': studentGrade,
      'studentStream': studentStream,
      'packageId': packageId,
      'packageName': packageName,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'transactionReference': transactionReference,
      'receiptUrl': receiptUrl,
      'receiptPath': receiptPath,
      'status': status,
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : FieldValue.serverTimestamp(),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'reviewerEmail': reviewerEmail,
    };
  }
}
