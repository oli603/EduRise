import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/features/payment/data/models/payment_submission.dart';
import 'package:edurise/features/payment/data/payment_settings_service.dart';
import 'package:edurise/features/notifications/data/notification_model.dart';
import 'package:edurise/features/admin/data/audit_service.dart';
import 'package:edurise/features/admin/data/admin_settings_service.dart';

void main() {
  group('PaymentSubmission Model Tests', () {
    test('Correctly serializes and deserializes PaymentSubmission', () {
      final now = DateTime.now();
      final submission = PaymentSubmission(
        id: 'sub_123',
        studentId: 'student_abc',
        studentName: 'Abebe Kebede',
        studentEmail: 'abebe@example.com',
        studentGrade: 'Grade 12',
        studentStream: 'Natural Science',
        packageId: 'full_access',
        packageName: 'EduRise All-Access Pass',
        amount: 500.0,
        paymentMethod: 'CBE',
        transactionReference: 'FT23490001',
        receiptUrl: 'https://storage.googleapis.com/receipt.jpg',
        receiptPath: 'payment_proofs/student_abc/123.jpg',
        status: 'pending',
        submittedAt: now,
      );

      expect(submission.isPending, isTrue);
      expect(submission.isApproved, isFalse);
      expect(submission.isRejected, isFalse);

      final map = submission.toMap();
      expect(map['studentId'], 'student_abc');
      expect(map['amount'], 500.0);
      expect(map['status'], 'pending');

      final fromMap = PaymentSubmission.fromMap('sub_123', {
        'studentId': 'student_abc',
        'studentName': 'Abebe Kebede',
        'studentEmail': 'abebe@example.com',
        'studentGrade': 'Grade 12',
        'studentStream': 'Natural Science',
        'packageId': 'full_access',
        'packageName': 'EduRise All-Access Pass',
        'amount': 500.0,
        'paymentMethod': 'CBE',
        'transactionReference': 'FT23490001',
        'receiptUrl': 'https://storage.googleapis.com/receipt.jpg',
        'receiptPath': 'payment_proofs/student_abc/123.jpg',
        'status': 'approved',
      });

      expect(fromMap.isApproved, isTrue);
      expect(fromMap.isPending, isFalse);
      expect(fromMap.isRejected, isFalse);
      expect(fromMap.studentName, 'Abebe Kebede');
    });

    test('PaymentSubmission copyWith overrides values cleanly', () {
      final original = PaymentSubmission(
        id: 'sub_1',
        studentId: 'stud_1',
        studentName: 'Abebe',
        studentEmail: 'abebe@example.com',
        studentGrade: 'Grade 12',
        studentStream: 'natural',
        packageId: 'full_access',
        packageName: 'EduRise Pass',
        amount: 1499.0,
        paymentMethod: 'Telebirr',
        transactionReference: 'TX123',
        receiptUrl: 'https://example.com/receipt.jpg',
        receiptPath: 'payment_proofs/stud_1/1.jpg',
        status: 'pending',
      );

      final updated = original.copyWith(
        status: 'approved',
        reviewedBy: 'admin_1',
        reviewerEmail: 'admin@edurise.et',
      );

      expect(updated.status, 'approved');
      expect(updated.isApproved, isTrue);
      expect(updated.reviewedBy, 'admin_1');
      expect(updated.studentName, 'Abebe');
    });

    test('Rejected state preserves rejection reason', () {
      final submission = PaymentSubmission.fromMap('sub_456', {
        'studentId': 'student_xyz',
        'status': 'rejected',
        'rejectionReason': 'Receipt screenshot was illegible',
      });

      expect(submission.isRejected, isTrue);
      expect(submission.rejectionReason, 'Receipt screenshot was illegible');
    });
  });

  group('AppNotification Model Tests', () {
    test('Correctly serializes and deserializes AppNotification', () {
      final notification = AppNotification(
        id: 'notif_001',
        userId: 'student_abc',
        title: 'Payment Approved 🎉',
        body: 'Your payment has been verified. Full access active.',
        type: 'payment_approved',
        isRead: false,
      );

      expect(notification.isRead, isFalse);
      expect(notification.type, 'payment_approved');

      final map = notification.toMap();
      expect(map['title'], 'Payment Approved 🎉');
      expect(map['userId'], 'student_abc');

      final deserialized = AppNotification.fromMap('notif_001', {
        'userId': 'all',
        'title': 'New Exam Published',
        'body': '2016 Natural Science exam is live.',
        'type': 'announcement',
        'isRead': true,
      });

      expect(deserialized.userId, 'all');
      expect(deserialized.isRead, isTrue);
      expect(deserialized.type, 'announcement');
    });
  });

  group('AuditLogEntry Model Tests', () {
    test('Correctly serializes and deserializes AuditLogEntry', () {
      final entry = AuditLogEntry(
        id: 'log_999',
        actorUid: 'admin_1',
        actorEmail: 'tamiratboja@gmail.com',
        actorRole: 'admin',
        action: 'payment_approved',
        targetType: 'payment_submission',
        targetId: 'sub_123',
        metadata: {'amount': 500.0},
      );

      expect(entry.action, 'payment_approved');
      expect(entry.actorRole, 'admin');

      final map = entry.toMap();
      expect(map['action'], 'payment_approved');
      expect(map['targetType'], 'payment_submission');
      expect(map['actorEmail'], 'tamiratboja@gmail.com');
    });
  });

  group('SystemSettings Model Tests', () {
    test('Provides sensible defaults and serializes properly', () {
      final defaults = SystemSettings.defaults();
      expect(defaults.cbeAccount, '1000123456789');
      expect(defaults.telebirrNumber, '0911000000');
      expect(defaults.subscriptionPrice, 1499.0);
      expect(defaults.maintenanceMode, isFalse);

      final map = defaults.toMap();
      final restored = SystemSettings.fromMap(map);
      expect(restored.cbeAccount, defaults.cbeAccount);
      expect(restored.telebirrNumber, defaults.telebirrNumber);
      expect(restored.subscriptionPrice, defaults.subscriptionPrice);
    });
  });

  group('PaymentSettings Model Tests', () {
    test('Provides payment-specific defaults matching system settings', () {
      final defaults = PaymentSettings.defaults();
      expect(defaults.cbeAccount, '1000123456789');
      expect(defaults.cbeAccountName, 'EduRise Academy');
      expect(defaults.telebirrNumber, '0911000000');
      expect(defaults.subscriptionPrice, 1499.0);
    });

    test('PaymentSettings.fromMap deserializes accurately with partial fallbacks', () {
      final settings = PaymentSettings.fromMap({
        'cbeAccount': '1000998877665',
        'subscriptionPrice': 1200.0,
      });

      expect(settings.cbeAccount, '1000998877665');
      expect(settings.cbeAccountName, 'EduRise Academy');
      expect(settings.telebirrNumber, '0911000000');
      expect(settings.subscriptionPrice, 1200.0);

      final map = settings.toMap();
      expect(map['cbeAccount'], '1000998877665');
      expect(map['subscriptionPrice'], 1200.0);
    });
  });
}
