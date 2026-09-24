import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/features/payment/data/models/payment_submission.dart';
import 'package:edurise/features/payment/data/payment_service.dart';
import 'package:edurise/features/payment/data/payment_admin_service.dart';
import 'package:edurise/features/payment/data/payment_settings_service.dart';

void main() {
  group('Payment Domain Boundary & Architecture Invariant Tests', () {
    test('Student SubmitPaymentScreen contains ZERO imports of features/admin/', () {
      final file = File('lib/features/payment/presentation/submit_payment_screen.dart');
      expect(file.existsSync(), isTrue, reason: 'submit_payment_screen.dart must exist');

      final content = file.readAsStringSync();
      expect(
        content.contains('features/admin/'),
        isFalse,
        reason: 'SubmitPaymentScreen must not import any file from features/admin/',
      );
      expect(
        content.contains('admin_settings_service.dart'),
        isFalse,
        reason: 'SubmitPaymentScreen must not import admin_settings_service.dart',
      );
      expect(
        content.contains('payment_admin_service.dart'),
        isFalse,
        reason: 'SubmitPaymentScreen must not import payment_admin_service.dart',
      );
    });

    test('Student PaymentService contains ZERO imports of features/admin/', () {
      final file = File('lib/features/payment/data/payment_service.dart');
      expect(file.existsSync(), isTrue, reason: 'payment_service.dart must exist');

      final content = file.readAsStringSync();
      expect(
        content.contains('features/admin/'),
        isFalse,
        reason: 'Student PaymentService must not import any file from features/admin/',
      );
      expect(
        content.contains('AdminService'),
        isFalse,
        reason: 'Student PaymentService must not depend on AdminService',
      );
      expect(
        content.contains('AuditService'),
        isFalse,
        reason: 'Student PaymentService must not depend on AuditService',
      );
    });

    test('PaymentSettingsService contains ZERO imports of features/admin/', () {
      final file = File('lib/features/payment/data/payment_settings_service.dart');
      expect(file.existsSync(), isTrue, reason: 'payment_settings_service.dart must exist');

      final content = file.readAsStringSync();
      expect(
        content.contains('features/admin/'),
        isFalse,
        reason: 'PaymentSettingsService must not import any file from features/admin/',
      );
    });

    test('Old admin payment files have been completely eliminated', () {
      final oldService = File('lib/features/admin/data/payment_service.dart');
      final oldModel = File('lib/features/admin/data/models/payment_model.dart');

      expect(oldService.existsSync(), isFalse, reason: 'Old admin payment_service.dart must be deleted');
      expect(oldModel.existsSync(), isFalse, reason: 'Old admin payment_model.dart must be deleted');
    });
  });

  group('PaymentDomain Models & Invariants', () {
    test('PaymentSubmission correctly constructs with required attributes and getters', () {
      final now = DateTime.now();
      final submission = PaymentSubmission(
        id: 'sub_001',
        studentId: 'student_123',
        studentName: 'Tadesse Gemechu',
        studentEmail: 'tadesse@example.com',
        studentGrade: 'Grade 12',
        studentStream: 'natural',
        packageId: 'full_access',
        packageName: 'EduRise All-Access Pass',
        amount: 1499.0,
        paymentMethod: 'Telebirr',
        transactionReference: 'TB998877',
        receiptUrl: 'https://storage.googleapis.com/receipt.jpg',
        receiptPath: 'payment_proofs/student_123/receipt.jpg',
        status: 'pending',
        submittedAt: now,
      );

      expect(submission.id, 'sub_001');
      expect(submission.studentId, 'student_123');
      expect(submission.isPending, isTrue);
      expect(submission.isApproved, isFalse);
      expect(submission.isRejected, isFalse);

      final approved = submission.copyWith(
        status: 'approved',
        reviewedAt: now,
        reviewedBy: 'admin_uid',
        reviewerEmail: 'tamiratboja@gmail.com',
      );
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);
      expect(approved.reviewedBy, 'admin_uid');

      final rejected = submission.copyWith(
        status: 'rejected',
        rejectionReason: 'Blurry receipt image',
      );
      expect(rejected.isRejected, isTrue);
      expect(rejected.rejectionReason, 'Blurry receipt image');
    });

    test('PaymentSettings provides reliable defaults matching production business rules', () {
      final defaults = PaymentSettings.defaults();
      expect(defaults.subscriptionPrice, 1499.0);
      expect(defaults.cbeAccount, '1000123456789');
      expect(defaults.cbeAccountName, 'EduRise Academy');
      expect(defaults.telebirrNumber, '0911000000');
    });

    test('PaymentSettings deserialization handles missing and custom fields safely', () {
      final custom = PaymentSettings.fromMap({
        'cbeAccount': '1000777888999',
        'cbeAccountName': 'EduRise Main',
        'telebirrNumber': '0922113344',
        'subscriptionPrice': 1200.0,
      });

      expect(custom.cbeAccount, '1000777888999');
      expect(custom.cbeAccountName, 'EduRise Main');
      expect(custom.telebirrNumber, '0922113344');
      expect(custom.subscriptionPrice, 1200.0);

      final map = custom.toMap();
      expect(map['cbeAccount'], '1000777888999');
      expect(map['subscriptionPrice'], 1200.0);
    });
  });

  group('Service Interface Conformance', () {
    test('PaymentService instantiates and exposes student methods', () {
      final service = PaymentService();
      expect(service, isNotNull);
      expect(service.getMyLatestSubmission, isNotNull);
      expect(service.getMySubmissions, isNotNull);
      expect(service.submitPaymentProof, isNotNull);
    });

    test('PaymentAdminService instantiates and exposes admin verification methods', () {
      final adminService = PaymentAdminService();
      expect(adminService, isNotNull);
      expect(adminService.getSubmissions, isNotNull);
      expect(adminService.approvePayment, isNotNull);
      expect(adminService.rejectPayment, isNotNull);
    });

    test('PaymentSettingsService instantiates and exposes settings methods', () {
      final settingsService = PaymentSettingsService();
      expect(settingsService, isNotNull);
      expect(settingsService.getPaymentSettings, isNotNull);
      expect(settingsService.getPaymentSettingsStream, isNotNull);
    });
  });
}
